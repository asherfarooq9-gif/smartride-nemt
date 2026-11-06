"""let a driver list the payment methods they accept

Adds drivers.payment_methods, a JSON list of method names (cash, easypaisa, ...).
The app never handles the money; this is only what the driver says they accept.

Additive: one column with a default, so the previous release ignores it.
Rollback: leave the column; reverting the code restores today's behavior.

Revision ID: 0013
Revises: 0012
Create Date: 2026-11-05
"""

from alembic import op

revision = "0013"
down_revision = "0012"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE drivers "
        "ADD COLUMN IF NOT EXISTS payment_methods json NOT NULL DEFAULT '[]'::json"
    )


def downgrade() -> None:
    op.execute("ALTER TABLE drivers DROP COLUMN IF EXISTS payment_methods")
