import Foundation

/// 连接模式。对齐 Android `MainViewModel.kt:48-51` + iOS Web 扩展。
public enum ConnectionMode: String, CaseIterable, Codable {
    case wifi
    case usb
    case web

    public var label: String {
        switch self {
        case .wifi: return L10n.s("connection.wifi")
        case .usb: return L10n.s("connection.usb")
        case .web: return L10n.s("connection.web")
        }
    }

    public var icon: String {
        switch self {
        case .wifi: return "wifi"
        case .usb: return "cable.connector"
        case .web: return "globe"
        }
    }
}

/// 传输协议。对齐 Android `MainViewModel.kt:53-56`。
public enum TransportProtocol: String, CaseIterable, Codable {
    case tcp
    case both

    public var label: String {
        switch self {
        case .tcp: return L10n.s("connection.tcp")
        case .both: return L10n.s("connection.both")
        }
    }
}

/// 流式状态。对齐 Android `MainViewModel.kt:58-60`。
public enum StreamState: String, Equatable {
    case idle
    case connecting
    case streaming
    case error

    public var label: String {
        switch self {
        case .idle: return L10n.s("state.idle")
        case .connecting: return L10n.s("state.connecting")
        case .streaming: return L10n.s("state.streaming")
        case .error: return L10n.s("state.error")
        }
    }
}
