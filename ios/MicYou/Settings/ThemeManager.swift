import SwiftUI

/// 主题管理器。对齐 Android `Theme.kt` + `ExpressiveColorScheme.kt`。
///
/// 从 `AppSettings` 派生主题属性（种子色/明暗/OLED/调色板）。
/// iOS 15 无 Material 3 动态取色 API（需 iOS 17+）；B16 提供：
/// - 种子色 → `.tint()` 全局强调色
/// - 明暗/系统 → `.preferredColorScheme()`
/// - OLED 纯黑 → 深色模式下纯黑背景
/// - 调色板样式 → 预留（iOS 17+ `ColorScheme` 动态取色扩展点）
@MainActor
public final class ThemeManager: ObservableObject {
    public let settings: AppSettings

    public init(settings: AppSettings) {
        self.settings = settings
    }

    /// 强调色（种子色）。
    public var accentColor: Color {
        Color(hex: settings.seedColorHex) ?? .blue
    }

    /// 颜色方案（nil = 跟随系统）。
    public var colorScheme: ColorScheme? {
        settings.themeMode.colorScheme
    }

    /// 是否启用 OLED 纯黑（仅深色模式）。
    public var isOledBlack: Bool {
        settings.oledPureBlack && settings.themeMode != .light
    }

    /// 背景色。
    public var backgroundColor: Color {
        if isOledBlack { return .black }
        return Color(.systemBackground)
    }

    /// 次级背景色。
    public var secondaryBackgroundColor: Color {
        if isOledBlack { return Color(red: 0.05, green: 0.05, blue: 0.05) }
        return Color(.secondarySystemBackground)
    }

    /// 是否支持动态取色（iOS 17+ 有 Material 3 API）。
    public var supportsDynamicColor: Bool {
        if #available(iOS 17.0, *) { return true }
        return false
    }
}

// MARK: - View 修饰符
extension View {
    /// 应用 MicYou 主题：种子色 tint + 明暗 + OLED 背景。
    @ViewBuilder
    func micyouTheme(_ theme: ThemeManager) -> some View {
        self
            .tint(theme.accentColor)
            .preferredColorScheme(theme.colorScheme)
    }
}
