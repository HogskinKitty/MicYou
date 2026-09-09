import SwiftUI

/// 设置视图占位（B14 将替换为完整设置 UI）。
struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        NavigationStack {
            Form {
                Section("外观") {
                    Picker("主题", selection: $settings.themeMode) {
                        ForEach(ThemeMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    Toggle("动态取色", isOn: $settings.useDynamicColor)
                    Toggle("OLED 纯黑", isOn: $settings.oledPureBlack)
                }
                Section("行为") {
                    Toggle("保持屏幕常亮", isOn: $settings.keepScreenOn)
                    Toggle("自动开始", isOn: $settings.autoStart)
                    Toggle("自动检查更新", isOn: $settings.autoCheckUpdate)
                }
                Section("语言") {
                    Picker("语言", selection: $settings.language) {
                        ForEach(AppLanguage.allCases, id: \.self) { lang in
                            Text(lang.label).tag(lang)
                        }
                    }
                }
                Section("可视化") {
                    Picker("样式", selection: $settings.visualizerStyle) {
                        ForEach(VisualizerStyle.allCases, id: \.self) { style in
                            Label(style.label, systemImage: style.icon).tag(style)
                        }
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
