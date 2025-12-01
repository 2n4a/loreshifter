import dotenv
dotenv.load_dotenv()

from app.auth import router as auth_router
from app.user import router as user_router
from app.play import router as play_router
from fastapi import FastAPI
import uvicorn

from app.dependencies import livespan

app = FastAPI(lifespan=livespan)

app.include_router(auth_router)
app.include_router(user_router)
app.include_router(play_router)

@app.get("/api/v0/liveness")
def liveness():
    return {}


def main():
    uvicorn.run(app, host="0.0.0.0", port=8000)


if __name__ == "__main__":
    main()
