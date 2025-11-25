# Arctic Map - Deployment Documentation

This document provides comprehensive instructions for deploying the Arctic Map web application to Google Cloud Run. It follows a phase-based structure with explicit validation steps and error handling.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Environment Variables](#environment-variables)
4. [Deployment Process](#deployment-process)
5. [Manual Deployment Steps](#manual-deployment-steps)
6. [Troubleshooting](#troubleshooting)
7. [Rollback Procedures](#rollback-procedures)

---

## Architecture Overview

The Arctic Map application consists of three main components:

1. **Frontend**: React application built with Vite, served by nginx
2. **Main Backend API**: FastAPI service running on port 8000 (spatial data, metadata, geocoding)
3. **Download Service**: FastAPI service running on port 8001 (shapefile downloads)

All three services are packaged into a single Docker container using:
- Multi-stage build for optimized image size
- Nginx as reverse proxy on port 8080
- Supervisor to manage multiple processes
- Python 3.12 and Node.js 20

**Port Configuration:**
- External (Cloud Run): Port 8080
- Internal nginx: Port 8080 → Frontend static files
- Internal API proxy: Port 8080 → Backend port 8000
- Internal downloads proxy: Port 8080 → Backend port 8001

---

## Prerequisites

### Required Tools

1. **Google Cloud SDK (gcloud)**
   ```bash
   # Install gcloud CLI
   # macOS:
   brew install --cask google-cloud-sdk
   
   # Linux:
   curl https://sdk.cloud.google.com | bash
   exec -l $SHELL
   
   # Windows: Download from https://cloud.google.com/sdk/docs/install
   
   # Verify installation
   gcloud --version
   ```

2. **Docker**
   ```bash
   # Verify Docker installation
   docker --version
   docker info
   
   # If not installed, visit: https://docs.docker.com/get-docker/
   ```

3. **Git** (for cloning the repository)
   ```bash
   git --version
   ```

### Google Cloud Platform Setup

**👋 HUMAN INTERVENTION REQUIRED:** Complete the following GCP setup steps:

1. **Create GCP Project**
   ```bash
   # Create a new project (or use existing)
   gcloud projects create PROJECT_ID --name="Arctic Map"
   
   # Set as active project
   gcloud config set project PROJECT_ID
   
   # Enable billing (MUST be done via Cloud Console)
   # Visit: https://console.cloud.google.com/billing
   ```

2. **Enable Required APIs**
   ```bash
   # Enable Cloud Run API
   gcloud services enable run.googleapis.com
   
   # Enable Container Registry API
   gcloud services enable containerregistry.googleapis.com
   
   # Enable Cloud Build API (optional, for automated builds)
   gcloud services enable cloudbuild.googleapis.com
   
   # Verify APIs are enabled
   gcloud services list --enabled | grep -E "(run|container|cloudbuild)"
   ```
   
   **Expected Output:**
   ```
   run.googleapis.com                     Cloud Run API
   containerregistry.googleapis.com       Container Registry API
   cloudbuild.googleapis.com              Cloud Build API
   ```

3. **Authenticate with gcloud**
   ```bash
   # Login to Google Cloud
   gcloud auth login
   
   # Configure Docker to use gcloud credentials
   gcloud auth configure-docker gcr.io
   
   # Verify authentication
   gcloud auth list
   ```
   
   **Expected Output:**
   ```
          Credentialed Accounts
   ACTIVE  ACCOUNT
   *       your-email@example.com
   ```

4. **Create Service Account (Optional but Recommended for CI/CD)**
   ```bash
   # Create service account
   gcloud iam service-accounts create arctic-map-deployer \
       --display-name="Arctic Map Deployment Service Account"
   
   # Grant necessary roles
   gcloud projects add-iam-policy-binding PROJECT_ID \
       --member="serviceAccount:arctic-map-deployer@PROJECT_ID.iam.gserviceaccount.com" \
       --role="roles/run.admin"
   
   gcloud projects add-iam-policy-binding PROJECT_ID \
       --member="serviceAccount:arctic-map-deployer@PROJECT_ID.iam.gserviceaccount.com" \
       --role="roles/storage.admin"
   
   # Create and download key (KEEP THIS SECURE!)
   gcloud iam service-accounts keys create ~/arctic-map-key.json \
       --iam-account=arctic-map-deployer@PROJECT_ID.iam.gserviceaccount.com
   ```

---

## Environment Variables

### Required Configuration

The application requires the following environment variables. Create local `.env` files from the templates:

#### Backend Environment Variables

**File: `backend/.env`** (create from `backend/.env.example`)

```bash
# Google Sheets Configuration
# Get these from your Google Sheet URL: https://docs.google.com/spreadsheets/d/{SHEET_ID}/edit#gid={GID}
GOOGLE_SHEET_ID=your_actual_google_sheet_id
GOOGLE_SHEET_GID=your_actual_google_sheet_gid
```

**👋 HUMAN INTERVENTION REQUIRED:** Replace placeholder values with actual Google Sheet credentials:
1. Open your Google Sheet in a browser
2. The URL format is: `https://docs.google.com/spreadsheets/d/{SHEET_ID}/edit#gid={GID}`
3. Copy the `SHEET_ID` and `GID` values from the URL
4. Update your local `backend/.env` file

#### Frontend Environment Variables

**File: `frontend/.env`** (create from `frontend/.env.example`)

```bash
# Mapbox Configuration
# Get your token from: https://account.mapbox.com/access-tokens/
VITE_MAPBOX_ACCESS_TOKEN=your_actual_mapbox_token
```

**👋 HUMAN INTERVENTION REQUIRED:** Get a Mapbox access token:
1. Visit https://account.mapbox.com/access-tokens/
2. Create a new token or copy an existing one
3. Update your local `frontend/.env` file
4. Export this variable before building: `export VITE_MAPBOX_ACCESS_TOKEN=your_token`

### Deployment Environment Variables

**👋 HUMAN INTERVENTION REQUIRED:** Export these variables in your shell before running deployment scripts:

```bash
# GCP Configuration
export PROJECT_ID="your-gcp-project-id"
export REGION="us-central1"  # or your preferred region
export SERVICE_NAME="arctic-map"
export IMAGE_NAME="arctic-map"
export IMAGE_TAG="latest"  # or use version tags like "v1.0.0"

# Application Secrets (required for Cloud Run deployment)
export GOOGLE_SHEET_ID="your_actual_google_sheet_id"
export GOOGLE_SHEET_GID="your_actual_google_sheet_gid"

# Build-time variable (required for Docker build)
export VITE_MAPBOX_ACCESS_TOKEN="your_actual_mapbox_token"
```

**Save these to a file** (DO NOT commit to git):
```bash
# Create a local deployment config file
cat > ~/.arctic-map-deploy.env << 'EOF'
export PROJECT_ID="your-gcp-project-id"
export REGION="us-central1"
export SERVICE_NAME="arctic-map"
export IMAGE_NAME="arctic-map"
export IMAGE_TAG="latest"
export GOOGLE_SHEET_ID="your_actual_google_sheet_id"
export GOOGLE_SHEET_GID="your_actual_google_sheet_gid"
export VITE_MAPBOX_ACCESS_TOKEN="your_actual_mapbox_token"
EOF

# Load variables
source ~/.arctic-map-deploy.env
```

---

## Deployment Process

### Automated Deployment (Using Scripts)

The deployment process is divided into two main scripts in `.deployment/scripts/`:

#### 🔍 Phase 1: Build (build.sh)

This script validates prerequisites, builds the Docker image, and pushes it to Google Container Registry.

```bash
# Load deployment variables
source ~/.arctic-map-deploy.env

# Run build script
cd /path/to/arctic-map
./.deployment/scripts/build.sh
```

**Script Phases:**

1. **🔍 PREPARE PHASE**
   - Validates environment variables (PROJECT_ID, VITE_MAPBOX_ACCESS_TOKEN)
   - Checks gcloud authentication
   - Checks Docker installation and daemon status
   - Expected output: "✅ All prerequisites validated"

2. **🚀 DEPLOY PHASE**
   - Configures Docker authentication for GCR
   - Builds Docker image with multi-stage build
   - Pushes image to gcr.io/PROJECT_ID/IMAGE_NAME:TAG
   - Expected output: "✅ Image pushed successfully"

3. **🧹 TEARDOWN PHASE**
   - Offers option to remove local image
   - Displays next steps

**Expected Total Time:** 5-10 minutes (depending on network speed)

**HALT Conditions:**
- Missing PROJECT_ID or VITE_MAPBOX_ACCESS_TOKEN → Exit with error
- gcloud not authenticated → "Please run: gcloud auth login"
- Docker build fails → Check Dockerfile and dependencies

#### 🚀 Phase 2: Deploy (deploy.sh)

This script deploys the built image to Google Cloud Run with proper configuration.

```bash
# Load deployment variables (if not already loaded)
source ~/.arctic-map-deploy.env

# Run deploy script
./.deployment/scripts/deploy.sh
```

**Script Phases:**

1. **🔍 PREPARE PHASE**
   - Validates deployment variables
   - Checks gcloud authentication
   - Verifies image exists in GCR
   - Expected output: "✅ All prerequisites validated"

2. **🚀 DEPLOY PHASE**
   - Deploys to Cloud Run with configuration:
     * Platform: managed
     * Region: $REGION
     * Port: 8080
     * Memory: 2Gi
     * CPU: 2
     * Timeout: 300s
     * Scaling: 0-10 instances
     * Permissions: allow-unauthenticated
   - Sets environment variables (GOOGLE_SHEET_ID, GOOGLE_SHEET_GID)
   - Expected output: "✅ Deployment successful"

3. **🧹 TEARDOWN PHASE**
   - Tests service health with curl
   - Displays service URL and useful commands
   - Expected output: "✅ Service is responding"

**Expected Total Time:** 2-5 minutes

**HALT Conditions:**
- Image not found in GCR → Run build.sh first
- Deployment fails → Check service logs
- Health check fails → Review application logs

---

## Manual Deployment Steps

If you prefer to run commands manually or need more control:

### 🔍 PREPARE PHASE

```bash
# 1. Set environment variables
export PROJECT_ID="your-gcp-project-id"
export REGION="us-central1"
export SERVICE_NAME="arctic-map"
export IMAGE_NAME="arctic-map"
export IMAGE_TAG="latest"
export VITE_MAPBOX_ACCESS_TOKEN="your_mapbox_token"
export GOOGLE_SHEET_ID="your_sheet_id"
export GOOGLE_SHEET_GID="your_sheet_gid"

# 2. Authenticate
gcloud auth login
gcloud config set project ${PROJECT_ID}
gcloud auth configure-docker gcr.io

# 3. Verify prerequisites
gcloud services list --enabled | grep -E "(run|container)"
docker info
```

**Validation:** All commands should succeed without errors.

### 🚀 DEPLOY PHASE

```bash
# 1. Build Docker image
docker build \
    --build-arg VITE_MAPBOX_ACCESS_TOKEN="${VITE_MAPBOX_ACCESS_TOKEN}" \
    -t gcr.io/${PROJECT_ID}/${IMAGE_NAME}:${IMAGE_TAG} \
    -f .deployment/Dockerfile \
    .

# Validation: Check image was created
docker images | grep ${IMAGE_NAME}
```

**Expected Output:**
```
gcr.io/your-project/arctic-map   latest   abc123def456   2 minutes ago   X.XXG
```

```bash
# 2. Push image to GCR
docker push gcr.io/${PROJECT_ID}/${IMAGE_NAME}:${IMAGE_TAG}

# Validation: Verify image in GCR
gcloud container images describe gcr.io/${PROJECT_ID}/${IMAGE_NAME}:${IMAGE_TAG}
```

**Expected Output:** JSON with image digest and creation timestamp

```bash
# 3. Deploy to Cloud Run
gcloud run deploy ${SERVICE_NAME} \
    --image=gcr.io/${PROJECT_ID}/${IMAGE_NAME}:${IMAGE_TAG} \
    --platform=managed \
    --region=${REGION} \
    --allow-unauthenticated \
    --port=8080 \
    --memory=2Gi \
    --cpu=2 \
    --timeout=300 \
    --max-instances=10 \
    --min-instances=0 \
    --set-env-vars="GOOGLE_SHEET_ID=${GOOGLE_SHEET_ID},GOOGLE_SHEET_GID=${GOOGLE_SHEET_GID}"

# Validation: Get service URL
gcloud run services describe ${SERVICE_NAME} --region=${REGION} --format="value(status.url)"
```

**Expected Output:**
```
Service [arctic-map] revision [arctic-map-00001-xxx] has been deployed and is serving 100 percent of traffic.
Service URL: https://arctic-map-xxxxxxxxx-uc.a.run.app
```

### 🧹 TEARDOWN PHASE

```bash
# 1. Test the deployment
SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} --region=${REGION} --format="value(status.url)")
curl -I ${SERVICE_URL}

# Expected output: HTTP/2 200

# 2. View logs
gcloud run services logs read ${SERVICE_NAME} --region=${REGION} --limit=50

# 3. Monitor service
gcloud run services describe ${SERVICE_NAME} --region=${REGION}
```

---

## Troubleshooting

### Common Issues and Solutions

#### Issue: Docker build fails with "Cannot find module"

**Symptoms:**
```
ERROR [frontend-builder 5/6] RUN npm run build
> frontend@0.0.0 build
> vite build
Error: Cannot find module 'react'
```

**Solution:**
```bash
# The npm ci command may not have installed correctly
# Try building with npm install instead
# Edit .deployment/Dockerfile line 15:
# Change: RUN npm ci --only=production
# To: RUN npm install --production=false
```

#### Issue: Image push fails with authentication error

**Symptoms:**
```
Error response from daemon: Get https://gcr.io/v2/: unauthorized
```

**Solution:**
```bash
# Re-authenticate Docker with gcloud
gcloud auth configure-docker gcr.io --quiet

# Verify authentication
gcloud auth list
```

#### Issue: Cloud Run deployment fails with "insufficient permissions"

**Symptoms:**
```
ERROR: (gcloud.run.deploy) PERMISSION_DENIED: Permission 'run.services.create' denied
```

**Solution:**
```bash
# Grant Cloud Run Admin role to your account
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="user:your-email@example.com" \
    --role="roles/run.admin"
```

#### Issue: Application starts but returns 500 errors

**Symptoms:**
Service deploys successfully but returns HTTP 500 on requests.

**Solution:**
```bash
# 1. Check application logs
gcloud run services logs read ${SERVICE_NAME} --region=${REGION} --limit=100

# 2. Common issues:
# - Missing environment variables → Update with --update-env-vars
# - Missing cpad.sqlite database → Upload to Cloud Storage or include in image
# - CORS issues → Check allow_origins in main.py

# 3. Update environment variables if needed
gcloud run services update ${SERVICE_NAME} \
    --region=${REGION} \
    --update-env-vars="GOOGLE_SHEET_ID=new_value,GOOGLE_SHEET_GID=new_value"
```

#### Issue: Frontend loads but API calls fail

**Symptoms:**
Frontend displays but map doesn't load, showing network errors in browser console.

**Solution:**
```bash
# The issue is likely hardcoded localhost URLs in frontend
# These are rewritten by nginx proxy, but check nginx logs:

# Get service logs filtered for nginx
gcloud run services logs read ${SERVICE_NAME} --region=${REGION} | grep nginx

# Verify nginx is proxying correctly:
# /api/* should route to backend services
# Check nginx configuration in Dockerfile
```

### Viewing Logs

```bash
# Real-time logs
gcloud run services logs tail ${SERVICE_NAME} --region=${REGION}

# Last 100 log entries
gcloud run services logs read ${SERVICE_NAME} --region=${REGION} --limit=100

# Filter by severity
gcloud run services logs read ${SERVICE_NAME} --region=${REGION} --log-filter="severity>=ERROR"

# Filter by specific service
gcloud run services logs read ${SERVICE_NAME} --region=${REGION} | grep "program:main-api"
```

### Debug Mode

To enable debug mode, update the service with additional environment variables:

```bash
gcloud run services update ${SERVICE_NAME} \
    --region=${REGION} \
    --update-env-vars="DEBUG=true,LOG_LEVEL=DEBUG"
```

---

## Rollback Procedures

### Rolling Back to Previous Version

Cloud Run keeps previous revisions. To rollback:

```bash
# 1. List all revisions
gcloud run revisions list --service=${SERVICE_NAME} --region=${REGION}

# Output shows revision names like: arctic-map-00001-xxx, arctic-map-00002-xxx

# 2. Rollback to specific revision
gcloud run services update-traffic ${SERVICE_NAME} \
    --region=${REGION} \
    --to-revisions=arctic-map-00001-xxx=100

# Validation: Check active revision
gcloud run services describe ${SERVICE_NAME} --region=${REGION} --format="value(status.traffic)"
```

### Emergency Rollback Script

Save this as `.deployment/scripts/rollback.sh`:

```bash
#!/bin/bash
set -e

SERVICE_NAME="${SERVICE_NAME:-arctic-map}"
REGION="${REGION:-us-central1}"

# Get current and previous revisions
CURRENT=$(gcloud run revisions list --service=${SERVICE_NAME} --region=${REGION} --format="value(name)" --limit=1)
PREVIOUS=$(gcloud run revisions list --service=${SERVICE_NAME} --region=${REGION} --format="value(name)" --limit=2 | tail -1)

echo "Current revision: ${CURRENT}"
echo "Previous revision: ${PREVIOUS}"
read -p "Rollback to ${PREVIOUS}? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    gcloud run services update-traffic ${SERVICE_NAME} \
        --region=${REGION} \
        --to-revisions=${PREVIOUS}=100
    echo "✅ Rolled back to ${PREVIOUS}"
fi
```

### Delete Deployment

To completely remove the service:

```bash
# Delete Cloud Run service
gcloud run services delete ${SERVICE_NAME} --region=${REGION}

# Delete images from GCR (optional)
gcloud container images delete gcr.io/${PROJECT_ID}/${IMAGE_NAME}:${IMAGE_TAG} --quiet

# List and delete all tags
gcloud container images list-tags gcr.io/${PROJECT_ID}/${IMAGE_NAME}
gcloud container images delete gcr.io/${PROJECT_ID}/${IMAGE_NAME}:TAG --quiet
```

---

## Cost Optimization

### Pricing Considerations

Cloud Run pricing is based on:
- **CPU allocation time**: Charged per vCPU-second
- **Memory allocation time**: Charged per GiB-second
- **Requests**: $0.40 per million requests
- **Networking**: Egress charges apply

### Optimization Tips

1. **Adjust resource allocation** based on actual usage:
   ```bash
   # Monitor resource usage
   gcloud run services describe ${SERVICE_NAME} --region=${REGION}
   
   # Reduce if over-provisioned
   gcloud run services update ${SERVICE_NAME} \
       --region=${REGION} \
       --memory=1Gi \
       --cpu=1
   ```

2. **Configure autoscaling**:
   ```bash
   # Reduce max instances to control costs
   gcloud run services update ${SERVICE_NAME} \
       --region=${REGION} \
       --max-instances=5
   
   # Keep min-instances at 0 to scale to zero when idle
   ```

3. **Enable request-based billing** (default):
   - Service scales to zero when not in use
   - No charges when idle
   - First request may have cold start latency (~2-3 seconds)

4. **Use a CDN** for static assets:
   - Consider Cloud CDN or Cloudflare
   - Reduces egress costs
   - Improves performance

---

## Security Considerations

### Environment Variables

**👋 HUMAN INTERVENTION REQUIRED:** Never commit secrets to git:

```bash
# Verify .env files are ignored
git check-ignore backend/.env frontend/.env

# If not ignored, add to .gitignore immediately
echo "backend/.env" >> .gitignore
echo "frontend/.env" >> .gitignore
```

### Service Account Permissions

Use least-privilege principle:

```bash
# Create dedicated service account
gcloud iam service-accounts create arctic-map-runtime \
    --display-name="Arctic Map Runtime Service Account"

# Grant only necessary permissions
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:arctic-map-runtime@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/run.invoker"

# Update service to use the service account
gcloud run services update ${SERVICE_NAME} \
    --region=${REGION} \
    --service-account=arctic-map-runtime@${PROJECT_ID}.iam.gserviceaccount.com
```

### Enable VPC Connector (Optional)

For private database access:

```bash
# Create VPC connector
gcloud compute networks vpc-access connectors create arctic-map-connector \
    --region=${REGION} \
    --range=10.8.0.0/28

# Update service to use connector
gcloud run services update ${SERVICE_NAME} \
    --region=${REGION} \
    --vpc-connector=arctic-map-connector
```

---

## CI/CD Integration

### GitHub Actions Workflow

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Cloud Run

on:
  push:
    branches: [ main ]
  workflow_dispatch:

env:
  PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
  REGION: us-central1
  SERVICE_NAME: arctic-map
  IMAGE_NAME: arctic-map

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v1
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}
      
      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v1
      
      - name: Configure Docker
        run: gcloud auth configure-docker gcr.io
      
      - name: Build Docker image
        run: |
          docker build \
            --build-arg VITE_MAPBOX_ACCESS_TOKEN="${{ secrets.VITE_MAPBOX_ACCESS_TOKEN }}" \
            -t gcr.io/${{ env.PROJECT_ID }}/${{ env.IMAGE_NAME }}:${{ github.sha }} \
            -t gcr.io/${{ env.PROJECT_ID }}/${{ env.IMAGE_NAME }}:latest \
            -f .deployment/Dockerfile \
            .
      
      - name: Push to Container Registry
        run: |
          docker push gcr.io/${{ env.PROJECT_ID }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          docker push gcr.io/${{ env.PROJECT_ID }}/${{ env.IMAGE_NAME }}:latest
      
      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy ${{ env.SERVICE_NAME }} \
            --image=gcr.io/${{ env.PROJECT_ID }}/${{ env.IMAGE_NAME }}:${{ github.sha }} \
            --platform=managed \
            --region=${{ env.REGION }} \
            --allow-unauthenticated \
            --port=8080 \
            --memory=2Gi \
            --cpu=2 \
            --timeout=300 \
            --max-instances=10 \
            --min-instances=0 \
            --set-env-vars="GOOGLE_SHEET_ID=${{ secrets.GOOGLE_SHEET_ID }},GOOGLE_SHEET_GID=${{ secrets.GOOGLE_SHEET_GID }}"
```

**👋 HUMAN INTERVENTION REQUIRED:** Configure GitHub Secrets:

1. Go to repository Settings → Secrets and variables → Actions
2. Add the following secrets:
   - `GCP_PROJECT_ID`: Your GCP project ID
   - `GCP_SA_KEY`: Service account JSON key (from prerequisites step)
   - `VITE_MAPBOX_ACCESS_TOKEN`: Mapbox access token
   - `GOOGLE_SHEET_ID`: Google Sheet ID
   - `GOOGLE_SHEET_GID`: Google Sheet GID

---

## Success Criteria

After deployment, verify:

1. **Service is accessible**
   ```bash
   curl -I ${SERVICE_URL}
   # Expected: HTTP/2 200
   ```

2. **Frontend loads**
   ```bash
   curl ${SERVICE_URL} | grep "<title>"
   # Expected: HTML with title tag
   ```

3. **API responds**
   ```bash
   curl ${SERVICE_URL}/api/layer_hierarchy
   # Expected: JSON response with layers
   ```

4. **Logs are clean**
   ```bash
   gcloud run services logs read ${SERVICE_NAME} --region=${REGION} --limit=20
   # Expected: No ERROR level messages
   ```

---

## Additional Resources

- [Google Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Container Registry Documentation](https://cloud.google.com/container-registry/docs)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [React Deployment Guide](https://reactjs.org/docs/optimizing-performance.html#use-the-production-build)
- [Nginx Configuration Reference](https://nginx.org/en/docs/)

---

## Support and Maintenance

For issues and questions:
1. Check [Troubleshooting](#troubleshooting) section
2. Review application logs
3. Consult Google Cloud Run documentation
4. Contact repository maintainers

**Document Version:** 1.0.0  
**Last Updated:** 2025-11-25  
**Maintained By:** Deployment Automation
