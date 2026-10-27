"""
SmartRide AI Triage Microservice
Phase 1: Rule-based fallback (fully functional)
Phase 3: Replace infer_specialty() with fine-tuned DistilBERT ONNX model

All keyword data and matching rules live in keywords.py so the backend can
vendor an identical copy. This service never logs request text (PHI).
"""
import time
from typing import Annotated

from fastapi import FastAPI
from pydantic import BaseModel, Field

from keywords import KEYWORDS_VERSION, compute_severity, infer_specialty

# 2000 matches the backend's symptom_text limit.
MAX_TEXT_LENGTH = 2000
MODEL_VERSION = f"rules-v2.0-{KEYWORDS_VERSION[:8]}"

app = FastAPI(title="SmartRide Triage Service", version="2.0.0")


class TriageRequest(BaseModel):
    # strict: ints, lists, bytes etc. are rejected instead of coerced to str.
    text: Annotated[str, Field(strict=True, min_length=1, max_length=MAX_TEXT_LENGTH)]


class TriageResponse(BaseModel):
    specialty: str
    # Heuristic keyword-match strength, NOT a calibrated probability.
    confidence: float
    severity: str
    rule_override: bool
    model_version: str
    inference_ms: int


# A plain `def`, not `async def`: keyword matching is CPU-bound, and FastAPI runs a
# sync handler in its threadpool instead of on the event loop that /health shares.
@app.post("/triage", response_model=TriageResponse)
def triage(req: TriageRequest):
    start = time.perf_counter()
    specialty, confidence = infer_specialty(req.text)
    severity, rule_override = compute_severity(req.text)
    elapsed_ms = int((time.perf_counter() - start) * 1000)

    return TriageResponse(
        specialty=specialty,
        confidence=confidence,
        severity=severity,
        rule_override=rule_override,
        model_version=MODEL_VERSION,   # change to "distilbert-v1.0" in Phase 3
        inference_ms=elapsed_ms,
    )


@app.get("/health")
async def health():
    return {"status": "ok", "model": MODEL_VERSION}
