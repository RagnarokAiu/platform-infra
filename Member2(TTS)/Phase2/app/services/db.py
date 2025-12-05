import psycopg2
from app.core.config import settings
import logging

logger = logging.getLogger(__name__)

class DBService:
    """Database service for TTS job management"""
    
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
        """Ensure the tts_jobs table exists"""
        conn = None
        try:
            conn = self.get_connection()
            cur = conn.cursor()
            cur.execute("""
                CREATE TABLE IF NOT EXISTS tts_jobs (
                    id UUID PRIMARY KEY,
                    text TEXT NOT NULL,
                    language VARCHAR(10) DEFAULT 'en',
                    status VARCHAR(50) DEFAULT 'pending',
                    audio_path VARCHAR(500),
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            conn.commit()
            logger.info("Ensured 'tts_jobs' table exists.")
        except Exception as e:
            logger.error(f"Error creating table: {e}")
            if conn:
                conn.rollback()
        finally:
            if conn:
                conn.close()

    def create_job(self, job_id: str, text: str, language: str = "en"):
        """Create a new TTS job"""
        conn = None
        try:
            conn = self.get_connection()
            cur = conn.cursor()
            cur.execute("""
                INSERT INTO tts_jobs (id, text, language, status)
                VALUES (%s, %s, %s, 'pending')
            """, (job_id, text, language))
            conn.commit()
            logger.info(f"TTS job {job_id} created.")
        except Exception as e:
            logger.error(f"Error creating TTS job: {e}")
            if conn:
                conn.rollback()
            raise e
        finally:
            if conn:
                conn.close()

    def update_job_status(self, job_id: str, status: str, audio_path: str = None):
        """Update a TTS job status"""
        conn = None
        try:
            conn = self.get_connection()
            cur = conn.cursor()
            if audio_path:
                cur.execute("""
                    UPDATE tts_jobs 
                    SET status = %s, audio_path = %s, updated_at = CURRENT_TIMESTAMP
                    WHERE id = %s
                """, (status, audio_path, job_id))
            else:
                cur.execute("""
                    UPDATE tts_jobs 
                    SET status = %s, updated_at = CURRENT_TIMESTAMP
                    WHERE id = %s
                """, (status, job_id))
            conn.commit()
            logger.info(f"TTS job {job_id} updated to status: {status}")
        except Exception as e:
            logger.error(f"Error updating TTS job: {e}")
            if conn:
                conn.rollback()
            raise e
        finally:
            if conn:
                conn.close()

    def get_job(self, job_id: str) -> dict:
        """Get a TTS job by ID"""
        conn = None
        try:
            conn = self.get_connection()
            cur = conn.cursor()
            cur.execute("""
                SELECT id, text, language, status, audio_path, created_at, updated_at 
                FROM tts_jobs WHERE id = %s
            """, (job_id,))
            row = cur.fetchone()
            if row:
                return {
                    "id": str(row[0]),
                    "text": row[1],
                    "language": row[2],
                    "status": row[3],
                    "audio_path": row[4],
                    "created_at": row[5],
                    "updated_at": row[6]
                }
            return None
        except Exception as e:
            logger.error(f"Error getting TTS job: {e}")
            return None
        finally:
            if conn:
                conn.close()

db_service = DBService()
