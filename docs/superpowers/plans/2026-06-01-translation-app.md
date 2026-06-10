# Translation App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first SwiftUI version of the translation app with manual input, eight-language selection, speech-to-text, photo/camera OCR, and a replaceable mock translation service.

**Architecture:** Use a single SwiftUI workspace screen backed by `TranslationViewModel`. Keep translation, speech recognition, OCR, and image picking behind small focused types so system integrations can be tested or replaced without rewriting the screen.

**Tech Stack:** SwiftUI, Observation, Speech, AVFoundation, Vision, PhotosUI, UIKit bridge for camera, XCTest, Xcode project file settings.

---

## File Structure

- Modify: `translate/ContentView.swift` - replace starter content with the translation workspace UI.
- Create: `translate/TranslationLanguage.swift` - supported language enum and framework language codes.
- Create: `translate/TranslationService.swift` - translation protocol and mock implementation.
- Create: `translate/TranslationViewModel.swift` - main state and app actions.
- Create: `translate/SpeechRecognizer.swift` - Speech and microphone capture wrapper.
- Create: `translate/TextRecognizer.swift` - Vision OCR wrapper.
- Create: `translate/ImagePicker.swift` - camera bridge for SwiftUI.
- Modify: `translate.xcodeproj/project.pbxproj` - add generated Info.plist permission strings and an XCTest target.
- Create: `translateTests/TranslationViewModelTests.swift` - ViewModel and mock-service coverage.

## Task 1: Add Language And Translation Core

**Files:**
- Create: `translate/TranslationLanguage.swift`
- Create: `translate/TranslationService.swift`
- Create: `translate/TranslationViewModel.swift`
- Create: `translateTests/TranslationViewModelTests.swift`
- Modify: `translate.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add an XCTest target to the project**

Edit `translate.xcodeproj/project.pbxproj` to add a `translateTests` unit test target that depends on the `translate` app target and has `TEST_HOST = "$(BUILT_PRODUCTS_DIR)/translate.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/translate";`, `BUNDLE_LOADER = "$(TEST_HOST)";`, `PRODUCT_BUNDLE_IDENTIFIER = dexun.translateTests;`, and `GENERATE_INFOPLIST_FILE = YES;`.

After editing, run:

```bash
xcodebuild -list -project translate.xcodeproj
```

Expected: output includes schemes or targets for both `translate` and `translateTests`.

- [ ] **Step 2: Write failing tests for language defaults, swap, empty input, and mock translation**

Create `translateTests/TranslationViewModelTests.swift`:

```swift
import XCTest
@testable import translate

@MainActor
final class TranslationViewModelTests: XCTestCase {
    func testInitialStateUsesChineseToEnglish() {
        let viewModel = TranslationViewModel(translationService: MockTranslationService())

        XCTAssertEqual(viewModel.sourceLanguage, .chinese)
        XCTAssertEqual(viewModel.targetLanguage, .english)
        XCTAssertEqual(viewModel.inputText, "")
        XCTAssertEqual(viewModel.translatedText, "")
        XCTAssertFalse(viewModel.isTranslating)
    }

    func testSwapLanguagesAlsoSwapsTextsWhenResultExists() {
        let viewModel = TranslationViewModel(translationService: MockTranslationService())
        viewModel.inputText = "你好"
        viewModel.translatedText = "Hello"

        viewModel.swapLanguages()

        XCTAssertEqual(viewModel.sourceLanguage, .english)
        XCTAssertEqual(viewModel.targetLanguage, .chinese)
        XCTAssertEqual(viewModel.inputText, "Hello")
        XCTAssertEqual(viewModel.translatedText, "你好")
    }

    func testTranslateRejectsEmptyInput() async {
        let viewModel = TranslationViewModel(translationService: MockTranslationService())
        viewModel.inputText = "   "

        await viewModel.translate()

        XCTAssertEqual(viewModel.translatedText, "")
        XCTAssertEqual(viewModel.alertMessage, "请输入需要翻译的文本")
        XCTAssertFalse(viewModel.isTranslating)
    }

    func testTranslateUsesMockService() async {
        let viewModel = TranslationViewModel(translationService: MockTranslationService())
        viewModel.inputText = "你好"

        await viewModel.translate()

        XCTAssertEqual(viewModel.translatedText, "[英文] 你好")
        XCTAssertNil(viewModel.alertMessage)
        XCTAssertFalse(viewModel.isTranslating)
    }
}
```

- [ ] **Step 3: Run tests to verify they fail because app types do not exist**

Run:

```bash
xcodebuild test -project translate.xcodeproj -scheme translate -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: FAIL with compiler errors for missing `TranslationViewModel`, `MockTranslationService`, or `TranslationLanguage`.

- [ ] **Step 4: Add supported languages**

Create `translate/TranslationLanguage.swift`:

```swift
import Foundation

enum TranslationLanguage: String, CaseIterable, Identifiable, Equatable {
    case chinese
    case english
    case japanese
    case korean
    case french
    case german
    case spanish
    case russian

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chinese: "中文"
        case .english: "英文"
        case .japanese: "日文"
        case .korean: "韩文"
        case .french: "法文"
        case .german: "德文"
        case .spanish: "西班牙文"
        case .russian: "俄文"
        }
    }

    var speechLocaleIdentifier: String {
        switch self {
        case .chinese: "zh-CN"
        case .english: "en-US"
        case .japanese: "ja-JP"
        case .korean: "ko-KR"
        case .french: "fr-FR"
        case .german: "de-DE"
        case .spanish: "es-ES"
        case .russian: "ru-RU"
        }
    }

    var recognitionLanguages: [String] {
        switch self {
        case .chinese: ["zh-Hans", "zh-Hant"]
        case .english: ["en-US"]
        case .japanese: ["ja-JP"]
        case .korean: ["ko-KR"]
        case .french: ["fr-FR"]
        case .german: ["de-DE"]
        case .spanish: ["es-ES"]
        case .russian: ["ru-RU"]
        }
    }
}
```

- [ ] **Step 5: Add translation service protocol and mock**

Create `translate/TranslationService.swift`:

```swift
import Foundation

protocol TranslationService {
    func translate(_ text: String, from source: TranslationLanguage, to target: TranslationLanguage) async throws -> String
}

struct MockTranslationService: TranslationService {
    func translate(_ text: String, from source: TranslationLanguage, to target: TranslationLanguage) async throws -> String {
        "[\(target.displayName)] \(text)"
    }
}
```

- [ ] **Step 6: Add the first ViewModel implementation**

Create `translate/TranslationViewModel.swift`:

```swift
import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class TranslationViewModel {
    var sourceLanguage: TranslationLanguage = .chinese
    var targetLanguage: TranslationLanguage = .english
    var inputText = ""
    var translatedText = ""
    var isTranslating = false
    var isRecognizingSpeech = false
    var isRecognizingImage = false
    var alertMessage: String?
    var selectedCameraImage: UIImage?

    private let translationService: TranslationService

    init(translationService: TranslationService = MockTranslationService()) {
        self.translationService = translationService
    }

    func swapLanguages() {
        swap(&sourceLanguage, &targetLanguage)

        if !translatedText.isEmpty {
            swap(&inputText, &translatedText)
        }
    }

    func translate() async {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            alertMessage = "请输入需要翻译的文本"
            return
        }

        isTranslating = true
        alertMessage = nil
        defer { isTranslating = false }

        do {
            translatedText = try await translationService.translate(trimmedText, from: sourceLanguage, to: targetLanguage)
        } catch {
            alertMessage = "翻译失败，请稍后重试"
        }
    }
}
```

- [ ] **Step 7: Run tests and commit**

Run:

```bash
xcodebuild test -project translate.xcodeproj -scheme translate -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: PASS for all tests in `TranslationViewModelTests`.

Commit:

```bash
git add translate/TranslationLanguage.swift translate/TranslationService.swift translate/TranslationViewModel.swift translateTests/TranslationViewModelTests.swift translate.xcodeproj/project.pbxproj
git commit -m "Add translation core state"
```

## Task 2: Add OCR Service And ViewModel Image Handling

**Files:**
- Create: `translate/TextRecognizer.swift`
- Modify: `translate/TranslationViewModel.swift`
- Modify: `translateTests/TranslationViewModelTests.swift`

- [ ] **Step 1: Extend tests for OCR success and empty OCR result**

Append these tests to `TranslationViewModelTests`:

```swift
func testRecognizedImageTextFillsInput() {
    let viewModel = TranslationViewModel(translationService: MockTranslationService())

    viewModel.applyRecognizedImageText(" Bonjour ")

    XCTAssertEqual(viewModel.inputText, "Bonjour")
    XCTAssertNil(viewModel.alertMessage)
}

func testEmptyRecognizedImageTextShowsError() {
    let viewModel = TranslationViewModel(translationService: MockTranslationService())

    viewModel.applyRecognizedImageText("   ")

    XCTAssertEqual(viewModel.inputText, "")
    XCTAssertEqual(viewModel.alertMessage, "没有识别到文字")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild test -project translate.xcodeproj -scheme translate -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: FAIL because `applyRecognizedImageText` does not exist.

- [ ] **Step 3: Add Vision OCR wrapper**

Create `translate/TextRecognizer.swift`:

```swift
import UIKit
import Vision

enum TextRecognizerError: Error {
    case invalidImage
    case noTextFound
}

struct TextRecognizer {
    func recognizeText(in image: UIImage, languages: [String]) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw TextRecognizerError.invalidImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = languages

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        let recognizedText = request.results?
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !recognizedText.isEmpty else {
            throw TextRecognizerError.noTextFound
        }

        return recognizedText
    }
}
```

- [ ] **Step 4: Add ViewModel OCR methods**

Update `TranslationViewModel.swift` by adding a stored recognizer and these methods:

```swift
private let textRecognizer = TextRecognizer()

func applyRecognizedImageText(_ text: String) {
    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedText.isEmpty else {
        alertMessage = "没有识别到文字"
        return
    }

    inputText = trimmedText
    translatedText = ""
    alertMessage = nil
}

func recognizeText(in image: UIImage) async {
    isRecognizingImage = true
    alertMessage = nil
    defer { isRecognizingImage = false }

    do {
        let text = try await textRecognizer.recognizeText(in: image, languages: sourceLanguage.recognitionLanguages)
        applyRecognizedImageText(text)
    } catch {
        alertMessage = "没有识别到文字"
    }
}
```

- [ ] **Step 5: Run tests and commit**

Run:

```bash
xcodebuild test -project translate.xcodeproj -scheme translate -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: PASS.

Commit:

```bash
git add translate/TextRecognizer.swift translate/TranslationViewModel.swift translateTests/TranslationViewModelTests.swift
git commit -m "Add image text recognition state"
```

## Task 3: Add Speech Recognition Wrapper

**Files:**
- Create: `translate/SpeechRecognizer.swift`
- Modify: `translate/TranslationViewModel.swift`
- Modify: `translateTests/TranslationViewModelTests.swift`

- [ ] **Step 1: Add tests for applying speech text**

Append these tests to `TranslationViewModelTests`:

```swift
func testRecognizedSpeechTextFillsInput() {
    let viewModel = TranslationViewModel(translationService: MockTranslationService())

    viewModel.applyRecognizedSpeechText(" Hello ")

    XCTAssertEqual(viewModel.inputText, "Hello")
    XCTAssertNil(viewModel.alertMessage)
}

func testEmptyRecognizedSpeechTextShowsError() {
    let viewModel = TranslationViewModel(translationService: MockTranslationService())

    viewModel.applyRecognizedSpeechText("   ")

    XCTAssertEqual(viewModel.alertMessage, "没有识别到语音内容")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild test -project translate.xcodeproj -scheme translate -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: FAIL because `applyRecognizedSpeechText` does not exist.

- [ ] **Step 3: Add Speech framework wrapper**

Create `translate/SpeechRecognizer.swift`:

```swift
import AVFoundation
import Foundation
import Speech

enum SpeechRecognizerError: Error {
    case permissionDenied
    case recognizerUnavailable
    case requestCreationFailed
    case noSpeechRecognized
}

final class SpeechRecognizer: NSObject {
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func recognizeOnce(localeIdentifier: String) async throws -> String {
        let speechGranted = await requestSpeechPermission()
        guard speechGranted else { throw SpeechRecognizerError.permissionDenied }

        let microphoneGranted = await requestMicrophonePermission()
        guard microphoneGranted else { throw SpeechRecognizerError.permissionDenied }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)), recognizer.isAvailable else {
            throw SpeechRecognizerError.recognizerUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            do {
                try startRecognition(with: recognizer) { result in
                    continuation.resume(with: result)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }

    private func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func startRecognition(
        with recognizer: SFSpeechRecognizer,
        completion: @escaping (Result<String, Error>) -> Void
    ) throws {
        stop()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = false
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let error {
                self?.stop()
                completion(.failure(error))
                return
            }

            guard let result, result.isFinal else {
                return
            }

            self?.stop()
            let text = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty {
                completion(.failure(SpeechRecognizerError.noSpeechRecognized))
            } else {
                completion(.success(text))
            }
        }
    }
}
```

- [ ] **Step 4: Add ViewModel speech methods**

Update `TranslationViewModel.swift` with a recognizer property and these methods:

```swift
private let speechRecognizer = SpeechRecognizer()

func applyRecognizedSpeechText(_ text: String) {
    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedText.isEmpty else {
        alertMessage = "没有识别到语音内容"
        return
    }

    inputText = trimmedText
    translatedText = ""
    alertMessage = nil
}

func recognizeSpeech() async {
    isRecognizingSpeech = true
    alertMessage = nil
    defer { isRecognizingSpeech = false }

    do {
        let text = try await speechRecognizer.recognizeOnce(localeIdentifier: sourceLanguage.speechLocaleIdentifier)
        applyRecognizedSpeechText(text)
    } catch {
        alertMessage = "语音识别失败，请检查权限后重试"
    }
}
```

- [ ] **Step 5: Run tests and commit**

Run:

```bash
xcodebuild test -project translate.xcodeproj -scheme translate -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: PASS.

Commit:

```bash
git add translate/SpeechRecognizer.swift translate/TranslationViewModel.swift translateTests/TranslationViewModelTests.swift
git commit -m "Add speech recognition state"
```

## Task 4: Build Camera Picker And Permission Strings

**Files:**
- Create: `translate/ImagePicker.swift`
- Modify: `translate.xcodeproj/project.pbxproj`
- Modify: `translate/TranslationViewModel.swift`

- [ ] **Step 1: Add generated Info.plist permission strings**

In both Debug and Release app target build configurations inside `translate.xcodeproj/project.pbxproj`, add:

```text
INFOPLIST_KEY_NSCameraUsageDescription = "用于拍摄包含文字的图片并识别文字";
INFOPLIST_KEY_NSMicrophoneUsageDescription = "用于录入语音并转换为文本";
INFOPLIST_KEY_NSSpeechRecognitionUsageDescription = "用于将语音内容识别为文本";
INFOPLIST_KEY_NSPhotoLibraryUsageDescription = "用于选择包含文字的图片并识别文字";
```

Run:

```bash
xcodebuild build -project translate.xcodeproj -scheme translate -destination 'generic/platform=iOS Simulator'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 2: Add camera picker bridge**

Create `translate/ImagePicker.swift`:

```swift
import SwiftUI
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    enum Source {
        case camera
    }

    let source: Source
    let onImagePicked: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onImagePicked: (UIImage) -> Void
        private let onCancel: () -> Void

        init(onImagePicked: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImagePicked = onImagePicked
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
```

- [ ] **Step 3: Add camera availability helper**

Add this method to `TranslationViewModel.swift`:

```swift
func canUseCamera() -> Bool {
    UIImagePickerController.isSourceTypeAvailable(.camera)
}
```

- [ ] **Step 4: Build and commit**

Run:

```bash
xcodebuild build -project translate.xcodeproj -scheme translate -destination 'generic/platform=iOS Simulator'
```

Expected: BUILD SUCCEEDED.

Commit:

```bash
git add translate/ImagePicker.swift translate/TranslationViewModel.swift translate.xcodeproj/project.pbxproj
git commit -m "Add image capture permissions"
```

## Task 5: Replace Starter Screen With Translation Workspace

**Files:**
- Modify: `translate/ContentView.swift`

- [ ] **Step 1: Replace ContentView with full workspace UI**

Replace `translate/ContentView.swift` with:

```swift
import PhotosUI
import SwiftUI

struct ContentView: View {
    @State private var viewModel = TranslationViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var isShowingAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    languageSelector
                    inputEditor
                    actionRow
                    translateButton
                    resultView
                }
                .padding()
            }
            .navigationTitle("翻译")
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task { await loadPhoto(from: newItem) }
            }
            .onChange(of: viewModel.alertMessage) { _, message in
                isShowingAlert = message != nil
            }
            .alert("提示", isPresented: $isShowingAlert) {
                Button("知道了") {
                    viewModel.alertMessage = nil
                }
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
            .sheet(isPresented: $isShowingCamera) {
                ImagePicker(source: .camera) { image in
                    isShowingCamera = false
                    Task { await viewModel.recognizeText(in: image) }
                } onCancel: {
                    isShowingCamera = false
                }
            }
        }
    }

    private var languageSelector: some View {
        HStack(spacing: 12) {
            languageMenu(title: "源语言", selection: $viewModel.sourceLanguage)

            Button {
                viewModel.swapLanguages()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.headline)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("交换语言")

            languageMenu(title: "目标语言", selection: $viewModel.targetLanguage)
        }
    }

    private func languageMenu(title: String, selection: Bindable<TranslationViewModel>.Binding<TranslationLanguage>) -> some View {
        Picker(title, selection: selection) {
            ForEach(TranslationLanguage.allCases) { language in
                Text(language.displayName).tag(language)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var inputEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("输入文本")
                .font(.headline)

            TextEditor(text: $viewModel.inputText)
                .frame(minHeight: 150)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.quaternary, lineWidth: 1)
                )
        }
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                Task { await viewModel.recognizeSpeech() }
            } label: {
                Label(viewModel.isRecognizingSpeech ? "识别中" : "语音", systemImage: "mic.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isRecognizingSpeech)

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label(viewModel.isRecognizingImage ? "识别中" : "相册", systemImage: "photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isRecognizingImage)

            Button {
                if viewModel.canUseCamera() {
                    isShowingCamera = true
                } else {
                    viewModel.alertMessage = "当前设备不可用相机"
                }
            } label: {
                Label("相机", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var translateButton: some View {
        Button {
            Task { await viewModel.translate() }
        } label: {
            HStack {
                if viewModel.isTranslating {
                    ProgressView()
                }
                Text(viewModel.isTranslating ? "翻译中" : "翻译")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isTranslating)
    }

    private var resultView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("翻译结果")
                .font(.headline)

            Text(viewModel.translatedText.isEmpty ? "结果会显示在这里" : viewModel.translatedText)
                .foregroundStyle(viewModel.translatedText.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func loadPhoto(from item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await viewModel.recognizeText(in: image)
            } else {
                viewModel.alertMessage = "无法读取图片"
            }
        } catch {
            viewModel.alertMessage = "无法读取图片"
        }

        selectedPhotoItem = nil
    }
}

#Preview {
    ContentView()
}
```

- [ ] **Step 2: Build and fix compile-only issues**

Run:

```bash
xcodebuild build -project translate.xcodeproj -scheme translate -destination 'generic/platform=iOS Simulator'
```

Expected: BUILD SUCCEEDED. If SwiftUI binding syntax fails for the helper picker, inline the two `Picker` controls in `languageSelector` using `$viewModel.sourceLanguage` and `$viewModel.targetLanguage`.

- [ ] **Step 3: Commit**

```bash
git add translate/ContentView.swift
git commit -m "Build translation workspace UI"
```

## Task 6: Final Verification

**Files:**
- Read: all changed files

- [ ] **Step 1: Run unit tests**

Run:

```bash
xcodebuild test -project translate.xcodeproj -scheme translate -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: PASS.

- [ ] **Step 2: Run a simulator build**

Run:

```bash
xcodebuild build -project translate.xcodeproj -scheme translate -destination 'generic/platform=iOS Simulator'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Manual verification checklist**

Run the app in Xcode or install to a simulator/device and verify:

- The app opens to the translation workspace.
- Source and target language menus show eight languages.
- Swap changes Chinese-English to English-Chinese.
- Empty translate shows `请输入需要翻译的文本`.
- Typing `你好` and tapping translate shows `[英文] 你好`.
- Photo picker opens and returns to the app on cancel.
- On a real device, camera opens from the camera button.
- On a real device, microphone permission appears and denied permission shows a useful alert.

- [ ] **Step 4: Check git status**

Run:

```bash
git status --short
```

Expected: no uncommitted files except simulator or local user files that are intentionally ignored.
