#!/bin/bash
# ==============================================================================
# Validate GCP Secret Manager Configuration
# ==============================================================================
# This script validates that all required secrets exist and are accessible
#
# Prerequisites:
#   - gcloud CLI installed and configured
#   - Secrets created (run setup-gcp-secrets.sh first)
#
# Usage:
#   ./validate-gcp-secrets.sh PROJECT_ID
# ==============================================================================

set -e

# Configuration
PROJECT_ID="${1:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
error() {
    echo -e "${RED}❌ $1${NC}" >&2
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Validate inputs
if [ -z "$PROJECT_ID" ]; then
    echo "Usage: $0 PROJECT_ID"
    exit 1
fi

echo "🔍 Validating GCP Secret Manager configuration..."
echo "Project ID: $PROJECT_ID"
echo ""

# Set the active project
gcloud config set project "$PROJECT_ID" --quiet

# Required secrets
REQUIRED_SECRETS=(
    "google-sheet-id"
    "google-sheet-gid"
)

VALIDATION_FAILED=0

# Check each secret
for SECRET in "${REQUIRED_SECRETS[@]}"; do
    echo -n "Checking $SECRET... "
    
    if gcloud secrets describe "$SECRET" --project="$PROJECT_ID" &>/dev/null; then
        # Try to access the latest version
        if gcloud secrets versions access latest --secret="$SECRET" --project="$PROJECT_ID" &>/dev/null; then
            success "OK"
        else
            error "FAILED (cannot access)"
            VALIDATION_FAILED=1
        fi
    else
        error "FAILED (does not exist)"
        VALIDATION_FAILED=1
    fi
done

echo ""

if [ $VALIDATION_FAILED -eq 0 ]; then
    success "==================================================================="
    success "✅ All secrets are configured correctly!"
    success "==================================================================="
    exit 0
else
    error "==================================================================="
    error "❌ Some secrets are missing or inaccessible"
    error "==================================================================="
    echo ""
    echo "To fix:"
    echo "  1. Run: ./setup-gcp-secrets.sh $PROJECT_ID"
    echo "  2. Verify service account permissions"
    echo ""
    exit 1
fi
