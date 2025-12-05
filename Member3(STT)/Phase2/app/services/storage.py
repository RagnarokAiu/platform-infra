import os
import shutil
import boto3
from botocore.exceptions import NoCredentialsError
from app.core.config import settings

class StorageService:
    def __init__(self):
        self.type = settings.STORAGE_TYPE
        self.local_path = settings.LOCAL_STORAGE_PATH
        self.bucket_name = settings.STT_BUCKET
        
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
    
    async def upload_audio(self, file, filename: str) -> str:
        """
        Upload audio file to storage (local or S3).
        
        Args:
            file: The uploaded file object
            filename: The filename to save as
            
        Returns:
            str: Path or URL to the saved file
        """
        if self.type == "local":
            file_path = os.path.join(self.local_path, filename)
            with open(file_path, "wb") as buffer:
                shutil.copyfileobj(file.file, buffer)
            return file_path
        elif self.type == "s3":
            try:
                self.s3.upload_fileobj(
                    file.file, 
                    self.bucket_name, 
                    filename
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
    
    def get_local_path(self, filename: str) -> str:
        """
        Get local file path for processing.
        For S3, downloads to temp location.
        
        Args:
            filename: The filename
            
        Returns:
            str: Local file path
        """
        if self.type == "local":
            return os.path.join(self.local_path, filename)
        elif self.type == "s3":
            import tempfile
            local_path = os.path.join(tempfile.gettempdir(), filename)
            self.s3.download_file(self.bucket_name, filename, local_path)
            return local_path
        return ""

storage_service = StorageService()
