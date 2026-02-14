"""add is_rejected to user_dictionary

Revision ID: 9a3f1d7d7e2c
Revises: 5c4a2a1b7a9f
Create Date: 2026-02-14 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "9a3f1d7d7e2c"
down_revision: Union[str, Sequence[str], None] = "5c4a2a1b7a9f"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "user_dictionary",
        sa.Column("is_rejected", sa.Boolean(), server_default=sa.text("false"), nullable=False),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("user_dictionary", "is_rejected")
