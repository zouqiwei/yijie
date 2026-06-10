//
//  SettingsViewModel.swift
//  translate
//

import SwiftUI

/// 颜色主题枚举（主要控制 App 背景色）
enum AppTheme: String, CaseIterable, Identifiable {
    case classic  = "深邃星空"   // 原默认深蓝紫
    case forest   = "暗夜森林"   // 深墨绿
    case ocean    = "深海蓝湾"   // 深海蓝
    case obsidian = "黑曜石黑"   // 深灰黑
    case wine     = "午夜酒红"   // 暗酒红
    
    var id: String { rawValue }
    
    /// 页面主背景色
    var bg: Color {
        switch self {
        case .classic:  return Color(red: 0.07, green: 0.07, blue: 0.15)
        case .forest:   return Color(red: 0.05, green: 0.12, blue: 0.08)
        case .ocean:    return Color(red: 0.04, green: 0.09, blue: 0.18)
        case .obsidian: return Color(red: 0.08, green: 0.08, blue: 0.09)
        case .wine:     return Color(red: 0.14, green: 0.05, blue: 0.08)
        }
    }
    
    /// 顶部 header 渐变起始色（稍亮于背景）
    var headerGradientTop: Color {
        switch self {
        case .classic:  return Color(red: 0.18, green: 0.14, blue: 0.42)
        case .forest:   return Color(red: 0.08, green: 0.26, blue: 0.14)
        case .ocean:    return Color(red: 0.06, green: 0.18, blue: 0.38)
        case .obsidian: return Color(red: 0.16, green: 0.16, blue: 0.18)
        case .wine:     return Color(red: 0.30, green: 0.08, blue: 0.14)
        }
    }
    
    /// 主强调色（按钮、图标等），跟随主题色变化
    var colors: [Color] {
        switch self {
        case .classic:  return [Color(red: 0.39, green: 0.40, blue: 0.96), Color(red: 0.72, green: 0.33, blue: 0.96)]
        case .forest:   return [Color(red: 0.18, green: 0.55, blue: 0.34), Color(red: 0.28, green: 0.75, blue: 0.44)]
        case .ocean:    return [Color(red: 0.16, green: 0.50, blue: 0.95), Color(red: 0.26, green: 0.70, blue: 0.98)]
        case .obsidian: return [Color(red: 0.45, green: 0.45, blue: 0.50), Color(red: 0.65, green: 0.65, blue: 0.70)]
        case .wine:     return [Color(red: 0.75, green: 0.25, blue: 0.35), Color(red: 0.95, green: 0.35, blue: 0.45)]
        }
    }
}

/// 管理翻译历史记录、语速设置、清空缓存等
@Observable
class SettingsViewModel {
    
    // 主题设置
    var currentTheme: AppTheme = .classic {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "appTheme")
        }
    }
    
    // 语速设置（范围 0.1 到 1.0），使用存储属性让 @Observable 正常追踪，同时保存到 UserDefaults
    var speechRate: Double = 0.48 {
        didSet {
            UserDefaults.standard.set(speechRate, forKey: "speechRate")
        }
    }
    
    // 历史记录
    var history: [TranslationHistoryItem] = []
    
    private let historyKey = "TranslationHistory"
    
    init() {
        loadHistory()
        
        // 初始化语速
        let storedRate = UserDefaults.standard.double(forKey: "speechRate")
        if storedRate != 0.0 {
            self.speechRate = storedRate
        } else {
            UserDefaults.standard.set(0.48, forKey: "speechRate")
        }
        
        // 初始化主题（如果读出旧 rawValue 无法匹配则默认回 classic）
        if let themeStr = UserDefaults.standard.string(forKey: "appTheme"),
           let theme = AppTheme(rawValue: themeStr) {
            self.currentTheme = theme
        } else {
            // 旧版数据无法匹配时清理，防止残留
            UserDefaults.standard.removeObject(forKey: "appTheme")
            self.currentTheme = .classic
        }
    }
    
    // MARK: - 历史记录操作
    
    func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey) else { return }
        do {
            let items = try JSONDecoder().decode([TranslationHistoryItem].self, from: data)
            self.history = items
        } catch {
            print("解析历史记录失败: \(error)")
        }
    }
    
    func addHistory(sourceText: String, targetText: String, sourceLanguage: String, targetLanguage: String) {
        // 防止重复插入一模一样的内容
        if let first = history.first, first.sourceText == sourceText && first.targetText == targetText {
            return
        }
        
        let item = TranslationHistoryItem(
            sourceText: sourceText,
            targetText: targetText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            timestamp: Date()
        )
        
        history.insert(item, at: 0) // 最新的在最前面
        saveHistory()
    }
    
    func deleteHistory(at offsets: IndexSet) {
        history.remove(atOffsets: offsets)
        saveHistory()
    }
    
    func toggleFavorite(for item: TranslationHistoryItem) {
        if let index = history.firstIndex(where: { $0.id == item.id }) {
            history[index].isFavorite.toggle()
            saveHistory()
        }
    }
    
    func clearHistory() {
        history.removeAll()
        saveHistory()
    }
    
    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(history)
            UserDefaults.standard.set(data, forKey: historyKey)
        } catch {
            print("保存历史记录失败: \(error)")
        }
    }
}
