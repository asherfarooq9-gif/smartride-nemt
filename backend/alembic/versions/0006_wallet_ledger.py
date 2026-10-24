"""wallet ledger: append-only wallet_transactions, money as NUMERIC

Revision ID: 0006
Revises: 0005
Create Date: 2026-10-21
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0006"
down_revision = "0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column(
        "drivers",
        "wallet_balance_pkr",
        type_=sa.Numeric(12, 2),
        existing_type=sa.DOUBLE_PRECISION(),
        postgresql_using="round(wallet_balance_pkr::numeric, 2)",
        existing_nullable=False,
        existing_server_default="0",
    )
    op.create_table(
        "wallet_transactions",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "driver_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("drivers.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("ride_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("rides.id")),
        sa.Column("kind", sa.String(20), nullable=False),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        # One commission per ride, whatever happens (retries, double taps).
        sa.UniqueConstraint("ride_id", "kind", name="uq_wallet_ride_kind"),
    )
    op.create_index(
        "ix_wallet_transactions_driver_created",
        "wallet_transactions",
        ["driver_id", "created_at"],
    )
    # Existing balances become the opening entry so balance == SUM(ledger) holds.
    op.execute(
        "INSERT INTO wallet_transactions (id, driver_id, kind, amount) "
        "SELECT gen_random_uuid(), id, 'adjustment', wallet_balance_pkr "
        "FROM drivers WHERE wallet_balance_pkr <> 0"
    )


def downgrade() -> None:
    op.drop_table("wallet_transactions")
    op.alter_column(
        "drivers",
        "wallet_balance_pkr",
        type_=sa.DOUBLE_PRECISION(),
        existing_type=sa.Numeric(12, 2),
        postgresql_using="wallet_balance_pkr::double precision",
        existing_nullable=False,
        existing_server_default="0",
    )
