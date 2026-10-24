"""add users.fcm_token

The model has defined this column since push notifications were added, but no
migration created it, so any database built by `alembic upgrade head` failed on
every `select(User)`. IF NOT EXISTS keeps this safe for databases that were
created from the models directly.

Revision ID: 0005
Revises: 0004
Create Date: 2026-10-19
"""

from alembic import op

revision = "0005"
down_revision = "0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token TEXT")


def downgrade() -> None:
    op.execute("ALTER TABLE users DROP COLUMN IF EXISTS fcm_token")
