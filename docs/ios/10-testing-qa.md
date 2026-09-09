# iOS · 测试与 QA

> 对齐 AGENTS.md "测试极简 by design"：以端到端手验为主，单测覆盖核心协议/编码逻辑，
> CI 保证 build green。无强制 lint/format 自动化。

## 1. 单元测试（XCTest）

| 模块 | 测试 | 对齐 |
|---|---|---|
| `Protocol/FrameCodec` | TCP 帧编码→解码往返一致；magic/长度校验；超长拒绝 | `micyou-protocol` 内联测试 |
| `Protocol/FrameCodec` | UDP 帧编码；8+payload<=1472 校验 | 同上 |
| `Protocol/Protos` | `MessageWrapper` serialize/deserialize 往返；各消息字段号正确 | `Protocol.kt` 等价 |
| `Audio/OpusEncoder` | PCM→Opus 编码产出非空；20ms 帧样本数正确；采样率映射 44100→48000 | `AudioEngine.kt` 行为 |
| `Audio/FecEncoder` | 12 包 XOR 正确；变长包 0 填充；`fecPacketLengths` 保留 | `xorBuffers` |
| `Network` | `calculateUdpPort` 边界（8554→8555；65535 溢出拒绝） | `Protocol.kt:141` |
| `Settings` | 各设置项读写往返；`mirror_cdk` Keychain 往返 | `Settings.kt` |

- 测试位置：`ios/MicYouTests/`（Xcode test target）。
- 运行：`xcodebuild test -scheme MicYou -destination 'platform=iOS Simulator,name=iPhone 15'`。

## 2. 静态门禁

- **CI build green** 是唯一硬门禁：`xcodebuild build`（macOS runner）。
- 可选 `SwiftLint`（若引入 `.swiftlint.yml`）；不强制。
- 无强制 format（对齐全仓无 prettier/ktlint wiring）。

## 3. 端到端手验清单（用户在 Mac + iPhone）

> 这是 de facto 验收管道（对齐 AGENTS.md "manual end-to-end verification of the audio path"）。

### 3.1 Wi-Fi 模式
- [ ] 桌面端启动 server（Wi-Fi 模式，mDNS 广播）。
- [ ] iPhone 选 Wi-Fi，扫描发现桌面设备，点选。
- [ ] 点开始 → 状态变"流式中" → 桌面虚拟麦克风出声。
- [ ] 对 iPhone 说话，PC 录音/通话收到声音。
- [ ] 静音 → 桌面无声；取消静音 → 恢复。
- [ ] 拔 Wi-Fi → 5s 心跳超时 → 错误态 → 重连。
- [ ] 切采样率/声道/格式 → 重连后生效。

### 3.2 USB 模式
- [ ] Mac 装 libimobiledevice，`iproxy 8554 8554 &` + `iproxy 8555 8555 &`。
- [ ] iPhone USB 连 Mac，选 USB 模式，点开始 → 桌面出声。
- [ ] 验证走 127.0.0.1（非 Wi-Fi）。

### 3.3 Web 模式
- [ ] 桌面端启动 server（Web 模式，webPort 8443）。
- [ ] iPhone 选 Web，填桌面 IP:8443，点开始 → 桌面出声。
- [ ] 验证发 Float32 二进制 WebSocket 帧（桌面日志）。
- [ ] 自签证书 → 接受/跳过校验后连通。

### 3.4 通用
- [ ] 麦克风权限拒绝 → 友好引导，不崩溃。
- [ ] 后台进入 → 按策略停止/保持；前台恢复。
- [ ] `keepScreenOn` → 屏幕不熄。
- [ ] 切语言 → UI 文案变化。
- [ ] 切主题 → 明暗生效。
- [ ] 设置项重启 app 后保留。

## 4. CI 工作流（`.github/workflows/ios.yml`）

```yaml
name: iOS
on: [push, pull_request]
jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - run: brew install swift-protobuf
      - run: bash ios/MicYouOpus/build-opus.sh   # 或缓存 xcframework
      - run: |
          xcodebuild -project ios/MicYou.xcodeproj -scheme MicYou \
            -sdk iphonesimulator \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            build
```
- `continue-on-error: true`（对齐 Android CI 不阻断 release）。
- 不做签名（sim build 免签）。

## 5. 已知限制（本环境）

- **本环境为 Linux，无 Xcode/Swift 工具链**：无法 `swift build`/`xcodebuild`。
- 验收基线 = 代码逐文件对照 Android 参考 + 类型/结构正确 + 文档完整。
- 真实编译/运行验证依赖**用户 Mac** 或 **CI macOS runner**。
- libopus.xcframework 需 macOS 生成；CI 可缓存或现地构建。

## 6. 与 Android QA 对应

| Android | iOS |
|---|---|
| `assembleDebug` + `npm run build` build green | `xcodebuild build` green |
| 内联 `#[cfg(test)]` / kotlin-test（未用） | XCTest |
| 手验音频路径 | 同（§3 清单） |
| CI `continue-on-error` | 同 |
