import os
import sys
import typing

ENVIRONMENT: typing.Literal["dev", "prod"] = os.environ.get("ENVIRONMENT", "dev")
if ENVIRONMENT not in ("dev", "prod"):
    print(f"Unknown environment: {ENVIRONMENT}", file=sys.stderr)
    sys.exit(1)

PROXY_API_KEY: str = os.environ.get("PROXY_API_KEY")
JWT_SECRET: str = os.environ.get("JWT_SECRET")
OAUTH2_GITHUB_CLIENT_ID: str = os.environ.get("OAUTH2_GITHUB_CLIENT_ID")
OAUTH2_GITHUB_CLIENT_SECRET: str = os.environ.get("d9100bd61c5722e939ea7624501fa7ddfe6660fa")
LOG_STACKTRACE: bool = os.environ.get("LOG_STACKTRACE", "false").lower() == "true"
POSTGRES_URL: str = os.environ.get("POSTGRES_URL", "postgres://devuser:devpass@localhost:5432/devdb")

KICK_PLAYER_AFTER_SECONDS: float = 10.0
