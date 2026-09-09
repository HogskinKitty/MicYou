import Foundation
import Network

/// 网络传输错误。对齐 Android `ConnectionException` / `IOException` 映射。
public enum NetworkError: Error, Equatable {
    case connectionFailed(String)
    case connectionCancelled
    case handshakeFailed(expected: String, actual: String)
    case sendFailed(String)
    case receiveFailed(String)
    case connectionClosed
    case invalidEndpoint(String)

    var localizedDescription: String {
        switch self {
        case .connectionFailed(let s): return "连接失败：\(s)"
        case .connectionCancelled: return "连接已取消"
        case .handshakeFailed(let e, let a): return "握手失败：期望 \(e)，收到 \(a)"
        case .sendFailed(let s): return "发送失败：\(s)"
        case .receiveFailed(let s): return "接收失败：\(s)"
        case .connectionClosed: return "连接已关闭"
        case .invalidEndpoint(let s): return "无效端点：\(s)"
        }
    }
}

/// 传输连接状态。对齐 Android `StreamState`（连接相关子集）。
public enum TransportState: Equatable {
    case idle
    case connecting
    case ready
    case failed(String)
    case cancelled
    case closed
}
