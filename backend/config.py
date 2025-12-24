import os
import sys
import typing
from pathlib import Path

import dotenv

dotenv.load_dotenv()

ENVIRONMENT: typing.Literal["dev", "prod"] = os.environ.get("ENVIRONMENT", "dev")
if ENVIRONMENT not in ("dev", "prod"):
    print(f"Unknown environment: {ENVIRONMENT}", file=sys.stderr)
    sys.exit(1)


def load_secret(name: str, *, required: bool = True) -> str | None:
    secret_path = Path(f"/run/secrets/{name.lower().replace('_', '-')}")
    if secret_path.exists():
        return secret_path.read_text().strip()
    secret = os.environ.get(name)
    if secret is not None:
        return secret
    if required:
        raise RuntimeError(f"Secret {name} not found")
    return None


PROXY_API_KEY: str | None = load_secret("PROXY_API_KEY", required=False)
JWT_SECRET: str | None = load_secret("JWT_SECRET", required=False)
OAUTH2_GITHUB_CLIENT_ID: str | None = load_secret(
    "OAUTH2_GITHUB_CLIENT_ID", required=False
)
OAUTH2_GITHUB_CLIENT_SECRET: str | None = load_secret(
    "OAUTH2_GITHUB_CLIENT_SECRET", required=False
)
_LLM_ENABLED_RAW = os.environ.get("LLM_ENABLED")
if _LLM_ENABLED_RAW is None:
    LLM_ENABLED: bool = bool(PROXY_API_KEY)
else:
    LLM_ENABLED = _LLM_ENABLED_RAW.lower() not in ("0", "false", "no", "off")
    if LLM_ENABLED and not PROXY_API_KEY:
        LLM_ENABLED = False

DM_MODEL: str = os.environ.get("DM_MODEL", "gpt-4o-mini")
PLAYER_MODEL: str = os.environ.get("PLAYER_MODEL", "gpt-4o-mini")
CHARACTER_MODEL: str = os.environ.get("CHARACTER_MODEL", PLAYER_MODEL)
LLM_LOG_LIMIT: int = int(os.environ.get("LLM_LOG_LIMIT", "200"))
LOG_STACKTRACE: bool = os.environ.get("LOG_STACKTRACE", "false").lower() == "true"

if "POSTGRES_URL" in os.environ or ENVIRONMENT == "dev":
    POSTGRES_URL: str = os.environ.get(
        "POSTGRES_URL", "postgres://devuser:devpass@localhost:5432/devdb"
    )
else:
    POSTGRES_URL: str = (
        f"postgres://"
        f"{os.getenv('DB_USER', 'postgres')}:{load_secret('DB_PASSWORD')}@"
        f"{os.getenv('DB_HOST', 'localhost')}:{os.getenv('DB_PORT', 5432)}/"
        f"{os.getenv('DB_NAME')}"
    )

KICK_PLAYER_AFTER_SECONDS: float = 10.0

SELF_URL: str = os.environ.get("SELF_URL", "http://localhost:8000")
FRONTEND_URL: str = os.environ.get("FRONTEND_URL", "http://localhost:8081")
AUTH_REDIRECT_URL: str = os.environ.get(
    "AUTH_REDIRECT_URL", f"{FRONTEND_URL}/auth-callback"
)


def _parse_csv_env(name: str) -> list[str]:
    raw = os.environ.get(name, "")
    if not raw:
        return []
    return [item.strip() for item in raw.split(",") if item.strip()]


CORS_ALLOW_ORIGINS: list[str] = _parse_csv_env("CORS_ALLOW_ORIGINS")
if not CORS_ALLOW_ORIGINS and ENVIRONMENT == "dev":
    CORS_ALLOW_ORIGINS = [
        "http://localhost:8081",
        "http://127.0.0.1:8081",
    ]
