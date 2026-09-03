"""add farm detail columns to users table

Revision ID: d4e5f6a7b8c9
Revises: c3d4e5f6a7b8
Create Date: 2026-09-03 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'd4e5f6a7b8c9'
down_revision: Union[str, None] = 'c3d4e5f6a7b8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('users', sa.Column('farm_name', sa.String(length=255), nullable=True))
    op.add_column('users', sa.Column('farm_location', sa.String(length=255), nullable=True))
    op.add_column('users', sa.Column('province', sa.String(length=100), nullable=True))
    op.add_column('users', sa.Column('district', sa.String(length=100), nullable=True))
    op.add_column('users', sa.Column('city', sa.String(length=100), nullable=True))
    op.add_column('users', sa.Column('farm_size', sa.Float(), nullable=True))
    op.add_column('users', sa.Column('farm_size_unit', sa.String(length=20), nullable=True))
    op.add_column('users', sa.Column('farmer_type', sa.String(length=100), nullable=True))


def downgrade() -> None:
    op.drop_column('users', 'farmer_type')
    op.drop_column('users', 'farm_size_unit')
    op.drop_column('users', 'farm_size')
    op.drop_column('users', 'city')
    op.drop_column('users', 'district')
    op.drop_column('users', 'province')
    op.drop_column('users', 'farm_location')
    op.drop_column('users', 'farm_name')
