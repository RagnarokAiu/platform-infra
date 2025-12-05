from fastapi.testclient import TestClient
from app.main import app
from app.services.storage import storage_service
from app.services.stt import stt_service
from app.services.kafka import kafka_service
from app.services.db import db_service
from unittest.mock import MagicMock, AsyncMock, patch
import pytest
import io

client = TestClient(app)

# Mock services for testing
storage_service.upload_audio = AsyncMock(return_value="uploads/test.mp3")
storage_service.get_local_path = MagicMock(return_value="uploads/test.mp3")
kafka_service.produce_event = MagicMock()
kafka_service.produce_transcription_completed = MagicMock()
kafka_service.flush = MagicMock()


def test_read_main():
    """Test root endpoint"""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["message"] == "STT Service is running"
    assert data["service"] == "Speech-to-Text"


def test_transcribe_audio_success():
    """Test audio transcription endpoint"""
    # Mock DB and STT service
    with patch.object(db_service, 'ensure_table_exists'), \
         patch.object(db_service, 'create_job'), \
         patch.object(db_service, 'update_job_status'), \
         patch.object(stt_service, 'transcribe', return_value={
             "text": "Hello world this is a test",
             "language": "en",
             "segments": []
         }):
        
        # Create a fake audio file
        fake_audio = io.BytesIO(b"fake audio content")
        
        response = client.post(
            "/api/stt/transcribe",
            files={"file": ("test.mp3", fake_audio, "audio/mpeg")},
            headers={"X-User-Role": "Teacher"}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert "id" in data
        assert data["status"] == "completed"
        assert data["message"] == "Audio transcribed successfully"


def test_transcribe_audio_permission_denied():
    """Test transcription with insufficient permissions"""
    fake_audio = io.BytesIO(b"fake audio content")
    
    response = client.post(
        "/api/stt/transcribe",
        files={"file": ("test.mp3", fake_audio, "audio/mpeg")},
        headers={"X-User-Role": "Student"}  # Students can't transcribe
    )
    
    assert response.status_code == 403
    assert "ACCESS DENIED" in response.json()["detail"]


def test_get_transcription_not_found():
    """Test getting transcription for non-existent job"""
    with patch.object(db_service, 'get_job', return_value=None):
        response = client.get(
            "/api/stt/transcription/fake-job-id",
            headers={"X-User-Role": "Teacher"}
        )
        
        assert response.status_code == 404
        assert "Job not found" in response.json()["detail"]


def test_get_transcription_success():
    """Test getting completed transcription"""
    mock_job = {
        "id": "test-id",
        "filename": "test.mp3",
        "audio_path": "uploads/test.mp3",
        "status": "completed",
        "text": "Hello world this is a test",
        "language": "en",
        "created_at": None,
        "updated_at": None
    }
    
    with patch.object(db_service, 'get_job', return_value=mock_job):
        response = client.get(
            "/api/stt/transcription/test-id",
            headers={"X-User-Role": "Teacher"}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == "test-id"
        assert data["status"] == "completed"
        assert data["text"] == "Hello world this is a test"
        assert data["language"] == "en"


def test_get_job_status():
    """Test getting job status"""
    mock_job = {
        "id": "test-id",
        "filename": "test.mp3",
        "audio_path": "uploads/test.mp3",
        "status": "processing",
        "text": None,
        "language": None,
        "created_at": None,
        "updated_at": None
    }
    
    with patch.object(db_service, 'get_job', return_value=mock_job):
        response = client.get(
            "/api/stt/status/test-id",
            headers={"X-User-Role": "Teacher"}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == "test-id"
        assert data["status"] == "processing"
