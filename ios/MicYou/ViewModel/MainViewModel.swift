import Foundation
import Combine
import SwiftUI

/// 主 ViewModel：MVVM 门面，对齐 Android `MainViewModel.kt`。
///
/// 拥有 `AudioEngine` + `AppSettings` + `DeviceDiscovery`，
/// 将引擎状态转发为 `@Published` 供 SwiftUI 观察。
/// UI 动作（开始/停止/静音/发现）经此分发。
@MainActor
public final class MainViewModel: ObservableObject {

    // MARK: - 拥有的组件
    public let engine = AudioEngine()
    public let settings = AppSettings()
    public let discovery = DeviceDiscovery()

    // MARK: - 转发的 UI 状态
    @Published public private(set) var streamState: StreamState = .idle
    @Published public private(set) var isMuted = false
    @Published public private(set) var audioLevel: Float = 0
    @Published public private(set) var lastError: String?
    @Published public private(set) var stats = AudioSendPipeline.Stats()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - 初始化
    public init() {
        // 转发 AudioEngine 状态到 @Published（主线程）
        engine.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.streamState = $0 }
            .store(in: &cancellables)
        engine.$isMuted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isMuted = $0 }
            .store(in: &cancellables)
        engine.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.audioLevel = $0 }
            .store(in: &cancellables)
        engine.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.lastError = $0 }
            .store(in: &cancellables)
        engine.$stats
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.stats = $0 }
            .store(in: &cancellables)
    }

    // MARK: - 生命周期
    /// 应用启动。对齐 Android `MainViewModel.init` 首次启动 + autoStart 逻辑。
    public func onLaunch() {
        if !settings.hasLaunchedBefore {
            settings.markLaunched()
        }
        if settings.autoStart {
            startStreaming()
        }
    }

    // MARK: - 流式控制
    /// 开始流式。从 settings 构建 config，启动 AudioEngine。
    public func startStreaming() {
        let config = makeConfig()
        Task { await engine.start(config) }
    }

    /// 停止流式。
    public func stopStreaming() {
        engine.stop()
    }

    /// 切换静音。
    public func toggleMute() {
        Task { await engine.setMuted(!isMuted) }
    }

    /// 设置静音。
    public func setMuted(_ muted: Bool) {
        Task { await engine.setMuted(muted) }
    }

    // MARK: - 设备发现
    public func startDiscovery() {
        discovery.startBrowsing()
    }

    public func stopDiscovery() {
        discovery.stopBrowsing()
    }

    /// 选中发现的设备，填入 host/port。
    public func selectDevice(_ device: DiscoveredDevice) {
        settings.host = device.ipAddress
        settings.port = device.port
    }

    // MARK: - 辅助
    /// 从当前 settings 构建 AudioEngine.Config。
    private func makeConfig() -> AudioEngine.Config {
        let isWeb = settings.connectionMode == .web
        return AudioEngine.Config(
            connectionMode: settings.connectionMode,
            transportProtocol: settings.transportProtocol,
            host: isWeb ? settings.webHost : settings.host,
            port: isWeb ? settings.webPort : settings.port,
            sampleRate: settings.sampleRate,
            channelCount: settings.channelCount,
            audioFormat: settings.audioFormat,
            sessionId: Int64(Date().timeIntervalSince1970 * 1000)
        )
    }

    /// 种子色（从 hex 转换）。
    public var seedColor: Color {
        Color(hex: settings.seedColorHex) ?? .blue
    }

    /// 是否正在流式。
    public var isStreaming: Bool { streamState == .streaming }

    /// 是否可操作（非连接中）。
    public var canToggle: Bool { streamState == .streaming || streamState == .idle }
}
