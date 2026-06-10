//
//  TranslationViewModel.swift
//  translate
//

import SwiftUI
import Translation

/// 管理翻译的核心数据（语言选择、输入/输出文本）
@Observable
class TranslationViewModel {
    var inputText: String = ""
    var translatedText: String = ""
    var isTranslating: Bool = false
    var errorMessage: String?

    var sourceLanguage: LanguageOption = .defaultSource
    var targetLanguage: LanguageOption = .defaultTarget

    /// 交换源语言和目标语言，同时交换文本
    func swapLanguages() {
        let tmpLang = sourceLanguage
        sourceLanguage = targetLanguage
        targetLanguage = tmpLang

        let tmpText = inputText
        inputText = translatedText
        translatedText = tmpText
    }

    /// 清空所有内容
    func clear() {
        inputText = ""
        translatedText = ""
        errorMessage = nil
    }
}
