"""add unique constraint to user_dictionary pattern

Revision ID: 4b2a1f9c6d7e
Revises: 9a3f1d7d7e2c
Create Date: 2026-02-14 00:00:00.000000
"""

from alembic import op

# revision identifiers, used by Alembic.
revision = "4b2a1f9c6d7e"
down_revision = "9a3f1d7d7e2c"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_unique_constraint(
        "uq_user_dictionary_user_id_pattern",
        "user_dictionary",
        ["user_id", "pattern"],
    )


def downgrade() -> None:
    op.drop_constraint(
        "uq_user_dictionary_user_id_pattern",
        "user_dictionary",
        type_="unique",
    )
