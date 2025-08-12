#!/bin/bash

# Master Monitoring Setup Script for MindX AKS Infrastructure
# Orchestrates the complete monitoring, logging, and alerting setup

set -e

# Get absolute paths
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_PATH/../../.." && pwd)"

# Change to project root directory
cd "$PROJECT_ROOT"

# Configuration
INSIGHTS_DIR="$PROJECT_ROOT/deploy/chart/insights"
SCRIPT_DIR="$PROJECT_ROOT/deploy/shell/monitoring"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

log_step() {
    echo -e "${PURPLE}🔄 STEP $1: $2${NC}"
    echo "================================================================"
}

echo -e "${CYAN}"
cat << "EOF"
🔍 MindX AKS Infrastructure Monitoring Setup
============================================
   
   ┌─────────────────────────────────────────┐
   │  📊 Azure Monitor Integration           │
   │  📈 Prometheus & Grafana                │
   │  🔧 Application Instrumentation         │
   │  🚨 Comprehensive Alerting              │
   │  📋 Custom Dashboards                   │
   └─────────────────────────────────────────┘

EOF
echo -e "${NC}"

echo "This script will set up comprehensive monitoring for:"
echo "• Azure Application Insights integration"
echo "• Container Insights for AKS"
echo "• Prometheus metrics collection"
echo "• Grafana dashboards and visualization"
echo "• Application instrumentation"
echo "• Infrastructure and application alerts"
echo "• Log aggregation and analysis"
echo ""
echo "📁 Using YAML configurations from: $INSIGHTS_DIR"
echo ""

# Verify insights directory exists
if [ ! -d "$INSIGHTS_DIR" ]; then
    log_error "Insights directory not found at $INSIGHTS_DIR"
    log_error "Please ensure the YAML configurations are available"
    exit 1
fi

read -p "🚀 Do you want to proceed with the complete monitoring setup? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Setup cancelled by user"
    exit 1
fi

echo ""
log "🎯 Starting comprehensive monitoring setup..."

# Step 1: Azure Monitor Integration
log_step "1" "Azure Monitor Integration"
if [ -f "$SCRIPT_DIR/azure-monitor-setup.sh" ]; then
    chmod +x "$SCRIPT_DIR/azure-monitor-setup.sh"
    "$SCRIPT_DIR/azure-monitor-setup.sh"
    log_success "Azure Monitor integration completed"
else
    log_error "Azure Monitor setup script not found"
    exit 1
fi

echo ""
read -p "⏳ Press Enter to continue to Prometheus & Grafana setup..."

# Step 2: Prometheus and Grafana Setup
log_step "2" "Prometheus & Grafana Deployment"
if [ -f "$SCRIPT_DIR/prometheus-setup.sh" ]; then
    chmod +x "$SCRIPT_DIR/prometheus-setup.sh"
    "$SCRIPT_DIR/prometheus-setup.sh"
    log_success "Prometheus & Grafana deployment completed"
else
    log_error "Prometheus setup script not found"
    exit 1
fi

echo ""
read -p "⏳ Press Enter to continue to application instrumentation..."

# Step 3: Application Instrumentation
log_step "3" "Application Instrumentation"
if [ -f "$SCRIPT_DIR/app-instrumentation.sh" ]; then
    chmod +x "$SCRIPT_DIR/app-instrumentation.sh"
    "$SCRIPT_DIR/app-instrumentation.sh"
    log_success "Application instrumentation completed"
else
    log_error "Application instrumentation script not found"
    exit 1
fi

echo ""
read -p "⏳ Press Enter to continue to alerts setup..."

# Step 4: Alerts Configuration
log_step "4" "Alerts & Notifications Setup"
if [ -f "$SCRIPT_DIR/alerts-setup.sh" ]; then
    chmod +x "$SCRIPT_DIR/alerts-setup.sh"
    "$SCRIPT_DIR/alerts-setup.sh"
    log_success "Alerts configuration completed"
else
    log_error "Alerts setup script not found"
    exit 1
fi

# Step 5: Final Verification and Summary
log_step "5" "Final Verification & Summary"

echo ""
log "🧪 Performing final verification..."

echo ""
echo "📋 Monitoring Infrastructure Status:"
echo "===================================="

echo ""
echo "🔍 Namespaces:"
kubectl get namespaces | grep -E "(azure-monitor|prometheus-system|grafana-system|banv-projects)"

echo ""
echo "🚀 Key Deployments:"
kubectl get deployments -n prometheus-system | head -5
kubectl get deployments -n grafana-system
kubectl get deployments -n azure-monitor

echo ""
echo "🌐 Services:"
kubectl get services -n prometheus-system | grep prometheus | head -3
kubectl get services -n grafana-system | grep grafana
kubectl get services -n banv-projects | grep metrics

echo ""
echo "📊 Monitoring Resources:"
kubectl get prometheusrules -n prometheus-system | head -3
kubectl get servicemonitors -n prometheus-system | head -5
kubectl get secrets -n banv-projects | grep -E "(app-insights|monitoring)"

echo ""
echo "📁 YAML Configurations Used:"
echo "=============================="
ls -la "$INSIGHTS_DIR"/*.yaml | wc -l | xargs echo "Total YAML files:"
ls "$INSIGHTS_DIR"/*.yaml | sed 's|.*/||' | sort

echo ""
log_success "Final verification completed!"

# Summary and Next Steps
echo ""
echo -e "${CYAN}🎉 MONITORING SETUP COMPLETED SUCCESSFULLY! 🎉${NC}"
echo ""
echo "📊 What has been configured:"
echo "============================"
echo "✅ Azure Application Insights integration"
echo "✅ Container Insights for AKS cluster"
echo "✅ Prometheus metrics collection"
echo "✅ Grafana dashboards and visualization"
echo "✅ Application instrumentation (frontend & backend)"
echo "✅ Infrastructure and application alerts"
echo "✅ Log Analytics workspace integration"
echo "✅ ServiceMonitors for metrics scraping"
echo "✅ Alertmanager for notifications"
echo ""

echo "🔗 Access URLs:"
echo "==============="
echo "📊 Grafana Dashboard: https://grafana-banv-dev.mindx.edu.vn"
echo "   Username: admin"
echo "   Password: MindX2024!"
echo ""
echo "🔗 Azure Application Insights:"
echo "   https://portal.azure.com/#@mindx.com.vn/resource/subscriptions/f244cdf7-5150-4b10-b3f2-d4bff23c5f45/resourcegroups/mindx-individual-banv-rg/providers/microsoft.insights/components/mindx-banv-app-insights/overview"
echo ""

echo "🛠️  Port Forward Commands (if needed):"
echo "======================================="
echo "# Grafana"
echo "kubectl port-forward -n grafana-system service/grafana 3000:80"
echo ""
echo "# Prometheus"
echo "kubectl port-forward -n prometheus-system service/prometheus-kube-prometheus-prometheus 9090:9090"
echo ""
echo "# Alertmanager"
echo "kubectl port-forward -n prometheus-system service/prometheus-kube-prometheus-alertmanager 9093:9093"
echo ""

echo "📧 Configuration Required:"
echo "=========================="
echo "1. Update Alertmanager with your email/Slack credentials:"
echo "   kubectl edit secret alertmanager-config -n prometheus-system"
echo ""
echo "2. Configure Azure Monitor alerts:"
echo "   kubectl exec -n azure-monitor deployment/webhook-receiver -- /bin/sh -c \"\$(kubectl get configmap azure-alerts-config -n azure-monitor -o jsonpath='{.data.create-azure-alerts\.sh}')\""
echo ""

echo "🧪 Testing:"
echo "============"
echo "1. Access Grafana dashboard and verify data sources"
echo "2. Check Prometheus targets: http://localhost:9090/targets"
echo "3. Test alerts: /tmp/test-alerts.sh (if created)"
echo "4. Verify Application Insights data in Azure Portal"
echo ""

echo "📈 Key Metrics to Monitor:"
echo "=========================="
echo "• CPU and Memory usage (nodes and pods)"
echo "• Application response times and error rates"
echo "• Certificate expiration dates"
echo "• Kong Ingress Controller performance"
echo "• Database connections and OAuth success rates"
echo "• Disk space and network I/O"
echo ""

echo "🚨 Alerts Configured:"
echo "===================="
echo "• Infrastructure: Node down, high CPU/memory, disk space"
echo "• Applications: Service down, high error rate, high latency"
echo "• Security: Certificate expiration and failures"
echo "• Kong: Ingress controller issues and performance"
echo ""

echo "🎯 Next Steps:"
echo "=============="
echo "1. 📊 Access Grafana and explore pre-configured dashboards"
echo "2. 🔧 Customize dashboards for your specific needs"
echo "3. 📧 Configure email/Slack notifications in Alertmanager"
echo "4. 🧪 Test alerts to ensure proper notification delivery"
echo "5. 📱 Set up mobile alerts for critical issues"
echo "6. 📋 Create runbooks for common alert scenarios"
echo "7. 🔍 Monitor application performance and optimize based on metrics"
echo ""

echo "💡 Application Code Updates Needed:"
echo "===================================="
echo "To fully utilize the monitoring setup, update your application code:"
echo ""
echo "Frontend (React/Vue/Angular):"
echo "• npm install applicationinsights @prometheus-prom/client"
echo "• Add Application Insights SDK initialization"
echo "• Add /metrics and /health endpoints"
echo ""
echo "Backend (Node.js/Express):"
echo "• npm install applicationinsights prom-client express-prometheus-middleware"
echo "• Add Application Insights SDK initialization"
echo "• Add Prometheus metrics middleware"
echo "• Add /metrics, /health, and /ready endpoints"
echo ""

echo "📚 Documentation:"
echo "=================="
echo "• Prometheus: https://prometheus.io/docs/"
echo "• Grafana: https://grafana.com/docs/"
echo "• Azure Monitor: https://docs.microsoft.com/en-us/azure/azure-monitor/"
echo "• Application Insights: https://docs.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview"
echo ""
echo "📁 YAML Configurations: $INSIGHTS_DIR"
echo ""

log_success "🎉 Complete monitoring setup finished! Your infrastructure is now fully monitored and ready for production! 🎉"

echo ""
echo -e "${PURPLE}Happy Monitoring! 📊✨${NC}" 