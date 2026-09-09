# iOS · 权限与生命周期

> 对齐 Android `AndroidManifest.xml` 权限 + `AudioService` 前台服务 +
> `MainActivity`。iOS 用 Info.plist 声明 + AVAudioSession + 场景生命周期。

## 1. 权限声明（Info.plist）

| Info.plist 键 | 值 | 对齐 Android | 触发时机 |
|---|---|---|---|
| `NSMicrophoneUsageDescription` | "MicYou 需要麦克风权限以采集音频发送到电脑" | `RECORD_AUDIO` | 首次采集 |
| `NSLocalNetworkUsageDescription` | "MicYou 需要本地网络权限以发现并连接电脑" | （Android 隐式） | 首次 mDNS 浏览（iOS 14+） |
| `NSBonjourServices` | `["_micyou._tcp"]` | — | mDNS 浏览声明 |
| `NSAppTransportSecurity` | `NSAllowsArbitraryLoads: true`（仅 web 模式自签 wss） | — | Web 模式 |

> iOS 无 `INTERNET`/`WAKE_LOCK` 显式权限（默认有出站网络；后台限制见 §3）。

## 2. 麦克风权限流程

```swift
// iOS 17+
AVAudioApplication.requestRecordPermission { granted in ... }
// iOS 15-16
AVAudioSession.sharedInstance().requestRecordPermission { granted in ... }
```
- 未授权 → 友好引导（对齐 Android `PermissionDialog`），不崩溃。
- 授权后 `AVAudioSession.setActive(true)` 再 `engine.start()`。
- 权限被撤销（设置里关）→ 停止流式 → `StreamState.error` + 引导重授权。

## 3. 前后台生命周期

### 3.1 iOS 后台限制
- iOS 后台**不允许持续麦克风采集**（除非 VoIP/音频后台模式，且 App Store 审核严格）。
- 策略（对齐 Android 前台 `AudioService` 保活，但 iOS 受限）：
  - **前台**：正常采集流式。
  - **进入后台**：默认**停止采集**（`StreamState.idle`），提示用户保持 app 前台。
  - 可选 `UIBackgroundModes: ["audio"]`（Info.plist）+ `AVAudioSession.category = .playAndRecord`
    尝试后台采集——但**仅本地构建/侧载可用，App Store 可能拒**。文档注明，默认不开。
- 对齐 Android `WAKE_LOCK` + 前台服务：iOS 无等价保活，靠用户保持前台。

### 3.2 keepScreenOn（对齐 Android `keepScreenOn`）
- `true` → `UIApplication.shared.isIdleTimerDisabled = true`（屏幕常亮）。
- `false` → 恢复系统默认。流式期间生效。

### 3.3 场景生命周期（SwiftUI）
- `@Environment(\.scenePhase)` 观察：
  - `.active` → 可恢复（若 `autoStart` 且之前在流式）。
  - `.background` → 按 §3.1 策略停止/保持。
  - `.inactive` → 短暂态，不处理。

## 4. AVAudioSession 配置（对齐 `AudioEngine.kt` 采集初始化）

```swift
let s = AVAudioSession.sharedInstance()
try s.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetoothA2DP])
try s.setPreferredSampleRate(Double(opusSampleRate))
try s.setPreferredIOBufferDuration(0.02)   // 20ms
try s.setActive(true)
```
- `mode = .voiceChat`：启用系统级降噪/AGC（对齐 Android `NoiseSuppressor`/`AutomaticGainControl`，
  由 `enable_ns`/`enable_agc` 控制是否依赖——iOS 无法单独开关硬件 NS/AGC，文档注明：
  `enableNS/enableAGC` 在 iOS 上映射为"是否使用 voiceChat mode"，true 用 voiceChat，false 用 `.default`）。
- 蓝牙麦克风：`allowBluetoothA2DP`/`allowBluetooth`（对齐 Android `BLUETOOTH_*` 权限）。

## 5. 中断处理

- `AVAudioSession` 中断通知（电话/闹钟）：暂停采集，中断结束自动恢复（对齐 Android 无显式处理，iOS 需显式）。
- `AVAudioSession.interruptionNotification` → 暂停/恢复 `engine`。

## 6. 与 Android 对应

| Android | iOS |
|---|---|
| `RECORD_AUDIO` 运行时权限 | `NSMicrophoneUsageDescription` + `requestRecordPermission` |
| `AudioService` 前台服务 + `WAKE_LOCK` | 前台采集 + `isIdleTimerDisabled`（后台受限） |
| `FOREGROUND_SERVICE_MICROPHONE` | （iOS 无等价，靠前台） |
| `BLUETOOTH_*` | `AVAudioSession` options `.allowBluetooth` |
| `CHANGE_WIFI_MULTICAST_STATE` | （iOS mDNS 自动处理） |
| `POST_NOTIFICATIONS` | （iOS 无前台服务通知需求） |
| `NoiseSuppressor`/`AutomaticGainControl` | `AVAudioSession.mode = .voiceChat` |

## 7. 首次启动引导

- `has_launched_before == false` → 弹引导：麦克风权限说明 + 模式选择 + "去授权"按钮。
- 对齐 Android `showFirstLaunchDialog`。
