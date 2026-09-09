import Foundation
import MicYouOpus

/// 音频发送管线：PCM 累积 → Opus 编码 → 封包 → 发送 → FEC。
///
/// 对齐 Android `AudioEngine.kt:925-1006`：
/// 1. 累积 Int16 PCM 到 20ms 帧
/// 2. Opus 编码 → AudioPacketMessage(codec=OPUS)
/// 3. AudioPacketMessageOrdered(sequenceNumber, timestamp, sessionId) → MessageWrapper
/// 4. UDP 模式：音频走 UDP + FEC；TCP 模式：音频走 TCP（无 FEC）
/// 5. FEC：每 12 包 XOR 生成 FEC 包，fecBuffer=[0x01]
///
/// 在音频线程调用 `processFrame`；编码同步（Opus 实时安全），网络发送派发到后台队列。
public final class AudioSendPipeline {

    // MARK: - 统计
    public struct Stats {
        public var packetsSent: Int = 0
        public var fecPacketsSent: Int = 0
        public var bytesSent: Int = 0
    }

    // MARK: - 配置
    private let opusEncoder: OpusEncoder
    private let fecEncoder = FecEncoder()
    private let opusSampleRate: Int32
    private let opusChannels: Int32
    private let wireAudioFormat: Int32
    private let frameSizePerChannel: Int32
    private let frameSampleCount: Int
    private var sessionId: Int64

    // MARK: - PCM 累积
    private var pcmAccumulator: [Int16] = []
    private var isMuted = false

    // MARK: - 传输
    private weak var tcp: TcpTransport?
    private weak var udp: UdpTransport?
    private let useUdp: Bool
    private let sendQueue = DispatchQueue(label: "top.micyou.audio.send", qos: .userInitiated)

    // MARK: - 统计
    public private(set) var stats = Stats()
    public var onStatsUpdate: ((Stats) -> Void)?

    /// 创建发送管线。
    /// - Parameters:
    ///   - opusSampleRate: Opus 采样率（8000/12000/16000/24000/48000）
    ///   - channels: 声道数（1=mono, 2=stereo）
    ///   - wireAudioFormat: 线上协议音频格式值（AudioFormatType.rawValue）
    ///   - sessionId: 会话 ID
    ///   - tcp: TCP 传输（控制 + TCP-only 音频）
    ///   - udp: UDP 传输（音频，可为 nil）
    ///   - useUdp: 是否用 UDP 发音频（Both 模式 + WiFi）
    public init(opusSampleRate: Int32, channels: Int32, wireAudioFormat: Int32,
                sessionId: Int64, tcp: TcpTransport, udp: UdpTransport?,
                useUdp: Bool) throws {
        self.opusSampleRate = opusSampleRate
        self.opusChannels = channels
        self.wireAudioFormat = wireAudioFormat
        self.frameSizePerChannel = opusSampleRate * 20 / 1000
        self.frameSampleCount = Int(frameSizePerChannel) * Int(channels)
        self.sessionId = sessionId
        self.tcp = tcp
        self.udp = udp
        self.useUdp = useUdp
        self.opusEncoder = try OpusEncoder(
            sampleRate: opusSampleRate, channels: channels,
            application: OpusEncoder.applicationVoIP)
        self.opusEncoder.setComplexity(5)
    }

    // MARK: - 处理采集帧
    /// 处理来自 AudioCaptureEngine 的采集帧。在音频线程调用。
    public func processFrame(_ frame: CapturedFrame) {
        // 静音时丢弃累积 PCM，避免恢复后发出残留音频。对齐 :1009-1011。
        if isMuted {
            pcmAccumulator.removeAll()
            return
        }

        pcmAccumulator.append(contentsOf: frame.samples)

        // 每凑满 20ms 帧就编码并发送。对齐 :938-1006。
        while pcmAccumulator.count >= frameSampleCount {
            let frameSamples = Array(pcmAccumulator.prefix(frameSampleCount))
            pcmAccumulator.removeFirst(frameSampleCount)
            encodeAndSend(frameSamples)
        }
    }

    /// 设置静音。对齐 Android `_isMuted`。
    public func setMuted(_ muted: Bool) {
        isMuted = muted
    }

    /// 更新会话 ID（重连后）。
    public func updateSessionId(_ id: Int64) {
        sessionId = id
    }

    // MARK: - 编码 + 发送
    private func encodeAndSend(_ pcm: [Int16]) {
        let encoded = opusEncoder.encode(pcm, frameSize: frameSizePerChannel)
        guard !encoded.isEmpty else { return }
        let encodedData = Data(encoded)
        let now = currentTimestampMs()

        // 常规包
        let seq = fecEncoder.nextSequenceNumber()
        let packet = AudioPacketMessage(
            buffer: encodedData,
            sampleRate: opusSampleRate,
            channelCount: opusChannels,
            audioFormat: wireAudioFormat,
            codec: WireConstants.codecOpus
        )
        let wrapper = MessageWrapper(audioPacket: AudioPacketMessageOrdered(
            sequenceNumber: seq, audioPacket: packet,
            timestamp: now, sessionId: sessionId
        ))
        sendWrapper(wrapper, payloadSize: encodedData.count)
        stats.packetsSent += 1

        // FEC（仅 UDP 模式）。对齐 :972-1003。
        if useUdp, let fecGroup = fecEncoder.processPacket(encodedData) {
            let fecPacket = AudioPacketMessage(
                buffer: fecGroup.xorPayload,
                sampleRate: opusSampleRate,
                channelCount: opusChannels,
                audioFormat: wireAudioFormat,
                codec: WireConstants.codecOpus
            )
            let fecWrapper = MessageWrapper(audioPacket: AudioPacketMessageOrdered(
                sequenceNumber: fecEncoder.currentSequenceNumber(),
                audioPacket: fecPacket,
                timestamp: currentTimestampMs(),
                fecBuffer: fecGroup.fecBuffer,
                fecSequenceNumber: fecGroup.fecSequenceNumber,
                sessionId: sessionId,
                fecPacketLengths: fecGroup.fecPacketLengths
            ))
            sendWrapper(fecWrapper, payloadSize: fecGroup.xorPayload.count)
            stats.fecPacketsSent += 1
        }

        onStatsUpdate?(stats)
    }

    // MARK: - 发送
    private func sendWrapper(_ wrapper: MessageWrapper, payloadSize: Int) {
        let useUdp = self.useUdp
        let udp = self.udp
        let tcp = self.tcp
        let size = payloadSize
        sendQueue.async {
            if useUdp, let udp = udp {
                Task { try? await udp.sendDatagram(wrapper) }
            } else if let tcp = tcp {
                Task { try? await tcp.sendFrame(wrapper) }
            }
        }
        stats.bytesSent += size
    }

    // MARK: - 重置
    public func reset() {
        pcmAccumulator.removeAll()
        fecEncoder.reset()
        stats = Stats()
    }

    // MARK: - 辅助
    private func currentTimestampMs() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}
