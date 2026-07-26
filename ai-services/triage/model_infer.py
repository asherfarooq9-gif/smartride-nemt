"""
Optional DistilBERT ONNX inference for the triage service.

Loads a fine-tuned model from MODEL_PATH when present and returns a canonical
specialty prediction. If no model is available (file missing, or onnxruntime /
transformers not installed), load_model() returns None and the caller falls back
to the keyword rules — matching the "graceful fallback" posture in render.yaml.

Expected layout in MODEL_PATH (default /app/model):
    model.onnx                     # exported DistilBERT sequence classifier
    tokenizer/                     # saved HF tokenizer (tokenizer.json etc.)
Label ids come from data/hospital_routing_label_map.json.
"""

import json
import os
from functools import lru_cache
from typing import Optional, Tuple

from specialties import normalize_specialty

MODEL_DIR = os.getenv("MODEL_PATH", "/app/model")
MODEL_FILE = os.path.join(MODEL_DIR, "model.onnx")
TOKENIZER_DIR = os.path.join(MODEL_DIR, "tokenizer")
LABEL_MAP_PATH = os.path.join(
    os.path.dirname(__file__), "data", "hospital_routing_label_map.json"
)
MODEL_VERSION = "distilbert-v1.0"
MAX_LEN = 96


class _Model:
    def __init__(self, session, tokenizer, id2label):
        self.session = session
        self.tokenizer = tokenizer
        self.id2label = id2label


def _load_id2label() -> dict:
    with open(LABEL_MAP_PATH) as f:
        label2id = json.load(f)
    return {int(v): k for k, v in label2id.items()}


@lru_cache(maxsize=1)
def load_model() -> Optional[_Model]:
    """Return a loaded model, or None if unavailable (caller uses rules)."""
    if not os.path.exists(MODEL_FILE):
        return None
    try:
        import onnxruntime as ort
        from transformers import AutoTokenizer
    except ImportError:
        return None
    try:
        session = ort.InferenceSession(MODEL_FILE, providers=["CPUExecutionProvider"])
        tokenizer = AutoTokenizer.from_pretrained(TOKENIZER_DIR)
        return _Model(session, tokenizer, _load_id2label())
    except Exception:
        # Any load failure degrades to rules rather than crashing the service.
        return None


def predict_specialty(text: str) -> Optional[Tuple[str, float]]:
    """
    Return (canonical_specialty, confidence) from the model, or None when the
    model is unavailable so the caller falls back to keyword rules.
    """
    model = load_model()
    if model is None:
        return None
    try:
        import numpy as np

        enc = model.tokenizer(
            text,
            truncation=True,
            max_length=MAX_LEN,
            return_tensors="np",
        )
        inputs = {k: v for k, v in enc.items() if k in {"input_ids", "attention_mask"}}
        logits = model.session.run(None, inputs)[0][0]
        exp = np.exp(logits - np.max(logits))
        probs = exp / exp.sum()
        idx = int(np.argmax(probs))
        raw_label = model.id2label.get(idx, "")
        return normalize_specialty(raw_label), float(probs[idx])
    except Exception:
        return None
