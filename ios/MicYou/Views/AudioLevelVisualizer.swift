import SwiftUI

/// 音频电平可视化。对齐 Android `VisualizerStyle`。
///
/// B13 实现 VolumeRing（默认）；其他样式 B16 扩展。
struct AudioLevelVisualizer: View {
    var level: Float
    var style: VisualizerStyle = .volumeRing
    var isStreaming: Bool = false

    private let size: CGFloat = 140

    var body: some View {
        switch style {
        case .volumeRing: volumeRing
        case .bars: bars
        case .wave: wave
        default: volumeRing
        }
    }

    // MARK: - Volume Ring
    private var volumeRing: some View {
        let progress = CGFloat(min(max(level, 0), 1))
        return ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.15), lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(colors: [.tint, .tint.opacity(0.6)],
                                    center: .center),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.08), value: level)
            micIcon
        }
        .frame(width: size, height: size)
    }

    // MARK: - Bars
    private var bars: some View {
        let barCount = 12
        let progress = CGFloat(min(max(level, 0), 1))
        return HStack(alignment: .center, spacing: 4) {
            ForEach(0..<barCount, id: \.self) { i in
                let height = progress * (size * 0.7) * CGFloat.random(in: 0.3...1.0)
                Capsule()
                    .fill(.tint.opacity(0.3 + Double(progress) * 0.7))
                    .frame(width: 6, height: max(4, height))
                    .animation(.easeOut(duration: 0.1), value: level)
            }
        }
        .frame(height: size)
    }

    // MARK: - Wave
    private var wave: some View {
        let progress = CGFloat(min(max(level, 0), 1))
        return ZStack {
            micIcon
            Circle()
                .stroke(.tint.opacity(0.3), lineWidth: 2)
                .scaleEffect(1 + progress * 0.5)
                .animation(.easeOut(duration: 0.2), value: level)
            Circle()
                .stroke(.tint.opacity(0.15), lineWidth: 1)
                .scaleEffect(1 + progress * 0.8)
                .animation(.easeOut(duration: 0.3), value: level)
        }
        .frame(width: size, height: size)
    }

    private var micIcon: some View {
        Image(systemName: isStreaming ? "mic.fill" : "mic")
            .font(.system(size: 44))
            .foregroundStyle(isStreaming ? .tint : .secondary)
    }
}
