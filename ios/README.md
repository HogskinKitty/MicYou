# MicYou iOS 客户端

> 把 iPhone 变成 PC 麦克风：采集音频 → Opus 编码 → 经 Wi-Fi/USB/Web 发送到桌面端。
> 部署目标 iOS 15.0（iPhone 6s 基准）。与 Android 客户端线上一致。

## 技术栈

- **UI**：SwiftUI（iOS 15+，非 `@Observable` 宏）
- **音频**：AVAudioEngine + installTap
- **网络**：Network framework（NWConnection TCP/UDP）+ URLSessionWebSocketTask（Web）
- **编解码**：libopus（本地 SPM 包 `MicYouOpus`，二进制 target `OpusXCF`）
- **协议**：手卷 protobuf（`ProtoWire.swift`，prost 兼容）+ SwiftProtobuf SPM 依赖（可选生成路径）
- **工程**：XcodeGen `project.yml` 为源 → 生成 `.xcodeproj`
- **架构**：MVVM（`ObservableObject` + `@Published`）

## 三种连接模式

| 模式 | 传输 | 目标 | UDP 音频 |
|---|---|---|---|
| **Wi-Fi** | TCP 8554 + UDP 8555 | LAN IP（mDNS `_micyou._tcp.`） | 是（Both 模式） |
| **USB** | TCP 8554 | `127.0.0.1`（Mac 运行 `iproxy`） | 是（Both 模式） |
| **Web** | `wss://<ip>:8443/ws` | 用户填主机 | 否（WebSocket Float32 PCM） |

## 构建（macOS）

```bash
# 一键准备：安装工具 + 构建 opus + 生成 proto + 生成 Xcode 工程
bash ios/setup.sh

# 打开 Xcode
open ios/MicYou.xcodeproj

# 或命令行构建
xcodebuild build \
  -project ios/MicYou.xcodeproj \
  -scheme MicYou \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# 运行测试
xcodebuild test \
  -project ios/MicYou.xcodeproj \
  -scheme MicYou \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

## USB 模式设置

iOS 无 `adb reverse`，需 Mac 端运行 `iproxy`（libimobiledevice）：

```bash
brew install libimobiledevice
iproxy 8554 8554 &     # TCP
iproxy 8555 8555 &     # UDP（若用 Both）
```

详见 `docs/ios/02-connection-modes.md` §3 + §7 排障。

## 目录结构

```
ios/
├── project.yml              # XcodeGen 工程定义（源）
├── setup.sh                 # 一键环境准备
├── MicYou/                  # App 源码
│   ├── App/                 # MicYouApp + ContentView
│   ├── Audio/               # 采集/Opus/FEC/管线/引擎/会话
│   ├── Network/             # TCP/UDP/Web 传输 + mDNS 发现
│   ├── Protocol/            # 线上协议（常量/protobuf/帧编解码）
│   ├── ViewModel/           # MainViewModel + 连接类型
│   ├── Settings/            # AppSettings + 主题 + 枚举
│   ├── Views/               # HomeView/连接面板/设置/可视化
│   ├── Util/                # L10n/ColorHex/ScreenLifecycle
│   └── Resources/           # 本地化 .strings × 5 语言
├── MicYouTests/             # 单元测试
└── MicYouOpus/              # libopus SPM 包
    ├── Package.swift
    ├── build-opus.sh
    └── Sources/MicYouOpus/  # OpusEncoder/Decoder 桥接
```

## 线上协议

- TCP 帧：`[magic "MicY" 4B BE][length 4B BE][protobuf MessageWrapper]`
- UDP 帧：`[magic "MicU" 4B BE][length 4B BE][protobuf]`，port = TCP+1
- 握手：client `"MicYouCheck1"` → server `"MicYouCheck2"` → client `ConnectMessage{sessionId}`
- FEC：每 12 个 Opus 包 XOR 生成 1 个 FEC 包
- 详见 `docs/ios/01-wire-protocol.md`

## CI

GitHub Actions `.github/workflows/ios-ci.yml`：macOS runner → setup.sh → xcodebuild test。

## 文档

全部设计文档在 `docs/ios/`（00-overview ～ 11-roadmap-commits）。
