"""trigram indexes for the admin substring searches

The admin lists search with ILIKE '%term%' on ride pickup address, driver name
and plate, patient name and user phone. A leading wildcard cannot use a btree
index, so each keystroke (debounced) scanned the whole table. GIN trigram
indexes serve that pattern.

Additive: the previous release ignores the indexes. They are built inside this
migration's transaction, which blocks writes to each table for the duration of
its build. That is milliseconds at pilot scale; on a large table build them with
CREATE INDEX CONCURRENTLY by hand first (IF NOT EXISTS makes this a no-op then).
pg_trgm is a trusted extension on PostgreSQL 13+, so no superuser is needed.

Revision ID: 0010
Revises: 0009
Create Date: 2026-10-26
"""

from alembic import op

revision = "0010"
down_revision = "0009"
branch_labels = None
depends_on = None

INDEXES = {
    "ix_rides_pickup_address_trgm": ("rides", "pickup_address"),
    "ix_drivers_full_name_trgm": ("drivers", "full_name"),
    "ix_drivers_vehicle_plate_trgm": ("drivers", "vehicle_plate"),
    "ix_patients_full_name_trgm": ("patients", "full_name"),
    "ix_users_phone_trgm": ("users", "phone"),
}


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")
    for name, (table, column) in INDEXES.items():
        op.execute(
            f"CREATE INDEX IF NOT EXISTS {name} ON {table} "
            f"USING gin ({column} gin_trgm_ops)"
        )


def downgrade() -> None:
    # The extension stays: dropping it could break an index someone added by hand.
    for name in INDEXES:
        op.execute(f"DROP INDEX IF EXISTS {name}")
