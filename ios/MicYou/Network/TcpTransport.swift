import Foundation
import Network

/// TCP 传输层：基于 `NWConnection(.tcp)`，含 MicYou 握手与流式帧接收。
///
/// 对齐 Android `AudioEngine.kt:650-718`：
/// 1. TCP connect（keepAlive, noDelay）
/// 2. 握手：client → "MicYouCheck1"（12B 裸字节）→ server "MicYouCheck2"（12B）
///    → client 发 ConnectMessage{sessionId} 的 TCP 帧（magic+length+protobuf）
/// 3. 控制消息（mute/ping/pong）走 TCP 帧
/// 4. 接收循环：流式 `receive` → `TcpFrameReader` → 回调 `MessageWrapper`
public final class TcpTransport {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "top.micyou.tcp", qos: .userInitiated)
    private let frameReader = TcpFrameReader()
    private var receiving = false
    private var onFrame: ((MessageWrapper) -> Void)?
    private var onError: ((Error) -> Void)?

    /// 状态变更回调（UI 观察）。
    public var onStateChange: ((TransportState) -> Void)?

    public init() {}

    // MARK: - 连接
    /// 连接到 `host:port`。await 直到 NWConnection `.ready`。
    public func connect(host: String, port: Int) async throws {
        guard let nwHost = NWEndpoint.Host(host) else {
            throw NetworkError.invalidEndpoint(host)
        }
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            throw NetworkError.invalidEndpoint("\(port)")
        }
        let conn = NWConnection(host: nwHost, port: nwPort, using: .tcp)
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

    // MARK: - 握手
    /// 执行 MicYou 三步握手。对齐 `AudioEngine.kt:699-718`。
    public func performHandshake(sessionId: Int64) async throws {
        // 1. 发送 "MicYouCheck1"
        let check1 = Data(WireConstants.handshakeClient.utf8)
        try await sendRaw(check1)

        // 2. 读取 "MicYouCheck2"（12 字节）
        let response = try await readExactly(WireConstants.handshakeServer.utf8.count)
        let responseStr = String(data: response, encoding: .utf8) ?? ""
        guard responseStr == WireConstants.handshakeServer else {
            throw NetworkError.handshakeFailed(
                expected: WireConstants.handshakeServer, actual: responseStr)
        }

        // 3. 发送 ConnectMessage{sessionId} 的 TCP 帧
        let wrapper = MessageWrapper(connect: ConnectMessage(sessionId: sessionId))
        let frame = try FrameCodec.encodeTcp(wrapper)
        try await sendRaw(frame)
    }

    // MARK: - 发送
    /// 发送一个 MessageWrapper 的 TCP 帧。对齐 `AudioEngine.kt:772-777`。
    public func sendFrame(_ wrapper: MessageWrapper) async throws {
        let frame = try FrameCodec.encodeTcp(wrapper)
        try await sendRaw(frame)
    }

    /// 发送裸字节（握手 / 帧均可）。
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

    // MARK: - 接收
    /// 启动流式接收循环。每收到一个完整 `MessageWrapper` 调 `onFrame`；出错调 `onError`。
    /// 幂等：重复调用会先停旧循环。
    public func startReceiving(
        onFrame: @escaping (MessageWrapper) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.onFrame = onFrame
        self.onError = onError
        receiving = true
        scheduleReceive()
    }

    public func stopReceiving() {
        receiving = false
    }

    private func scheduleReceive() {
        guard receiving, let conn = connection else { return }
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self, self.receiving else { return }
            if let error = error {
                self.onError?(NetworkError.receiveFailed(error.localizedDescription))
                self.onStateChange?(.failed(error.localizedDescription))
                return
            }
            if let data = data, !data.isEmpty {
                self.frameReader.append(data)
                do {
                    let frames = try self.frameReader.popFrames()
                    for frame in frames {
                        self.onFrame?(frame)
                    }
                } catch {
                    self.onError?(error)
                    return
                }
            }
            if isComplete {
                self.receiving = false
                self.onStateChange?(.closed)
                self.onError?(NetworkError.connectionClosed)
                return
            }
            self.scheduleReceive()
        }
    }

    // MARK: - 读取精确字节数（握手用）
    private func readExactly(_ count: Int) async throws -> Data {
        var accumulated = Data()
        while accumulated.count < count {
            let remaining = count - accumulated.count
            let chunk = try await receiveChunk(min: 1, max: remaining)
            if chunk.isEmpty {
                throw NetworkError.connectionClosed
            }
            accumulated.append(chunk)
        }
        return accumulated
    }

    private func receiveChunk(min: Int, max: Int) async throws -> Data {
        guard let conn = connection else { throw NetworkError.connectionClosed }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
            conn.receive(minimumIncompleteLength: min, maximumLength: max) { data, _, isComplete, error in
                if let error = error {
                    cont.resume(throwing: NetworkError.receiveFailed(error.localizedDescription))
                } else if isComplete && (data == nil || data!.isEmpty) {
                    cont.resume(throwing: NetworkError.connectionClosed)
                } else {
                    cont.resume(returning: data ?? Data())
                }
            }
        }
    }

    // MARK: - 关闭
    public func close() {
        receiving = false
        frameReader.reset()
        connection?.cancel()
        connection = nil
        onStateChange?(.closed)
    }

    deinit {
        connection?.cancel()
    }
}
