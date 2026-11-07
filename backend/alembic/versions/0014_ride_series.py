"""group repeat bookings into a series

Adds rides.series_id, shared by every ride booked in one repeat request
(for example weekly dialysis trips).

Additive: one nullable column and a partial index. The previous release ignores it.
Rollback: leave the column; reverting the code restores today's behavior.

Revision ID: 0014
Revises: 0013
Create Date: 2026-11-05
"""

from alembic import op

revision = "0014"
down_revision = "0013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE rides ADD COLUMN IF NOT EXISTS series_id uuid")
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_rides_series_id "
        "ON rides (series_id) WHERE series_id IS NOT NULL"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_rides_series_id")
    op.execute("ALTER TABLE rides DROP COLUMN IF EXISTS series_id")
