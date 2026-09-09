# iOS · 本地化

> 对齐 Android `res/values*/strings.xml`（en/zh/zh-rTW/zh-rHK/ca/zh-rHD）+
> `util/Localization.kt`（`AppLanguage` 枚举）。iOS 用 **String Catalog (`.xcstrings`)**。

## 1. 支持语言

| iOS 语言 | code | 对齐 Android | 显示名 |
|---|---|---|---|
| 跟随系统 | `system` | `AppLanguage.System` | 跟随系统 |
| 简体中文 | `zh` | `Chinese` | 简体中文 |
| 繁體中文 | `zh-TW` | `ChineseTraditional` | 繁體中文 |
| 粤语 | `zh-HK` | `Cantonese` | 粤语 |
| English | `en` | `English` | English |
| 猫猫语 | `ca` | `ChineseCat` | 中文（猫猫语）🐱 |
| 坚硬模式 | `zh-rHD` | `ChineseHard` | 中文（坚硬）— 初版可缺，后续补 |

> `AppLanguage` 枚举对齐 `Localization.kt`（`label`/`code`）。

## 2. String Catalog 方案

- 单个 `Localizable.xcstrings`（Xcode 15+ 编辑），编译为各 `.lproj/Localizable.strings`。
- 运行时兼容 iOS 15（String Catalog 是构建期产物）。
- 切换语言：`UserDefaults.standard.set([code], forKey: "AppleLanguages")` + 重发
  `NSLocalizedString`（或 SwiftUI `.environment(\.locale, Locale(identifier:))`）。
  - 对齐 Android `Localization.kt` 的 `AppLanguage` 切换 + `recreate`。

## 3. 字符串键命名（对齐 Android `strings.xml` 键）

沿用 Android 的 camelCase 键名作为 String Catalog key，保证语义一一对应。示例：

| key | en | zh |
|---|---|---|
| `appName` | MicYou | MicYou |
| `clickToStart` | Click to Start | 点击开始 |
| `cancel` | Cancel | 取消 |
| `audioFormatLabel` | Audio Format | 音频格式 |
| `channelCountLabel` | Channels | 声道 |
| `autoConfigLabel` | Auto Configure Audio | 自动配置音频 |
| `error.connectionRefused` | Connection refused (port %d) | 连接被拒绝（端口 %d） |
| `error.connectionTimeout` | Connection timeout | 连接超时 |
| `error.micPermissionDenied` | Microphone permission denied | 麦克风权限被拒绝 |
| `error.handshakeFailed` | Handshake failed | 握手失败 |
| `error.udpCircuitBreaker` | UDP send failed too many times | UDP 发送连续失败，已断开 |
| `error.heartbeatTimeout` | Server unreachable (heartbeat timeout) | 服务不可达（心跳超时） |

> 完整键集在实现时从 Android `strings.xml` 全量迁移；**新增/改名键必须同步所有语言**（对齐 AGENTS.md 约定）。

## 4. 回退策略

- 缺某语言某键 → 回退 `en`（String Catalog 默认行为）。
- `system` → 跟随设备语言；设备语言不在支持集 → 回退 `en`。

## 5. 与 Android 对应

| Android | iOS |
|---|---|
| `res/values/strings.xml`（en base） | `.xcstrings` `en` |
| `res/values-zh/strings.xml` | `.xcstrings` `zh` |
| `res/values-zh-rTW/` | `.xcstrings` `zh-TW` |
| `res/values-zh-rHK/` | `.xcstrings` `zh-HK` |
| `res/values-ca/` | `.xcstrings` `ca` |
| `getString(R.string.xxx)` | `String(localized: "xxx")` / `NSLocalizedString` |
| `AppLanguage` enum + 切换 | `AppLanguage` enum + `AppleLanguages` / `.environment(\.locale)` |

## 6. 实现要点

- 一个 `L10n` 命名空间/枚举封装 `String(localized:)`，避免散落硬编码。
- 所有用户可见字符串经 `L10n`，**禁止硬编码**（对齐 AGENTS.md）。
- 带参数文案用 `String(format:)` 或 String Catalog 插值 `%d`/`%@`。
