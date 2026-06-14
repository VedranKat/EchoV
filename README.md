# EchoV

EchoV is a local-first macOS menu bar dictation app. Press a global hotkey, speak, and EchoV transcribes locally before pasting the text into the active app.

## Build

```sh
swift build
```

To build a `.app` bundle:

```sh
bash Scripts/build-app.sh
```

The app build downloads the pinned macOS arm64 ONNX Runtime C package into
`.build-deps/onnxruntime/` when it is not already cached. Set
`SPEAKER_VERIFIER_ORT_DIR` to use a local ONNX Runtime package, or set
`SPEAKER_VERIFIER_ORT_AUTO_DOWNLOAD=0` for offline builds.

The bundle is written to `dist/EchoV.app` and ad-hoc signed by default. To sign with a local identity:

```sh
CODE_SIGN_IDENTITY="Developer ID Application: Your Name" bash Scripts/build-app.sh
```

## Use

Run the packaged app:

```sh
open dist/EchoV.app
```

Open EchoV from the menu bar, grant microphone and accessibility permissions, then download or select the local transcription model in Settings. The default shortcuts are:

- Toggle dictation: Option + Space
- Push to talk: §

### Assistant commands

When Assistant is on, say the command exactly:

| Command | Does |
| --- | --- |
| Computer | Continue the voice chat |
| Computer refresh | Start a fresh voice chat |
| Computer text | Start a fresh text chat |
| Continue | Follow up on the active chat |
| Computer cleanup | Rewrite selected text with Prime |

Selected text is included when available.
