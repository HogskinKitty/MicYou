import Foundation
import Combine

/// 应用设置模型。对齐 Android `SettingsViewModel.kt` + `AudioStreamViewModel.kt`。
///
/// 持久化到 `UserDefaults`，键名与 Android SharedPreferences (`"android_mic_prefs"`)
/// 一致。`@Published` 供 SwiftUI 绑定；`objectWillChange` debounce 自动保存。
public final class AppSettings: ObservableObject {

    // MARK: - 键名（对齐 Android SharedPreferences keys）
    enum Key {
        // 连接
        static let connectionMode = "connection_mode"
        static let transportProtocol = "transport_protocol"
        static let port = "port"
        static let host = "host"                    // iOS 专有：记住上次主机
        // Web
        static let webHost = "web_host"             // iOS 专有
        static let webPort = "web_port"             // iOS 专有
        // 音频
        static let sampleRate = "sample_rate"
        static let channelCount = "channel_count"
        static let audioFormat = "audio_format"
        // 外观
        static let themeMode = "theme_mode"
        static let useDynamicColor = "use_dynamic_color"
        static let oledPureBlack = "oled_pure_black"
        static let paletteStyle = "palette_style"
        static let useExpressiveShapes = "use_expressive_shapes"
        static let seedColor = "seed_color"         // iOS 专有：种子色 hex
        // 语言
        static let language = "language"
        // 行为
        static let autoStart = "auto_start"
        static let keepScreenOn = "keep_screen_on"
        static let visualizerStyle = "visualizer_style"
        // 背景
        static let backgroundImagePath = "background_image_path"
        static let enableHazeEffect = "enable_haze_effect"
        // 更新
        static let autoCheckUpdate = "auto_check_update"
        static let useMirrorDownload = "use_mirror_download"
        static let mirrorCdk = "mirror_cdk"
        // 首次启动
        static let hasLaunchedBefore = "has_launched_before"
    }

    private let defaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 连接设置
    @Published public var connectionMode: ConnectionMode = .wifi
    @Published public var transportProtocol: TransportProtocol = .both
    @Published public var host: String = "127.0.0.1"
    @Published public var port: Int = WireConstants.defaultTcpPort

    // MARK: - Web 设置
    @Published public var webHost: String = ""
    @Published public var webPort: Int = WireConstants.defaultWebPort

    // MARK: - 音频设置
    @Published public var sampleRate: SampleRate = .rate48000
    @Published public var channelCount: ChannelCount = .stereo
    @Published public var audioFormat: AudioFormatType = .pcm16bit

    // MARK: - 外观设置
    @Published public var themeMode: ThemeMode = .system
    @Published public var useDynamicColor: Bool = false
    @Published public var oledPureBlack: Bool = false
    @Published public var paletteStyle: PaletteStyle = .tonalSpot
    @Published public var useExpressiveShapes: Bool = true
    @Published public var seedColorHex: String = "4287F5"

    // MARK: - 语言
    @Published public var language: AppLanguage = .system

    // MARK: - 行为设置
    @Published public var autoStart: Bool = false
    @Published public var keepScreenOn: Bool = false
    @Published public var visualizerStyle: VisualizerStyle = .volumeRing

    // MARK: - 背景
    @Published public var backgroundImagePath: String = ""
    @Published public var enableHazeEffect: Bool = false

    // MARK: - 更新
    @Published public var autoCheckUpdate: Bool = true
    @Published public var useMirrorDownload: Bool = false
    @Published public var mirrorCdk: String = ""

    // MARK: - 首次启动
    @Published public var hasLaunchedBefore: Bool = false

    // MARK: - 初始化
    public init() {
        load()
        // 自动保存：objectWillChange debounce 200ms 后批量写入
        objectWillChange
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.save() }
            .store(in: &cancellables)
    }

    // MARK: - 加载
    public func load() {
        // 连接
        if let s = defaults.string(forKey: Key.connectionMode), let v = ConnectionMode(rawValue: s) {
            connectionMode = v
        }
        if let s = defaults.string(forKey: Key.transportProtocol), let v = TransportProtocol(rawValue: s) {
            transportProtocol = v
        }
        if let s = defaults.string(forKey: Key.host), !s.isEmpty { host = s }
        if defaults.object(forKey: Key.port) != nil { port = defaults.integer(forKey: Key.port) }

        // Web
        if let s = defaults.string(forKey: Key.webHost), !s.isEmpty { webHost = s }
        if defaults.object(forKey: Key.webPort) != nil { webPort = defaults.integer(forKey: Key.webPort) }

        // 音频
        if defaults.object(forKey: Key.sampleRate) != nil {
            sampleRate = SampleRate(rawValue: defaults.integer(forKey: Key.sampleRate)) ?? .rate48000
        }
        if defaults.object(forKey: Key.channelCount) != nil {
            channelCount = ChannelCount(rawValue: defaults.integer(forKey: Key.channelCount)) ?? .stereo
        }
        if defaults.object(forKey: Key.audioFormat) != nil {
            audioFormat = AudioFormatType(rawValue: defaults.integer(forKey: Key.audioFormat)) ?? .pcm16bit
        }

        // 外观
        if let s = defaults.string(forKey: Key.themeMode), let v = ThemeMode(rawValue: s) {
            themeMode = v
        }
        useDynamicColor = defaults.bool(forKey: Key.useDynamicColor)
        oledPureBlack = defaults.bool(forKey: Key.oledPureBlack)
        if let s = defaults.string(forKey: Key.paletteStyle), let v = PaletteStyle(rawValue: s) {
            paletteStyle = v
        }
        if defaults.object(forKey: Key.useExpressiveShapes) != nil {
            useExpressiveShapes = defaults.bool(forKey: Key.useExpressiveShapes)
        }
        if let s = defaults.string(forKey: Key.seedColor), !s.isEmpty { seedColorHex = s }

        // 语言
        if let s = defaults.string(forKey: Key.language), let v = AppLanguage(rawValue: s) {
            language = v
        }

        // 行为
        autoStart = defaults.bool(forKey: Key.autoStart)
        keepScreenOn = defaults.bool(forKey: Key.keepScreenOn)
        if let s = defaults.string(forKey: Key.visualizerStyle), let v = VisualizerStyle(rawValue: s) {
            visualizerStyle = v
        }

        // 背景
        if let s = defaults.string(forKey: Key.backgroundImagePath) { backgroundImagePath = s }
        enableHazeEffect = defaults.bool(forKey: Key.enableHazeEffect)

        // 更新
        if defaults.object(forKey: Key.autoCheckUpdate) != nil {
            autoCheckUpdate = defaults.bool(forKey: Key.autoCheckUpdate)
        }
        useMirrorDownload = defaults.bool(forKey: Key.useMirrorDownload)
        if let s = defaults.string(forKey: Key.mirrorCdk) { mirrorCdk = s }

        // 首次启动
        hasLaunchedBefore = defaults.bool(forKey: Key.hasLaunchedBefore)
    }

    // MARK: - 保存
    public func save() {
        // 连接
        defaults.set(connectionMode.rawValue, forKey: Key.connectionMode)
        defaults.set(transportProtocol.rawValue, forKey: Key.transportProtocol)
        defaults.set(host, forKey: Key.host)
        defaults.set(port, forKey: Key.port)
        // Web
        defaults.set(webHost, forKey: Key.webHost)
        defaults.set(webPort, forKey: Key.webPort)
        // 音频
        defaults.set(sampleRate.rawValue, forKey: Key.sampleRate)
        defaults.set(channelCount.rawValue, forKey: Key.channelCount)
        defaults.set(audioFormat.rawValue, forKey: Key.audioFormat)
        // 外观
        defaults.set(themeMode.rawValue, forKey: Key.themeMode)
        defaults.set(useDynamicColor, forKey: Key.useDynamicColor)
        defaults.set(oledPureBlack, forKey: Key.oledPureBlack)
        defaults.set(paletteStyle.rawValue, forKey: Key.paletteStyle)
        defaults.set(useExpressiveShapes, forKey: Key.useExpressiveShapes)
        defaults.set(seedColorHex, forKey: Key.seedColor)
        // 语言
        defaults.set(language.rawValue, forKey: Key.language)
        // 行为
        defaults.set(autoStart, forKey: Key.autoStart)
        defaults.set(keepScreenOn, forKey: Key.keepScreenOn)
        defaults.set(visualizerStyle.rawValue, forKey: Key.visualizerStyle)
        // 背景
        defaults.set(backgroundImagePath, forKey: Key.backgroundImagePath)
        defaults.set(enableHazeEffect, forKey: Key.enableHazeEffect)
        // 更新
        defaults.set(autoCheckUpdate, forKey: Key.autoCheckUpdate)
        defaults.set(useMirrorDownload, forKey: Key.useMirrorDownload)
        defaults.set(mirrorCdk, forKey: Key.mirrorCdk)
        // 首次启动
        defaults.set(hasLaunchedBefore, forKey: Key.hasLaunchedBefore)
    }

    // MARK: - 便捷
    /// 标记首次启动已完成。
    public func markLaunched() {
        hasLaunchedBefore = true
        save()
    }

    /// 重置为默认值。
    public func reset() {
        connectionMode = .wifi
        transportProtocol = .both
        host = "127.0.0.1"
        port = WireConstants.defaultTcpPort
        webHost = ""
        webPort = WireConstants.defaultWebPort
        sampleRate = .rate48000
        channelCount = .stereo
        audioFormat = .pcm16bit
        themeMode = .system
        useDynamicColor = false
        oledPureBlack = false
        paletteStyle = .tonalSpot
        useExpressiveShapes = true
        seedColorHex = "4287F5"
        language = .system
        autoStart = false
        keepScreenOn = false
        visualizerStyle = .volumeRing
        backgroundImagePath = ""
        enableHazeEffect = false
        autoCheckUpdate = true
        useMirrorDownload = false
        mirrorCdk = ""
        save()
    }
}
