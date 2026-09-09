import Foundation

/// Web 模式音频发送器：Int16 PCM → Float32 LE → WebSocket。
///
/// 对齐桌面 `web_server.rs:297-331`：
/// - 48kHz / mono / Float32 LE PCM
/// - 每条消息 ≤ 64KB（16384 个 Float32 样本）
/// - 4 字节对齐（Float32 天然对齐）
/// - 无 protobuf / 无 magic / 无 FEC
public final class WebAudioSender {

    /// 单条 WebSocket 消息上限：64KB。对齐 `web_server.rs` MAX_FRAME。
    private static let maxMessageBytes = 64 * 1024
    /// 单条消息最大样本数 = 64KB / 4B。
    private static let maxSamplesPerMessage = maxMessageBytes / 4

    private weak var transport: WebTransport?
    private let sendQueue = DispatchQueue(label: "top.micyou.web.send", qos: .userInitiated)
    private var isMuted = false
    public private(set) var bytesSent: Int = 0
    public private(set) var messagesSent: Int = 0

    public init(transport: WebTransport) {
        self.transport = transport
    }

    /// 处理采集帧：Int16 → Float32 LE → 分块发送。
    public func processFrame(_ frame: CapturedFrame) {
        if isMuted { return }

        // 若立体声，混缩为单声道（Web 模式仅支持 mono）。
        let monoSamples: [Int16]
        if frame.channels == 1 {
            monoSamples = frame.samples
        } else {
            monoSamples = mixDownToMono(frame.samples, channels: frame.channels)
        }

        // Int16 → Float32 LE Data
        let floatData = convertToFloat32LE(monoSamples)
        guard !floatData.isEmpty else { return }

        // 分块发送（≤64KB）
        let chunkBytes = Self.maxMessageBytes
        var offset = 0
        while offset < floatData.count {
            let end = min(offset + chunkBytes, floatData.count)
            let chunk = floatData.subdata(in: offset..<end)
            let size = chunk.count
            sendQueue.async { [weak self] in
                guard let transport = self?.transport else { return }
                Task { try? await transport.send(chunk) }
            }
            offset = end
            bytesSent += size
            messagesSent += 1
        }
    }

    /// 设置静音。
    public func setMuted(_ muted: Bool) {
        isMuted = muted
    }

    /// 重置统计。
    public func reset() {
        bytesSent = 0
        messagesSent = 0
    }

    // MARK: - 转换
    /// Int16 → Float32 LE `Data`。对齐桌面 web_server Float32 解析。
    private func convertToFloat32LE(_ samples: [Int16]) -> Data {
        var data = Data(count: samples.count * MemoryLayout<Float32>.size)
        data.withUnsafeMutableBytes { rawBuf in
            let floatPtr = rawBuf.bindMemory(to: Float32.self)
            for i in 0..<samples.count {
                floatPtr[i] = Float32(samples[i]) / 32768.0
            }
        }
        return data
    }

    /// 立体声混缩为单声道（取平均）。
    private func mixDownToMono(_ samples: [Int16], channels: Int) -> [Int16] {
        let frameCount = samples.count / channels
        var mono = [Int16](repeating: 0, count: frameCount)
        for frame in 0..<frameCount {
            var sum: Int32 = 0
            for ch in 0..<channels {
                sum += Int32(samples[frame * channels + ch])
            }
            mono[frame] = Int16(sum / Int32(channels))
        }
        return mono
    }
}
