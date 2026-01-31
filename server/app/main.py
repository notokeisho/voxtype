"""FastAPI application entry point."""

from fastapi import FastAPI
from starlette.middleware.sessions import SessionMiddleware

from app.admin.dictionary import router as admin_dictionary_router
from app.admin.users import router as admin_users_router
from app.admin.whitelist import router as admin_whitelist_router
from app.api.dictionary import router as dictionary_router
from app.api.me import router as me_router
from app.api.protected import router as api_router
from app.api.status import router as status_router
from app.api.transcribe import router as transcribe_router
from app.auth.routes import router as auth_router
from app.config import settings

app = FastAPI(
    title=settings.app_name,
    debug=settings.debug,
)

# Add session middleware for OAuth (required by authlib)
app.add_middleware(SessionMiddleware, secret_key=settings.jwt_secret)

# Include routers
app.include_router(auth_router)
app.include_router(api_router)
app.include_router(me_router)
app.include_router(status_router)
app.include_router(transcribe_router)
app.include_router(dictionary_router)

# Admin routers
app.include_router(admin_users_router)
app.include_router(admin_whitelist_router)
app.include_router(admin_dictionary_router)


@app.get("/")
async def root():
    """Root endpoint returning application status."""
    return {"status": "ok", "app": settings.app_name}
