import SwiftUI

/// Color 扩展：hex 字符串转换。
extension Color {
    /// 从 hex 字符串创建 Color。支持 "RRGGBB" / "#RRGGBB" / "RRGGBBAA"。
    init?(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }

        guard hex.count == 6 || hex.count == 8 else { return nil }
        guard let value = UInt64(hex, radix: 16) else { return nil }

        let r, g, b, a: Double
        if hex.count == 8 {
            a = Double((value >> 24) & 0xFF) / 255.0
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >> 8) & 0xFF) / 255.0
            b = Double(value & 0xFF) / 255.0
        } else {
            a = 1.0
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >> 8) & 0xFF) / 255.0
            b = Double(value & 0xFF) / 255.0
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// 转换为 hex 字符串 "RRGGBB"。
    func toHex() -> String {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X",
                      Int(r * 255), Int(g * 255), Int(b * 255))
        #else
        return "4287F5"
        #endif
    }
}
