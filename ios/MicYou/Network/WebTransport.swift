import Foundation

/// WebSocket 传输层：基于 `URLSessionWebSocketTask`。
///
/// 对齐桌面 `web_server.rs:297-331`：Web 模式走 `wss://<ip>:8443/ws`，
/// 发送二进制 Float32 LE PCM（48k/mono/≤64KB/4 字节对齐），
/// 无 protobuf / 无 magic / 无握手。
public final class WebTransport: ObservableObject {

    @Published public private(set) var state: TransportState = .idle
    public var onStateChange: ((TransportState) -> Void)?

    private var task: URLSessionWebSocketTask?
    private let session: URLSession

    /// 是否使用 TLS（wss）。默认 true（端口 8443）。
    public var useTLS: Bool = true

    public init() {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    // MARK: - 连接
    /// 连接到 WebSocket。`wss://<host>:<port>/ws` 或 `ws://`。
    public func connect(host: String, port: Int, useTLS: Bool = true) async throws {
        self.useTLS = useTLS
        let scheme = useTLS ? "wss" : "ws"
        guard let url = URL(string: "\(scheme)://\(host):\(port)/ws") else {
            throw NetworkError.invalidEndpoint("\(scheme)://\(host):\(port)/ws")
        }

        let task = session.webSocketTask(with: url)
        self.task = task
        state = .connecting
        onStateChange?(.connecting)
        task.resume()

        // WebSocket 无 NWConnection 式 ready 回调；resume 后即视为已连接。
        // 发一个协议级 ping 验证连通性。
        do {
            try await ping()
            state = .ready
            onStateChange?(.ready)
        } catch {
            state = .failed(error.localizedDescription)
            onStateChange?(.failed(error.localizedDescription))
            throw NetworkError.connectionFailed(error.localizedDescription)
        }
    }

    // MARK: - 发送
    /// 发送二进制数据（Float32 LE PCM）。
    public func send(_ data: Data) async throws {
        guard let task = task else { throw NetworkError.connectionClosed }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            task.send(.data(data)) { error in
                if let error = error {
                    cont.resume(throwing: NetworkError.sendFailed(error.localizedDescription))
                } else {
                    cont.resume()
                }
            }
        }
    }

    /// 协议级 ping（验证连通性）。
    public func ping() async throws {
        guard let task = task else { throw NetworkError.connectionClosed }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            task.sendPing { error in
                if let error = error {
                    cont.resume(throwing: NetworkError.connectionFailed(error.localizedDescription))
                } else {
                    cont.resume()
                }
            }
        }
    }

    // MARK: - 接收
    /// 启动接收循环（Web 模式通常不需要接收，但保留用于服务端控制消息）。
    public func startReceiving(onMessage: @escaping (Data) -> Void,
                                onError: @escaping (Error) -> Void) {
        Task { [weak self] in
            while let self = self, self.state == .ready {
                do {
                    let msg = try await self.receive()
                    switch msg {
                    case .data(let data): onMessage(data)
                    case .string: break
                    @unknown default: break
                    }
                } catch {
                    onError(error)
                    break
                }
            }
        }
    }

    private func receive() async throws -> URLSessionWebSocketTask.Message {
        guard let task = task else { throw NetworkError.connectionClosed }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<URLSessionWebSocketTask.Message, Error>) in
            task.receive { result in
                switch result {
                case .success(let msg): cont.resume(returning: msg)
                case .failure(let err): cont.resume(throwing: NetworkError.receiveFailed(err.localizedDescription))
                }
            }
        }
    }

    // MARK: - 关闭
    public func close() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        state = .closed
        onStateChange?(.closed)
    }

    deinit {
        task?.cancel(with: .goingAway, reason: nil)
    }
}
