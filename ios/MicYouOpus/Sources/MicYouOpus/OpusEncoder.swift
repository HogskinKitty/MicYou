/// libopus 编码器 Swift 封装（B1 占位）。
///
/// B1 仅提供类型骨架以让工程编译；`encode` 会 fatalError。
/// B6 将引入 `import OpusXCF`（libopus.xcframework 二进制 target）并实现真正的
/// `opus_encoder_create` / `opus_encode` / `opus_encoder_destroy` 调用。
///
/// 对齐 Android `io.github.jaredmdobson.concentus.OpusEncoder`。
public final class OpusEncoder {
    /// OPUS_APPLICATION_VOIP = 2048
    public static let applicationVoIP: Int32 = 2048

    public init(sampleRate: Int32, channels: Int32, application: Int32) {
        // B6 实现
    }

    /// 把 16-bit LE PCM 编码为 Opus 载荷。
    /// - Parameters:
    ///   - pcm: 交错 16-bit 样本
    ///   - frameSize: 每声道帧样本数（20ms = sampleRate*20/1000）
    /// - Returns: 编码后的 Opus 字节
    public func encode(_ pcm: [Int16], frameSize: Int32) -> [UInt8] {
        fatalError("OpusEncoder.encode 将在 B6 实现（libopus 桥接）")
    }

    deinit {}
}
