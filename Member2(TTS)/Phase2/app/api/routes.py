from fastapi import APIRouter, HTTPException, Header, Response
from fastapi.responses import StreamingResponse
from app.core import rbac
from app.models.schemas import SynthesizeRequest, SynthesizeResponse, AudioResponse, JobStatus
from app.services.tts import tts_service
from app.services.storage import storage_service
from app.services.kafka import kafka_service
import uuid
import io
import os

router = APIRouter()

# In-memory job storage for local testing (when DB is not available)
jobs_cache = {}

@router.post("/tts/synthesize", response_model=SynthesizeResponse)
async def synthesize_text(
    request: SynthesizeRequest,
    x_user_role: str = Header(..., alias="X-User-Role")
):
    """
    Convert text to speech and start a synthesis job.
    
    - Request body: {"text": "Hello world", "language": "en"}
    - Returns: Job ID and status
    """
    # RBAC Check
    try:
        rbac.enforce_permission(x_user_role, "tts:synthesize")
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    
    # Generate job ID
    job_id = str(uuid.uuid4())
    
    try:
        # Synthesize audio using gTTS
        audio_data = tts_service.synthesize(request.text, request.language)
        
        # Upload to storage
        filename = f"{job_id}.mp3"
        audio_path = await storage_service.upload_audio(audio_data, filename)
        
        # Store job info in cache (for local testing without DB)
        jobs_cache[job_id] = {
            "id": job_id,
            "text": request.text,
            "language": request.language,
            "status": "completed",
            "audio_path": audio_path
        }
        
        # Try to save to DB (optional - won't fail if DB unavailable)
        try:
            from app.services.db import db_service
            db_service.ensure_table_exists()
            db_service.create_job(job_id, request.text, request.language)
            db_service.update_job_status(job_id, "completed", audio_path)
        except Exception as db_error:
            print(f"DB not available (using cache): {db_error}")
        
        # Produce Kafka event (won't fail if Kafka unavailable)
        kafka_service.produce_generation_completed(job_id, audio_path, "completed")
        kafka_service.flush()
        
        return SynthesizeResponse(
            id=job_id,
            status=JobStatus.COMPLETED,
            message="Text synthesized successfully"
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Synthesis failed: {str(e)}")


@router.get("/tts/audio/{job_id}")
async def get_audio(
    job_id: str,
    x_user_role: str = Header(..., alias="X-User-Role")
):
    """
    Download the generated audio file.
    
    - Path param: job_id (UUID of the synthesis job)
    - Returns: MP3 audio file or job status
    """
    # RBAC Check
    try:
        rbac.enforce_permission(x_user_role, "tts:read")
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
        return AudioResponse(
            id=job_id,
            status=JobStatus(job["status"]),
            message=f"Audio is still being processed. Status: {job['status']}"
        )
    
    if job["status"] == "failed":
        return AudioResponse(
            id=job_id,
            status=JobStatus.FAILED,
            message="Audio synthesis failed"
        )
    
    # Get audio from storage
    try:
        filename = f"{job_id}.mp3"
        audio_data = await storage_service.get_audio(filename)
        
        return StreamingResponse(
            io.BytesIO(audio_data),
            media_type="audio/mpeg",
            headers={"Content-Disposition": f"attachment; filename={filename}"}
        )
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail="Audio file not found")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving audio: {str(e)}")


@router.get("/tts/status/{job_id}", response_model=AudioResponse)
async def get_job_status(
    job_id: str,
    x_user_role: str = Header(..., alias="X-User-Role")
):
    """
    Get the status of a synthesis job.
    """
    # RBAC Check
    try:
        rbac.enforce_permission(x_user_role, "tts:read")
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
    
    audio_url = None
    if job["status"] == "completed" and job.get("audio_path"):
        audio_url = f"/api/tts/audio/{job_id}"
    
    return AudioResponse(
        id=job_id,
        status=JobStatus(job["status"]),
        audio_url=audio_url,
        message=f"Job status: {job['status']}"
    )
