# 译介 (Translate App)

译介App是一款面向日常沟通、学习阅读和出行场景的多方式翻译工具。我们希望它既能快速完成一句话的翻译，也能在更复杂的交流场景中保持清晰、顺手和可靠。

## 🌟 核心功能

*   **💬 文字翻译**：输入文本后快速获取译文，适合聊天、邮件、笔记和资料阅读。
*   **🎙️ 语音翻译**：通过语音输入完成翻译，减少打字成本，适合面对面沟通。
*   **📷 图片文字识别 (OCR)**：从图片中提取文字并翻译，方便处理菜单、标识、截图和纸质资料。
*   **🗣️ 对话翻译**：支持双向对话场景，让跨语言交流更自然。
*   **🕒 翻译历史与收藏**：自动保存常用翻译记录，支持查看详情、复制、分享，并且可以一键添加到“收藏夹”以便日后复习。
*   **🎨 个性化设置**：可自定义主题颜色，以及调整语音朗读的播放语速，让使用体验更贴合个人习惯。

## 🛠️ 技术栈

*   **平台**: iOS 16.0+ (请根据实际 Target 调整)
*   **框架**: SwiftUI
*   **架构**: MVVM (Model-View-ViewModel)
*   **核心模块**:
    *   `Speech` / `AVFoundation`: 语音识别与文字转语音合成
    *   `Vision`: 图像文字提取 (OCR)
    *   `PhotosUI`: 本地相册图片选取

## 📂 项目结构说明

*   `translate/Views/`: 包含所有的 SwiftUI 视图组件 (如 `HomeView`, `ConversationView`, `ProfileView`, `ImageInputView` 等)。
*   `translate/ViewModels/`: 包含业务逻辑处理模块 (如 `TranslationViewModel`, `SettingsViewModel`, `ImageOCRViewModel` 等)。
*   `translate/Models/`: 包含底层数据模型 (如 `TranslationHistoryItem`, `AppTheme` 等)。
*   `docs/`: 用于存放供 App Store 审核及对外展示的静态网页资源，如隐私政策网页。

## 🚀 运行项目

1. 确保 Mac 上安装了较新版本的 **Xcode**。
2. 下载或克隆本项目到本地。
3. 双击 `translate.xcodeproj` 打开工程。
4. 在 Xcode 顶部设备列表中选择一个模拟器（如 iPhone 15 Pro）或连接你的真机设备。
5. 点击 `Run` 按钮 (或快捷键 `Cmd + R`) 编译并运行项目。

> **注意**：部分依赖硬件传感器和系统授权的功能（如相机拍照、麦克风录音、系统级语音识别）在模拟器上可能无法正常工作或表现受限，推荐使用 **iOS 真机** 进行调试和完整体验测试。

## 🔒 隐私与合规

为了提供完整的体验，App 会在用户首次使用对应功能时请求以下系统权限：
*   **相机权限** (`NSCameraUsageDescription`): 用于拍照并识别图片中的文字。
*   **麦克风权限** (`NSMicrophoneUsageDescription`): 用于录制语音。
*   **相册权限** (`NSPhotoLibraryUsageDescription`): 用于选取本地相册图片。
*   **语音识别权限** (`NSSpeechRecognitionUsageDescription`): 用于将系统捕获的语音实时转化为文本。

*应用非常重视用户隐私保护，所有数据本地优先，权限仅限所需。详情请查阅项目中的[隐私政策](docs/privacy.html)。*

## 📬 反馈与联系

如有任何问题、Bug 反馈或新功能建议，欢迎通过应用内的“反馈与联系我们”页面提交，或直接发送邮件至：`dexunkklxc@163.com`。
