"""ride dropoff fields

Revision ID: 0008
Revises: 0007
Create Date: 2026-07-28

Scheduled rides previously only captured a pickup location plus an optional
hospital_id — but hospital_id was never actually populated by the create-ride
flow (the mobile hospital picker was decorative, never serialized into the
request). Add real dropoff columns so the patient app can capture a
destination by manual address entry or a map pin, independent of the
hospital directory.
"""

from alembic import op
import sqlalchemy as sa

revision = "0008"
down_revision = "0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("rides", sa.Column("dropoff_lat", sa.Double(), nullable=True))
    op.add_column("rides", sa.Column("dropoff_lng", sa.Double(), nullable=True))
    op.add_column("rides", sa.Column("dropoff_address", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("rides", "dropoff_address")
    op.drop_column("rides", "dropoff_lng")
    op.drop_column("rides", "dropoff_lat")
