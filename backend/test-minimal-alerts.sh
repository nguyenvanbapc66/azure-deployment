#!/bin/bash

# ================================================================================
# Minimal Alert Testing - Cost-Conscious
# ================================================================================
# This script triggers the test alert with minimal API calls

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${BLUE}======================================================================"
echo -e " 🧪 Minimal Alert Testing - Cost-Conscious"
echo -e " Triggering test alert with minimal API calls"
echo -e "======================================================================${NC}"

# Configuration
BACKEND_URL="${BACKEND_URL:-https://banv-api-dev.mindx.edu.vn}"
RESOURCE_GROUP="mindx-individual-banv-rg"

echo -e "${PURPLE}🔧 Configuration:${NC}"
echo -e "   Backend URL: ${BACKEND_URL}"
echo -e "   Target: >3 failed requests in 5 minutes"
echo -e "   Expected Cost: ~$0.02 in notifications"
echo

# Generate exactly 4 failed requests (just above the threshold)
echo -e "${BLUE}🚨 Generating test errors (4 failed requests)...${NC}"

for i in {1..4}; do
    echo "Making test error request $i/4..."
    curl -s "${BACKEND_URL}/api/user/nonexistent-endpoint" > /dev/null || echo "  ✓ Error generated"
    sleep 2
done

echo -e "${GREEN}✅ Test errors generated${NC}"
echo

# Check if test alert rule exists
echo -e "${BLUE}🔍 Verifying test alert rule...${NC}"
TEST_RULE=$(az monitor scheduled-query show \
  --name "TEST-Mobile-Alert-Rule" \
  --resource-group "$RESOURCE_GROUP" \
  --query "name" -o tsv 2>/dev/null || echo "")

if [[ -n "$TEST_RULE" ]]; then
    echo -e "${GREEN}✅ Test alert rule found: $TEST_RULE${NC}"
else
    echo -e "${RED}❌ Test alert rule not found. Run deploy-minimal-test.sh first${NC}"
    exit 1
fi

echo

# Summary
echo -e "${GREEN}🎯 MINIMAL TEST COMPLETE!${NC}"
echo -e "${BLUE}=========================${NC}"
echo
echo -e "${PURPLE}📱 Expected Results:${NC}"
echo -e "   • Alert should trigger in 5-10 minutes"
echo -e "   • Email notification to banv@mindx.com.vn"
echo -e "   • Mobile push notification to Azure app"
echo
echo -e "${YELLOW}📲 Check your notifications:${NC}"
echo -e "   1. 📧 Check email inbox (banv@mindx.com.vn)"
echo -e "   2. 📱 Check Azure mobile app notifications"
echo -e "   3. 🌐 Azure Portal → Monitor → Alerts"
echo
echo -e "${GREEN}💰 Cost of this test: ~$0.02${NC}"
echo
echo -e "${BLUE}⏰ Timeline:${NC}"
echo -e "   • 0-5 min: Alert rule evaluation"
echo -e "   • 5-10 min: Alert should fire"
echo -e "   • 10-15 min: Notifications delivered"
echo
echo -e "${PURPLE}🧪 If test works, deploy full system with: ./deploy-mobile-alerts.sh${NC}"
echo -e "${YELLOW}🧹 Clean up test resources with: ./cleanup-test-alerts.sh${NC}" 