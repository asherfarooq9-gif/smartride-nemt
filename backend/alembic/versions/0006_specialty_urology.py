"""add urology to specialty enum

Revision ID: 0006
Revises: 0005
Create Date: 2026-07-26

The triage dataset (ai-services/triage/data/hospital_routing_*.csv) includes a
``Urology`` class that had no home in the Postgres ``specialty`` enum. Add it so
the fine-tuned model can emit urology routing faithfully instead of collapsing
it to general_emergency.
"""

from alembic import op

revision = "0006"
down_revision = "0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ALTER TYPE ... ADD VALUE is supported inside a transaction on PostgreSQL 12+.
    op.execute("ALTER TYPE specialty ADD VALUE IF NOT EXISTS 'urology'")


def downgrade() -> None:
    # PostgreSQL cannot DROP a single enum value. Downgrade is a no-op; the
    # value is harmless if unused. Removing it would require recreating the type.
    pass
