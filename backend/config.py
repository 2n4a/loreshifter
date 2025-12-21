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

def load_secret(name):
    secret_path = Path(f"/run/secrets/{name.lower().replace('_', '-')}")
    if secret_path.exists():
        return secret_path.read_text()
    secret = os.environ.get(name)
    if secret is not None:
        return secret
    raise Exception(f"Secret {name} not found")


PROXY_API_KEY: str = load_secret("PROXY_API_KEY")
JWT_SECRET: str = load_secret("JWT_SECRET")
OAUTH2_GITHUB_CLIENT_ID: str = load_secret("OAUTH2_GITHUB_CLIENT_ID")
OAUTH2_GITHUB_CLIENT_SECRET: str = load_secret("OAUTH2_GITHUB_CLIENT_SECRET")
LOG_STACKTRACE: bool = os.environ.get("LOG_STACKTRACE", "false").lower() == "true"

if "POSTGRES_URL" in os.environ or ENVIRONMENT == "dev":
    POSTGRES_URL: str = os.environ.get(
        "POSTGRES_URL", "postgres://devuser:devpass@localhost:5432/devdb"
    )
else:
    POSTGRES_URL: str = (
        f"postgres://"
        f"{os.getenv("DB_USER", "postgres")}:{load_secret("DB_PASSWORD")}@"
        f"{os.getenv("DB_HOST", "localhost")}:{os.getenv("DB_PORT", 5432)}/"
        f"{os.getenv("DB_NAME")}"
    )

KICK_PLAYER_AFTER_SECONDS: float = 10.0
