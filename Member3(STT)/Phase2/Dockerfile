FROM python:3.11-slim

WORKDIR /app

# Install system dependencies including ffmpeg for audio processing
RUN apt-get update && apt-get install -y \
    libpq-dev \
    gcc \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for cache optimization
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create uploads directory
RUN mkdir -p uploads

# Expose port
EXPOSE 5000

# Run the application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "5000"]
