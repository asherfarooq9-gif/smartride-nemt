"""
Export the fine-tuned DistilBERT classifier to the ONNX layout the triage
service expects.

train_distilbert.py leaves a HuggingFace model directory behind, but
model_infer.py loads `model.onnx` through onnxruntime — serving torch in the
API container would pull ~2GB of dependencies for no gain. This script bridges
the two.

Setup (training environment, not the serving image):
    pip install torch transformers onnx

Usage:
    python export_onnx.py [--model-dir DIR] [--out DIR]

Writes:
    <out>/model.onnx
    <out>/tokenizer/

Defaults to the MODEL_PATH the service reads (/app/model), so exporting in
place activates the model on the next load_model() call.
"""

import argparse
import json
import os
import shutil

DEFAULT_MODEL_DIR = "./distilbert-hospital-routing-final"
DEFAULT_OUT_DIR = os.getenv("MODEL_PATH", "/app/model")
LABEL_MAP = "hospital_routing_label_map.json"
# Must match MAX_LEN in model_infer.py; only used to trace a representative
# input, since the exported graph takes a dynamic sequence length.
MAX_LEN = 96
OPSET = 14


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model-dir", default=DEFAULT_MODEL_DIR)
    parser.add_argument("--out", default=DEFAULT_OUT_DIR)
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    import torch
    from transformers import AutoModelForSequenceClassification, AutoTokenizer

    if not os.path.isdir(args.model_dir):
        raise SystemExit(
            f"No trained model at {args.model_dir!r}. Run train_distilbert.py first."
        )

    tokenizer = AutoTokenizer.from_pretrained(args.model_dir)
    model = AutoModelForSequenceClassification.from_pretrained(args.model_dir)
    model.eval()

    # Fail loudly if the checkpoint and the label map disagree — a silent
    # mismatch would route patients to the wrong department.
    with open(LABEL_MAP) as f:
        label2id = json.load(f)
    if model.config.num_labels != len(label2id):
        raise SystemExit(
            f"Model has {model.config.num_labels} labels but {LABEL_MAP} has "
            f"{len(label2id)}. Refusing to export a mismatched classifier."
        )

    os.makedirs(args.out, exist_ok=True)
    onnx_path = os.path.join(args.out, "model.onnx")
    tokenizer_dir = os.path.join(args.out, "tokenizer")

    sample = tokenizer(
        "severe chest pain radiating to the left arm",
        truncation=True,
        max_length=MAX_LEN,
        return_tensors="pt",
    )
    inputs = (sample["input_ids"], sample["attention_mask"])

    # Both axes are dynamic: the service tokenizes one message at a time
    # without padding to a fixed width.
    dynamic_axes = {
        "input_ids": {0: "batch", 1: "sequence"},
        "attention_mask": {0: "batch", 1: "sequence"},
        "logits": {0: "batch"},
    }

    with torch.no_grad():
        torch.onnx.export(
            model,
            inputs,
            onnx_path,
            input_names=["input_ids", "attention_mask"],
            output_names=["logits"],
            dynamic_axes=dynamic_axes,
            opset_version=OPSET,
            do_constant_folding=True,
        )

    if os.path.isdir(tokenizer_dir):
        shutil.rmtree(tokenizer_dir)
    tokenizer.save_pretrained(tokenizer_dir)

    size_mb = os.path.getsize(onnx_path) / (1024 * 1024)
    print(f"Wrote {onnx_path} ({size_mb:.1f} MB)")
    print(f"Wrote {tokenizer_dir}/")
    print("The triage service picks this up on its next load_model() call.")


if __name__ == "__main__":
    main()
