#!/bin/bash
# Arctic Map - Deployment Script for Google Cloud Run
# This script deploys the Arctic Map application to Google Cloud Run

set -e  # Exit on error
set -u  # Exit on undefined variable
set -o pipefail  # Exit on pipe failure

### 🔍 PREPARE PHASE ###
echo "=========================================="
echo "🔍 PREPARE PHASE: Pre-deployment validation"
echo "=========================================="

# Validate required environment variables
if [ -z "${PROJECT_ID:-}" ]; then
    echo "❌ ERROR: PROJECT_ID environment variable is not set"
    echo "Please set it with: export PROJECT_ID=your-gcp-project-id"
    exit 1
fi

if [ -z "${REGION:-}" ]; then
    echo "⚠️  WARNING: REGION not set, using default 'us-central1'"
    REGION="us-central1"
fi

if [ -z "${SERVICE_NAME:-}" ]; then
    echo "⚠️  WARNING: SERVICE_NAME not set, using default 'arctic-map'"
    SERVICE_NAME="arctic-map"
fi

if [ -z "${IMAGE_NAME:-}" ]; then
    echo "⚠️  WARNING: IMAGE_NAME not set, using default 'arctic-map'"
    IMAGE_NAME="arctic-map"
fi

if [ -z "${IMAGE_TAG:-}" ]; then
    echo "⚠️  WARNING: IMAGE_TAG not set, using default 'latest'"
    IMAGE_TAG="latest"
fi

# Validate required secrets
if [ -z "${GOOGLE_SHEET_ID:-}" ]; then
    echo "❌ ERROR: GOOGLE_SHEET_ID environment variable is not set"
    echo "This is required for the application to function."
    exit 1
fi

if [ -z "${GOOGLE_SHEET_GID:-}" ]; then
    echo "❌ ERROR: GOOGLE_SHEET_GID environment variable is not set"
    echo "This is required for the application to function."
    exit 1
fi

# Validate gcloud is installed and authenticated
if ! command -v gcloud &> /dev/null; then
    echo "❌ ERROR: gcloud CLI is not installed"
    echo "Install from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check authentication
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo "❌ ERROR: No active gcloud authentication found"
    echo "Please run: gcloud auth login"
    exit 1
fi

# Set the project
gcloud config set project "${PROJECT_ID}"

echo "✅ All prerequisites validated"
echo ""

### 🚀 DEPLOY PHASE ###
echo "=========================================="
echo "🚀 DEPLOY PHASE: Deploying to Cloud Run"
echo "=========================================="

# Set full image path
FULL_IMAGE_PATH="gcr.io/${PROJECT_ID}/${IMAGE_NAME}:${IMAGE_TAG}"
echo "📦 Image: ${FULL_IMAGE_PATH}"
echo "🌍 Region: ${REGION}"
echo "🏷️  Service: ${SERVICE_NAME}"
echo ""

# Check if image exists
if ! gcloud container images describe "${FULL_IMAGE_PATH}" &> /dev/null; then
    echo "❌ ERROR: Image ${FULL_IMAGE_PATH} not found in GCR"
    echo "Please build and push the image first using build.sh"
    exit 1
fi

# Deploy to Cloud Run
echo "🚀 Deploying to Cloud Run..."
gcloud run deploy "${SERVICE_NAME}" \
    --image="${FULL_IMAGE_PATH}" \
    --platform=managed \
    --region="${REGION}" \
    --allow-unauthenticated \
    --port=8080 \
    --memory=2Gi \
    --cpu=2 \
    --timeout=300 \
    --max-instances=10 \
    --min-instances=0 \
    --set-env-vars="GOOGLE_SHEET_ID=${GOOGLE_SHEET_ID},GOOGLE_SHEET_GID=${GOOGLE_SHEET_GID}"

if [ $? -eq 0 ]; then
    echo "✅ Deployment successful"
else
    echo "❌ ERROR: Deployment failed"
    exit 1
fi

# Get service URL
SERVICE_URL=$(gcloud run services describe "${SERVICE_NAME}" \
    --region="${REGION}" \
    --format="value(status.url)")

### 🧹 TEARDOWN PHASE ###
echo "=========================================="
echo "🧹 TEARDOWN PHASE: Post-deployment validation"
echo "=========================================="

# Test the service (with retry for cold start)
echo "🔍 Testing service health (waiting for cold start)..."
MAX_RETRIES=6
RETRY_DELAY=5

for i in $(seq 1 $MAX_RETRIES); do
    if curl -sf "${SERVICE_URL}" > /dev/null; then
        echo "✅ Service is responding"
        break
    else
        if [ $i -lt $MAX_RETRIES ]; then
            echo "⏳ Attempt $i/$MAX_RETRIES failed, retrying in ${RETRY_DELAY}s..."
            sleep $RETRY_DELAY
        else
            echo "⚠️  WARNING: Service health check failed after $MAX_RETRIES attempts"
            echo "Please check the service logs with:"
            echo "gcloud run services logs read ${SERVICE_NAME} --region=${REGION}"
        fi
    fi
done

echo ""
echo "=========================================="
echo "✅ DEPLOYMENT COMPLETE"
echo "=========================================="
echo "Service URL: ${SERVICE_URL}"
echo ""
echo "Useful commands:"
echo "  View logs: gcloud run services logs read ${SERVICE_NAME} --region=${REGION} --limit=50"
echo "  Check status: gcloud run services describe ${SERVICE_NAME} --region=${REGION}"
echo "  Update env vars: gcloud run services update ${SERVICE_NAME} --region=${REGION} --update-env-vars KEY=VALUE"
echo "=========================================="
