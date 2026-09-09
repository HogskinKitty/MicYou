import XCTest
import MicYouOpus

/// Opus 编解码器烟雾测试。需 opus.xcframework（build-opus.sh 生成）。
/// 对齐 Android Concentus 编解码行为验证。
final class OpusEncoderTests: XCTestCase {

    /// 编码器创建 + 编码正弦波 → 非空输出。
    func testEncodeSineWave() throws {
        let sampleRate: Int32 = 48000
        let channels: Int32 = 1
        let frameSize: Int32 = 960   // 20ms @48k

        let encoder = try OpusEncoder(sampleRate: sampleRate, channels: channels,
                                      application: OpusEncoder.applicationVoIP)
        let pcm = sineWave(frequency: 440, sampleRate: sampleRate,
                           frameSize: frameSize, channels: channels)
        let encoded = encoder.encode(pcm, frameSize: frameSize)
        XCTAssertFalse(encoded.isEmpty, "编码正弦波应产生非空 Opus 载荷")
        XCTAssertLessThanOrEqual(encoded.count, 1276, "Opus 包应 ≤ 1276 字节")
    }

    /// 编码静音 → 载荷极小（Opus 擅长压缩静音）。
    func testEncodeSilence() throws {
        let encoder = try OpusEncoder(sampleRate: 48000, channels: 1,
                                      application: OpusEncoder.applicationVoIP)
        let silence = [Int16](repeating: 0, count: 960)
        let encoded = encoder.encode(silence, frameSize: 960)
        // 静音编码后应非常小（通常 2-5 字节）
        XCTAssertLessThan(encoded.count, 20, "静音 Opus 载荷应极小")
    }

    /// 编解码往返：decode(encode(pcm)) 长度 == frameSize * channels。
    func testEncodeDecodeRoundtrip() throws {
        let sampleRate: Int32 = 16000
        let channels: Int32 = 1
        let frameSize: Int32 = 320   // 20ms @16k

        let encoder = try OpusEncoder(sampleRate: sampleRate, channels: channels)
        let decoder = try OpusDecoder(sampleRate: sampleRate, channels: channels)

        let pcm = sineWave(frequency: 1000, sampleRate: sampleRate,
                           frameSize: frameSize, channels: channels)
        let encoded = encoder.encode(pcm, frameSize: frameSize)
        XCTAssertFalse(encoded.isEmpty)

        let decoded = decoder.decode(encoded, frameSize: frameSize)
        XCTAssertEqual(decoded.count, Int(frameSize) * Int(channels),
                       "解码帧长度应 == frameSize * channels")
    }

    /// 立体声编解码往返。
    func testStereoRoundtrip() throws {
        let sampleRate: Int32 = 48000
        let channels: Int32 = 2
        let frameSize: Int32 = 960

        let encoder = try OpusEncoder(sampleRate: sampleRate, channels: channels)
        let decoder = try OpusDecoder(sampleRate: sampleRate, channels: channels)

        let pcm = sineWave(frequency: 440, sampleRate: sampleRate,
                           frameSize: frameSize, channels: channels)
        XCTAssertEqual(pcm.count, Int(frameSize * channels))

        let encoded = encoder.encode(pcm, frameSize: frameSize)
        XCTAssertFalse(encoded.isEmpty)

        let decoded = decoder.decode(encoded, frameSize: frameSize)
        XCTAssertEqual(decoded.count, Int(frameSize * channels))
    }

    /// 设置比特率后仍能正常编码。
    func testSetBitrate() throws {
        let encoder = try OpusEncoder(sampleRate: 48000, channels: 1)
        encoder.setBitrate(32000)   // 32 kbps
        encoder.setComplexity(5)
        let pcm = sineWave(frequency: 440, sampleRate: 48000,
                           frameSize: 960, channels: 1)
        let encoded = encoder.encode(pcm, frameSize: 960)
        XCTAssertFalse(encoded.isEmpty)
    }

    // MARK: - 辅助
    /// 生成交错 Int16 正弦波。
    private func sineWave(frequency: Float, sampleRate: Int32,
                          frameSize: Int32, channels: Int32) -> [Int16] {
        let count = Int(frameSize * channels)
        var samples = [Int16](repeating: 0, count: count)
        let twoPi: Float = 2 * .pi
        let phaseInc = twoPi * frequency / Float(sampleRate)
        var phase: Float = 0
        for frame in 0..<Int(frameSize) {
            let value = Int16(sin(phase) * 16384)   // 0.5 振幅
            for ch in 0..<Int(channels) {
                samples[frame * Int(channels) + ch] = value
            }
            phase += phaseInc
            if phase >= twoPi { phase -= twoPi }
        }
        return samples
    }
}
