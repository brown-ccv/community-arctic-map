# 🚀 Deployment Guide for Community Arctic Map

This guide provides step-by-step instructions for deploying the Community Arctic Map application to Google Cloud Run.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Architecture](#architecture)
- [Phase 1: 🔍 Prepare](#phase-1--prepare)
- [Phase 2: 🚀 Deploy](#phase-2--deploy)
- [Phase 3: 🧹 Teardown](#phase-3--teardown)
- [Database File Handling](#database-file-handling)
- [Troubleshooting](#troubleshooting)

## Overview

The Community Arctic Map is a full-stack geospatial web application consisting of:
- **Frontend**: React + Vite application
- **Backend**: Python FastAPI with two services
  - Main API (port 8080): Geospatial queries, metadata, geocoding
  - Download API (port 8001): Shapefile download service
- **Database**: SQLite file (4.3 GB) - `cpad.sqlite`

**Deployment Target**: Google Cloud Run (us-east1 region)

## Prerequisites

### Required Tools

1. **Google Cloud SDK** (`gcloud`)
   ```bash
   # Install from: https://cloud.google.com/sdk/docs/install
   # Verify installation:
   gcloud --version
   ```

2. **GitHub CLI** (`gh`)
   ```bash
   # Install from: https://cli.github.com/
   # Verify installation:
   gh --version
   ```

3. **Docker** (for local testing)
   ```bash
   # Install from: https://docs.docker.com/get-docker/
   # Verify installation:
   docker --version
   ```

### Required Accounts

1. **Google Cloud Platform** account with:
   - Billing enabled
   - Project created
   - Owner or Editor role

2. **GitHub** account with:
   - Repository admin access
   - Actions enabled

### Environment Variables

You'll need values for these variables:

**Application Secrets:**
- `GOOGLE_SHEET_ID`: Google Sheet ID containing layer theme organization
- `GOOGLE_SHEET_GID`: Google Sheet GID (tab identifier)
- `VITE_MAPBOX_ACCESS_TOKEN`: Mapbox access token from https://account.mapbox.com/

**GCP Configuration:**
- `GCP_PROJECT_ID`: Your Google Cloud Project ID
- `GCP_REGION`: us-east1 (required by Brown University policy)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Actions CI/CD                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                  │
│  │ Prepare  │→ │  Deploy  │→ │ Teardown │                  │
│  └──────────┘  └──────────┘  └──────────┘                  │
└─────────────────────┬───────────────────────────────────────┘
                      │ Deploy to
                      ↓
┌─────────────────────────────────────────────────────────────┐
│                  Google Cloud Run (us-east1)                 │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Container (4GB RAM, 2 CPU)                             │ │
│  │  ┌──────────────┐  ┌──────────────┐                   │ │
│  │  │   Frontend   │  │   Backend    │                   │ │
│  │  │ React + Vite │  │   FastAPI    │                   │ │
│  │  └──────────────┘  └──────────────┘                   │ │
│  │           │                │                            │ │
│  │           └────────┬───────┘                            │ │
│  │                    ↓                                    │ │
│  │            ┌───────────────┐                            │ │
│  │            │ cpad.sqlite   │ ← Mounted from Cloud      │ │
│  │            │    (4.3 GB)   │   Storage Bucket          │ │
│  │            └───────────────┘                            │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase 1: 🔍 PREPARE

### Step 1.1: Authenticate with Google Cloud

```bash
# Login to Google Cloud
gcloud auth login

# Set your project
gcloud config set project YOUR_PROJECT_ID

# Configure Docker authentication for Artifact Registry
gcloud auth configure-docker us-east1-docker.pkg.dev
```

### Step 1.2: Run GCP Service Account Setup

This script creates the service account, enables required APIs, and sets up necessary permissions.

```bash
# Navigate to deployment scripts
cd .deployment/scripts/gcp

# Run the setup script
./setup-service-account.sh

# Follow the prompts to enter your GCP Project ID
# The script will:
#   - Enable required Google Cloud APIs
#   - Create a service account with necessary roles
#   - Create an Artifact Registry repository
#   - Create a Cloud Storage bucket for the database
#   - Generate a service account key for GitHub Actions
```

**Output:** This creates a file `community-arctic-map-sa-key.json` in your current directory. **Keep this file secure!**

### Step 1.3: Upload Database File to Cloud Storage

The `cpad.sqlite` file (4.3 GB) is not included in the repository and must be uploaded separately.

```bash
# Ensure you have the cpad.sqlite file locally
# Replace YOUR_PROJECT_ID with your actual project ID

gsutil cp backend/cpad.sqlite gs://YOUR_PROJECT_ID-community-arctic-map-data/cpad.sqlite

# Verify upload
gsutil ls gs://YOUR_PROJECT_ID-community-arctic-map-data/
```

### Step 1.4: Set Up Runtime Secrets (Optional but Recommended)

If you want to use GCP Secret Manager for runtime secrets:

```bash
# Run the GCP secrets setup script
./setup-gcp-secrets.sh

# The script will prompt you to enter values for:
#   - GOOGLE_SHEET_ID
#   - GOOGLE_SHEET_GID
```

**Note:** Alternatively, you can set these as environment variables directly in GitHub Secrets (next step).

### Step 1.5: Authenticate with GitHub

```bash
# Login to GitHub CLI
gh auth login

# Select:
#   - GitHub.com
#   - HTTPS
#   - Login with a web browser
# Required scopes: repo, workflow, admin:repo_hook

# Verify authentication
gh auth status
```

### Step 1.6: Set Up GitHub Secrets

```bash
# Navigate to GitHub scripts
cd ../github

# Run the GitHub secrets setup script
./setup-github-secrets.sh

# The script will prompt you to enter:
#   - GCP_PROJECT_ID
#   - GCP_SERVICE_ACCOUNT_KEY (path to the JSON file)
#   - GOOGLE_SHEET_ID
#   - GOOGLE_SHEET_GID
#   - VITE_MAPBOX_ACCESS_TOKEN
```

### Step 1.7: Set Up GitHub Environments (Optional)

```bash
# Create staging and production environments
./setup-github-environments.sh

# This creates two environments with different protection rules:
#   - staging: No protection, for testing
#   - production: Optional wait timers and approval requirements
```

### Step 1.8: Validate Configuration

```bash
# Validate GCP configuration
cd ../gcp
./validate-gcp-config.sh

# Validate GitHub configuration
cd ../github
./validate-github-config.sh

# Both scripts should report "All validations passed!"
```

### 👋 HUMAN INTERVENTION SUMMARY - Phase 1

**You must complete these steps manually:**

1. ✅ Create a GCP project with billing enabled (one-time)
2. ✅ Run `gcloud auth login`
3. ✅ Run `.deployment/scripts/gcp/setup-service-account.sh`
4. ✅ Upload `cpad.sqlite` to Cloud Storage: `gsutil cp backend/cpad.sqlite gs://YOUR_PROJECT_ID-community-arctic-map-data/cpad.sqlite`
5. ✅ Run `gh auth login`
6. ✅ Run `.deployment/scripts/github/setup-github-secrets.sh`
7. ✅ **IMPORTANT**: Delete the service account key file after adding it to GitHub Secrets: `rm community-arctic-map-sa-key.json`
8. ✅ Run validation scripts to confirm setup

---

## Phase 2: 🚀 DEPLOY

### Deployment via GitHub Actions (Recommended)

1. **Navigate to GitHub Actions**
   ```
   https://github.com/YOUR_ORG/community-arctic-map/actions
   ```

2. **Select Workflow**
   - Click on "🚀 Deploy to Google Cloud Run"

3. **Run Workflow**
   - Click "Run workflow"
   - Select environment: `staging` or `production`
   - Optionally check "Skip validation tests" for faster deployment
   - Click "Run workflow"

4. **Monitor Deployment**
   - Watch the workflow progress through three phases:
     - 🔍 Prepare and Validate
     - 🚀 Build and Deploy
     - 🧹 Cleanup
   - Deployment typically takes 10-15 minutes

5. **Get Service URL**
   - After successful deployment, the service URL will be displayed in the workflow summary
   - Format: `https://community-arctic-map-HASH-us-east1.a.run.app`

### Manual Deployment (Alternative)

If you prefer to deploy manually from your local machine:

```bash
# Navigate to repository root
cd /path/to/community-arctic-map

# Build the Docker image
docker build \
  -f .deployment/Dockerfile \
  -t us-east1-docker.pkg.dev/YOUR_PROJECT_ID/arctic-map-repo/community-arctic-map:latest \
  --build-arg VITE_MAPBOX_ACCESS_TOKEN=YOUR_MAPBOX_TOKEN \
  --build-arg VITE_API_BASE_URL=/api \
  --build-arg VITE_DOWNLOAD_API_URL=/api/download \
  .

# Push to Artifact Registry
docker push us-east1-docker.pkg.dev/YOUR_PROJECT_ID/arctic-map-repo/community-arctic-map:latest

# Deploy to Cloud Run
gcloud run deploy community-arctic-map \
  --image=us-east1-docker.pkg.dev/YOUR_PROJECT_ID/arctic-map-repo/community-arctic-map:latest \
  --region=us-east1 \
  --platform=managed \
  --allow-unauthenticated \
  --service-account=community-arctic-map-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com \
  --memory=4Gi \
  --cpu=2 \
  --timeout=300 \
  --max-instances=10 \
  --min-instances=0 \
  --set-env-vars="PORT=8080,GOOGLE_SHEET_ID=YOUR_SHEET_ID,GOOGLE_SHEET_GID=YOUR_SHEET_GID" \
  --no-cpu-throttling

# Get the service URL
gcloud run services describe community-arctic-map \
  --region=us-east1 \
  --format='value(status.url)'
```

### Verify Deployment

```bash
# Get service URL
SERVICE_URL=$(gcloud run services describe community-arctic-map \
  --region=us-east1 \
  --format='value(status.url)')

# Test health endpoint
curl -s "$SERVICE_URL/api/layer_hierarchy" | head -20

# Expected: JSON response with layer hierarchy
```

### 👋 HUMAN INTERVENTION SUMMARY - Phase 2

**For GitHub Actions deployment:**
1. ✅ Navigate to GitHub Actions
2. ✅ Select "Deploy to Google Cloud Run" workflow
3. ✅ Click "Run workflow" and select environment
4. ✅ Monitor deployment progress
5. ✅ Visit the service URL to verify deployment

**For manual deployment:**
1. ✅ Run the Docker build command with your Mapbox token
2. ✅ Run the Docker push command
3. ✅ Run the gcloud deploy command with your project ID and secrets
4. ✅ Test the service URL

---

## Phase 3: 🧹 TEARDOWN

### Monitoring and Logs

```bash
# View Cloud Run logs
gcloud run logs read community-arctic-map \
  --region=us-east1 \
  --limit=100

# Stream logs in real-time
gcloud run logs tail community-arctic-map \
  --region=us-east1

# View service details
gcloud run services describe community-arctic-map \
  --region=us-east1
```

### Rollback to Previous Version

If a deployment fails or has issues:

```bash
# List revisions
gcloud run revisions list \
  --service=community-arctic-map \
  --region=us-east1

# Rollback to a specific revision
gcloud run services update-traffic community-arctic-map \
  --to-revisions=REVISION_NAME=100 \
  --region=us-east1
```

### Cleanup Resources (Complete Teardown)

**⚠️ WARNING**: This will delete all deployed resources

```bash
# Delete Cloud Run service
gcloud run services delete community-arctic-map \
  --region=us-east1 \
  --quiet

# Delete Artifact Registry images
gcloud artifacts docker images delete \
  us-east1-docker.pkg.dev/YOUR_PROJECT_ID/arctic-map-repo/community-arctic-map \
  --delete-tags \
  --quiet

# Delete Artifact Registry repository (optional)
gcloud artifacts repositories delete arctic-map-repo \
  --location=us-east1 \
  --quiet

# Delete Cloud Storage bucket and contents (optional)
gsutil rm -r gs://YOUR_PROJECT_ID-community-arctic-map-data

# Delete service account (optional)
gcloud iam service-accounts delete \
  community-arctic-map-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com \
  --quiet
```

### 👋 HUMAN INTERVENTION SUMMARY - Phase 3

**For monitoring:**
1. ✅ Use `gcloud run logs` commands to view logs
2. ✅ Monitor service health from Cloud Console

**For rollback:**
1. ✅ List revisions and identify the working version
2. ✅ Run the update-traffic command to rollback

**For cleanup:**
1. ✅ Run deletion commands in order (service → images → repo → bucket → SA)
2. ✅ Verify deletion in Cloud Console

---

## Database File Handling

### Understanding the Database Requirement

The application requires a **4.3 GB SQLite database file** (`cpad.sqlite`) containing geospatial data. This file is **NOT** included in the repository due to its size.

### Two Approaches for Database Integration

#### Approach 1: Cloud Storage Bucket (Recommended for Production)

**Advantages:**
- Persistent storage
- Easy to update database independently
- Cost-effective ($0.023/GB/month)

**Setup:**

1. **Upload database to Cloud Storage** (already done in Phase 1):
   ```bash
   gsutil cp backend/cpad.sqlite gs://YOUR_PROJECT_ID-community-arctic-map-data/cpad.sqlite
   ```

2. **Mount in Cloud Run** (requires Cloud Run revision update):
   
   Currently, Cloud Run doesn't support direct volume mounts from Cloud Storage. You have two options:

   **Option A: Download at startup** (Current implementation):
   - Container downloads database from Cloud Storage on startup
   - Stored in container's ephemeral storage
   - Simple but slower startup

   **Option B: Cloud Run with GCS FUSE** (Requires additional setup):
   - Use GCS FUSE to mount Cloud Storage as a filesystem
   - More complex but better performance
   - See: https://cloud.google.com/run/docs/tutorials/network-filesystems-fuse

3. **Update the Dockerfile** to include download logic:
   ```dockerfile
   # Add to startup script
   RUN echo '#!/bin/bash\n\
   # Download database if not present\n\
   if [ ! -f /app/backend/cpad.sqlite ]; then\n\
     gsutil cp gs://PROJECT_ID-community-arctic-map-data/cpad.sqlite /app/backend/cpad.sqlite\n\
   fi\n\
   ' > /app/download-db.sh && chmod +x /app/download-db.sh
   ```

#### Approach 2: Include in Docker Image (Simpler for Testing)

**Advantages:**
- Faster startup time
- No external dependencies

**Disadvantages:**
- Large Docker image (4.3 GB+)
- Slow build and push times
- Database updates require new image build

**Setup:**

1. **Place database file in repository locally** (do NOT commit):
   ```bash
   # Ensure it's in .gitignore (it is)
   cp /path/to/your/cpad.sqlite backend/cpad.sqlite
   ```

2. **Update Dockerfile**:
   ```dockerfile
   # Add this line to copy the database into the image
   COPY backend/cpad.sqlite ./backend/cpad.sqlite
   ```

3. **Build and deploy** as normal

### Current Implementation Status

The current deployment configuration uses **Approach 1 (Cloud Storage)** with **Option A (download at startup)**.

**To use the database:**

1. Ensure `cpad.sqlite` is uploaded to Cloud Storage (done in Phase 1)
2. The container will download it on first startup
3. Database is cached in ephemeral storage for the life of the container

**To update the database:**

```bash
# Upload new version
gsutil cp backend/cpad.sqlite gs://YOUR_PROJECT_ID-community-arctic-map-data/cpad.sqlite

# Force new Cloud Run revision (will download new database)
gcloud run services update community-arctic-map \
  --region=us-east1 \
  --update-labels="db-updated=$(date +%s)"
```

---

## Troubleshooting

### Common Issues

#### 1. Build Fails: "VITE_MAPBOX_ACCESS_TOKEN is undefined"

**Solution:** Ensure the secret is set in GitHub Secrets:
```bash
gh secret set VITE_MAPBOX_ACCESS_TOKEN --repo=YOUR_REPO
```

#### 2. Deployment Fails: "Permission denied"

**Solution:** Check service account permissions:
```bash
# Re-run setup script
.deployment/scripts/gcp/setup-service-account.sh
```

#### 3. Service Returns 500: "Could not list layers"

**Solution:** Database file is missing or not accessible:
```bash
# Verify database in Cloud Storage
gsutil ls gs://YOUR_PROJECT_ID-community-arctic-map-data/cpad.sqlite

# Check Cloud Run logs
gcloud run logs read community-arctic-map --region=us-east1 --limit=50
```

#### 4. Frontend Loads But API Calls Fail

**Solution:** Check CORS and API routing:
- Ensure frontend is using relative paths (`/api/...`)
- Check `production.py` is correctly serving static files
- Verify environment variables in Cloud Run

#### 5. Slow Startup or Timeouts

**Solution:** Increase Cloud Run timeout and startup probe:
```bash
gcloud run services update community-arctic-map \
  --region=us-east1 \
  --timeout=600 \
  --cpu-boost
```

### Getting Help

1. **Check Cloud Run Logs**:
   ```bash
   gcloud run logs tail community-arctic-map --region=us-east1
   ```

2. **Check Service Status**:
   ```bash
   gcloud run services describe community-arctic-map --region=us-east1
   ```

3. **Validate Configuration**:
   ```bash
   .deployment/scripts/gcp/validate-gcp-config.sh
   .deployment/scripts/github/validate-github-config.sh
   ```

4. **Test Docker Image Locally**:
   ```bash
   docker build -f .deployment/Dockerfile -t test-image .
   docker run -p 8080:8080 -e PORT=8080 test-image
   ```

### Support Resources

- **Google Cloud Run Documentation**: https://cloud.google.com/run/docs
- **GitHub Actions Documentation**: https://docs.github.com/actions
- **Repository Issues**: https://github.com/brown-ccv/community-arctic-map/issues

---

## Cost Estimation

### Monthly Cost Breakdown (Typical Usage)

| Service | Usage | Cost |
|---------|-------|------|
| Cloud Run | 1M requests, 100 GB-hours | ~$18 |
| Artifact Registry | 10 GB storage | ~$1 |
| Cloud Storage | 5 GB storage | ~$0.12 |
| **Total** | | **~$19/month** |

**Notes:**
- Cloud Run scales to zero when not in use
- First 2M requests per month are free
- First 360,000 GB-seconds of memory are free

### Cost Optimization Tips

1. **Set min-instances=0**: Service scales to zero when idle
2. **Use appropriate memory**: 4Gi is needed for geospatial operations
3. **Enable CPU throttling for idle**: Reduces costs during low traffic
4. **Set appropriate timeouts**: Prevent long-running requests

---

## Next Steps

After successful deployment:

1. ✅ Visit your service URL to verify the application is working
2. ✅ Test all features (map loading, geocoding, downloads)
3. ✅ Set up monitoring and alerts in Google Cloud Console
4. ✅ Configure a custom domain (optional)
5. ✅ Enable Cloud CDN for better performance (optional)
6. ✅ Set up scheduled database updates if needed

---

## Appendix

### Environment Variables Reference

| Variable | Required | Description | Where Set |
|----------|----------|-------------|-----------|
| `PORT` | Yes | Port for Cloud Run (8080) | Cloud Run |
| `GOOGLE_SHEET_ID` | Yes | Google Sheet ID for layer themes | GitHub Secrets |
| `GOOGLE_SHEET_GID` | Yes | Google Sheet GID | GitHub Secrets |
| `VITE_MAPBOX_ACCESS_TOKEN` | Yes | Mapbox token (build-time) | GitHub Secrets |
| `GCP_PROJECT_ID` | Yes | GCP Project ID (CI/CD) | GitHub Secrets |
| `GCP_SERVICE_ACCOUNT_KEY` | Yes | Service account key (CI/CD) | GitHub Secrets |

### File Structure

```
community-arctic-map/
├── .deployment/
│   ├── Dockerfile              # Multi-stage build
│   ├── cloudbuild.yaml         # Cloud Build config
│   ├── cloudrun.yaml           # Cloud Run service config
│   ├── scripts/
│   │   ├── gcp/
│   │   │   ├── setup-service-account.sh
│   │   │   ├── setup-gcp-secrets.sh
│   │   │   └── validate-gcp-config.sh
│   │   └── github/
│   │       ├── setup-github-secrets.sh
│   │       ├── validate-github-config.sh
│   │       └── setup-github-environments.sh
│   └── DEPLOYMENT.md           # This file
├── .github/
│   └── workflows/
│       └── deploy.yml          # GitHub Actions workflow
├── backend/
│   ├── main.py                 # Main FastAPI application
│   ├── production.py           # Production wrapper (serves frontend)
│   ├── zip_downloads.py        # Download service
│   ├── requirements.txt        # Python dependencies
│   └── .env.example            # Environment template
├── frontend/
│   ├── src/                    # React source code
│   ├── package.json            # Node dependencies
│   └── .env.example            # Environment template
└── .env.example                # Root environment template
```

### Useful Commands Cheat Sheet

```bash
# GCP Authentication
gcloud auth login
gcloud config set project PROJECT_ID

# View Cloud Run services
gcloud run services list --region=us-east1

# View logs
gcloud run logs read community-arctic-map --region=us-east1 --limit=100

# Update environment variable
gcloud run services update community-arctic-map \
  --region=us-east1 \
  --update-env-vars="KEY=VALUE"

# View service details
gcloud run services describe community-arctic-map --region=us-east1

# GitHub Actions
gh workflow list
gh workflow run deploy.yml
gh run list --workflow=deploy.yml

# GitHub Secrets
gh secret list
gh secret set SECRET_NAME
gh secret remove SECRET_NAME

# Cloud Storage
gsutil ls gs://bucket-name
gsutil cp file.txt gs://bucket-name/
gsutil rm gs://bucket-name/file.txt
```

---

**End of Deployment Guide**

For questions or issues, please open an issue in the GitHub repository.
