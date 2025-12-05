from gtts import gTTS
import io
import os
from app.core.config import settings

class TTSService:
    """Text-to-Speech service using gTTS (Google Text-to-Speech)"""
    
    def synthesize(self, text: str, lang: str = 'en') -> bytes:
        """
        Convert text to speech and return audio bytes.
        
        Args:
            text: The text to convert to speech
            lang: Language code (default: 'en')
            
        Returns:
            bytes: MP3 audio data
        """
        try:
            tts = gTTS(text=text, lang=lang)
            audio_buffer = io.BytesIO()
            tts.write_to_fp(audio_buffer)
            audio_buffer.seek(0)
            return audio_buffer.getvalue()
        except Exception as e:
            print(f"TTS synthesis error: {e}")
            raise e
    
    def synthesize_to_file(self, text: str, output_path: str, lang: str = 'en') -> str:
        """
        Convert text to speech and save to a file.
        
        Args:
            text: The text to convert to speech
            output_path: Path to save the audio file
            lang: Language code (default: 'en')
            
        Returns:
            str: Path to the saved audio file
        """
        try:
            tts = gTTS(text=text, lang=lang)
            tts.save(output_path)
            return output_path
        except Exception as e:
            print(f"TTS synthesis to file error: {e}")
            raise e

tts_service = TTSService()
