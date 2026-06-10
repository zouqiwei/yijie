//
//  ConversationView.swift
//  translate
//

import SwiftUI
import Translation

struct ConversationView: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var settingsVM: SettingsViewModel
    @State private var vm: ConversationViewModel
    
    // Translation framework state
    @State private var topToBottomConfig: TranslationSession.Configuration?
    @State private var bottomToTopConfig: TranslationSession.Configuration?
    
    // To ensure unique triggering
    @State private var topVersion = 0
    @State private var bottomVersion = 0

    private var themeStart: Color { settingsVM.currentTheme.colors[0] }
    private var themeEnd: Color { settingsVM.currentTheme.colors[1] }
    private var bg: Color { settingsVM.currentTheme.bg }

    init(settingsVM: SettingsViewModel, topLanguage: LanguageOption, bottomLanguage: LanguageOption) {
        self.settingsVM = settingsVM
        // If auto is selected, fallback to something concrete since Conversation needs explicit langs
        let safeTop = topLanguage.id == "auto" ? LanguageOption.allLanguages.first(where: { $0.id != bottomLanguage.id }) ?? LanguageOption.allLanguages[0] : topLanguage
        let safeBottom = bottomLanguage.id == "auto" ? LanguageOption.allLanguages.first(where: { $0.id != safeTop.id }) ?? LanguageOption.allLanguages[1] : bottomLanguage
        
        _vm = State(initialValue: ConversationViewModel(topLanguage: safeTop, bottomLanguage: safeBottom))
    }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ── Top Half (Person A) ──
                halfView(
                    isTop: true,
                    language: vm.topLanguage,
                    recognizedText: vm.activeSpeaker == .top ? vm.speechVM.recognizedText : vm.topRecognizedText,
                    translatedText: vm.topTranslatedText,
                    isActive: vm.activeSpeaker == .top,
                    onMicTapped: {
                        vm.toggleRecording(for: .top)
                    }
                )
                .rotationEffect(.degrees(180)) // Invert for face-to-face
                
                // ── Middle Divider & Close Button ──
                ZStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 2)
                    
                    Button(action: {
                        vm.stopRecording()
                        vm.stopSpeaking()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(bg)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    }
                }
                .frame(height: 44)
                
                // ── Bottom Half (Person B) ──
                halfView(
                    isTop: false,
                    language: vm.bottomLanguage,
                    recognizedText: vm.activeSpeaker == .bottom ? vm.speechVM.recognizedText : vm.bottomRecognizedText,
                    translatedText: vm.bottomTranslatedText,
                    isActive: vm.activeSpeaker == .bottom,
                    onMicTapped: {
                        vm.toggleRecording(for: .bottom)
                    }
                )
            }
            .ignoresSafeArea(.keyboard)
            
            // Error Banner Overlay
            if let err = vm.errorMessage {
                VStack {
                    Spacer()
                    errorBanner(err)
                        .padding(.bottom, 60)
                }
            }
        }
        .task {
            vm.speechRate = Float(settingsVM.speechRate)
            vm.speechVM.checkPermissionStatus()
        }
        // Watch for Top Speech completing -> Trigger Translation to Bottom
        .onChange(of: vm.activeSpeaker) { old, new in
            if old == .top && new == .none {
                triggerTopToBottomTranslation()
            } else if old == .bottom && new == .none {
                triggerBottomToTopTranslation()
            }
        }
        // Translation Task for Top -> Bottom
        .translationTask(topToBottomConfig) { session in
            let text = vm.topRecognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            
            do {
                vm.isTranslating = true
                let response = try await session.translate(text)
                vm.bottomTranslatedText = response.targetText
                vm.speak(text: response.targetText, in: vm.bottomLanguage)
                vm.isTranslating = false
            } catch {
                fallbackTopToBottom(text: text)
            }
        }
        // Translation Task for Bottom -> Top
        .translationTask(bottomToTopConfig) { session in
            let text = vm.bottomRecognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            
            do {
                vm.isTranslating = true
                let response = try await session.translate(text)
                vm.topTranslatedText = response.targetText
                vm.speak(text: response.targetText, in: vm.topLanguage)
                vm.isTranslating = false
            } catch {
                fallbackBottomToTop(text: text)
            }
        }
    }
    
    // MARK: - Translation Helpers
    
    private func triggerTopToBottomTranslation() {
        let text = vm.topRecognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Reset and trigger config
        topToBottomConfig = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            topToBottomConfig = TranslationSession.Configuration(
                source: vm.topLanguage.locale,
                target: vm.bottomLanguage.locale
            )
        }
    }
    
    private func triggerBottomToTopTranslation() {
        let text = vm.bottomRecognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Reset and trigger config
        bottomToTopConfig = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            bottomToTopConfig = TranslationSession.Configuration(
                source: vm.bottomLanguage.locale,
                target: vm.topLanguage.locale
            )
        }
    }
    
    private func fallbackTopToBottom(text: String) {
        Task { @MainActor in
            do {
                let result = try await BaiduTranslator.translate(text: text, source: vm.topLanguage.locale, target: vm.bottomLanguage.locale)
                vm.bottomTranslatedText = result
                vm.speak(text: result, in: vm.bottomLanguage)
                vm.isTranslating = false
            } catch {
                do {
                    let result2 = try await NetworkTranslator.translate(text: text, source: vm.topLanguage.locale, target: vm.bottomLanguage.locale)
                    vm.bottomTranslatedText = result2
                    vm.speak(text: result2, in: vm.bottomLanguage)
                    vm.isTranslating = false
                } catch {
                    vm.errorMessage = "翻译失败，请检查网络。"
                    vm.isTranslating = false
                }
            }
        }
    }
    
    private func fallbackBottomToTop(text: String) {
        Task { @MainActor in
            do {
                let result = try await BaiduTranslator.translate(text: text, source: vm.bottomLanguage.locale, target: vm.topLanguage.locale)
                vm.topTranslatedText = result
                vm.speak(text: result, in: vm.topLanguage)
                vm.isTranslating = false
            } catch {
                do {
                    let result2 = try await NetworkTranslator.translate(text: text, source: vm.bottomLanguage.locale, target: vm.topLanguage.locale)
                    vm.topTranslatedText = result2
                    vm.speak(text: result2, in: vm.topLanguage)
                    vm.isTranslating = false
                } catch {
                    vm.errorMessage = "翻译失败，请检查网络。"
                    vm.isTranslating = false
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func halfView(isTop: Bool, language: LanguageOption, recognizedText: String, translatedText: String, isActive: Bool, onMicTapped: @escaping () -> Void) -> some View {
        VStack {
            // Language Label
            HStack {
                Text(language.flag)
                Text(language.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, isTop ? 40 : 20)
            
            Spacer()
            
            // Text Area
            VStack(alignment: .leading, spacing: 12) {
                if !translatedText.isEmpty {
                    // Translated result (other person's speech)
                    Text(translatedText)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [themeStart, themeEnd], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .multilineTextAlignment(.leading)
                        .lineLimit(5)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if !recognizedText.isEmpty {
                    // Currently speaking text
                    Text(recognizedText)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(5)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    // Empty state
                    Text("点击麦克风说话...")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.2))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Mic Button
            Button(action: onMicTapped) {
                ZStack {
                    if isActive {
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 90, height: 90)
                            .scaleEffect(1.2)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isActive)
                    }
                    
                    Circle()
                        .fill(isActive ? Color.red : Color.white.opacity(0.15))
                        .frame(width: 70, height: 70)
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: isActive ? 0 : 1))
                        .shadow(color: isActive ? Color.red.opacity(0.5) : .clear, radius: 10, x: 0, y: 5)
                    
                    Image(systemName: isActive ? "stop.fill" : "mic.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(isActive ? .white : .white.opacity(0.8))
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .padding(.bottom, isTop ? 20 : 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isActive ? Color.black.opacity(0.2) : Color.clear)
        .contentShape(Rectangle()) // makes whole area tappable if we wanted to
    }
    
    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(msg)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
            Spacer()
            Button { vm.errorMessage = nil } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.white.opacity(0.4))
                    .font(.caption)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.15))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.3), lineWidth: 1))
        )
        .padding(.horizontal, 20)
    }
}
