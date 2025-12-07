import dotenv
from starlette.middleware.cors import CORSMiddleware

dotenv.load_dotenv()

from app.auth import router as auth_router
from app.user import router as user_router
from app.game import router as game_router
from app.world import router as world_router
from fastapi import FastAPI
import uvicorn

from app.dependencies import livespan

app = FastAPI(lifespan=livespan)

app.include_router(auth_router)
app.include_router(user_router)
app.include_router(game_router)
app.include_router(world_router)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/api/v0/liveness")
def liveness():
    return {}


def main():
    uvicorn.run(app, host="0.0.0.0", port=8000)


if __name__ == "__main__":
    main()
