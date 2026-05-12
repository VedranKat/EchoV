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
