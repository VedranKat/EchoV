# SpeechBrain ECAPA Speaker Verifier ONNX Runtime

This archive packages a macOS arm64 speaker-verification runtime around an
ONNX conversion of the upstream SpeechBrain ECAPA-TDNN speaker embedding
model.

It does not require user-installed Python, pip, PyTorch, torchaudio, or
SpeechBrain.

This package did not train or author the speaker embedding model. It
repackages and converts the upstream SpeechBrain ECAPA-TDNN model to ONNX so
it is easier to run locally.

## Contents

```text
manifest.json
README.md
LICENSE
NOTICE
LICENSE.onnxruntime
NOTICE.onnxruntime
bin/speaker-verifier
model/ecapa-speaker-v1.onnx
model/fbank-80x201-f32.bin
lib/libonnxruntime.1.19.2.dylib
lib/libonnxruntime.dylib
```

## Commands

```bash
bin/speaker-verifier --model model/ecapa-speaker-v1.onnx enroll --audio enrollment.wav
bin/speaker-verifier --model model/ecapa-speaker-v1.onnx score --audio same-speaker.wav --profile profile.json
```

The helper writes compact JSON to stdout and human-readable errors to stderr.
It expects local audio that CoreAudio can decode; 16 kHz mono WAV is the
preferred fixture and app-recording format.

## Model

The speaker embedding model is converted from:

```text
speechbrain/spkrec-ecapa-voxceleb
```

The upstream model is Apache-2.0 licensed. The conversion keeps the ECAPA
embedding network and uses a frozen SpeechBrain filterbank matrix for native
preprocessing. The output embedding size is 192 dimensions.

The model weights remain derived from the upstream SpeechBrain release. This
package provides the ONNX conversion, native helper, and runtime packaging.

The upstream model card says the system was trained on VoxCeleb1 and VoxCeleb2
training data, expects 16 kHz single-channel recordings, and does not provide a
warranty for performance on other datasets.

## References

- SpeechBrain: A General-Purpose Speech Toolkit, Ravanelli et al.,
  arXiv:2106.04624, 2021.
- ECAPA-TDNN: Emphasized Channel Attention, Propagation and Aggregation in
  TDNN Based Speaker Verification, Desplanques, Thienpondt, and Demuynck,
  Interspeech 2020, pages 3830-3834.
