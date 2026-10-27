"""users.token_version for per-user token invalidation

Access tokens carry the version they were issued under. Bumping the column
(log out everywhere) makes every older token fail, without a Redis entry per
token. Additive and constant-defaulted, so it is safe to run while the previous
release is still serving: that release ignores the column, and tokens issued
without a version count as version 0.

Revision ID: 0009
Revises: 0008
Create Date: 2026-10-26
"""

import sqlalchemy as sa
from alembic import op

revision = "0009"
down_revision = "0008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("token_version", sa.Integer(), nullable=False, server_default="0"),
    )


def downgrade() -> None:
    op.drop_column("users", "token_version")
