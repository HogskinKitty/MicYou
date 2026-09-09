import Foundation

/// 发现的 MicYou 设备。对齐 Android `DiscoveredDevice`（`DeviceDiscovery.kt`）。
public struct DiscoveredDevice: Identifiable, Hashable {
    /// 唯一 ID = Bonjour 服务名。
    public let id: String
    /// Bonjour 服务名（设备显示名）。
    public let name: String
    /// 解析后的 IPv4 地址（优先用于连接）。
    public var ipAddress: String?
    /// 主机名（如 "MacBook.local."，ipAddress 为空时回退）。
    public var hostName: String?
    /// 端口。
    public var port: Int

    /// 用于连接的主机：优先 IPv4，回退 hostName。
    public var connectHost: String? { ipAddress ?? hostName }

    public init(id: String, name: String, ipAddress: String? = nil,
                hostName: String? = nil, port: Int = 0) {
        self.id = id; self.name = name
        self.ipAddress = ipAddress; self.hostName = hostName; self.port = port
    }
}
