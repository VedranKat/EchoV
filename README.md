# EchoV

EchoV is a local-first macOS dictation app prototype.

MVP loop:

```text
global hotkey -> record audio -> transcribe locally -> paste into active app
```

The project is currently scaffolded as a native Swift/SwiftUI menu bar app with clean seams for audio recording, hotkeys, ASR, text insertion, model validation, local history, and third-party acknowledgements.

## Build

```sh
swift build
```

## Build App Bundle

```sh
bash Scripts/build-app.sh
```

The app bundle is written to `dist/EchoV.app`.

## Run

```sh
swift run EchoV
```

For microphone permission behavior, prefer running the packaged app bundle:

```sh
open dist/EchoV.app
```
