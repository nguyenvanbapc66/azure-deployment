#!/bin/bash

# Azure Monitor Setup Script for MindX AKS Infrastructure
# Integrates with existing Application Insights: mindx-banv-app-insights

set -e

# Configuration
RESOURCE_GROUP="mindx-individual-banv-rg"
AKS_CLUSTER_NAME="mindx_aks_banv"
APP_INSIGHTS_NAME="mindx-banv-app-insights"
NAMESPACE="banv-projects"
MONITORING_NAMESPACE="azure-monitor"
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_PATH/../../.." && pwd)"
INSIGHTS_DIR="$PROJECT_ROOT/deploy/chart/insights/azure-monitor-setup"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

echo "🔍 Setting up Azure Monitor Integration for MindX AKS Infrastructure"
echo "=================================================================="
echo ""

# Step 1: Install required Azure CLI extensions
log "🔧 Installing required Azure CLI extensions..."
az config set extension.use_dynamic_install=yes_without_prompt
az extension add --name application-insights --allow-preview --yes 2>/dev/null || true

# Step 2: Get Application Insights details
log "📊 Getting Application Insights details..."

APP_INSIGHTS_ID=$(az monitor app-insights component show \
    --app "$APP_INSIGHTS_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "id" -o tsv 2>/dev/null || echo "")

if [ -z "$APP_INSIGHTS_ID" ]; then
    log_error "Application Insights '$APP_INSIGHTS_NAME' not found in resource group '$RESOURCE_GROUP'"
    exit 1
fi

APP_INSIGHTS_KEY=$(az monitor app-insights component show \
    --app "$APP_INSIGHTS_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "instrumentationKey" -o tsv 2>/dev/null || echo "")

APP_INSIGHTS_CONNECTION_STRING=$(az monitor app-insights component show \
    --app "$APP_INSIGHTS_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "connectionString" -o tsv 2>/dev/null || echo "")

log_success "Application Insights found:"
echo "  - Name: $APP_INSIGHTS_NAME"
echo "  - Resource ID: $APP_INSIGHTS_ID"
echo "  - Instrumentation Key: ${APP_INSIGHTS_KEY:0:8}..."
echo "  - Connection String: ${APP_INSIGHTS_CONNECTION_STRING:0:50}..."

# Step 3: Enable Container Insights on AKS
log "🚀 Enabling Container Insights on AKS cluster..."

# Check if Container Insights is already enabled
CONTAINER_INSIGHTS_ENABLED=$(az aks show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AKS_CLUSTER_NAME" \
    --query "addonProfiles.omsagent.enabled" -o tsv 2>/dev/null || echo "false")

if [ "$CONTAINER_INSIGHTS_ENABLED" = "true" ]; then
    log_success "Container Insights already enabled on AKS cluster"
else
    log_warning "Container Insights not enabled on AKS cluster"
    log_warning "This requires Log Analytics workspace creation permissions"
    log_warning "Please ask your Azure administrator to enable Container Insights"
    log_warning "Continuing with Application Insights setup..."
fi

# Step 4: Create monitoring namespace
log "📁 Creating monitoring namespace..."
kubectl create namespace "$MONITORING_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Step 5: Create Application Insights secrets
log "🔑 Creating Application Insights secrets..."
kubectl create secret generic app-insights-secret \
    --from-literal=instrumentation-key="$APP_INSIGHTS_KEY" \
    --from-literal=connection-string="$APP_INSIGHTS_CONNECTION_STRING" \
    --namespace="$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic app-insights-secret \
    --from-literal=instrumentation-key="$APP_INSIGHTS_KEY" \
    --from-literal=connection-string="$APP_INSIGHTS_CONNECTION_STRING" \
    --namespace="$MONITORING_NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

log_success "Application Insights secrets created"

# Step 6: Get Log Analytics workspace details
log "📊 Getting Log Analytics workspace details..."

LOG_ANALYTICS_WORKSPACE_ID=$(az aks show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AKS_CLUSTER_NAME" \
    --query "addonProfiles.omsagent.config.logAnalyticsWorkspaceResourceID" -o tsv 2>/dev/null || echo "")

if [ -n "$LOG_ANALYTICS_WORKSPACE_ID" ]; then
    log_success "Log Analytics workspace found: $LOG_ANALYTICS_WORKSPACE_ID"
    
    # Get workspace key
    WORKSPACE_NAME=$(echo "$LOG_ANALYTICS_WORKSPACE_ID" | sed 's/.*workspaces\///')
    WORKSPACE_RG=$(echo "$LOG_ANALYTICS_WORKSPACE_ID" | sed 's/.*resourceGroups\/\([^/]*\).*/\1/')
    
    WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
        --resource-group "$WORKSPACE_RG" \
        --workspace-name "$WORKSPACE_NAME" \
        --query "primarySharedKey" -o tsv 2>/dev/null || echo "")
    
    if [ -n "$WORKSPACE_KEY" ]; then
        # Create Log Analytics secret
        kubectl create secret generic log-analytics-secret \
            --from-literal=workspace-id="$LOG_ANALYTICS_WORKSPACE_ID" \
            --from-literal=workspace-key="$WORKSPACE_KEY" \
            --namespace="$MONITORING_NAMESPACE" \
            --dry-run=client -o yaml | kubectl apply -f -
        
        log_success "Log Analytics secrets created"
    fi
else
    log_warning "Log Analytics workspace not found - Container Insights not enabled"
    log_warning "Skipping Log Analytics configuration"
fi

# Step 7: Install Azure Monitor for containers DaemonSet (if not already present)
log "🔧 Checking Azure Monitor for containers..."

OMSAGENT_PODS=$(kubectl get pods -n kube-system -l component=oms-agent --no-headers 2>/dev/null | wc -l)
if [ "$OMSAGENT_PODS" -gt 0 ]; then
    log_success "Azure Monitor for containers is running ($OMSAGENT_PODS pods)"
else
    log_warning "Azure Monitor for containers not found - may still be deploying"
fi

# Step 8: Deploy Azure Monitor configuration from insights directory
log "⚙️  Deploying Azure Monitor configuration from insights..."

if [ -d "$INSIGHTS_DIR" ]; then
    # Update monitoring-configmap.yaml with actual values and apply
    sed "s|log-analytics-workspace-id: \"\"|log-analytics-workspace-id: \"$LOG_ANALYTICS_WORKSPACE_ID\"|" \
        "$INSIGHTS_DIR/monitoring-configmap.yaml" | kubectl apply -f -
    
    # Deploy App Insights config with actual values
    sed -e "s|APPLICATIONINSIGHTS_CONNECTION_STRING: \"\"|APPLICATIONINSIGHTS_CONNECTION_STRING: \"$APP_INSIGHTS_CONNECTION_STRING\"|" \
        -e "s|APPINSIGHTS_INSTRUMENTATIONKEY: \"\"|APPINSIGHTS_INSTRUMENTATIONKEY: \"$APP_INSIGHTS_KEY\"|" \
        "$INSIGHTS_DIR/app-insights-config.yaml" | kubectl apply -f -
    
    # Deploy Fluent Bit config
    kubectl apply -f "$INSIGHTS_DIR/fluent-bit-config.yaml"
    
    log_success "Azure Monitor configuration deployed from insights directory"
else
    log_error "Azure Monitor insights directory not found at $INSIGHTS_DIR"
    exit 1
fi

# Step 9: Verify setup
log "🧪 Verifying monitoring setup..."

echo ""
echo "📋 Monitoring Components Status:"
echo "================================="

echo "🔍 Namespaces:"
kubectl get namespace "$MONITORING_NAMESPACE" "$NAMESPACE"

echo ""
echo "🔑 Secrets:"
kubectl get secrets -n "$NAMESPACE" | grep -E "(app-insights|log-analytics)" || echo "No monitoring secrets in $NAMESPACE"
kubectl get secrets -n "$MONITORING_NAMESPACE" | grep -E "(app-insights|log-analytics)" || echo "No monitoring secrets in $MONITORING_NAMESPACE"

echo ""
echo "⚙️  ConfigMaps:"
kubectl get configmap monitoring-config -n "$MONITORING_NAMESPACE" || echo "Monitoring config not found"

echo ""
echo "🚀 Azure Monitor Pods:"
kubectl get pods -n kube-system -l component=oms-agent || echo "OMS Agent pods not found"

echo ""
log_success "Azure Monitor integration setup completed!"

echo ""
echo "🎯 Next Steps:"
echo "=============="
echo "1. Deploy Prometheus and Grafana: ./deploy/shell/monitoring/prometheus-setup.sh"
echo "2. Set up application instrumentation: ./deploy/shell/monitoring/app-instrumentation.sh"
echo "3. Create monitoring dashboards: ./deploy/shell/monitoring/dashboards-setup.sh"
echo "4. Configure alerts: ./deploy/shell/monitoring/alerts-setup.sh"
echo ""
echo "🔗 Azure Portal Links:"
echo "- Application Insights: https://portal.azure.com/#@mindx.com.vn/resource$APP_INSIGHTS_ID"
echo "- AKS Insights: https://portal.azure.com/#@mindx.com.vn/resource$AKS_CLUSTER_NAME/insights" 