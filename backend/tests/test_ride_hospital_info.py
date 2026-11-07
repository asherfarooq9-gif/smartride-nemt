"""The driver is handed the hospital's coordinates so a maps app can navigate there."""

from types import SimpleNamespace

from app.routers.rides import _hospital_info


def _ride(hospital):
    return SimpleNamespace(hospital=hospital)


def test_hospital_info_carries_coordinates():
    hospital = SimpleNamespace(
        name="PIMS", address="G-8/3", city="Islamabad", lat=33.7, lng=73.05
    )

    info = _hospital_info(_ride(hospital))

    assert info is not None
    assert (info.lat, info.lng) == (33.7, 73.05)
    assert info.model_dump()["lat"] == 33.7


def test_hospital_info_is_none_without_a_hospital():
    assert _hospital_info(_ride(None)) is None
