#!/bin/bash
# Arctic Map Application Startup Script
# This script is executed by the container to start all services

set -e  # Exit on error

echo "🔍 PREPARE PHASE: Starting Arctic Map Application"
echo "================================================="

# Check required files exist
if [ ! -f /app/backend/main.py ]; then
    echo "❌ ERROR: main.py not found"
    exit 1
fi

if [ ! -f /app/backend/zip_downloads.py ]; then
    echo "❌ ERROR: zip_downloads.py not found"
    exit 1
fi

if [ ! -d /app/frontend/dist ]; then
    echo "❌ ERROR: Frontend dist directory not found"
    exit 1
fi

echo "✅ All required files present"

# Check environment variables
if [ -z "$GOOGLE_SHEET_ID" ]; then
    echo "⚠️  WARNING: GOOGLE_SHEET_ID not set"
fi

if [ -z "$GOOGLE_SHEET_GID" ]; then
    echo "⚠️  WARNING: GOOGLE_SHEET_GID not set"
fi

if [ -z "$VITE_MAPBOX_ACCESS_TOKEN" ]; then
    echo "⚠️  WARNING: VITE_MAPBOX_ACCESS_TOKEN not set"
fi

echo ""
echo "🚀 DEPLOY PHASE: Launching Services"
echo "================================================="

# Start supervisor to manage all processes
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
