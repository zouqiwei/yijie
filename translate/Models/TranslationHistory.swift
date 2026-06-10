//
//  TranslationHistory.swift
//  translate
//

import Foundation

/// 单条翻译历史记录
struct TranslationHistoryItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    let sourceText: String
    let targetText: String
    let sourceLanguage: String
    let targetLanguage: String
    let timestamp: Date
    var isFavorite: Bool = false
    
    // 自定义解码以兼容旧版数据
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        sourceText = try container.decode(String.self, forKey: .sourceText)
        targetText = try container.decode(String.self, forKey: .targetText)
        sourceLanguage = try container.decode(String.self, forKey: .sourceLanguage)
        targetLanguage = try container.decode(String.self, forKey: .targetLanguage)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }
    
    // 默认初始化
    init(id: UUID = UUID(), sourceText: String, targetText: String, sourceLanguage: String, targetLanguage: String, timestamp: Date, isFavorite: Bool = false) {
        self.id = id
        self.sourceText = sourceText
        self.targetText = targetText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.timestamp = timestamp
        self.isFavorite = isFavorite
    }
}
