import Foundation
import AVFAudio

/// AVAudioSession 管理器。对齐 Android `AudioEngine.kt` session 配置 + 生命周期。
///
/// 职责：
/// 1. 配置 .playAndRecord + .voiceChat（VOIP 优化）
/// 2. 20ms IO buffer（低延迟）
/// 3. 中断处理（来电/闹钟 → 暂停；结束 → 可恢复）
/// 4. 路由变更（耳机/蓝牙连接断开）
/// 5. 后台音频（Info.plist UIBackgroundModes=audio）
public final class AudioSessionManager: NSObject {

    public static let shared = AudioSessionManager()

    /// 中断开始时调用（UI 可据此停止流式）。
    public var onInterruptionBegan: (() -> Void)?
    /// 中断结束且可恢复时调用。
    public var onInterruptionEnded: (() -> Void)?
    /// 路由变更时调用。
    public var onRouteChange: ((AVAudioSession.RouteChangeReason) -> Void)?

    private var observers: [NSObjectProtocol] = []
    private(set) var isActive = false

    private override init() {
        super.init()
    }

    // MARK: - 配置
    /// 配置录音会话。在 AudioEngine.start() 前调用。
    public func configureForRecording(sampleRate: Double = 48000) throws {
        let session = AVAudioSession.sharedInstance()

        // .playAndRecord: 需要同时录音和监听
        // .voiceChat: VOIP 优化（自动回声消除、降噪）
        // .allowBluetoothA2DP: 支持蓝牙 A2DP 输出
        // .defaultToSpeaker: 默认扬声器输出
        try session.setCategory(.playAndRecord,
                                mode: .voiceChat,
                                options: [.allowBluetoothA2DP, .defaultToSpeaker])
        try session.setPreferredSampleRate(sampleRate)
        try session.setPreferredIOBufferDuration(0.02)  // 20ms 低延迟
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        isActive = true
        registerNotifications()
    }

    /// 停用会话。
    public func deactivate() {
        guard isActive else { return }
        try? AVAudioSession.sharedInstance().setActive(
            false, options: .notifyOthersOnDeactivation)
        isActive = false
        unregisterNotifications()
    }

    // MARK: - 通知
    private func registerNotifications() {
        guard observers.isEmpty else { return }

        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        })
        observers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        })
    }

    private func unregisterNotifications() {
        let center = NotificationCenter.default
        observers.forEach { center.removeObserver($0) }
        observers.removeAll()
    }

    // MARK: - 中断处理
    private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            // 来电/闹钟等中断 → 停止流式
            isActive = false
            onInterruptionBegan?()
        case .ended:
            // 中断结束 → 检查是否可恢复
            let options = AVAudioSession.InterruptionOptions(
                rawValue: (info[AVAudioSessionInterruptionOptionKey] as? UInt) ?? 0)
            if options.contains(.shouldResume) {
                try? AVAudioSession.sharedInstance().setActive(true)
                isActive = true
                onInterruptionEnded?()
            }
        @unknown default:
            break
        }
    }

    // MARK: - 路由变更
    private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        onRouteChange?(reason)

        // 耳机断开 → 停止流式（对齐 Android onRouteDisconnected）
        if reason == .oldDeviceUnavailable {
            let session = AVAudioSession.sharedInstance()
            let outputs = session.currentRoute.outputs
            if outputs.isEmpty {
                onInterruptionBegan?()
            }
        }
    }

    deinit {
        unregisterNotifications()
    }
}
