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
SPEAKER_VERIFIER_ORT_PACKAGE_NAME="onnxruntime-osx-arm64-1.19.2"
SPEAKER_VERIFIER_ORT_DYLIB_NAME="libonnxruntime.1.19.2.dylib"
SPEAKER_VERIFIER_ORT_ARCHIVE_NAME="$SPEAKER_VERIFIER_ORT_PACKAGE_NAME.tgz"
SPEAKER_VERIFIER_ORT_ARCHIVE_SHA256="370c49770e2e1f243e17c7b227bb7f4b3da793b847d02f38016dc0e46c30fbe1"
SPEAKER_VERIFIER_ORT_URL="${SPEAKER_VERIFIER_ORT_URL:-"https://github.com/microsoft/onnxruntime/releases/download/v1.19.2/$SPEAKER_VERIFIER_ORT_ARCHIVE_NAME"}"
SPEAKER_VERIFIER_ORT_DIR="${SPEAKER_VERIFIER_ORT_DIR:-"$ROOT_DIR/.build-deps/onnxruntime/$SPEAKER_VERIFIER_ORT_PACKAGE_NAME"}"
SPEAKER_VERIFIER_SUPPORT_DIR="$RESOURCES_DIR/SpeakerVerifierRuntime"

download_tmp_dir=""

cleanup_download_tmp_dir() {
  if [[ -n "$download_tmp_dir" ]]; then
    rm -rf "$download_tmp_dir"
  fi
}

trap cleanup_download_tmp_dir EXIT

speaker_verifier_ort_available() {
  [[ -f "$SPEAKER_VERIFIER_ORT_DIR/include/onnxruntime_cxx_api.h" \
    && -f "$SPEAKER_VERIFIER_ORT_DIR/lib/$SPEAKER_VERIFIER_ORT_DYLIB_NAME" \
    && -f "$SPEAKER_VERIFIER_ORT_DIR/LICENSE" \
    && -f "$SPEAKER_VERIFIER_ORT_DIR/ThirdPartyNotices.txt" ]]
}

sha256_for_file() {
  local file="$1"
  local checksum
  checksum="$(shasum -a 256 "$file")"
  echo "${checksum%% *}"
}

install_speaker_verifier_ort() {
  if [[ "${SPEAKER_VERIFIER_ORT_AUTO_DOWNLOAD:-1}" == "0" ]]; then
    echo "Missing ONNX Runtime C package at $SPEAKER_VERIFIER_ORT_DIR" >&2
    echo "Set SPEAKER_VERIFIER_ORT_DIR to $SPEAKER_VERIFIER_ORT_PACKAGE_NAME or enable SPEAKER_VERIFIER_ORT_AUTO_DOWNLOAD." >&2
    exit 1
  fi

  if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
    echo "Missing ONNX Runtime C package at $SPEAKER_VERIFIER_ORT_DIR" >&2
    echo "Automatic ONNX Runtime download is pinned to macOS arm64. Set SPEAKER_VERIFIER_ORT_DIR for this machine." >&2
    exit 1
  fi

  command -v curl >/dev/null || {
    echo "curl is required to download ONNX Runtime. Install it or set SPEAKER_VERIFIER_ORT_DIR." >&2
    exit 1
  }
  command -v shasum >/dev/null || {
    echo "shasum is required to verify ONNX Runtime. Install it or set SPEAKER_VERIFIER_ORT_DIR." >&2
    exit 1
  }

  local parent_dir archive_url partial_archive archive_path extracted_dir actual_sha256
  parent_dir="$(dirname "$SPEAKER_VERIFIER_ORT_DIR")"
  archive_url="$SPEAKER_VERIFIER_ORT_URL"
  archive_path="$parent_dir/$SPEAKER_VERIFIER_ORT_ARCHIVE_NAME"

  mkdir -p "$parent_dir"
  download_tmp_dir="$(mktemp -d "$parent_dir/.onnxruntime-extract.XXXXXX")"
  partial_archive="$download_tmp_dir/$SPEAKER_VERIFIER_ORT_ARCHIVE_NAME.download"

  if [[ -f "$archive_path" ]]; then
    actual_sha256="$(sha256_for_file "$archive_path")"
    if [[ "$actual_sha256" == "$SPEAKER_VERIFIER_ORT_ARCHIVE_SHA256" ]]; then
      echo "Using cached ONNX Runtime archive at $archive_path"
    else
      echo "Cached ONNX Runtime archive checksum mismatch; downloading a fresh copy." >&2
      rm -f "$archive_path"
    fi
  fi

  if [[ ! -f "$archive_path" ]]; then
    echo "Downloading ONNX Runtime C package from $archive_url"
    curl --fail --location --retry 3 --connect-timeout 20 --output "$partial_archive" "$archive_url"

    actual_sha256="$(sha256_for_file "$partial_archive")"
    if [[ "$actual_sha256" != "$SPEAKER_VERIFIER_ORT_ARCHIVE_SHA256" ]]; then
      echo "Downloaded ONNX Runtime archive checksum mismatch." >&2
      echo "Expected: $SPEAKER_VERIFIER_ORT_ARCHIVE_SHA256" >&2
      echo "Actual:   $actual_sha256" >&2
      exit 1
    fi

    mv "$partial_archive" "$archive_path"
  fi

  tar -xzf "$archive_path" -C "$download_tmp_dir"

  extracted_dir="$download_tmp_dir/$SPEAKER_VERIFIER_ORT_PACKAGE_NAME"
  if [[ ! -f "$extracted_dir/include/onnxruntime_cxx_api.h" || ! -f "$extracted_dir/lib/$SPEAKER_VERIFIER_ORT_DYLIB_NAME" ]]; then
    echo "Downloaded ONNX Runtime archive did not contain the expected macOS arm64 C package." >&2
    exit 1
  fi

  rm -rf "$SPEAKER_VERIFIER_ORT_DIR"
  mv "$extracted_dir" "$SPEAKER_VERIFIER_ORT_DIR"
  rm -rf "$download_tmp_dir"
  download_tmp_dir=""
}

cd "$ROOT_DIR"

if ! speaker_verifier_ort_available; then
  install_speaker_verifier_ort
fi

if ! speaker_verifier_ort_available; then
  echo "Missing ONNX Runtime C package at $SPEAKER_VERIFIER_ORT_DIR" >&2
  echo "Set SPEAKER_VERIFIER_ORT_DIR to $SPEAKER_VERIFIER_ORT_PACKAGE_NAME before building EchoV." >&2
  exit 1
fi

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-"$SCRATCH_PATH/clang-module-cache"}"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-"$SCRATCH_PATH/swiftpm-module-cache"}"

SWIFT_BUILD_ARGS=(
  -c "$CONFIGURATION"
  --scratch-path "$SCRATCH_PATH"
)

if [[ "${ECHOV_DEV_DIAGNOSTICS:-0}" == "1" ]]; then
  SWIFT_BUILD_ARGS+=(-Xswiftc -DECHOV_DEV_DIAGNOSTICS)
fi

swift build "${SWIFT_BUILD_ARGS[@]}"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$SCRATCH_PATH/$CONFIGURATION/EchoV" "$MACOS_DIR/EchoV"
cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Packaging/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "$ROOT_DIR/THIRD_PARTY_NOTICES.md" "$RESOURCES_DIR/THIRD_PARTY_NOTICES.md"
printf "APPL????" > "$CONTENTS_DIR/PkgInfo"

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

cp "$SPEAKER_VERIFIER_ORT_DIR/lib/$SPEAKER_VERIFIER_ORT_DYLIB_NAME" "$SPEAKER_VERIFIER_SUPPORT_DIR/lib/$SPEAKER_VERIFIER_ORT_DYLIB_NAME"
ln -sf "$SPEAKER_VERIFIER_ORT_DYLIB_NAME" "$SPEAKER_VERIFIER_SUPPORT_DIR/lib/libonnxruntime.dylib"
cp "$SPEAKER_VERIFIER_ORT_DIR/LICENSE" "$SPEAKER_VERIFIER_SUPPORT_DIR/LICENSE.onnxruntime"
cp "$SPEAKER_VERIFIER_ORT_DIR/ThirdPartyNotices.txt" "$SPEAKER_VERIFIER_SUPPORT_DIR/NOTICE.onnxruntime"

codesign \
  --force \
  --sign "$CODE_SIGN_IDENTITY" \
  "$SPEAKER_VERIFIER_SUPPORT_DIR/bin/speaker-verifier"

codesign \
  --force \
  --sign "$CODE_SIGN_IDENTITY" \
  "$SPEAKER_VERIFIER_SUPPORT_DIR/lib/$SPEAKER_VERIFIER_ORT_DYLIB_NAME"

codesign \
  --force \
  --sign "$CODE_SIGN_IDENTITY" \
  --entitlements "$ROOT_DIR/Packaging/EchoV.entitlements" \
  "$APP_DIR"

echo "Built $APP_DIR"
echo "Signed with: $CODE_SIGN_IDENTITY"
