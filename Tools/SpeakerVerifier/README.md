# EchoV Speaker Verifier

`speaker_verifier.py` is a development/reference implementation for validating
speaker embeddings against SpeechBrain. EchoV's app user path uses a bundled
macOS helper plus a downloaded portable ONNX model package under:

```text
~/Library/Application Support/EchoV/Runtimes/speaker-verifier/
```

Expected managed model layout:

```text
manifest.json
model/ecapa-speaker-v1.onnx
model/fbank-80x201-f32.bin
```

The EchoV app bundle supplies the macOS-specific runtime support:

```text
Contents/Resources/SpeakerVerifierRuntime/bin/speaker-verifier
Contents/Resources/SpeakerVerifierRuntime/lib/libonnxruntime*.dylib
```

The native `bin/speaker-verifier` helper exposes the same JSON command surface
as this Python script:

```bash
speaker-verifier --model model/ecapa-speaker-v1.onnx enroll --audio enrollment.wav
speaker-verifier --model model/ecapa-speaker-v1.onnx score --audio same-speaker.wav --profile profile.json
```

For local development, create a project-local virtual environment:

```bash
python3 -m venv Tools/SpeakerVerifier/.venv
Tools/SpeakerVerifier/.venv/bin/python3 -m pip install torch torchaudio speechbrain
```

Use this script only to produce reference similarities while exporting and
retuning the ONNX path. Fixture names used for comparison:

- `enrollment.wav`
- `same-speaker.wav`
- `different-speaker.wav`

Exact cosine scores do not need to match the ONNX helper perfectly, but
same-speaker and different-speaker separation should remain strong before
updating `VoiceGateSpeakerMatchStrictness` thresholds.
