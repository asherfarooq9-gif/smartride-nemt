"""wallet ledger guards, FK/rating integrity, indexes, dispatch contract columns

Revision ID: 0007
Revises: 0006
Create Date: 2026-10-23

* wallet_transactions: CHECKs on kind and amount sign, append-only trigger,
  driver FK RESTRICT, idempotency_key (UNIQUE), admin_user_id, payment_method.
* rides: patient/driver FKs RESTRICT, patient_rating CHECK 1..5, queued_at,
  symptom_text, one live emergency ride per patient (partial unique index).
* triage_events: one row per ride (older duplicates removed, newest kept).
* Indexes: missing FK indexes, dispatch partial indexes, redundant duplicates
  of the UNIQUE user_id indexes dropped.

Negative driver balances are allowed on purpose (commission is debited after the
ride completes), so there is no CHECK on drivers.wallet_balance_pkr.
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0007"
down_revision = "0006"
branch_labels = None
depends_on = None

ACTIVE_EMERGENCY = (
    "ride_type = 'emergency' AND status IN ('pending', 'driver_assigned', "
    "'driver_en_route', 'patient_picked_up', 'arrived_at_hospital')"
)
AMOUNT_SIGN_OK = (
    "(kind = 'topup' AND amount > 0) OR (kind = 'commission' AND amount < 0) "
    "OR kind = 'adjustment'"
)


def _count(sql: str) -> int:
    return op.get_bind().execute(sa.text(sql)).scalar_one()


def _require_none(sql: str, message: str) -> None:
    """Fail with a readable message instead of a bare constraint violation."""
    count = _count(sql)
    if count:
        raise RuntimeError(f"Migration 0007 cannot continue: {count} {message}")


def _refuse_if_any(sql: str, message: str) -> None:
    count = _count(sql)
    if count:
        raise RuntimeError(
            f"Refusing to downgrade 0007: {count} {message}. "
            "Dropping that column would destroy data."
        )


def upgrade() -> None:
    _require_none(
        "SELECT count(*) FROM wallet_transactions WHERE NOT (" + AMOUNT_SIGN_OK + ")",
        "wallet_transactions rows have an unknown kind or the wrong amount sign",
    )
    _require_none(
        "SELECT count(*) FROM rides WHERE patient_rating NOT BETWEEN 1 AND 5",
        "rides have a patient_rating outside 1..5",
    )
    _require_none(
        "SELECT count(*) FROM (SELECT patient_id FROM rides WHERE "
        + ACTIVE_EMERGENCY
        + " GROUP BY patient_id HAVING count(*) > 1) dup",
        "patients have more than one active emergency ride; cancel the extras first",
    )

    # ── wallet ledger ────────────────────────────────────────────────────────
    op.add_column("wallet_transactions", sa.Column("idempotency_key", sa.Text()))
    op.add_column(
        "wallet_transactions",
        sa.Column("admin_user_id", postgresql.UUID(as_uuid=True)),
    )
    op.add_column("wallet_transactions", sa.Column("payment_method", sa.Text()))
    op.create_unique_constraint(
        "uq_wallet_idempotency_key", "wallet_transactions", ["idempotency_key"]
    )
    op.create_foreign_key(
        "wallet_transactions_admin_user_id_fkey",
        "wallet_transactions",
        "users",
        ["admin_user_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.drop_constraint(
        "wallet_transactions_driver_id_fkey", "wallet_transactions", type_="foreignkey"
    )
    op.create_foreign_key(
        "wallet_transactions_driver_id_fkey",
        "wallet_transactions",
        "drivers",
        ["driver_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_check_constraint(
        "ck_wallet_kind",
        "wallet_transactions",
        "kind IN ('topup', 'commission', 'adjustment')",
    )
    op.create_check_constraint("ck_wallet_amount_sign", "wallet_transactions", AMOUNT_SIGN_OK)
    op.execute("""
        CREATE OR REPLACE FUNCTION wallet_transactions_append_only()
        RETURNS TRIGGER AS $$
        BEGIN
          RAISE EXCEPTION 'wallet_transactions is append-only (% not allowed)', TG_OP;
        END;
        $$ LANGUAGE plpgsql
    """)
    op.execute("""
        CREATE TRIGGER trg_wallet_append_only
        BEFORE UPDATE OR DELETE ON wallet_transactions
        FOR EACH ROW EXECUTE FUNCTION wallet_transactions_append_only()
    """)

    # ── ride history must outlive its patient/driver ────────────────────────
    for column, target in (("patient_id", "patients"), ("driver_id", "drivers")):
        name = "rides_" + column + "_fkey"
        op.drop_constraint(name, "rides", type_="foreignkey")
        op.create_foreign_key(
            name, "rides", target, [column], ["id"], ondelete="RESTRICT"
        )
    op.create_check_constraint(
        "ck_rides_patient_rating_range", "rides", "patient_rating BETWEEN 1 AND 5"
    )

    # ── dispatch contract columns ────────────────────────────────────────────
    op.add_column(
        "rides",
        sa.Column(
            "queued_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.execute("UPDATE rides SET queued_at = COALESCE(requested_at, created_at, now())")
    op.add_column("rides", sa.Column("symptom_text", sa.Text()))

    # Keep the newest triage event per ride, then enforce it.
    op.execute("""
        DELETE FROM triage_events WHERE id IN (
          SELECT id FROM (
            SELECT id, row_number() OVER (
              PARTITION BY ride_id ORDER BY created_at DESC NULLS LAST, id DESC
            ) AS rn
            FROM triage_events
          ) ranked WHERE rn > 1
        )
    """)
    op.create_unique_constraint(
        "uq_triage_events_ride_id", "triage_events", ["ride_id"]
    )
    op.create_index(
        "uq_rides_active_emergency_per_patient",
        "rides",
        ["patient_id"],
        unique=True,
        postgresql_where=sa.text(ACTIVE_EMERGENCY),
    )

    # ── indexes ──────────────────────────────────────────────────────────────
    op.create_index("ix_hospital_alerts_ride_id", "hospital_alerts", ["ride_id"])
    op.create_index(
        "ix_hospital_alerts_hospital_id", "hospital_alerts", ["hospital_id"]
    )
    op.create_index(
        "ix_family_notifications_ride_id", "family_notifications", ["ride_id"]
    )
    op.create_index("ix_rides_hospital_id", "rides", ["hospital_id"])
    op.create_index(
        "ix_rides_pending_requested_at",
        "rides",
        ["requested_at"],
        postgresql_where=sa.text("status = 'pending'"),
    )
    op.create_index(
        "ix_rides_driver_status_completed",
        "rides",
        ["driver_id", "status", sa.text("completed_at DESC")],
    )
    op.create_index(
        "ix_drivers_available_location",
        "drivers",
        ["current_lat", "current_lng"],
        postgresql_where=sa.text("status = 'available' AND is_verified"),
    )
    # user_id is UNIQUE, so these only duplicate the constraint's own index.
    op.execute("DROP INDEX IF EXISTS idx_patients_user")
    op.execute("DROP INDEX IF EXISTS idx_drivers_user")
    op.execute("DROP INDEX IF EXISTS ix_drivers_user_id")


def downgrade() -> None:
    _refuse_if_any(
        "SELECT count(*) FROM wallet_transactions WHERE idempotency_key IS NOT NULL "
        "OR admin_user_id IS NOT NULL OR payment_method IS NOT NULL",
        "wallet_transactions rows carry idempotency_key/admin_user_id/payment_method",
    )
    _refuse_if_any(
        "SELECT count(*) FROM rides WHERE symptom_text IS NOT NULL",
        "rides carry symptom_text",
    )

    op.execute("CREATE INDEX idx_patients_user ON patients(user_id)")
    op.execute("CREATE INDEX idx_drivers_user ON drivers(user_id)")
    op.drop_index("ix_drivers_available_location", table_name="drivers")
    op.drop_index("ix_rides_driver_status_completed", table_name="rides")
    op.drop_index("ix_rides_pending_requested_at", table_name="rides")
    op.drop_index("ix_rides_hospital_id", table_name="rides")
    op.drop_index("ix_family_notifications_ride_id", table_name="family_notifications")
    op.drop_index("ix_hospital_alerts_hospital_id", table_name="hospital_alerts")
    op.drop_index("ix_hospital_alerts_ride_id", table_name="hospital_alerts")

    op.drop_index("uq_rides_active_emergency_per_patient", table_name="rides")
    # Removed duplicate triage events cannot be restored.
    op.drop_constraint("uq_triage_events_ride_id", "triage_events", type_="unique")
    op.drop_column("rides", "symptom_text")
    op.drop_column("rides", "queued_at")

    op.drop_constraint("ck_rides_patient_rating_range", "rides", type_="check")
    for column, target in (("driver_id", "drivers"), ("patient_id", "patients")):
        name = "rides_" + column + "_fkey"
        op.drop_constraint(name, "rides", type_="foreignkey")
        op.create_foreign_key(name, "rides", target, [column], ["id"])

    op.execute("DROP TRIGGER IF EXISTS trg_wallet_append_only ON wallet_transactions")
    op.execute("DROP FUNCTION IF EXISTS wallet_transactions_append_only()")
    op.drop_constraint("ck_wallet_amount_sign", "wallet_transactions", type_="check")
    op.drop_constraint("ck_wallet_kind", "wallet_transactions", type_="check")
    op.drop_constraint(
        "wallet_transactions_driver_id_fkey", "wallet_transactions", type_="foreignkey"
    )
    op.create_foreign_key(
        "wallet_transactions_driver_id_fkey",
        "wallet_transactions",
        "drivers",
        ["driver_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.drop_constraint(
        "wallet_transactions_admin_user_id_fkey",
        "wallet_transactions",
        type_="foreignkey",
    )
    op.drop_constraint(
        "uq_wallet_idempotency_key", "wallet_transactions", type_="unique"
    )
    op.drop_column("wallet_transactions", "payment_method")
    op.drop_column("wallet_transactions", "admin_user_id")
    op.drop_column("wallet_transactions", "idempotency_key")
