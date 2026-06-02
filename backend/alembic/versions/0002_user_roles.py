"""multi-role: user_roles join table + backfill

Revision ID: 0002
Revises: 0001
Create Date: 2026-05-30

One account can hold both patient and driver roles. `users.role` keeps the
*active* role (current portal); `user_roles` holds all roles the account has.
"""
from typing import Sequence, Union
from alembic import op

revision: str = "0002"
down_revision: Union[str, None] = "0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("""
        CREATE TABLE user_roles (
            id      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            role    user_role NOT NULL
        )
    """)
    op.execute("CREATE INDEX ix_user_roles_user_id ON user_roles (user_id)")
    op.execute(
        "CREATE UNIQUE INDEX uq_user_roles_user_role ON user_roles (user_id, role)"
    )

    # Backfill: every existing user gets a role link mirroring their current role.
    op.execute("""
        INSERT INTO user_roles (id, user_id, role)
        SELECT uuid_generate_v4(), id, role FROM users
    """)


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS user_roles")
