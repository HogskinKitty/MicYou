import SwiftUI

/// 流式控制栏：开始/停止 + 静音 + 统计。
/// 对齐 Android `MobileHome` 底部控制区。
struct StreamControlBar: View {
    @EnvironmentObject var viewModel: MainViewModel

    var body: some View {
        VStack(spacing: 12) {
            statsRow
            actionRow
        }
    }

    // MARK: - 统计
    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem("包", value: "\(viewModel.stats.packetsSent)")
            Divider().frame(height: 24)
            statItem("FEC", value: "\(viewModel.stats.fecPacketsSent)")
            Divider().frame(height: 24)
            statItem("已发", value: formatBytes(viewModel.stats.bytesSent))
        }
        .padding(.horizontal)
        .opacity(viewModel.isStreaming ? 1 : 0.4)
    }

    private func statItem(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.bold()).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 操作按钮
    private var actionRow: some View {
        HStack(spacing: 16) {
            muteButton
            startStopButton
            Spacer().frame(width: 48)  // 平衡 muteButton 宽度
        }
    }

    private var muteButton: some View {
        Button {
            viewModel.toggleMute()
        } label: {
            Image(systemName: viewModel.isMuted ? "mic.slash.fill" : "mic.fill")
                .font(.title2)
                .frame(width: 48, height: 48)
                .background(
                    Circle().fill(viewModel.isMuted ? Color.red.opacity(0.15) : Color.gray.opacity(0.1))
                )
        }
        .disabled(!viewModel.isStreaming)
        .tint(viewModel.isMuted ? .red : .primary)
    }

    private var startStopButton: some View {
        Button {
            if viewModel.isStreaming {
                viewModel.stopStreaming()
            } else {
                viewModel.startStreaming()
            }
        } label: {
            HStack(spacing: 8) {
                if viewModel.streamState == .connecting {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: viewModel.isStreaming ? "stop.fill" : "play.fill")
                }
                Text(viewModel.isStreaming ? "停止" : "开始")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(buttonColor)
            )
            .foregroundStyle(.white)
        }
        .disabled(viewModel.streamState == .connecting)
    }

    private var buttonColor: Color {
        switch viewModel.streamState {
        case .streaming: return .red
        case .connecting: return .orange
        case .error: return .red.opacity(0.7)
        case .idle: return .tint
        }
    }

    // MARK: - 辅助
    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }
}
