"""Model-inference fallback behavior (no model file present in CI)."""

import model_infer
from model_infer import predict_specialty, load_model, _load_id2label
from specialties import CANONICAL_SPECIALTIES


def test_predict_returns_none_without_model():
    # No model.onnx in MODEL_PATH during tests -> caller falls back to rules.
    assert load_model() is None
    assert predict_specialty("severe chest pain radiating to the arm") is None


def test_id2label_covers_all_14_classes():
    id2label = _load_id2label()
    assert len(id2label) == 14
    assert id2label[0] and 13 in id2label


def test_every_model_label_normalizes_into_the_enum():
    for label in _load_id2label().values():
        assert model_infer.normalize_specialty(label) in CANONICAL_SPECIALTIES
