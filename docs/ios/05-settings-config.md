# iOS · 设置与持久化

> 对齐 Android `settings/Settings.kt`（SharedPreferences `"android_mic_prefs"`）+
> `SettingsViewModel`。iOS 用 `UserDefaults`，**键名完全一致**便于文档对照。

## 1. 存储后端

- `UserDefaults(suiteName: "group.micyou")`（App Group，为后续 Widget/扩展预留）。
- 对齐 Android `SharedPreferences`：同步、轻量、无加密。
- `mirror_cdk`：Android 用 AES/GCM 加密（`Settings.kt:72`）。iOS 等价用 Keychain
  存储 `mirror_cdk`（`SecItemAdd`），而非 UserDefaults 明文。文档注明此差异。

## 2. 设置项清单（键 · 类型 · 默认值 · 对齐）

| 键 | 类型 | 默认 | 对齐 Android | 说明 |
|---|---|---|---|---|
| `connection_mode` | String(enum) | `wifi` | `connection_mode` | wifi/usb/web |
| `transport_protocol` | String(enum) | `both` | `transport_protocol` | tcp/both |
| `ip_address` | String | `192.168.1.5` | `ip_address` | 目标 IP |
| `port` | String(Int) | `8554` | `port` | TCP 端口 |
| `sample_rate` | String(enum) | `48000` | `sample_rate` | 16000/44100/48000 |
| `channel_count` | String(enum) | `stereo` | `channel_count` | mono/stereo |
| `audio_format` | String(enum) | `pcm_float` | `audio_format` | pcm8/pcm16/pcmFloat/pcm24 |
| `is_auto_config` | Bool | `true` | `is_auto_config` | 自动选最优音频设置 |
| `audio_source` | String(enum) | `mic` | `android_audio_source` | iOS 映射：mic/voiceCommunication/voiceRecognition/voicePerformance/camcorder/unprocessed |
| `enable_ns` | Bool | `false` | (AudioEngine `enableNS`) | 系统降噪（iOS 经 voiceChat mode） |
| `enable_agc` | Bool | `false` | (AudioEngine `enableAGC`) | 自动增益 |
| `theme_mode` | String(enum) | `system` | `theme_mode` | system/light/dark |
| `seed_color` | Int64(Hex) | `0xFF1565C0` | `seed_color` | 种子色 |
| `use_dynamic_color` | Bool | `false` | `use_dynamic_color` | iOS 16+ 无 Material You，映射为系统强调色 |
| `oled_pure_black` | Bool | `false` | `oled_pure_black` | 暗色纯黑背景 |
| `palette_style` | String(enum) | `tonalSpot` | `palette_style` | iOS 简化为种子色变体 |
| `use_expressive_shapes` | Bool | `true` | `use_expressive_shapes` | iOS 圆角策略 |
| `language` | String(enum) | `system` | `language` | system/zh/zh-TW/zh-HK/en/ca |
| `auto_start` | Bool | `false` | `auto_start` | 启动即开始流式 |
| `keep_screen_on` | Bool | `false` | `keep_screen_on` | 保持屏幕常亮 |
| `auto_check_update` | Bool | `true` | `auto_check_update` | 自动检查更新 |
| `use_mirror_download` | Bool | `false` | `use_mirror_download` | 镜像下载 |
| `mirror_cdk` | String | `""` | `mirror_cdk` | **Keychain** 存储 |
| `visualizer_style` | String(enum) | `volumeRing` | `visualizer_style` | volumeRing/ripple/bars/wave/glow/particles |
| `background_image_path` | String? | nil | `background_image_path` | 自定义背景 |
| `background_brightness` | Float | 1.0 | `background_brightness` | |
| `background_blur` | Float | 0.0 | `background_blur` | |
| `card_opacity` | Float | 1.0 | `card_opacity` | |
| `enable_haze_effect` | Bool | `false` | `enable_haze_effect` | iOS 用 `.ultraThinMaterial` |
| `has_launched_before` | Bool | `false` | `has_launched_before` | 首次启动引导 |

## 3. 枚举定义（对齐 Android）

```swift
enum ConnectionMode: String { case wifi, usb, web }
enum TransportProtocol: String { case tcp, both }
enum SampleRate: Int { case rate16000 = 16000, rate44100 = 44100, rate48000 = 48000 }
enum ChannelCount: Int, CaseIterable { case mono = 1, stereo = 2 }
enum AudioFormat: Int { case pcm8bit = 3, pcm16bit = 2, pcm24bit = 6, pcmFloat = 4 }
enum StreamState { case idle, connecting, streaming, error }
enum ThemeMode: String { case system, light, dark }
enum AppLanguage: String { case system, zh, zhTW = "zh-TW", zhHK = "zh-HK", en, ca }
enum VisualizerStyle: String { case volumeRing, ripple, bars, wave, glow, particles }
enum AudioSource: String { case mic, voiceCommunication, voiceRecognition, voicePerformance, camcorder, unprocessed }
```

> `AudioFormat.value` 为**线上协议值**（对齐 `AudioSettings.kt:37`）。`pcm24bit` 运行时降级 `pcm16bit`。

## 4. 自动配置（对齐 `is_auto_config`）

- `isAutoConfig=true` 时按模式自动选采样率/声道/格式：
  - Wi-Fi/USB：48k / stereo / pcmFloat（对齐 Android 默认）。
  - Web：固定 48k / mono / float（Web 协议要求）。
- 用户手改任一音频项 → `isAutoConfig` 自动关。

## 5. SettingsStore API（对齐 `Settings` 接口）

```swift
protocol SettingsStore {
    func string(_ key: String, default: String) -> String
    func setString(_ key: String, _ value: String)
    func bool(_ key: String, default: Bool) -> Bool
    func setBool(_ key: String, _ value: Bool)
    func int(_ key: String, default: Int) -> Int
    func setInt(_ key: String, _ value: Int)
    func float(_ key: String, default: Float) -> Float
    func setFloat(_ key: String, _ value: Float)
}
```
- `mirror_cdk` 走 Keychain（`KeychainStore`），其余走 UserDefaults。
- 对齐 Android `SettingsFactory.getSettings()` 单例。

## 6. 与桌面共享配置的关系

- 桌面用 `~/.config/micyou/*.json`；iOS 用 UserDefaults——**不共享文件**（不同平台）。
- iOS 不读写桌面 `settings.json`/`server.json`。设置语义对齐，存储独立。

## 7. 首次启动

- `has_launched_before == false` → 显示首次启动引导（权限说明 + 模式选择），对齐 Android `showFirstLaunchDialog`。
- 引导完成后置 `has_launched_before = true`。
