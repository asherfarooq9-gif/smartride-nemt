"""
Canonical specialty vocabulary + keyword rules for the triage service.

Single source of truth shared by:
  - main.py                (rule-based inference, and model-output normalization)
  - backend fallback rules (mirrored in backend/app/core/specialties.py)

CANONICAL_SPECIALTIES matches the Postgres ``specialty`` enum in
backend/app/models/models.py. The trained DistilBERT model is labelled with the
richer dataset vocabulary (see data/hospital_routing_label_map.json); its output
MUST be passed through normalize_specialty() before it reaches the backend or DB.
"""

# Enum values in backend/app/models/models.py (kept in sync).
CANONICAL_SPECIALTIES = frozenset(
    {
        "cardiology",
        "neurology",
        "orthopedics",
        "obstetrics",
        "pediatrics",
        "psychiatry",
        "oncology",
        "nephrology",
        "pulmonology",
        "gastroenterology",
        "ophthalmology",
        "ent",
        "dermatology",
        "urology",
        "general_emergency",
    }
)

FALLBACK_SPECIALTY = "general_emergency"

# Dataset label (data/hospital_routing_label_map.json) -> canonical enum value.
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

# Keyword rules — active until the DistilBERT model is trained and wired.
# (Deduplicated: this list is the single copy; main.py imports it.)
SEVERITY_5_KEYWORDS = [
    "chest pain", "heart attack", "not breathing", "stroke",
    "unconscious", "unresponsive", "seizure", "severe bleeding",
    "cardiac arrest", "overdose", "choking", "can't breathe",
]

SPECIALTY_RULES = [
    (["chest", "heart", "palpitation", "cardiac"], "cardiology"),
    (["stroke", "brain", "unconscious", "numbness", "can't talk", "cant talk", "slurred"], "neurology"),
    (["broken", "fracture", "joint", "bone", "sprain"], "orthopedics"),
    (["pregnant", "labour", "delivery", "contractions"], "obstetrics"),
    (["child", "infant", "baby", "toddler", "pediatric"], "pediatrics"),
    (["mental", "anxiety", "depression", "hallucination"], "psychiatry"),
    (["cancer", "tumor", "chemotherapy", "chemo"], "oncology"),
    (["kidney", "dialysis", "renal"], "nephrology"),
    (["breathing", "lungs", "asthma", "copd", "respiratory"], "pulmonology"),
    (["stomach", "abdomen", "vomit", "diarrhea", "bowel"], "gastroenterology"),
    (["eye", "vision", "blind"], "ophthalmology"),
    (["ear", "nose", "throat", "hearing"], "ent"),
    (["skin", "rash", "burn", "allergy"], "dermatology"),
    (["urine", "urinary", "bladder", "prostate", "kidney stone"], "urology"),
]


def normalize_specialty(raw: str) -> str:
    """
    Map any specialty string (dataset label, model output, or already-canonical
    slug) to a canonical enum value. Unknown inputs fall back to
    general_emergency so routing never crashes on an out-of-vocab label.
    """
    if raw is None:
        return FALLBACK_SPECIALTY
    if raw in DATASET_LABEL_TO_ENUM:
        return DATASET_LABEL_TO_ENUM[raw]
    slug = raw.strip().lower().replace(" ", "_")
    if slug in CANONICAL_SPECIALTIES:
        return slug
    return FALLBACK_SPECIALTY
