"""Tests for backend specialty normalization (app.core.specialties)."""

from app.core.specialties import (
    CANONICAL_SPECIALTIES,
    DATASET_LABEL_TO_ENUM,
    FALLBACK_SPECIALTY,
    normalize_specialty,
)
from app.models.models import Specialty


def test_canonical_set_matches_enum():
    assert CANONICAL_SPECIALTIES == frozenset(s.value for s in Specialty)


def test_urology_is_in_enum():
    assert Specialty.urology.value == "urology"
    assert "urology" in CANONICAL_SPECIALTIES


def test_every_dataset_label_maps_into_the_enum():
    for label, value in DATASET_LABEL_TO_ENUM.items():
        assert value in CANONICAL_SPECIALTIES, f"{label} -> {value} not in enum"


def test_normalize_dataset_labels():
    assert normalize_specialty("Urology") == "urology"
    assert normalize_specialty("Nephrology_Dialysis") == "nephrology"
    assert normalize_specialty("Emergency_Trauma") == "general_emergency"


def test_normalize_passthrough_and_fallback():
    assert normalize_specialty("cardiology") == "cardiology"
    assert normalize_specialty("nonsense") == FALLBACK_SPECIALTY
    assert normalize_specialty(None) == FALLBACK_SPECIALTY
