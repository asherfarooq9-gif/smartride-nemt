"""add driver wallet balance

Revision ID: 0003_driver_wallet
Revises: 0002_user_roles
Create Date: 2026-06-08

"""
from alembic import op
import sqlalchemy as sa

revision = '0003_driver_wallet'
down_revision = '0002'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        'drivers',
        sa.Column(
            'wallet_balance_pkr',
            sa.DOUBLE_PRECISION(),
            nullable=False,
            server_default='0',
        ),
    )


def downgrade() -> None:
    op.drop_column('drivers', 'wallet_balance_pkr')
