# MicYou iOS 客户端 · 总览

> 本文档是 iOS 客户端需求与设计的入口。所有线上行为以现有 Android 客户端
> (`composeApp/`) 与桌面后端 (`tauri-app/src-tauri/`) 为唯一事实来源，iOS 端
> **逐字节、逐字段对齐**，不引入新协议。

## 1. 项目目标

把 iPhone 变成 PC 的高质量麦克风。iPhone 采集麦克风音频，经网络流式发送到
桌面端；桌面端接收后通过虚拟麦克风设备（Windows VB-CABLE / macOS BlackHole /
Linux PipeWire）或浏览器回放。iOS 客户端是**纯发送端**，不接收/播放音频。

## 2. 技术栈（固定）

| 层 | 技术 | 对应 Android |
|---|---|---|
| UI | SwiftUI | Jetpack Compose + Material 3 |
| 音频采集 | AVAudioEngine + AVAudioSession | `AudioRecord` + `audiofx` |
| 网络传输 | Network framework (`NWConnection` TCP/UDP) | ktor `aSocket` / `DatagramSocket` |
| WebSocket（Web 模式） | `URLSessionWebSocketTask` | （Android 无，桌面 `web_server.rs`） |
| 序列化 | SwiftProtobuf（从 `network.proto` 生成） | kotlinx-serialization-protobuf |
| 音频编码 | libopus（C，本地 SPM 包裹） | Concentus (`io.github.jaredmdobson.concentus`) |
| 状态管理 | MVVM + `ObservableObject`/`@Published` + Combine | MVVM + `StateFlow` + `combine()` |
| 持久化 | UserDefaults | SharedPreferences (`android_mic_prefs`) |
| 本地化 | String Catalog (`.xcstrings`) | `res/values*/strings.xml` |

## 3. 部署目标

- **最低部署目标 iOS 15.0**，以 **iPhone 6s**（A9，2015，最高 iOS 15.8.3）为基准设备。
- `URLSessionWebSocketTask`（iOS 13+）、`AVAudioEngine`、`NWConnection`、SwiftUI 均满足。
- `@Observable` 宏需 iOS 17+，**故采用 `ObservableObject` + `@Published`** 以兼容 iOS 15。
- String Catalog 由 Xcode 15+ 编辑，编译产物在 iOS 15 运行时兼容。

## 4. 三种连接模式

| 模式 | 传输 | 发现 | 对齐 |
|---|---|---|---|
| **Wi-Fi** | TCP 控制（8554）+ UDP 音频（8555） | mDNS `_micyou._tcp.` | Android `ConnectionMode.Wifi` |
| **USB** | TCP 控制 + UDP 音频，连 `127.0.0.1` | 无（桌面端 `iproxy` 转发） | Android `ConnectionMode.Usb`（adb reverse → iproxy） |
| **Web** | `wss://<ip>:8443/ws` 二进制 Float32 帧 | 手填 IP | 桌面 `web_server.rs`（Android 无此模式） |

> iOS 无 `adb reverse`。USB 模式由 Mac 端运行 `iproxy`（libimobiledevice）把设备端口
> 转发到 `127.0.0.1`，iPhone 连 `127.0.0.1:8554`，模型与 Android 一致。详见
> `02-connection-modes.md`。

## 5. 与现有代码的关系

- **不改桌面后端 / 不改 wire 协议**：iOS 复用 `tauri-app/crates/micyou-protocol/proto/network.proto`。
  该 proto 仅被**复制**到 `ios/Protos/network.proto` 供 SwiftProtobuf 生成，原文件不动。
- **不改 Android**：iOS 是独立新增客户端，与 `:composeApp` 并存。
- **版本**：iOS 独立版本号，初版对齐 `MARKETING_VERSION=2.0.3` / `CURRENT_PROJECT_VERSION=27`
  （与 `gradle.properties` 一致），后续独立演进。

## 6. 工程布局（计划）

```
ios/
├── MicYou.xcodeproj          # Xcode 工程（project.pbxproj 入库）
├── MicYou/                   # App target
│   ├── App/                  # @main App、根视图
│   ├── Protocol/             # SwiftProtobuf 生成模型 + 常量 + 帧编解码
│   ├── Network/              # NWConnection 传输、握手、mDNS 发现、WebSocket
│   ├── Audio/                # AVAudioEngine 采集、Opus 编码、FEC、AudioEngine 状态机
│   ├── ViewModel/            # ObservableObject ViewModel + AppUiState
│   ├── Views/                # SwiftUI 视图（主界面、设置、可视化、主题）
│   ├── Settings/             # UserDefaults 持久化 + 设置模型
│   ├── Localization/         # .xcstrings
│   ├── Util/                 # Logger、扩展
│   └── Resources/            # Info.plist、Assets、opus.xcframework 引用
├── MicYouOpus/               # SPM 本地包：libopus C 桥接
└── Protos/                   # network.proto 副本 + 生成脚本
```

## 7. 不做的事（明确边界）

- 不实现接收/播放/虚拟麦克风（那是桌面端职责）。
- 不改 Rust/Tauri/Android 任何代码。
- 不做 App Store 上架配置（仅本地构建 + CI 验证；签名密钥由用户配置）。
- 不实现 Android 独有的 Quick Settings Tile / 前台 Service 通知（iOS 用 AVAudioSession + 后台音频策略替代，见 `07-permissions-lifecycle.md`）。
- 不实现 Android 的 `zh-rHD`（坚硬模式）彩蛋资源（可后续补）。

## 8. 相关文档索引

| 文件 | 主题 |
|---|---|
| `01-wire-protocol.md` | 线上协议规范 |
| `02-connection-modes.md` | 三种连接模式 |
| `03-audio-pipeline.md` | 音频采集与编码管线 |
| `04-architecture.md` | iOS 架构与状态管理 |
| `05-settings-config.md` | 设置与持久化 |
| `06-localization.md` | 本地化 |
| `07-permissions-lifecycle.md` | 权限与生命周期 |
| `08-dependencies-build.md` | 依赖与构建 |
| `09-ui-spec.md` | UI 规范 |
| `10-testing-qa.md` | 测试与 QA |
| `11-roadmap-commits.md` | 实现路线图与提交计划 |
