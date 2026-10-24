"""The backend ships a vendored copy of the triage rules; it must never drift."""

import hashlib
import importlib.util
from pathlib import Path

import pytest

from app.services import triage_keywords as vendored

ORIGINAL = (
    Path(__file__).resolve().parents[2] / "ai-services" / "triage" / "keywords.py"
)
DATA_TABLES = (
    "ROMAN_URDU_SPELLINGS",
    "LIFE_THREAT_EN",
    "LIFE_THREAT_ROMAN_URDU",
    "LIFE_THREAT_URDU",
    "RED_FLAGS_4_EN",
    "RED_FLAGS_4_ROMAN_URDU",
    "RED_FLAGS_4_URDU",
    "PREGNANCY_ESCALATORS",
    "PEDIATRIC_ESCALATORS",
    "INTENSITY_WORDS",
    "PAIN_WORDS",
    "SPECIALTY_KEYWORDS_EN",
    "SPECIALTY_KEYWORDS_ROMAN_URDU",
    "SPECIALTY_KEYWORDS_URDU",
    "SPECIALTY_PRIORITY",
    "CONTEXT_FIRST_SPECIALTIES",
    "SPECIALTY_BASE_SEVERITY",
    "COMPOUND_RULES",
    "FALLBACK_SPECIALTY",
    "UNKNOWN_SEVERITY",
    "NO_MATCH_CONFIDENCE",
    "KEYWORDS_VERSION",
)

pytestmark = pytest.mark.skipif(
    not ORIGINAL.exists(),
    reason=f"{ORIGINAL} is absent (backend-only checkout): cannot verify the vendored "
    "triage rules against the original",
)


def _load_original():
    spec = importlib.util.spec_from_file_location("triage_keywords_original", ORIGINAL)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _body_hash(path: Path) -> str:
    """Hash of the file with line endings normalised and the vendored header removed."""
    lines = path.read_bytes().decode("utf-8").replace("\r\n", "\n").split("\n")
    start = 0
    while start < len(lines) and lines[start].startswith("# "):
        start += 1
    return hashlib.sha256("\n".join(lines[start:]).encode("utf-8")).hexdigest()


def test_keywords_version_matches_the_original():
    assert vendored.KEYWORDS_VERSION == _load_original().KEYWORDS_VERSION


@pytest.mark.parametrize("table", DATA_TABLES)
def test_each_data_table_matches_the_original(table):
    assert getattr(vendored, table) == getattr(_load_original(), table)


def test_whole_file_matches_the_original_apart_from_the_header():
    vendored_path = Path(vendored.__file__)
    assert _body_hash(vendored_path) == _body_hash(ORIGINAL), (
        "backend/app/services/triage_keywords.py drifted from "
        "ai-services/triage/keywords.py: re-copy it"
    )


def test_vendored_rules_still_flag_a_curly_apostrophe_emergency():
    assert vendored.compute_severity("he can’t breathe") == ("5", True)
