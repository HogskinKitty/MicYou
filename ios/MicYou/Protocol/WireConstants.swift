import Foundation

/// 线上协议常量。逐项对齐 Android `network/Protocol.kt` + `util/Constants.kt`。
///
/// 来源事实：`composeApp/.../network/Protocol.kt:121-133`、`util/Constants.kt:28-46`、
/// `audio/AudioEngine.kt:285-291`。
public enum WireConstants {
    /// TCP 帧魔数 "MicY"（ASCII）。`Protocol.kt:121`
    public static let packetMagic: UInt32 = 0x4D696359
    /// UDP 帧魔数 "MicU"（ASCII）。`Protocol.kt:122`
    public static let udpPacketMagic: UInt32 = 0x4D696355
    /// UDP 自定义头长度（magic 4 + length 4）。`Protocol.kt:123`
    public static let udpCustomHeaderSize: Int = 8
    /// UDP 数据报上限。`Protocol.kt:124`
    public static let udpMaxDatagramSize: Int = 1472
    /// UDP PCM 载荷预算。`Protocol.kt:126`
    public static let udpPcmPayloadSize: Int = 1320
    /// buffer 编码：PCM。`Protocol.kt:129`
    public static let codecPCM: Int32 = 0
    /// buffer 编码：Opus。`Protocol.kt:130`
    public static let codecOpus: Int32 = 1
    /// UDP 端口 = TCP + 1。`Protocol.kt:133`
    public static let udpPortOffset: Int = 1
    /// 默认 TCP 端口。`Constants.kt:34`
    public static let defaultTcpPort: Int = 8554
    /// 默认 UDP 端口。`Constants.kt:37`
    public static let defaultUdpPort: Int = 8555
    /// TCP 包上限 2MiB。`Constants.kt:28`
    public static let maxPacketSize: Int = 2 * 1024 * 1024
    /// FEC 组大小：每 12 包一组。`AudioEngine.kt:291`
    public static let fecGroupSize: Int = 12
    /// UDP 连续失败熔断阈值。`AudioEngine.kt:285`
    public static let maxUdpConsecutiveFailures: Int = 500
    /// 心跳超时 5s。`AudioEngine.kt:286`
    public static let heartbeatTimeoutMs: Int64 = 5000
    /// TCP 握手客户端→服务端。`AudioEngine.kt:625`
    public static let handshakeClient = "MicYouCheck1"
    /// TCP 握手服务端→客户端。`AudioEngine.kt:626`
    public static let handshakeServer = "MicYouCheck2"
    /// 默认 Web 模式端口。`app_config.rs:166`
    public static let defaultWebPort: Int = 8443
}

/// 计算 UDP 端口 = TCP + 1，带边界校验。对齐 `Protocol.kt:141`。
/// - Parameter tcpPort: TCP 端口
/// - Returns: UDP 端口
/// - Throws: `WireError.portOverflow` 当结果超出 0...65535
public func calculateUdpPort(_ tcpPort: Int) throws -> Int {
    let udpPort = tcpPort + WireConstants.udpPortOffset
    guard (0...65535).contains(udpPort) else {
        throw WireError.portOverflow(tcpPort: tcpPort)
    }
    return udpPort
}

/// 线上协议错误。
public enum WireError: Error, Equatable {
    case portOverflow(tcpPort: Int)
    case invalidMagic(expected: UInt32, actual: UInt32)
    case packetTooLarge(size: Int)
    case udpDatagramTooLarge(size: Int)
    case truncated
    case handshakeFailed(expected: String, actual: String)
    case decodeFailed(String)
}
