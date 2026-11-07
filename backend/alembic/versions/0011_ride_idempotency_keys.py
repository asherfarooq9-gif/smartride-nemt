"""durable idempotency keys for ride creation

POST /rides/scheduled deduplicated only through a Redis key written after the
ride committed, so two concurrent requests could both create a ride, and a Redis
outage allowed a duplicate on every retry. This table is written in the same
transaction as the ride, so the database decides.

Additive: a new table nothing else reads. The previous release ignores it, so it
can be deployed before the code. Rollback: leave the table; reverting the code
restores the Redis-only behavior.

Revision ID: 0011
Revises: 0010
Create Date: 2026-11-05
"""

from alembic import op

revision = "0011"
down_revision = "0010"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE IF NOT EXISTS ride_idempotency_keys (
            patient_id  uuid        NOT NULL REFERENCES patients(id),
            scope       text        NOT NULL,
            key         text        NOT NULL,
            fingerprint text        NOT NULL,
            ride_id     uuid        NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
            created_at  timestamptz NOT NULL DEFAULT now(),
            PRIMARY KEY (patient_id, scope, key)
        )
        """
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_ride_idempotency_keys_created_at "
        "ON ride_idempotency_keys (created_at)"
    )


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS ride_idempotency_keys")
