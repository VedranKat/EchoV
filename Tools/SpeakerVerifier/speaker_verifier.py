#!/usr/bin/env python3
import argparse
import json
import sys


MODEL_ID = "speechbrain/spkrec-ecapa-voxceleb"


def fail(message: str, exit_code: int = 1) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(exit_code)


def load_dependencies():
    try:
        import torch
        import torchaudio
        from speechbrain.inference.speaker import EncoderClassifier
    except Exception as error:
        fail(
            "SpeechBrain speaker verification is not installed. "
            "Install torch, torchaudio, and speechbrain for the Python interpreter EchoV uses. "
            f"Details: {error}"
        )

    return torch, torchaudio, EncoderClassifier


def load_audio(audio_path: str, torch, torchaudio):
    waveform, sample_rate = torchaudio.load(audio_path)
    if waveform.numel() == 0:
        fail("Audio file is empty.")

    if waveform.shape[0] > 1:
        waveform = waveform.mean(dim=0, keepdim=True)

    if sample_rate != 16000:
        resampler = torchaudio.transforms.Resample(sample_rate, 16000)
        waveform = resampler(waveform)

    return waveform


def classifier():
    torch, torchaudio, EncoderClassifier = load_dependencies()
    classifier = EncoderClassifier.from_hparams(source=MODEL_ID)
    return torch, torchaudio, classifier


def embedding_for(audio_path: str):
    torch, torchaudio, encoder = classifier()
    waveform = load_audio(audio_path, torch, torchaudio)

    with torch.no_grad():
        embedding = encoder.encode_batch(waveform)

    vector = embedding.squeeze().detach().cpu().double()
    norm = torch.linalg.vector_norm(vector)
    if not torch.isfinite(norm) or norm.item() == 0:
        fail("Could not create a usable speaker embedding.")

    vector = vector / norm
    return [float(value) for value in vector.tolist()]


def enroll(args) -> None:
    print(json.dumps({
        "model_id": MODEL_ID,
        "embedding": embedding_for(args.audio),
    }))


def score(args) -> None:
    torch, torchaudio, encoder = classifier()

    with open(args.profile, "r", encoding="utf-8") as profile_file:
        profile = json.load(profile_file)

    profile_embedding = profile.get("embedding") or []
    if not profile_embedding:
        fail("Voice profile does not contain an embedding.")

    waveform = load_audio(args.audio, torch, torchaudio)
    with torch.no_grad():
        embedding = encoder.encode_batch(waveform)

    live_vector = embedding.squeeze().detach().cpu().double()
    profile_vector = torch.tensor(profile_embedding, dtype=torch.double)

    live_norm = torch.linalg.vector_norm(live_vector)
    profile_norm = torch.linalg.vector_norm(profile_vector)
    if live_norm.item() == 0 or profile_norm.item() == 0:
        fail("Could not compare speaker embeddings.")

    similarity = torch.dot(live_vector / live_norm, profile_vector / profile_norm).item()
    print(json.dumps({"similarity": float(similarity)}))


def main() -> None:
    parser = argparse.ArgumentParser(description="EchoV SpeechBrain speaker verifier")
    subparsers = parser.add_subparsers(required=True)

    enroll_parser = subparsers.add_parser("enroll")
    enroll_parser.add_argument("--audio", required=True)
    enroll_parser.set_defaults(func=enroll)

    score_parser = subparsers.add_parser("score")
    score_parser.add_argument("--audio", required=True)
    score_parser.add_argument("--profile", required=True)
    score_parser.set_defaults(func=score)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
