//
//  ConversationViewModel.swift
//  translate
//

import SwiftUI
import AVFoundation

enum ActiveSpeaker {
    case none
    case top
    case bottom
}

@Observable
class ConversationViewModel {
    // 语言设置
    var topLanguage: LanguageOption
    var bottomLanguage: LanguageOption
    
    // 识别与翻译结果
    var topRecognizedText: String = ""
    var bottomRecognizedText: String = ""
    
    var topTranslatedText: String = ""
    var bottomTranslatedText: String = ""
    
    // 状态
    var activeSpeaker: ActiveSpeaker = .none
    var isTranslating: Bool = false
    var errorMessage: String?
    
    // 录音与朗读
    let speechVM = SpeechViewModel()
    private let synthesizer = AVSpeechSynthesizer()
    var speechRate: Float = 0.48
    
    init(topLanguage: LanguageOption, bottomLanguage: LanguageOption) {
        self.topLanguage = topLanguage
        self.bottomLanguage = bottomLanguage
    }
    
    // MARK: - 录音控制
    
    func toggleRecording(for speaker: ActiveSpeaker) {
        // 如果正在朗读，则打断朗读
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        if activeSpeaker == speaker {
            // 停止录音
            stopRecording()
        } else {
            // 开始新的录音
            startRecording(for: speaker)
        }
    }
    
    private func startRecording(for speaker: ActiveSpeaker) {
        stopRecording()
        
        activeSpeaker = speaker
        let locale = speaker == .top ? topLanguage.speechRecognitionLocaleIdentifier : bottomLanguage.speechRecognitionLocaleIdentifier
        
        // 清理旧内容
        if speaker == .top {
            topRecognizedText = ""
            bottomTranslatedText = ""
        } else {
            bottomRecognizedText = ""
            topTranslatedText = ""
        }
        
        Task {
            await speechVM.startRecording(localeIdentifier: locale)
        }
    }
    
    func stopRecording() {
        if activeSpeaker != .none {
            speechVM.stopRecording()
            // 将识别到的文本存下来，等待触发翻译
            let finalRecognized = speechVM.recognizedText
            if activeSpeaker == .top {
                topRecognizedText = finalRecognized
            } else if activeSpeaker == .bottom {
                bottomRecognizedText = finalRecognized
            }
            activeSpeaker = .none
        }
    }
    
    // MARK: - 语音朗读 (TTS)
    
    func speak(text: String, in language: LanguageOption) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language.speechLocaleIdentifier)
        utterance.rate = speechRate
        utterance.pitchMultiplier = 1.0
        
        // 使用 AVAudioSession 确保播放声音正常（避免录音模式导致声音太小）
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .default, options: .duckOthers)
        try? audioSession.setActive(true)
        
        synthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
