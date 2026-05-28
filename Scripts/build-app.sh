#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
SCRATCH_PATH="${SCRATCH_PATH:-"$ROOT_DIR/.build-app"}"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
APP_DIR="$ROOT_DIR/dist/EchoV.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SPEAKER_VERIFIER_ORT_DIR="${SPEAKER_VERIFIER_ORT_DIR:-"$ROOT_DIR/.build-deps/onnxruntime/onnxruntime-osx-arm64-1.19.2"}"
SPEAKER_VERIFIER_SUPPORT_DIR="$RESOURCES_DIR/SpeakerVerifierRuntime"

cd "$ROOT_DIR"

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-"$SCRATCH_PATH/clang-module-cache"}"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-"$SCRATCH_PATH/swiftpm-module-cache"}"

swift build \
  -c "$CONFIGURATION" \
  --scratch-path "$SCRATCH_PATH"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$SCRATCH_PATH/$CONFIGURATION/EchoV" "$MACOS_DIR/EchoV"
cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Packaging/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "$ROOT_DIR/THIRD_PARTY_NOTICES.md" "$RESOURCES_DIR/THIRD_PARTY_NOTICES.md"
printf "APPL????" > "$CONTENTS_DIR/PkgInfo"

if [[ ! -f "$SPEAKER_VERIFIER_ORT_DIR/include/onnxruntime_cxx_api.h" || ! -f "$SPEAKER_VERIFIER_ORT_DIR/lib/libonnxruntime.1.19.2.dylib" ]]; then
  echo "Missing ONNX Runtime C package at $SPEAKER_VERIFIER_ORT_DIR" >&2
  echo "Set SPEAKER_VERIFIER_ORT_DIR to onnxruntime-osx-arm64-1.19.2 before building EchoV." >&2
  exit 1
fi

mkdir -p "$SPEAKER_VERIFIER_SUPPORT_DIR/bin" "$SPEAKER_VERIFIER_SUPPORT_DIR/lib"

clang++ \
  -std=c++17 \
  -O3 \
  -I "$SPEAKER_VERIFIER_ORT_DIR/include" \
  "$ROOT_DIR/Tools/SpeakerVerifier/Native/speaker_verifier.cpp" \
  -L "$SPEAKER_VERIFIER_ORT_DIR/lib" \
  -lonnxruntime \
  -Wl,-rpath,@loader_path/../lib \
  -framework AudioToolbox \
  -framework CoreFoundation \
  -o "$SPEAKER_VERIFIER_SUPPORT_DIR/bin/speaker-verifier"

cp "$SPEAKER_VERIFIER_ORT_DIR/lib/libonnxruntime.1.19.2.dylib" "$SPEAKER_VERIFIER_SUPPORT_DIR/lib/libonnxruntime.1.19.2.dylib"
ln -sf libonnxruntime.1.19.2.dylib "$SPEAKER_VERIFIER_SUPPORT_DIR/lib/libonnxruntime.dylib"
cp "$SPEAKER_VERIFIER_ORT_DIR/LICENSE" "$SPEAKER_VERIFIER_SUPPORT_DIR/LICENSE.onnxruntime"
cp "$SPEAKER_VERIFIER_ORT_DIR/ThirdPartyNotices.txt" "$SPEAKER_VERIFIER_SUPPORT_DIR/NOTICE.onnxruntime"

codesign \
  --force \
  --sign "$CODE_SIGN_IDENTITY" \
  "$SPEAKER_VERIFIER_SUPPORT_DIR/bin/speaker-verifier"

codesign \
  --force \
  --sign "$CODE_SIGN_IDENTITY" \
  "$SPEAKER_VERIFIER_SUPPORT_DIR/lib/libonnxruntime.1.19.2.dylib"

codesign \
  --force \
  --sign "$CODE_SIGN_IDENTITY" \
  --entitlements "$ROOT_DIR/Packaging/EchoV.entitlements" \
  "$APP_DIR"

echo "Built $APP_DIR"
echo "Signed with: $CODE_SIGN_IDENTITY"
