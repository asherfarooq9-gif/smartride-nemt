"""Unit tests for keywords.py: sensitivity on life threats, severity design,
specialty selection, normalisation."""
import ast
import re

import pytest

import keywords
from keywords import (
    KEYWORDS_VERSION,
    LIFE_THREAT_EN,
    LIFE_THREAT_ROMAN_URDU,
    LIFE_THREAT_URDU,
    compute_severity,
    detect_severity_override,
    infer_specialty,
    normalise,
)

# Hand-written and independent of the data tables, so a normalisation or
# compilation bug cannot hide behind the table testing itself.
ENGLISH_LIFE_THREATS = [
    "he can't breathe", "he cant breathe", "he can’t breathe", "she cannot breathe",
    "she can not breathe", "I CAN'T BREATHE", "cant breath", "unable to breathe",
    "shortness of breath", "short of breath", "difficulty breathing", "he has trouble breathing",
    "not breathing", "baby is not breathing", "stopped breathing", "choking", "he choked on food",
    "she collapsed", "he fainted", "she passed out", "unconscious", "unconsciousness",
    "found him unresponsive", "face drooping", "his face is drooping", "slurred speech",
    "speech is slurred", "left side paralysed", "left side paralyzed", "possible stroke",
    "heart attack", "chest pain", "pain in my chest", "chest tightness", "my chest is tight",
    "anaphylaxis", "throat swelling", "his throat is swelling", "allergic reaction severe",
    "severe allergic reaction", "suicidal", "he is suicidal", "overdose", "took an overdose",
    "head injury", "hit his head", "accident", "road accident", "car accident on the highway",
    "severe bleeding", "heavy bleeding", "bleeds heavily", "bleeding heavily",
    "my water broke", "her waters broke", "seizure", "he is seizing", "convulsion",
    "convulsions", "cardiac arrest", "vomiting blood", "coughing up blood", "gunshot wound",
    "stabbed", "electric shock", "drowning", "snake bite", "heavy vaginal bleeding",
    "burnt badly", "severe burns", "poisoned", "drank poison", "she wants to die",
    "he wants to kill himself", "self-harm", "self harm", "not moving", "no pulse",
    "worst headache of my life", "cyanosis", "his lips are blue",
]

ROMAN_URDU_LIFE_THREATS = [
    "saans nahi aa rahi", "saans nahi aa raha", "sans nahin aa rahi", "saans nahi aati",
    "saans lene mein takleef", "saans phool rahi hai", "saans ruk gayi", "dam ghut raha hai",
    "seenay mein dard", "seene mein dard hai", "seena dard", "seene me jakran",
    "chaati mein dard", "dil ka daura", "dil ka dora para hai", "behosh", "behosh ho gaya",
    "be hosh", "hosh nahi hai", "khoon beh raha hai", "khoon bah raha hai", "bohat khoon",
    "khoon nahi ruk raha", "khoon ki ulti", "khudkushi", "khud kushi", "mirgi", "mirgi ka daura",
    "daura pad gaya", "falij", "lakwa", "munh tedha ho gaya", "zehar kha liya", "zehar pi liya",
    "accident ho gaya", "hadsa", "sar par chot", "pani toot gaya", "doob gaya", "saanp ne kata",
    "current lag gaya", "goli lagi", "chaku lagi", "neela par gaya", "bohat jal gaya",
    "aag lag gayi", "jhatke aa rahe hain", "dil band ho gaya", "mar gaya",
]

URDU_LIFE_THREATS = [
    "سانس نہیں آرہی", "سانس نہیں آ رہی", "سانس لینے میں مشکل", "سانس لینے میں تکلیف",
    "سانس پھول رہی ہے", "دم گھٹ رہا ہے", "سینے میں درد", "سینے میں جکڑن", "دل کا دورہ",
    "بے ہوش", "بیہوش", "ہوش نہیں", "خون بہہ رہا ہے", "خون نہیں رک رہا", "خودکشی",
    "خود کشی", "مرگی", "دورہ پڑا", "فالج", "منہ ٹیڑھا", "زہر", "حادثہ", "سر پر چوٹ",
    "سانپ نے کاٹ لیا", "کرنٹ لگ گیا", "ڈوب گیا", "گولی لگی", "پانی ٹوٹ گیا", "نیلا پڑ گیا",
]


def _id(text: str) -> str:
    return re.sub(r"\W+", "_", text)[:40]


@pytest.mark.parametrize("text", ENGLISH_LIFE_THREATS, ids=_id)
def test_english_life_threat_is_severity_5(text):
    assert compute_severity(text) == ("5", True)
    assert detect_severity_override(text) is True


@pytest.mark.parametrize("text", ROMAN_URDU_LIFE_THREATS, ids=_id)
def test_roman_urdu_life_threat_is_severity_5(text):
    assert compute_severity(text) == ("5", True)


@pytest.mark.parametrize("text", URDU_LIFE_THREATS)
def test_urdu_script_life_threat_is_severity_5(text):
    assert compute_severity(text) == ("5", True)


@pytest.mark.parametrize(
    "phrase", LIFE_THREAT_EN + LIFE_THREAT_ROMAN_URDU + LIFE_THREAT_URDU,
)
def test_every_life_threat_table_entry_triggers_override(phrase):
    assert detect_severity_override(phrase) is True
    assert detect_severity_override("patient says: " + phrase + ", please hurry") is True


@pytest.mark.parametrize("apostrophe", ["'", "’", "‘", "ʼ", "´", "`", ""])
@pytest.mark.parametrize(
    "template", ["he can@t breathe", "CAN@T BREATHE!", "she couldn@t breathe"],
)
def test_apostrophe_variants_all_match(template, apostrophe):
    assert compute_severity(template.replace("@", apostrophe)) == ("5", True)


@pytest.mark.parametrize(
    "text", ["can't breathe", "cant breathe", "can’t breathe", "Can’t  Breathe."],
)
def test_normalise_collapses_apostrophe_forms(text):
    assert normalise(text) == "cant breathe"


def test_normalise_rejects_non_strings():
    for bad in (None, 5, b"chest pain", ["a"]):
        with pytest.raises(TypeError):
            normalise(bad)


def test_normalise_handles_empty_and_symbols():
    assert normalise("") == ""
    assert normalise("  !!! ?? ") == ""


def test_normalise_folds_roman_urdu_spellings():
    assert normalise("Seenay MEIN dard") == normalise("seene me dard") == "seena me dard"


def test_urdu_script_spacing_and_letter_variants_match():
    assert detect_severity_override("سانس نہیں آرہی")
    assert detect_severity_override("سانس نہیں آ رہی")
    assert detect_severity_override("سانسنہیں")
    # Arabic yeh / kaf / heh variants and zero-width joiners typed by some keyboards.
    assert detect_severity_override("بي‌هوش")
    assert detect_severity_override("خودكشي")


def test_whole_word_matching_avoids_substrings():
    assert compute_severity("accidentally spilled tea")[1] is False
    assert compute_severity("hospital appointment for follow up")[1] is False


# ── the old inverted severity map ────────────────────────────────────────────

@pytest.mark.parametrize(
    "text,minimum",
    [
        ("difficulty breathing", 5),
        ("severe burns", 4),
        ("baby has high fever", 4),
        ("suicidal", 5),
        ("child with fever", 4),
        ("asthma, wheezing", 4),
        ("hallucinating and violent", 4),
        ("burn on the arm", 4),
        ("suicidal thoughts and depression", 5),
        ("pregnant, broken arm", 4),
        ("pregnant and bleeding", 5),
    ],
)
def test_clinical_danger_outranks_specialty_order(text, minimum):
    assert int(compute_severity(text)[0]) >= minimum


def test_dangerous_complaints_never_score_below_unrecognised_text():
    unknown = int(compute_severity("zzz qqq blorp")[0])
    for text in ("difficulty breathing", "severe burns", "baby has high fever", "suicidal"):
        assert int(compute_severity(text)[0]) >= unknown


@pytest.mark.parametrize(
    "text", ["zzz qqq blorp", "I need a ride", "mujhe lift chahiye", "ہمیں گاڑی چاہیے", "x"],
)
def test_unrecognised_text_never_gets_lowest_severity(text):
    severity, forced = compute_severity(text)
    assert int(severity) >= 3
    assert forced is False


def test_severity_floor_uses_most_dangerous_matched_specialty():
    # Pediatrics alone is 3, but a child with a racing heart is cardiology too.
    assert int(compute_severity("child heart racing")[0]) >= 4


def test_negation_is_deliberately_not_handled():
    assert compute_severity("no chest pain")[0] == "5"


# ── specialty selection and confidence ──────────────────────────────────────

def test_pregnancy_context_beats_list_order():
    assert infer_specialty("pregnant, broken arm")[0] == "obstetrics"


def test_child_context_beats_cardiology():
    assert infer_specialty("child chest pain")[0] == "pediatrics"


def test_age_phrases_set_pediatric_context():
    assert infer_specialty("6 year old with chest tightness")[0] == "pediatrics"
    assert infer_specialty("3-month-old has a cough")[0] == "pediatrics"
    assert infer_specialty("45 year old man with chest pain")[0] == "cardiology"


def test_highest_score_wins_without_context():
    # one orthopedics hit vs two cardiology hits
    assert infer_specialty("chest pain, sprain")[0] == "cardiology"


def test_roman_urdu_and_urdu_specialties():
    assert infer_specialty("seene me dard")[0] == "cardiology"
    assert infer_specialty("bachay ko bukhar")[0] == "pediatrics"
    assert infer_specialty("سانس نہیں آرہی")[0] == "pulmonology"
    assert infer_specialty("کان میں درد")[0] == "ent"


def test_no_match_falls_back_to_general_emergency_with_lowest_confidence():
    specialty, confidence = infer_specialty("zzz qqq blorp")
    assert specialty == "general_emergency"
    assert confidence == keywords.NO_MATCH_CONFIDENCE


def test_confidence_is_derived_from_match_score_not_constant():
    one_hit = infer_specialty("heart")[1]
    two_hits = infer_specialty("heart attack")[1]
    three_hits = infer_specialty("chest pain and heart attack")[1]
    assert keywords.NO_MATCH_CONFIDENCE < one_hit < two_hits < three_hits <= 0.90
    assert len({one_hit, two_hits, three_hits}) == 3


def test_competing_specialty_lowers_confidence():
    clean = infer_specialty("kidney dialysis")[1]
    contested = infer_specialty("kidney dialysis and chest pain")[1]
    assert contested < clean


@pytest.mark.parametrize(
    "text", ["heart", "chest pain heart attack cardiac", "x", "", "سینے میں درد"],
)
def test_confidence_stays_in_range(text):
    assert 0.30 <= infer_specialty(text)[1] <= 0.90


# ── data module contract (the backend vendors this file) ────────────────────

def test_keywords_version_is_sha256_and_stable():
    assert re.fullmatch(r"[0-9a-f]{64}", KEYWORDS_VERSION)
    assert KEYWORDS_VERSION == keywords._compute_version()


def test_keywords_version_changes_when_data_changes(monkeypatch):
    before = keywords._compute_version()
    monkeypatch.setattr(keywords, "LIFE_THREAT_EN", keywords.LIFE_THREAT_EN + ("brand new phrase",))
    assert keywords._compute_version() != before


def test_keywords_module_is_standalone():
    with open(keywords.__file__, encoding="utf-8") as handle:
        tree = ast.parse(handle.read())
    imports = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imports.update(alias.name.split(".")[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom):
            imports.add((node.module or "").split(".")[0])
    assert imports <= {"__future__", "hashlib", "json", "re", "unicodedata"}


def test_roman_urdu_and_urdu_tables_are_separate_from_english():
    assert set(LIFE_THREAT_EN).isdisjoint(LIFE_THREAT_URDU)
    assert all(re.search(r"[؀-ۿ]", p) for p in LIFE_THREAT_URDU)
    assert not any(
        re.search(r"[؀-ۿ]", p) for p in LIFE_THREAT_ROMAN_URDU + LIFE_THREAT_EN
    )
