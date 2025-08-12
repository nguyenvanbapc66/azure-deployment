#!/bin/bash

# Prometheus and Grafana Setup Script for MindX AKS Infrastructure
# Deploys monitoring stack for metrics collection and visualization

set -e

# Configuration
NAMESPACE="azure-monitor"
PROMETHEUS_NAMESPACE="prometheus-system"
GRAFANA_NAMESPACE="grafana-system"
INSIGHTS_DIR="$(dirname "$0")/../../chart/insights/prometheus-setup"

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

echo "📊 Setting up Prometheus and Grafana for MindX AKS Infrastructure"
echo "================================================================="
echo ""

# Step 1: Add Helm repositories
log "📦 Adding Helm repositories..."

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

log_success "Helm repositories added and updated"

# Step 2: Create namespaces
log "📁 Creating monitoring namespaces..."

kubectl create namespace "$PROMETHEUS_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace "$GRAFANA_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

log_success "Monitoring namespaces created"

# Step 3: Verify Prometheus values file exists
log "⚙️  Verifying Prometheus configuration..."

if [ ! -f "$INSIGHTS_DIR/prometheus-values.yaml" ]; then
    log_error "Prometheus values file not found at $INSIGHTS_DIR/prometheus-values.yaml"
    exit 1
fi

log_success "Prometheus configuration found"

# Step 4: Install Prometheus
log "🚀 Installing Prometheus stack..."

if helm list -n "$PROMETHEUS_NAMESPACE" | grep -q prometheus; then
    log "🔄 Upgrading existing Prometheus installation..."
    helm upgrade prometheus prometheus-community/kube-prometheus-stack \
        --namespace "$PROMETHEUS_NAMESPACE" \
        --values "$INSIGHTS_DIR/prometheus-values.yaml"
else
    log "📦 Installing Prometheus stack..."
    helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace "$PROMETHEUS_NAMESPACE" \
        --create-namespace \
        --values "$INSIGHTS_DIR/prometheus-values.yaml"
fi

log_success "Prometheus stack installation completed"

# Step 5: Verify Grafana values file exists
log "⚙️  Verifying Grafana configuration..."

if [ ! -f "$INSIGHTS_DIR/grafana-values.yaml" ]; then
    log_error "Grafana values file not found at $INSIGHTS_DIR/grafana-values.yaml"
    exit 1
fi

log_success "Grafana configuration found"

# Step 6: Install Grafana
log "🚀 Installing Grafana..."

if helm list -n "$GRAFANA_NAMESPACE" | grep -q grafana; then
    log "🔄 Upgrading existing Grafana installation..."
    helm upgrade grafana grafana/grafana \
        --namespace "$GRAFANA_NAMESPACE" \
        --values "$INSIGHTS_DIR/grafana-values.yaml"
else
    log "📦 Installing Grafana..."
    helm install grafana grafana/grafana \
        --namespace "$GRAFANA_NAMESPACE" \
        --create-namespace \
        --values "$INSIGHTS_DIR/grafana-values.yaml"
fi

log_success "Grafana installation completed"

# Step 7: Wait for deployments to be ready
log "⏳ Waiting for monitoring stack to be ready..."

echo "Waiting for Prometheus..."
kubectl wait --for=condition=available --timeout=300s deployment/prometheus-kube-prometheus-operator -n "$PROMETHEUS_NAMESPACE" 2>/dev/null || log_warning "Prometheus operator not ready yet"

echo "Waiting for Grafana..."
kubectl wait --for=condition=available --timeout=300s deployment/grafana -n "$GRAFANA_NAMESPACE" 2>/dev/null || log_warning "Grafana not ready yet"

# Step 8: Deploy Prometheus setup resources from insights directory
log "⚙️  Deploying Prometheus setup resources from insights..."

if [ -d "$INSIGHTS_DIR" ]; then
    # Deploy ServiceMonitors
    if [ -f "$INSIGHTS_DIR/service-monitors.yaml" ]; then
        kubectl apply -f "$INSIGHTS_DIR/service-monitors.yaml"
        log_success "ServiceMonitors deployed"
    fi
    
    # Deploy metrics services
    if [ -f "$INSIGHTS_DIR/metrics-services.yaml" ]; then
        kubectl apply -f "$INSIGHTS_DIR/metrics-services.yaml"
        log_success "Metrics services deployed"
    fi
    
    # Deploy custom metrics config
    if [ -f "$INSIGHTS_DIR/custom-metrics-config.yaml" ]; then
        kubectl apply -f "$INSIGHTS_DIR/custom-metrics-config.yaml"
        log_success "Custom metrics configuration deployed"
    fi
    
    log_success "Prometheus setup resources deployed from insights directory"
else
    log_warning "Prometheus insights directory not found at $INSIGHTS_DIR"
fi

# Step 9: Display status and access information
log "🧪 Checking monitoring stack status..."

echo ""
echo "📋 Monitoring Stack Status:"
echo "==========================="

echo ""
echo "🔍 Namespaces:"
kubectl get namespace "$PROMETHEUS_NAMESPACE" "$GRAFANA_NAMESPACE"

echo ""
echo "🚀 Prometheus Pods:"
kubectl get pods -n "$PROMETHEUS_NAMESPACE" | head -10

echo ""
echo "📊 Grafana Pods:"
kubectl get pods -n "$GRAFANA_NAMESPACE"

echo ""
echo "🌐 Services:"
kubectl get services -n "$PROMETHEUS_NAMESPACE" | grep prometheus
kubectl get services -n "$GRAFANA_NAMESPACE" | grep grafana

echo ""
echo "🔗 Ingress:"
kubectl get ingress -n "$GRAFANA_NAMESPACE" | grep grafana || echo "Grafana ingress not found"

echo ""
log_success "Prometheus and Grafana setup completed!"

echo ""
echo "🎯 Access Information:"
echo "====================="
echo "📊 Grafana Dashboard: https://grafana-banv-dev.mindx.edu.vn"
echo "👤 Username: admin"
echo "🔑 Password: MindX2024!"
echo ""
echo "🔧 Port Forward (if ingress not working):"
echo "kubectl port-forward -n $GRAFANA_NAMESPACE service/grafana 3000:80"
echo "Then access: http://localhost:3000"
echo ""
echo "📈 Prometheus UI (port-forward):"
echo "kubectl port-forward -n $PROMETHEUS_NAMESPACE service/prometheus-kube-prometheus-prometheus 9090:9090"
echo "Then access: http://localhost:9090"
echo ""
echo "🎯 Next Steps:"
echo "=============="
echo "1. Set up application instrumentation: ./deploy/shell/monitoring/app-instrumentation.sh"
echo "2. Create custom dashboards: ./deploy/shell/monitoring/dashboards-setup.sh"
echo "3. Configure alerts: ./deploy/shell/monitoring/alerts-setup.sh" 