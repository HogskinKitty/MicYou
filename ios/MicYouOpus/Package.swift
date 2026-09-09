// swift-tools-version: 5.9
import PackageDescription

/// MicYouOpus：libopus 的 Swift 封装（本地 SPM 包）。
///
/// 二进制 target `OpusXCF` 引用 `opus.xcframework`（由 `build-opus.sh` 在 macOS 生成，
/// 不入库）。Swift wrapper target `MicYouOpus` 通过 `import OpusXCF` 调用 C API。
///
/// 构建前提：先运行 `bash ios/MicYouOpus/build-opus.sh`（或 `ios/setup.sh`）生成 xcframework。
let package = Package(
    name: "MicYouOpus",
    products: [
        .library(name: "MicYouOpus", targets: ["MicYouOpus"]),
    ],
    targets: [
        .binaryTarget(
            name: "OpusXCF",
            path: "opus.xcframework"
        ),
        .target(
            name: "MicYouOpus",
            dependencies: ["OpusXCF"],
            path: "Sources/MicYouOpus"
        ),
    ]
)
