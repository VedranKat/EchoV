# SpeechBrain ECAPA Speaker Verifier ONNX

This package contains a portable ONNX conversion of the upstream SpeechBrain
ECAPA-TDNN speaker embedding model.

It does not contain an application, platform-specific helper binary, or ONNX
Runtime library. Applications using this package must provide their own ONNX
Runtime integration and audio preprocessing code.

This package did not train or author the speaker embedding model. It
repackages and converts the upstream SpeechBrain ECAPA-TDNN model to ONNX so
it is easier to run in local applications.

## Contents

```text
manifest.json
README.md
LICENSE
NOTICE
model/ecapa-speaker-v1.onnx
model/fbank-80x201-f32.bin
```

## Model

The speaker embedding model is converted from:

```text
speechbrain/spkrec-ecapa-voxceleb
```

The upstream model is Apache-2.0 licensed. The conversion keeps the ECAPA
embedding network and uses a frozen SpeechBrain filterbank matrix for
preprocessing. The output embedding size is 192 dimensions.

The ONNX model expects SpeechBrain-compatible fbank features, not raw audio.
The included `model/fbank-80x201-f32.bin` file is a portable numeric table for
reproducing the SpeechBrain-style fbank preprocessing from audio.

The model weights remain derived from the upstream SpeechBrain release. This
package provides the ONNX conversion and portable preprocessing metadata.

The upstream model card says the system was trained on VoxCeleb1 and VoxCeleb2
training data, expects 16 kHz single-channel recordings, and does not provide a
warranty for performance on other datasets.

## References

- SpeechBrain: A General-Purpose Speech Toolkit, Ravanelli et al.,
  arXiv:2106.04624, 2021.
- ECAPA-TDNN: Emphasized Channel Attention, Propagation and Aggregation in
  TDNN Based Speaker Verification, Desplanques, Thienpondt, and Demuynck,
  Interspeech 2020, pages 3830-3834.
