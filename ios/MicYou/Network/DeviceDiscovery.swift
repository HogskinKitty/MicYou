import Foundation
import Darwin

/// mDNS/Bonjour 设备发现。对齐 Android `DeviceDiscovery.kt`（NsdManager `_micyou._tcp.`）。
///
/// 使用 `NetServiceBrowser` 搜索 `_micyou._tcp.` 服务，逐个 `NetService.resolve()`
/// 取 IPv4 地址。UI 线程驱动（run loop 主线程）。
public final class DeviceDiscovery: NSObject, ObservableObject {
    /// Bonjour 服务类型。对齐 Android `_micyou._tcp.`。
    public static let serviceType = "_micyou._tcp."
    /// 搜索域（空串 = 本地域 local.）。
    public static let searchDomain = ""

    /// 已发现的设备列表。
    @Published public private(set) var devices: [DiscoveredDevice] = []
    /// 是否正在搜索。
    @Published public private(set) var isBrowsing = false
    /// 最近错误。
    @Published public var lastError: String?

    private let browser = NetServiceBrowser()
    /// 待解析/已解析的服务引用（保持存活）。
    private var resolvingServices: [String: NetService] = [:]

    public override init() {
        super.init()
    }

    // MARK: - 搜索控制
    /// 开始搜索 `_micyou._tcp.` 服务。
    public func startBrowsing() {
        guard !isBrowsing else { return }
        devices.removeAll()
        resolvingServices.removeAll()
        lastError = nil
        browser.delegate = self
        browser.searchForServices(ofType: Self.serviceType, inDomain: Self.searchDomain)
        isBrowsing = true
    }

    /// 停止搜索。
    public func stopBrowsing() {
        guard isBrowsing else { return }
        browser.stop()
        browser.delegate = nil
        resolvingServices.removeAll()
        isBrowsing = false
    }

    /// 手动添加一个设备（手动输入 IP 时用）。
    public func addManualDevice(name: String, host: String, port: Int) {
        let device = DiscoveredDevice(id: "manual-\(host):\(port)", name: name,
                                      ipAddress: host, port: port)
        if let idx = devices.firstIndex(where: { $0.id == device.id }) {
            devices[idx] = device
        } else {
            devices.append(device)
        }
    }
}

// MARK: - NetServiceBrowserDelegate
extension DeviceDiscovery: NetServiceBrowserDelegate {
    public func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        isBrowsing = true
    }

    public func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        isBrowsing = false
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser,
                                  didNotSearch errorDict: [String: NSNumber]) {
        lastError = errorDict[NetServicesError]?.stringValue ?? "搜索失败"
        isBrowsing = false
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser,
                                  foundService service: NetService,
                                  moreComing: Bool) {
        let name = service.name
        let device = DiscoveredDevice(id: name, name: name, port: Int(service.port))
        devices.append(device)

        // 解析地址
        service.delegate = self
        resolvingServices[name] = service
        service.resolve(withTimeout: 5.0)
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser,
                                  removedService service: NetService,
                                  moreComing: Bool) {
        devices.removeAll { $0.id == service.name }
        resolvingServices.removeValue(forKey: service.name)
    }
}

// MARK: - NetServiceDelegate
extension DeviceDiscovery: NetServiceDelegate {
    public func netServiceDidResolveAddress(_ sender: NetService) {
        let name = sender.name
        let ipAddress = sender.addresses?.compactMap { Self.extractIPv4(from: $0) }.first
        let hostName = sender.hostName

        if let idx = devices.firstIndex(where: { $0.id == name }) {
            devices[idx].ipAddress = ipAddress
            devices[idx].hostName = hostName
            devices[idx].port = Int(sender.port)
        }
        // 解析完成，可释放引用（保留以备后续更新）
    }

    public func netService(_ sender: NetService,
                           didNotResolve errorDict: [String: NSNumber]) {
        // 解析失败：保留设备条目（用户可手动连接），仅记日志
        resolvingServices.removeValue(forKey: sender.name)
    }
}

// MARK: - sockaddr 解析
extension DeviceDiscovery {
    /// 从 sockaddr `Data` 提取 IPv4 字符串。对齐 Android `NsdManager` 地址解析。
    static func extractIPv4(from data: Data) -> String? {
        data.withUnsafeBytes { rawBuffer -> String? in
            guard let base = rawBuffer.baseAddress else { return nil }
            let sa = base.assumingMemoryBound(to: sockaddr.self)
            guard sa.pointee.sa_family == sa_family_t(AF_INET) else { return nil }
            let sin = base.assumingMemoryBound(to: sockaddr_in.self)
            var addr = sin.pointee.sin_addr
            var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            let result = inet_ntop(AF_INET, &addr, &buf, socklen_t(INET_ADDRSTRLEN))
            guard result != nil else { return nil }
            return String(cString: buf)
        }
    }
}
