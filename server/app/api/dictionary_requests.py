"""Dictionary request API endpoints."""

from fastapi import APIRouter, Depends, status
from pydantic import BaseModel

from app.auth.dependencies import get_current_user
from app.database import get_session
from app.models.global_dictionary_request import add_request
from app.models.user import User

router = APIRouter(prefix="/api", tags=["dictionary-requests"])


class DictionaryRequestCreate(BaseModel):
    """Request body for creating a dictionary request."""

    pattern: str
    replacement: str


class DictionaryRequestResponse(BaseModel):
    """Response for a dictionary request."""

    id: int
    pattern: str
    replacement: str
    status: str


@router.post(
    "/dictionary-requests",
    response_model=DictionaryRequestResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_dictionary_request(
    body: DictionaryRequestCreate,
    current_user: User = Depends(get_current_user),
):
    """Create a dictionary request."""
    async with get_session() as session:
        request = await add_request(
            session=session,
            user_id=current_user.id,
            pattern=body.pattern,
            replacement=body.replacement,
        )

    return DictionaryRequestResponse(
        id=request.id,
        pattern=request.pattern,
        replacement=request.replacement,
        status=request.status,
    )
