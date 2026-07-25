"""Tests for the canonical specialty vocabulary and normalization."""

import json
import os

from specialties import (
    CANONICAL_SPECIALTIES,
    DATASET_LABEL_TO_ENUM,
    FALLBACK_SPECIALTY,
    SPECIALTY_RULES,
    normalize_specialty,
)

DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "data")
LABEL_MAP_PATH = os.path.join(DATA_DIR, "hospital_routing_label_map.json")


def test_every_dataset_label_maps_to_a_canonical_specialty():
    for dataset_label, enum_value in DATASET_LABEL_TO_ENUM.items():
        assert enum_value in CANONICAL_SPECIALTIES, (
            f"{dataset_label} maps to {enum_value}, not in the enum"
        )


def test_dataset_label_map_matches_normalization_keys():
    # The training label_map.json is the authoritative dataset vocabulary;
    # every one of its labels must have an explicit normalization entry.
    with open(LABEL_MAP_PATH) as f:
        label_map = json.load(f)
    assert set(label_map.keys()) == set(DATASET_LABEL_TO_ENUM.keys())


def test_normalize_accepts_dataset_labels():
    assert normalize_specialty("Nephrology_Dialysis") == "nephrology"
    assert normalize_specialty("Obstetrics_Gynecology") == "obstetrics"
    assert normalize_specialty("Urology") == "urology"
    assert normalize_specialty("ENT") == "ent"


def test_normalize_accepts_already_canonical_slugs():
    assert normalize_specialty("cardiology") == "cardiology"
    assert normalize_specialty("Cardiology") == "cardiology"
    assert normalize_specialty(" CARDIOLOGY ") == "cardiology"


def test_normalize_unknown_falls_back():
    assert normalize_specialty("proctology") == FALLBACK_SPECIALTY
    assert normalize_specialty("") == FALLBACK_SPECIALTY
    assert normalize_specialty(None) == FALLBACK_SPECIALTY


def test_rule_outputs_are_all_canonical():
    for _keywords, specialty in SPECIALTY_RULES:
        assert specialty in CANONICAL_SPECIALTIES
