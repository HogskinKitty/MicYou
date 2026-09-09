import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// 屏幕生命周期管理。对齐 Android `keep_screen_on` + PowerManager.WakeLock。
public enum ScreenLifecycle {

    /// 设置屏幕常亮（防止自动锁屏）。
    public static func setKeepScreenOn(_ enabled: Bool) {
        #if canImport(UIKit)
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = enabled
        }
        #endif
    }

    /// 当前是否保持常亮。
    public static var isKeepScreenOn: Bool {
        #if canImport(UIKit)
        return UIApplication.shared.isIdleTimerDisabled
        #else
        return false
        #endif
    }
}
