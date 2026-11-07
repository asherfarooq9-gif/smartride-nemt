"""let a driver claim a booked ride ahead of time

Adds rides.claimed_driver_id and claimed_at. A claimed ride stays pending and is
hidden from other drivers; dispatch hands it to the claiming driver when its
pickup window opens.

Additive: two nullable columns and a partial index. The previous release ignores
them (every claim is NULL), so this can be deployed before the code. Rollback:
leave the columns; reverting the code restores today's behavior.

Revision ID: 0012
Revises: 0011
Create Date: 2026-11-05
"""

from alembic import op

revision = "0012"
down_revision = "0011"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE rides "
        "ADD COLUMN IF NOT EXISTS claimed_driver_id uuid "
        "REFERENCES drivers(id) ON DELETE RESTRICT, "
        "ADD COLUMN IF NOT EXISTS claimed_at timestamptz"
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_rides_claimed_driver_id "
        "ON rides (claimed_driver_id) WHERE claimed_driver_id IS NOT NULL"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_rides_claimed_driver_id")
    op.execute(
        "ALTER TABLE rides DROP COLUMN IF EXISTS claimed_at, "
        "DROP COLUMN IF EXISTS claimed_driver_id"
    )
