import psycopg2
from app.core.config import settings
import logging

logger = logging.getLogger(__name__)

class DBService:
    """Database service for STT job management"""
    
    def __init__(self):
        self.host = settings.DB_HOST
        self.port = settings.DB_PORT
        self.dbname = settings.DB_NAME
        self.user = settings.DB_USER
        self.password = settings.DB_PASSWORD

    def get_connection(self):
        """Get database connection"""
        try:
            conn = psycopg2.connect(
                host=self.host,
                port=self.port,
                dbname=self.dbname,
                user=self.user,
                password=self.password
            )
            return conn
        except Exception as e:
            logger.error(f"Failed to connect to DB: {e}")
            raise e

    def ensure_table_exists(self):
        """Ensure the stt_jobs table exists"""
        conn = None
        try:
            conn = self.get_connection()
            cur = conn.cursor()
            cur.execute("""
                CREATE TABLE IF NOT EXISTS stt_jobs (
                    id UUID PRIMARY KEY,
                    filename VARCHAR(255) NOT NULL,
                    audio_path VARCHAR(500),
                    status VARCHAR(50) DEFAULT 'pending',
                    text TEXT,
                    language VARCHAR(10),
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            conn.commit()
            logger.info("Ensured 'stt_jobs' table exists.")
        except Exception as e:
            logger.error(f"Error creating table: {e}")
            if conn:
                conn.rollback()
        finally:
            if conn:
                conn.close()

    def create_job(self, job_id: str, filename: str, audio_path: str = None):
        """Create a new STT job"""
        conn = None
        try:
            conn = self.get_connection()
            cur = conn.cursor()
            cur.execute("""
                INSERT INTO stt_jobs (id, filename, audio_path, status)
                VALUES (%s, %s, %s, 'pending')
            """, (job_id, filename, audio_path))
            conn.commit()
            logger.info(f"STT job {job_id} created.")
        except Exception as e:
            logger.error(f"Error creating STT job: {e}")
            if conn:
                conn.rollback()
            raise e
        finally:
            if conn:
                conn.close()

    def update_job_status(self, job_id: str, status: str, text: str = None, language: str = None):
        """Update a STT job status with transcription result"""
        conn = None
        try:
            conn = self.get_connection()
            cur = conn.cursor()
            if text is not None:
                cur.execute("""
                    UPDATE stt_jobs 
                    SET status = %s, text = %s, language = %s, updated_at = CURRENT_TIMESTAMP
                    WHERE id = %s
                """, (status, text, language, job_id))
            else:
                cur.execute("""
                    UPDATE stt_jobs 
                    SET status = %s, updated_at = CURRENT_TIMESTAMP
                    WHERE id = %s
                """, (status, job_id))
            conn.commit()
            logger.info(f"STT job {job_id} updated to status: {status}")
        except Exception as e:
            logger.error(f"Error updating STT job: {e}")
            if conn:
                conn.rollback()
            raise e
        finally:
            if conn:
                conn.close()

    def get_job(self, job_id: str) -> dict:
        """Get a STT job by ID"""
        conn = None
        try:
            conn = self.get_connection()
            cur = conn.cursor()
            cur.execute("""
                SELECT id, filename, audio_path, status, text, language, created_at, updated_at 
                FROM stt_jobs WHERE id = %s
            """, (job_id,))
            row = cur.fetchone()
            if row:
                return {
                    "id": str(row[0]),
                    "filename": row[1],
                    "audio_path": row[2],
                    "status": row[3],
                    "text": row[4],
                    "language": row[5],
                    "created_at": row[6],
                    "updated_at": row[7]
                }
            return None
        except Exception as e:
            logger.error(f"Error getting STT job: {e}")
            return None
        finally:
            if conn:
                conn.close()

db_service = DBService()
