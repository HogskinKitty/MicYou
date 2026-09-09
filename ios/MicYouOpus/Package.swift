// swift-tools-version: 5.9
import PackageDescription

/// MicYouOpus：libopus 的 Swift 封装。
///
/// B1 阶段为纯 Swift 占位 target（不依赖二进制 xcframework），保证工程在未构建 opus 时
/// 也能解析编译。B6 将改为 `.binaryTarget(name: "OpusXCF", path: "opus.xcframework")`
/// + C 桥接，引入真正的 libopus。
let package = Package(
    name: "MicYouOpus",
    products: [
        .library(name: "MicYouOpus", targets: ["MicYouOpus"]),
    ],
    targets: [
        .target(
            name: "MicYouOpus",
            path: "Sources/MicYouOpus"
        ),
    ]
)
