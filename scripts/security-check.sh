#!/bin/bash

# Health Exporter Security Check Script
# Runs before commits to ensure no sensitive data is included

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔒 Health Exporter Security Check${NC}"
echo "================================"

# Check for certificates and provisioning profiles
echo -e "${YELLOW}🔍 Checking for code signing artifacts...${NC}"
SECURITY_VIOLATIONS=0

# Code signing files that should never be committed
FORBIDDEN_FILES=(
    "*.p12"
    "*.mobileprovision" 
    "*.provisionprofile"
    "*.cer"
    "*.p8"
    "AuthKey_*.p8"
    "*.certSigningRequest"
    "*.pem"
    "*.key"
)

for pattern in "${FORBIDDEN_FILES[@]}"; do
    if find . -name "$pattern" -not -path "./.git/*" | grep -q .; then
        echo -e "${RED}❌ Found code signing files: $pattern${NC}"
        find . -name "$pattern" -not -path "./.git/*"
        SECURITY_VIOLATIONS=$((SECURITY_VIOLATIONS + 1))
    fi
done

# Check for hardcoded secrets in code
echo -e "${YELLOW}🔍 Checking for potential secrets in code...${NC}"
SECRETS_PATTERNS=(
    "api_key.*=.*['\"][A-Za-z0-9]{8,}['\"]"  # API keys with actual values
    "secret.*=.*['\"][A-Za-z0-9]{8,}['\"]"   # Secrets with actual values
    "password.*=.*['\"][A-Za-z0-9]{6,}['\"]" # Passwords with actual values (not empty strings)
    "token.*=.*['\"][A-Za-z0-9]{8,}['\"]"    # Tokens with actual values
    "private_key.*=.*['\"][A-Za-z0-9]{8,}['\"]" # Private keys with actual values
    "AKIA[0-9A-Z]{16}"  # AWS Access Key
    "sk_live_[0-9A-Za-z]{24}"  # Stripe Secret Key
    "xox[pboa]-[0-9]{12}-[0-9]{12}-[0-9A-Za-z]{24}"  # Slack Token
)

for pattern in "${SECRETS_PATTERNS[@]}"; do
    # Exclude common false positives like @State password variables and empty strings
    MATCHES=$(grep -r -E -i "$pattern" --include="*.swift" --include="*.plist" --include="*.json" . | grep -v ".git" | grep -v '@State.*password.*=""' | grep -v 'password.*=""' | grep -v 'password.*= ""' || true)
    if [ -n "$MATCHES" ]; then
        echo -e "${RED}❌ Potential secret found matching pattern: $pattern${NC}"
        echo "$MATCHES"
        SECURITY_VIOLATIONS=$((SECURITY_VIOLATIONS + 1))
    fi
done

# Check for real health data files
echo -e "${YELLOW}🔍 Checking for real health data...${NC}"
HEALTH_DATA_PATTERNS=(
    "health_data_*.json"
    "health_data_*.db"
    "export_*.json"
    "export_*.sqlite"
)

for pattern in "${HEALTH_DATA_PATTERNS[@]}"; do
    if find . -name "$pattern" -not -path "./.git/*" | grep -q .; then
        echo -e "${YELLOW}⚠️  Found potential health data files: $pattern${NC}"
        echo -e "${YELLOW}   Make sure these are test files, not real health data!${NC}"
        find . -name "$pattern" -not -path "./.git/*"
    fi
done

# Check for large files (potential data dumps)
echo -e "${YELLOW}🔍 Checking for large files...${NC}"
LARGE_FILES=$(find . -type f -size +10M -not -path "./.git/*" 2>/dev/null || true)
if [ -n "$LARGE_FILES" ]; then
    echo -e "${YELLOW}⚠️  Found large files (>10MB):${NC}"
    echo "$LARGE_FILES"
    echo -e "${YELLOW}   Consider if these should be in git or added to .gitignore${NC}"
fi

# Check .env files
echo -e "${YELLOW}🔍 Checking for environment files...${NC}"
if find . -name ".env*" -not -path "./.git/*" | grep -q .; then
    echo -e "${RED}❌ Found .env files (should be in .gitignore):${NC}"
    find . -name ".env*" -not -path "./.git/*"
    SECURITY_VIOLATIONS=$((SECURITY_VIOLATIONS + 1))
fi

# Check git status for staged secrets
echo -e "${YELLOW}🔍 Checking staged files...${NC}"
if git status --porcelain | grep -E '\.(p12|mobileprovision|p8|key|pem)$'; then
    echo -e "${RED}❌ Sensitive files are staged for commit!${NC}"
    SECURITY_VIOLATIONS=$((SECURITY_VIOLATIONS + 1))
fi

# Check for TODO/FIXME with security implications
echo -e "${YELLOW}🔍 Checking for security-related TODOs...${NC}"
SECURITY_TODOS=$(grep -r -i "TODO.*\(security\|encrypt\|password\|auth\|secret\)" --include="*.swift" . | grep -v ".git" || true)
if [ -n "$SECURITY_TODOS" ]; then
    echo -e "${YELLOW}⚠️  Found security-related TODOs:${NC}"
    echo "$SECURITY_TODOS"
fi

# Final report
echo ""
echo "================================"
if [ $SECURITY_VIOLATIONS -eq 0 ]; then
    echo -e "${GREEN}✅ Security check passed! No violations found.${NC}"
    exit 0
else
    echo -e "${RED}❌ Security check failed! Found $SECURITY_VIOLATIONS violation(s).${NC}"
    echo ""
    echo -e "${YELLOW}🔧 To fix:${NC}"
    echo "1. Remove sensitive files from the repository"
    echo "2. Add patterns to .gitignore if needed"
    echo "3. Use GitHub Secrets for certificates and API keys"
    echo "4. Never commit real health data - use test data only"
    echo ""
    echo -e "${BLUE}💡 For CI/CD setup, see: .github/SETUP.md${NC}"
    exit 1
fi