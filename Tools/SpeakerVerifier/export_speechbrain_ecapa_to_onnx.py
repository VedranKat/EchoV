#!/usr/bin/env python3
import argparse
from pathlib import Path


MODEL_ID = "speechbrain/spkrec-ecapa-voxceleb"


def load_classifier():
    try:
        from speechbrain.inference.speaker import EncoderClassifier
    except Exception as error:
        raise SystemExit(
            "Install speechbrain in the development environment before exporting. "
            f"Details: {error}"
        )

    return EncoderClassifier.from_hparams(source=MODEL_ID)


def load_export_dependencies():
    try:
        import onnx
        import torch
    except Exception as error:
        raise SystemExit(
            "Install torch and onnx in the development environment before exporting. "
            f"Details: {error}"
        )

    return onnx, torch


def build_embedding_export_module(torch, classifier):
    class EmbeddingOnly(torch.nn.Module):
        def __init__(self, embedding_model):
            super().__init__()
            self.embedding_model = embedding_model

        def forward(self, features, feature_lens):
            embedding = self.embedding_model(features, feature_lens)
            return embedding.squeeze(1)

    return EmbeddingOnly(classifier.mods.embedding_model).eval()


def main() -> None:
    parser = argparse.ArgumentParser(description="Export EchoV's reference SpeechBrain ECAPA embedding network to ONNX.")
    parser.add_argument("--output", default="ecapa-speaker-v1.onnx")
    parser.add_argument("--fbank-output", help="Optional path for the frozen SpeechBrain fbank matrix as little-endian float32.")
    args = parser.parse_args()

    onnx, torch = load_export_dependencies()
    classifier = load_classifier()
    embedding_model = build_embedding_export_module(torch, classifier)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    # SpeechBrain's waveform frontend uses torch.stft with complex tensors,
    # which does not export cleanly to ONNX in this stack. Export the ECAPA
    # embedding network instead; the native helper owns the 16 kHz mono audio
    # frontend and feeds [batch, frames, 80] fbank features into this graph.
    dummy_features = torch.randn(1, 301, 80)
    dummy_lens = torch.ones(1)
    torch.onnx.export(
        embedding_model,
        (dummy_features, dummy_lens),
        output.as_posix(),
        input_names=["features", "feature_lens"],
        output_names=["embedding"],
        dynamic_axes={
            "features": {0: "batch", 1: "frames"},
            "feature_lens": {0: "batch"},
            "embedding": {0: "batch"},
        },
        opset_version=17,
        do_constant_folding=True,
    )
    onnx.checker.check_model(output.as_posix())

    if args.fbank_output:
        fbank_output = Path(args.fbank_output)
        fbank_output.parent.mkdir(parents=True, exist_ok=True)
        fbank = classifier.mods.compute_features.compute_fbanks
        f_central_mat = fbank.f_central.repeat(fbank.all_freqs_mat.shape[1], 1).transpose(0, 1)
        band_mat = fbank.band.repeat(fbank.all_freqs_mat.shape[1], 1).transpose(0, 1)
        fbank_matrix = fbank._create_fbank_matrix(f_central_mat, band_mat).detach().cpu().float().numpy()
        fbank_matrix.tofile(fbank_output)

    print(output)


if __name__ == "__main__":
    main()
