"""add disease_category and pest_category columns

Revision ID: 8a1c2f9b7e3d
Revises: 4f27d696912b
Create Date: 2026-08-30 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '8a1c2f9b7e3d'
down_revision: Union[str, None] = '4f27d696912b'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('disease_detections', sa.Column('disease_category', sa.String(length=50), nullable=True))
    op.add_column('pest_detections', sa.Column('pest_category', sa.String(length=50), nullable=True))


def downgrade() -> None:
    op.drop_column('pest_detections', 'pest_category')
    op.drop_column('disease_detections', 'disease_category')
