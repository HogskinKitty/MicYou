# MicYouOpus

libopus 的 Swift 封装（本地 SPM 包）。对齐 Android `io.github.jaredmdobson.concentus`（Concentus）。

## 状态

- **B1**：纯 Swift 占位 target，`OpusEncoder.encode` 会 `fatalError`。工程可在未构建 opus 时解析编译。
- **B6**：引入 `opus.xcframework`（binary target）+ C 桥接，实现真正的 `opus_encoder_create/encode/destroy`。

## 构建 opus.xcframework（macOS）

```bash
bash ios/MicYouOpus/build-opus.sh
```

产物 `ios/MicYouOpus/opus.xcframework`（iphoneos-arm64 + simulator-arm64 + simulator-x86_64）。
该产物**不入库**（见 `ios/.gitignore`），由 `setup.sh` / CI 在 macOS 生成或缓存。

## 用法（B6 之后）

```swift
let enc = OpusEncoder(sampleRate: 48000, channels: 1, application: OpusEncoder.applicationVoIP)
let opusBytes = enc.encode(pcmShorts, frameSize: 960)  // 20ms @48k
```

## 对齐 Android

| Android (Concentus) | iOS (MicYouOpus) |
|---|---|
| `OpusEncoder(sampleRate, channels, OPUS_APPLICATION_VOIP)` | `OpusEncoder(sampleRate:channels:application:)` |
| `encoder.encode(pcm, 0, frameSize, out, 0, outCap)` | `encoder.encode(pcm, frameSize:)` |
| 20ms 帧、采样率 8/12/16/24/48kHz、44.1k→48k 映射 | 同（见 `docs/ios/03-audio-pipeline.md`） |
