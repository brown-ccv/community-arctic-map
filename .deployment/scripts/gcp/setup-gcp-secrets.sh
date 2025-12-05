#!/bin/bash
# Setup script for creating secrets in Google Cloud Secret Manager
# This script creates secrets for runtime application configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}==================================================================${NC}"
echo -e "${GREEN}🔐 GCP Secret Manager Setup for Community Arctic Map${NC}"
echo -e "${GREEN}==================================================================${NC}"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ Error: gcloud CLI is not installed${NC}"
    exit 1
fi

# Get project ID
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    echo -e "${YELLOW}📋 Enter your GCP Project ID:${NC}"
    read -r PROJECT_ID
    gcloud config set project "$PROJECT_ID"
fi

echo -e "${GREEN}📊 Using Project: $PROJECT_ID${NC}"
echo ""

# Enable Secret Manager API
echo -e "${GREEN}🔌 Enabling Secret Manager API...${NC}"
gcloud services enable secretmanager.googleapis.com --project="$PROJECT_ID"
echo -e "${GREEN}✅ Secret Manager API enabled${NC}"
echo ""

# Function to create or update a secret
create_or_update_secret() {
    local secret_name=$1
    local secret_description=$2
    
    echo -e "${YELLOW}🔑 Setting up secret: $secret_name${NC}"
    echo "   Description: $secret_description"
    echo -e "${YELLOW}   Enter value for $secret_name:${NC}"
    read -rs secret_value
    echo ""
    
    if [ -z "$secret_value" ]; then
        echo -e "${YELLOW}⚠️  Skipping empty value for $secret_name${NC}"
        return
    fi
    
    # Check if secret exists
    if gcloud secrets describe "$secret_name" --project="$PROJECT_ID" &> /dev/null; then
        echo "   Secret exists, adding new version..."
        echo -n "$secret_value" | gcloud secrets versions add "$secret_name" \
            --data-file=- \
            --project="$PROJECT_ID"
    else
        echo "   Creating new secret..."
        echo -n "$secret_value" | gcloud secrets create "$secret_name" \
            --data-file=- \
            --replication-policy="automatic" \
            --project="$PROJECT_ID"
    fi
    
    echo -e "${GREEN}✅ Secret $secret_name configured${NC}"
    echo ""
}

# Note about runtime secrets
echo -e "${YELLOW}📝 Note: The following secrets are used by the application at runtime${NC}"
echo "   These are different from GitHub Secrets (which are for CI/CD)"
echo ""

# Google Sheets Configuration
echo -e "${GREEN}--- Google Sheets Configuration ---${NC}"
create_or_update_secret "GOOGLE_SHEET_ID" "Google Sheet ID for layer theme organization"
create_or_update_secret "GOOGLE_SHEET_GID" "Google Sheet GID (tab/sheet identifier)"
echo ""

# Mapbox Configuration (if using server-side rendering or API calls)
echo -e "${GREEN}--- Mapbox Configuration (optional) ---${NC}"
echo -e "${YELLOW}ℹ️  Mapbox token is typically a build-time variable, not a runtime secret${NC}"
echo -e "${YELLOW}   Only create this if you need server-side Mapbox API access${NC}"
echo -e "${YELLOW}   Press Enter to skip, or type 'yes' to add:${NC}"
read -r add_mapbox
if [ "$add_mapbox" = "yes" ]; then
    create_or_update_secret "MAPBOX_ACCESS_TOKEN" "Mapbox API access token"
fi
echo ""

# Grant Cloud Run service account access to secrets
SERVICE_ACCOUNT="community-arctic-map-sa@${PROJECT_ID}.iam.gserviceaccount.com"
echo -e "${GREEN}🔐 Granting Cloud Run service account access to secrets...${NC}"

SECRETS=("GOOGLE_SHEET_ID" "GOOGLE_SHEET_GID")
for secret in "${SECRETS[@]}"; do
    if gcloud secrets describe "$secret" --project="$PROJECT_ID" &> /dev/null; then
        echo "   Granting access to $secret..."
        gcloud secrets add-iam-policy-binding "$secret" \
            --member="serviceAccount:$SERVICE_ACCOUNT" \
            --role="roles/secretmanager.secretAccessor" \
            --project="$PROJECT_ID" \
            --quiet
    fi
done

echo -e "${GREEN}✅ Secrets access granted to service account${NC}"
echo ""

# Summary
echo -e "${GREEN}==================================================================${NC}"
echo -e "${GREEN}✅ GCP Secret Manager Setup Complete!${NC}"
echo -e "${GREEN}==================================================================${NC}"
echo ""
echo -e "${YELLOW}📋 Configured Secrets:${NC}"
gcloud secrets list --project="$PROJECT_ID" --format="table(name,createTime)"
echo ""
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo "1. Update your Cloud Run deployment to use these secrets"
echo "2. Test the deployment to ensure secrets are accessible"
echo ""
echo -e "${YELLOW}💡 To update Cloud Run with secrets, run:${NC}"
echo "   gcloud run services update community-arctic-map \\"
echo "     --region=us-east1 \\"
echo "     --update-secrets=GOOGLE_SHEET_ID=GOOGLE_SHEET_ID:latest,GOOGLE_SHEET_GID=GOOGLE_SHEET_GID:latest"
echo ""
