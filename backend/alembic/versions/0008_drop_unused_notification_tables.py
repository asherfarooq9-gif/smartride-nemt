"""drop hospital_alerts and family_notifications

Nothing ever wrote to either table: hospital and family SMS go straight through
Twilio and are not recorded. Removing them also removes a place message bodies
(PHI) could have been stored.

Revision ID: 0008
Revises: 0007
Create Date: 2026-10-24
"""

from alembic import op

revision = "0008"
down_revision = "0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("DROP TABLE hospital_alerts")
    op.execute("DROP TABLE family_notifications")


def downgrade() -> None:
    # Same shape as 0001 plus the indexes 0007 added, so 0007's own downgrade still works.
    op.execute("""
        CREATE TABLE hospital_alerts (
            id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            ride_id     UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
            hospital_id UUID NOT NULL REFERENCES hospitals(id),
            channel     VARCHAR(20) NOT NULL,
            payload     JSONB,
            sent_at     TIMESTAMPTZ,
            status      VARCHAR(20) DEFAULT 'pending',
            error_msg   TEXT
        )
    """)
    op.execute("""
        CREATE TABLE family_notifications (
            id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            ride_id         UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
            recipient_phone VARCHAR(20) NOT NULL,
            message_body    TEXT NOT NULL,
            twilio_sid      VARCHAR(100),
            sent_at         TIMESTAMPTZ DEFAULT NOW(),
            status          VARCHAR(20) DEFAULT 'pending'
        )
    """)
    op.create_index("ix_hospital_alerts_ride_id", "hospital_alerts", ["ride_id"])
    op.create_index(
        "ix_hospital_alerts_hospital_id", "hospital_alerts", ["hospital_id"]
    )
    op.create_index(
        "ix_family_notifications_ride_id", "family_notifications", ["ride_id"]
    )
