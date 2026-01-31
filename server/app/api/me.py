"""User profile API endpoint."""

from datetime import datetime

from fastapi import APIRouter, Depends
from pydantic import BaseModel, ConfigDict

from app.auth.dependencies import get_current_user
from app.models.user import User

router = APIRouter(prefix="/api", tags=["user"])


class UserResponse(BaseModel):
    """User profile response."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    github_id: str
    github_avatar: str | None
    is_admin: bool
    created_at: datetime
    last_login_at: datetime | None


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)) -> UserResponse:
    """Get current user profile.

    Returns the authenticated user's profile information.
    """
    return UserResponse.model_validate(current_user)
