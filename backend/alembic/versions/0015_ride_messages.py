"""in-ride chat messages

Adds ride_messages: short text messages between a ride's patient and driver.
Rows are deleted when the ride ends, so the table stays small.

Additive: one new table. The previous release ignores it.
Rollback: drop the table (it holds nothing that outlives a trip).

Revision ID: 0015
Revises: 0014
Create Date: 2026-11-08
"""

from alembic import op

revision = "0015"
down_revision = "0014"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE IF NOT EXISTS ride_messages (
            id bigserial PRIMARY KEY,
            ride_id uuid NOT NULL REFERENCES rides (id) ON DELETE CASCADE,
            sender_user_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
            sender_role varchar(10) NOT NULL,
            body varchar(500) NOT NULL,
            created_at timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT ck_ride_messages_role
                CHECK (sender_role IN ('patient', 'driver')),
            CONSTRAINT ck_ride_messages_body
                CHECK (char_length(btrim(body)) > 0)
        )
        """
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_ride_messages_ride_id_id "
        "ON ride_messages (ride_id, id)"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_ride_messages_ride_id_id")
    op.execute("DROP TABLE IF EXISTS ride_messages")
