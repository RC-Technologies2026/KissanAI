"""add plants and plant_diagnoses tables

Revision ID: c3d4e5f6a7b8
Revises: 8a1c2f9b7e3d
Create Date: 2026-09-01 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = 'c3d4e5f6a7b8'
down_revision: Union[str, None] = '8a1c2f9b7e3d'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # --- plants table ---
    op.create_table('plants',
    sa.Column('id', sa.UUID(), nullable=False),
    sa.Column('user_id', sa.UUID(), nullable=False),
    sa.Column('plant_name', sa.String(length=255), nullable=False),
    sa.Column('species', sa.String(length=255), nullable=True),
    sa.Column('image_url', sa.String(length=500), nullable=True),
    sa.Column('health_status', sa.String(length=50), nullable=True),
    sa.Column('notes', sa.Text(), nullable=True),
    sa.Column('created_at', sa.DateTime(), nullable=True),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
    sa.PrimaryKeyConstraint('id')
    )

    # --- plant_diagnoses table ---
    op.create_table('plant_diagnoses',
    sa.Column('id', sa.UUID(), nullable=False),
    sa.Column('plant_id', sa.UUID(), nullable=False),
    sa.Column('image_id', sa.UUID(), nullable=False),
    sa.Column('issue_name', sa.String(length=255), nullable=False),
    sa.Column('issue_category', sa.String(length=50), nullable=True),
    sa.Column('confidence_score', sa.Float(), nullable=True),
    sa.Column('diagnosis', sa.Text(), nullable=True),
    sa.Column('detected_at', sa.DateTime(), nullable=True),
    sa.ForeignKeyConstraint(['plant_id'], ['plants.id'], ),
    sa.ForeignKeyConstraint(['image_id'], ['images.id'], ),
    sa.PrimaryKeyConstraint('id')
    )


def downgrade() -> None:
    op.drop_table('plant_diagnoses')
    op.drop_table('plants')
