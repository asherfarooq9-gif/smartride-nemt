"""Fare and commission rules. Money is Decimal end to end, rounded to the paisa."""

from decimal import ROUND_HALF_UP, Decimal

from app.core.config import settings

PAISA = Decimal("0.01")


def fare_for(distance_km: float) -> Decimal:
    """Flat base plus a per-km rate for the pickup -> hospital distance."""
    fare = Decimal(str(settings.FARE_BASE_PKR)) + Decimal(
        str(settings.FARE_PER_KM_PKR)
    ) * Decimal(str(distance_km))
    return fare.quantize(PAISA, ROUND_HALF_UP)


def commission_for(fare: Decimal) -> Decimal:
    return (fare * Decimal(str(settings.COMMISSION_RATE))).quantize(
        PAISA, ROUND_HALF_UP
    )
