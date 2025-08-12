#!/bin/bash

# Alerts Setup Script for MindX AKS Infrastructure
# Creates comprehensive alerting for infrastructure and applications

set -e

# Configuration
NAMESPACE="banv-projects"
PROMETHEUS_NAMESPACE="prometheus-system"
MONITORING_NAMESPACE="azure-monitor"
INSIGHTS_DIR="$(dirname "$0")/../../chart/insights/alert-setup"

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

echo "🚨 Setting up Alerts for MindX AKS Infrastructure"
echo "================================================="
echo ""

# Step 1: Deploy all alert setup resources from insights directory
log "⚙️  Deploying alert setup resources from insights..."

if [ -d "$INSIGHTS_DIR" ]; then
    # Deploy infrastructure alerts
    if [ -f "$INSIGHTS_DIR/infrastructure-alerts.yaml" ]; then
        kubectl apply -f "$INSIGHTS_DIR/infrastructure-alerts.yaml"
        log_success "Infrastructure alerts deployed"
    fi
    
    # Deploy application alerts
    if [ -f "$INSIGHTS_DIR/application-alerts.yaml" ]; then
        kubectl apply -f "$INSIGHTS_DIR/application-alerts.yaml"
        log_success "Application alerts deployed"
    fi
    
    # Deploy Alertmanager configuration
    if [ -f "$INSIGHTS_DIR/alertmanager-config.yaml" ]; then
        kubectl apply -f "$INSIGHTS_DIR/alertmanager-config.yaml"
        log_success "Alertmanager configuration deployed"
    fi
    
    # Deploy Azure Monitor alerts configuration
    if [ -f "$INSIGHTS_DIR/azure-alerts-config.yaml" ]; then
        kubectl apply -f "$INSIGHTS_DIR/azure-alerts-config.yaml"
        log_success "Azure Monitor alerts configuration deployed"
    fi
    
    # Deploy webhook receiver
    if [ -f "$INSIGHTS_DIR/webhook-receiver.yaml" ]; then
        kubectl apply -f "$INSIGHTS_DIR/webhook-receiver.yaml"
        log_success "Webhook receiver deployed"
    fi
    
    log_success "All alert setup resources deployed from insights directory"
else
    log_error "Alert setup insights directory not found at $INSIGHTS_DIR"
    exit 1
fi

# Step 2: Create alert testing script
log "🧪 Creating alert testing script..."

cat <<EOF > /tmp/test-alerts.sh
#!/bin/bash
# Script to test alerts

echo "🧪 Testing alerts..."

# Test infrastructure alerts
echo "Testing node down alert (simulation)..."
kubectl scale deployment/frontend-deployment -n banv-projects --replicas=0
sleep 60
kubectl scale deployment/frontend-deployment -n banv-projects --replicas=1

# Test application alerts
echo "Testing high CPU alert..."
kubectl run cpu-stress --image=containerstack/cpustress -- --cpu=1 --timeout=300s --metrics-brief
sleep 30
kubectl delete pod cpu-stress

# Test memory alerts
echo "Testing high memory alert..."
kubectl run memory-stress --image=polinux/stress -- stress --vm 1 --vm-bytes 512M --timeout 300s
sleep 30
kubectl delete pod memory-stress

echo "Alert tests completed. Check Alertmanager UI for fired alerts."
EOF

chmod +x /tmp/test-alerts.sh
log_success "Alert testing script created"

# Step 3: Display status and access information
log "🧪 Checking alerts setup status..."

echo ""
echo "📋 Alerts Setup Status:"
echo "======================="

echo ""
echo "🔍 PrometheusRules:"
kubectl get prometheusrules -n "$PROMETHEUS_NAMESPACE"

echo ""
echo "📧 Alertmanager Config:"
kubectl get secret alertmanager-config -n "$PROMETHEUS_NAMESPACE"

echo ""
echo "🔗 Webhook Receiver:"
kubectl get deployment webhook-receiver -n "$MONITORING_NAMESPACE"
kubectl get service webhook-service -n "$MONITORING_NAMESPACE"

echo ""
echo "☁️  Azure Alerts Config:"
kubectl get configmap azure-alerts-config -n "$MONITORING_NAMESPACE"

echo ""
log_success "Alerts setup completed!"

echo ""
echo "🎯 Access Information:"
echo "====================="
echo "📊 Alertmanager UI (port-forward):"
echo "kubectl port-forward -n $PROMETHEUS_NAMESPACE service/prometheus-kube-prometheus-alertmanager 9093:9093"
echo "Then access: http://localhost:9093"
echo ""
echo "🧪 Test Alerts:"
echo "/tmp/test-alerts.sh"
echo ""
echo "☁️  Create Azure Monitor Alerts:"
echo "kubectl exec -n $MONITORING_NAMESPACE deployment/webhook-receiver -- /bin/sh -c \"\$(kubectl get configmap azure-alerts-config -n $MONITORING_NAMESPACE -o jsonpath='{.data.create-azure-alerts\.sh}')\""
echo ""
echo "🎯 Next Steps:"
echo "=============="
echo "1. Configure email/Slack credentials in Alertmanager"
echo "2. Test alerts using the test script"
echo "3. Create custom dashboards: ./deploy/shell/monitoring/dashboards-setup.sh"
echo "4. Monitor alerts in Grafana and Azure Portal"
echo ""
echo "📧 Email Configuration:"
echo "======================="
echo "Update the Alertmanager secret with your SMTP credentials:"
echo "kubectl edit secret alertmanager-config -n $PROMETHEUS_NAMESPACE"
echo ""
echo "🔗 Slack Configuration:"
echo "======================="
echo "Update the Slack webhook URL in the Alertmanager config"
echo "Create a Slack app and get webhook URL from: https://api.slack.com/apps"

# Clean up temporary files
rm -f /tmp/test-alerts.sh 