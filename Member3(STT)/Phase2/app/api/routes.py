from fastapi import APIRouter, HTTPException, Header, UploadFile, File
from app.core import rbac
from app.models.schemas import TranscribeResponse, TranscriptionResult, JobStatus
from app.services.stt import stt_service
from app.services.storage import storage_service
from app.services.kafka import kafka_service
import uuid
import os

router = APIRouter()

# In-memory job storage for local testing (when DB is not available)
jobs_cache = {}

@router.post("/stt/transcribe", response_model=TranscribeResponse)
async def transcribe_audio(
    file: UploadFile = File(...),
    x_user_role: str = Header(..., alias="X-User-Role")
):
    """
    Upload audio file and start transcription job.
    
    - Accepts: Audio file (MP3, WAV, M4A, etc.)
    - Returns: Job ID and status
    """
    # RBAC Check
    try:
        rbac.enforce_permission(x_user_role, "stt:transcribe")
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    
    # Generate job ID
    job_id = str(uuid.uuid4())
    
    # Get file extension
    _, ext = os.path.splitext(file.filename)
    filename = f"{job_id}{ext}"
    
    try:
        # Upload audio to storage
        audio_path = await storage_service.upload_audio(file, filename)
        
        # Store initial job info in cache
        jobs_cache[job_id] = {
            "id": job_id,
            "filename": file.filename,
            "audio_path": audio_path,
            "status": "processing",
            "text": None,
            "language": None
        }
        
        # Try to save to DB (optional - won't fail if DB unavailable)
        try:
            from app.services.db import db_service
            db_service.ensure_table_exists()
            db_service.create_job(job_id, file.filename, audio_path)
            db_service.update_job_status(job_id, "processing")
        except Exception as db_error:
            print(f"DB not available (using cache): {db_error}")
        
        # Get local path for Whisper processing
        local_path = storage_service.get_local_path(filename)
        
        # Transcribe audio using Whisper
        result = stt_service.transcribe(local_path)
        
        # Update job with transcription result
        jobs_cache[job_id].update({
            "status": "completed",
            "text": result["text"],
            "language": result["language"]
        })
        
        # Try to update DB
        try:
            from app.services.db import db_service
            db_service.update_job_status(
                job_id, 
                "completed", 
                text=result["text"], 
                language=result["language"]
            )
        except:
            pass
        
        # Produce Kafka event (won't fail if Kafka unavailable)
        kafka_service.produce_transcription_completed(
            job_id, 
            result["text"], 
            result["language"], 
            "completed"
        )
        kafka_service.flush()
        
        return TranscribeResponse(
            id=job_id,
            status=JobStatus.COMPLETED,
            message="Audio transcribed successfully"
        )
        
    except Exception as e:
        # Update job as failed
        if job_id in jobs_cache:
            jobs_cache[job_id]["status"] = "failed"
        raise HTTPException(status_code=500, detail=f"Transcription failed: {str(e)}")


@router.get("/stt/transcription/{job_id}", response_model=TranscriptionResult)
async def get_transcription(
    job_id: str,
    x_user_role: str = Header(..., alias="X-User-Role")
):
    """
    Get the transcription result for a job.
    """
    # RBAC Check
    try:
        rbac.enforce_permission(x_user_role, "stt:read")
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    
    # Check cache first
    job = jobs_cache.get(job_id)
    
    # If not in cache, try database
    if not job:
        try:
            from app.services.db import db_service
            job = db_service.get_job(job_id)
        except:
            pass
    
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    if job["status"] == "pending" or job["status"] == "processing":
        return TranscriptionResult(
            id=job_id,
            status=JobStatus(job["status"]),
            message=f"Transcription is still being processed. Status: {job['status']}"
        )
    
    if job["status"] == "failed":
        return TranscriptionResult(
            id=job_id,
            status=JobStatus.FAILED,
            message="Transcription failed"
        )
    
    return TranscriptionResult(
        id=job_id,
        status=JobStatus.COMPLETED,
        text=job["text"],
        language=job["language"],
        message="Transcription completed successfully"
    )


@router.get("/stt/status/{job_id}", response_model=TranscriptionResult)
async def get_job_status(
    job_id: str,
    x_user_role: str = Header(..., alias="X-User-Role")
):
    """
    Get the status of a transcription job.
    """
    # RBAC Check
    try:
        rbac.enforce_permission(x_user_role, "stt:read")
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    
    # Check cache first
    job = jobs_cache.get(job_id)
    
    if not job:
        try:
            from app.services.db import db_service
            job = db_service.get_job(job_id)
        except:
            pass
    
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    return TranscriptionResult(
        id=job_id,
        status=JobStatus(job["status"]),
        text=job.get("text"),
        language=job.get("language"),
        message=f"Job status: {job['status']}"
    )
