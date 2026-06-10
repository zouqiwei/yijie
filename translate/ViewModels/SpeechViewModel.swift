//
//  SpeechViewModel.swift
//  translate
//

import Foundation
import Speech
import AVFoundation
import SwiftUI

/// 管理语音录入与实时识别
@Observable
class SpeechViewModel {
    var isRecording: Bool = false
    var recognizedText: String = ""
    var audioLevel: Float = 0.0
    var errorMessage: String?
    var speechAuthStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    var microphoneAuthorized: Bool = false

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    /// 是否可以开始录音（双权限均已授权）
    var canRecord: Bool {
        speechAuthStatus == .authorized && microphoneAuthorized
    }

    // MARK: - 权限

    /// 仅查询当前权限状态，不弹出系统对话框
    func checkPermissionStatus() {
        speechAuthStatus = SFSpeechRecognizer.authorizationStatus()
        if #available(iOS 17.0, *) {
            microphoneAuthorized = AVAudioApplication.shared.recordPermission == .granted
        } else {
            microphoneAuthorized = AVAudioSession.sharedInstance().recordPermission == .granted
        }
    }

    /// 请求麦克风 + 语音识别权限（内部按需调用）
    private func requestPermissions() async {
        // 1. 语音识别权限
        let status = await withCheckedContinuation {
            (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { s in
                cont.resume(returning: s)
            }
        }
        speechAuthStatus = status

        // 2. 麦克风权限
        if #available(iOS 17.0, *) {
            microphoneAuthorized = await AVAudioApplication.requestRecordPermission()
        } else {
            microphoneAuthorized = await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        }
    }

    // MARK: - 录音控制

    /// 启动录音。
    /// async 设计：若权限尚未授权，会先弹出系统权限对话框，用户确认后再开始录音。
    func startRecording(localeIdentifier: String) async {
        errorMessage = nil

        // 权限未确定时先请求
        if speechAuthStatus == .notDetermined || !microphoneAuthorized {
            await requestPermissions()
        }

        // 权限仍未满足则给出提示并退出
        guard canRecord else {
            switch (speechAuthStatus, microphoneAuthorized) {
            case (.denied, _), (.restricted, _):
                errorMessage = "请前往「设置 - 隐私与安全性 - 语音识别」开启权限"
            case (_, false):
                errorMessage = "请前往「设置 - 隐私与安全性 - 麦克风」开启权限"
            default:
                errorMessage = "无法获取录音权限，请重试"
            }
            return
        }

        // 停止上一次录音（如有）
        stopCurrentRecording()

        // 配置音频会话
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "音频会话启动失败：\(error.localizedDescription)"
            return
        }

        // 创建识别器
        let recognizer: SFSpeechRecognizer
        if let r = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)), r.isAvailable {
            recognizer = r
        } else if let fallback = SFSpeechRecognizer() {
            recognizer = fallback
        } else {
            errorMessage = "当前语言不支持语音识别"
            return
        }
        speechRecognizer = recognizer

        // 创建识别请求
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        // 安装音频 tap（直接捕获 request，避免跨 actor 访问 self）
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)

            guard let data = buffer.floatChannelData?[0] else { return }
            let count = Int(buffer.frameLength)
            guard count > 0 else { return }

            var sumSq: Float = 0
            for i in 0..<count { sumSq += data[i] * data[i] }
            let rms = sqrt(sumSq / Float(count))
            let level = min(rms * 20, 1.0)

            Task { @MainActor [weak self] in
                self?.audioLevel = level
            }
        }

        // 启动识别任务
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString ?? ""
            let isFinal = result?.isFinal ?? false
            let hasError = error != nil

            Task { @MainActor [weak self] in
                guard let self else { return }
                if !text.isEmpty { self.recognizedText = text }
                if isFinal || hasError { self.stopRecording() }
            }
        }

        // 启动引擎
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            recognizedText = ""
        } catch {
            errorMessage = "录音引擎启动失败：\(error.localizedDescription)"
            stopCurrentRecording()
        }
    }

    func stopRecording() {
        recognitionRequest?.endAudio()
        stopCurrentRecording()
    }

    private func stopCurrentRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
        audioLevel = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func clear() {
        recognizedText = ""
        errorMessage = nil
    }
}
