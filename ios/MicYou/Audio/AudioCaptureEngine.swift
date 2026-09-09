import Foundation
import AVFAudio

/// 音频采集引擎：基于 `AVAudioEngine` + `inputNode.installTap`。
///
/// 对齐 Android `AudioEngine.kt`（AudioRecord 采集）：
/// - 设置 AVAudioSession（.playAndRecord / .voiceChat / 20ms buffer）
/// - 在 inputNode 安装 tap，目标格式 = (sampleRate, channels, Float32 非交错)
/// - tap 回调：Float32 → Int16 交错 PCM + RMS 电平
/// - 采集线程极轻：仅转换 + 回调；编码/发送由调用方在后台队列处理（B7）
public final class AudioCaptureEngine {

    /// 采集配置。
    public struct Config {
        public var sampleRate: SampleRate
        public var channelCount: ChannelCount
        public init(sampleRate: SampleRate = .rate48000, channelCount: ChannelCount = .mono) {
            self.sampleRate = sampleRate
            self.channelCount = channelCount
        }
    }

    /// 采集到的音频帧。
    public struct CapturedFrame {
        /// 交错 Int16 PCM 样本。
        public let samples: [Int16]
        /// 每声道帧样本数。
        public let frameLength: Int
        /// 声道数。
        public let channels: Int
        /// 采样率。
        public let sampleRate: Int
    }

    /// 采集回调（在实时音频线程调用，必须轻量）。
    public var onCapture: ((CapturedFrame) -> Void)?
    /// 电平回调（0...1 归一化 RMS，在音频线程）。
    public var onLevelUpdate: ((Float) -> Void)?

    private let engine = AVAudioEngine()
    private var config: Config
    private(set) var isRunning = false

    public init(config: Config = Config()) {
        self.config = config
    }

    public func updateConfig(_ config: Config) {
        self.config = config
    }

    // MARK: - 启动/停止
    /// 启动采集。需先获得麦克风权限。
    public func start() throws {
        guard !isRunning else { return }
        guard MicrophonePermission.status == .granted else {
            throw AudioError.permissionNotGranted
        }

        // 1. AVAudioSession
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat,
                                options: [.allowBluetoothA2DP, .defaultToSpeaker])
        try session.setPreferredSampleRate(Double(config.sampleRate.rawValue))
        try session.setPreferredIOBufferDuration(0.02)   // 20ms
        try session.setActive(true, options: [])

        // 2. 安装 tap
        let channels = AVAudioChannelCount(config.channelCount.rawValue)
        guard let tapFormat = AVAudioFormat(
            standardFormatWithSampleRate: Double(config.sampleRate.rawValue),
            channels: channels) else {
            throw AudioError.formatNotSupported
        }

        let inputNode = engine.inputNode
        let frameSize = AVAudioFrameCount(config.sampleRate.frameSize20ms)
        inputNode.installTap(onBus: 0, bufferSize: frameSize, format: tapFormat) { [weak self] buffer, _ in
            self?.processBuffer(buffer)
        }

        // 3. 启动引擎
        try engine.start()
        isRunning = true
    }

    /// 停止采集。
    public func stop() {
        guard isRunning else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        isRunning = false
    }

    // MARK: - 缓冲区处理
    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }
        let channelCount = Int(buffer.format.channelCount)
        let sampleRate = Int(buffer.format.sampleRate)

        guard let floatData = buffer.floatChannelData else { return }

        // Float32 非交错 → Int16 交错 + RMS
        var samples = [Int16](repeating: 0, count: frameLength * channelCount)
        var sumSquares: Float = 0

        for frame in 0..<frameLength {
            for ch in 0..<channelCount {
                let sample = floatData[ch][frame]
                let clamped = max(-1.0, min(1.0, sample))
                samples[frame * channelCount + ch] = Int16(clamped * 32767.0)
                sumSquares += sample * sample
            }
        }

        // 电平（归一化 RMS 0...1）
        let rms = sqrt(sumSquares / Float(frameLength * channelCount))
        let level = min(1.0, rms * 3.0)   // 增益后限幅，对齐 Android 电平缩放
        onLevelUpdate?(level)

        // 采集回调
        onCapture?(CapturedFrame(
            samples: samples, frameLength: frameLength,
            channels: channelCount, sampleRate: sampleRate))
    }

    deinit {
        if isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
    }
}

/// 音频错误。
public enum AudioError: Error, Equatable {
    case permissionNotGranted
    case formatNotSupported
    case engineNotRunning
    case sessionActivationFailed(String)
}
