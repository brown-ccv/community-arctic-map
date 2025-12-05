# 🚀 Community Arctic Map - Deployment Guide

Complete guide for deploying the Community Arctic Map to Google Cloud Run.

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Large File Handling](#large-file-handling)
- [Environment Variables](#environment-variables)
- [Deployment Process](#deployment-process)
  - [Phase 1: Prepare](#phase-1-prepare---one-time-setup)
  - [Phase 2: Deploy](#phase-2-deploy)
  - [Phase 3: Teardown](#phase-3-teardown-optional)
- [Troubleshooting](#troubleshooting)
- [Maintenance](#maintenance)

---

## 🏗️ Architecture Overview

### Application Structure

The Community Arctic Map consists of three components running in a single container:

```
┌─────────────────────────────────────────────────┐
│           Cloud Run Container (Port 8080)        │
├─────────────────────────────────────────────────┤
│                                                  │
│  ┌────────────┐  ┌──────────┐  ┌──────────┐   │
│  │  Gateway   │  │ Main API │  │ Download │   │
│  │  (8080)    │  │  (8000)  │  │   API    │   │
│  │            │  │          │  │  (8001)  │   │
│  │ - Frontend │  │ - Layer  │  │ - Shape  │   │
│  │ - Proxy    │  │   Data   │  │   files  │   │
│  └────────────┘  └──────────┘  └──────────┘   │
│                                                  │
└─────────────────────────────────────────────────┘
           │                    │
           │                    │
    ┌──────▼──────┐      ┌─────▼──────┐
    │   Secret    │      │   Cloud    │
    │   Manager   │      │   Storage  │
    └─────────────┘      └────────────┘
```

### Key Technologies

- **Frontend**: React + Vite + Mapbox GL JS
- **Backend**: Python 3.12 + FastAPI + GeoPandas
- **Platform**: Google Cloud Run (Gen 2)
- **CI/CD**: GitHub Actions

---

## 📦 Prerequisites

### Required Accounts and Tools

1. **Google Cloud Platform**
   - Active GCP project with billing enabled
   - Project ID (e.g., `my-project-123`)
   - gcloud CLI installed: https://cloud.google.com/sdk/docs/install

2. **GitHub**
   - Repository admin access
   - GitHub CLI installed: https://cli.github.com/
   - Personal access token with scopes: `repo`, `workflow`, `admin:repo_hook`

3. **Required APIs** (Mapbox, Google Sheets)
   - Mapbox access token: https://account.mapbox.com/access-tokens/
   - Google Sheets with layer hierarchy data

### System Requirements

```bash
# Check installed tools
gcloud version    # Google Cloud SDK 400.0.0+
gh --version      # GitHub CLI 2.0.0+
docker --version  # Docker 20.10.0+ (optional, for local testing)
```

---

## 📁 Large File Handling

### Critical Files Not in Repository

Three large files are excluded from Git but required for deployment:

1. **`backend/cpad.sqlite`** (4.3 GB)
   - SQLite/SpatiaLite database with GIS layers
   - Contains all geographic data for the application

2. **`backend/metadata.html`** (size varies)
   - Metadata descriptions for all layers
   - Referenced by the `/api/metadata_html` endpoint

3. **`backend/zipped_shapefiles/`** (directory)
   - Pre-zipped shapefiles for download functionality
   - One `.zip` file per layer

### Recommended Approach: Google Cloud Storage

#### Step 1: Create Cloud Storage Bucket

```bash
# Set variables
export PROJECT_ID="your-project-id"
export BUCKET_NAME="community-arctic-map-data"
export REGION="us-east1"

# Create bucket
gsutil mb -p $PROJECT_ID -l $REGION gs://$BUCKET_NAME

# Set bucket permissions
gsutil iam ch serviceAccount:community-arctic-map-sa@${PROJECT_ID}.iam.gserviceaccount.com:objectViewer gs://$BUCKET_NAME
```

#### Step 2: Upload Data Files

```bash
# Upload cpad.sqlite
gsutil -m cp backend/cpad.sqlite gs://$BUCKET_NAME/data/

# Upload metadata.html
gsutil -m cp backend/metadata.html gs://$BUCKET_NAME/data/

# Upload zipped shapefiles directory
gsutil -m cp -r backend/zipped_shapefiles gs://$BUCKET_NAME/data/

# Verify uploads
gsutil ls -lh gs://$BUCKET_NAME/data/
```

#### Step 3: Mount in Cloud Run (Option A - Startup Script)

Modify `.deployment/scripts/start.sh` to download files on container startup:

```bash
#!/bin/bash
# Add before "Starting services..."

echo "📥 Downloading data files from Cloud Storage..."

# Create data directory
mkdir -p /app/data

# Download cpad.sqlite (4.3 GB - may take 1-2 minutes)
if [ ! -f "/app/data/cpad.sqlite" ]; then
    gsutil cp gs://$BUCKET_NAME/data/cpad.sqlite /app/data/ || echo "⚠️ Failed to download cpad.sqlite"
fi

# Download metadata.html
if [ ! -f "/app/data/metadata.html" ]; then
    gsutil cp gs://$BUCKET_NAME/data/metadata.html /app/data/ || echo "⚠️ Failed to download metadata.html"
fi

# Download zipped_shapefiles directory
if [ ! -d "/app/data/zipped_shapefiles" ]; then
    gsutil -m cp -r gs://$BUCKET_NAME/data/zipped_shapefiles /app/data/ || echo "⚠️ Failed to download zipped_shapefiles"
fi

echo "✅ Data files downloaded"
```

**Note**: This approach increases container startup time (~2-3 minutes for first request).

#### Step 4: Mount in Cloud Run (Option B - GCS FUSE)

For better performance, mount Cloud Storage as a volume using GCS FUSE:

Update `.deployment/cloudrun.yaml`:

```yaml
spec:
  template:
    spec:
      containers:
      - name: community-arctic-map
        volumeMounts:
        - name: gcs-data
          mountPath: /app/data
          readOnly: true
      
      volumes:
      - name: gcs-data
        csi:
          driver: gcsfuse.run.googleapis.com
          volumeAttributes:
            bucketName: community-arctic-map-data
            mountOptions: "implicit-dirs,file-mode=644,dir-mode=755"
```

Deploy with:

```bash
gcloud run services replace .deployment/cloudrun.yaml --region=$REGION
```

**Advantages**: Faster startup, no data download required  
**Requirements**: Cloud Run Gen 2, GCS FUSE enabled

---

## ⚙️ Environment Variables

### Required Environment Variables

| Variable | Description | Where Used | Example |
|----------|-------------|------------|---------|
| `VITE_MAPBOX_ACCESS_TOKEN` | Mapbox API token | Frontend build | `pk.eyJ1...` |
| `GOOGLE_SHEET_ID` | Google Sheets ID | Backend runtime | `1CftOecfPT...` |
| `GOOGLE_SHEET_GID` | Google Sheets GID | Backend runtime | `583540745` |
| `GCP_PROJECT_ID` | GCP project ID | GitHub Actions | `my-project-123` |
| `GCP_SERVICE_ACCOUNT_KEY` | Service account JSON key | GitHub Actions | `{"type":"service_account",...}` |

### Optional Environment Variables

| Variable | Description | Default | When to Set |
|----------|-------------|---------|-------------|
| `VITE_BACKEND_API_URL` | Backend API base URL | Relative URL | Multi-domain setups |
| `VITE_DOWNLOAD_API_URL` | Download API base URL | Relative URL | Multi-domain setups |
| `PORT` | Container port | `8080` | Cloud Run override |
| `CPAD_SQLITE_PATH` | Path to SQLite database | `/app/data/cpad.sqlite` | Custom mount point |
| `METADATA_HTML_PATH` | Path to metadata file | `/app/data/metadata.html` | Custom mount point |
| `ZIPPED_SHAPEFILES_PATH` | Path to shapefiles | `/app/data/zipped_shapefiles` | Custom mount point |

### Environment Variable Configuration

Create local `.env` files for development:

```bash
# Copy template
cp .env.example backend/.env
cp .env.example frontend/.env

# Edit with your values
nano backend/.env
nano frontend/.env
```

---

## 🚀 Deployment Process

### Phase 1: PREPARE - One-Time Setup

#### 1.1 Authenticate with GCP

```bash
# Login to GCP
gcloud auth login

# Set project
export PROJECT_ID="your-project-id"
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable \
    run.googleapis.com \
    cloudbuild.googleapis.com \
    artifactregistry.googleapis.com \
    secretmanager.googleapis.com \
    storage.googleapis.com
```

#### 1.2 Create Service Account

```bash
cd .deployment/scripts/gcp
./setup-service-account.sh $PROJECT_ID

# This creates:
# - Service account: community-arctic-map-sa@PROJECT_ID.iam.gserviceaccount.com
# - Key file: community-arctic-map-sa-key.json
# - IAM roles: run.admin, artifactregistry.writer, storage.objectViewer, secretmanager.secretAccessor
```

**🔐 Security Note**: Keep the `community-arctic-map-sa-key.json` file secure. Do NOT commit it to Git.

#### 1.3 Configure GCP Secrets

```bash
# Create secrets in Secret Manager
./setup-gcp-secrets.sh $PROJECT_ID

# Prompts for:
# - Google Sheets ID
# - Google Sheets GID

# Validate configuration
./validate-gcp-secrets.sh $PROJECT_ID
```

#### 1.4 Upload Data Files to Cloud Storage

Follow steps in [Large File Handling](#large-file-handling) section above.

#### 1.5 Authenticate with GitHub

```bash
# Login to GitHub CLI with required scopes
gh auth login --scopes repo,workflow,admin:repo_hook

# Verify authentication
gh auth status
```

#### 1.6 Configure GitHub Secrets

```bash
cd .deployment/scripts/github
./setup-github-secrets.sh brown-ccv/community-arctic-map

# Prompts for:
# - GCP_PROJECT_ID
# - GCP_SERVICE_ACCOUNT_KEY (path to JSON file)
# - VITE_MAPBOX_ACCESS_TOKEN
# - GOOGLE_SHEET_ID
# - GOOGLE_SHEET_GID

# Validate configuration
./validate-github-config.sh brown-ccv/community-arctic-map
```

#### 1.7 Create GitHub Environments (Optional)

```bash
./setup-github-environments.sh brown-ccv/community-arctic-map

# Creates:
# - production environment
# - staging environment
```

#### 1.8 Enable GitHub Actions

1. Go to: https://github.com/brown-ccv/community-arctic-map/settings/actions
2. Under "Actions permissions", select: **Allow all actions and reusable workflows**
3. Click **Save**

---

### Phase 2: DEPLOY

#### 2.1 Trigger Deployment via GitHub Actions (Recommended)

1. **Navigate to Actions tab**:
   ```
   https://github.com/brown-ccv/community-arctic-map/actions
   ```

2. **Select workflow**:
   - Click: `🚀 Deploy to Google Cloud Run`

3. **Run workflow**:
   - Click: `Run workflow` (dropdown)
   - Select branch: `main` or your deployment branch
   - Choose environment: `production` or `staging`
   - Choose region: `us-east1` (recommended for Brown University)
   - Click: `Run workflow` (button)

4. **Monitor deployment**:
   - Watch the workflow run in real-time
   - Three phases: Prepare → Deploy → Teardown (if failed)
   - Deployment typically takes 10-15 minutes

5. **Get deployment URL**:
   - URL displayed in deployment summary
   - Format: `https://community-arctic-map-HASH-us-east1.a.run.app`

#### 2.2 Manual Deployment via gcloud CLI (Alternative)

```bash
# Set variables
export PROJECT_ID="your-project-id"
export REGION="us-east1"
export SERVICE_NAME="community-arctic-map"
export VITE_MAPBOX_ACCESS_TOKEN="your-mapbox-token"

# Build and push image
gcloud builds submit \
    --config=.deployment/cloudbuild.yaml \
    --substitutions=_REGION=$REGION,_SERVICE_NAME=$SERVICE_NAME,_VITE_MAPBOX_ACCESS_TOKEN=$VITE_MAPBOX_ACCESS_TOKEN \
    --timeout=1800s

# Deploy to Cloud Run
gcloud run deploy $SERVICE_NAME \
    --image=$REGION-docker.pkg.dev/$PROJECT_ID/$SERVICE_NAME/$SERVICE_NAME:latest \
    --platform=managed \
    --region=$REGION \
    --service-account=${SERVICE_NAME}-sa@${PROJECT_ID}.iam.gserviceaccount.com \
    --allow-unauthenticated \
    --min-instances=0 \
    --max-instances=10 \
    --cpu=2 \
    --memory=2Gi \
    --timeout=300 \
    --concurrency=80 \
    --port=8080 \
    --set-env-vars="PORT=8080,BACKEND_API_URL=http://localhost:8000,DOWNLOAD_API_URL=http://localhost:8001" \
    --set-secrets="GOOGLE_SHEET_ID=google-sheet-id:latest,GOOGLE_SHEET_GID=google-sheet-gid:latest" \
    --execution-environment=gen2 \
    --cpu-boost

# Get service URL
gcloud run services describe $SERVICE_NAME --region=$REGION --format='value(status.url)'
```

#### 2.3 Verify Deployment

```bash
# Health check
SERVICE_URL=$(gcloud run services describe community-arctic-map --region=$REGION --format='value(status.url)')
curl -f $SERVICE_URL/health

# Expected output:
# {"status":"healthy","service":"community-arctic-map"}

# Test API endpoint
curl -f $SERVICE_URL/api/layer_hierarchy

# Access the application
open $SERVICE_URL
```

---

### Phase 3: TEARDOWN (Optional)

#### Delete Deployment

```bash
# Delete Cloud Run service
gcloud run services delete community-arctic-map --region=us-east1 --quiet

# Delete container images
gcloud artifacts repositories delete community-arctic-map \
    --location=us-east1 --quiet

# Delete GCP secrets (if no longer needed)
gcloud secrets delete google-sheet-id --quiet
gcloud secrets delete google-sheet-gid --quiet

# Delete Cloud Storage bucket (if no longer needed)
gsutil -m rm -r gs://community-arctic-map-data
```

#### Rollback to Previous Version

```bash
# List revisions
gcloud run revisions list --service=community-arctic-map --region=us-east1

# Rollback to specific revision
gcloud run services update-traffic community-arctic-map \
    --region=us-east1 \
    --to-revisions=REVISION_NAME=100
```

---

## 🔧 Troubleshooting

### Common Issues

#### 1. Build Fails: `fiona` Package Error

**Error**: `error: command 'gcc' failed` or `fiona installation error`

**Solution**: The Dockerfile includes `g++` compiler. Verify Dockerfile contains:

```dockerfile
RUN apt-get update && apt-get install -y \
    g++ \
    gcc \
    libgdal-dev \
    gdal-bin \
    ...
```

#### 2. Container Startup Timeout

**Error**: `Container failed to start. Failed to start and then listen on the port defined by the PORT environment variable.`

**Cause**: Large data files (cpad.sqlite) taking too long to download on startup.

**Solutions**:
- Use GCS FUSE mount (Option B) for instant access
- Increase Cloud Run timeout: `--timeout=600`
- Pre-warm containers: `--min-instances=1`

#### 3. Database File Not Found

**Error**: `cpad.sqlite not found at /app/data/cpad.sqlite`

**Solution**: Verify Cloud Storage configuration and file paths:

```bash
# Check bucket contents
gsutil ls -lh gs://community-arctic-map-data/data/

# Verify service account has access
gsutil iam get gs://community-arctic-map-data

# Test download manually
gsutil cp gs://community-arctic-map-data/data/cpad.sqlite /tmp/test.sqlite
```

#### 4. Secret Access Denied

**Error**: `Permission denied` when accessing Secret Manager

**Solution**: Grant service account access:

```bash
# Grant secretAccessor role
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:community-arctic-map-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"

# Verify secret is accessible
gcloud secrets versions access latest --secret=google-sheet-id
```

#### 5. GitHub Actions Workflow Fails

**Error**: Various authentication or permission errors

**Solution**: Verify GitHub Secrets:

```bash
# List configured secrets
gh secret list --repo=brown-ccv/community-arctic-map

# Re-run validation
cd .deployment/scripts/github
./validate-github-config.sh brown-ccv/community-arctic-map
```

### Viewing Logs

```bash
# Real-time logs
gcloud run services logs tail community-arctic-map --region=us-east1

# Filter by severity
gcloud run services logs read community-arctic-map \
    --region=us-east1 \
    --limit=50 \
    --format="table(severity,timestamp,textPayload)"

# View in Cloud Console
open "https://console.cloud.google.com/run/detail/us-east1/community-arctic-map/logs"
```

### Performance Optimization

```bash
# Increase resources for large files
gcloud run services update community-arctic-map \
    --region=us-east1 \
    --cpu=4 \
    --memory=4Gi

# Enable CPU boost for faster startup
gcloud run services update community-arctic-map \
    --region=us-east1 \
    --cpu-boost

# Set minimum instances to avoid cold starts
gcloud run services update community-arctic-map \
    --region=us-east1 \
    --min-instances=1
```

---

## 🔄 Maintenance

### Updating the Application

```bash
# Trigger deployment with updated code
# (Automatic via GitHub Actions on push to main)

# Or manually trigger workflow
gh workflow run "deploy.yml" \
    --repo=brown-ccv/community-arctic-map \
    --ref=main \
    -f environment=production \
    -f region=us-east1
```

### Updating Data Files

```bash
# Update cpad.sqlite
gsutil cp backend/cpad.sqlite gs://community-arctic-map-data/data/

# Update metadata
gsutil cp backend/metadata.html gs://community-arctic-map-data/data/

# Update shapefiles
gsutil -m rsync -r backend/zipped_shapefiles gs://community-arctic-map-data/data/zipped_shapefiles

# Restart service to reload data (if using startup download)
gcloud run services update community-arctic-map --region=us-east1
```

### Updating Secrets

```bash
# Update GCP secrets
gcloud secrets versions add google-sheet-id --data-file=- <<< "NEW_VALUE"
gcloud secrets versions add google-sheet-gid --data-file=- <<< "NEW_VALUE"

# Update GitHub secrets
echo "NEW_VALUE" | gh secret set VITE_MAPBOX_ACCESS_TOKEN --repo=brown-ccv/community-arctic-map

# Redeploy for secrets to take effect
```

### Monitoring

```bash
# View metrics
gcloud run services describe community-arctic-map \
    --region=us-east1 \
    --format="table(status.traffic,status.conditions)"

# Set up alerts (example)
gcloud alpha monitoring policies create \
    --notification-channels=CHANNEL_ID \
    --display-name="Community Arctic Map Errors" \
    --condition-display-name="Error rate > 5%" \
    --condition-threshold-value=0.05 \
    --condition-threshold-duration=300s
```

---

## 📞 Support

### Resources

- **GitHub Issues**: https://github.com/brown-ccv/community-arctic-map/issues
- **Cloud Run Documentation**: https://cloud.google.com/run/docs
- **Mapbox GL JS**: https://docs.mapbox.com/mapbox-gl-js/
- **FastAPI**: https://fastapi.tiangolo.com/

### Contact

- **CPAD Consortium**: https://nna-cpad.org/
- **Brown CCV**: https://ccv.brown.edu/

---

## 📄 License

This project is licensed under the MIT License. See the LICENSE file for details.
