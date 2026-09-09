import SwiftUI

/// 根视图占位（B13 将替换为完整 HomeView）。
///
/// 当前仅展示应用名与状态，验证 SwiftUI 壳可编译运行。
struct ContentView: View {
    @EnvironmentObject var viewModel: MainViewModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("MicYou")
                .font(.largeTitle.bold())
            Text(viewModel.streamState.label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .tint(viewModel.seedColor)
    }
}
