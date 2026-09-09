import SwiftUI

/// MicYou iOS 应用入口。
///
/// 把 iPhone 变成 PC 麦克风：采集音频 → Opus 编码 → 经 Wi-Fi/USB/Web 发送到桌面端。
/// 部署目标 iOS 15.0（iPhone 6s 基准）。对齐 Android `MicYouApplication` + `MainActivity`。
@main
struct MicYouApp: App {
    @StateObject private var viewModel: MainViewModel
    @StateObject private var theme: ThemeManager

    init() {
        let vm = MainViewModel()
        _viewModel = StateObject(wrappedValue: vm)
        _theme = StateObject(wrappedValue: ThemeManager(settings: vm.settings))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(viewModel.settings)
                .environmentObject(theme)
                .micyouTheme(theme)
                .onAppear { viewModel.onLaunch() }
        }
    }
}
