#!/bin/bash

# ================================================================================
# Cleanup Test Alert Resources - Stop Costs
# ================================================================================
# This script removes test alert resources to stop accumulating costs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${BLUE}======================================================================"
echo -e " 🧹 Cleanup Test Alert Resources"
echo -e " Removing test alerts to stop costs"
echo -e "======================================================================${NC}"

# Configuration
RESOURCE_GROUP="mindx-individual-banv-rg"

echo -e "${PURPLE}🔧 Configuration:${NC}"
echo -e "   Resource Group: ${RESOURCE_GROUP}"
echo -e "   Target: Remove test action group + alert rule"
echo

# Confirm deletion
echo -e "${YELLOW}⚠️  This will delete:${NC}"
echo -e "   📱 banv-test-mobile-alerts (Action Group)"
echo -e "   🚨 TEST-Mobile-Alert-Rule (Alert Rule)"
echo
read -p "Continue with cleanup? (y/N): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}❌ Cleanup cancelled${NC}"
    exit 0
fi

# Step 1: Delete Alert Rule
echo -e "${BLUE}🚨 Step 1: Deleting test alert rule...${NC}"

if az monitor scheduled-query delete \
  --name "TEST-Mobile-Alert-Rule" \
  --resource-group "$RESOURCE_GROUP" \
  --yes 2>/dev/null; then
    echo -e "${GREEN}✅ Test alert rule deleted${NC}"
else
    echo -e "${YELLOW}⚠️  Test alert rule not found or already deleted${NC}"
fi

echo

# Step 2: Delete Action Group
echo -e "${BLUE}📱 Step 2: Deleting test action group...${NC}"

if az monitor action-group delete \
  --name "banv-test-mobile-alerts" \
  --resource-group "$RESOURCE_GROUP" \
  --yes 2>/dev/null; then
    echo -e "${GREEN}✅ Test action group deleted${NC}"
else
    echo -e "${YELLOW}⚠️  Test action group not found or already deleted${NC}"
fi

echo

# Verify cleanup
echo -e "${BLUE}🔍 Step 3: Verifying cleanup...${NC}"

# Check for remaining test resources
TEST_GROUPS=$(az monitor action-group list --resource-group "$RESOURCE_GROUP" --query "[?contains(name, 'test')].[name]" -o tsv 2>/dev/null || echo "")
TEST_RULES=$(az monitor scheduled-query list --resource-group "$RESOURCE_GROUP" --query "[?contains(name, 'TEST')].[name]" -o tsv 2>/dev/null || echo "")

if [[ -z "$TEST_GROUPS" ]] && [[ -z "$TEST_RULES" ]]; then
    echo -e "${GREEN}✅ All test resources successfully deleted${NC}"
else
    echo -e "${YELLOW}⚠️  Some test resources may still exist:${NC}"
    [[ -n "$TEST_GROUPS" ]] && echo -e "   📱 Action Groups: $TEST_GROUPS"
    [[ -n "$TEST_RULES" ]] && echo -e "   🚨 Alert Rules: $TEST_RULES"
fi

echo

# Summary
echo -e "${GREEN}🎊 CLEANUP COMPLETE!${NC}"
echo -e "${BLUE}=====================${NC}"
echo
echo -e "${PURPLE}💰 Cost Impact:${NC}"
echo -e "   ✅ Test alert rule billing stopped"
echo -e "   ✅ Test evaluations stopped"
echo -e "   ✅ Test notifications stopped"
echo -e "   💳 Estimated savings: ~$1.10/month"
echo
echo -e "${GREEN}🚀 Ready for production deployment:${NC}"
echo -e "   ./deploy-mobile-alerts.sh"
echo
echo -e "${YELLOW}📝 Note: Any test alerts fired will still appear in Azure Portal history${NC}"
echo -e "${BLUE}🔗 View alert history: Azure Portal → Monitor → Alerts → Alert History${NC}" 