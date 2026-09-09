#!/usr/bin/env bash
# MicYou iOS 一次性环境准备（macOS）
#
# 1. 安装工具：swift-protobuf（protoc-gen-swift）、xcodegen
# 2. 构建 libopus.xcframework（MicYouOpus）
# 3. 从 network.proto 生成 Swift 模型
# 4. 用 XcodeGen 生成 MicYou.xcodeproj
#
# 用法：  bash ios/setup.sh
# 之后： open ios/MicYou.xcodeproj   或   xcodebuild -project ios/MicYou.xcodeproj -scheme MicYou build
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> [1/4] 安装工具（swift-protobuf, xcodegen）"
if ! command -v protoc-gen-swift >/dev/null 2>&1 || ! command -v xcodegen >/dev/null 2>&1; then
  brew install swift-protobuf xcodegen
else
  echo "    已安装，跳过"
fi

echo "==> [2/4] 构建 libopus.xcframework"
bash ios/MicYouOpus/build-opus.sh

echo "==> [3/4] 生成 SwiftProtobuf 模型"
bash ios/scripts/generate-proto.sh

echo "==> [4/4] 用 XcodeGen 生成 Xcode 工程"
xcodegen generate --spec ios/project.yml --project ios

echo "==> 完成。现在可以： open ios/MicYou.xcodeproj"
