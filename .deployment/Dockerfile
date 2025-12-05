# ==============================================================================
# Community Arctic Map - Multi-Stage Dockerfile for Google Cloud Run
# ==============================================================================
# This Dockerfile builds a production-ready container that:
# 1. Builds the React frontend with environment variables
# 2. Installs Python backend with GIS dependencies (including g++ for fiona)
# 3. Serves frontend static files and backend APIs from a single container
# 
# Architecture:
# - Backend: FastAPI (main.py on port 8000, zip_downloads.py on port 8001)
# - Frontend: React + Vite (served as static files from backend)
# - Combined service listens on $PORT (Cloud Run default: 8080)
# ==============================================================================

# ==============================================================================
# Stage 1: Build Frontend
# ==============================================================================
FROM node:20-alpine AS frontend-builder

WORKDIR /frontend

# Copy package files and install dependencies
COPY frontend/package*.json ./
RUN npm ci --only=production

# Copy frontend source
COPY frontend/ ./

# Build arguments for environment variables (passed during build)
ARG VITE_MAPBOX_ACCESS_TOKEN
ARG VITE_BACKEND_API_URL
ARG VITE_DOWNLOAD_API_URL

# Set environment variables for Vite build
ENV VITE_MAPBOX_ACCESS_TOKEN=${VITE_MAPBOX_ACCESS_TOKEN}
ENV VITE_BACKEND_API_URL=${VITE_BACKEND_API_URL}
ENV VITE_DOWNLOAD_API_URL=${VITE_DOWNLOAD_API_URL}

# Build the frontend
RUN npm run build

# ==============================================================================
# Stage 2: Production Backend with Frontend
# ==============================================================================
FROM python:3.12-slim

# Install system dependencies required for GIS libraries
# - g++: Required for building fiona from source
# - libgdal-dev: GDAL library for geospatial operations
# - build-essential: General build tools
RUN apt-get update && apt-get install -y \
    g++ \
    gcc \
    libgdal-dev \
    gdal-bin \
    libproj-dev \
    libgeos-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy backend requirements and install Python dependencies
COPY backend/requirements.txt ./backend/
RUN pip install --no-cache-dir -r backend/requirements.txt

# Copy backend source code
COPY backend/ ./backend/

# Copy built frontend from Stage 1
COPY --from=frontend-builder /frontend/dist ./frontend/dist

# Create directories for data files
RUN mkdir -p /app/data /app/backend/bundled_zips

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PORT=8080

# Expose port (Cloud Run will override with $PORT)
EXPOSE 8080

# Health check (optional but recommended)
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health').read()" || exit 1

# Copy and use startup script
COPY .deployment/scripts/start.sh /app/start.sh
RUN chmod +x /app/start.sh

CMD ["/app/start.sh"]
