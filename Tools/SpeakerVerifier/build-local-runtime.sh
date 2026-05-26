#!/usr/bin/env bash
set -euo pipefail

# Developer-only helper for building a complete macOS arm64 smoke-test runtime.
# The publishable model artifact is built by build-portable-model-artifact.sh.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SPEAKER_DIR="$ROOT_DIR/Tools/SpeakerVerifier"
PYTHON="${PYTHON:-"$SPEAKER_DIR/.venv/bin/python3"}"
BUILD_DIR="${BUILD_DIR:-"/private/tmp/echov-speaker-verifier"}"
ORT_DIR="${ORT_DIR:-"$BUILD_DIR/onnxruntime/onnxruntime-osx-arm64-1.19.2"}"
RUNTIME_DIR="$BUILD_DIR/runtime/speaker-verifier"
ARCHIVE_PATH="$BUILD_DIR/speaker-verifier-ecapa-speaker-v1-macos-arm64.tar.gz"

if [[ ! -x "$PYTHON" ]]; then
  echo "Missing Python export environment at $PYTHON" >&2
  exit 1
fi

if [[ ! -f "$ORT_DIR/include/onnxruntime_cxx_api.h" || ! -f "$ORT_DIR/lib/libonnxruntime.1.19.2.dylib" ]]; then
  echo "Missing ONNX Runtime C package at $ORT_DIR" >&2
  exit 1
fi

rm -rf "$RUNTIME_DIR" "$ARCHIVE_PATH"
mkdir -p "$RUNTIME_DIR/bin" "$RUNTIME_DIR/model" "$RUNTIME_DIR/lib"

"$PYTHON" "$SPEAKER_DIR/export_speechbrain_ecapa_to_onnx.py" \
  --output "$RUNTIME_DIR/model/ecapa-speaker-v1.onnx" \
  --fbank-output "$RUNTIME_DIR/model/fbank-80x201-f32.bin"

clang++ \
  -std=c++17 \
  -O3 \
  -I "$ORT_DIR/include" \
  "$SPEAKER_DIR/Native/speaker_verifier.cpp" \
  -L "$ORT_DIR/lib" \
  -lonnxruntime \
  -Wl,-rpath,@loader_path/../lib \
  -framework AudioToolbox \
  -framework CoreFoundation \
  -o "$RUNTIME_DIR/bin/speaker-verifier"

cp "$ORT_DIR/lib/libonnxruntime.1.19.2.dylib" "$RUNTIME_DIR/lib/libonnxruntime.1.19.2.dylib"
ln -sf libonnxruntime.1.19.2.dylib "$RUNTIME_DIR/lib/libonnxruntime.dylib"
cp "$ROOT_DIR/LICENSE" "$RUNTIME_DIR/LICENSE"
cp "$SPEAKER_DIR/NOTICE.runtime" "$RUNTIME_DIR/NOTICE"
cp "$SPEAKER_DIR/README.runtime.md" "$RUNTIME_DIR/README.md"
cp "$ORT_DIR/LICENSE" "$RUNTIME_DIR/LICENSE.onnxruntime"
cp "$ORT_DIR/ThirdPartyNotices.txt" "$RUNTIME_DIR/NOTICE.onnxruntime"

cat > "$RUNTIME_DIR/manifest.json" <<JSON
{
  "schema_version": 1,
  "package": {
    "name": "SpeechBrain ECAPA Speaker Verifier ONNX Runtime",
    "version": "ecapa-speaker-v1",
    "platform": "macos-arm64",
    "architecture": "arm64"
  },
  "entrypoint": "bin/speaker-verifier",
  "model": {
    "id": "speechbrain/spkrec-ecapa-voxceleb-onnx",
    "file": "model/ecapa-speaker-v1.onnx",
    "upstream": "speechbrain/spkrec-ecapa-voxceleb",
    "upstream_url": "https://huggingface.co/speechbrain/spkrec-ecapa-voxceleb",
    "upstream_license": "Apache-2.0",
    "embedding_dimensions": 192
  },
  "preprocessing": {
    "sample_rate_hz": 16000,
    "channels": 1,
    "feature_type": "SpeechBrain fbank",
    "fbank_file": "model/fbank-80x201-f32.bin",
    "n_fft": 400,
    "win_length": 400,
    "hop_length": 160,
    "n_mels": 80,
    "normalization": "sentence mean subtraction"
  },
  "runtime": {
    "name": "ONNX Runtime",
    "version": "1.19.2",
    "library": "lib/libonnxruntime.1.19.2.dylib"
  },
  "licenses": [
    "LICENSE",
    "NOTICE",
    "LICENSE.onnxruntime",
    "NOTICE.onnxruntime"
  ]
}
JSON

COPYFILE_DISABLE=1 tar \
  --no-xattrs \
  --format ustar \
  --uid 0 \
  --gid 0 \
  --uname root \
  --gname wheel \
  -C "$BUILD_DIR/runtime" \
  -czf "$ARCHIVE_PATH" \
  speaker-verifier

echo "$RUNTIME_DIR"
echo "$ARCHIVE_PATH"
shasum -a 256 "$ARCHIVE_PATH"
