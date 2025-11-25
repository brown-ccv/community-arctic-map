#!/bin/bash
# Arctic Map - Build Script for Google Cloud Run Deployment
# This script builds and pushes the Docker image to Google Container Registry

set -e  # Exit on error
set -u  # Exit on undefined variable
set -o pipefail  # Exit on pipe failure

### 🔍 PREPARE PHASE ###
echo "=========================================="
echo "🔍 PREPARE PHASE: Pre-build validation"
echo "=========================================="

# Validate required environment variables
if [ -z "${PROJECT_ID:-}" ]; then
    echo "❌ ERROR: PROJECT_ID environment variable is not set"
    echo "Please set it with: export PROJECT_ID=your-gcp-project-id"
    exit 1
fi

if [ -z "${IMAGE_NAME:-}" ]; then
    echo "⚠️  WARNING: IMAGE_NAME not set, using default 'arctic-map'"
    IMAGE_NAME="arctic-map"
fi

if [ -z "${IMAGE_TAG:-}" ]; then
    echo "⚠️  WARNING: IMAGE_TAG not set, using default 'latest'"
    IMAGE_TAG="latest"
fi

if [ -z "${VITE_MAPBOX_ACCESS_TOKEN:-}" ]; then
    echo "❌ ERROR: VITE_MAPBOX_ACCESS_TOKEN environment variable is not set"
    echo "This is required to build the frontend. Get your token from: https://account.mapbox.com/access-tokens/"
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

# Validate Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ ERROR: Docker is not installed"
    echo "Install from: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo "❌ ERROR: Docker daemon is not running"
    echo "Please start Docker and try again"
    exit 1
fi

echo "✅ All prerequisites validated"
echo ""

### 🚀 DEPLOY PHASE ###
echo "=========================================="
echo "🚀 DEPLOY PHASE: Building and pushing image"
echo "=========================================="

# Set full image path
FULL_IMAGE_PATH="gcr.io/${PROJECT_ID}/${IMAGE_NAME}:${IMAGE_TAG}"
echo "📦 Image path: ${FULL_IMAGE_PATH}"
echo ""

# Configure Docker to use gcloud as a credential helper
echo "🔐 Configuring Docker authentication..."
gcloud auth configure-docker gcr.io --quiet

# Build the Docker image with build argument
echo "🔨 Building Docker image..."
docker build \
    --build-arg VITE_MAPBOX_ACCESS_TOKEN="${VITE_MAPBOX_ACCESS_TOKEN}" \
    -t "${FULL_IMAGE_PATH}" \
    -f .deployment/Dockerfile \
    .

if [ $? -eq 0 ]; then
    echo "✅ Docker image built successfully"
else
    echo "❌ ERROR: Docker build failed"
    exit 1
fi

# Push the image to GCR
echo "📤 Pushing image to Google Container Registry..."
docker push "${FULL_IMAGE_PATH}"

if [ $? -eq 0 ]; then
    echo "✅ Image pushed successfully"
else
    echo "❌ ERROR: Failed to push image to GCR"
    exit 1
fi

### 🧹 TEARDOWN PHASE ###
echo "=========================================="
echo "🧹 TEARDOWN PHASE: Cleanup"
echo "=========================================="

# Optional: Remove local image to save space
read -p "Do you want to remove the local Docker image to free up space? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker rmi "${FULL_IMAGE_PATH}"
    echo "✅ Local image removed"
else
    echo "ℹ️  Local image retained"
fi

echo ""
echo "=========================================="
echo "✅ BUILD COMPLETE"
echo "=========================================="
echo "Image: ${FULL_IMAGE_PATH}"
echo ""
echo "Next steps:"
echo "1. Deploy to Cloud Run using deploy.sh"
echo "2. Or manually: gcloud run deploy arctic-map --image ${FULL_IMAGE_PATH} --platform managed"
echo "=========================================="
