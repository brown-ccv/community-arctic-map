#!/bin/bash
# ==============================================================================
# Setup GitHub Secrets for Community Arctic Map Deployment
# ==============================================================================
# This script configures GitHub Secrets required for the deployment workflow.
#
# Prerequisites:
#   - GitHub CLI (gh) installed and authenticated
#   - Service account key created (run setup-service-account.sh first)
#   - Repository access (admin permissions)
#
# Authentication:
#   gh auth login --scopes repo,workflow,admin:repo_hook
#
# Usage:
#   ./setup-github-secrets.sh OWNER/REPO
# ==============================================================================

set -e

# Configuration
REPO="${1:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
error() {
    echo -e "${RED}❌ Error: $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${GREEN}ℹ️  $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

prompt() {
    echo -e "${BLUE}🔹 $1${NC}"
}

# Validate inputs
if [ -z "$REPO" ]; then
    error "Repository is required. Usage: $0 OWNER/REPO (e.g., brown-ccv/community-arctic-map)"
fi

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    error "GitHub CLI (gh) is not installed. Install from: https://cli.github.com/"
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    error "Not authenticated with GitHub CLI. Run: gh auth login --scopes repo,workflow,admin:repo_hook"
fi

info "🔐 Setting up GitHub Secrets for deployment"
info "Repository: $REPO"
echo ""

# Function to set a secret
set_secret() {
    local SECRET_NAME=$1
    local PROMPT_TEXT=$2
    local IS_FILE=${3:-false}
    local DEFAULT_VALUE=${4:-}
    
    prompt "$PROMPT_TEXT"
    
    if [ "$IS_FILE" = true ]; then
        read -e -r SECRET_VALUE
        if [ -f "$SECRET_VALUE" ]; then
            info "  Setting secret from file: $SECRET_VALUE"
            gh secret set "$SECRET_NAME" --repo="$REPO" < "$SECRET_VALUE" || warn "Failed to set $SECRET_NAME"
            info "  ✅ Secret $SECRET_NAME configured"
        else
            warn "  File not found: $SECRET_VALUE, skipping $SECRET_NAME"
        fi
    else
        if [ -n "$DEFAULT_VALUE" ]; then
            read -r SECRET_VALUE
            SECRET_VALUE=${SECRET_VALUE:-$DEFAULT_VALUE}
        else
            read -r SECRET_VALUE
        fi
        
        if [ -z "$SECRET_VALUE" ]; then
            warn "  Skipping $SECRET_NAME (no value provided)"
            return
        fi
        
        echo -n "$SECRET_VALUE" | gh secret set "$SECRET_NAME" --repo="$REPO" || warn "Failed to set $SECRET_NAME"
        info "  ✅ Secret $SECRET_NAME configured"
    fi
}

echo ""
info "==================================================================="
info "📝 Please provide the following secret values"
info "==================================================================="
echo ""

# GCP Configuration
info "Google Cloud Platform Configuration"
set_secret \
    "GCP_PROJECT_ID" \
    "Enter GCP Project ID:"

set_secret \
    "GCP_SERVICE_ACCOUNT_KEY" \
    "Enter path to service account key JSON file:" \
    true

# Mapbox Configuration
echo ""
info "Mapbox Configuration"
set_secret \
    "VITE_MAPBOX_ACCESS_TOKEN" \
    "Enter Mapbox access token:"

# Google Sheets Configuration
echo ""
info "Google Sheets Configuration"
set_secret \
    "GOOGLE_SHEET_ID" \
    "Enter Google Sheets ID:"

set_secret \
    "GOOGLE_SHEET_GID" \
    "Enter Google Sheets GID:"

echo ""
info "==================================================================="
info "✅ GitHub Secrets Setup Complete!"
info "==================================================================="
echo ""
echo "Secrets configured for repository: $REPO"
echo ""
echo "To verify secrets:"
echo "  gh secret list --repo=$REPO"
echo ""
echo "Next steps:"
echo "1. Verify secrets are set correctly: ./validate-github-config.sh $REPO"
echo "2. Enable GitHub Actions in repository settings"
echo "3. Trigger deployment workflow from Actions tab"
echo ""
