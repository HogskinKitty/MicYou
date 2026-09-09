# iOS · 音频采集与编码管线

> 对齐 Android `AudioEngine.kt`（采集 → PCM 转换 → Opus → FEC → 发送）。
> iOS 用 `AVAudioEngine` 替代 `AudioRecord`，libopus 替代 Concentus。

## 1. 管线总览

```
AVAudioEngine.inputNode ──installTap──▶ AVAudioPCMBuffer
   │  (Float32 / 48k / 选定声道)
   ▼
格式转换 → 16-bit LE Short[]  (convertPcmToShort)
   ▼
帧累积 (20ms = sampleRate*20/1000 样本/声道)
   ▼
opus_encode → Opus 载荷 (codec=1)
   ▼
AudioPacketMessageOrdered (seq++, sessionId, timestamp)
   ▼
MessageWrapper(audioPacket=...) ──▶ UDP帧(Wi-Fi+Both) / TCP帧 / wss Float32(Web)
   ▼
每 12 包 → XOR → FEC 包 ──▶ 同信道发送
```

## 2. AVAudioEngine 采集

### 2.1 会话配置
- `AVAudioSession.sharedInstance()`：
  - `category = .playAndRecord`（或 `.record`）
  - `mode = .voiceChat`（启用系统降噪/AGC 硬件，对齐 Android `NoiseSuppressor`/`AutomaticGainControl`）
  - `setPreferredSampleRate(选定的 opus 采样率)`
  - `setPreferredIOBufferDuration(0.02)`（倾向 20ms）
  - `setActive(true)`
- 权限：`AVAudioApplication.requestRecordPermission`（iOS 17+）或
  `AVAudioSession.requestRecordPermission`（iOS 15-16），需 `Info.plist`
  `NSMicrophoneUsageDescription`。

### 2.2 输入 tap
- `engine.inputNode` 的 `outputFormat` 即硬件采集格式（通常 Float32）。
- `installTap(onBus: 0, bufferSize: preferred, format: targetFormat)`：
  - `targetFormat` = `AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: opusSampleRate, channels: opusChannels)`。
  - 回调里拿 `AVAudioPCMBuffer`，取 `floatChannelData`。
- `engine.prepare()` → `engine.start()`。

### 2.3 采样率映射（对齐 `AudioEngine.kt:547`）
- 用户可选 `16000 / 44100 / 48000`（对齐 `SampleRate` 枚举）。
- Opus 仅支持 `8/12/16/24/48kHz`；**44100 → 48000**。
- `opusSampleRate = supported.contains(requested) ? requested : 48000`。

### 2.4 声道
- `Mono(1)` / `Stereo(2)`（对齐 `ChannelCount`）。
- `opusChannels = channelCount.value`。

## 3. PCM → 16-bit Short 转换（对齐 `convertPcmToShort`）

AVAudioEngine 产出 **Float32**。转换：
```swift
// float [-1,1] → int16 [-32768,32767]
short = Int16(max(-32768, min(32767, Int32(float * 32767))))
```
- 采集格式枚举 `audioFormat`：`PCM_8BIT(3)/PCM_16BIT(2)/PCM_FLOAT(4)/PCM_24BIT(6)`。
- iOS 实际采集恒为 Float32；`audioFormat` 字段写入**线上格式值**供遥测（与 Android 一致：
  `wireAudioFormat`，24-bit 运行时降级 16-bit）。
- `bytesPerSample = captureFormat.bitsPerSample / 8`。

## 4. Opus 编码（libopus C 桥接）

### 4.1 编码器创建
```c
OpusEncoder *enc = opus_encoder_create(sampleRate, channels, OPUS_APPLICATION_VOIP, &err);
opus_encoder_ctl(enc, OPUS_SET_BITRATE(...));  // 可选
```
- 帧长 `frameSamples = (opusSampleRate * 20) / 1000`（20ms）。
- 每帧样本数（含声道）`frameSizePerChannel = frameSamples * opusChannels`。

### 4.2 帧累积
- tap 回调产出的 Short 先追加到 `opusPcmAccumulator`。
- 每凑满 `frameSizePerChannel` 个样本：
  1. `opus_encode(enc, accumulator, frameSamples, outBuf, outCap)` → `encodedLen`。
  2. 紧凑剩余未编码样本（`System.arraycopy` 等价）。
  3. 产出 `encoded = outBuf[0..<encodedLen]`。

### 4.3 输出缓冲
- libopus 输出缓冲 >= 4000 字节（对齐 Concentus 要求，`AudioEngine.kt:856`）。

## 5. 音频包封装

每个 Opus 帧：
```swift
let packet = AudioPacketMessage(
    buffer: encoded,
    sampleRate: opusSampleRate,
    channelCount: opusChannels,
    audioFormat: wireAudioFormat.value,   // 遥测用
    codec: 1                              // CODEC_OPUS
)
let wrapper = MessageWrapper(
    audioPacket: AudioPacketMessageOrdered(
        sequenceNumber: seq, audioPacket: packet,
        timestamp: nowMs, sessionId: sessionId
    )
)
```
- `sequenceNumber` 单调递增（从 0）。
- `timestamp` = `Date().timeIntervalSince1970 * 1000`（ms）。

## 6. 发送分发（对齐 `AudioEngine.kt:758`）

```
shouldUseUdp =
  transport == .both && mode == .wifi && !msg.hasControlMessage
```
- `true` → UDP 帧发送（`02` §4）。
- `false` → TCP 帧发送（`01` §3）。
- 控制消息（mute/ping/pong/connect）恒走 TCP。

## 7. FEC（对齐 `AudioEngine.kt:972`）

- 维护 `fecGroupBuffer: [[UInt8]]`、`fecGroupStartSeq`。
- 每发出一个 Opus 包，`fecGroupBuffer.append(encoded)`。
- `fecGroupBuffer.count >= 12`：
  1. `xor = xorBuffers(fecGroupBuffer)`（最长为准，短 0 填充）。
  2. FEC 包：
     ```
     AudioPacketMessage(buffer: xor, sampleRate, channelCount, audioFormat, codec: 1)
     AudioPacketMessageOrdered(
       sequenceNumber: seq,          // 下一序号，不造间隙
       audioPacket: fecPacket,
       timestamp: nowMs,
       fecBuffer: [0x01],            // 非空 = FEC 标记
       fecSequenceNumber: fecGroupStartSeq,
       sessionId: sessionId,
       fecPacketLengths: fecGroupBuffer.map { $0.count }
     )
     ```
  3. 同信道发送 FEC 包。
  4. 清空 `fecGroupBuffer`，`fecGroupStartSeq = seq`。

## 8. 电平计量（对齐 `calculateAudioLevelData`）

- 对采集 PCM 算 RMS（Float32 → abs → 均方根）。
- 暴露 `@Published audioLevel: Float`（0…1）供可视化。
- 静音时不发音频但仍可更新电平（或置 0，对齐 Android：静音丢弃累积 PCM）。

## 9. 静音处理（对齐 `AudioEngine.kt:1008`）

- `isMuted == true`：`opusPendingSamples = 0`（清空累积），跳过编码/发送。
- 静音状态变化发 `MuteMessage(isMuted)` 经 TCP。
- 入站 `MuteMessage`（桌面下发）→ 更新 `isMuted`。

## 10. 心跳（对齐 `AudioEngine.kt:870`）

- 记 `lastPingReceivedTime`。收 `ping` → 回 `pong`，更新时间。
- `now - lastPingReceivedTime > 5000ms` → 抛"Heartbeat timeout"→ `StreamState.error`。

## 11. 资源释放（stop）

- `engine.removeTap(onBus: 0)` → `engine.stop()`。
- `opus_encoder_destroy(enc)`。
- 关 `NWConnection`（TCP/UDP）/ `URLSessionWebSocketTask`。
- `AVAudioSession.setActive(false)`。
- 对齐 Android `finally` 块的有序释放。

## 12. 与 Android 对应

| Android (`AudioEngine.kt`) | iOS |
|---|---|
| `AudioRecord` + `READ_NON_BLOCKING` | `AVAudioEngine` + `installTap`（回调驱动，非轮询） |
| `NoiseSuppressor` / `AutomaticGainControl` | `AVAudioSession.mode = .voiceChat`（系统级） |
| `OpusEncoder` (Concentus) | `MicYouOpus` (libopus C) |
| `convertPcmToShort` | Float32→Int16 转换 |
| `xorBuffers` | Swift XOR |
| `SystemClock.elapsedRealtime()` | `ProcessInfo.processInfo.systemUptime` / `Date()` |
