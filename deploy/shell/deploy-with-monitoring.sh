#!/bin/bash

# Deploy Applications with Monitoring Integration to Kubernetes
# Uses pre-built images with Application Insights monitoring

set -e

# Change to project root directory
cd "$(dirname "$0")/../.."

# Configuration
REGISTRY="mindxacrbanv.azurecr.io"
NAMESPACE="banv-projects"
NEW_VERSION="v1.8.0-monitoring"

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

echo -e "${BLUE}"
cat << "EOF"
🚀 Deploying Applications with Monitoring to Kubernetes
======================================================
   
   ┌─────────────────────────────────────────┐
   │  📊 Application Insights Integration    │
   │  📈 Prometheus Metrics Collection       │
   │  🔧 Health & Readiness Probes           │
   │  🚨 Error Tracking & Telemetry          │
   └─────────────────────────────────────────┘

   Prerequisites: Run './deploy/shell/deploy-docker.sh' first
   to build and push images with monitoring integration.

EOF
echo -e "${NC}"

log "📋 Using pre-built images with monitoring:"
log "   Backend: $REGISTRY/banv-projects-backend:$NEW_VERSION"
log "   Frontend: $REGISTRY/banv-projects-frontend:$NEW_VERSION"
echo ""

# Check if Application Insights secret exists
log "🔍 Checking monitoring prerequisites..."
APP_INSIGHTS_SECRET=$(kubectl get secret app-insights-secret -n $NAMESPACE 2>/dev/null || echo "")
if [ -z "$APP_INSIGHTS_SECRET" ]; then
    log_error "❌ Application Insights secret not found!"
    echo ""
    echo "🔧 Please run the monitoring setup first:"
    echo "   ./deploy/shell/monitoring/setup-monitoring.sh"
    echo ""
    echo "Or create the secret manually:"
    echo "   kubectl create secret generic app-insights-secret \\"
    echo "     --from-literal=instrumentation-key='YOUR_KEY' \\"
    echo "     --from-literal=connection-string='YOUR_CONNECTION_STRING' \\"
    echo "     --namespace $NAMESPACE"
    echo ""
    exit 1
else
    log_success "Application Insights secret found"
fi

# Step 1: Update deployment manifests with new image versions
log "📝 Updating deployment manifests..."
sed -i.bak "s|image: $REGISTRY/banv-projects-backend:.*|image: $REGISTRY/banv-projects-backend:$NEW_VERSION|" ./deploy/chart/app/app-backend-deployment.yaml
sed -i.bak "s|image: $REGISTRY/banv-projects-frontend:.*|image: $REGISTRY/banv-projects-frontend:$NEW_VERSION|" ./deploy/chart/app/app-frontend-deployment.yaml
log_success "Deployment manifests updated"

# Step 2: Apply the updated deployments
log "🚀 Deploying to Kubernetes..."

# Apply core application resources
kubectl apply -k ./deploy/chart/app

# Check if Kong CRDs are available before applying Kong resources
KONG_CRDS=$(kubectl get crd 2>/dev/null | grep kong | wc -l)
if [ "$KONG_CRDS" -gt 0 ]; then
    log "🦍 Kong CRDs found, applying Kong ingress resources..."
    if kubectl apply -k ./deploy/chart/kong-ingress; then
        log_success "Kong ingress resources applied successfully"
    else
        log_warning "Kong ingress resources failed to apply, but continuing..."
    fi
else
    log_warning "Kong CRDs not found - skipping Kong ingress resources"
    log_warning "Applications will be accessible via port-forwarding only"
    log_warning "To enable external access, install Kong first:"
    log_warning "  helm upgrade --install kong-ingress kong/kong --namespace banv-projects"
fi

log_success "Core applications deployed to Kubernetes"

# Step 3: Wait for deployments to be ready
log "⏳ Waiting for deployments to be ready..."
kubectl rollout status deployment/backend-deployment -n $NAMESPACE --timeout=300s
kubectl rollout status deployment/frontend-deployment -n $NAMESPACE --timeout=300s
log_success "All deployments are ready"

# Step 4: Verify monitoring endpoints
log "🧪 Verifying monitoring endpoints..."
echo ""

# Check backend health and metrics endpoints
log "🔍 Backend endpoints:"
kubectl get pods -n $NAMESPACE -l app=backend -o name | head -1 | xargs -I {} kubectl exec {} -n $NAMESPACE -- curl -s http://localhost:5000/health | jq '.'
kubectl get pods -n $NAMESPACE -l app=backend -o name | head -1 | xargs -I {} kubectl exec {} -n $NAMESPACE -- curl -s http://localhost:5000/ready | jq '.'
echo ""

# Step 5: Show access information
echo ""
log_success "🎉 Deployment completed successfully!"
echo ""
echo "📊 Monitoring Access:"
echo "===================="
echo "🔗 Azure Application Insights:"
echo "   https://portal.azure.com/#@mindx.com.vn/resource/subscriptions/f244cdf7-5150-4b10-b3f2-d4bff23c5f45/resourceGroups/mindx-individual-banv-rg/providers/microsoft.insights/components/mindx-banv-app-insights/overview"
echo ""
echo "🔧 Grafana (port-forward):"
echo "   kubectl port-forward -n grafana-system service/grafana 3000:80"
echo "   Then access: http://localhost:3000"
echo ""
echo "📈 Prometheus (port-forward):"
echo "   kubectl port-forward -n prometheus-system service/prometheus-kube-prometheus-prometheus 9090:9090"
echo "   Then access: http://localhost:9090"
echo ""

# Show application access information based on Kong availability
if [ "$KONG_CRDS" -gt 0 ]; then
    echo "🌐 Application Access (via Kong Ingress):"
    echo "========================================="
    echo "Frontend: https://banv-app-dev.mindx.edu.vn"
    echo "Backend:  https://banv-api-dev.mindx.edu.vn"
    echo "Backend Metrics: https://banv-api-dev.mindx.edu.vn/metrics"
    echo "Backend Health:  https://banv-api-dev.mindx.edu.vn/health"
else
    echo "🌐 Application Access (via Port-Forward):"
    echo "========================================="
    echo "Frontend: kubectl port-forward -n $NAMESPACE service/frontend-service 3000:3000"
    echo "          Then access: http://localhost:3000"
    echo ""
    echo "Backend:  kubectl port-forward -n $NAMESPACE service/backend-service 5000:5000"
    echo "          Then access: http://localhost:5000"
    echo "          Metrics: http://localhost:5000/metrics"
    echo "          Health:  http://localhost:5000/health"
    echo ""
    echo "⚠️  External HTTPS access requires Kong Ingress Controller installation"
fi
echo ""

echo "🎯 Application URLs:"
echo "==================="
echo "🌐 Frontend: https://banv-app-dev.mindx.edu.vn"
echo "🔧 Backend API: https://banv-api-dev.mindx.edu.vn"
echo "📊 Backend Metrics: https://banv-api-dev.mindx.edu.vn/metrics"
echo "💚 Backend Health: https://banv-api-dev.mindx.edu.vn/health"
echo ""

echo "🚀 Next Steps:"
echo "=============="
echo "1. 📊 Visit Azure Application Insights to see live telemetry data"
echo "2. 🔧 Access Grafana dashboards for infrastructure monitoring"  
echo "3. 📱 Test your applications to generate telemetry data"
echo "4. 🧪 Check the /metrics endpoint for Prometheus data"
echo ""

log_success "🎉 Applications with monitoring are now live! 🎉" 