"""
9 test cases for the hospital matching engine.

Scoring formula:
  score = 0.40*dist_score + 0.30*ed_score + 0.20*specialty_score + 0.10*outcome_score
  dist_score  = 1 - (d / max_dist_in_filtered_set)
  ed_score    = 1 - (load / capacity)
  specialty_score = 1.0 if required_specialty in h.specialties else 0.4
  outcome_score   = h.outcome_score (default 0.5)
"""

import pytest
from app.services.hospital_matching import (
    HospitalCandidate,
    match_hospitals,
    haversine_km,
)

# ── reference location: PIMS Islamabad ────────────────────────────────────────
PATIENT_LAT, PATIENT_LNG = 33.7215, 73.0433


def make_h(
    id: str,
    lat: float,
    lng: float,
    specialties=None,
    capacity: int = 100,
    load: int = 30,
    outcome: float = 0.5,
    fhir: str | None = None,
    coord_phone: str | None = None,
) -> HospitalCandidate:
    return HospitalCandidate(
        id=id,
        name=f"Hospital {id}",
        lat=lat,
        lng=lng,
        specialties=specialties or ["cardiology"],
        ed_capacity=capacity,
        ed_current_load=load,
        fhir_endpoint=fhir,
        coordinator_phone=coord_phone,
        outcome_score=outcome,
    )


# ─────────────────────────────────────────────────────────────────────────────
# Case 1: single match — correct fields returned
# ─────────────────────────────────────────────────────────────────────────────
def test_single_candidate_returns_match():
    h = make_h("A", 33.7200, 73.0400, specialties=["cardiology"], load=20, capacity=100)
    results = match_hospitals(PATIENT_LAT, PATIENT_LNG, "cardiology", [h])
    assert len(results) == 1
    r = results[0]
    assert r.hospital_id == "A"
    assert r.score > 0
    assert r.distance_km >= 0
    assert r.ed_occupancy_pct == pytest.approx(20.0, abs=0.1)


# ─────────────────────────────────────────────────────────────────────────────
# Case 2: specialty filter removes non-matching hospital
# ─────────────────────────────────────────────────────────────────────────────
def test_specialty_filter_excludes_wrong_specialty():
    h_wrong = make_h("B", 33.7200, 73.0400, specialties=["neurology"])
    h_right = make_h("C", 33.7250, 73.0450, specialties=["cardiology"])
    results = match_hospitals(
        PATIENT_LAT, PATIENT_LNG, "cardiology", [h_wrong, h_right]
    )
    ids = {r.hospital_id for r in results}
    assert "B" not in ids
    assert "C" in ids


# ─────────────────────────────────────────────────────────────────────────────
# Case 3: distance filter — hospital beyond max_radius_km excluded
# ─────────────────────────────────────────────────────────────────────────────
def test_distance_filter_excludes_far_hospital():
    # ~40 km away (Rawalpindi city centre ~20 km; Lahore ~300 km)
    far = make_h("D", 31.5497, 74.3436, specialties=["cardiology"])  # Lahore, ~250 km
    near = make_h("E", 33.7100, 73.0500, specialties=["cardiology"])
    results = match_hospitals(
        PATIENT_LAT, PATIENT_LNG, "cardiology", [far, near], max_radius_km=30
    )
    ids = {r.hospital_id for r in results}
    assert "D" not in ids
    assert "E" in ids


# ─────────────────────────────────────────────────────────────────────────────
# Case 4: full ED excluded
# ─────────────────────────────────────────────────────────────────────────────
def test_full_ed_excluded():
    full = make_h(
        "F", 33.7200, 73.0400, specialties=["cardiology"], capacity=50, load=50
    )
    ok = make_h("G", 33.7250, 73.0450, specialties=["cardiology"], capacity=50, load=10)
    results = match_hospitals(PATIENT_LAT, PATIENT_LNG, "cardiology", [full, ok])
    ids = {r.hospital_id for r in results}
    assert "F" not in ids
    assert "G" in ids


# ─────────────────────────────────────────────────────────────────────────────
# Case 5: weighted ranking — closer but busier vs farther but emptier
#   H1: 2 km away, 80% full, specialty match, outcome 0.5
#   H2: 8 km away, 10% full, specialty match, outcome 0.5
# With two candidates, max_dist = 8 km.
#   H1: dist_score = 1-(2/8)=0.75  ed_score=0.20  spec=1.0  out=0.5
#       score = 0.40*0.75 + 0.30*0.20 + 0.20*1.0 + 0.10*0.5 = 0.30+0.06+0.20+0.05 = 0.61
#   H2: dist_score = 1-(8/8)=0.00  ed_score=0.90  spec=1.0  out=0.5
#       score = 0.40*0.0 + 0.30*0.90 + 0.20*1.0 + 0.10*0.5 = 0+0.27+0.20+0.05 = 0.52
# Expected: H1 wins (0.61 > 0.52)
# ─────────────────────────────────────────────────────────────────────────────
def test_weighted_score_ranking_closer_busy_vs_farther_empty():
    # place hospitals at known haversine distances: ~2 km north, ~8 km north
    h1 = make_h(
        "H1", 33.7394, 73.0433, specialties=["cardiology"], capacity=100, load=80
    )  # ~2 km
    h2 = make_h(
        "H2", 33.7935, 73.0433, specialties=["cardiology"], capacity=100, load=10
    )  # ~8 km

    d1 = haversine_km(PATIENT_LAT, PATIENT_LNG, h1.lat, h1.lng)
    d2 = haversine_km(PATIENT_LAT, PATIENT_LNG, h2.lat, h2.lng)
    max_d = max(d1, d2)

    score1 = 0.40 * (1 - d1 / max_d) + 0.30 * (1 - 80 / 100) + 0.20 * 1.0 + 0.10 * 0.5
    score2 = 0.40 * (1 - d2 / max_d) + 0.30 * (1 - 10 / 100) + 0.20 * 1.0 + 0.10 * 0.5

    results = match_hospitals(PATIENT_LAT, PATIENT_LNG, "cardiology", [h1, h2])
    assert len(results) == 2
    assert results[0].hospital_id == ("H1" if score1 > score2 else "H2")
    assert results[0].score >= results[1].score


# ─────────────────────────────────────────────────────────────────────────────
# Case 6: general_emergency bypasses specialty filter
# ─────────────────────────────────────────────────────────────────────────────
def test_general_emergency_bypasses_specialty_filter():
    h_neuro = make_h("J", 33.7200, 73.0400, specialties=["neurology"])
    h_cardio = make_h("K", 33.7250, 73.0450, specialties=["cardiology"])
    results = match_hospitals(
        PATIENT_LAT, PATIENT_LNG, "general_emergency", [h_neuro, h_cardio]
    )
    ids = {r.hospital_id for r in results}
    assert "J" in ids
    assert "K" in ids


# ─────────────────────────────────────────────────────────────────────────────
# Case 7: fallback — no specialty match → returns any in-radius, non-full hospital
# ─────────────────────────────────────────────────────────────────────────────
def test_fallback_when_no_specialty_match():
    h_ortho = make_h("L", 33.7200, 73.0400, specialties=["orthopedics"])
    results = match_hospitals(PATIENT_LAT, PATIENT_LNG, "cardiology", [h_ortho])
    # fallback should include h_ortho (in radius, not full)
    assert len(results) == 1
    assert results[0].hospital_id == "L"


# ─────────────────────────────────────────────────────────────────────────────
# Case 8: top_n caps result list
# ─────────────────────────────────────────────────────────────────────────────
def test_top_n_limits_results():
    hospitals = [
        make_h(f"N{i}", 33.7200 + i * 0.002, 73.0400, specialties=["cardiology"])
        for i in range(5)
    ]
    results = match_hospitals(
        PATIENT_LAT, PATIENT_LNG, "cardiology", hospitals, top_n=3
    )
    assert len(results) == 3


# ─────────────────────────────────────────────────────────────────────────────
# Case 9: all candidates out of radius → empty list
# ─────────────────────────────────────────────────────────────────────────────
def test_empty_when_all_out_of_radius():
    far = make_h("Z", 31.5497, 74.3436, specialties=["cardiology"])  # Lahore ~250 km
    results = match_hospitals(
        PATIENT_LAT, PATIENT_LNG, "cardiology", [far], max_radius_km=30
    )
    assert results == []
