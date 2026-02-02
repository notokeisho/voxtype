"""Authentication routes for GitHub OAuth."""

from urllib.parse import urlencode

from fastapi import APIRouter, Request
from fastapi.responses import RedirectResponse

from app.auth.oauth import oauth

router = APIRouter(prefix="/auth", tags=["auth"])


async def _handle_login(request: Request):
    """Common login handler for both VoiceClient and admin-web.

    Query Parameters:
        callback: The client's callback URL scheme (e.g., voiceclient://callback) - used by VoiceClient
        redirect_uri: The web callback URL (e.g., http://localhost:5173/auth/callback) - used by admin-web

    Returns:
        RedirectResponse to GitHub OAuth authorization URL
    """
    # Support both parameter names: callback (VoiceClient) and redirect_uri (admin-web)
    client_callback = request.query_params.get("callback", "")
    if not client_callback:
        client_callback = request.query_params.get("redirect_uri", "")

    request.session["client_callback"] = client_callback

    redirect_uri = str(request.url_for("callback"))
    github = oauth.create_client("github")
    return await github.authorize_redirect(request, redirect_uri)


# VoiceClient uses /auth/github/login
@router.get("/github/login")
async def github_login(request: Request):
    """Redirect to GitHub OAuth login page (VoiceClient endpoint)."""
    return await _handle_login(request)


# admin-web uses /auth/login
@router.get("/login")
async def login(request: Request):
    """Redirect to GitHub OAuth login page (admin-web endpoint)."""
    return await _handle_login(request)


@router.get("/github/callback")
async def callback(request: Request):
    """Handle GitHub OAuth callback.

    Redirects to the client's callback URL with either:
    - Success: ?token=<jwt_token>
    - Error: ?error=<error_code>&message=<error_message>

    Args:
        request: The incoming request with OAuth code

    Returns:
        RedirectResponse to client callback URL
    """
    # Get client callback URL from session
    client_callback = request.session.get("client_callback", "")

    def redirect_with_error(error_code: str, message: str) -> RedirectResponse:
        """Helper to redirect with error parameters."""
        if client_callback:
            params = urlencode({"error": error_code, "message": message})
            return RedirectResponse(url=f"{client_callback}?{params}", status_code=302)
        # Fallback: return simple error page if no callback
        return RedirectResponse(url=f"/auth/error?{urlencode({'error': error_code, 'message': message})}", status_code=302)

    def redirect_with_token(token: str) -> RedirectResponse:
        """Helper to redirect with token."""
        if client_callback:
            params = urlencode({"token": token})
            return RedirectResponse(url=f"{client_callback}?{params}", status_code=302)
        # Fallback: return JSON if no callback (for testing)
        from fastapi.responses import JSONResponse
        return JSONResponse({"access_token": token, "token_type": "bearer"})

    # Check for error from GitHub
    error = request.query_params.get("error")
    if error:
        error_desc = request.query_params.get("error_description", "OAuth authorization failed")
        return redirect_with_error("github_error", error_desc)

    # Check for authorization code
    code = request.query_params.get("code")
    if not code:
        return redirect_with_error("missing_code", "Missing authorization code")

    # Exchange code for access token and get user info
    github = oauth.create_client("github")
    try:
        token = await github.authorize_access_token(request)
        resp = await github.get("user", token=token)
        user_info = resp.json()
    except Exception as e:
        return redirect_with_error("github_auth_failed", str(e))

    # Import here to avoid circular imports
    from sqlalchemy import select

    from app.auth.jwt import create_jwt_token
    from app.database import async_session_factory
    from app.models.user import User
    from app.models.whitelist import is_whitelisted

    github_id = str(user_info.get("id"))
    github_avatar = user_info.get("avatar_url")

    # Check whitelist
    async with async_session_factory() as session:
        if not await is_whitelisted(session, github_id):
            return redirect_with_error("not_whitelisted", "Your account is not in the whitelist. Please contact an administrator.")

        # Get or create user
        result = await session.execute(
            select(User).where(User.github_id == github_id)
        )
        user = result.scalar_one_or_none()

        if user is None:
            user = User(github_id=github_id, github_avatar=github_avatar)
            session.add(user)
            await session.commit()
            await session.refresh(user)
        else:
            # Update avatar if changed
            if user.github_avatar != github_avatar:
                user.github_avatar = github_avatar
                await session.commit()

        # Create JWT token
        jwt_token = create_jwt_token(user_id=user.id, github_id=github_id)

    return redirect_with_token(jwt_token)


@router.get("/error")
async def auth_error(request: Request):
    """Display authentication error page.

    This is a fallback for when the client callback URL is not available.
    """
    error = request.query_params.get("error", "unknown")
    message = request.query_params.get("message", "An unknown error occurred")

    # Return simple HTML error page
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Authentication Error</title>
        <style>
            body {{ font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 40px; text-align: center; }}
            .error-box {{ background: #fee; border: 1px solid #fcc; padding: 20px; border-radius: 8px; max-width: 400px; margin: 0 auto; }}
            h1 {{ color: #c00; }}
        </style>
    </head>
    <body>
        <div class="error-box">
            <h1>Authentication Failed</h1>
            <p><strong>Error:</strong> {error}</p>
            <p>{message}</p>
            <p>Please close this window and try again.</p>
        </div>
    </body>
    </html>
    """
    from fastapi.responses import HTMLResponse
    return HTMLResponse(content=html_content, status_code=400)
