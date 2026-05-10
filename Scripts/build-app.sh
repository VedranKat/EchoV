#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
SCRATCH_PATH="${SCRATCH_PATH:-"$ROOT_DIR/.build-app"}"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
APP_DIR="$ROOT_DIR/dist/EchoV.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

cd "$ROOT_DIR"

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-"$SCRATCH_PATH/clang-module-cache"}"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-"$SCRATCH_PATH/swiftpm-module-cache"}"

swift build \
  -c "$CONFIGURATION" \
  --scratch-path "$SCRATCH_PATH"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"

cp "$SCRATCH_PATH/$CONFIGURATION/EchoV" "$MACOS_DIR/EchoV"
cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS_DIR/Info.plist"
printf "APPL????" > "$CONTENTS_DIR/PkgInfo"

codesign \
  --force \
  --sign "$CODE_SIGN_IDENTITY" \
  --entitlements "$ROOT_DIR/Packaging/EchoV.entitlements" \
  "$APP_DIR"

echo "Built $APP_DIR"
echo "Signed with: $CODE_SIGN_IDENTITY"
