"""Admin user management API endpoints."""

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy import delete, select

from app.auth.dependencies import get_current_admin_user
from app.database import async_session_factory
from app.models.user import User

router = APIRouter(prefix="/admin/api", tags=["admin"])


class UserResponse(BaseModel):
    """User response model."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    github_id: str
    github_avatar: str | None
    is_admin: bool
    created_at: datetime
    last_login_at: datetime | None


@router.get("/users", response_model=list[UserResponse])
async def list_users(
    _admin: User = Depends(get_current_admin_user),
) -> list[UserResponse]:
    """List all users.

    Admin only endpoint.
    """
    async with async_session_factory() as session:
        result = await session.execute(select(User).order_by(User.created_at.desc()))
        users = result.scalars().all()
        return [UserResponse.model_validate(u) for u in users]


@router.delete("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_user(
    user_id: int,
    _admin: User = Depends(get_current_admin_user),
) -> None:
    """Delete a user.

    Admin only endpoint. Cannot delete admin users.
    """
    async with async_session_factory() as session:
        result = await session.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()

        if user is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found",
            )

        if user.is_admin:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot delete admin users",
            )

        await session.execute(delete(User).where(User.id == user_id))
        await session.commit()
