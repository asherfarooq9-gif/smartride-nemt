"""Model-inference fallback behavior.

These pin MODEL_FILE at a path under the test's control rather than relying on
no model being installed: once a trained model is exported into MODEL_PATH the
ambient-absence version of this test passes in CI and fails on any machine that
has actually run the training, which tests the environment, not the fallback.
"""

import pytest

import model_infer
from model_infer import predict_specialty, load_model, _load_id2label
from specialties import CANONICAL_SPECIALTIES

SYMPTOM = "severe chest pain radiating to the arm"


@pytest.fixture
def model_file(monkeypatch):
    """Point model_infer at a caller-controlled path, cache cleared both ways."""

    def _set(path: str) -> None:
        load_model.cache_clear()
        monkeypatch.setattr(model_infer, "MODEL_FILE", path)

    yield _set
    load_model.cache_clear()


def test_predict_returns_none_when_no_model_file_exists(model_file, tmp_path):
    model_file(str(tmp_path / "absent.onnx"))
    assert load_model() is None
    assert predict_specialty(SYMPTOM) is None


def test_predict_falls_back_when_the_model_file_is_unreadable(model_file, tmp_path):
    """A corrupt or truncated model must degrade to rules, not crash triage."""
    broken = tmp_path / "model.onnx"
    broken.write_bytes(b"not a real onnx graph")
    model_file(str(broken))

    assert load_model() is None
    assert predict_specialty(SYMPTOM) is None


def test_id2label_covers_all_14_classes():
    id2label = _load_id2label()
    assert len(id2label) == 14
    assert id2label[0] and 13 in id2label


def test_every_model_label_normalizes_into_the_enum():
    for label in _load_id2label().values():
        assert model_infer.normalize_specialty(label) in CANONICAL_SPECIALTIES
