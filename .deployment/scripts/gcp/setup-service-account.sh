#!/bin/bash
# ==============================================================================
# Setup Google Cloud Service Account for Community Arctic Map
# ==============================================================================
# This script creates a service account with the necessary IAM roles for
# deploying and running the Community Arctic Map on Cloud Run.
#
# Prerequisites:
#   - gcloud CLI installed and configured
#   - Authenticated with sufficient permissions (Owner or Project IAM Admin)
#   - Billing enabled on the project
#
# Usage:
#   ./setup-service-account.sh PROJECT_ID [SERVICE_ACCOUNT_NAME]
# ==============================================================================

set -e

# Configuration
PROJECT_ID="${1:-}"
SERVICE_NAME="${2:-community-arctic-map}"
SA_NAME="${SERVICE_NAME}-sa"
SA_DISPLAY_NAME="Community Arctic Map Service Account"
SA_DESCRIPTION="Service account for Community Arctic Map Cloud Run service"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Validate inputs
if [ -z "$PROJECT_ID" ]; then
    error "PROJECT_ID is required. Usage: $0 PROJECT_ID [SERVICE_ACCOUNT_NAME]"
fi

info "🚀 Setting up service account for Community Arctic Map"
info "Project ID: $PROJECT_ID"
info "Service Account: $SA_NAME"

# Set the active project
info "📋 Setting active project..."
gcloud config set project "$PROJECT_ID" || error "Failed to set project"

# Create service account
info "👤 Creating service account..."
if gcloud iam service-accounts describe "${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" &>/dev/null; then
    warn "Service account already exists, skipping creation"
else
    gcloud iam service-accounts create "$SA_NAME" \
        --display-name="$SA_DISPLAY_NAME" \
        --description="$SA_DESCRIPTION" || error "Failed to create service account"
    info "✅ Service account created"
fi

SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Grant IAM roles
info "🔐 Granting IAM roles..."

# Required roles for Cloud Run deployment
ROLES=(
    "roles/run.admin"                    # Deploy and manage Cloud Run services
    "roles/iam.serviceAccountUser"       # Use service accounts
    "roles/artifactregistry.writer"      # Push images to Artifact Registry
    "roles/storage.objectViewer"         # Read from Cloud Storage (for data files)
    "roles/secretmanager.secretAccessor" # Access secrets from Secret Manager
)

for ROLE in "${ROLES[@]}"; do
    info "  Granting $ROLE..."
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:${SA_EMAIL}" \
        --role="$ROLE" \
        --condition=None \
        --quiet || warn "Failed to grant $ROLE (may already exist)"
done

info "✅ IAM roles granted"

# Create and download service account key
info "🔑 Creating service account key..."
KEY_FILE="${SA_NAME}-key.json"

gcloud iam service-accounts keys create "$KEY_FILE" \
    --iam-account="$SA_EMAIL" || error "Failed to create service account key"

info "✅ Service account key created: $KEY_FILE"
warn "⚠️  Keep this key file secure! It provides access to your GCP resources."
warn "⚠️  Add this key to GitHub Secrets as GCP_SERVICE_ACCOUNT_KEY"

# Display summary
echo ""
info "==================================================================="
info "✅ Service Account Setup Complete!"
info "==================================================================="
echo ""
echo "Service Account Email: ${SA_EMAIL}"
echo "Service Account Key:   ${KEY_FILE}"
echo ""
echo "Next steps:"
echo "1. Copy the contents of ${KEY_FILE}"
echo "2. Add it to GitHub Secrets as: GCP_SERVICE_ACCOUNT_KEY"
echo "3. Run the GitHub secrets setup script: ./setup-github-secrets.sh"
echo ""
warn "⚠️  Do NOT commit ${KEY_FILE} to version control!"
echo ""
