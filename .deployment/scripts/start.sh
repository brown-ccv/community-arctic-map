#!/bin/bash
# ==============================================================================
# Community Arctic Map - Startup Script for Cloud Run
# ==============================================================================
# This script starts both FastAPI applications and serves the frontend
# ==============================================================================

set -e

echo "🚀 Starting Community Arctic Map..."

# Get port from environment (Cloud Run provides this)
PORT=${PORT:-8080}
BACKEND_PORT=8000
DOWNLOAD_PORT=8001

echo "📍 Configured ports:"
echo "   Main service: $PORT"
echo "   Backend API: $BACKEND_PORT"
echo "   Download API: $DOWNLOAD_PORT"

# Check if data files exist
echo "🔍 Checking for required data files..."

if [ ! -f "/app/data/cpad.sqlite" ]; then
    echo "⚠️  Warning: cpad.sqlite not found at /app/data/cpad.sqlite"
    echo "   This file should be mounted from Cloud Storage"
fi

if [ ! -f "/app/data/metadata.html" ]; then
    echo "⚠️  Warning: metadata.html not found at /app/data/metadata.html"
    echo "   This file should be mounted from Cloud Storage or included in deployment"
fi

if [ ! -d "/app/data/zipped_shapefiles" ]; then
    echo "⚠️  Warning: zipped_shapefiles directory not found at /app/data/zipped_shapefiles"
    echo "   This directory should be mounted from Cloud Storage"
fi

echo "✅ Starting services..."

# Change to backend directory
cd /app/backend

# Start main API (main.py) in background on port 8000
echo "🔧 Starting main API on port $BACKEND_PORT..."
uvicorn main:app --host 0.0.0.0 --port $BACKEND_PORT &
MAIN_PID=$!

# Start download API (zip_downloads.py) in background on port 8001
echo "📦 Starting download API on port $DOWNLOAD_PORT..."
uvicorn zip_downloads:app --host 0.0.0.0 --port $DOWNLOAD_PORT &
DOWNLOAD_PID=$!

# Start combined gateway that serves frontend and proxies to backend APIs
echo "🌐 Starting gateway on port $PORT..."
cd /app
uvicorn gateway:app --host 0.0.0.0 --port $PORT &
GATEWAY_PID=$!

# Wait for all processes
echo "✅ All services started successfully!"
echo "   Main API PID: $MAIN_PID"
echo "   Download API PID: $DOWNLOAD_PID"
echo "   Gateway PID: $GATEWAY_PID"

# Function to handle shutdown
shutdown() {
    echo "🛑 Shutting down services..."
    kill $MAIN_PID $DOWNLOAD_PID $GATEWAY_PID 2>/dev/null
    exit 0
}

trap shutdown SIGTERM SIGINT

# Wait for any process to exit
wait -n

# Exit with status of process that exited first
exit $?
