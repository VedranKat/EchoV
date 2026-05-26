#!/usr/bin/env python3
import argparse
import json
import math
from pathlib import Path

import numpy as np


MODEL_ID = "speechbrain/spkrec-ecapa-voxceleb"
SAMPLE_RATE = 16000


def load_dependencies():
    try:
        import onnxruntime as ort
        import torch
        import torchaudio
        from speechbrain.inference.speaker import EncoderClassifier
    except Exception as error:
        raise SystemExit(
            "Install torch, torchaudio, speechbrain, and onnxruntime in the development environment. "
            f"Details: {error}"
        )

    return ort, torch, torchaudio, EncoderClassifier


def synthetic_waveforms(seconds: float = 4.0) -> dict[str, np.ndarray]:
    samples = int(SAMPLE_RATE * seconds)
    t = np.arange(samples, dtype=np.float32) / SAMPLE_RATE

    def harmonic(base: float, wobble: float) -> np.ndarray:
        carrier = (
            0.55 * np.sin(2 * np.pi * base * t)
            + 0.25 * np.sin(2 * np.pi * base * 2.01 * t)
            + 0.12 * np.sin(2 * np.pi * base * 3.02 * t)
        )
        envelope = 0.55 + 0.45 * np.sin(2 * np.pi * wobble * t) ** 2
        return (carrier * envelope).astype(np.float32)

    return {
        "enrollment": harmonic(145.0, 2.4),
        "same_speaker": harmonic(148.0, 2.1),
        "different_speaker": harmonic(230.0, 3.3),
    }


def load_audio(path: Path, torch, torchaudio):
    waveform, sample_rate = torchaudio.load(path.as_posix())
    if waveform.numel() == 0:
        raise RuntimeError(f"{path} is empty.")

    if waveform.shape[0] > 1:
        waveform = waveform.mean(dim=0, keepdim=True)

    if sample_rate != SAMPLE_RATE:
        waveform = torchaudio.transforms.Resample(sample_rate, SAMPLE_RATE)(waveform)

    return waveform.squeeze(0).float().numpy()


def l2_normalize(values: np.ndarray) -> np.ndarray:
    vector = values.astype(np.float64).reshape(-1)
    norm = np.linalg.norm(vector)
    if not math.isfinite(norm) or norm == 0:
        raise RuntimeError("Embedding has invalid norm.")
    return vector / norm


def cosine(left: np.ndarray, right: np.ndarray) -> float:
    return float(np.dot(l2_normalize(left), l2_normalize(right)))


def speechbrain_embedding(classifier, torch, waveform: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    wavs = torch.from_numpy(waveform).unsqueeze(0)
    wav_lens = torch.ones(1)
    with torch.no_grad():
        features = classifier.mods.compute_features(wavs)
        features = classifier.mods.mean_var_norm(features, wav_lens)
        embedding = classifier.mods.embedding_model(features, wav_lens).squeeze(1)
    return features.detach().cpu().numpy(), embedding.detach().cpu().numpy()


def onnx_embedding(session, features: np.ndarray) -> np.ndarray:
    feature_lens = np.ones((features.shape[0],), dtype=np.float32)
    return session.run(None, {"features": features.astype(np.float32), "feature_lens": feature_lens})[0]


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate EchoV ECAPA ONNX export against SpeechBrain.")
    parser.add_argument("--model", required=True, type=Path)
    parser.add_argument("--audio", action="append", type=Path, default=[])
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    ort, torch, torchaudio, EncoderClassifier = load_dependencies()
    classifier = EncoderClassifier.from_hparams(source=MODEL_ID)
    session = ort.InferenceSession(args.model.as_posix(), providers=["CPUExecutionProvider"])

    waveforms: dict[str, np.ndarray] = {}
    if args.audio:
        for audio_path in args.audio:
            waveforms[audio_path.stem] = load_audio(audio_path, torch, torchaudio)
    else:
        waveforms = synthetic_waveforms()

    rows = []
    embeddings = {}
    for name, waveform in waveforms.items():
        features, reference = speechbrain_embedding(classifier, torch, waveform)
        exported = onnx_embedding(session, features)
        max_abs_diff = float(np.max(np.abs(reference - exported)))
        rows.append(
            {
                "name": name,
                "frames": int(features.shape[1]),
                "embedding_dimensions": int(exported.reshape(-1).shape[0]),
                "max_abs_diff": max_abs_diff,
            }
        )
        embeddings[name] = {"reference": reference, "onnx": exported}

    comparisons = []
    names = list(embeddings)
    if names:
        anchor = names[0]
        for name in names[1:]:
            comparisons.append(
                {
                    "pair": f"{anchor}:{name}",
                    "reference_similarity": cosine(embeddings[anchor]["reference"], embeddings[name]["reference"]),
                    "onnx_similarity": cosine(embeddings[anchor]["onnx"], embeddings[name]["onnx"]),
                }
            )

    payload = {
        "model": args.model.as_posix(),
        "inputs": rows,
        "comparisons": comparisons,
    }

    if args.json:
        print(json.dumps(payload, indent=2))
        return

    print(f"model: {payload['model']}")
    for row in rows:
        print(
            f"{row['name']}: frames={row['frames']} dims={row['embedding_dimensions']} "
            f"max_abs_diff={row['max_abs_diff']:.6f}"
        )
    for comparison in comparisons:
        print(
            f"{comparison['pair']}: reference={comparison['reference_similarity']:.4f} "
            f"onnx={comparison['onnx_similarity']:.4f}"
        )


if __name__ == "__main__":
    main()
