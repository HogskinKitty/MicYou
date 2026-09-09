import SwiftUI

/// 根视图：加载 HomeView。
struct ContentView: View {
    @EnvironmentObject var viewModel: MainViewModel

    var body: some View {
        HomeView()
    }
}
