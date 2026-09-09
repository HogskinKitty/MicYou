import Foundation
import OpusXCF

/// libopus 解码器 Swift 封装。对齐 Android Concentus `OpusDecoder`。
///
/// iOS 客户端仅编码（发送），解码器供测试与未来回声消除使用。
public final class OpusDecoder {
    private var decoder: OpaquePointer?
    public let sampleRate: Int32
    public let channels: Int32

    public init(sampleRate: Int32, channels: Int32) throws {
        self.sampleRate = sampleRate
        self.channels = channels
        var error: Int32 = 0
        guard let dec = opus_decoder_create(sampleRate, channels, &error) else {
            throw MicYouOpusError.decoderCreateFailed(error)
        }
        decoder = dec
    }

    /// 把 Opus 载荷解码为 16-bit LE PCM。
    /// - Parameters:
    ///   - data: Opus 字节
    ///   - frameSize: 每声道帧样本数
    /// - Returns: 交错 Int16 样本（空数组 = 失败）
    public func decode(_ data: [UInt8], frameSize: Int32) -> [Int16] {
        guard let dec = decoder, !data.isEmpty else { return [] }
        var output = [Int16](repeating: 0, count: Int(frameSize) * Int(channels))
        let decoded: Int32 = data.withUnsafeBufferPointer { dataPtr in
            output.withUnsafeMutableBufferPointer { outPtr in
                opus_decode(dec, dataPtr.baseAddress, Int32(data.count),
                            outPtr.baseAddress, frameSize, 0)
            }
        }
        guard decoded > 0 else { return [] }
        return Array(output.prefix(Int(decoded) * Int(channels)))
    }

    deinit {
        if let dec = decoder { opus_decoder_destroy(dec) }
    }
}
