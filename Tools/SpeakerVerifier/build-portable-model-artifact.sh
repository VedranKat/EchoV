#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SPEAKER_DIR="$ROOT_DIR/Tools/SpeakerVerifier"
PYTHON="${PYTHON:-"$SPEAKER_DIR/.venv/bin/python3"}"
BUILD_DIR="${BUILD_DIR:-"/private/tmp/echov-speaker-verifier"}"
PACKAGE_NAME="speechbrain-spkrec-ecapa-voxceleb-onnx"
PACKAGE_DIR="$BUILD_DIR/model-package/$PACKAGE_NAME"
ARCHIVE_PATH="$BUILD_DIR/$PACKAGE_NAME.tar.gz"

if [[ ! -x "$PYTHON" ]]; then
  echo "Missing Python export environment at $PYTHON" >&2
  exit 1
fi

rm -rf "$PACKAGE_DIR" "$ARCHIVE_PATH"
mkdir -p "$PACKAGE_DIR/model"

"$PYTHON" "$SPEAKER_DIR/export_speechbrain_ecapa_to_onnx.py" \
  --output "$PACKAGE_DIR/model/ecapa-speaker-v1.onnx" \
  --fbank-output "$PACKAGE_DIR/model/fbank-80x201-f32.bin"

cp "$ROOT_DIR/LICENSE" "$PACKAGE_DIR/LICENSE"
cp "$SPEAKER_DIR/NOTICE.model" "$PACKAGE_DIR/NOTICE"
cp "$SPEAKER_DIR/README.model.md" "$PACKAGE_DIR/README.md"

cat > "$PACKAGE_DIR/manifest.json" <<JSON
{
  "schema_version": 1,
  "package": {
    "name": "SpeechBrain ECAPA Speaker Verifier ONNX",
    "version": "ecapa-speaker-v1",
    "format": "portable-onnx"
  },
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
  "licenses": [
    "LICENSE",
    "NOTICE"
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
  -C "$BUILD_DIR/model-package" \
  -czf "$ARCHIVE_PATH" \
  "$PACKAGE_NAME"

echo "$PACKAGE_DIR"
echo "$ARCHIVE_PATH"
shasum -a 256 "$ARCHIVE_PATH"
