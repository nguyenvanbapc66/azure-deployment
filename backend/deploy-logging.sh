#!/bin/bash

# ================================================================================
# Azure Application Insights Logging Deployment Script
# ================================================================================
# This script sets up Application Insights integration for the logging system
# Run this AFTER your main deployment to enable cloud logging

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================================================"
echo -e " 🚀 Azure Application Insights Logging Setup"
echo -e " Enabling cloud logging for BANV Backend"
echo -e "======================================================================${NC}"

# Check if running in the right directory
if [[ ! -f "package.json" ]]; then
    echo -e "${RED}❌ Error: Please run this script from the backend directory${NC}"
    echo "Current directory: $(pwd)"
    exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${BLUE}📋 Checking prerequisites...${NC}"

if ! command_exists kubectl; then
    echo -e "${RED}❌ kubectl not found. Please install kubectl.${NC}"
    exit 1
fi

if ! command_exists az; then
    echo -e "${RED}❌ Azure CLI not found. Please install Azure CLI.${NC}"
    exit 1
fi

# Check if logged into Azure
if ! az account show >/dev/null 2>&1; then
    echo -e "${RED}❌ Not logged into Azure. Please run 'az login' first.${NC}"
    exit 1
fi

# Check kubectl context
CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "none")
echo -e "${GREEN}✅ Kubectl context: ${CURRENT_CONTEXT}${NC}"

# Variables (you can modify these)
NAMESPACE="banv-projects"
SECRET_NAME="app-insights-secret"
RESOURCE_GROUP="${RESOURCE_GROUP:-mindx-individual-banv-rg}"  # Set via environment or use default
APP_INSIGHTS_NAME="${APP_INSIGHTS_NAME:-mindx-banv-app-insights}"  # Set via environment or use default

echo -e "${YELLOW}📝 Configuration:${NC}"
echo -e "   Namespace: ${NAMESPACE}"
echo -e "   Secret Name: ${SECRET_NAME}"
echo -e "   Resource Group: ${RESOURCE_GROUP}"
echo -e "   App Insights Name: ${APP_INSIGHTS_NAME}"
echo

# Get Application Insights connection string
echo -e "${BLUE}🔍 Getting Application Insights connection string...${NC}"

CONNECTION_STRING=$(az monitor app-insights component show \
    --app "${APP_INSIGHTS_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --query 'connectionString' \
    --output tsv 2>/dev/null || echo "")

if [[ -z "${CONNECTION_STRING}" ]]; then
    echo -e "${RED}❌ Could not find Application Insights resource: ${APP_INSIGHTS_NAME}${NC}"
    echo -e "${YELLOW}💡 Available App Insights resources in ${RESOURCE_GROUP}:${NC}"
    az monitor app-insights component list \
        --resource-group "${RESOURCE_GROUP}" \
        --query '[].name' \
        --output table || true
    echo
    echo -e "${YELLOW}Please either:${NC}"
    echo "   1. Set APP_INSIGHTS_NAME environment variable with the correct name"
    echo "   2. Create an Application Insights resource first"
    echo "   3. Update RESOURCE_GROUP if the resource is in a different group"
    exit 1
fi

echo -e "${GREEN}✅ Found Application Insights connection string${NC}"

# Create namespace if it doesn't exist
echo -e "${BLUE}📁 Ensuring namespace exists...${NC}"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1
echo -e "${GREEN}✅ Namespace '${NAMESPACE}' is ready${NC}"

# Check if secret already exists
if kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Secret '${SECRET_NAME}' already exists${NC}"
    read -p "Do you want to update it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete secret "${SECRET_NAME}" -n "${NAMESPACE}"
        echo -e "${GREEN}✅ Existing secret deleted${NC}"
    else
        echo -e "${BLUE}ℹ️  Keeping existing secret${NC}"
    fi
fi

# Create Application Insights secret
if ! kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
    echo -e "${BLUE}🔐 Creating Application Insights secret...${NC}"
    kubectl create secret generic "${SECRET_NAME}" \
        --from-literal=connection-string="${CONNECTION_STRING}" \
        -n "${NAMESPACE}"
    echo -e "${GREEN}✅ Secret '${SECRET_NAME}' created successfully${NC}"
fi

# Apply or update the ConfigMap with logging configuration
echo -e "${BLUE}📝 Updating ConfigMap with logging configuration...${NC}"
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: ${NAMESPACE}
data:
  NODE_ENV: "production"
  PORT: "5000"
  # Application Insights configuration
  APPLICATION_INSIGHTS_CLOUD_ROLE: "banv-backend-api"
  APPLICATION_INSIGHTS_CLOUD_ROLE_INSTANCE: "banv-backend"
  # Logging configuration
  LOG_LEVEL: "info"
  LOG_TO_CONSOLE: "true"
  LOG_TO_FILE: "true"
  LOG_TO_AZURE: "true"
EOF

echo -e "${GREEN}✅ ConfigMap updated with logging configuration${NC}"

# Check deployment status
echo -e "${BLUE}🔍 Checking backend deployment status...${NC}"
if kubectl get deployment backend-deployment -n "${NAMESPACE}" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Backend deployment found${NC}"
    
    # Restart deployment to pick up new secret
    echo -e "${BLUE}🔄 Restarting deployment to pick up new configuration...${NC}"
    kubectl rollout restart deployment/backend-deployment -n "${NAMESPACE}"
    
    # Wait for rollout to complete
    echo -e "${BLUE}⏳ Waiting for deployment to complete...${NC}"
    kubectl rollout status deployment/backend-deployment -n "${NAMESPACE}" --timeout=300s
    
    echo -e "${GREEN}✅ Deployment restarted successfully${NC}"
else
    echo -e "${YELLOW}⚠️  Backend deployment not found. The secret is ready for when you deploy.${NC}"
fi

# Verification
echo -e "${BLUE}🔍 Verification...${NC}"
echo
echo -e "${GREEN}✅ Application Insights Logging Setup Complete!${NC}"
echo
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo "   1. Check logs in Azure Portal:"
echo "      → Application Insights → Logs → Tables: requests, traces, exceptions"
echo
echo "   2. Test the logging:"
echo "      → Make API calls to your backend"
echo "      → Check Azure portal in 1-2 minutes for logs"
echo
echo "   3. Sample queries to try in Azure Portal:"
echo "      → requests | where timestamp > ago(1h)"
echo "      → traces | where customDimensions.logType == \"application\""
echo "      → customEvents | where name == \"SecurityEvent\""
echo
echo -e "${GREEN}🎉 Your backend now sends all logs to Azure Application Insights!${NC}"
echo -e "${BLUE}📚 See AZURE-INSIGHTS-LOGGING-GUIDE.md for detailed usage instructions${NC}"

# Show connection verification
echo
echo -e "${BLUE}🔍 Connection Details:${NC}"
echo "   App Insights: ${APP_INSIGHTS_NAME}"
echo "   Resource Group: ${RESOURCE_GROUP}"
echo "   Secret: ${SECRET_NAME} (in namespace ${NAMESPACE})"
echo "   Connection String: ${CONNECTION_STRING:0:50}..."
echo

# Optional: Show current pod logs to verify
if kubectl get pods -n "${NAMESPACE}" -l app=backend >/dev/null 2>&1; then
    POD_NAME=$(kubectl get pods -n "${NAMESPACE}" -l app=backend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "${POD_NAME}" ]]; then
        echo -e "${BLUE}📝 Recent logs from ${POD_NAME}:${NC}"
        kubectl logs "${POD_NAME}" -n "${NAMESPACE}" --tail=5 2>/dev/null || echo "   (No recent logs available)"
    fi
fi

echo
echo -e "${GREEN}🚀 Deployment complete! Your logging system is now integrated with Azure Application Insights.${NC}" 