#!/bin/bash
# ==============================================================================
# Validate GitHub Configuration for Community Arctic Map Deployment
# ==============================================================================
# This script validates that all required GitHub Secrets are configured
#
# Prerequisites:
#   - GitHub CLI (gh) installed and authenticated
#   - Secrets configured (run setup-github-secrets.sh first)
#
# Usage:
#   ./validate-github-config.sh OWNER/REPO
# ==============================================================================

set -e

# Configuration
REPO="${1:-}"

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
if [ -z "$REPO" ]; then
    echo "Usage: $0 OWNER/REPO (e.g., brown-ccv/community-arctic-map)"
    exit 1
fi

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    error "GitHub CLI (gh) is not installed"
    exit 1
fi

echo "🔍 Validating GitHub configuration..."
echo "Repository: $REPO"
echo ""

# Required secrets
REQUIRED_SECRETS=(
    "GCP_PROJECT_ID"
    "GCP_SERVICE_ACCOUNT_KEY"
    "VITE_MAPBOX_ACCESS_TOKEN"
    "GOOGLE_SHEET_ID"
    "GOOGLE_SHEET_GID"
)

VALIDATION_FAILED=0

# Get list of configured secrets
CONFIGURED_SECRETS=$(gh secret list --repo="$REPO" --json name --jq '.[].name' 2>/dev/null || echo "")

# Check each required secret
for SECRET in "${REQUIRED_SECRETS[@]}"; do
    echo -n "Checking $SECRET... "
    
    if echo "$CONFIGURED_SECRETS" | grep -q "^${SECRET}$"; then
        success "OK"
    else
        error "FAILED (not found)"
        VALIDATION_FAILED=1
    fi
done

echo ""

# Check if GitHub Actions is enabled
echo -n "Checking GitHub Actions... "
if gh api "repos/$REPO/actions/permissions" --jq '.enabled' 2>/dev/null | grep -q "true"; then
    success "ENABLED"
else
    warn "DISABLED or cannot check"
    echo "  Enable in: Settings → Actions → General"
fi

echo ""

if [ $VALIDATION_FAILED -eq 0 ]; then
    success "==================================================================="
    success "✅ All GitHub Secrets are configured correctly!"
    success "==================================================================="
    echo ""
    echo "You can now trigger the deployment workflow:"
    echo "  1. Go to: https://github.com/$REPO/actions"
    echo "  2. Select: '🚀 Deploy to Google Cloud Run'"
    echo "  3. Click: 'Run workflow'"
    echo ""
    exit 0
else
    error "==================================================================="
    error "❌ Some GitHub Secrets are missing"
    error "==================================================================="
    echo ""
    echo "To fix:"
    echo "  1. Run: ./setup-github-secrets.sh $REPO"
    echo "  2. Verify you have admin access to the repository"
    echo ""
    exit 1
fi
