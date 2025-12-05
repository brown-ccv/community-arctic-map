#!/bin/bash
# ==============================================================================
# Community Arctic Map - Startup Script for Cloud Run
# ==============================================================================
# This script starts both FastAPI applications
# The main API (port 8080) serves both the frontend and backend APIs
# ==============================================================================

set -e

echo "🚀 Starting Community Arctic Map..."

# Get port from environment (Cloud Run provides this)
PORT=${PORT:-8080}

echo "📍 Configured port: $PORT"

# Check if data files exist
echo "🔍 Checking for required data files..."

if [ ! -f "${CPAD_SQLITE_PATH:-/app/data/cpad.sqlite}" ]; then
    echo "⚠️  Warning: cpad.sqlite not found"
    echo "   Expected at: ${CPAD_SQLITE_PATH:-/app/data/cpad.sqlite}"
fi

if [ ! -f "${METADATA_HTML_PATH:-/app/data/metadata.html}" ]; then
    echo "⚠️  Warning: metadata.html not found"
    echo "   Expected at: ${METADATA_HTML_PATH:-/app/data/metadata.html}"
fi

if [ ! -d "${ZIPPED_SHAPEFILES_PATH:-/app/data/zipped_shapefiles}" ]; then
    echo "⚠️  Warning: zipped_shapefiles directory not found"
    echo "   Expected at: ${ZIPPED_SHAPEFILES_PATH:-/app/data/zipped_shapefiles}"
fi

echo "✅ Starting services..."

# Change to backend directory
cd /app/backend

# Start main API (with frontend serving) on the main port
echo "🌐 Starting main API with frontend on port $PORT..."
uvicorn main:app --host 0.0.0.0 --port $PORT

