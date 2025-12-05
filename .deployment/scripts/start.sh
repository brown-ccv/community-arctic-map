#!/bin/bash
# Startup script for Community Arctic Map on Cloud Run
# This script:
# 1. Downloads the database file from Cloud Storage if needed
# 2. Starts the zip_downloads service on port 8001
# 3. Starts the main API service on the PORT provided by Cloud Run

set -e

echo "=============================================="
echo "Community Arctic Map - Startup"
echo "=============================================="

# Download database if needed
echo "[INFO] Checking for database file..."
if [ -x /app/scripts/download-database.sh ]; then
    if /app/scripts/download-database.sh; then
        echo "[INFO] Database ready"
    else
        echo "[ERROR] Database download failed"
        echo "[ERROR] Application may not function correctly without the database"
        # Continue anyway - let the application handle the missing database
        # The application will fail on first request if database is truly required
    fi
else
    echo "[WARNING] Database download script not found"
    echo "[WARNING] Application may not function correctly without the database"
fi

# Change to backend directory
cd /app/backend

# Start zip_downloads service on port 8001 in background
echo "[INFO] Starting zip_downloads service on port 8001..."
uvicorn zip_downloads:app --host 0.0.0.0 --port 8001 &
ZIP_PID=$!
echo "[INFO] zip_downloads service started (PID: $ZIP_PID)"

# Start main service with production config on PORT (provided by Cloud Run) or default 8080
PORT=${PORT:-8080}
echo "[INFO] Starting main service on port $PORT..."
exec uvicorn production:app --host 0.0.0.0 --port $PORT

# Note: exec replaces the shell with uvicorn, so this line is never reached
# If the main service exits, the container will stop
