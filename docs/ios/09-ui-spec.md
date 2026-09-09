# iOS · UI 规范

> 对齐 Android `ui/MobileHome.kt` + `ui/MobileSettingsContent.kt` + `ui/visualizer/`。
> iOS 用 SwiftUI + 系统组件（无 Material 3，用原生 `Form`/`List`/`Picker`/`Toggle`）。

## 1. 主界面（`HomeView`，对齐 `MobileHome`）

```
┌───────────────────────────────────┐
│  MicYou                  [设置⚙]  │
├───────────────────────────────────┤
│  连接模式：[Wi-Fi][USB][Web]      │  segmented
│  IP 地址：[192.168.1.5    ]       │  TextField（USB 灰显 127.0.0.1）
│  端口：  [8554]                   │  TextField
│  传输：  [TCP+UDP] (Wi-Fi/USB)    │  Picker（Web 模式隐藏）
│  ┌─ 扫描设备 ─┐ (Wi-Fi)           │
│  │ Desktop-PC  192.168.1.10:8554 │  List（点选填入 IP/端口）
│  └────────────┘                  │
├───────────────────────────────────┤
│       ╭─────────╮                 │
│       │  ▶/⏸    │  流式开关       │  大按钮（idle=开始 / streaming=停止）
│       ╰─────────╯                 │
│       [音量环可视化]              │  Visualizer（audioLevel 驱动）
│       静音 [🔘]                   │  Toggle
├───────────────────────────────────┤
│  状态：流式中 ●  延迟 23ms        │  状态行
└───────────────────────────────────┘
```

- 流式按钮：`idle`→"开始"（▶）、`connecting`→"连接中…"（转圈）、
  `streaming`→"停止"（⏸）、`error`→"重试"（⚠）。
- 错误 → 弹 `ConnectionErrorDialog`（对齐 Android `ConnectionErrorDialog`）：标题 + 消息 + 建议 + 重试/取消。
- `audioLevel` 驱动可视化（`VisualizerStyle` 6 种，对齐 `MainViewModel.kt:62`）。

## 2. 设置界面（`SettingsView`，对齐 `MobileSettingsContent`）

用 SwiftUI `Form` + 分区（`Section`）：

### 2.1 音频区
- 采样率（Picker：16000/44100/48000）
- 声道（Picker：Mono/Stereo）
- 音频格式（Picker：PCM16/PCM Float/PCM8；PCM24 不显示，对齐 `availableAudioFormats`）
- 音频源（Picker：Mic/VoiceCommunication/VoiceRecognition/VoicePerformance/Camcorder/Unprocessed）
- 自动配置音频（Toggle）
- 内建音频处理（Toggle：NS/AGC，对齐 `androidAudioProcessingLabel`）

### 2.2 外观区
- 主题（Picker：跟随系统/浅色/深色）
- 种子色（ColorPicker，对齐 `ui/ColorPicker.kt`）
- 动态颜色（Toggle；iOS 16+ 无 Material You，映射系统强调色）
- OLED 纯黑（Toggle）
- 可视化样式（Picker：6 种）
- 语言（Picker：跟随系统/简中/繁中/粤语/English/猫猫语）

### 2.3 通用区
- 自动开始（Toggle）
- 保持屏幕常亮（Toggle）
- 自动检查更新（Toggle）
- 检查更新（按钮）
- 导出日志（按钮，对齐 `exportLog`）

### 2.4 关于区
- 版本号（2.0.3）
- 开源许可（对齐 `OpenSourceLibraries.kt`）
- 贡献者/赞助（对齐 `ContributorsDialog`/`SponsorDialog`，可简化）

## 3. 可视化（对齐 `ui/visualizer/AudioVisualizers.kt`）

- 输入：`audioLevel: Float`（0…1）+ `VisualizerStyle`。
- 6 种样式：`volumeRing`（音量环）/ `ripple`（涟漪）/ `bars`（柱状）/ `wave`（波形）/ `glow`（光晕）/ `particles`（粒子）。
- 用 SwiftUI `Canvas` / `TimelineView` 绘制；轻量，不阻塞采集。
- 对齐 Android `VisualizerStyle` 枚举。

## 4. 主题（对齐 `theme/Theme.kt`）

- `ThemeMode`：system/light/dark → SwiftUI `.preferredColorScheme`。
- 种子色驱动强调色（iOS 无 Material You tonalSpot，用种子色直接作 `accentColor`/`tint`）。
- `oledPureBlack` → 暗色下背景 `Color.black`。
- `useDynamicColor` → iOS 16+ 可用系统强调色；iOS 15 回退种子色。
- 对齐 Android 8 主题 × 明暗：iOS 简化为种子色 + 明暗，文档注明差异。

## 5. 背景自定义（对齐 `ui/background/`）

- `background_image_path` → `Image` 铺底 + 模糊（`background_blur`）+ 亮度（`background_brightness`）。
- `card_opacity` → 卡片透明度。
- `enable_haze_effect` → SwiftUI `.ultraThinMaterial`（对齐 Android `haze`）。
- 选图用 `PhotosPicker`（iOS 16+）或 `UIImagePickerController`（iOS 15）。

## 6. 首次启动引导（对齐 `showFirstLaunchDialog`）

- 半屏 sheet：欢迎 + 麦克风权限说明 + "授权并开始"。
- 完成置 `has_launched_before = true`。

## 7. 与 Android 对应

| Android | iOS |
|---|---|
| `MobileHome.kt`（Compose） | `HomeView.swift`（SwiftUI） |
| `MobileSettingsContent.kt` | `SettingsView.swift`（`Form`） |
| Material 3 组件 | SwiftUI 原生 `Form`/`List`/`Picker`/`Toggle`/`Section` |
| `ColorPicker.kt` | SwiftUI `ColorPicker` |
| `AudioVisualizers.kt` | `VisualizerView.swift`（`Canvas`） |
| 状态驱动 Dialog（无 Navigation） | SwiftUI `.sheet`/`.alert`（无 NavigationStack） |
| `ExpressiveShapes`/`ExpressiveComponents` | SwiftUI 圆角策略（简化） |
