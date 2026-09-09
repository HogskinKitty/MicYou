import Foundation
import Network

/// UDP 传输层：基于 `NWConnection(.udp)`，仅发送音频数据报。
///
/// 对齐 Android `AudioEngine.kt:671-688, 1208-1218`：
/// - UDP "connect" = 设置默认远端端点（NWConnection 连接式 UDP）
/// - 发送：`[UDP_PACKET_MAGIC][length][protobuf]` 数据报
/// - 音频单向（client → server），不接收
public final class UdpTransport {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "top.micyou.udp", qos: .userInitiated)

    /// 状态变更回调。
    public var onStateChange: ((TransportState) -> Void)?

    public init() {}

    // MARK: - 连接
    /// 连接到 `host:port`（连接式 UDP，设置默认远端）。await 直到 `.ready`。
    public func connect(host: String, port: Int) async throws {
        guard let nwHost = NWEndpoint.Host(host) else {
            throw NetworkError.invalidEndpoint(host)
        }
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            throw NetworkError.invalidEndpoint("\(port)")
        }
        let conn = NWConnection(host: nwHost, port: nwPort, using: .udp)
        connection = conn

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            conn.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.onStateChange?(.ready)
                    cont.resume()
                case .failed(let err):
                    self?.onStateChange?(.failed(err.localizedDescription))
                    cont.resume(throwing: NetworkError.connectionFailed(err.localizedDescription))
                case .cancelled:
                    self?.onStateChange?(.cancelled)
                    cont.resume(throwing: NetworkError.connectionCancelled)
                default:
                    break
                }
            }
            conn.start(queue: queue)
        }
    }

    // MARK: - 发送
    /// 发送一个 MessageWrapper 的 UDP 帧。对齐 `AudioEngine.kt:1208-1218`。
    /// - Throws: `WireError.udpDatagramTooLarge` 当超过 MTU
    public func sendDatagram(_ wrapper: MessageWrapper) async throws {
        let datagram = try FrameCodec.encodeUdp(wrapper)
        try await sendRaw(datagram)
    }

    /// 发送裸数据报。
    public func sendRaw(_ data: Data) async throws {
        guard let conn = connection else { throw NetworkError.connectionClosed }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            conn.send(content: data, completion: { error in
                if let error = error {
                    cont.resume(throwing: NetworkError.sendFailed(error.localizedDescription))
                } else {
                    cont.resume()
                }
            })
        }
    }

    // MARK: - 关闭
    public func close() {
        connection?.cancel()
        connection = nil
        onStateChange?(.closed)
    }

    deinit {
        connection?.cancel()
    }
}
