"""
SmartRide AI Triage Microservice
Phase 1: Rule-based fallback (fully functional)
Phase 3: Replace infer_specialty() with fine-tuned DistilBERT ONNX model
"""
import time
from fastapi import FastAPI
from pydantic import BaseModel

from specialties import SEVERITY_5_KEYWORDS, SPECIALTY_RULES, FALLBACK_SPECIALTY
from model_infer import predict_specialty, load_model, MODEL_VERSION

RULES_VERSION = "rules-v1.0"

app = FastAPI(title="SmartRide Triage Service", version="1.0.0")


def _active_model_version() -> str:
    """distilbert-v1.0 when a model is loaded, otherwise rules-v1.0."""
    return MODEL_VERSION if load_model() is not None else RULES_VERSION


def infer_rules(text: str) -> tuple[str, float]:
    """Keyword-based specialty inference (fallback when no model is loaded)."""
    text_lower = text.lower()

    for keywords, specialty in SPECIALTY_RULES:
        if any(kw in text_lower for kw in keywords):
            return specialty, 0.78

    return FALLBACK_SPECIALTY, 0.60


def infer_specialty(text: str) -> tuple[str, float]:
    """Use the DistilBERT model when available; otherwise the keyword rules."""
    model_result = predict_specialty(text)
    if model_result is not None:
        return model_result
    return infer_rules(text)


def compute_severity(text: str, specialty: str) -> tuple[str, bool]:
    text_lower = text.lower()

    for kw in SEVERITY_5_KEYWORDS:
        if kw in text_lower:
            return "5", True

    severity_map = {
        "cardiology": "4",
        "neurology": "4",
        "obstetrics": "4",
        "general_emergency": "3",
    }
    return severity_map.get(specialty, "2"), False


class TriageRequest(BaseModel):
    text: str


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
        model_version=_active_model_version(),
        inference_ms=elapsed_ms,
    )


@app.get("/health")
async def health():
    return {"status": "ok", "model": _active_model_version()}
