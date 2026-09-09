import Foundation
import OpusXCF

/// libopus 编码器 Swift 封装。对齐 Android Concentus `OpusEncoder`。
///
/// 通过 `import OpusXCF`（opus.xcframework 二进制 target）调用 C API：
/// `opus_encoder_create` / `opus_encode` / `opus_encoder_destroy`。
///
/// Opus `#define` 常量不被 Swift 导入，故在此显式定义。
public final class OpusEncoder {
    // MARK: - Opus 常量（C #define，Swift 不自动导入）
    /// OPUS_APPLICATION_VOIP
    public static let applicationVoIP: Int32 = 2048
    /// OPUS_APPLICATION_AUDIO
    public static let applicationAudio: Int32 = 2049
    /// OPUS_APPLICATION_RESTRICTED_LOWDELAY
    public static let applicationRestrictedLowDelay: Int32 = 2051

    // MARK: - ctl 请求码（C #define）
    /// OPUS_SET_BITRATE_REQUEST
    public static let ctlSetBitrate: Int32 = 4002
    /// OPUS_SET_COMPLEXITY_REQUEST
    public static let ctlSetComplexity: Int32 = 4010
    /// OPUS_SET_PACKET_LOSS_PERC_REQUEST
    public static let ctlSetPacketLossPerc: Int32 = 4012
    /// OPUS_SET_DTX_REQUEST
    public static let ctlSetDtx: Int32 = 4016

    private var encoder: OpaquePointer?
    public let sampleRate: Int32
    public let channels: Int32

    /// 创建 Opus 编码器。
    /// - Parameters:
    ///   - sampleRate: 采样率（8000/12000/16000/24000/48000）
    ///   - channels: 声道数（1=mono, 2=stereo）
    ///   - application: OPUS_APPLICATION_VOIP / AUDIO / RESTRICTED_LOWDELAY
    public init(sampleRate: Int32, channels: Int32,
                application: Int32 = OpusEncoder.applicationVoIP) throws {
        self.sampleRate = sampleRate
        self.channels = channels
        var error: Int32 = 0
        guard let enc = opus_encoder_create(sampleRate, channels, application, &error) else {
            throw MicYouOpusError.encoderCreateFailed(error)
        }
        encoder = enc
    }

    /// 把 16-bit LE PCM 编码为 Opus 载荷。对齐 Android `encoder.encode(pcm, 0, frameSize, out, 0, outCap)`。
    /// - Parameters:
    ///   - pcm: 交错 Int16 样本
    ///   - frameSize: 每声道帧样本数（20ms = sampleRate*20/1000）
    /// - Returns: 编码后的 Opus 字节（空数组 = 编码失败或空输入）
    public func encode(_ pcm: [Int16], frameSize: Int32) -> [UInt8] {
        guard let enc = encoder, !pcm.isEmpty else { return [] }
        // Opus 最大包 1276 字节，留余量
        let maxDataBytes: Int32 = 1276
        var output = [UInt8](repeating: 0, count: Int(maxDataBytes))
        let encoded: Int32 = pcm.withUnsafeBufferPointer { pcmPtr in
            output.withUnsafeMutableBufferPointer { outPtr in
                opus_encode(enc, pcmPtr.baseAddress, frameSize,
                            outPtr.baseAddress, maxDataBytes)
            }
        }
        guard encoded > 0 else { return [] }
        return Array(output.prefix(Int(encoded)))
    }

    /// 设置比特率（bps）。对齐 Android `encoder.bitrate = ...`。
    public func setBitrate(_ bitrate: Int32) {
        guard let enc = encoder else { return }
        _ = opus_encoder_ctl(enc, Self.ctlSetBitrate, bitrate)
    }

    /// 设置复杂度（0-10）。iPhone 6s 建议用 5（平衡质量与性能）。
    public func setComplexity(_ complexity: Int32) {
        guard let enc = encoder else { return }
        _ = opus_encoder_ctl(enc, Self.ctlSetComplexity, complexity)
    }

    deinit {
        if let enc = encoder { opus_encoder_destroy(enc) }
    }
}
