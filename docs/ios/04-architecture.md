# iOS · 架构与状态管理

> 对齐 Android MVVM（`MainViewModel` facade + `AppUiState` + `combine()`）。
> iOS 用 SwiftUI + `ObservableObject` + Combine。

## 1. 分层

```
┌─────────────────────────────────────────────┐
│  Views (SwiftUI)                             │  观察 ViewModel
├─────────────────────────────────────────────┤
│  ViewModel (ObservableObject)                │  持有 AudioEngine/Discovery/Settings
│   └ AppUiState (@Published)                  │  单一状态源
├─────────────────────────────────────────────┤
│  Audio   │  Network   │  Protocol  │ Settings│  领域层
│  Engine  │  Transport │  Codec     │  Store  │
├─────────────────────────────────────────────┤
│  AVAudioEngine │ NWConnection │ libopus │ UD  │  系统/三方
└─────────────────────────────────────────────┘
```

## 2. 模块职责

| 模块 | 职责 | 对齐 Android |
|---|---|---|
| `Protocol/` | SwiftProtobuf 模型、常量、`FrameCodec`（TCP/UDP 帧编解码） | `network/Protocol.kt` |
| `Network/` | `TcpTransport`（NWConnection TCP + 握手 + reader/writer）、`UdpTransport`、`WebSocketTransport`、`DeviceDiscovery`（NetService） | `network/DeviceDiscovery.kt` + `AudioEngine` 内 socket |
| `Audio/` | `AudioCaptureEngine`（AVAudioEngine tap）、`OpusEncoder`（libopus 桥接）、`FecEncoder`、`MicYouAudioEngine`（状态机主循环） | `audio/AudioEngine.kt` + `AudioSource` |
| `Settings/` | `SettingsStore`（UserDefaults）、`AppSettings` 模型 | `settings/Settings.kt` + `SettingsViewModel` |
| `ViewModel/` | `MainViewModel`（`ObservableObject`）+ `AppUiState` | `viewmodel/MainViewModel.kt` |
| `Views/` | `HomeView`、`SettingsView`、`Visualizer`、`Theme` | `ui/MobileHome.kt` 等 |

## 3. 状态管理

### 3.1 AppUiState（对齐 `MainViewModel.kt:75`）
```swift
struct AppUiState {
    var mode: ConnectionMode = .wifi
    var transportProtocol: TransportProtocol = .both
    var streamState: StreamState = .idle
    var ipAddress: String = "192.168.1.5"
    var port: String = "8554"
    var errorMessage: String? = nil
    var sampleRate: SampleRate = .rate48000
    var channelCount: ChannelCount = .stereo
    var audioFormat: AudioFormat = .pcmFloat
    var isMuted: Bool = false
    var isAutoConfig: Bool = true
    var audioSource: AudioSource = .mic
    var enableNS: Bool = false
    var enableAGC: Bool = false
    // 外观/通用
    var themeMode: ThemeMode = .system
    var seedColor: Color = .init(hex: 0xFF1565C0)
    var useDynamicColor: Bool = false
    var oledPureBlack: Bool = false
    var language: AppLanguage = .system
    var autoStart: Bool = false
    var keepScreenOn: Bool = false
    var autoCheckUpdate: Bool = true
    var visualizerStyle: VisualizerStyle = .volumeRing
    // 发现
    var discoveredDevices: [DiscoveredDevice] = []
    var isDiscovering: Bool = false
    // UI
    var snackbarMessage: String? = nil
    var showErrorDialog: Bool = false
}
```

### 3.2 ViewModel
```swift
@MainActor
final class MainViewModel: ObservableObject {
    @Published private(set) var state = AppUiState()
    private let audioEngine = MicYouAudioEngine()
    private let discovery = DeviceDiscovery()
    private let settings = SettingsStore()
    // 把 audioEngine/discovery/settings 的回调合并进 state（对齐 combine()）
}
```
- `@MainActor` 保证 UI 更新在主线程。
- `MicYouAudioEngine` 用 `AsyncStream`/Combine 把 `streamState`/`audioLevel`/`isMuted` 推给 ViewModel。
- 对齐 Android `combine(audioState, settingsState, updateState)` → 单一 `AppUiState`。

## 4. 并发模型

- `MicYouAudioEngine` 内部用 `Task` + `AsyncStream` 管理采集/发送循环（对齐 Android 协程 `lifecycleScope`）。
- `NWConnection` 用 `receive` 回调 + `async/await` 包装（`NWConnection` 原生支持 async）。
- 共享可变状态（序号、FEC buffer）放 `actor` 或 `@MainActor` + 串行化。
- 取消：`Task.cancel()`（对齐 Android `CancellationToken`/`Job.cancel()`）。
- 生命周期代际（对齐 `lifecycleGeneration`）：每次 start 递增，旧代际的回调被忽略。

## 5. 错误映射（对齐 `AudioEngine.kt:1026` + `ConnectionError.kt`）

| 条件 | iOS 错误文案键 | Android |
|---|---|---|
| TCP 连接被拒 | `error.connectionRefused` | `connectionRejected` |
| 连接超时 | `error.connectionTimeout` | `connectionTimeout` |
| 不可达 | `error.connectionUnreachable` | `connectionUnreachable` |
| 握手失败 | `error.handshakeFailed` | `errorHandshakeFailedDetailed` |
| 心跳超时 | `error.heartbeatTimeout` | "Heartbeat timeout" |
| UDP 熔断（500 次失败） | `error.udpCircuitBreaker` | `UdpCircuitBreakerException` |
| 麦克风权限拒绝 | `error.micPermissionDenied` | `errorRecordingPermissionDenied` |
| 通用断连 | `error.connectionDisconnected` | `connectionDisconnected` |

错误文案经本地化（`06-localization.md`），UI 弹 `ConnectionErrorDialog` 等价物。

## 6. 生命周期代际与重入保护

- 对齐 Android `startStopMutex` + `desiredRunning` + `lifecycleGeneration`：
  - 同时只允许一个活跃会话；start 时若已在运行则忽略。
  - stop 超时（`STOP_TIMEOUT_MS=5000`）记录 `stopTimedOutJob`，下次 start 检查。
- iOS 用 `AsyncSemaphore` 或 `actor` 串行化 start/stop。

## 7. 日志

- 对齐 `util/Logger.kt`：统一 `Logger`（OSLog `subsystem: "top.micyou.ios"`），分级 `i/d/w/e`。
- 设置页"导出日志"对齐 Android `exportLog`（iOS 用 `NSSharingService` 分享临时文件）。

## 8. 与 Android 对应

| Android | iOS |
|---|---|
| `MainViewModel : ViewModel` | `MainViewModel: ObservableObject` (`@MainActor`) |
| `MutableStateFlow<AppUiState>` + `combine` | `@Published var state: AppUiState` |
| `CoroutineScope(Dispatchers.IO)` | `Task.detached` / `async` |
| `Mutex` / `SupervisorJob` | `actor` / `AsyncSemaphore` / `Task` |
| `ContextHelper` | `UIApplication.shared` / 单例 |
