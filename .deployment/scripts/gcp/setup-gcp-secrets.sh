#!/bin/bash
# ==============================================================================
# Setup GCP Secret Manager Secrets for Community Arctic Map
# ==============================================================================
# This script creates and populates secrets in Google Cloud Secret Manager
# for the runtime application configuration.
#
# Prerequisites:
#   - gcloud CLI installed and configured
#   - Service account created (run setup-service-account.sh first)
#   - Secret Manager API enabled
#
# Usage:
#   ./setup-gcp-secrets.sh PROJECT_ID
# ==============================================================================

set -e

# Configuration
PROJECT_ID="${1:-}"

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
if [ -z "$PROJECT_ID" ]; then
    error "PROJECT_ID is required. Usage: $0 PROJECT_ID"
fi

info "🔐 Setting up GCP Secret Manager secrets"
info "Project ID: $PROJECT_ID"

# Set the active project
gcloud config set project "$PROJECT_ID" || error "Failed to set project"

# Enable Secret Manager API
info "🔧 Enabling Secret Manager API..."
gcloud services enable secretmanager.googleapis.com || error "Failed to enable Secret Manager API"

# Function to create or update a secret
create_or_update_secret() {
    local SECRET_NAME=$1
    local SECRET_DESCRIPTION=$2
    local PROMPT_TEXT=$3
    
    prompt "$PROMPT_TEXT"
    read -r SECRET_VALUE
    
    if [ -z "$SECRET_VALUE" ]; then
        warn "Skipping $SECRET_NAME (no value provided)"
        return
    fi
    
    # Check if secret exists
    if gcloud secrets describe "$SECRET_NAME" --project="$PROJECT_ID" &>/dev/null; then
        info "  Updating existing secret: $SECRET_NAME"
        echo -n "$SECRET_VALUE" | gcloud secrets versions add "$SECRET_NAME" \
            --data-file=- \
            --project="$PROJECT_ID" || warn "Failed to update $SECRET_NAME"
    else
        info "  Creating new secret: $SECRET_NAME"
        echo -n "$SECRET_VALUE" | gcloud secrets create "$SECRET_NAME" \
            --data-file=- \
            --replication-policy="automatic" \
            --project="$PROJECT_ID" || warn "Failed to create $SECRET_NAME"
    fi
    
    info "  ✅ Secret $SECRET_NAME configured"
}

echo ""
info "==================================================================="
info "📝 Please provide the following secret values"
info "==================================================================="
echo ""

# Google Sheets Configuration
info "Google Sheets Configuration (for layer hierarchy)"
create_or_update_secret \
    "google-sheet-id" \
    "Google Sheets ID for layer hierarchy" \
    "Enter Google Sheets ID (from spreadsheet URL):"

create_or_update_secret \
    "google-sheet-gid" \
    "Google Sheets GID for layer hierarchy" \
    "Enter Google Sheets GID (from spreadsheet URL):"

echo ""
info "==================================================================="
info "✅ GCP Secrets Setup Complete!"
info "==================================================================="
echo ""
echo "Secrets created in project: $PROJECT_ID"
echo ""
echo "To verify secrets:"
echo "  gcloud secrets list --project=$PROJECT_ID"
echo ""
echo "To access a secret:"
echo "  gcloud secrets versions access latest --secret=SECRET_NAME --project=$PROJECT_ID"
echo ""
echo "Next steps:"
echo "1. Verify secrets are accessible by the service account"
echo "2. Update Cloud Run deployment to use these secrets"
echo "3. Run: ./validate-gcp-secrets.sh $PROJECT_ID"
echo ""
