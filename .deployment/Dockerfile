# Multi-stage Dockerfile for Arctic Map Application
# Builds both frontend and backend, serves via nginx proxy

# ============================================
# Stage 1: Build Frontend (React + Vite)
# ============================================
FROM node:20-alpine AS frontend-builder

WORKDIR /app/frontend

# Copy frontend package files
COPY frontend/package*.json ./

# Install dependencies (including dev dependencies needed for build)
RUN npm ci

# Copy frontend source
COPY frontend/ ./

# Build frontend (requires VITE_MAPBOX_ACCESS_TOKEN at build time)
ARG VITE_MAPBOX_ACCESS_TOKEN
ENV VITE_MAPBOX_ACCESS_TOKEN=${VITE_MAPBOX_ACCESS_TOKEN}
RUN npm run build

# ============================================
# Stage 2: Backend Runtime (Python + FastAPI)
# ============================================
FROM python:3.12-slim AS backend-runtime

WORKDIR /app

# Install system dependencies for geospatial libraries
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy backend requirements
COPY backend/requirements.txt ./

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend source
COPY backend/ ./backend/

# ============================================
# Stage 3: Nginx + Supervisor (Final Image)
# ============================================
FROM python:3.12-slim

WORKDIR /app

# Install nginx, supervisor, and geospatial libraries
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    supervisor \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy Python dependencies from backend-runtime stage
COPY --from=backend-runtime /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=backend-runtime /usr/local/bin/uvicorn /usr/local/bin/uvicorn

# Copy backend application
COPY --from=backend-runtime /app/backend ./backend

# Copy built frontend to nginx html directory
COPY --from=frontend-builder /app/frontend/dist /usr/share/nginx/html

# Copy nginx configuration
COPY .deployment/nginx.conf /etc/nginx/sites-available/default

# Copy supervisor configuration
COPY .deployment/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose port 8080 (Cloud Run requirement)
EXPOSE 8080

# Set environment variable for port
ENV PORT=8080

# Start supervisor to manage all services
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
