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
            Text(viewModel.state.streamState.label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .tint(viewModel.state.seedColor)
    }
}

/// 占位：B12 引入完整 MainViewModel 前，提供一个最小实现以让壳可编译。
/// B12 会用真正的 MVVM 状态管理替换。
@MainActor
final class MainViewModel: ObservableObject {
    @Published var state = AppUiState()

    func onLaunch() {}

    struct AppUiState {
        var streamState: StreamState = .idle
        var seedColor: Color = .blue
        var themeMode: ThemeMode = .system
    }
}

enum StreamState {
    case idle, connecting, streaming, error

    var label: String {
        switch self {
        case .idle: return "点击开始"
        case .connecting: return "连接中…"
        case .streaming: return "流式中"
        case .error: return "错误"
        }
    }
}

enum ThemeMode: String {
    case system, light, dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
