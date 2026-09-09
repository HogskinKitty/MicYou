import SwiftUI

/// 主题模式。对齐 Android `theme/ThemeMode`。
public enum ThemeMode: String, CaseIterable, Codable {
    case system
    case light
    case dark

    public var label: String {
        switch self {
        case .system: return L10n.s("theme.system")
        case .light: return L10n.s("theme.light")
        case .dark: return L10n.s("theme.dark")
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
