# Arctic Map Application - Google Cloud Run Deployment Guide

This document provides comprehensive, AI-agent-compatible deployment instructions for deploying the Arctic Map application to Google Cloud Run.

## 📋 Table of Contents
1. [Application Architecture](#application-architecture)
2. [Prerequisites](#prerequisites)
3. [Phase 1: 🔍 PREPARE - Environment Setup](#phase-1--prepare---environment-setup)
4. [Phase 2: 🚀 DEPLOY - Build and Deploy](#phase-2--deploy---build-and-deploy)
5. [Phase 3: 🧹 TEARDOWN - Cleanup and Rollback](#phase-3--teardown---cleanup-and-rollback)
6. [Environment Variables Reference](#environment-variables-reference)
7. [Troubleshooting](#troubleshooting)

---

## Application Architecture

The Arctic Map application consists of:
- **Frontend**: React + Vite SPA served by Nginx
- **Backend API (Port 8000)**: FastAPI service for GIS operations (`main.py`)
- **Download Service (Port 8001)**: FastAPI service for shapefile downloads (`zip_downloads.py`)
- **Nginx**: Reverse proxy serving frontend and routing API requests

All services run in a single Docker container managed by supervisord.

**Container Port**: 8080 (Cloud Run listens on this port)

---

## Prerequisites

**👋 HUMAN INTERVENTION REQUIRED:** Complete ALL prerequisites before proceeding with deployment.

### Required Services and Tools

1. **Google Cloud Project**
   - Active GCP project with billing enabled
   - Project ID noted (replace `YOUR_PROJECT_ID` in all commands)

2. **Local Development Tools**
   ```bash
   # Verify installations
   docker --version          # Docker 20.10+
   gcloud --version         # Google Cloud SDK
   git --version            # Git
   ```

3. **GCP Authentication**
   ```bash
   # Login to Google Cloud
   gcloud auth login
   
   # Set your project
   gcloud config set project YOUR_PROJECT_ID
   
   # Configure Docker to use gcloud credentials
   gcloud auth configure-docker
   ```

4. **Enable Required APIs**
   ```bash
   # Enable Cloud Run API
   gcloud services enable run.googleapis.com
   
   # Enable Container Registry API
   gcloud services enable containerregistry.googleapis.com
   
   # Enable Cloud Build API (optional, for CI/CD)
   gcloud services enable cloudbuild.googleapis.com
   
   # Verify APIs are enabled
   gcloud services list --enabled | grep -E "(run|containerregistry|cloudbuild)"
   ```
   **Expected output**: Should show all three services listed as enabled

5. **Required Application Files**
   - `backend/cpad.sqlite`: SQLite database with spatial layers (NOT in git, must be provided)
   - `backend/metadata.html`: HTML metadata file (NOT in git, must be provided)
   - `backend/zipped_shapefiles/`: Directory with zipped shapefiles (NOT in git, must be provided)

### Required Secrets

**👋 HUMAN INTERVENTION REQUIRED:** Obtain and store these secrets securely:

1. **Mapbox Access Token**
   - Obtain from: https://account.mapbox.com/access-tokens/
   - Scope: `styles:read`, `fonts:read`, `geocoding:read`

2. **Google Sheet Credentials**
   - Google Sheet ID: From spreadsheet URL
   - Google Sheet GID: From sheet tab URL parameter

---

## Phase 1: 🔍 PREPARE - Environment Setup

### Step 1.1: Clone Repository and Verify Files

```bash
# Clone the repository
git clone https://github.com/brown-ccv/arctic-map.git
cd arctic-map

# Verify directory structure
ls -la backend/ frontend/ .deployment/

# Check for .deployment directory
test -d .deployment && echo "✅ .deployment directory exists" || echo "❌ .deployment directory missing"
```

**Expected Output**: Should see backend/, frontend/, and .deployment/ directories

**HALT DIRECTIVE**: If .deployment/ directory is missing, STOP. The deployment files have not been created yet.

### Step 1.2: Add Required Application Files

**👋 HUMAN INTERVENTION REQUIRED:** Copy the following files to the repository:

```bash
# Create directory for zipped shapefiles if it doesn't exist
mkdir -p backend/zipped_shapefiles
mkdir -p backend/bundled_zips

# Copy your files (replace SOURCE paths with your actual file locations)
# Example:
# cp /path/to/your/cpad.sqlite backend/cpad.sqlite
# cp /path/to/your/metadata.html backend/metadata.html
# cp /path/to/your/shapefiles/*.zip backend/zipped_shapefiles/

# Verify files are present
test -f backend/cpad.sqlite && echo "✅ cpad.sqlite present" || echo "❌ cpad.sqlite missing"
test -f backend/metadata.html && echo "✅ metadata.html present" || echo "❌ metadata.html missing"
test -d backend/zipped_shapefiles && echo "✅ zipped_shapefiles directory present" || echo "❌ zipped_shapefiles missing"
```

**HALT DIRECTIVE**: If any required files are missing, STOP. These files are essential for the application to function.

### Step 1.3: Configure Environment Variables

Create a `.env` file for local testing (this file is NOT committed to git):

```bash
# Create .env file from template
cp .env.example .env

# Edit the file with actual values
# Use your preferred text editor (nano, vim, code, etc.)
nano .env
```

**👋 HUMAN INTERVENTION REQUIRED:** Edit `.env` and replace ALL placeholders:
- `your_mapbox_access_token_here` → Your actual Mapbox token
- `your_google_sheet_id_here` → Your Google Sheet ID
- `your_google_sheet_gid_here` → Your Google Sheet GID

**Validation Command:**
```bash
# Check .env file has no placeholder values
grep -E "your_.*_here" .env && echo "❌ Placeholder values detected in .env" || echo "✅ .env configured"
```

**HALT DIRECTIVE**: If placeholder values are detected, STOP and update .env with actual values.

### Step 1.4: Setup Google Cloud Secret Manager

Store sensitive credentials in Google Cloud Secret Manager:

```bash
# Set your project ID
export PROJECT_ID=YOUR_PROJECT_ID  # 👋 HUMAN: Replace with your project ID

# Create secrets from .env values
# Extract values from .env and create secrets

# Mapbox Access Token
export MAPBOX_TOKEN=$(grep VITE_MAPBOX_ACCESS_TOKEN .env | cut -d '=' -f2)
echo -n "$MAPBOX_TOKEN" | gcloud secrets create mapbox-access-token \
    --data-file=- \
    --replication-policy="automatic"

# Google Sheet ID
export SHEET_ID=$(grep GOOGLE_SHEET_ID .env | cut -d '=' -f2)
echo -n "$SHEET_ID" | gcloud secrets create google-sheet-id \
    --data-file=- \
    --replication-policy="automatic"

# Google Sheet GID
export SHEET_GID=$(grep GOOGLE_SHEET_GID .env | cut -d '=' -f2)
echo -n "$SHEET_GID" | gcloud secrets create google-sheet-gid \
    --data-file=- \
    --replication-policy="automatic"

# Verify secrets were created
gcloud secrets list
```

**Expected Output**: Should list three secrets: `mapbox-access-token`, `google-sheet-id`, `google-sheet-gid`

**Alternative: Use Cloud Console**
If command-line fails, create secrets via Cloud Console:
1. Navigate to: https://console.cloud.google.com/security/secret-manager
2. Click "CREATE SECRET" for each value
3. Enter secret name and value
4. Click "CREATE"

---

## Phase 2: 🚀 DEPLOY - Build and Deploy

### Step 2.1: Build Docker Image

**🔍 PREPARE PHASE for Build:**
```bash
# Ensure you're in the project root
cd /path/to/arctic-map  # 👋 HUMAN: Use your actual path

# Verify Dockerfile exists
test -f .deployment/Dockerfile && echo "✅ Dockerfile found" || echo "❌ Dockerfile missing"

# Verify all required deployment files exist
for file in .deployment/nginx.conf .deployment/supervisord.conf; do
    test -f "$file" && echo "✅ $file found" || echo "❌ $file missing"
done
```

**HALT DIRECTIVE**: If any deployment files are missing, STOP.

**🚀 DEPLOY PHASE for Build:**

Build the Docker image and push to Google Container Registry:

```bash
# Set variables
export PROJECT_ID=YOUR_PROJECT_ID          # 👋 HUMAN: Replace with your project ID
export IMAGE_NAME=arctic-map
export IMAGE_TAG=latest
export GCR_IMAGE=gcr.io/${PROJECT_ID}/${IMAGE_NAME}:${IMAGE_TAG}

# Build the Docker image
echo "🐳 Building Docker image..."
docker build -f .deployment/Dockerfile -t ${GCR_IMAGE} .

# Verify build succeeded
docker images | grep arctic-map && echo "✅ Image built successfully" || echo "❌ Image build failed"
```

**Expected Output**: 
```
Successfully built [hash]
Successfully tagged gcr.io/YOUR_PROJECT_ID/arctic-map:latest
```

**HALT DIRECTIVE**: If build fails, check error messages and resolve before continuing.

**Common Build Errors:**
- Missing files → Verify all files in Step 1.2
- Permission denied → Check Docker daemon is running
- Out of disk space → Free up space or use `docker system prune`

### Step 2.2: Test Docker Image Locally (Optional but Recommended)

```bash
# Run container locally with environment variables
docker run -d \
    -p 8080:8080 \
    -e VITE_MAPBOX_ACCESS_TOKEN="$MAPBOX_TOKEN" \
    -e GOOGLE_SHEET_ID="$SHEET_ID" \
    -e GOOGLE_SHEET_GID="$SHEET_GID" \
    --name arctic-map-test \
    ${GCR_IMAGE}

# Check if container is running
docker ps | grep arctic-map-test && echo "✅ Container running" || echo "❌ Container not running"

# Check container logs
docker logs arctic-map-test

# Test health endpoint
sleep 10  # Wait for services to start
curl http://localhost:8080/health
```

**Expected Output**: `healthy` response from health check

**Cleanup test container:**
```bash
docker stop arctic-map-test
docker rm arctic-map-test
```

### Step 2.3: Push Image to Google Container Registry

```bash
# Push the image to GCR
echo "📤 Pushing image to Google Container Registry..."
docker push ${GCR_IMAGE}

# Verify image was pushed
gcloud container images list --repository=gcr.io/${PROJECT_ID} | grep arctic-map && \
    echo "✅ Image pushed successfully" || echo "❌ Image push failed"

# List image tags
gcloud container images list-tags gcr.io/${PROJECT_ID}/${IMAGE_NAME}
```

**Expected Output**: Should show the `latest` tag with recent timestamp

### Step 2.4: Deploy to Cloud Run

**🚀 DEPLOY PHASE for Cloud Run:**

```bash
# Set deployment variables
export PROJECT_ID=YOUR_PROJECT_ID          # 👋 HUMAN: Replace with your project ID
export SERVICE_NAME=arctic-map
export REGION=us-central1                  # 👋 HUMAN: Choose your preferred region
export GCR_IMAGE=gcr.io/${PROJECT_ID}/arctic-map:latest

# Deploy to Cloud Run with secrets from Secret Manager
gcloud run deploy ${SERVICE_NAME} \
    --image ${GCR_IMAGE} \
    --platform managed \
    --region ${REGION} \
    --allow-unauthenticated \
    --port 8080 \
    --memory 2Gi \
    --cpu 2 \
    --timeout 300 \
    --min-instances 0 \
    --max-instances 10 \
    --set-secrets="VITE_MAPBOX_ACCESS_TOKEN=mapbox-access-token:latest,GOOGLE_SHEET_ID=google-sheet-id:latest,GOOGLE_SHEET_GID=google-sheet-gid:latest"

# Capture the service URL
export SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} \
    --platform managed \
    --region ${REGION} \
    --format 'value(status.url)')

echo "🎉 Service deployed successfully!"
echo "📍 Service URL: ${SERVICE_URL}"
```

**Explanation of Flags:**
- `--image`: Docker image to deploy
- `--platform managed`: Use fully managed Cloud Run
- `--region`: GCP region for deployment
- `--allow-unauthenticated`: Make service publicly accessible (use `--no-allow-unauthenticated` for private)
- `--port 8080`: Container port (matches nginx configuration)
- `--memory 2Gi`: RAM allocation (adjust based on data size)
- `--cpu 2`: CPU allocation
- `--timeout 300`: Request timeout (5 minutes, for large data operations)
- `--min-instances 0`: Scale to zero when idle (saves costs)
- `--max-instances 10`: Maximum concurrent instances
- `--set-secrets`: Mount secrets from Secret Manager as environment variables

**Expected Output**:
```
Deploying container to Cloud Run service [arctic-map] in project [YOUR_PROJECT_ID] region [us-central1]
✓ Deploying... Done.
  ✓ Creating Revision...
  ✓ Routing traffic...
Done.
Service [arctic-map] revision [arctic-map-00001-xxx] has been deployed and is serving 100 percent of traffic.
Service URL: https://arctic-map-xxx-uc.a.run.app
```

### Step 2.5: Verify Deployment

```bash
# Test the health endpoint
curl ${SERVICE_URL}/health

# Test the API
curl ${SERVICE_URL}/api/layer_hierarchy | jq '.' | head -20

# Open in browser
echo "🌐 Open in browser: ${SERVICE_URL}"
```

**Expected Output**:
- Health check: `healthy`
- API response: JSON with layer hierarchy data

**HALT DIRECTIVE**: If health check fails or returns error, check logs:
```bash
gcloud run services logs read ${SERVICE_NAME} --region ${REGION} --limit 50
```

### Step 2.6: Configure Custom Domain (Optional)

**👋 HUMAN INTERVENTION REQUIRED:** If you want a custom domain:

1. **Verify domain ownership** in Google Cloud Console
2. **Map domain to Cloud Run service:**

```bash
# Add domain mapping
gcloud run domain-mappings create \
    --service ${SERVICE_NAME} \
    --domain your-custom-domain.com \
    --region ${REGION}

# Get DNS records to configure
gcloud run domain-mappings describe \
    --domain your-custom-domain.com \
    --region ${REGION}
```

3. **Update DNS records** at your domain registrar with the provided values
4. **Wait for SSL certificate** provisioning (can take up to 24 hours)

---

## Phase 3: 🧹 TEARDOWN - Cleanup and Rollback

### Rollback to Previous Revision

If deployment fails or has issues:

```bash
# List all revisions
gcloud run revisions list --service ${SERVICE_NAME} --region ${REGION}

# Rollback to previous revision (replace REVISION_NAME)
gcloud run services update-traffic ${SERVICE_NAME} \
    --region ${REGION} \
    --to-revisions REVISION_NAME=100
```

### Delete Service (Complete Teardown)

```bash
# Delete Cloud Run service
gcloud run services delete ${SERVICE_NAME} \
    --region ${REGION} \
    --quiet

# Delete container images
gcloud container images delete gcr.io/${PROJECT_ID}/${IMAGE_NAME}:${IMAGE_TAG} --quiet

# Delete secrets (if no longer needed)
gcloud secrets delete mapbox-access-token --quiet
gcloud secrets delete google-sheet-id --quiet
gcloud secrets delete google-sheet-gid --quiet
```

### Cleanup Local Resources

```bash
# Remove Docker images
docker rmi ${GCR_IMAGE}
docker system prune -a --volumes --force

# Remove local test files
rm -rf .env
```

---

## Environment Variables Reference

### Required Variables

| Variable | Description | Source | Example |
|----------|-------------|--------|---------|
| `VITE_MAPBOX_ACCESS_TOKEN` | Mapbox API token for map rendering | Mapbox Account | `pk.eyJ1...` |
| `GOOGLE_SHEET_ID` | ID of Google Sheet with layer metadata | Google Sheets URL | `1CftOe...` |
| `GOOGLE_SHEET_GID` | Specific sheet/tab ID | Google Sheets URL parameter | `583540745` |

### Optional Variables for Development

| Variable | Description | Default |
|----------|-------------|---------|
| `VITE_BACKEND_API_URL` | Backend API URL | `http://localhost:8000` (dev) or same domain (prod) |
| `VITE_DOWNLOAD_API_URL` | Download service URL | `http://localhost:8001` (dev) or same domain (prod) |

**Note**: In production (Cloud Run), both backend URLs should point to the same Cloud Run service URL since nginx proxies all requests.

---

## Troubleshooting

### Issue: Build fails with "GDAL not found"

**Solution**: The Dockerfile installs GDAL. If build fails, check:
```bash
# Verify Dockerfile has GDAL dependencies
grep -A5 "gdal-bin" .deployment/Dockerfile
```

### Issue: Service returns 502 or 503 errors

**Diagnosis:**
```bash
# Check service logs
gcloud run services logs read ${SERVICE_NAME} --region ${REGION} --limit 100

# Check revision status
gcloud run revisions list --service ${SERVICE_NAME} --region ${REGION}
```

**Common causes:**
- Application crash on startup → Check logs for Python errors
- Missing environment variables → Verify secrets are configured
- Insufficient memory/CPU → Increase `--memory` and `--cpu` flags

### Issue: API returns "Layer not found" errors

**Diagnosis**: Missing `cpad.sqlite` file or incorrect data

**Solution:**
1. Verify `backend/cpad.sqlite` is present in the image
2. Check file was copied during build:
```bash
docker run --rm ${GCR_IMAGE} ls -la /app/backend/cpad.sqlite
```
3. If missing, rebuild image after adding the file

### Issue: Frontend displays blank page

**Diagnosis:**
```bash
# Check if frontend files exist
docker run --rm ${GCR_IMAGE} ls -la /app/frontend/dist

# Check nginx logs in Cloud Run
gcloud run services logs read ${SERVICE_NAME} --region ${REGION} | grep nginx
```

**Solution**: Verify frontend build succeeded before Docker build

### Issue: "Permission denied" when accessing Secret Manager

**Solution**: Grant Cloud Run service account access to secrets:
```bash
# Get the service account email
export SERVICE_ACCOUNT=$(gcloud run services describe ${SERVICE_NAME} \
    --region ${REGION} \
    --format='value(spec.template.spec.serviceAccountName)')

# Grant secret accessor role
for SECRET in mapbox-access-token google-sheet-id google-sheet-gid; do
    gcloud secrets add-iam-policy-binding ${SECRET} \
        --member="serviceAccount:${SERVICE_ACCOUNT}" \
        --role="roles/secretmanager.secretAccessor"
done
```

---

## Additional Resources

- [Google Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Docker Documentation](https://docs.docker.com/)
- [Mapbox GL JS Documentation](https://docs.mapbox.com/mapbox-gl-js/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)

---

## Support and Maintenance

For issues or questions:
1. Check application logs: `gcloud run services logs read arctic-map --region REGION --limit 100`
2. Review Cloud Run metrics in GCP Console
3. Contact repository maintainers

**Service Monitoring:**
```bash
# View service details
gcloud run services describe ${SERVICE_NAME} --region ${REGION}

# View recent deployments
gcloud run revisions list --service ${SERVICE_NAME} --region ${REGION}

# Stream logs in real-time
gcloud run services logs tail ${SERVICE_NAME} --region ${REGION}
```
