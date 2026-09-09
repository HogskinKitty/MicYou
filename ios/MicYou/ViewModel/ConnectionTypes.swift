import Foundation

/// 连接模式。对齐 Android `MainViewModel.kt:48-51` + iOS Web 扩展。
public enum ConnectionMode: String, CaseIterable, Codable {
    case wifi
    case usb
    case web

    public var label: String {
        switch self {
        case .wifi: return "Wi-Fi"
        case .usb: return "USB (iproxy)"
        case .web: return "Web"
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
        case .tcp: return "TCP"
        case .both: return "TCP+UDP"
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
        case .idle: return "待机"
        case .connecting: return "连接中…"
        case .streaming: return "流式中"
        case .error: return "错误"
        }
    }
}
