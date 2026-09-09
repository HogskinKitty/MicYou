import Foundation

/// 应用语言。对齐 Android `Localization.kt:27-35` `AppLanguage`。
///
/// 存储值 = Kotlin enum `.name`（PascalCase），与 Android 一致。
public enum AppLanguage: String, CaseIterable, Codable {
    case system = "System"
    case chinese = "Chinese"
    case chineseTraditional = "ChineseTraditional"
    case cantonese = "Cantonese"
    case english = "English"
    case chineseCat = "ChineseCat"
    case chineseHard = "ChineseHard"

    public var label: String {
        switch self {
        case .system: return "跟随系统"
        case .chinese: return "简体中文"
        case .chineseTraditional: return "繁體中文"
        case .cantonese: return "粤语"
        case .english: return "English"
        case .chineseCat: return "中文（猫猫语）🐱"
        case .chineseHard: return "中文（坚硬）"
        }
    }

    /// BCP 47 语言代码（用于 SwiftUI Locale / String Catalog）。
    public var code: String {
        switch self {
        case .system: return Locale.current.identifier
        case .chinese: return "zh-Hans"
        case .chineseTraditional: return "zh-Hant"
        case .cantonese: return "zh-HK"
        case .english: return "en"
        case .chineseCat: return "ca"
        case .chineseHard: return "zh-Hans"
        }
    }

    /// 是否跟随系统。
    public var isSystem: Bool { self == .system }
}
