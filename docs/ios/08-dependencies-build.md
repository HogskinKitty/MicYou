# iOS · 依赖与构建

> 技术栈：SwiftUI + AVAudioEngine + Network framework + SwiftProtobuf + libopus。
> 部署目标 iOS 15.0。Xcode 15+。SPM 管理依赖。

## 1. SPM 依赖

| 包 | 来源 | 用途 | 对齐 Android |
|---|---|---|---|
| `SwiftProtobuf` | `apple/swift-protobuf`（GitHub SPM） | protobuf 编解码 | kotlinx-serialization-protobuf |
| `MicYouOpus`（本地包） | `ios/MicYouOpus/` | libopus C 桥接 | Concentus |
| `Network` / `AVFoundation` | 系统框架 | TCP/UDP/WebSocket / 音频 | ktor / AudioRecord |

> 不引第三方 UI/日志包（SwiftUI + OSLog 足够）。不引 Combine 替代品。

## 2. SwiftProtobuf 集成

1. 复制 `tauri-app/crates/micyou-protocol/proto/network.proto` → `ios/Protos/network.proto`（**不改原文件**）。
2. 安装 `protoc-gen-swift`（CI 用 `brew install swift-protobuf`；本地同）。
3. 生成：`protoc --swift_out=ios/MicYou/Protocol/Generated ios/Protos/network.proto`。
4. 产物 `network.swift`（`MessageWrapper` 等 `SwiftProtobuf.Message`）入库或 build phase 生成。
5. 用法：`try wrapper.serializedData()` / `try MessageWrapper(serializedData: bytes)`。

## 3. libopus 集成（`MicYouOpus` 本地 SPM 包）

### 3.1 xcframework 构建（macOS 上执行）
```bash
# 1. 下载 opus 官方源码（如 opus-1.5.2.tar.gz）
# 2. 为每个 slice 构建 static lib：
#    - iphoneos   arm64
#    - iphonesimulator arm64
#    - iphonesimulator x86_64
# 3. xcodebuild -create-xcframework 合并
xcodebuild -create-xcframework \
  -library build/ios/libopus.a -headers build/ios/include \
  -library build/sim-arm/libopus.a -headers build/sim-arm/include \
  -library build/sim-x86/libopus.a -headers build/sim-x86/include \
  -output ios/MicYouOpus/Sources/MicYouOpus/opus.xcframework
```
- 脚本 `ios/MicYouOpus/build-opus.sh`（macOS 运行；CI 可缓存产物）。
- **本环境（Linux）无法生成 xcframework**：脚本入库，二进制由用户/CI 在 macOS 产出。
- 若用户倾向现成 SPM wrapper（如 `SwiftOpus`），可在 B1 前确认替换。

### 3.2 SPM 包结构
```
ios/MicYouOpus/
├── Package.swift
└── Sources/MicYouOpus/
    ├── opus.xcframework/      # 构建产物（可 git-lfs 或 CI 生成）
    ├── module.modulemap       # 暴露 opus.h
    └── OpusEncoder.swift      # Swift 封装：create/encode/destroy
```
- `Package.swift` 声明 `.binaryTarget(name: "OpusXCF", path: "...opus.xcframework")`
  或 `.target` + `cSettings` + `publicHeadersPath`。
- Swift 封装：
  ```swift
  public final class OpusEncoder {
      public init(sampleRate: Int32, channels: Int32, application: Int32)
      public func encode(_ pcm: [Int16], frameSize: Int32) -> [UInt8]
      deinit { opus_encoder_destroy(handle) }
  }
  ```

## 4. Xcode 工程

- `ios/MicYou.xcodeproj`（`project.pbxproj` 入库；`xcuserdata` 已 gitignore）。
- Target `MicYou`（iOS app）：
  - `IPHONEOS_DEPLOYMENT_TARGET = 15.0`
  - `MARKETING_VERSION = 2.0.3`、`CURRENT_PROJECT_VERSION = 27`（对齐 `gradle.properties`）
  - `PRODUCT_BUNDLE_IDENTIFIER = top.micyou.ios`（对齐 Android `com.lanrhyme.micyou` 域名风格）
  - `SUPPORTED_PLATFORMS = iphoneos iphonesimulator`
  - `SWIFT_VERSION = 5.0`
- Build Phases：`protoc` 生成 Swift（或预生成入库）。
- 签名：本地开发 `CODE_SIGN_IDENTITY = "-"`（ad-hoc）；发布由用户配 Apple ID（文档说明，不在 CI 强签）。

## 5. CI（GitHub Actions，macOS runner）

- 新增 `.github/workflows/ios.yml`：
  - `runs-on: macos-14`（Xcode 15+）。
  - `brew install swift-protobuf`（生成 proto）。
  - 构建 opus.xcframework（或缓存）。
  - `xcodebuild -project ios/MicYou.xcodeproj -scheme MicYou -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build`。
  - 可选 `swiftlint`（若引入）。
- 对齐现有 `.github/workflows/development.yml` 风格（continue-on-error 不阻断其他平台）。

## 6. .gitignore 处理

- 现有 `.gitignore` 已含 `xcuserdata`、`*.xcodeproj/*` 例外（保留 `project.pbxproj`）。
- 新增（若需）：`ios/MicYouOpus/Sources/MicYouOpus/opus.xcframework`（若用 git-lfs/CI 生成不入库）。
- `ios/MicYou/Protocol/Generated/` 可入库（预生成）或 gitignore（build phase 生成）——选预生成入库，简化 CI。

## 7. 版本同步

- iOS 版本独立于 `gradle.properties`。初版手动对齐 2.0.3/27。
- 文档（`11-roadmap-commits.md`）说明：iOS 版本演进独立，不跑 `npm run sync-version`。

## 8. 与 Android 构建对应

| Android | iOS |
|---|---|
| `gradlew :composeApp:assembleDebug` | `xcodebuild build`（sim） |
| `libs.versions.toml` | SPM `Package.resolved` |
| `build.gradle.kts` 签名 env | Xcode signing config（用户配） |
| `compileSdk 36 / minSdk 24` | `IPHONEOS_DEPLOYMENT_TARGET = 15.0` |
