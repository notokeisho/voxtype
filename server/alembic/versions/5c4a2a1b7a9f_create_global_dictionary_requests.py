"""create global dictionary requests table

Revision ID: 5c4a2a1b7a9f
Revises: 25d9d52ace8d
Create Date: 2026-02-14 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "5c4a2a1b7a9f"
down_revision: Union[str, Sequence[str], None] = "25d9d52ace8d"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "global_dictionary_requests",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("pattern", sa.String(length=255), nullable=False),
        sa.Column("replacement", sa.String(length=255), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("created_at", sa.DateTime(), server_default=sa.text("now()"), nullable=False),
        sa.Column("reviewed_at", sa.DateTime(), nullable=True),
        sa.Column("reviewed_by", sa.Integer(), nullable=True),
        sa.ForeignKeyConstraint(["reviewed_by"], ["users.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_global_dictionary_requests_user_id"),
        "global_dictionary_requests",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_global_dictionary_requests_pattern"),
        "global_dictionary_requests",
        ["pattern"],
        unique=False,
    )
    op.create_index(
        op.f("ix_global_dictionary_requests_status"),
        "global_dictionary_requests",
        ["status"],
        unique=False,
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(op.f("ix_global_dictionary_requests_status"), table_name="global_dictionary_requests")
    op.drop_index(op.f("ix_global_dictionary_requests_pattern"), table_name="global_dictionary_requests")
    op.drop_index(op.f("ix_global_dictionary_requests_user_id"), table_name="global_dictionary_requests")
    op.drop_table("global_dictionary_requests")
