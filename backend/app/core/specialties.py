"""
Specialty vocabulary normalization (backend side).

Mirrors ai-services/triage/specialties.py. The triage microservice already emits
canonical slugs, but this guard makes the backend resilient to the fine-tuned
model's richer dataset labels (e.g. "Nephrology_Dialysis") and to any future
caller, guaranteeing every specialty that reaches hospital matching or the
Postgres ``specialty`` enum is a valid enum value.
"""

from app.models.models import Specialty

CANONICAL_SPECIALTIES = frozenset(s.value for s in Specialty)

FALLBACK_SPECIALTY = Specialty.general_emergency.value

# Dataset label (ai-services/triage/data/hospital_routing_label_map.json)
# -> canonical enum value.
DATASET_LABEL_TO_ENUM = {
    "Cardiology": "cardiology",
    "ENT": "ent",
    "Emergency_Trauma": "general_emergency",
    "Gastroenterology": "gastroenterology",
    "General_Medicine": "general_emergency",
    "Nephrology_Dialysis": "nephrology",
    "Neurology": "neurology",
    "Obstetrics_Gynecology": "obstetrics",
    "Oncology": "oncology",
    "Orthopedics": "orthopedics",
    "Pediatrics": "pediatrics",
    "Psychiatry_MentalHealth": "psychiatry",
    "Pulmonology": "pulmonology",
    "Urology": "urology",
}


def normalize_specialty(raw: str) -> str:
    """Map any specialty string to a canonical enum value; unknown -> fallback."""
    if not raw:
        return FALLBACK_SPECIALTY
    if raw in DATASET_LABEL_TO_ENUM:
        return DATASET_LABEL_TO_ENUM[raw]
    slug = raw.strip().lower().replace(" ", "_")
    if slug in CANONICAL_SPECIALTIES:
        return slug
    return FALLBACK_SPECIALTY
