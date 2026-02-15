"""FastAPI application entry point."""

import asyncio
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.sessions import SessionMiddleware

from app.admin.dictionary import router as admin_dictionary_router
from app.admin.dictionary_requests import router as admin_dictionary_requests_router
from app.admin.backup_settings import router as admin_backup_settings_router
from app.admin.backup_run import router as admin_backup_run_router
from app.admin.backup_files import router as admin_backup_files_router
from app.admin.backup_restore import router as admin_backup_restore_router
from app.admin.users import router as admin_users_router
from app.admin.whitelist import router as admin_whitelist_router
from app.api.dictionary import router as dictionary_router
from app.api.dictionary_requests import router as dictionary_requests_router
from app.api.me import router as me_router
from app.api.protected import router as api_router
from app.api.status import router as status_router
from app.api.transcribe import router as transcribe_router
from app.auth.routes import router as auth_router
from app.bootstrap import ensure_initial_admin
from app.config import settings
from app.database import async_session_factory
from app.services.backup import run_backup_if_enabled
from app.services.backup_scheduler import start_backup_scheduler


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan event handler."""
    # Startup
    await ensure_initial_admin()
    stop_event = asyncio.Event()

    async def run_backup_job() -> None:
        async with async_session_factory() as session:
            await run_backup_if_enabled(session)

    scheduler_task = start_backup_scheduler(
        stop_event=stop_event,
        run_task=run_backup_job,
        run_at_hour=3,
    )

    try:
        yield
    finally:
        # Shutdown
        stop_event.set()
        try:
            await asyncio.wait_for(scheduler_task, timeout=5)
        except asyncio.TimeoutError:
            scheduler_task.cancel()
            await asyncio.gather(scheduler_task, return_exceptions=True)


app = FastAPI(
    title=settings.app_name,
    debug=settings.debug,
    lifespan=lifespan,
)

# Add CORS middleware for admin-web
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:5173",  # admin-web dev server (default)
        "http://localhost:5174",  # admin-web dev server (alternate)
        "http://localhost:5175",  # admin-web dev server (alternate)
        "http://localhost:5176",  # admin-web dev server (alternate)
        "http://localhost:5177",  # admin-web dev server (alternate)
        "http://localhost:3000",  # admin-web production (local)
        "https://voxtype-admin.oshiruko.dev",  # admin-web production
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
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
app.include_router(dictionary_requests_router)

# Admin routers
app.include_router(admin_users_router)
app.include_router(admin_whitelist_router)
app.include_router(admin_dictionary_router)
app.include_router(admin_dictionary_requests_router)
app.include_router(admin_backup_settings_router)
app.include_router(admin_backup_run_router)
app.include_router(admin_backup_files_router)
app.include_router(admin_backup_restore_router)


@app.get("/")
async def root():
    """Root endpoint returning application status."""
    return {"status": "ok", "app": settings.app_name}
