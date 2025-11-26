# Multi-stage Dockerfile for Arctic Map Application
# This container runs:
# 1. Frontend (React/Vite) served via Nginx
# 2. Backend API (FastAPI main.py) on port 8000
# 3. Download service (FastAPI zip_downloads.py) on port 8001

# ============================================
# Stage 1: Build Frontend
# ============================================
FROM node:20-alpine AS frontend-builder

WORKDIR /app/frontend

# Copy frontend package files
COPY frontend/package*.json ./

# Install dependencies
RUN npm ci --production=false

# Copy frontend source code
COPY frontend/ ./

# Build frontend for production
RUN npm run build

# ============================================
# Stage 2: Runtime Container
# ============================================
FROM python:3.12-slim

# Install system dependencies for geospatial libraries and nginx
RUN apt-get update && apt-get install -y \
    gdal-bin \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    nginx \
    supervisor \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables for GDAL
ENV GDAL_CONFIG=/usr/bin/gdal-config
ENV CPLUS_INCLUDE_PATH=/usr/include/gdal
ENV C_INCLUDE_PATH=/usr/include/gdal

WORKDIR /app

# Copy backend requirements and install Python dependencies
COPY backend/requirements.txt ./backend/
RUN pip install --no-cache-dir -r backend/requirements.txt

# Copy backend application code
COPY backend/ ./backend/

# Copy built frontend from builder stage
COPY --from=frontend-builder /app/frontend/dist ./frontend/dist

# Configure Nginx
RUN rm /etc/nginx/sites-enabled/default
COPY .deployment/nginx.conf /etc/nginx/sites-available/arctic-map
RUN ln -s /etc/nginx/sites-available/arctic-map /etc/nginx/sites-enabled/

# Configure Supervisor to manage processes
COPY .deployment/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Create necessary directories
RUN mkdir -p /var/log/supervisor \
    /app/backend/bundled_zips \
    && chmod -R 755 /app

# Expose port for Cloud Run (Nginx will listen on this port)
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Start supervisor to manage all services
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
