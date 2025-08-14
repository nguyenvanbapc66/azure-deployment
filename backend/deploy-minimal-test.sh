#!/bin/bash

# ================================================================================
# MINIMAL Mobile Alert Testing - Cost-Conscious Approach
# ================================================================================
# This script creates only ONE action group and ONE alert rule for testing
# Total cost: ~$1.10/month while testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================================================"
echo -e " 🧪 MINIMAL Mobile Alert Testing (Cost-Conscious)"
echo -e " Creating 1 action group + 1 alert rule for testing"
echo -e " Estimated cost: ~$1.10/month during testing"
echo -e "======================================================================${NC}"

# Configuration
RESOURCE_GROUP="mindx-individual-banv-rg"
APP_INSIGHTS_ID="/subscriptions/f244cdf7-5150-4b10-b3f2-d4bff23c5f45/resourceGroups/mindx-individual-banv-rg/providers/microsoft.insights/components/mindx-banv-app-insights"

echo -e "${PURPLE}🔧 Test Configuration:${NC}"
echo -e "   Resource Group: ${RESOURCE_GROUP}"
echo -e "   Alert Rules: 1 (instead of 7)"
echo -e "   Action Groups: 1 (instead of 6)"
echo -e "   Estimated Monthly Cost: ~$1.10"
echo

# Check prerequisites
echo -e "${BLUE}📋 Checking prerequisites...${NC}"

if ! command -v az >/dev/null 2>&1; then
    echo -e "${RED}❌ Azure CLI not found${NC}"
    exit 1
fi

if ! az account show >/dev/null 2>&1; then
    echo -e "${RED}❌ Not logged into Azure${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites met${NC}"
echo

# Step 1: Create TEST Action Group
echo -e "${BLUE}📱 Step 1: Creating TEST Action Group...${NC}"

az monitor action-group create \
  --name "banv-test-mobile-alerts" \
  --resource-group "$RESOURCE_GROUP" \
  --short-name "BANVTest" \
  --action email "Test-Email" "banv@mindx.com.vn" \
  --action azureapppush "Test-Mobile" "banv@mindx.com.vn" \
  --tags Environment=Testing Service=BANV AlertType=Test MobileEnabled=true

echo -e "${GREEN}✅ Test Action Group created${NC}"
echo

# Step 2: Create ONE Test Alert Rule
echo -e "${BLUE}🚨 Step 2: Creating ONE test alert rule...${NC}"

az monitor scheduled-query create \
  --name "TEST-Mobile-Alert-Rule" \
  --resource-group "$RESOURCE_GROUP" \
  --scopes "$APP_INSIGHTS_ID" \
  --condition "count 'TestQuery' >= 1" \
  --condition-query TestQuery="requests | where timestamp > ago(5m) | where success == false | summarize ErrorCount = count() | where ErrorCount > 3" \
  --evaluation-frequency PT5M \
  --window-size PT10M \
  --severity 1 \
  --description "🧪 TEST: Mobile alert testing rule - triggers when >3 failed requests in 5min" \
  --action-groups "/subscriptions/f244cdf7-5150-4b10-b3f2-d4bff23c5f45/resourceGroups/mindx-individual-banv-rg/providers/Microsoft.Insights/actionGroups/banv-test-mobile-alerts"

echo -e "${GREEN}✅ Test alert rule created${NC}"
echo

# Step 3: Verify Test Setup
echo -e "${BLUE}🔍 Step 3: Verifying test deployment...${NC}"

# Check Action Group
TEST_GROUPS=$(az monitor action-group list --resource-group "$RESOURCE_GROUP" --query "[?contains(name, 'test')].[name]" -o tsv 2>/dev/null || echo "")

if [[ -n "$TEST_GROUPS" ]]; then
    echo -e "${GREEN}✅ Test action group found: $TEST_GROUPS${NC}"
else
    echo -e "${RED}❌ Test action group not found${NC}"
fi

# Check Alert Rule
TEST_RULES=$(az monitor scheduled-query list --resource-group "$RESOURCE_GROUP" --query "[?contains(name, 'TEST')].[name,enabled]" -o tsv 2>/dev/null || echo "")

if [[ -n "$TEST_RULES" ]]; then
    echo -e "${GREEN}✅ Test alert rule found and enabled${NC}"
else
    echo -e "${RED}❌ Test alert rule not found${NC}"
fi

echo

# Summary
echo -e "${GREEN}🎯 MINIMAL TEST DEPLOYMENT COMPLETE!${NC}"
echo -e "${BLUE}========================================${NC}"
echo
echo -e "${PURPLE}💰 Cost Impact:${NC}"
echo -e "   📱 Action Group: FREE"
echo -e "   🚨 Alert Rule: $1.00/month"
echo -e "   📊 Evaluations: ~$0.10/month (5min intervals)"
echo -e "   📧 Notifications: ~$0.01/month"
echo -e "   💳 TOTAL: ~$1.11/month while testing"
echo
echo -e "${YELLOW}🧪 Next Steps for Testing:${NC}"
echo -e "   1. Run: cd backend && ./test-minimal-alerts.sh"
echo -e "   2. Check Azure mobile app for notifications"
echo -e "   3. If working → deploy full system"
echo -e "   4. Clean up: ./cleanup-test-alerts.sh"
echo
echo -e "${PURPLE}📱 Expected Test Alert:${NC}"
echo -e "   • Name: 'TEST-Mobile-Alert-Rule'"
echo -e "   • Trigger: >3 failed requests in 5 minutes"
echo -e "   • Notifications: Email + Mobile App"
echo
echo -e "${GREEN}🔥 READY FOR LOW-COST TESTING!${NC}" 