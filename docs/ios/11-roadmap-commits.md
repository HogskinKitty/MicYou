# iOS · 实现路线图与提交计划

> 18 个功能点 → 18 次 commit + push。每个功能点附验收点。顺序经依赖排序。
> commit message 用中文 conventional commits（对齐 AGENTS.md "ALWAYS use Chinese"）。

## 阶段 A：需求文档（1 次 commit）

| commit | message | 内容 |
|---|---|---|
| A1 | `docs(ios): 新增 iOS 客户端全部需求与设计文档` | `docs/ios/00-11` 共 12 篇 |

## 阶段 B：实现（18 次 commit）

工程根：`ios/MicYou/`（app）+ `ios/MicYouOpus/`（SPM libopus）+ `ios/Protos/`（proto）。

| # | commit message | 内容 | 验收 | 依赖 |
|---|---|---|---|---|
| B1 | `feat(ios): 初始化 Xcode 工程与 SwiftUI App 壳` | `.xcodeproj`、`Package.swift`、SPM 依赖声明（SwiftProtobuf/MicYouOpus）、`Info.plist`（权限键）、`@main App` + 空 `HomeView`、`ios/MicYouOpus/Package.swift` + `build-opus.sh`、复制 `network.proto` | Xcode 可打开，SPM 解析通过，`build-opus.sh` 存在 | A1 |
| B2 | `feat(ios): 实现线上协议层(protobuf+帧编解码)` | SwiftProtobuf 生成模型入库、`WireConstants`、`FrameCodec`（TCP/UDP 编解码）、`calculateUdpPort` | 单测：编解码往返、magic/长度校验、端口边界 | B1 |
| B3 | `feat(ios): 实现 Network framework TCP/UDP 传输与握手` | `TcpTransport`（NWConnection + 握手 MicYouCheck1/2 + ConnectMessage + reader/writer 循环）、`UdpTransport` | 能握手并收发 ConnectMessage | B2 |
| B4 | `feat(ios): 实现 mDNS 设备发现` | `DeviceDiscovery`（NetService 浏览 `_micyou._tcp.` + 解析）、`DiscoveredDevice` | 列出桌面广播的服务 | B1 |
| B5 | `feat(ios): 实现 AVAudioEngine 采集与权限` | `AudioCaptureEngine`（AVAudioSession 配置 + installTap + Float32 采集）、权限请求、电平计量 | 授权后 tap 产出 buffer，电平更新 | B1 |
| B6 | `feat(ios): 集成 libopus 编码器` | `MicYouOpus` Swift 封装（create/encode/destroy）、`OpusEncoder`、20ms 帧累积、采样率映射 | PCM→Opus 产出非空载荷 | B5 |
| B7 | `feat(ios): 实现 FEC 与音频发送管线` | `FecEncoder`（12 包 XOR + fecPacketLengths）、`AudioPipeline`（序号、封装 AudioPacketMessageOrdered、UDP/TCP 分发） | 每 12 包生成 1 FEC 包，分发正确 | B2,B3,B6 |
| B8 | `feat(ios): 实现 AudioEngine 状态机与心跳` | `MicYouAudioEngine`（Idle/Connecting/Streaming/Error、start/stop、心跳 ping/pong 5s、重连、生命周期代际、错误映射） | 状态流转正确，心跳超时断开，stop 干净释放 | B3,B5,B7 |
| B9 | `feat(ios): 实现 Web(wss)连接模式` | `WebSocketTransport`（URLSessionWebSocketTask + Float32 二进制帧 + 自签证书 delegate） | 连 `wss://ip:8443/ws` 发 Float32，桌面出声 | B5,B8 |
| B10 | `feat(ios): 实现 USB(iproxy)连接模式` | `ConnectionMode.usb` → 目标 IP 强制 `127.0.0.1`；`02-connection-modes.md` iproxy 命令已在文档 | 经 iproxy 转发后握手+流式成功 | B8 |
| B11 | `feat(ios): 实现设置持久化(UserDefaults)` | `SettingsStore`（UserDefaults + Keychain for mirror_cdk）、`AppSettings` 模型、所有键读写 | 设置项读写往返，键名对齐 Android | B1 |
| B12 | `feat(ios): 实现 MVVM 状态管理` | `MainViewModel`（ObservableObject @MainActor）+ `AppUiState` + 合并 audioEngine/discovery/settings 状态 | UI 单一状态源，状态合并正确 | B8,B11 |
| B13 | `feat(ios): 实现主界面与音频可视化` | `HomeView`（模式/IP/端口/传输/设备列表/流式开关/静音/状态）、`VisualizerView`（6 种样式 Canvas） | 可选模式、开关流式、显示设备、可视化随电平动 | B12 |
| B14 | `feat(ios): 实现设置界面` | `SettingsView`（Form 分区：音频/外观/通用/关于） | 各设置项可编辑并持久化 | B11,B13 |
| B15 | `feat(ios): 实现多语言本地化` | `Localizable.xcstrings`（en/zh/zh-TW/zh-HK/ca）、`L10n` 封装、`AppLanguage` 切换 | 切语言 UI 文案变化，无硬编码 | B13,B14 |
| B16 | `feat(ios): 实现主题与动态配色` | `ThemeView`/`ThemeMode`、种子色驱动 tint、OLED 纯黑、动态色回退 | 三种 themeMode 生效，种子色驱动配色 | B13 |
| B17 | `feat(ios): 实现音频会话与前后台生命周期` | scenePhase 观察、keepScreenOn（isIdleTimerDisabled）、中断处理、后台策略、首次启动引导 | 锁屏/后台行为合规，keepScreenOn 生效 | B8,B13 |
| B18 | `ci(ios): 新增 macOS 构建工作流并同步文档` | `.github/workflows/ios.yml`（macOS xcodebuild）、`11-roadmap-commits.md` 标记完成、README 提及 iOS | CI 在 macOS runner build 通过 | B1-B17 |

## 提交规范

- 每个功能点**单独 commit**，scope 用 `ios`（如 `feat(ios): ...`）。
- commit body 用中文说明改了什么、对齐 Android 哪处。
- 每次 commit 后 `git push origin master`。
- **push 依赖 SSH 凭证**：若本环境无凭证，push 失败时提交保留本地并告知用户手动 push，不阻塞后续 commit。

## 版本

- 初版 `MARKETING_VERSION=2.0.3` / `CURRENT_PROJECT_VERSION=27`（对齐 `gradle.properties`）。
- iOS 版本独立演进，不跑 `npm run sync-version`。

## 验收总标准

1. `docs/ios/` 12 篇齐全且与代码对齐。
2. `xcodebuild build`（macOS CI）通过。
3. Wi-Fi/USB/Web 三模式端到端出声（用户手验）。
4. 18 次 commit 全部 push 到 `origin/master`。

## 完成状态

| # | commit | 状态 |
|---|---|---|
| A1 | `bb5a96f` | ✅ 已推送 |
| B1 | `e9ef0f5` | ✅ 已推送 |
| B2 | `29cb7ac` | ✅ 已推送 |
| B3 | `3e612d2` | ✅ 已推送 |
| B4 | `4ecc57d` | ✅ 已推送 |
| B5 | `3084fa2` | ✅ 已推送 |
| B6 | `b49795a` | ✅ 已推送 |
| B7 | `052ddff` | ✅ 已推送 |
| B8 | `ec6e61c` | ✅ 已推送 |
| B9 | `0348cbf` | ✅ 已推送 |
| B10 | `08dcdbf` | ✅ 已推送 |
| B11 | `c1f33c0` | ✅ 已推送 |
| B12 | `909d036` | ✅ 已推送 |
| B13 | `e7fc695` | ✅ 已推送 |
| B14 | `f143cc9` | ✅ 已推送 |
| B15 | `5075a4c` | ✅ 已推送 |
| B16 | `0926e6d` | ✅ 已推送 |
| B17 | `1864fb8` | ✅ 已推送 |
| B18 | — | ✅ 本提交 |
