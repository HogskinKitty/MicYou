import SwiftUI

/// 主界面。对齐 Android `MobileHome`。
///
/// 布局：顶部可视化 + 状态 → 中部连接设置 → 底部流式控制。
/// B14 在 toolbar 注入 SettingsView；B16 扩展可视化样式。
struct HomeView: View {
    @EnvironmentObject var viewModel: MainViewModel
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    visualizerSection
                    connectionSection
                    if settings.connectionMode == .wifi {
                        DeviceListView()
                    }
                }
                .padding()
            }
            .background(theme.backgroundColor)
            .safeAreaInset(edge: .bottom) {
                StreamControlBar()
                    .padding()
                    .background(theme.isOledBlack ? Color.black : Color(.bar))
            }
            .navigationTitle("MicYou")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }

    // MARK: - 可视化区
    private var visualizerSection: some View {
        VStack(spacing: 12) {
            AudioLevelVisualizer(
                level: viewModel.audioLevel,
                style: settings.visualizerStyle,
                isStreaming: viewModel.isStreaming
            )
            stateLabel
            if let error = viewModel.lastError, viewModel.streamState == .error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var stateLabel: some View {
        HStack(spacing: 6) {
            if viewModel.isStreaming {
                Circle().fill(.green).frame(width: 8, height: 8)
            }
            Text(viewModel.streamState.label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 连接设置区
    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("连接设置", systemImage: "network")
                .font(.headline)
            ConnectionPanel()
        }
        .padding()
        .background(theme.secondaryBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
