import os
import shutil
import boto3
from botocore.exceptions import NoCredentialsError
from app.core.config import settings

class StorageService:
    def __init__(self):
        self.type = settings.STORAGE_TYPE
        self.local_path = settings.LOCAL_STORAGE_PATH
        self.bucket_name = settings.TTS_BUCKET
        
        if self.type == "local":
            os.makedirs(self.local_path, exist_ok=True)
        elif self.type == "s3":
            self.s3 = boto3.client(
                's3',
                aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
                aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
                aws_session_token=settings.AWS_SESSION_TOKEN,
                region_name=settings.AWS_DEFAULT_REGION
            )
    
    async def upload_audio(self, audio_data: bytes, filename: str) -> str:
        """
        Upload audio data to storage (local or S3).
        
        Args:
            audio_data: The audio bytes to upload
            filename: The filename to save as
            
        Returns:
            str: Path or URL to the saved file
        """
        if self.type == "local":
            file_path = os.path.join(self.local_path, filename)
            with open(file_path, "wb") as f:
                f.write(audio_data)
            return file_path
        elif self.type == "s3":
            try:
                import io
                self.s3.upload_fileobj(
                    io.BytesIO(audio_data), 
                    self.bucket_name, 
                    filename,
                    ExtraArgs={'ContentType': 'audio/mpeg'}
                )
                return f"s3://{self.bucket_name}/{filename}"
            except NoCredentialsError:
                print("S3 Credentials not available")
                raise Exception("S3 Credentials missing")
        return ""
    
    async def get_audio(self, filename: str) -> bytes:
        """
        Retrieve audio data from storage.
        
        Args:
            filename: The filename to retrieve
            
        Returns:
            bytes: The audio data
        """
        if self.type == "local":
            file_path = os.path.join(self.local_path, filename)
            if os.path.exists(file_path):
                with open(file_path, "rb") as f:
                    return f.read()
            raise FileNotFoundError(f"Audio file not found: {filename}")
        elif self.type == "s3":
            try:
                import io
                buffer = io.BytesIO()
                self.s3.download_fileobj(self.bucket_name, filename, buffer)
                buffer.seek(0)
                return buffer.read()
            except Exception as e:
                print(f"S3 download error: {e}")
                raise e
        return b""
    
    def get_signed_url(self, filename: str, expiration: int = 3600) -> str:
        """
        Generate a pre-signed URL for S3 audio file.
        
        Args:
            filename: The filename in S3
            expiration: URL expiration in seconds (default: 1 hour)
            
        Returns:
            str: Pre-signed URL or empty string for local storage
        """
        if self.type == "s3":
            try:
                url = self.s3.generate_presigned_url(
                    'get_object',
                    Params={'Bucket': self.bucket_name, 'Key': filename},
                    ExpiresIn=expiration
                )
                return url
            except Exception as e:
                print(f"Error generating signed URL: {e}")
                return ""
        return ""

storage_service = StorageService()
