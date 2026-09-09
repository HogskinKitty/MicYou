import Foundation

/// 本地化辅助。对齐 Android `strings.xml` + iOS `Localizable.strings`。
///
/// 用法：`L10n.s("button.start")` → "开始" / "Start"
enum L10n {
    /// 取本地化字符串。
    static func s(_ key: String, _ args: CVarArg...) -> String {
        let template = NSLocalizedString(key, comment: "")
        if args.isEmpty { return template }
        return String(format: template, arguments: args)
    }
}
