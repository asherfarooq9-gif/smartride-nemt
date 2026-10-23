"""Streaming CSV export of rides for the admin dashboard."""

import csv
import io
from typing import AsyncIterator, Optional

from sqlalchemy import and_, select, tuple_

from app.core import database
from app.core.search import contains
from app.models.models import Ride, RideStatus, RideType

EXPORT_PAGE_SIZE = 500

CSV_HEADER = [
    "id",
    "ride_type",
    "status",
    "pickup_address",
    "requested_at",
    "completed_at",
    "cancelled_at",
    "estimated_fare_pkr",
    "final_fare_pkr",
    "patient_id",
    "driver_id",
    "hospital_id",
]

_FORMULA_PREFIXES = ("=", "+", "-", "@", "\t", "\r")


def csv_safe(value: str) -> str:
    """Spreadsheets run cells that start with = + - @ (or tab/CR) as formulas."""
    return "'" + value if value[:1] in _FORMULA_PREFIXES else value


def _iso(value) -> str:
    return value.isoformat() if value else ""


def ride_row(r: Ride) -> list:
    cells = [
        str(r.id),
        r.ride_type.value,
        r.status.value,
        r.pickup_address or "",
        _iso(r.requested_at),
        _iso(r.completed_at),
        _iso(r.cancelled_at),
        float(r.estimated_fare_pkr) if r.estimated_fare_pkr else "",
        float(r.final_fare_pkr) if r.final_fare_pkr else "",
        str(r.patient_id),
        str(r.driver_id) if r.driver_id else "",
        str(r.hospital_id) if r.hospital_id else "",
    ]
    return [csv_safe(c) if isinstance(c, str) else c for c in cells]


def _to_csv(rows: list[list]) -> str:
    buf = io.StringIO()
    csv.writer(buf).writerows(rows)
    return buf.getvalue()


def _filters(
    status: Optional[RideStatus], ride_type: Optional[RideType], search: Optional[str]
) -> list:
    conditions = []
    if status:
        conditions.append(Ride.status == status)
    if ride_type:
        conditions.append(Ride.ride_type == ride_type)
    if search:
        conditions.append(Ride.pickup_address.ilike(contains(search), escape="\\"))
    return conditions


async def rides_csv_chunks(
    status: Optional[RideStatus] = None,
    ride_type: Optional[RideType] = None,
    search: Optional[str] = None,
) -> AsyncIterator[str]:
    """Yield the export page by page, newest first.

    Owns its session: a StreamingResponse body runs after the request-scoped
    get_db session may already be closed, so the generator must not use it.
    Keyset pagination (no OFFSET, no COUNT) keeps every page cheap and stable
    while new rides arrive.
    """
    yield _to_csv([CSV_HEADER])
    conditions = _filters(status, ride_type, search)
    async with database.AsyncSessionLocal() as db:
        cursor = None
        while True:
            where = list(conditions)
            if cursor is not None:
                where.append(tuple_(Ride.requested_at, Ride.id) < tuple_(*cursor))
            query = select(Ride).order_by(Ride.requested_at.desc(), Ride.id.desc())
            if where:
                query = query.where(and_(*where))
            rows = (await db.execute(query.limit(EXPORT_PAGE_SIZE))).scalars().all()
            if not rows:
                return
            yield _to_csv([ride_row(r) for r in rows])
            if len(rows) < EXPORT_PAGE_SIZE:
                return
            cursor = (rows[-1].requested_at, rows[-1].id)
