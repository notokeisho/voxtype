"""Admin user management API endpoints."""

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy import delete, select

from app.auth.dependencies import get_current_admin_user
from app.config import settings
from app.database import async_session_factory
from app.models.global_dictionary_request import get_pending_request_count_for_user
from app.models.user import User
from app.models.user_dictionary import get_user_rejected_entry_count

router = APIRouter(prefix="/admin/api", tags=["admin"])
REQUEST_LIMIT = 200


class UserResponse(BaseModel):
    """User response model."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    github_id: str
    github_username: str | None
    github_avatar: str | None
    is_admin: bool
    created_at: datetime
    last_login_at: datetime | None
    request_remaining: int


class UpdateUserRequest(BaseModel):
    """Request model for updating user."""

    is_admin: bool


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
        responses: list[UserResponse] = []
        for user in users:
            pending_count = await get_pending_request_count_for_user(session, user.id)
            rejected_count = await get_user_rejected_entry_count(session, user.id)
            responses.append(
                UserResponse(
                    id=user.id,
                    github_id=user.github_id,
                    github_username=user.github_username,
                    github_avatar=user.github_avatar,
                    is_admin=user.is_admin,
                    created_at=user.created_at,
                    last_login_at=user.last_login_at,
                    request_remaining=REQUEST_LIMIT - pending_count - rejected_count,
                )
            )
        return responses


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


@router.patch("/users/{user_id}", response_model=UserResponse)
async def update_user(
    user_id: int,
    request: UpdateUserRequest,
    admin: User = Depends(get_current_admin_user),
) -> UserResponse:
    """Update a user's admin status.

    Admin only endpoint.
    Constraints:
    - Cannot change your own admin status
    - Cannot change the initial admin to member
    """
    async with async_session_factory() as session:
        result = await session.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()

        if user is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found",
            )

        # Cannot change your own admin status
        if user.id == admin.id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot change your own admin status",
            )

        # Cannot change the initial admin to member
        if (
            settings.initial_admin_github_id
            and user.github_id == settings.initial_admin_github_id
            and not request.is_admin
        ):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot change the initial admin to member",
            )

        user.is_admin = request.is_admin
        await session.commit()
        await session.refresh(user)

        return UserResponse.model_validate(user)
