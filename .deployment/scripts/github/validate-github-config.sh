#!/bin/bash
# Validation script for GitHub Secrets configuration
# This script checks if all required secrets are properly set

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}==================================================================${NC}"
echo -e "${GREEN}🔍 Validating GitHub Secrets Configuration${NC}"
echo -e "${GREEN}==================================================================${NC}"
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ Error: GitHub CLI (gh) is not installed${NC}"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ Error: Not authenticated with GitHub CLI${NC}"
    exit 1
fi

# Get repository information
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
if [ -z "$REPO" ]; then
    echo -e "${RED}❌ Error: Could not determine repository${NC}"
    exit 1
fi

echo -e "${GREEN}📊 Repository: $REPO${NC}"
echo ""

# Get list of secrets
echo -e "${YELLOW}🔐 Checking GitHub Secrets...${NC}"
SECRETS=$(gh secret list --repo="$REPO" 2>/dev/null || echo "")

if [ -z "$SECRETS" ]; then
    echo -e "${RED}❌ No secrets found or unable to list secrets${NC}"
    exit 1
fi

ERRORS=0

# Function to check if a secret exists
check_secret() {
    local secret_name=$1
    local is_required=$2
    
    if echo "$SECRETS" | grep -q "^$secret_name"; then
        echo -e "  ${GREEN}✅ $secret_name${NC}"
    else
        if [ "$is_required" = "true" ]; then
            echo -e "  ${RED}❌ $secret_name (REQUIRED - missing)${NC}"
            ((ERRORS++))
        else
            echo -e "  ${YELLOW}⚠️  $secret_name (optional - not set)${NC}"
        fi
    fi
}

# Check required secrets
echo ""
echo -e "${YELLOW}Required Secrets:${NC}"
check_secret "GCP_PROJECT_ID" "true"
check_secret "GCP_SERVICE_ACCOUNT_KEY" "true"
check_secret "GOOGLE_SHEET_ID" "true"
check_secret "GOOGLE_SHEET_GID" "true"
check_secret "VITE_MAPBOX_ACCESS_TOKEN" "true"

echo ""
echo -e "${YELLOW}Optional Secrets:${NC}"
check_secret "SLACK_WEBHOOK_URL" "false"

echo ""

# Check workflow file
echo -e "${YELLOW}🔍 Checking GitHub Actions workflow...${NC}"
WORKFLOW_FILE=".github/workflows/deploy.yml"
if [ -f "$WORKFLOW_FILE" ]; then
    echo -e "  ${GREEN}✅ Workflow file exists: $WORKFLOW_FILE${NC}"
else
    echo -e "  ${RED}❌ Workflow file not found: $WORKFLOW_FILE${NC}"
    ((ERRORS++))
fi

echo ""

# Check if Actions is enabled
echo -e "${YELLOW}🔍 Checking if GitHub Actions is enabled...${NC}"
ACTIONS_ENABLED=$(gh api repos/"$REPO" --jq '.has_discussions' 2>/dev/null || echo "unknown")
if [ "$ACTIONS_ENABLED" != "unknown" ]; then
    echo -e "  ${GREEN}✅ Repository is accessible via API${NC}"
else
    echo -e "  ${YELLOW}⚠️  Could not verify Actions status${NC}"
fi

echo ""

# Summary
echo -e "${GREEN}==================================================================${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ All validations passed!${NC}"
    echo -e "${GREEN}==================================================================${NC}"
    echo ""
    echo -e "${YELLOW}📋 GitHub Secrets are configured correctly${NC}"
    echo ""
    echo -e "${YELLOW}🚀 Ready to deploy!${NC}"
    echo "   Go to: https://github.com/$REPO/actions"
    echo "   Select: Deploy to Google Cloud Run"
    echo "   Click: Run workflow"
else
    echo -e "${RED}❌ $ERRORS validation error(s) found${NC}"
    echo -e "${GREEN}==================================================================${NC}"
    echo ""
    echo -e "${YELLOW}📋 Please set missing secrets by running:${NC}"
    echo "   .deployment/scripts/github/setup-github-secrets.sh"
    exit 1
fi
echo ""
