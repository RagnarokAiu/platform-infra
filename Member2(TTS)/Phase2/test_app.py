from fastapi.testclient import TestClient
from app.main import app
from app.services.storage import storage_service
from app.services.tts import tts_service
from app.services.kafka import kafka_service
from app.services.db import db_service
from unittest.mock import MagicMock, AsyncMock, patch
import pytest

client = TestClient(app)

# Mock services for testing
storage_service.upload_audio = AsyncMock(return_value="uploads/test.mp3")
kafka_service.produce_event = MagicMock()
kafka_service.produce_generation_completed = MagicMock()
kafka_service.flush = MagicMock()


def test_read_main():
    """Test root endpoint"""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["message"] == "TTS Service is running"
    assert data["service"] == "Text-to-Speech"


def test_synthesize_text_success():
    """Test text synthesis endpoint"""
    # Mock DB service
    with patch.object(db_service, 'ensure_table_exists'), \
         patch.object(db_service, 'create_job'), \
         patch.object(db_service, 'update_job_status'), \
         patch.object(tts_service, 'synthesize', return_value=b'fake audio data'):
        
        response = client.post(
            "/api/tts/synthesize",
            json={"text": "Hello world", "language": "en"},
            headers={"X-User-Role": "Teacher"}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert "id" in data
        assert data["status"] == "completed"
        assert data["message"] == "Text synthesized successfully"


def test_synthesize_text_permission_denied():
    """Test synthesis with insufficient permissions"""
    response = client.post(
        "/api/tts/synthesize",
        json={"text": "Hello world", "language": "en"},
        headers={"X-User-Role": "Student"}  # Students can't synthesize
    )
    
    assert response.status_code == 403
    assert "ACCESS DENIED" in response.json()["detail"]


def test_get_audio_not_found():
    """Test getting audio for non-existent job"""
    with patch.object(db_service, 'get_job', return_value=None):
        response = client.get(
            "/api/tts/audio/fake-job-id",
            headers={"X-User-Role": "Teacher"}
        )
        
        assert response.status_code == 404
        assert "Job not found" in response.json()["detail"]


def test_get_job_status():
    """Test getting job status"""
    mock_job = {
        "id": "test-id",
        "text": "Hello",
        "language": "en",
        "status": "completed",
        "audio_path": "uploads/test.mp3",
        "created_at": None,
        "updated_at": None
    }
    
    with patch.object(db_service, 'get_job', return_value=mock_job), \
         patch.object(storage_service, 'get_signed_url', return_value=""):
        
        response = client.get(
            "/api/tts/status/test-id",
            headers={"X-User-Role": "Teacher"}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == "test-id"
        assert data["status"] == "completed"
