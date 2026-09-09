import SwiftUI

/// 设置视图。对齐 Android `SettingsScreen`。
///
/// 分区：外观 / 行为 / 语言 / 可视化 / 更新 / 关于。
/// B16 扩展动态取色 + 种子色实时预览。
struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var viewModel: MainViewModel

    private let presetColors: [String] = [
        "4287F5", "FF6B6B", "4ECDC4", "FFE66D", "A8E6CF", "FF8B94",
        "C7CEEA", "E0BBE4", "95E1D3", "F38181", "AA96DA", "FCBAD3",
        "6C5CE7", "FD79A8", "00CEC9", "FDCB6E", "E17055", "74B9FF"
    ]

    var body: some View {
        Form {
            appearanceSection
            behaviorSection
            languageSection
            visualizerSection
            updateSection
            aboutSection
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 外观
    private var appearanceSection: some View {
        Section("外观") {
            Picker("主题模式", selection: $settings.themeMode) {
                ForEach(ThemeMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            Toggle("动态取色", isOn: $settings.useDynamicColor)
            Toggle("OLED 纯黑", isOn: $settings.oledPureBlack)
            Picker("调色板", selection: $settings.paletteStyle) {
                ForEach(PaletteStyle.allCases, id: \.self) { style in
                    Text(style.label).tag(style)
                }
            }
            Toggle("表现力形状", isOn: $settings.useExpressiveShapes)
            seedColorPicker
        }
    }

    private var seedColorPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("种子色")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                ForEach(presetColors, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex) ?? .blue)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle().stroke(.white, lineWidth: settings.seedColorHex == hex ? 3 : 0)
                        )
                        .overlay(
                            Circle().stroke(.gray.opacity(0.3), lineWidth: 1)
                        )
                        .onTapGesture { settings.seedColorHex = hex }
                }
            }
        }
    }

    // MARK: - 行为
    private var behaviorSection: some View {
        Section("行为") {
            Toggle("保持屏幕常亮", isOn: $settings.keepScreenOn)
            Toggle("自动开始", isOn: $settings.autoStart)
            Toggle("雾面效果", isOn: $settings.enableHazeEffect)
        }
    }

    // MARK: - 语言
    private var languageSection: some View {
        Section("语言") {
            Picker("语言", selection: $settings.language) {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    Text(lang.label).tag(lang)
                }
            }
        }
    }

    // MARK: - 可视化
    private var visualizerSection: some View {
        Section("可视化") {
            Picker("样式", selection: $settings.visualizerStyle) {
                ForEach(VisualizerStyle.allCases, id: \.self) { style in
                    Label(style.label, systemImage: style.icon).tag(style)
                }
            }
        }
    }

    // MARK: - 更新
    private var updateSection: some View {
        Section("更新") {
            Toggle("自动检查更新", isOn: $settings.autoCheckUpdate)
            Toggle("使用镜像下载", isOn: $settings.useMirrorDownload)
            if settings.useMirrorDownload {
                TextField("镜像 CDK", text: $settings.mirrorCdk)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    // MARK: - 关于
    private var aboutSection: some View {
        Section("关于") {
            HStack {
                Text("版本")
                Spacer()
                Text(appVersion).foregroundStyle(.secondary)
            }
            HStack {
                Text("构建")
                Spacer()
                Text(buildNumber).foregroundStyle(.secondary)
            }
            Button(role: .destructive) {
                settings.reset()
            } label: {
                Text("重置所有设置")
            }
        }
    }

    // MARK: - 辅助
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.3"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "27"
    }
}
