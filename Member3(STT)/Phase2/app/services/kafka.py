from kafka import KafkaProducer
from kafka.errors import NoBrokersAvailable
import json
from app.core.config import settings

class KafkaService:
    """Kafka service for STT event streaming"""
    
    def __init__(self):
        self.bootstrap_servers = settings.KAFKA_BOOTSTRAP_SERVERS
        self.producer = None
        self._init_producer()
    
    def _init_producer(self):
        """Initialize Kafka producer (gracefully handle connection errors)"""
        try:
            self.producer = KafkaProducer(
                bootstrap_servers=self.bootstrap_servers,
                value_serializer=lambda v: json.dumps(v).encode('utf-8')
            )
        except NoBrokersAvailable:
            print(f"Warning: Kafka broker not available at {self.bootstrap_servers}")
            self.producer = None
    
    def produce_event(self, topic: str, data: dict):
        """
        Produce an event to a Kafka topic.
        
        Args:
            topic: The Kafka topic to publish to
            data: The event data (will be JSON serialized)
        """
        if self.producer is None:
            print(f"Kafka not connected. Would send to {topic}: {data}")
            return
            
        try:
            self.producer.send(topic, data)
            self.producer.flush()
            print(f"Message sent to {topic}")
        except Exception as e:
            print(f"Failed to produce message: {e}")
    
    def produce_transcription_completed(self, job_id: str, text: str, language: str, status: str = "completed"):
        """
        Produce audio.transcription.completed event.
        
        Args:
            job_id: The STT job ID
            text: The transcribed text
            language: Detected language
            status: Job status
        """
        self.produce_event("audio.transcription.completed", {
            "job_id": job_id,
            "text": text,
            "language": language,
            "status": status
        })
    
    def flush(self):
        """Flush pending messages"""
        if self.producer:
            self.producer.flush()

kafka_service = KafkaService()
