import whisper
import os
import tempfile
from app.core.config import settings

class STTService:
    """Speech-to-Text service using OpenAI Whisper"""
    
    def __init__(self):
        self.model = None
        self.model_name = settings.WHISPER_MODEL
    
    def _ensure_model_loaded(self):
        """Lazy load the Whisper model"""
        if self.model is None:
            print(f"Loading Whisper model: {self.model_name}")
            self.model = whisper.load_model(self.model_name)
            print(f"Whisper model {self.model_name} loaded successfully")
    
    def transcribe(self, audio_path: str) -> dict:
        """
        Transcribe audio file to text using Whisper.
        
        Args:
            audio_path: Path to the audio file
            
        Returns:
            dict: Contains 'text' and 'language' keys
        """
        try:
            self._ensure_model_loaded()
            
            result = self.model.transcribe(audio_path)
            
            return {
                "text": result["text"].strip(),
                "language": result.get("language", "en"),
                "segments": result.get("segments", [])
            }
        except Exception as e:
            print(f"STT transcription error: {e}")
            raise e
    
    def transcribe_bytes(self, audio_data: bytes, file_extension: str = ".mp3") -> dict:
        """
        Transcribe audio bytes to text.
        
        Args:
            audio_data: Audio file bytes
            file_extension: Extension of the audio file (e.g., '.mp3', '.wav')
            
        Returns:
            dict: Contains 'text' and 'language' keys
        """
        # Write to temp file for Whisper processing
        with tempfile.NamedTemporaryFile(suffix=file_extension, delete=False) as tmp_file:
            tmp_file.write(audio_data)
            tmp_path = tmp_file.name
        
        try:
            result = self.transcribe(tmp_path)
            return result
        finally:
            # Clean up temp file
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

stt_service = STTService()
