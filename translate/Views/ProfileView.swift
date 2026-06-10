//
//  ProfileView.swift
//  translate
//
import SwiftUI
import UIKit
import PhotosUI

struct ProfileView: View {
    @Bindable var settingsVM: SettingsViewModel
    
    private var bg: Color { settingsVM.currentTheme.bg }

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()
                
                List {
                    Section {
                        profileRow(icon: "clock.fill", color: .blue, title: "翻译历史", destination: HistoryView(settingsVM: settingsVM, initialFilterMode: .all))
                        
                        profileRow(icon: "speaker.wave.2.fill", color: .purple, title: "偏好设置", destination: SettingsDetailView(settingsVM: settingsVM))
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                    
                    Section {
                        profileRow(icon: "doc.text.fill", color: .gray, title: "用户协议", destination: TextDetailView(title: "用户协议", content: userAgreementContent, bgColor: settingsVM.currentTheme.bg))
                        
                        profileRow(icon: "lock.shield.fill", color: .green, title: "隐私政策", destination: TextDetailView(title: "隐私政策", content: privacyPolicyContent, bgColor: settingsVM.currentTheme.bg))

                        profileRow(icon: "envelope.fill", color: .cyan, title: "反馈与联系我们", destination: FeedbackView(settingsVM: settingsVM))
                        
                        profileRow(
                            icon: "info.circle.fill",
                            color: .orange,
                            title: "关于",
                            destination: TextDetailView(
                                title: "关于",
                                content: aboutContent,
                                bgColor: settingsVM.currentTheme.bg,
                                logoName: "logo",
                                contentFont: .footnote
                            )
                        )
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
                .scrollContentBackground(.hidden)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                headerView
            }
            // 隐藏自带的导航栏，使用自定义的 headerView
            .toolbar(.hidden, for: .navigationBar)
        }
    } 
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text("我的")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("设置 · 历史 · 协议")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            // 装饰圆圈
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: settingsVM.currentTheme.colors,
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing)
                    )
                    .frame(width: 54, height: 54)
                    .shadow(color: settingsVM.currentTheme.colors[0].opacity(0.6), radius: 12, x: 0, y: 6)

                Image(systemName: "person.fill")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: [settingsVM.currentTheme.headerGradientTop, settingsVM.currentTheme.bg],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }

    private var aboutContent: String {
        """
        译介App
        版本 1.0.0

        译介App是一款面向日常沟通、学习阅读和出行场景的多方式翻译工具。我们希望它既能快速完成一句话的翻译，也能在更复杂的交流场景中保持清晰、顺手和可靠。

        核心功能
        · 文字翻译：输入文本后快速获取译文，适合聊天、邮件、笔记和资料阅读。
        · 语音翻译：通过语音输入完成翻译，减少打字成本，适合面对面沟通。
        · 图片文字识别：从图片中提取文字并翻译，方便处理菜单、标识、截图和纸质资料。
        · 对话翻译：支持双向对话场景，让跨语言交流更自然。
        · 翻译历史：自动保存常用翻译记录，支持查看详情、复制、分享和收藏。
        · 个性化设置：可调整主题颜色和语音播放偏好，让使用体验更贴合个人习惯。

        适用场景
        无论是旅行问路、学习外语、阅读资料，还是和不同语言的朋友交流，你都可以把它当作一个轻量、随手可用的翻译助手。

        感谢使用译介App。我们会持续优化翻译体验、交互细节和稳定性，让它成为你日常跨语言沟通中的可靠工具。
        """
    }

    private var userAgreementContent: String {
        """
        译介App用户协议
        生效日期：2026-06-09

        欢迎使用译介App。请你在使用本应用前仔细阅读并理解本协议。你使用本应用，即表示你已阅读、理解并同意本协议内容。

        一、服务内容
        译介App为用户提供文字翻译、语音输入、图片文字识别、对话翻译、翻译历史、收藏和相关偏好设置等功能。具体功能可能会根据版本更新、设备能力或系统权限情况发生变化。

        二、使用规则
        你应合法、正当地使用本应用，不得利用本应用从事违法违规、侵犯他人权益、扰乱正常服务或违反公序良俗的行为。你输入、上传或识别的文本、语音、图片等内容，应由你自行确保来源合法并有权使用。

        三、权限使用
        为实现语音翻译、图片文字识别等功能，本应用可能需要访问麦克风、相机、相册或语音识别等系统权限。相关权限仅用于你主动触发的功能。你可以在系统设置中随时关闭权限，但关闭后对应功能可能无法正常使用。

        四、翻译结果说明
        翻译和识别结果可能受语言环境、表达方式、图片清晰度、语音质量、网络状态或系统能力影响。本应用会尽力提供准确、可读的结果，但不保证所有翻译内容完全准确。涉及法律、医疗、金融、考试、合同等重要场景时，请结合专业意见进行判断。

        五、历史记录与内容管理
        本应用会保存你的翻译历史和收藏内容，以便你回看、复制、分享或管理常用翻译。你可以在应用内删除单条历史记录、取消收藏或清空历史记录。请妥善管理包含敏感信息的翻译内容。

        六、知识产权
        本应用的界面设计、功能结构、图标、文字说明及相关内容，除依法属于第三方或用户自行提供的内容外，均受相关法律保护。未经许可，不得复制、修改、传播或用于商业用途。

        七、免责声明
        在法律允许的范围内，因用户不当使用、本地设备或系统环境异常、网络服务波动、第三方能力限制等原因造成的损失，本应用不承担超出法律规定范围的责任。

        八、协议更新
        我们可能根据功能调整、法律法规变化或产品运营需要更新本协议。更新后的协议会在应用内展示。若你继续使用本应用，即视为接受更新后的协议。

        九、联系我们
        如果你对本协议或应用使用有疑问，可以通过邮箱 dexunkklxc@163.com 与我们联系。
        """
    }

    private var privacyPolicyContent: String {
        """
        译介App隐私政策
        生效日期：2026-06-09

        译介App重视你的隐私和个人信息保护。本政策说明我们在提供翻译、语音、图片识别、历史记录等功能时，如何处理与你相关的信息。

        一、我们处理的信息
        为提供服务，本应用可能处理以下信息：
        · 你主动输入的文本内容，用于生成翻译结果。
        · 你主动录入的语音内容，用于语音识别和翻译。
        · 你主动选择或拍摄的图片内容，用于文字识别和翻译。
        · 翻译历史、收藏状态、语言选择、主题和语速设置等应用使用数据。

        二、权限说明
        麦克风权限：用于语音输入和语音翻译。
        相机权限：用于拍摄图片并识别其中的文字。
        相册权限：用于选择图片进行文字识别。
        语音识别权限：用于将语音转换为文字。

        这些权限仅在你主动使用相关功能时调用。你可以在系统设置中关闭权限，关闭后对应功能可能无法使用。

        三、信息的使用目的
        我们处理相关信息是为了：
        · 完成文字、语音、图片和对话翻译。
        · 保存和展示翻译历史及收藏内容。
        · 记住你的主题、语速等偏好设置。
        · 优化应用体验、稳定性和功能表现。

        四、本地存储
        翻译历史、收藏内容和偏好设置会保存在你的设备本地，用于方便你再次查看和管理。你可以在应用内删除历史记录或清空相关内容。卸载应用也可能清除本地保存的数据。

        五、第三方服务
        当应用调用系统能力或翻译、语音、识别等相关服务时，你输入的内容可能会被发送至系统或服务提供方进行处理。不同系统版本和服务能力的处理方式可能不同，具体也可能受相关服务提供方规则约束。

        六、信息安全
        我们会尽力采用合理方式保护你的信息安全。但请理解，任何系统或网络环境都无法保证绝对安全。请避免在不必要的情况下输入或保存身份证号、银行卡号、密码、私人通信等高度敏感信息。

        七、你的管理权利
        你可以在应用内查看、删除翻译历史，取消收藏或清空历史记录；也可以在系统设置中管理相机、麦克风、相册、语音识别等权限。

        八、未成年人使用
        未成年人应在监护人指导下使用本应用。监护人应帮助未成年人理解本政策，并合理管理其输入、识别和保存的内容。

        九、政策更新
        我们可能根据功能变化或法律法规要求更新本政策。更新后的内容会在应用内展示。若你继续使用本应用，即表示你了解并接受更新后的政策。

        十、联系我们
        如果你对隐私政策或信息处理方式有疑问，可以通过邮箱 dexunkklxc@163.com 与我们联系。
        """
    }

    private var contactContent: String {
        """
        反馈与联系我们

        感谢你使用译介App。如果你在使用过程中遇到问题，或希望提出功能建议、体验反馈、隐私相关疑问，可以通过以下方式联系我们：

        邮箱
        dexunkklxc@163.com

        为了更快定位问题，建议你在反馈时尽量提供以下信息：
        · 你使用的设备型号和系统版本。
        · App版本号。
        · 遇到问题的功能页面，例如文字翻译、语音翻译、图片识别、对话翻译或翻译历史。
        · 问题出现的大致步骤。
        · 如方便，可附上错误提示或截图说明。

        常见反馈范围
        · 翻译结果不准确或不自然。
        · 语音识别、图片识别无法正常使用。
        · 权限、历史记录、收藏或复制分享相关问题。
        · App界面显示异常、卡顿、闪退或其他稳定性问题。
        · 对新功能、语言支持或交互体验的建议。

        我们会认真阅读你的反馈，并在后续版本中持续优化体验。感谢你的支持。
        """
    }
    
    private func profileRow<V: View>(icon: String, color: Color, title: String, destination: V) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.2))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(color)
                }
                
                Text(title)
                    .font(.body)
                    .foregroundStyle(.white)
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Sub Views

/// 历史记录页
struct HistoryView: View {
    @Bindable var settingsVM: SettingsViewModel
    @State private var showingClearAlert = false
    @State private var filterMode: FilterMode
    
    enum FilterMode { case all, favorites }
    
    init(settingsVM: SettingsViewModel, initialFilterMode: FilterMode = .all) {
        self.settingsVM = settingsVM
        _filterMode = State(initialValue: initialFilterMode)
    }
    
    private var bg: Color { settingsVM.currentTheme.bg }

    private static let listDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
    
    var filteredHistory: [TranslationHistoryItem] {
        filterMode == .all ? settingsVM.history : settingsVM.history.filter { $0.isFavorite }
    }
    
    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            
            if settingsVM.history.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock.badge.xmark")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.2))
                    Text("暂无翻译历史")
                        .foregroundStyle(.white.opacity(0.4))
                }
            } else {
                VStack(spacing: 0) {
                    Picker("筛选", selection: $filterMode) {
                        Text("全部").tag(FilterMode.all)
                        Text("我的收藏").tag(FilterMode.favorites)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 16)

                    List {
                        ForEach(filteredHistory) { item in
                            let timestampText = Self.listDateFormatter.string(from: item.timestamp)
                            NavigationLink {
                                HistoryDetailView(settingsVM: settingsVM, item: item)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("\(item.sourceLanguage) ➔ \(item.targetLanguage)")
                                            .font(.caption)
                                            .foregroundStyle(settingsVM.currentTheme.colors[0])
                                        Spacer()
                                        if item.isFavorite {
                                            Image(systemName: "star.fill")
                                                .foregroundStyle(.yellow)
                                                .font(.caption2)
                                        }
                                        Text(timestampText)
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.4))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.85)
                                    }

                                    Text(item.sourceText)
                                        .font(.subheadline)
                                        .foregroundStyle(.white)
                                        .lineLimit(2)

                                    Text(item.targetText)
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.7))
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(Color.white.opacity(0.05))
                            .swipeActions(edge: .leading) {
                                Button {
                                    settingsVM.toggleFavorite(for: item)
                                } label: {
                                    Label(item.isFavorite ? "取消收藏" : "收藏", systemImage: item.isFavorite ? "star.slash.fill" : "star.fill")
                                }
                                .tint(.yellow)
                            }
                        }
                        .onDelete { offsets in
                            // 如果在收藏过滤模式下删除，需要映射到真实索引
                            if filterMode == .all {
                                settingsVM.deleteHistory(at: offsets)
                            } else {
                                for offset in offsets {
                                    let item = filteredHistory[offset]
                                    if let idx = settingsVM.history.firstIndex(where: { $0.id == item.id }) {
                                        settingsVM.deleteHistory(at: IndexSet(integer: idx))
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .contentMargins(.top, 4, for: .scrollContent)
                }
            }
        }
        .navigationTitle("翻译历史")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !settingsVM.history.isEmpty {
                Button(role: .destructive) {
                    showingClearAlert = true
                } label: {
                    Text("清空")
                        .foregroundStyle(.red)
                }
            }
        }
        .alert("清空历史记录", isPresented: $showingClearAlert) {
            Button("取消", role: .cancel) { }
            Button("确定清空", role: .destructive) {
                withAnimation { settingsVM.clearHistory() }
            }
        } message: {
            Text("确定要清空所有的翻译历史记录吗？此操作不可恢复。")
        }
        .toolbar(.hidden, for: .tabBar) // 跳转隐藏底部 TabBar
    }
}

/// 历史记录详情页
struct HistoryDetailView: View {
    @Bindable var settingsVM: SettingsViewModel
    let item: TranslationHistoryItem

    @State private var copiedText: CopiedText?

    private enum CopiedText {
        case source
        case target
    }

    private var currentItem: TranslationHistoryItem {
        settingsVM.history.first(where: { $0.id == item.id }) ?? item
    }

    private var bg: Color { settingsVM.currentTheme.bg }

    private static let detailDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerView

                    detailTextSection(
                        title: "原文",
                        text: currentItem.sourceText,
                        copiedState: .source
                    )

                    detailTextSection(
                        title: "译文",
                        text: currentItem.targetText,
                        copiedState: .target
                    )
                }
                .padding(20)
            }
        }
        .navigationTitle("翻译详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        settingsVM.toggleFavorite(for: currentItem)
                    }
                } label: {
                    Image(systemName: currentItem.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(currentItem.isFavorite ? .yellow : .white.opacity(0.75))
                }

                ShareLink(item: currentItem.targetText) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private var headerView: some View {
        let timestampText = Self.detailDateFormatter.string(from: currentItem.timestamp)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(currentItem.sourceLanguage)
                Image(systemName: "arrow.right")
                    .font(.caption)
                Text(currentItem.targetLanguage)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(settingsVM.currentTheme.colors[0])

            Text(timestampText)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func detailTextSection(title: String, text: String, copiedState: CopiedText) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    copy(text, copiedState: copiedState)
                } label: {
                    Image(systemName: copiedText == copiedState ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(copiedText == copiedState ? settingsVM.currentTheme.colors[0] : .white.opacity(0.55))
                }
                .buttonStyle(.plain)
            }

            Text(text)
                .font(.body)
                .foregroundStyle(.white.opacity(0.82))
                .textSelection(.enabled)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func copy(_ text: String, copiedState: CopiedText) {
        UIPasteboard.general.string = text
        withAnimation(.spring(duration: 0.25)) {
            copiedText = copiedState
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                if copiedText == copiedState {
                    copiedText = nil
                }
            }
        }
    }
}

/// 偏好设置页
struct SettingsDetailView: View {
    @Bindable var settingsVM: SettingsViewModel
    private var bg: Color { settingsVM.currentTheme.bg }
    
    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            
            List {
                Section {
                    Picker("主题颜色", selection: $settingsVM.currentTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.menu)
                    .listRowBackground(Color.white.opacity(0.05))
                    .tint(settingsVM.currentTheme.colors[0])
                } header: {
                    Text("个性化")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("朗读语速")
                                .foregroundStyle(.white)
                            Spacer()
                            Text(String(format: "%.2f", settingsVM.speechRate))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        
                        Slider(value: $settingsVM.speechRate, in: 0.1...1.0)
                            .tint(settingsVM.currentTheme.colors[0])
                        
                        Text("调整翻译结果语音朗读的播放速度。")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.white.opacity(0.05))
                } header: {
                    Text("语音")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("偏好设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar) // 跳转隐藏底部 TabBar
    }
}

/// 纯文本展示页（用于协议、隐私政策、关于等）
struct TextDetailView: View {
    let title: String
    let content: String
    var bgColor: Color = Color(red: 0.07, green: 0.07, blue: 0.15)
    var logoName: String? = nil
    var contentFont: Font = .body
    
    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 18) {
                    if let logoName {
                        Image(logoName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 88, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: .black.opacity(0.22), radius: 12, x: 0, y: 6)
                            .padding(.top, 8)
                    }

                    Text(content)
                        .font(contentFont)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar) // 跳转隐藏底部 TabBar
    }
}

/// 反馈表单页
struct FeedbackView: View {
    @Bindable var settingsVM: SettingsViewModel

    @State private var feedbackText = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isSubmitting = false
    @State private var toastMessage: String?

    private var bg: Color { settingsVM.currentTheme.bg }
    private var canSubmit: Bool {
        !isSubmitting && !feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("反馈内容")
                            .font(.headline)
                            .foregroundStyle(.white)

                        TextEditor(text: $feedbackText)
                            .frame(minHeight: 180)
                            .scrollContentBackground(.hidden)
                            .padding(12)
                            .foregroundStyle(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.06))
                            )
                            .overlay(alignment: .topLeading) {
                                if feedbackText.isEmpty {
                                    Text("请描述你遇到的问题或想提出的建议")
                                        .font(.body)
                                        .foregroundStyle(.white.opacity(0.35))
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 20)
                                        .allowsHitTesting(false)
                                }
                            }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("上传图片")
                            .font(.headline)
                            .foregroundStyle(.white)

                        if let selectedImage {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                Button {
                                    self.selectedImage = nil
                                    selectedPhotoItem = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.white, .black.opacity(0.55))
                                        .padding(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label(selectedImage == nil ? "选择图片" : "更换图片", systemImage: "photo")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundStyle(.white)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(settingsVM.currentTheme.colors[0].opacity(0.75))
                                )
                        }
                    }

                    Button {
                        submitFeedback()
                    } label: {
                        HStack(spacing: 8) {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.85)
                            }

                            Text(isSubmitting ? "提交中..." : "提交")
                                .font(.body.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(canSubmit ? settingsVM.currentTheme.colors[0] : Color.white.opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSubmit)
                }
                .padding(20)
            }

            if let toastMessage {
                VStack {
                    Spacer()

                    Text(toastMessage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.78))
                        )
                        .padding(.bottom, 28)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .padding(.horizontal, 20)
                .allowsHitTesting(false)
            }
        }
        .navigationTitle("反馈与联系我们")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task(id: selectedPhotoItem) {
            await loadSelectedImage()
        }
    }

    private func loadSelectedImage() async {
        guard let selectedPhotoItem else { return }
        guard let data = try? await selectedPhotoItem.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return
        }
        selectedImage = image
    }

    private func submitFeedback() {
        guard canSubmit else { return }

        isSubmitting = true

        Task {
            await submitFeedbackRequest()

            await MainActor.run {
                isSubmitting = false
                feedbackText = ""
                selectedImage = nil
                selectedPhotoItem = nil
                showToast("反馈已提交，感谢你的建议")
            }
        }
    }

    private func submitFeedbackRequest() async {
        // 后续接入网络请求时，把接口调用替换到这里。
        try? await Task.sleep(for: .seconds(2))
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(duration: 0.25)) {
            toastMessage = message
        }

        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    toastMessage = nil
                }
            }
        }
    }
}
