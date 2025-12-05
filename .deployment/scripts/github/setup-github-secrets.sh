#!/bin/bash
# Setup script for configuring GitHub Secrets for CI/CD deployment
# This script uses the GitHub CLI to set repository secrets

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}==================================================================${NC}"
echo -e "${GREEN}🔐 GitHub Secrets Setup for Community Arctic Map${NC}"
echo -e "${GREEN}==================================================================${NC}"
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ Error: GitHub CLI (gh) is not installed${NC}"
    echo "Please install it from: https://cli.github.com/"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}⚠️  You are not authenticated with GitHub CLI${NC}"
    echo "Please run: gh auth login"
    exit 1
fi

# Get repository information
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
if [ -z "$REPO" ]; then
    echo -e "${RED}❌ Error: Could not determine repository${NC}"
    echo "Please run this script from within your repository"
    exit 1
fi

echo -e "${GREEN}📊 Repository: $REPO${NC}"
echo ""

# Function to set a secret
set_secret() {
    local secret_name=$1
    local secret_description=$2
    local is_required=$3
    local validation_pattern=$4
    local validation_message=$5
    
    echo -e "${YELLOW}🔑 Setting secret: $secret_name${NC}"
    echo "   Description: $secret_description"
    
    if [ "$is_required" = "true" ]; then
        echo -e "${RED}   (REQUIRED)${NC}"
    else
        echo -e "${YELLOW}   (Optional - press Enter to skip)${NC}"
    fi
    
    echo -e "${YELLOW}   Enter value:${NC}"
    read -rs secret_value
    echo ""
    
    if [ -z "$secret_value" ]; then
        if [ "$is_required" = "true" ]; then
            echo -e "${RED}❌ Error: This secret is required${NC}"
            exit 1
        else
            echo -e "${YELLOW}⚠️  Skipping $secret_name${NC}"
            echo ""
            return
        fi
    fi
    
    # Validate format if pattern provided
    if [ -n "$validation_pattern" ] && ! [[ "$secret_value" =~ $validation_pattern ]]; then
        echo -e "${RED}❌ Error: Invalid format${NC}"
        echo "   $validation_message"
        exit 1
    fi
    
    # Set the secret using gh CLI
    echo -n "$secret_value" | gh secret set "$secret_name" --repo="$REPO"
    echo -e "${GREEN}✅ Secret $secret_name set successfully${NC}"
    echo ""
}

# Function to set a secret from file
set_secret_from_file() {
    local secret_name=$1
    local secret_description=$2
    local file_path=$3
    
    echo -e "${YELLOW}🔑 Setting secret: $secret_name${NC}"
    echo "   Description: $secret_description"
    echo -e "${YELLOW}   Enter path to file (or press Enter for: $file_path):${NC}"
    read -r user_file_path
    
    if [ -z "$user_file_path" ]; then
        user_file_path=$file_path
    fi
    
    if [ ! -f "$user_file_path" ]; then
        echo -e "${RED}❌ Error: File not found: $user_file_path${NC}"
        echo -e "${YELLOW}   Please create this file first by running:${NC}"
        echo "   .deployment/scripts/gcp/setup-service-account.sh"
        exit 1
    fi
    
    gh secret set "$secret_name" --repo="$REPO" < "$user_file_path"
    echo -e "${GREEN}✅ Secret $secret_name set successfully${NC}"
    echo ""
}

echo -e "${YELLOW}📝 This script will configure GitHub Secrets for CI/CD deployment${NC}"
echo ""

# Required secrets
echo -e "${GREEN}--- Required Secrets (CI/CD) ---${NC}"
set_secret "GCP_PROJECT_ID" "Your Google Cloud Project ID" "true" "" ""
set_secret_from_file "GCP_SERVICE_ACCOUNT_KEY" "Service account key JSON file" "./community-arctic-map-sa-key.json"

# Application secrets (runtime)
echo -e "${GREEN}--- Application Secrets (Runtime) ---${NC}"
set_secret "GOOGLE_SHEET_ID" "Google Sheet ID for layer theme organization" "true" "" ""
set_secret "GOOGLE_SHEET_GID" "Google Sheet GID (tab identifier)" "true" "^[0-9]{1,20}$" "GID must be 1-20 numeric digits"
set_secret "VITE_MAPBOX_ACCESS_TOKEN" "Mapbox access token for frontend" "true" "^pk\.[a-zA-Z0-9._-]{50,}$" "Mapbox public token must start with 'pk.' followed by at least 50 characters"

# Optional secrets
echo -e "${GREEN}--- Optional Secrets ---${NC}"
set_secret "SLACK_WEBHOOK_URL" "Slack webhook for deployment notifications" "false" "" ""

# Summary
echo -e "${GREEN}==================================================================${NC}"
echo -e "${GREEN}✅ GitHub Secrets Setup Complete!${NC}"
echo -e "${GREEN}==================================================================${NC}"
echo ""
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo "1. Verify secrets with: .deployment/scripts/github/validate-github-config.sh"
echo "2. Trigger deployment from GitHub Actions: Actions → Deploy to Google Cloud Run"
echo ""
echo -e "${YELLOW}🔒 Security Reminder:${NC}"
echo "   - Never commit the service account key file to version control"
echo "   - Delete the key file after setup if no longer needed"
echo ""
