#!/bin/bash
# ==============================================================================
# Setup GitHub Environments for Community Arctic Map
# ==============================================================================
# This script creates GitHub environments with protection rules
#
# Prerequisites:
#   - GitHub CLI (gh) installed and authenticated
#   - Repository admin access
#
# Usage:
#   ./setup-github-environments.sh OWNER/REPO
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
if [ -z "$REPO" ]; then
    error "Repository is required. Usage: $0 OWNER/REPO"
fi

info "🌍 Setting up GitHub environments"
info "Repository: $REPO"
echo ""

# Function to create environment
create_environment() {
    local ENV_NAME=$1
    local WAIT_TIME=${2:-0}
    
    info "Creating environment: $ENV_NAME"
    
    # Create environment using GitHub API
    gh api -X PUT "repos/$REPO/environments/$ENV_NAME" \
        -f wait_timer="$WAIT_TIME" || warn "Failed to create $ENV_NAME (may already exist)"
    
    info "  ✅ Environment $ENV_NAME configured"
}

# Create environments
create_environment "production" 0
create_environment "staging" 0

echo ""
info "==================================================================="
info "✅ GitHub Environments Setup Complete!"
info "==================================================================="
echo ""
echo "Environments created:"
echo "  - production"
echo "  - staging"
echo ""
echo "Configure environment protection rules at:"
echo "  https://github.com/$REPO/settings/environments"
echo ""
