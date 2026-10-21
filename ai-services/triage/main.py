"""
SmartRide AI Triage Microservice
Phase 1: Rule-based fallback (fully functional)
Phase 3: Replace infer_specialty() with fine-tuned DistilBERT ONNX model
"""
import time
from fastapi import FastAPI
from pydantic import BaseModel, Field
import re

app = FastAPI(title="SmartRide Triage Service", version="1.0.0")

# ── KEYWORD RULES (active until DistilBERT is trained) ────────────────────────

SEVERITY_5_KEYWORDS = [
    "chest pain", "heart attack", "not breathing", "stroke",
    "unconscious", "unresponsive", "seizure", "severe bleeding",
    "cardiac arrest", "overdose", "choking", "can't breathe",
]

SPECIALTY_RULES = [
    (["chest", "heart", "palpitation", "cardiac"],             "cardiology"),
    (["stroke", "brain", "unconscious", "numbness", "can't talk", "cant talk", "slurred"],  "neurology"),
    (["broken", "fracture", "joint", "bone", "sprain"],        "orthopedics"),
    (["pregnant", "labour", "delivery", "contractions"],       "obstetrics"),
    (["child", "infant", "baby", "toddler", "pediatric"],      "pediatrics"),
    (["mental", "anxiety", "depression", "hallucination"],     "psychiatry"),
    (["cancer", "tumor", "chemotherapy", "chemo"],             "oncology"),
    (["kidney", "dialysis", "renal"],                          "nephrology"),
    (["breathing", "lungs", "asthma", "copd", "respiratory"],  "pulmonology"),
    (["stomach", "abdomen", "vomit", "diarrhea", "bowel"],     "gastroenterology"),
    (["eye", "vision", "blind"],                               "ophthalmology"),
    (["ear", "nose", "throat", "hearing"],                     "ent"),
    (["skin", "rash", "burn", "allergy"],                      "dermatology"),
]


def _compile(keywords: list[str]) -> re.Pattern:
    """Whole-word match with simple inflections.

    Plain substring tests matched "ear" inside "early", "nearby" and "year".
    Whitespace inside a phrase matches any run of whitespace.
    """
    alternatives = "|".join(
        r"\s+".join(re.escape(word) for word in kw.split()) for kw in keywords
    )
    return re.compile(r"\b(?:" + alternatives + r")(?:s|es|ed|ing)?\b")


def _normalise(text: str) -> str:
    # Mobile keyboards type U+2019 where the keyword lists use an ASCII apostrophe.
    return text.lower().replace("\u2019", "'").replace("\u2018", "'")


SEVERITY_5_PATTERN = _compile(SEVERITY_5_KEYWORDS)
SPECIALTY_PATTERNS = [(_compile(kws), specialty) for kws, specialty in SPECIALTY_RULES]


def infer_specialty(text: str) -> tuple[str, float]:
    """
    Rule-based specialty inference.
    REPLACE this function body with ONNX DistilBERT call in Phase 3.
    """
    text_lower = _normalise(text)

    for pattern, specialty in SPECIALTY_PATTERNS:
        if pattern.search(text_lower):
            return specialty, 0.78

    return "general_emergency", 0.60


def compute_severity(text: str, specialty: str) -> tuple[str, bool]:
    # Negation ("no chest pain") is deliberately not handled: over-triaging a
    # negated symptom costs a faster ambulance, missing a real one costs a life.
    if SEVERITY_5_PATTERN.search(_normalise(text)):
        return "5", True

    severity_map = {
        "cardiology": "4",
        "neurology": "4",
        "obstetrics": "4",
        "general_emergency": "3",
    }
    return severity_map.get(specialty, "2"), False


class TriageRequest(BaseModel):
    # 2000 matches the backend's symptom_text limit.
    text: str = Field(min_length=1, max_length=2000)


class TriageResponse(BaseModel):
    specialty: str
    confidence: float
    severity: str
    rule_override: bool
    model_version: str
    inference_ms: int


@app.post("/triage", response_model=TriageResponse)
async def triage(req: TriageRequest):
    start = time.time()
    specialty, confidence = infer_specialty(req.text)
    severity, rule_override = compute_severity(req.text, specialty)
    elapsed_ms = int((time.time() - start) * 1000)

    return TriageResponse(
        specialty=specialty,
        confidence=confidence,
        severity=severity,
        rule_override=rule_override,
        model_version="rules-v1.0",   # change to "distilbert-v1.0" in Phase 3
        inference_ms=elapsed_ms,
    )


@app.get("/health")
async def health():
    return {"status": "ok", "model": "rules-v1.0"}
