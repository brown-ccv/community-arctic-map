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

# Install system dependencies for geospatial libraries and Google Cloud SDK
RUN apt-get update && apt-get install -y \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    curl \
    gnupg \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - \
    && apt-get update && apt-get install -y google-cloud-cli \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy Python requirements and install dependencies
COPY backend/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend application code
COPY backend/ ./backend/

# Copy built frontend from builder stage
COPY --from=frontend-builder /app/frontend/dist ./frontend/dist

# Copy database download script and startup script
COPY .deployment/scripts/download-database.sh /app/scripts/download-database.sh
COPY .deployment/scripts/start.sh /app/start.sh
RUN chmod +x /app/scripts/download-database.sh /app/start.sh

# Create directory for the SQLite database file
# This will be populated by the download script at startup
RUN mkdir -p /app/backend

# Install additional dependencies for serving static files
RUN pip install --no-cache-dir aiofiles

# Expose port (Cloud Run will set the PORT environment variable)
EXPOSE 8080

# Set working directory to backend
WORKDIR /app/backend

# Run the startup script
CMD ["/app/start.sh"]
