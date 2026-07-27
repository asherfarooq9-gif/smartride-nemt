"""multi-device fcm tokens

Revision ID: 0007
Revises: 0006
Create Date: 2026-07-27

users.fcm_token held one token per account, so logging into a second device
silently evicted push for the first. Replace it with a user_fcm_tokens table
(one row per device) so push fans out to every device a user is logged into,
and a single device can be unregistered on logout without affecting others.
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0007"
down_revision = "0006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "user_fcm_tokens",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("token", sa.Text(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_index(
        "ix_user_fcm_tokens_user_id", "user_fcm_tokens", ["user_id"]
    )
    op.create_index(
        "uq_user_fcm_tokens_user_token",
        "user_fcm_tokens",
        ["user_id", "token"],
        unique=True,
    )

    # Carry forward any token already registered under the old single-column
    # scheme so existing devices don't silently stop receiving push.
    op.execute(
        """
        INSERT INTO user_fcm_tokens (id, user_id, token, created_at)
        SELECT gen_random_uuid(), id, fcm_token, now()
        FROM users
        WHERE fcm_token IS NOT NULL AND fcm_token <> ''
        """
    )

    op.drop_column("users", "fcm_token")


def downgrade() -> None:
    op.add_column("users", sa.Column("fcm_token", sa.Text(), nullable=True))
    op.execute(
        """
        UPDATE users
        SET fcm_token = t.token
        FROM (
            SELECT DISTINCT ON (user_id) user_id, token
            FROM user_fcm_tokens
            ORDER BY user_id, created_at DESC
        ) t
        WHERE users.id = t.user_id
        """
    )
    op.drop_index("uq_user_fcm_tokens_user_token", table_name="user_fcm_tokens")
    op.drop_index("ix_user_fcm_tokens_user_id", table_name="user_fcm_tokens")
    op.drop_table("user_fcm_tokens")
