import Foundation

/// TCP/UDP 帧编解码。对齐 Android `AudioEngine.kt` 的 `writeInt(PACKET_MAGIC)`/`DatagramPacket`。
///
/// TCP 帧：`[PACKET_MAGIC 4B BE][length 4B BE][protobuf MessageWrapper]`
/// UDP 帧：`[UDP_PACKET_MAGIC 4B BE][length 4B BE][protobuf MessageWrapper]`
public enum FrameCodec {
    /// 编码 TCP 帧。对齐 `AudioEngine.kt:660`（writeInt magic + length + payload）。
    public static func encodeTcp(_ wrapper: MessageWrapper) throws -> Data {
        let payload = wrapper.serializedData()
        guard payload.count <= WireConstants.maxPacketSize else {
            throw WireError.packetTooLarge(size: payload.count)
        }
        var frame = Data(capacity: 8 + payload.count)
        frame.appendBE(WireConstants.packetMagic)
        frame.appendBE(UInt32(payload.count))
        frame.append(payload)
        return frame
    }

    /// 编码 UDP 帧（含大小校验）。对齐 `AudioEngine.kt:1218`。
    public static func encodeUdp(_ wrapper: MessageWrapper) throws -> Data {
        let payload = wrapper.serializedData()
        let total = WireConstants.udpCustomHeaderSize + payload.count
        guard total <= WireConstants.udpMaxDatagramSize else {
            throw WireError.udpDatagramTooLarge(size: total)
        }
        var frame = Data(capacity: total)
        frame.appendBE(WireConstants.udpPacketMagic)
        frame.appendBE(UInt32(payload.count))
        frame.append(payload)
        return frame
    }

    /// 从完整 UDP 数据报解码为 MessageWrapper。对齐桌面 `udp_server` 解析。
    public static func decodeUdp(_ datagram: Data) throws -> MessageWrapper {
        guard datagram.count >= WireConstants.udpCustomHeaderSize else {
            throw WireError.truncated
        }
        let magic = datagram.readBE(at: 0)
        guard magic == WireConstants.udpPacketMagic else {
            throw WireError.invalidMagic(expected: WireConstants.udpPacketMagic, actual: magic)
        }
        let length = Int(datagram.readBE(at: 4))
        let start = WireConstants.udpCustomHeaderSize
        guard start + length <= datagram.count else { throw WireError.truncated }
        let payload = datagram.subdata(in: (datagram.startIndex + start)..<(datagram.startIndex + start + length))
        return try MessageWrapper(serializedData: payload)
    }
}

/// 流式 TCP 帧读取器：累积字节，弹出完整帧。对齐桌面 `tcp_server` 的分帧循环。
public final class TcpFrameReader {
    private var buffer = Data()

    public init() {}

    /// 追加新到达的字节。
    public func append(_ data: Data) {
        buffer.append(data)
    }

    /// 弹出所有已完整的帧；剩余不完整数据留在缓冲区。
    /// - Returns: 解码出的 MessageWrapper 数组（可能为空）
    public func popFrames() throws -> [MessageWrapper] {
        var frames: [MessageWrapper] = []
        while true {
            guard buffer.count >= 8 else { return frames }
            let magic = buffer.readBE(at: 0)
            guard magic == WireConstants.packetMagic else {
                throw WireError.invalidMagic(expected: WireConstants.packetMagic, actual: magic)
            }
            let length = Int(buffer.readBE(at: 4))
            guard length <= WireConstants.maxPacketSize else {
                throw WireError.packetTooLarge(size: length)
            }
            guard buffer.count >= 8 + length else { return frames }   // 等待更多数据
            let payload = buffer.subdata(in: (buffer.startIndex + 8)..<(buffer.startIndex + 8 + length))
            frames.append(try MessageWrapper(serializedData: payload))
            buffer.removeFirst(8 + length)
        }
    }

    /// 当前缓冲区中未成帧的字节数（诊断用）。
    public var pendingByteCount: Int { buffer.count }

    /// 重置缓冲区。
    public func reset() { buffer.removeAll(keepingCapacity: true) }
}

// MARK: - Data big-endian 辅助
extension Data {
    func readBE(at offset: Int) -> UInt32 {
        let i = startIndex + offset
        return (UInt32(self[i]) << 24)
             | (UInt32(self[i + 1]) << 16)
             | (UInt32(self[i + 2]) << 8)
             | UInt32(self[i + 3])
    }

    mutating func appendBE(_ value: UInt32) {
        append(UInt8((value >> 24) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8(value & 0xFF))
    }
}
