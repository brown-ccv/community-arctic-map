#!/bin/bash
# Setup script for creating Google Cloud Platform service account and IAM roles
# This script creates a service account with the necessary permissions for Cloud Run deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}==================================================================${NC}"
echo -e "${GREEN}🔧 GCP Service Account Setup for Community Arctic Map${NC}"
echo -e "${GREEN}==================================================================${NC}"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ Error: gcloud CLI is not installed${NC}"
    echo "Please install it from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if user is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    echo -e "${YELLOW}⚠️  You are not authenticated with gcloud${NC}"
    echo "Please run: gcloud auth login"
    exit 1
fi

# Prompt for GCP project ID
echo -e "${YELLOW}📋 Enter your GCP Project ID:${NC}"
read -r PROJECT_ID

if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}❌ Error: Project ID cannot be empty${NC}"
    exit 1
fi

# Set the project
gcloud config set project "$PROJECT_ID"

# Variables
SERVICE_NAME="community-arctic-map"
SERVICE_ACCOUNT_NAME="${SERVICE_NAME}-sa"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
REGION="us-east1"
ARTIFACT_REGISTRY_REPO="arctic-map-repo"

echo ""
echo -e "${GREEN}📊 Configuration:${NC}"
echo "  Project ID: $PROJECT_ID"
echo "  Service Name: $SERVICE_NAME"
echo "  Service Account: $SERVICE_ACCOUNT_EMAIL"
echo "  Region: $REGION"
echo ""

# Enable required APIs
echo -e "${GREEN}🔌 Enabling required Google Cloud APIs...${NC}"
gcloud services enable \
    run.googleapis.com \
    artifactregistry.googleapis.com \
    cloudbuild.googleapis.com \
    secretmanager.googleapis.com \
    storage.googleapis.com \
    --project="$PROJECT_ID"

echo -e "${GREEN}✅ APIs enabled successfully${NC}"
echo ""

# Create service account
echo -e "${GREEN}👤 Creating service account: $SERVICE_ACCOUNT_NAME${NC}"
if gcloud iam service-accounts describe "$SERVICE_ACCOUNT_EMAIL" --project="$PROJECT_ID" &> /dev/null; then
    echo -e "${YELLOW}⚠️  Service account already exists${NC}"
else
    gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
        --display-name="Community Arctic Map Cloud Run Service Account" \
        --description="Service account for running Community Arctic Map on Cloud Run" \
        --project="$PROJECT_ID"
    echo -e "${GREEN}✅ Service account created${NC}"
fi
echo ""

# Grant IAM roles to service account
echo -e "${GREEN}🔐 Granting IAM roles to service account...${NC}"

# Required roles for Cloud Run
ROLES=(
    "roles/run.invoker"
    "roles/artifactregistry.reader"
    "roles/secretmanager.secretAccessor"
    "roles/storage.objectViewer"
)

for role in "${ROLES[@]}"; do
    echo "  Granting $role..."
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
        --role="$role" \
        --condition=None \
        --quiet
done

echo -e "${GREEN}✅ IAM roles granted successfully${NC}"
echo ""

# Create Artifact Registry repository
echo -e "${GREEN}📦 Creating Artifact Registry repository...${NC}"
if gcloud artifacts repositories describe "$ARTIFACT_REGISTRY_REPO" \
    --location="$REGION" \
    --project="$PROJECT_ID" &> /dev/null; then
    echo -e "${YELLOW}⚠️  Artifact Registry repository already exists${NC}"
else
    gcloud artifacts repositories create "$ARTIFACT_REGISTRY_REPO" \
        --repository-format=docker \
        --location="$REGION" \
        --description="Docker repository for Community Arctic Map" \
        --project="$PROJECT_ID"
    echo -e "${GREEN}✅ Artifact Registry repository created${NC}"
fi
echo ""

# Create Cloud Storage bucket for database file
BUCKET_NAME="${PROJECT_ID}-${SERVICE_NAME}-data"
echo -e "${GREEN}🗄️  Creating Cloud Storage bucket for database file...${NC}"
if gsutil ls -b "gs://$BUCKET_NAME" &> /dev/null; then
    echo -e "${YELLOW}⚠️  Storage bucket already exists${NC}"
else
    gsutil mb -p "$PROJECT_ID" -l "$REGION" "gs://$BUCKET_NAME"
    echo -e "${GREEN}✅ Storage bucket created: gs://$BUCKET_NAME${NC}"
fi
echo ""

# Create service account key for GitHub Actions
echo -e "${GREEN}🔑 Creating service account key for GitHub Actions...${NC}"
KEY_FILE="${SERVICE_ACCOUNT_NAME}-key.json"

if [ -f "$KEY_FILE" ]; then
    echo -e "${YELLOW}⚠️  Key file already exists: $KEY_FILE${NC}"
    echo -e "${YELLOW}   Skipping key creation to avoid overwriting${NC}"
else
    gcloud iam service-accounts keys create "$KEY_FILE" \
        --iam-account="$SERVICE_ACCOUNT_EMAIL" \
        --project="$PROJECT_ID"
    echo -e "${GREEN}✅ Service account key created: $KEY_FILE${NC}"
    echo -e "${YELLOW}⚠️  IMPORTANT: Keep this file secure and do not commit it to version control${NC}"
fi
echo ""

# Summary
echo -e "${GREEN}==================================================================${NC}"
echo -e "${GREEN}✅ GCP Service Account Setup Complete!${NC}"
echo -e "${GREEN}==================================================================${NC}"
echo ""
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo ""
echo "1. Add the following secrets to your GitHub repository:"
echo "   - GCP_PROJECT_ID: $PROJECT_ID"
echo "   - GCP_SERVICE_ACCOUNT_KEY: (contents of $KEY_FILE)"
echo ""
echo "2. Upload your cpad.sqlite file to Cloud Storage:"
echo "   gsutil cp backend/cpad.sqlite gs://$BUCKET_NAME/cpad.sqlite"
echo ""
echo "3. Run the GitHub secrets setup script:"
echo "   .deployment/scripts/github/setup-github-secrets.sh"
echo ""
echo -e "${YELLOW}🔒 Security Reminder:${NC}"
echo "   - Delete the key file after adding it to GitHub Secrets:"
echo "     rm $KEY_FILE"
echo ""
