//
//  LanguageConfig.swift
//  translate
//

import Foundation
import NaturalLanguage
import Translation

/// 单个语言选项
struct LanguageOption: Identifiable, Hashable {
    let id: String           // 如 "zh-Hans"
    let displayName: String  // 如 "中文（简体）"
    let flag: String         // 如 "🇨🇳"
    let locale: Locale.Language

    static func == (lhs: LanguageOption, rhs: LanguageOption) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// 用于 AVSpeechSynthesizer 的 locale 标识符
    var speechLocaleIdentifier: String {
        switch id {
        case "zh-Hans": return "zh-CN"
        case "zh-Hant": return "zh-TW"
        case "en":      return "en-US"
        case "ja":      return "ja-JP"
        case "ko":      return "ko-KR"
        case "fr":      return "fr-FR"
        case "de":      return "de-DE"
        case "es":      return "es-ES"
        case "it":      return "it-IT"
        case "pt":      return "pt-BR"
        case "ru":      return "ru-RU"
        case "ar":      return "ar-SA"
        default:        return "en-US"
        }
    }

    /// 用于 SFSpeechRecognizer 的 locale 标识符
    var speechRecognitionLocaleIdentifier: String {
        speechLocaleIdentifier
    }
}

extension LanguageOption {
    /// 特殊选项：自动识别源语言
    static let auto = LanguageOption(
        id: "auto",
        displayName: "自动识别",
        flag: "🔍",
        locale: Locale.Language(identifier: "und") // 占位，实际不会直接使用
    )
    
    static let allLanguages: [LanguageOption] = [
        LanguageOption(id: "zh-Hans", displayName: "中文（简体）", flag: "🇨🇳",
                       locale: Locale.Language(identifier: "zh-Hans")),
        LanguageOption(id: "zh-Hant", displayName: "中文（繁体）", flag: "🇨🇳",
                       locale: Locale.Language(identifier: "zh-Hant")),
        LanguageOption(id: "en",      displayName: "英语",         flag: "🇺🇸",
                       locale: Locale.Language(identifier: "en")),
        LanguageOption(id: "ja",      displayName: "日语",         flag: "🇯🇵",
                       locale: Locale.Language(identifier: "ja")),
        LanguageOption(id: "ko",      displayName: "韩语",         flag: "🇰🇷",
                       locale: Locale.Language(identifier: "ko")),
        LanguageOption(id: "fr",      displayName: "法语",         flag: "🇫🇷",
                       locale: Locale.Language(identifier: "fr")),
        LanguageOption(id: "de",      displayName: "德语",         flag: "🇩🇪",
                       locale: Locale.Language(identifier: "de")),
        LanguageOption(id: "es",      displayName: "西班牙语",     flag: "🇪🇸",
                       locale: Locale.Language(identifier: "es")),
        LanguageOption(id: "it",      displayName: "意大利语",     flag: "🇮🇹",
                       locale: Locale.Language(identifier: "it")),
        LanguageOption(id: "pt",      displayName: "葡萄牙语",     flag: "🇧🇷",
                       locale: Locale.Language(identifier: "pt")),
        LanguageOption(id: "ru",      displayName: "俄语",         flag: "🇷🇺",
                       locale: Locale.Language(identifier: "ru")),
        LanguageOption(id: "ar",      displayName: "阿拉伯语",     flag: "🇸🇦",
                       locale: Locale.Language(identifier: "ar")),
    ]
    
    /// 默认源语言：自动识别
    static var defaultSource: LanguageOption { .auto }
    /// 默认目标语言：英语 (index 2)
    static var defaultTarget: LanguageOption { allLanguages[2] }
    
    /// 通过 NLLanguageRecognizer 识别文本语言，返回匹配的 LanguageOption（没有匹配则返回 nil）
    static func detect(from text: String) -> LanguageOption? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let dominant = recognizer.dominantLanguage else { return nil }
        let identifier = dominant.rawValue // e.g. "zh-Hans", "en", "ja"…
        // 尝试精确匹配
        if let exact = allLanguages.first(where: { $0.id == identifier }) {
            return exact
        }
        // 尝试前缀匹配（如 "zh" 匹配 "zh-Hans"，"pt" 匹配 "pt"）
        let prefix = identifier.split(separator: "-").first.map(String.init) ?? identifier
        return allLanguages.first(where: { $0.id.hasPrefix(prefix) })
    }
}

// MARK: - Network API (百度通用翻译 + MyMemory 兜底)

/// 百度通用翻译 API（doc/21）
/// 文档：https://api.fanyi.baidu.com/doc/21
struct BaiduTranslator {

    // ⚠️ 请将下方占位符替换为你在百度翻译开放平台申请的真实凭证
    static let appid     = "20260605002626402"      // 替换为你的 AppID
    static let secretKey = "beVZ6vabJJUqzB5L1kUa" // 替换为你的密钥

    /// 百度通用翻译 API 端点。
    /// 当前实现使用开放平台 AppID + 密钥的 MD5 签名，必须请求 fanyi-api 域名。
    private static let endpoint = "https://fanyi-api.baidu.com/api/trans/vip/translate"

    enum TranslatorError: Error {
        case invalidURL
        case networkError(Error)
        case invalidResponse
        case apiError(Int, String)  // error_code, error_msg
    }

    /// 将 Locale.Language 映射为百度 API 的语言代码
    static func mapLanguageCode(_ language: Locale.Language) -> String {
        guard let code = language.languageCode?.identifier else { return "auto" }
        switch code {
        case "zh":
            return language.script?.identifier == "Hant" ? "cht" : "zh"
        case "en": return "en"
        case "ja": return "jp"
        case "ko": return "kor"
        case "fr": return "fra"
        case "de": return "de"
        case "es": return "spa"
        case "it": return "it"
        case "pt": return "pt"
        case "ru": return "ru"
        case "ar": return "ara"
        default:   return code
        }
    }

    /// 生成 MD5 签名（appid + q + salt + secretKey）—— 纯 Swift 实现，无需 CommonCrypto
    private static func md5(_ string: String) -> String {
        let bytes = Array(string.utf8)
        var state = [UInt32](repeating: 0, count: 4)
        state[0] = 0x67452301; state[1] = 0xefcdab89
        state[2] = 0x98badcfe; state[3] = 0x10325476

        let s: [UInt32] = [
            7,12,17,22, 7,12,17,22, 7,12,17,22, 7,12,17,22,
            5, 9,14,20, 5, 9,14,20, 5, 9,14,20, 5, 9,14,20,
            4,11,16,23, 4,11,16,23, 4,11,16,23, 4,11,16,23,
            6,10,15,21, 6,10,15,21, 6,10,15,21, 6,10,15,21
        ]
        let K: [UInt32] = (0..<64).map { i in
            UInt32(abs(sin(Double(i) + 1)) * pow(2, 32))
        }

        var msg = bytes
        let msgLen = msg.count
        msg.append(0x80)
        while msg.count % 64 != 56 { msg.append(0x00) }
        let bitLen = UInt64(msgLen) * 8
        for i in 0..<8 { msg.append(UInt8((bitLen >> (i * 8)) & 0xff)) }

        func leftRotate(_ x: UInt32, _ n: UInt32) -> UInt32 {
            (x << n) | (x >> (32 - n))
        }

        for chunk in stride(from: 0, to: msg.count, by: 64) {
            var M = [UInt32](repeating: 0, count: 16)
            for j in 0..<16 {
                let offset = chunk + j * 4
                M[j] = UInt32(msg[offset]) | (UInt32(msg[offset+1]) << 8)
                      | (UInt32(msg[offset+2]) << 16) | (UInt32(msg[offset+3]) << 24)
            }
            var (a, b, c, d) = (state[0], state[1], state[2], state[3])
            for i in 0..<64 {
                var F: UInt32; var g: Int
                switch i {
                case  0..<16: F = (b & c) | (~b & d); g = i
                case 16..<32: F = (d & b) | (~d & c); g = (5*i + 1) % 16
                case 32..<48: F = b ^ c ^ d;           g = (3*i + 5) % 16
                default:      F = c ^ (b | ~d);        g = (7*i) % 16
                }
                F = F &+ a &+ K[i] &+ M[g]
                a = d; d = c; c = b
                b = b &+ leftRotate(F, s[i])
            }
            state[0] = state[0] &+ a; state[1] = state[1] &+ b
            state[2] = state[2] &+ c; state[3] = state[3] &+ d
        }

        return state.flatMap { v -> [UInt8] in
            [UInt8(v & 0xff), UInt8((v >> 8) & 0xff),
             UInt8((v >> 16) & 0xff), UInt8((v >> 24) & 0xff)]
        }.map { String(format: "%02x", $0) }.joined()
    }

    /// 调用百度通用翻译 API
    static func translate(text: String, source: Locale.Language, target: Locale.Language) async throws -> String {
        let from = mapLanguageCode(source)
        let to   = mapLanguageCode(target)
        let salt  = String(Int.random(in: 10000...99999))
        let sign  = md5("\(appid)\(text)\(salt)\(secretKey)")
        print("[BaiduTranslator] Request from=\(from) to=\(to) textLength=\(text.count)")

        // 构造 POST body（application/x-www-form-urlencoded）
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "q",    value: text),
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "to",   value: to),
            URLQueryItem(name: "appid", value: appid),
            URLQueryItem(name: "salt", value: salt),
            URLQueryItem(name: "sign", value: sign),
        ]
        let bodyString = components.percentEncodedQuery ?? ""

        guard let url = URL(string: endpoint) else {
            throw TranslatorError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(bodyString.utf8)
        request.timeoutInterval = 8.0

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest  = 8.0
        config.timeoutIntervalForResource = 8.0
        let session = URLSession(configuration: config)

        do {
            let (data, response) = try await session.data(for: request)
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? -1
            let rawBody = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("[BaiduTranslator] HTTP \(statusCode) body: \(rawBody)")

            guard statusCode == 200 else {
                throw TranslatorError.invalidResponse
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw TranslatorError.invalidResponse
            }

            // 错误格式：{"error_code": "54001", "error_msg": "Invalid Sign"}
            // error_code 可能是 String 或 Int，统一处理
            let errorCodeStr: String?
            if let s = json["error_code"] as? String { errorCodeStr = s }
            else if let n = json["error_code"] as? Int { errorCodeStr = String(n) }
            else { errorCodeStr = nil }

            if let errorCodeStr, errorCodeStr != "52000" && errorCodeStr != "0" {
                let errorMsg = json["error_msg"] as? String ?? "unknown error"
                print("[BaiduTranslator] API error \(errorCodeStr): \(errorMsg)")
                throw TranslatorError.apiError(Int(errorCodeStr) ?? -1, errorMsg)
            }

            // 响应格式：{"trans_result": [{"src": "...", "dst": "..."}], ...}
            guard let results = json["trans_result"] as? [[String: Any]],
                  let first   = results.first,
                  let dst      = first["dst"] as? String,
                  !dst.isEmpty else {
                print("[BaiduTranslator] Unexpected response structure: \(json)")
                throw TranslatorError.invalidResponse
            }

            return dst

        } catch let err as TranslatorError {
            throw err
        } catch {
            throw TranslatorError.networkError(error)
        }
    }
}

/// MyMemory 免费接口（作为百度 API 不可用时的最终兜底）
struct NetworkTranslator {
    enum TranslatorError: Error {
        case invalidURL
        case networkError(Error)
        case invalidResponse
    }

    /// 将系统 Locale.Language 转换为 API 识别的语言代码
    static func mapLanguageCode(_ language: Locale.Language) -> String {
        guard let code = language.languageCode?.identifier else { return "auto" }
        switch code {
        case "zh":
            return language.script?.identifier == "Hant" ? "zh-TW" : "zh-CN"
        default:
            return code
        }
    }

    /// 执行翻译请求
    static func translate(text: String, source: Locale.Language, target: Locale.Language) async throws -> String {
        let sl = mapLanguageCode(source)
        let tl = mapLanguageCode(target)
        let langpair = "\(sl)|\(tl)"

        var components = URLComponents(string: "https://api.mymemory.translated.net/get")!
        components.queryItems = [
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "langpair", value: langpair)
        ]

        guard let url = components.url else {
            throw TranslatorError.invalidURL
        }

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest  = 4.0
        config.timeoutIntervalForResource = 4.0
        let session = URLSession(configuration: config)

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw TranslatorError.invalidResponse
            }

            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let responseData = json["responseData"] as? [String: Any],
                  let translatedText = responseData["translatedText"] as? String,
                  !translatedText.isEmpty else {
                throw TranslatorError.invalidResponse
            }

            return translatedText
        } catch {
            throw TranslatorError.networkError(error)
        }
    }
}
