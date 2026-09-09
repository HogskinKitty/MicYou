#!/usr/bin/env bash
# 构建 libopus.xcframework（macOS 上运行）
#
# 产物：ios/MicYouOpus/opus.xcframework
# 包含 slice：iphoneos-arm64、iphonesimulator-arm64、iphonesimulator-x86_64
#
# 本脚本在 macOS 上执行；Linux/CI 环境无法运行（需 Xcode）。
# CI 可缓存产物或在本机构建后提交（若用 git-lfs）。
set -euo pipefail
cd "$(dirname "$0")"

OPUS_VERSION="${OPUS_VERSION:-1.5.2}"
WORKDIR="build-work"
OUT="opus.xcframework"

if [ -d "$OUT" ]; then
  echo "opus.xcframework 已存在，跳过（删除后可重建）"
  exit 0
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "错误：需要 macOS + Xcode 才能构建 opus.xcframework" >&2
  echo "若已在别处构建，请把 opus.xcframework 放到 ios/MicYouOpus/" >&2
  exit 1
fi

echo "==> 下载 opus-$OPUS_VERSION 源码"
mkdir -p "$WORKDIR"
curl -fsSL "https://downloads.xiph.org/releases/opus/opus-$OPUS_VERSION.tar.gz" -o "$WORKDIR/opus.tar.gz"
tar -C "$WORKDIR" -xzf opus.tar.gz

build_slice() {
  local sdk="$1" arch="$2" outdir="$WORKDIR/build-$sdk-$arch"
  echo "==> 构建 slice：$sdk $arch"
  mkdir -p "$outdir"
  ( cd "$WORKDIR/opus-$OPUS_VERSION" && \
    make distclean 2>/dev/null || true && \
    CC="$(xcrun --sdk "$sdk" -f clang)" \
    CFLAGS="-arch $arch -isysroot $(xcrun --sdk "$sdk" --show-sdk-path) -O2" \
    ./configure --host="$arch-apple-darwin" --enable-static --disable-shared --disable-doc --disable-extra-programs && \
    make -j"$(sysctl -n hw.ncpu)" && \
    cp -R include "$outdir/" && cp .libs/libopus.a "$outdir/" )
}

build_slice iphoneos arm64
build_slice iphonesimulator arm64
build_slice iphonesimulator x86_64

echo "==> 合并 xcframework"
xcodebuild -create-xcframework \
  -library "$WORKDIR/build-iphoneos-arm64/libopus.a"     -headers "$WORKDIR/build-iphoneos-arm64/include" \
  -library "$WORKDIR/build-iphonesimulator-arm64/libopus.a"  -headers "$WORKDIR/build-iphonesimulator-arm64/include" \
  -library "$WORKDIR/build-iphonesimulator-x86_64/libopus.a" -headers "$WORKDIR/build-iphonesimulator-x86_64/include" \
  -output "$OUT"

echo "==> 完成：$OUT"
echo "注意：B6 会更新 Package.swift 引用此 xcframework（binary target）。"
