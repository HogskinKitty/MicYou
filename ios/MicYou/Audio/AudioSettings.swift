import Foundation

/// 采样率。对齐 Android `AudioSettings.kt:20-24`。
public enum SampleRate: Int, CaseIterable, Codable {
    case rate16000 = 16000
    case rate44100 = 44100
    case rate48000 = 48000

    public var label: String { "\(rawValue) Hz" }

    /// Opus 支持的采样率：8/12/16/24/48kHz。44100 不支持 → 映射到 48000。
    /// 对齐 `docs/ios/03-audio-pipeline.md` 44.1k→48k 映射。
    public var opusSampleRate: Int {
        switch self {
        case .rate16000: return 16000
        case .rate44100: return 48000   // 44.1k → 48k
        case .rate48000: return 48000
        }
    }

    /// 20ms 帧的样本数（每声道）。
    public var frameSize20ms: Int { rawValue * 20 / 1000 }
}

/// 声道数。对齐 Android `AudioSettings.kt:26-29`。
public enum ChannelCount: Int, CaseIterable, Codable {
    case mono = 1
    case stereo = 2

    public var label: String {
        switch self {
        case .mono: return "Mono"
        case .stereo: return "Stereo"
        }
    }
}

/// 音频格式。`value` = 线上协议格式值，对齐 Android `AudioSettings.kt:37-42`。
public enum AudioFormatType: Int, CaseIterable, Codable {
    /// AudioFormat.ENCODING_PCM_8BIT = 3
    case pcm8bit = 3
    /// AudioFormat.ENCODING_PCM_16BIT = 2
    case pcm16bit = 2
    /// 保留配置兼容；运行时安全回退到 PCM16
    case pcm24bit = 6
    /// AudioFormat.ENCODING_PCM_FLOAT = 4
    case pcmFloat = 4

    public var label: String {
        switch self {
        case .pcm8bit: return "8-bit PCM"
        case .pcm16bit: return "16-bit PCM"
        case .pcm24bit: return "24-bit PCM"
        case .pcmFloat: return "32-bit Float"
        }
    }

    public var bitsPerSample: Int {
        switch self {
        case .pcm8bit: return 8
        case .pcm16bit: return 16
        case .pcm24bit: return 24
        case .pcmFloat: return 32
        }
    }

    /// 运行时安全格式：24bit → 16bit。对齐 `resolveAudioFormat`。
    public var resolved: AudioFormatType {
        self == .pcm24bit ? .pcm16bit : self
    }

    /// 设置 UI 可选项：不显示 24bit。对齐 `availableAudioFormats()`。
    public static var availableForUI: [AudioFormatType] {
        allCases.filter { $0 != .pcm24bit }
    }
}
