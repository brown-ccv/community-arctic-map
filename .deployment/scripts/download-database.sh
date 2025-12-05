#!/bin/bash
# Database download script for Cloud Run
# Downloads cpad.sqlite from Cloud Storage if not present

set -e

DATABASE_PATH="/app/backend/cpad.sqlite"
BUCKET_NAME="${GCS_BUCKET_NAME:-${GCP_PROJECT_ID}-community-arctic-map-data}"
OBJECT_PATH="cpad.sqlite"

# Check if database already exists
if [ -f "$DATABASE_PATH" ]; then
    echo "[INFO] Database file already exists at $DATABASE_PATH"
    FILE_SIZE=$(du -h "$DATABASE_PATH" | cut -f1)
    echo "[INFO] Database size: $FILE_SIZE"
    exit 0
fi

# Check if gsutil is available
if ! command -v gsutil &> /dev/null; then
    echo "[WARNING] gsutil not found, skipping database download"
    echo "[WARNING] Application will fail if database is required"
    exit 0
fi

# Download database from Cloud Storage
echo "[INFO] Downloading database from gs://${BUCKET_NAME}/${OBJECT_PATH}..."
echo "[INFO] This may take several minutes for a 4.3GB file..."

if gsutil -q stat "gs://${BUCKET_NAME}/${OBJECT_PATH}" 2>/dev/null; then
    gsutil cp "gs://${BUCKET_NAME}/${OBJECT_PATH}" "$DATABASE_PATH"
    echo "[INFO] Database downloaded successfully"
    FILE_SIZE=$(du -h "$DATABASE_PATH" | cut -f1)
    echo "[INFO] Database size: $FILE_SIZE"
else
    echo "[ERROR] Database not found at gs://${BUCKET_NAME}/${OBJECT_PATH}"
    echo "[ERROR] Please upload the database file with:"
    echo "[ERROR]   gsutil cp backend/cpad.sqlite gs://${BUCKET_NAME}/${OBJECT_PATH}"
    exit 1
fi
