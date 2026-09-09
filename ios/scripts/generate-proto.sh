#!/usr/bin/env bash
# 从 ios/Protos/network.proto 生成 SwiftProtobuf Swift 模型
# 产物：ios/MicYou/Protocol/Generated/network.swift
set -euo pipefail
cd "$(dirname "$0")/.."

PROTO="Protos/network.proto"
OUT="MicYou/Protocol/Generated"
mkdir -p "$OUT"

if ! command -v protoc >/dev/null 2>&1; then
  echo "错误：未找到 protoc。请先 'brew install protobuf'。" >&2
  exit 1
fi
if ! command -v protoc-gen-swift >/dev/null 2>&1; then
  echo "错误：未找到 protoc-gen-swift。请先 'brew install swift-protobuf'。" >&2
  exit 1
fi

echo "生成 SwiftProtobuf 模型：$PROTO -> $OUT/network.swift"
PATH="$PATH:$(dirname "$(command -v protoc-gen-swift)")" \
  protoc --swift_out="$OUT" --swift_opt=FileNaming=PathToUnderscores "$PROTO"

echo "完成：$(wc -l < "$OUT/network.swift") 行"
