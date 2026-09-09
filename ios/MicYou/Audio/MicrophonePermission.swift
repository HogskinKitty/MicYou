import Foundation
import AVFAudio

/// 麦克风权限管理。对齐 Android `ContextCompat.checkSelfPermission(RECORD_AUDIO)`。
public enum MicrophonePermission {
    public enum Status {
        case granted, denied, notDetermined
    }

    /// 当前权限状态。
    public static var status: Status {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted: return .granted
            case .denied: return .denied
            case .undetermined: return .notDetermined
            @unknown default: return .notDetermined
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted: return .granted
            case .denied: return .denied
            case .undetermined: return .notDetermined
            @unknown default: return .notDetermined
            }
        }
    }

    /// 请求麦克风权限。对齐 Android `requestPermissions`。
    public static func request() async -> Bool {
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        }
    }
}
