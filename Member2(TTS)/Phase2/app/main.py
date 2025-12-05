from fastapi import FastAPI
from app.api.routes import router
from app.core.config import settings

app = FastAPI(title=settings.PROJECT_NAME)

app.include_router(router, prefix=settings.API_V1_STR)

@app.get("/")
async def root():
    return {"message": "TTS Service is running", "service": "Text-to-Speech"}
