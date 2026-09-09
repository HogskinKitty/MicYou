import Foundation
import Combine
import MicYouOpus

/// 音频引擎：核心编排层，对齐 Android `AudioEngine.kt`。
///
/// 职责：
/// 1. 创建 TCP/UDP 传输，连接 + 握手
/// 2. 创建采集引擎 + 发送管线，接线采集→编码→发送
/// 3. TCP 接收循环（处理 Pong 心跳 / Mute 控制）
/// 4. 心跳：定期发 Ping，超时判定断线
/// 5. 状态机：idle → connecting → streaming / error
/// 6. 启动/停止/静音
///
/// B8 覆盖 WiFi + USB；Web 模式由 B9 扩展。
public final class AudioEngine: ObservableObject {

    // MARK: - 配置
    public struct Config {
        public var connectionMode: ConnectionMode
        public var transportProtocol: TransportProtocol
        public var host: String
        public var port: Int
        public var sampleRate: SampleRate
        public var channelCount: ChannelCount
        public var audioFormat: AudioFormatType
        public var sessionId: Int64

        public init(connectionMode: ConnectionMode = .wifi,
                    transportProtocol: TransportProtocol = .both,
                    host: String = "127.0.0.1", port: Int = WireConstants.defaultTcpPort,
                    sampleRate: SampleRate = .rate48000,
                    channelCount: ChannelCount = .mono,
                    audioFormat: AudioFormatType = .pcm16bit,
                    sessionId: Int64 = 0) {
            self.connectionMode = connectionMode
            self.transportProtocol = transportProtocol
            self.host = host
            self.port = port
            self.sampleRate = sampleRate
            self.channelCount = channelCount
            self.audioFormat = audioFormat
            self.sessionId = sessionId
        }
    }

    // MARK: - 发布状态（UI 观察）
    @Published public private(set) var state: StreamState = .idle
    @Published public private(set) var lastError: String?
    @Published public private(set) var isMuted = false
    @Published public private(set) var audioLevel: Float = 0
    @Published public private(set) var stats = AudioSendPipeline.Stats()

    // MARK: - 内部组件
    private var tcp: TcpTransport?
    private var udp: UdpTransport?
    private var webTransport: WebTransport?
    private var webSender: WebAudioSender?
    private var captureEngine: AudioCaptureEngine?
    private var sendPipeline: AudioSendPipeline?
    private var heartbeatTask: Task<Void, Never>?
    private var config: Config?

    /// 心跳间隔（秒）。
    private let heartbeatInterval: UInt64 = 5
    /// 心跳超时（秒，3 次未收到 Pong 判定断线）。
    private let heartbeatTimeout: UInt64 = 15
    /// 最近一次 Pong 时间。
    private var lastPongTime: Date = .distantPast

    public init() {}

    // MARK: - 启动
    /// 启动流式。对齐 `AudioEngine.kt:646-751`。
    public func start(_ config: Config) async {
        guard state == .idle || state == .error else { return }
        await MainActor.run { self.state = .connecting; self.lastError = nil }
        self.config = config

        if config.connectionMode == .web {
            await startWeb(config)
            return
        }

        do {
            // 1. 确定目标主机与传输模式
            let targetHost = config.connectionMode == .usb ? "127.0.0.1" : config.host
            let useUdp = config.connectionMode == .wifi && config.transportProtocol == .both

            // 2. TCP 连接 + 握手
            let tcp = TcpTransport()
            self.tcp = tcp
            try await tcp.connect(host: targetHost, port: config.port)
            try await tcp.performHandshake(sessionId: config.sessionId)

            // 3. UDP 连接（WiFi + Both）
            if useUdp {
                let udp = UdpTransport()
                self.udp = udp
                let udpPort = try calculateUdpPort(config.port)
                try await udp.connect(host: targetHost, port: udpPort)
            }

            // 4. 采集引擎（用 opusSampleRate 采集）
            let captureRate = captureRateFor(config.sampleRate)
            let captureEngine = AudioCaptureEngine(config: .init(
                sampleRate: captureRate, channelCount: config.channelCount))
            self.captureEngine = captureEngine

            // 5. 发送管线
            let opusRate = Int32(config.sampleRate.opusSampleRate)
            let channels = Int32(config.channelCount.rawValue)
            let wireFormat = Int32(config.audioFormat.resolved.rawValue)
            let pipeline = try AudioSendPipeline(
                opusSampleRate: opusRate, channels: channels,
                wireAudioFormat: wireFormat, sessionId: config.sessionId,
                tcp: tcp, udp: self.udp, useUdp: useUdp)
            self.sendPipeline = pipeline

            // 6. 接线回调
            captureEngine.onCapture = { [weak self] frame in
                self?.sendPipeline?.processFrame(frame)
            }
            captureEngine.onLevelUpdate = { [weak self] level in
                DispatchQueue.main.async { self?.audioLevel = level }
            }
            pipeline.onStatsUpdate = { [weak self] stats in
                DispatchQueue.main.async { self?.stats = stats }
            }

            // 7. 配置 AVAudioSession + 启动采集
            try setupAudioSession(sampleRate: Double(config.sampleRate.opusSampleRate))
            try captureEngine.start()

            // 8. TCP 接收循环（控制消息）
            tcp.startReceiving(onFrame: { [weak self] wrapper in
                self?.handleControlMessage(wrapper)
            }, onError: { [weak self] error in
                self?.handleReceiveError(error)
            })

            // 9. 心跳
            startHeartbeat()

            // 10. 完成
            lastPongTime = Date()
            await MainActor.run { self.state = .streaming }

        } catch {
            await handleError(error)
        }
    }

    // MARK: - Web 模式启动
    /// Web 模式：WebSocket Float32 PCM，无 protobuf/magic/握手/FEC。
    /// 对齐桌面 `web_server.rs:297-331`。
    private func startWeb(_ config: Config) async {
        do {
            // 1. WebSocket 连接
            let web = WebTransport()
            self.webTransport = web
            let webPort = config.port == WireConstants.defaultTcpPort
                ? WireConstants.defaultWebPort : config.port
            try await web.connect(host: config.host, port: webPort, useTLS: true)

            // 2. 采集引擎（Web 模式固定 48kHz mono）
            let captureEngine = AudioCaptureEngine(config: .init(
                sampleRate: .rate48000, channelCount: .mono))
            self.captureEngine = captureEngine

            // 3. Web 发送器
            let sender = WebAudioSender(transport: web)
            self.webSender = sender

            // 4. 接线回调
            captureEngine.onCapture = { [weak self] frame in
                self?.webSender?.processFrame(frame)
            }
            captureEngine.onLevelUpdate = { [weak self] level in
                DispatchQueue.main.async { self?.audioLevel = level }
            }

            // 5. 配置 AVAudioSession + 启动采集
            try setupAudioSession(sampleRate: 48000)
            try captureEngine.start()

            // 6. WebSocket 定期 ping 保活
            startWebHeartbeat()

            await MainActor.run { self.state = .streaming }

        } catch {
            await handleError(error)
        }
    }

    private func startWebHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)  // 10s
                guard let self = self, !Task.isCancelled else { break }
                try? await self.webTransport?.ping()
            }
        }
    }

    // MARK: - 停止
    /// 停止流式并清理所有资源。
    public func stop() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        captureEngine?.stop()
        captureEngine = nil
        sendPipeline?.reset()
        sendPipeline = nil
        webSender?.reset()
        webSender = nil
        udp?.close()
        udp = nil
        tcp?.close()
        tcp = nil
        webTransport?.close()
        webTransport = nil
        AudioSessionManager.shared.deactivate()
        DispatchQueue.main.async {
            self.state = .idle
            self.audioLevel = 0
        }
    }

    // MARK: - 静音
    /// 发送静音控制消息到服务端。对齐 Android `_isMuted` + MuteMessage。
    public func setMuted(_ muted: Bool) async {
        await MainActor.run { self.isMuted = muted }
        sendPipeline?.setMuted(muted)
        webSender?.setMuted(muted)
        // Web 模式无 TCP 控制通道，仅本地静音
        guard let tcp = tcp else { return }
        let wrapper = MessageWrapper(mute: MuteMessage(isMuted: muted))
        try? await tcp.sendFrame(wrapper)
    }

    // MARK: - AVAudioSession
    private func setupAudioSession(sampleRate: Double) throws {
        let session = AudioSessionManager.shared
        try session.configureForRecording(sampleRate: sampleRate)
        session.onInterruptionBegan = { [weak self] in
            DispatchQueue.main.async { self?.stop() }
        }
    }

    // MARK: - 心跳
    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: self?.heartbeatInterval ?? 5 * 1_000_000_000)
                guard let self = self, !Task.isCancelled else { break }
                await self.sendPing()
                self.checkHeartbeatTimeout()
            }
        }
    }

    private func sendPing() async {
        guard let tcp = tcp else { return }
        let wrapper = MessageWrapper(ping: PingMessage(timestamp: currentTimestampMs()))
        try? await tcp.sendFrame(wrapper)
    }

    private func checkHeartbeatTimeout() {
        let elapsed = Date().timeIntervalSince(lastPongTime)
        if elapsed > Double(heartbeatTimeout) {
            Task { await handleError(NetworkError.connectionClosed) }
        }
    }

    // MARK: - 接收处理
    private func handleControlMessage(_ wrapper: MessageWrapper) {
        if let pong = wrapper.pong {
            lastPongTime = Date()
            _ = pong
        }
        if let mute = wrapper.mute {
            DispatchQueue.main.async { self.isMuted = mute.isMuted ?? false }
            sendPipeline?.setMuted(mute.isMuted ?? false)
        }
    }

    private func handleReceiveError(_ error: Error) {
        Task { await handleError(error) }
    }

    // MARK: - 错误处理
    @MainActor
    private func handleError(_ error: Error) async {
        let msg: String
        if let netErr = error as? NetworkError {
            msg = netErr.localizedDescription
        } else if let audioErr = error as? AudioError {
            msg = "\(audioErr)"
        } else {
            msg = error.localizedDescription
        }
        state = .error
        lastError = msg
        // 清理资源
        heartbeatTask?.cancel()
        heartbeatTask = nil
        captureEngine?.stop()
        captureEngine = nil
        sendPipeline = nil
        webSender = nil
        udp?.close()
        udp = nil
        tcp?.close()
        tcp = nil
        webTransport?.close()
        webTransport = nil
        AudioSessionManager.shared.deactivate()
    }

    // MARK: - 辅助
    private func currentTimestampMs() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    /// 采集采样率：44100 → 48000（Opus 不支持 44100）。对齐 `opusSampleRate` 逻辑。
    private func captureRateFor(_ rate: SampleRate) -> SampleRate {
        switch rate.opusSampleRate {
        case 16000: return .rate16000
        default: return .rate48000
        }
    }

    deinit {
        heartbeatTask?.cancel()
        captureEngine?.stop()
        udp?.close()
        tcp?.close()
        webTransport?.close()
    }
}
