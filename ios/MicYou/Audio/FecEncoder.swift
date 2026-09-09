import Foundation

/// FEC（前向纠错）编码器：每 12 个 Opus 包生成一个 XOR FEC 包。
///
/// 对齐 Android `AudioEngine.kt:972-1003` + `xorBuffers`（:1197-1206）：
/// - 收集 Opus 编码包到 `fecGroupBuffer`
/// - 满 `FEC_GROUP_SIZE`(12) 后：XOR 所有包 → FEC 包
/// - FEC 包 `fecBuffer = [0x01]`（标记），`fecSequenceNumber = fecGroupStartSeq`，
///   `fecPacketLengths = 各包长度`（处理变长 Opus 包）
/// - FEC 包的 `sequenceNumber` = 当前序列号（不递增，与下一个常规包共享）
/// - 重置组，`fecGroupStartSeq = 当前序列号`
public final class FecEncoder {
    private var fecGroupBuffer: [Data] = []
    private var fecGroupStartSeq: Int32 = 0
    private var sequenceNumber: Int32 = 0

    /// FEC 组信息（满组时返回）。
    public struct FecGroup {
        /// XOR 载荷（各 Opus 包异或结果），放入 AudioPacketMessage.buffer。
        public let xorPayload: Data
        /// FEC 标记字节 `[0x01]`。
        public let fecBuffer: Data
        /// 本组首个常规包的序列号。
        public let fecSequenceNumber: Int32
        /// 组内各 Opus 包的原始长度。
        public let fecPacketLengths: [UInt32]
    }

    public init() {}

    /// 获取并递增序列号（常规包用）。对齐 `sequenceNumber = sequenceNumber++`。
    public func nextSequenceNumber() -> Int32 {
        let seq = sequenceNumber
        sequenceNumber &+= 1
        return seq
    }

    /// 当前序列号（FEC 包用，不递增）。
    public func currentSequenceNumber() -> Int32 {
        sequenceNumber
    }

    /// 处理一个已发送的 Opus 包，满组时返回 FEC 信息。
    /// - Parameter encoded: Opus 编码字节
    /// - Returns: 满组时返回 `FecGroup`，否则 nil
    public func processPacket(_ encoded: Data) -> FecGroup? {
        fecGroupBuffer.append(encoded)
        guard fecGroupBuffer.count >= WireConstants.fecGroupSize else { return nil }

        let xorResult = xorBuffers(fecGroupBuffer)
        let group = FecGroup(
            xorPayload: xorResult,
            fecBuffer: Data([0x01]),
            fecSequenceNumber: fecGroupStartSeq,
            fecPacketLengths: fecGroupBuffer.map { UInt32($0.count) }
        )
        fecGroupBuffer.removeAll()
        fecGroupStartSeq = sequenceNumber
        return group
    }

    /// 重置状态（新会话用）。
    public func reset() {
        fecGroupBuffer.removeAll()
        fecGroupStartSeq = 0
        sequenceNumber = 0
    }

    // MARK: - XOR
    /// XOR 所有缓冲区，结果长度 = 最长缓冲区。对齐 `AudioEngine.kt:1197-1206`。
    private func xorBuffers(_ buffers: [Data]) -> Data {
        let maxLen = buffers.map { $0.count }.max() ?? 0
        var result = Data(count: maxLen)
        for buf in buffers {
            for i in 0..<buf.count {
                result[i] ^= buf[i]
            }
        }
        return result
    }
}
