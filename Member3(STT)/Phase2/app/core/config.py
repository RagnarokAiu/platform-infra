import os
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    PROJECT_NAME: str = "STT Service"
    API_V1_STR: str = "/api"
    
    # Storage
    STORAGE_TYPE: str = "s3"  # or "local"
    LOCAL_STORAGE_PATH: str = "uploads"

    # Kafka
    KAFKA_BOOTSTRAP_SERVERS: str = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "10.0.10.10:9092")

    # Database
    DB_HOST: str = os.getenv("DB_HOST", "127.0.0.1")
    DB_PORT: str = os.getenv("DB_PORT", "5432")
    DB_NAME: str = os.getenv("DB_NAME", "postgres")
    DB_USER: str = os.getenv("DB_USER", "dbadmin")
    DB_PASSWORD: str = os.getenv("DB_PASSWORD", "password123")

    # AWS Credentials
    AWS_ACCESS_KEY_ID: str = os.getenv("AWS_ACCESS_KEY_ID", "")
    AWS_SECRET_ACCESS_KEY: str = os.getenv("AWS_SECRET_ACCESS_KEY", "")
    AWS_SESSION_TOKEN: str = os.getenv("AWS_SESSION_TOKEN", "")
    AWS_DEFAULT_REGION: str = os.getenv("AWS_DEFAULT_REGION", "us-east-1")
    
    # STT S3 Bucket
    STT_BUCKET: str = os.getenv("STT_BUCKET", "hydra-speech-to-text-hgpb5g")
    
    # Whisper Model Size (tiny, base, small, medium, large)
    WHISPER_MODEL: str = os.getenv("WHISPER_MODEL", "base")

    model_config = SettingsConfigDict(case_sensitive=True, env_file=".env", extra="ignore")

settings = Settings()
