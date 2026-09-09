import Foundation

/// 可视化样式。对齐 Android `MainViewModel.kt:62-69` `VisualizerStyle`。
public enum VisualizerStyle: String, CaseIterable, Codable {
    case volumeRing = "VolumeRing"
    case ripple = "Ripple"
    case bars = "Bars"
    case wave = "Wave"
    case glow = "Glow"
    case particles = "Particles"

    public var label: String {
        switch self {
        case .volumeRing: return "音量环"
        case .ripple: return "涟漪"
        case .bars: return "频谱条"
        case .wave: return "波形"
        case .glow: return "光晕"
        case .particles: return "粒子"
        }
    }

    public var icon: String {
        switch self {
        case .volumeRing: return "circle.hexagongrid"
        case .ripple: return "waveform.circle"
        case .bars: return "chart.bar"
        case .wave: return "waveform"
        case .glow: return "sun.max"
        case .particles: return "sparkles"
        }
    }
}

/// 调色板样式。对齐 Android `ExpressiveColorScheme.kt:35-47` `PaletteStyle`。
public enum PaletteStyle: String, CaseIterable, Codable {
    case tonalSpot = "TonalSpot"
    case neutral = "Neutral"
    case vibrant = "Vibrant"
    case expressive = "Expressive"
    case rainbow = "Rainbow"
    case fruitSalad = "FruitSalad"
    case monochrome = "Monochrome"
    case fidelity = "Fidelity"
    case content = "Content"

    public var label: String {
        switch self {
        case .tonalSpot: return "Tonal Spot"
        case .neutral: return "Neutral"
        case .vibrant: return "Vibrant"
        case .expressive: return "Expressive"
        case .rainbow: return "Rainbow"
        case .fruitSalad: return "FruitSalad"
        case .monochrome: return "Monochrome"
        case .fidelity: return "Fidelity"
        case .content: return "Content"
        }
    }
}
