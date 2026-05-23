"""
Hospital Matching Engine
Score = 0.40 × distance + 0.30 × ed_wait + 0.20 × specialty + 0.10 × outcome
All sub-scores normalised to [0, 1]. Higher = better.
"""
import math
from typing import List, Optional
from dataclasses import dataclass


@dataclass
class HospitalCandidate:
    id: str
    name: str
    lat: float
    lng: float
    specialties: List[str]
    ed_capacity: int
    ed_current_load: int
    fhir_endpoint: Optional[str]
    coordinator_phone: Optional[str]
    # optional historical outcome score (0–1, default 0.5)
    outcome_score: float = 0.5


@dataclass
class MatchResult:
    hospital_id: str
    hospital_name: str
    score: float
    distance_km: float
    ed_occupancy_pct: float
    has_fhir: bool
    coordinator_phone: Optional[str]


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Great-circle distance between two GPS points."""
    R = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def match_hospitals(
    patient_lat: float,
    patient_lng: float,
    required_specialty: str,
    candidates: List[HospitalCandidate],
    max_radius_km: float = 30.0,
    top_n: int = 3,
) -> List[MatchResult]:
    """
    Filter candidates then rank by weighted score.
    Returns top_n sorted by score descending.
    """

    # ── HARD FILTERS ──────────────────────────────────────────────────────────
    def passes_filter(h: HospitalCandidate, dist_km: float) -> bool:
        if dist_km > max_radius_km:
            return False
        if h.ed_current_load >= h.ed_capacity:
            return False
        if required_specialty not in h.specialties and required_specialty != "general_emergency":
            return False
        return True

    filtered = []
    for h in candidates:
        dist = haversine_km(patient_lat, patient_lng, h.lat, h.lng)
        if passes_filter(h, dist):
            filtered.append((h, dist))

    if not filtered:
        # fallback: relax specialty filter, keep nearest with capacity
        for h in candidates:
            dist = haversine_km(patient_lat, patient_lng, h.lat, h.lng)
            if dist <= max_radius_km and h.ed_current_load < h.ed_capacity:
                filtered.append((h, dist))

    if not filtered:
        return []

    # ── NORMALISE DISTANCE (0 km = score 1.0, max_radius = 0.0) ──────────────
    max_dist = max(d for _, d in filtered)

    def dist_score(d: float) -> float:
        if max_dist == 0:
            return 1.0
        return 1.0 - (d / max_dist)

    # ── NORMALISE ED WAIT (0% full = 1.0, 100% full = 0.0) ───────────────────
    def ed_score(h: HospitalCandidate) -> float:
        occupancy = h.ed_current_load / max(h.ed_capacity, 1)
        return 1.0 - occupancy

    # ── SPECIALTY SCORE ───────────────────────────────────────────────────────
    def specialty_score(h: HospitalCandidate) -> float:
        return 1.0 if required_specialty in h.specialties else 0.4

    # ── WEIGHTED TOTAL ────────────────────────────────────────────────────────
    results = []
    for h, dist in filtered:
        score = (
            0.40 * dist_score(dist) +
            0.30 * ed_score(h) +
            0.20 * specialty_score(h) +
            0.10 * h.outcome_score
        )
        results.append(MatchResult(
            hospital_id=h.id,
            hospital_name=h.name,
            score=round(score, 4),
            distance_km=round(dist, 2),
            ed_occupancy_pct=round((h.ed_current_load / max(h.ed_capacity, 1)) * 100, 1),
            has_fhir=bool(h.fhir_endpoint),
            coordinator_phone=h.coordinator_phone,
        ))

    results.sort(key=lambda r: r.score, reverse=True)
    return results[:top_n]
