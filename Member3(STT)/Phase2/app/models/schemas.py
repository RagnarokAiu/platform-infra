from pydantic import BaseModel
from typing import Optional
from enum import Enum

class JobStatus(str, Enum):
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"

class TranscribeResponse(BaseModel):
    id: str
    status: JobStatus
    message: str

class TranscriptionResult(BaseModel):
    id: str
    status: JobStatus
    text: Optional[str] = None
    language: Optional[str] = None
    message: str

class STTJobDB(BaseModel):
    id: str
    filename: str
    status: JobStatus
    text: Optional[str] = None
    language: Optional[str] = None
