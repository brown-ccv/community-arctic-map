# Multi-stage Dockerfile for Community Arctic Map
# This Dockerfile builds both the frontend and backend services

# =============================================================================
# Stage 1: Build Frontend (React + Vite)
# =============================================================================
FROM node:20-alpine AS frontend-builder

WORKDIR /app/frontend

# Copy frontend package files
COPY frontend/package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy frontend source code
COPY frontend/ ./

# Build frontend for production
# Note: Build-time environment variables must be provided during docker build
ARG VITE_MAPBOX_ACCESS_TOKEN
ARG VITE_API_BASE_URL=/api
ARG VITE_DOWNLOAD_API_URL=/api/download

ENV VITE_MAPBOX_ACCESS_TOKEN=${VITE_MAPBOX_ACCESS_TOKEN}
ENV VITE_API_BASE_URL=${VITE_API_BASE_URL}
ENV VITE_DOWNLOAD_API_URL=${VITE_DOWNLOAD_API_URL}

RUN npm run build

# =============================================================================
# Stage 2: Production Runtime with FastAPI
# =============================================================================
FROM python:3.12-slim

# Install system dependencies for geospatial libraries
RUN apt-get update && apt-get install -y \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy Python requirements and install dependencies
COPY backend/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend application code
COPY backend/ ./backend/

# Copy built frontend from builder stage
COPY --from=frontend-builder /app/frontend/dist ./frontend/dist

# Create directory for the SQLite database file
# This will be mounted as a volume in production
RUN mkdir -p /app/backend/data

# Install additional dependencies for serving static files
RUN pip install --no-cache-dir aiofiles

# Create a startup script that runs both FastAPI services
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Start zip_downloads service on port 8001 in background\n\
cd /app/backend\n\
uvicorn zip_downloads:app --host 0.0.0.0 --port 8001 &\n\
\n\
# Start main service with production config on PORT (provided by Cloud Run) or default 8080\n\
PORT=${PORT:-8080}\n\
uvicorn production:app --host 0.0.0.0 --port $PORT\n\
' > /app/start.sh && chmod +x /app/start.sh

# Expose port (Cloud Run will set the PORT environment variable)
EXPOSE 8080

# Set working directory to backend
WORKDIR /app/backend

# Run the startup script
CMD ["/app/start.sh"]
