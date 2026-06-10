//
//  HomeView.swift
//  translate
//

import SwiftUI
import Translation

// MARK: - 内部错误类型

enum TranslationError: Error {
    /// Apple Translation 两种调用方式均返回空字符串，说明 session 状态异常
    case emptyResponse
}

// MARK: - 输入模式枚举
enum InputMode: CaseIterable {
    case text, voice, image

    var title: String {
        switch self {
        case .text:  return "文字"
        case .voice: return "语音"
        case .image: return "图片"
        }
    }

    var icon: String {
        switch self {
        case .text:  return "text.cursor"
        case .voice: return "waveform"
        case .image: return "photo"
        }
    }
}

// MARK: - ScaleButtonStyle（全局复用）

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - HomeView

struct HomeView: View {

    // ── ViewModels ──
    @Bindable var settingsVM: SettingsViewModel
    @State private var translationVM = TranslationViewModel()
    @State private var speechVM      = SpeechViewModel()
    @State private var ocrVM         = ImageOCRViewModel()

    // ── UI 状态 ──
    @State private var inputMode: InputMode = .text
    @State private var isSwapping = false
    @State private var showingConversation = false

    // ── Translation framework ──
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var pendingText: String = ""
    /// 识别到的实际源语言（仅在 auto 模式下使用）
    @State private var detectedLanguage: LanguageOption?
    /// 看门狗 Task，若 translationTask 超时未触发则重置
    @State private var watchdogTask: Task<Void, Never>?
    /// 当前翻译请求的版本号，用于防止过期回调
    @State private var translationVersion: Int = 0
    /// 是否正在执行「先置 nil、再赋新 config」的两步重置
    @State private var isResettingConfig = false
    /// 记录当前请求是否为由于第一次失败而触发的自动重试
    @State private var isAutoRetryingFullFlow = false

    // 颜色（全部从主题读取）
    private var bg: Color { settingsVM.currentTheme.bg }
    private var themeStart: Color { settingsVM.currentTheme.colors[0] }
    private var themeEnd:   Color { settingsVM.currentTheme.colors[1] }

    // MARK: - Body

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    languageSelectorView
                    conversationEntryView
                    modeSelectorView
                    inputAreaView
                    translateButtonView
                    resultSectionView
                    errorBannerView
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 50)
            }
            // header 挂在 ScrollView 外，自动调整内容区 inset
            .safeAreaInset(edge: .top, spacing: 0) {
                headerView
            }
        }
        // ── Apple Translation 任务 ──
        .translationTask(translationConfig) { session in
            // config 被置 nil 时也会触发（session 为重置中间态），直接忽略
            guard !isResettingConfig, !pendingText.isEmpty else {
                print("[Translation] ⏭ skip: isResettingConfig=\(isResettingConfig) pendingText=\(pendingText.isEmpty)")
                return
            }

            // 取消看门狗
            watchdogTask?.cancel()
            watchdogTask = nil

            let capturedVersion = translationVersion
            print("[Translation] 🚀 translationTask fired v\(capturedVersion) pendingText=\(pendingText)")

            do {
                let availability = LanguageAvailability()
                if let sessionSrc = session.sourceLanguage, let sessionTgt = session.targetLanguage {
                    let status = await availability.status(from: sessionSrc, to: sessionTgt)
                    print("[Translation] 📊 Availability: \(status)")
                    if status == .unsupported {
                        print("[Translation] ⚠️ Apple Translation unsupported, falling back to Baidu...")
                        let actualSourceOption = detectedLanguage ?? translationVM.sourceLanguage
                        do {
                            var fallbackText: String
                            do {
                                fallbackText = try await BaiduTranslator.translate(
                                    text: pendingText,
                                    source: actualSourceOption.locale,
                                    target: translationVM.targetLanguage.locale
                                )
                                print("[Translation] ✅ Baidu Translator succeeded: \(fallbackText)")
                            } catch {
                                print("[Translation] ⚠️ Baidu failed: \(error), trying MyMemory...")
                                fallbackText = try await NetworkTranslator.translate(
                                    text: pendingText,
                                    source: actualSourceOption.locale,
                                    target: translationVM.targetLanguage.locale
                                )
                                print("[Translation] ✅ MyMemory fallback succeeded: \(fallbackText)")
                            }
                            guard translationVersion == capturedVersion else { return }
                            translationVM.translatedText = fallbackText
                            translationVM.errorMessage = nil
                            settingsVM.addHistory(
                                sourceText: pendingText,
                                targetText: fallbackText,
                                sourceLanguage: actualSourceOption.displayName,
                                targetLanguage: translationVM.targetLanguage.displayName
                            )
                        } catch {
                            guard translationVersion == capturedVersion else { return }
                            translationVM.errorMessage = "翻译失败，请检查网络连接。"
                        }
                        translationVM.isTranslating = false
                        return
                    }
                }

                try await session.prepareTranslation()
                let translatedText = try await translateText(pendingText, using: session)

                // 版本过期（用户又发起了新翻译），丢弃
                guard translationVersion == capturedVersion else { return }

                guard !translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    translationVM.errorMessage = "翻译结果为空，请检查语言包是否已下载。"
                    translationVM.isTranslating = false
                    return
                }
                translationVM.translatedText = translatedText
                settingsVM.addHistory(
                    sourceText: pendingText,
                    targetText: translatedText,
                    sourceLanguage: translationVM.sourceLanguage.displayName,
                    targetLanguage: translationVM.targetLanguage.displayName
                )
            } catch {
                guard translationVersion == capturedVersion else { return }
                print("[Translation] ❌ Apple Translation error v\(capturedVersion): \(error)")
                print("[Translation] 🛟 Apple Translation failed/hung. Using Google Translate fallback...")
                
                // ── 核心：Apple Translation 框架无响应时，先尝试百度翻译，失败再用 MyMemory 兜底 ──
                do {
                    let actualSourceOption = detectedLanguage ?? translationVM.sourceLanguage
                    var fallbackText: String
                    do {
                        print("[Translation] 🛟 Trying Baidu Translator...")
                        fallbackText = try await BaiduTranslator.translate(
                            text: pendingText,
                            source: actualSourceOption.locale,
                            target: translationVM.targetLanguage.locale
                        )
                        print("[Translation] ✅ Baidu Translator succeeded: \(fallbackText)")
                    } catch {
                        print("[Translation] ⚠️ Baidu Translator failed: \(error), falling back to MyMemory...")
                        fallbackText = try await NetworkTranslator.translate(
                            text: pendingText,
                            source: actualSourceOption.locale,
                            target: translationVM.targetLanguage.locale
                        )
                        print("[Translation] ✅ MyMemory fallback succeeded: \(fallbackText)")
                    }
                    guard translationVersion == capturedVersion else { return }

                    translationVM.translatedText = fallbackText
                    settingsVM.addHistory(
                        sourceText: pendingText,
                        targetText: fallbackText,
                        sourceLanguage: actualSourceOption.displayName,
                        targetLanguage: translationVM.targetLanguage.displayName
                    )
                    translationVM.errorMessage = nil
                } catch let fallbackErr {
                    guard translationVersion == capturedVersion else { return }
                    print("[Translation] ❌ All fallbacks failed: \(fallbackErr)")
                    
                    // ── 新增：第一次启动由于 Apple 翻译尚未唤醒可能导致超时并双双失败，此时自动重试一次整个流程 ──
                    if !isAutoRetryingFullFlow {
                        print("[Translation] 🔁 First time failed completely, triggering auto-retry of the entire flow...")
                        Task { @MainActor in
                            triggerTranslation(text: pendingText, isAutoRetry: true)
                        }
                        return
                    }
                    
                    translationVM.errorMessage = "翻译失败。系统服务无响应，且网络兜底请求异常。\n请检查网络或在「设置 → 通用 → 语言与地区」中检查语言包。"
                }
                
                if translationVersion == capturedVersion {
                    translationVM.isTranslating = false
                }
            }
            if translationVersion == capturedVersion {
                translationVM.isTranslating = false
            }
        }
        // 启动时仅查询现有权限状态（不弹系统对话框）
        .task { speechVM.checkPermissionStatus() }
        .fullScreenCover(isPresented: $showingConversation) {
            ConversationView(
                settingsVM: settingsVM,
                topLanguage: translationVM.targetLanguage, // Top person represents the target language
                bottomLanguage: translationVM.sourceLanguage // Bottom person represents the source language
            )
        }
    }

    private func translateText(_ text: String, using session: TranslationSession) async throws -> String {
        let request = TranslationSession.Request(sourceText: text, clientIdentifier: "current")
        let responses = try await session.translations(from: [request])

        if let response = responses.first {
            let targetText = normalizedTargetText(from: response)
            print("[Translation] ✅ batch source=\(response.sourceLanguage.languageCode?.identifier ?? "nil"), target=\(response.targetLanguage.languageCode?.identifier ?? "nil"), result=\(targetText.isEmpty ? "<empty>" : targetText)")
            if !targetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return targetText
            }
            print("[Translation] ⚠️ batch returned empty, trying single…")
        } else {
            print("[Translation] ⚠️ batch response array was empty, trying single…")
        }

        let singleResponse = try await session.translate(text)
        let targetText = normalizedTargetText(from: singleResponse)
        print("[Translation] ✅ single source=\(singleResponse.sourceLanguage.languageCode?.identifier ?? "nil"), target=\(singleResponse.targetLanguage.languageCode?.identifier ?? "nil"), result=\(targetText.isEmpty ? "<empty>" : targetText)")

        // 两种方式均返回空字符串——说明 session 状态异常，抛出错误触发自动重建
        if targetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("[Translation] ❌ Both methods returned empty — session likely in bad state")
            throw TranslationError.emptyResponse
        }
        return targetText
    }

    private func normalizedTargetText(from response: TranslationSession.Response) -> String {
        let plainText = response.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !plainText.isEmpty {
            return response.targetText
        }

        if #available(iOS 26.4, *), let attributedText = response.attributedTargetText {
            return String(attributedText.characters)
        }

        return response.targetText
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text("智能翻译")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("文字 · 语音 · 图片 OCR")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            // App 图标圆圈
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [themeStart, themeEnd],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing)
                    )
                    .frame(width: 54, height: 54)
                    .shadow(color: themeStart.opacity(0.6), radius: 12, x: 0, y: 6)

                Image(systemName: "globe")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 20)
        // 渐变背景向上延伸覆盖安全区（刘海 / Dynamic Island 区域）
        .background(
            LinearGradient(
                colors: [settingsVM.currentTheme.headerGradientTop, bg],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Language Selector

    private var languageSelectorView: some View {
        HStack(spacing: 10) {
            sourceLanguageMenuButton

            // 交换按鈕
            Button(action: swapLanguages) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: [themeStart, themeEnd],
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing)
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: themeStart.opacity(0.45), radius: 8, x: 0, y: 4)

                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(isSwapping ? 180 : 0))
                }
            }
            .buttonStyle(ScaleButtonStyle())
            // auto 模式下暂时禁用交换（因为还不知道实际源语言）
            .disabled(translationVM.sourceLanguage.id == "auto" && detectedLanguage == nil)
            .opacity((translationVM.sourceLanguage.id == "auto" && detectedLanguage == nil) ? 0.45 : 1)

            languageMenuButton(language: translationVM.targetLanguage, label: "目标语言") { lang in
                translationVM.targetLanguage = lang
                resetResult()
            }
        }
    }

    /// 源语言单独处理：包含自动识别选项
    private var sourceLanguageMenuButton: some View {
        let isAuto = translationVM.sourceLanguage.id == "auto"
        let displayLang: LanguageOption = isAuto ? (detectedLanguage ?? .auto) : translationVM.sourceLanguage
        let labelText = isAuto ? "源语言" : "源语言"
        let detectedBadge: String? = isAuto && detectedLanguage != nil ? "已识别" : nil

        return Menu {
            // 置顶：自动识别
            Button {
                translationVM.sourceLanguage = .auto
                detectedLanguage = nil
                resetResult()
            } label: {
                if translationVM.sourceLanguage.id == "auto" {
                    Label("🔍 自动识别", systemImage: "checkmark")
                } else {
                    Text("🔍 自动识别")
                }
            }

            Divider()

            let options = LanguageOption.allLanguages
            ForEach(options) { lang in
                Button {
                    translationVM.sourceLanguage = lang
                    detectedLanguage = nil
                    resetResult()
                } label: {
                    if lang.id == translationVM.sourceLanguage.id {
                        Label("\(lang.flag) \(lang.displayName)", systemImage: "checkmark")
                    } else {
                        Text("\(lang.flag) \(lang.displayName)")
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                // 图标区：自动识别时显示动态 icon
                if isAuto && detectedLanguage == nil {
                    Image(systemName: "wand.and.sparkles")
                        .font(.title3)
                        .foregroundStyle(
                            LinearGradient(colors: [themeStart, themeEnd],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                } else {
                    Text(displayLang.flag).font(.title3)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(isAuto && detectedLanguage == nil ? "自动识别" : displayLang.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        // 识别得到时展示徽章
                        if let badge = detectedBadge {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(
                                        LinearGradient(colors: [themeStart, themeEnd],
                                                       startPoint: .leading, endPoint: .trailing)
                                    )
                                )
                        }
                    }

                    HStack {
                        Text(labelText)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(
                        isAuto
                        ? AnyShapeStyle(LinearGradient(colors: [themeStart.opacity(0.6), themeEnd.opacity(0.6)],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(Color.white.opacity(0.1)),
                        lineWidth: isAuto ? 1.5 : 1))
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func languageMenuButton(
        language: LanguageOption,
        label: String,
        onSelect: @escaping (LanguageOption) -> Void
    ) -> some View {
        Menu {
            let options = LanguageOption.allLanguages
            ForEach(options) { lang in
                Button {
                    onSelect(lang)
                } label: {
                    if lang.id == language.id {
                        Label("\(lang.flag) \(lang.displayName)", systemImage: "checkmark")
                    } else {
                        Text("\(lang.flag) \(lang.displayName)")
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(language.flag).font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    HStack {
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
            )
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Conversation Entry
    
    private var conversationEntryView: some View {
        Button {
            showingConversation = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [themeStart, themeEnd], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 36, height: 36)
                    Image(systemName: "rectangle.split.2x1")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("面对面分屏对话")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text("双人实时语音翻译")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: [themeStart.opacity(0.15), themeEnd.opacity(0.05)], startPoint: .leading, endPoint: .trailing))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(themeStart.opacity(0.3), lineWidth: 1))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Mode Selector

    private var modeSelectorView: some View {
        HStack(spacing: 0) {
            ForEach(InputMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.spring(duration: 0.3)) { inputMode = mode }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 18, weight: .medium))
                        Text(mode.title)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(inputMode == mode ? .white : .white.opacity(0.38))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                inputMode == mode
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [themeStart, themeEnd],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing))
                                : AnyShapeStyle(Color.clear)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 17)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
    }

    // MARK: - Input Area

    @ViewBuilder
    private var inputAreaView: some View {
        switch inputMode {
        case .text:
            TextInputView(vm: translationVM, theme: settingsVM.currentTheme)

        case .voice:
            VoiceInputView(
                speechVM: speechVM,
                sourceLocale: translationVM.sourceLanguage.speechRecognitionLocaleIdentifier,
                theme: settingsVM.currentTheme,
                onTranslate: {
                    triggerTranslation(text: speechVM.recognizedText)
                }
            )

        case .image:
            ImageInputView(ocrVM: ocrVM, theme: settingsVM.currentTheme, onTranslate: {
                triggerTranslation(text: ocrVM.combinedText)
            })
        }
    }

    // MARK: - Translate Button

    @ViewBuilder
    private var translateButtonView: some View {
        let hasInput: Bool = {
            switch inputMode {
            case .text:  return !translationVM.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .voice: return !speechVM.recognizedText.isEmpty && !speechVM.isRecording
            case .image: return false // 图片模式内部有翻译按钮
            }
        }()

        if hasInput {
            Button {
                switch inputMode {
                case .text:  triggerTranslation(text: translationVM.inputText)
                case .voice: triggerTranslation(text: speechVM.recognizedText)
                case .image: break
                }
            } label: {
                HStack(spacing: 10) {
                    if translationVM.isTranslating {
                        ProgressView().tint(.white).scaleEffect(0.85)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(translationVM.isTranslating ? "翻译中…" : "翻译")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    LinearGradient(
                        colors: translationVM.isTranslating
                            ? [themeStart.opacity(0.55), themeEnd.opacity(0.55)]
                            : [themeStart, themeEnd],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: themeStart.opacity(translationVM.isTranslating ? 0 : 0.4),
                        radius: translationVM.isTranslating ? 0 : 12,
                        x: 0, y: translationVM.isTranslating ? 0 : 6)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(translationVM.isTranslating)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(duration: 0.3), value: hasInput)
        }
    }

    // MARK: - Result

    @ViewBuilder
    private var resultSectionView: some View {
        if !translationVM.translatedText.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(themeStart)
                        .font(.system(size: 14))
                    Text("翻译结果")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.75))
                }

                TranslationResultCard(
                    text: translationVM.translatedText,
                    language: translationVM.targetLanguage,
                    speechRate: Float(settingsVM.speechRate),
                    theme: settingsVM.currentTheme,
                    isFavorite: settingsVM.history.first(where: { $0.sourceText == pendingText && $0.targetText == translationVM.translatedText })?.isFavorite ?? false,
                    onToggleFavorite: {
                        if let item = settingsVM.history.first(where: { $0.sourceText == pendingText && $0.targetText == translationVM.translatedText }) {
                            settingsVM.toggleFavorite(for: item)
                        }
                    }
                )
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(duration: 0.45), value: translationVM.translatedText)
        }
    }

    // MARK: - Error Banner

    @ViewBuilder
    private var errorBannerView: some View {
        if let msg = translationVM.errorMessage {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(msg)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Button { translationVM.errorMessage = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.orange.opacity(0.14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.28), lineWidth: 1))
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Actions

    private func swapLanguages() {
        // 若当前是 auto 模式且已识别到语言，先固定为实际检测语言再交换
        if translationVM.sourceLanguage.id == "auto", let detected = detectedLanguage {
            translationVM.sourceLanguage = detected
            detectedLanguage = nil
        }
        withAnimation(.spring(duration: 0.45)) {
            isSwapping = true
            translationVM.swapLanguages()
        }
        translationConfig = nil
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            isSwapping = false
        }
    }

    private func resetResult() {
        translationVM.translatedText = ""
        translationVM.errorMessage   = nil
        translationConfig            = nil
        if translationVM.sourceLanguage.id != "auto" {
            detectedLanguage = nil
        }
    }

    /// 触发 Apple Translation
    private func triggerTranslation(text: String, isAutoRetry: Bool = false) {
        self.isAutoRetryingFullFlow = isAutoRetry
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        // — 自动识别模式：先用 NLLanguageRecognizer 检测 —
        var effectiveSource = translationVM.sourceLanguage
        if translationVM.sourceLanguage.id == "auto" {
            if let detected = LanguageOption.detect(from: clean) {
                effectiveSource = detected
                detectedLanguage = detected
                print("[Translation] 🤖 Auto-detected: \(detected.displayName)")
                if detected.id == translationVM.targetLanguage.id {
                    let fallback = LanguageOption.allLanguages.first { $0.id != detected.id } ?? LanguageOption.allLanguages[0]
                    translationVM.targetLanguage = fallback
                }
            } else {
                detectedLanguage = nil
                translationVM.errorMessage = "无法识别语言，请手动选择源语言。"
                return
            }
        }

        pendingText                  = clean
        translationVM.isTranslating  = true
        translationVM.translatedText = ""
        translationVM.errorMessage   = nil
        translationVersion          += 1

        let src = effectiveSource.locale
        let tgt = translationVM.targetLanguage.locale
        print("[Translation] 🎯 v\(translationVersion) src=\(src.languageCode?.identifier ?? "?") tgt=\(tgt.languageCode?.identifier ?? "?")")

        // ── 核心修复：始终走 nil → 新 config 的两步赋值 ──
        // 不再使用 invalidate()，强制 SwiftUI 完全销毁并重建 Translation Session
        Task { @MainActor in
            await applyNewConfig(source: src, target: tgt)
        }

        // ── 看门狗：8 秒内 translationTask 未触发/未完成则执行网络兜底 ──
        let capturedVersion = translationVersion
        let capturedText = pendingText
        let srcLang = effectiveSource
        let tgtLang = translationVM.targetLanguage
        
        watchdogTask?.cancel()
        watchdogTask = Task { @MainActor in
            // 将超时时间缩短为 8 秒，以便更快接管
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled, translationVersion == capturedVersion,
                  translationVM.isTranslating else { return }
            
            print("[Translation] ⏰ Watchdog: session not responding. Switching to Network API...")
            
            // 立即置空 config 防止挂起的 Apple Translation 突然返回覆盖 UI
            translationConfig = nil
            
            do {
                let fallbackText = try await NetworkTranslator.translate(
                    text: capturedText,
                    source: srcLang.locale,
                    target: tgtLang.locale
                )
                guard translationVersion == capturedVersion else { return }
                print("[Translation] ✅ Watchdog Fallback succeeded: \(fallbackText)")
                
                translationVM.translatedText = fallbackText
                settingsVM.addHistory(
                    sourceText: capturedText,
                    targetText: fallbackText,
                    sourceLanguage: srcLang.displayName,
                    targetLanguage: tgtLang.displayName
                )
                translationVM.errorMessage = nil
            } catch let fallbackErr {
                guard translationVersion == capturedVersion else { return }
                print("[Translation] ❌ Watchdog Fallback failed: \(fallbackErr)")
                
                // ── 自动重试机制 ──
                if !isAutoRetryingFullFlow {
                    print("[Translation] 🔁 Watchdog failed completely, triggering auto-retry of the entire flow...")
                    triggerTranslation(text: capturedText, isAutoRetry: true)
                    return
                }
                
                translationVM.errorMessage = "翻译超时。Apple 翻译未响应，且网络兜底失败。\n请检查网络连接。"
            }
            
            if translationVersion == capturedVersion {
                translationVM.isTranslating = false
            }
        }
    }

    /// 强制 nil → 新 config
    /// 使用 Task.sleep(100ms) 而非 Task.yield()，
    /// 确保主线程 RunLoop 完整跑一圈，SwiftUI 真正提交 nil 状态再赋新 config
    @MainActor
    private func applyNewConfig(source: Locale.Language, target: Locale.Language) async {
        isResettingConfig = true
        translationConfig = nil
        // 必须 sleep 而非 yield：
        // yield 只是让出当前 Task，主线程 RunLoop 不一定处理完 SwiftUI diff
        // sleep 才能确保跨过至少一个 16ms 帧，nil 状态被封存到视图树后再赋新值
        try? await Task.sleep(for: .milliseconds(100))
        isResettingConfig = false
        translationConfig = TranslationSession.Configuration(source: source, target: target)
        print("[Translation] ✅ New config applied: \(source.languageCode?.identifier ?? "?") → \(target.languageCode?.identifier ?? "?")")
    }

    /// 出错后强制重建 session（目前作为后续可能的兜底备用，主要走 GoogleFallback）
    @MainActor
    private func forceRebuildSession() async {
        guard let cfg = translationConfig else { return }
        let src = cfg.source
        let tgt = cfg.target
        await applyNewConfig(source: src ?? Locale.Language(identifier: "en"),
                             target: tgt ?? Locale.Language(identifier: "zh-Hans"))
    }
}

#Preview {
    HomeView(settingsVM: SettingsViewModel())
}
