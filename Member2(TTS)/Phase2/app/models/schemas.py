from pydantic import BaseModel
from typing import Optional
from enum import Enum

class JobStatus(str, Enum):
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"

class SynthesizeRequest(BaseModel):
    text: str
    language: str = "en"

class SynthesizeResponse(BaseModel):
    id: str
    status: JobStatus
    message: str

class AudioResponse(BaseModel):
    id: str
    status: JobStatus
    audio_url: Optional[str] = None
    message: str

class TTSJobDB(BaseModel):
    id: str
    text: str
    language: str
    status: JobStatus
    audio_path: Optional[str] = None
