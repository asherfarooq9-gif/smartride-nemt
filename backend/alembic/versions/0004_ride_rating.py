"""add patient_rating and rating_comment to rides

Revision ID: 0004
Revises: 0003
Create Date: 2026-06-09
"""
from alembic import op
import sqlalchemy as sa

revision = '0004'
down_revision = '0003'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('rides', sa.Column('patient_rating', sa.Numeric(2, 1), nullable=True))
    op.add_column('rides', sa.Column('rating_comment', sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column('rides', 'rating_comment')
    op.drop_column('rides', 'patient_rating')
