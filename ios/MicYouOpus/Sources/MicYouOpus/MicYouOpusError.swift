import Foundation

/// MicYouOpus 错误。对齐 Android Concentus `OpusError`。
public enum MicYouOpusError: Error, Equatable {
    case encoderCreateFailed(Int32)
    case decoderCreateFailed(Int32)
    case encodeFailed(Int32)
    case decodeFailed(Int32)
    case notInitialized

    public var localizedDescription: String {
        switch self {
        case .encoderCreateFailed(let code): return "Opus 编码器创建失败（错误码 \(code)）"
        case .decoderCreateFailed(let code): return "Opus 解码器创建失败（错误码 \(code)）"
        case .encodeFailed(let code): return "Opus 编码失败（错误码 \(code)）"
        case .decodeFailed(let code): return "Opus 解码失败（错误码 \(code)）"
        case .notInitialized: return "Opus 编解码器未初始化"
        }
    }
}
