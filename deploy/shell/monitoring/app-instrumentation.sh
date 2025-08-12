#!/bin/bash

# Application Instrumentation Setup Script for MindX AKS Infrastructure
# Configures monitoring for frontend and backend applications

set -e

# Configuration
NAMESPACE="banv-projects"
MONITORING_NAMESPACE="azure-monitor"
AZURE_INSIGHTS_DIR="$(dirname "$0")/../../chart/insights/azure-monitor-setup"
PROMETHEUS_INSIGHTS_DIR="$(dirname "$0")/../../chart/insights/prometheus-setup"

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

echo "🔧 Setting up Application Instrumentation for MindX AKS Infrastructure"
echo "======================================================================"
echo ""

# Step 1: Get Application Insights connection details
log "📊 Getting Application Insights connection details..."

APP_INSIGHTS_KEY=$(kubectl get secret app-insights-secret -n "$NAMESPACE" -o jsonpath='{.data.instrumentation-key}' 2>/dev/null | base64 -d || echo "")
APP_INSIGHTS_CONNECTION_STRING=$(kubectl get secret app-insights-secret -n "$NAMESPACE" -o jsonpath='{.data.connection-string}' 2>/dev/null | base64 -d || echo "")

if [ -z "$APP_INSIGHTS_KEY" ]; then
    log_error "Application Insights secrets not found. Run azure-monitor-setup.sh first."
    exit 1
fi

log_success "Application Insights connection details retrieved"

# Step 2: Deploy monitoring sidecar configuration from Azure insights
log "⚙️  Deploying monitoring sidecar configuration from Azure insights..."

if [ -f "$AZURE_INSIGHTS_DIR/fluent-bit-config.yaml" ]; then
    kubectl apply -f "$AZURE_INSIGHTS_DIR/fluent-bit-config.yaml"
    log_success "Monitoring sidecar configuration deployed"
else
    log_error "Fluent Bit config file not found at $AZURE_INSIGHTS_DIR/fluent-bit-config.yaml"
    exit 1
fi

# Step 3: Deploy Application Insights instrumentation ConfigMap from Azure insights
log "⚙️  Deploying Application Insights instrumentation configuration..."

if [ -f "$AZURE_INSIGHTS_DIR/app-insights-config.yaml" ]; then
    # Update the ConfigMap with actual values and apply
    sed -e "s|APPLICATIONINSIGHTS_CONNECTION_STRING: \"\"|APPLICATIONINSIGHTS_CONNECTION_STRING: \"$APP_INSIGHTS_CONNECTION_STRING\"|" \
        -e "s|APPINSIGHTS_INSTRUMENTATIONKEY: \"\"|APPINSIGHTS_INSTRUMENTATIONKEY: \"$APP_INSIGHTS_KEY\"|" \
        "$AZURE_INSIGHTS_DIR/app-insights-config.yaml" | kubectl apply -f -
    log_success "Application Insights configuration deployed"
else
    log_error "App Insights config file not found at $AZURE_INSIGHTS_DIR/app-insights-config.yaml"
    exit 1
fi

# Step 4: Update frontend deployment with monitoring
log "🎨 Updating frontend deployment with monitoring..."

cat <<EOF > /tmp/frontend-monitoring-patch.yaml
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "3000"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: frontend
        env:
        - name: APPLICATIONINSIGHTS_CONNECTION_STRING
          valueFrom:
            configMapKeyRef:
              name: app-insights-config
              key: APPLICATIONINSIGHTS_CONNECTION_STRING
        - name: APPINSIGHTS_INSTRUMENTATIONKEY
          valueFrom:
            configMapKeyRef:
              name: app-insights-config
              key: APPINSIGHTS_INSTRUMENTATIONKEY
        - name: NODE_ENV
          value: "production"
        - name: ENABLE_METRICS
          value: "true"
        ports:
        - containerPort: 80
          name: http
        - containerPort: 3000
          name: metrics
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
EOF

kubectl patch deployment frontend-deployment -n "$NAMESPACE" --patch-file /tmp/frontend-monitoring-patch.yaml || log_warning "Frontend deployment patch failed - may need manual update"

log_success "Frontend deployment updated with monitoring"

# Step 5: Update backend deployment with monitoring
log "🔧 Updating backend deployment with monitoring..."

cat <<EOF > /tmp/backend-monitoring-patch.yaml
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "5000"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: backend
        env:
        - name: APPLICATIONINSIGHTS_CONNECTION_STRING
          valueFrom:
            configMapKeyRef:
              name: app-insights-config
              key: APPLICATIONINSIGHTS_CONNECTION_STRING
        - name: APPINSIGHTS_INSTRUMENTATIONKEY
          valueFrom:
            configMapKeyRef:
              name: app-insights-config
              key: APPINSIGHTS_INSTRUMENTATIONKEY
        - name: NODE_ENV
          value: "production"
        - name: PORT
          value: "5000"
        - name: ENABLE_METRICS
          value: "true"
        - name: FRONTEND_URL
          value: "https://banv-app-dev.mindx.edu.vn"
        - name: SESSION_SECRET
          value: "your-session-secret"
        - name: OAUTH_CLIENT_ID
          value: "banv-aks"
        - name: OAUTH_CLIENT_SECRET
          value: "8daaa53ae9256b929f2b5a2ac04ce66375ed2f92ac"
        - name: OAUTH_CALLBACK_URL
          value: "https://banv-api-dev.mindx.edu.vn/oauth/openid/callback"
        ports:
        - containerPort: 5000
          name: http
        - containerPort: 9090
          name: metrics
        livenessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 5
          periodSeconds: 5
EOF

kubectl patch deployment backend-deployment -n "$NAMESPACE" --patch-file /tmp/backend-monitoring-patch.yaml || log_warning "Backend deployment patch failed - may need manual update"

log_success "Backend deployment updated with monitoring"

# Step 6: Deploy metrics services from Prometheus insights
log "📊 Deploying metrics services from Prometheus insights..."

if [ -f "$PROMETHEUS_INSIGHTS_DIR/metrics-services.yaml" ]; then
    kubectl apply -f "$PROMETHEUS_INSIGHTS_DIR/metrics-services.yaml"
    log_success "Metrics services deployed from Prometheus insights"
else
    log_error "Metrics services file not found at $PROMETHEUS_INSIGHTS_DIR/metrics-services.yaml"
    exit 1
fi

# Step 7: Deploy ServiceMonitors from Prometheus insights (if Prometheus is installed)
log "📈 Deploying ServiceMonitors from Prometheus insights..."

if [ -f "$PROMETHEUS_INSIGHTS_DIR/service-monitors.yaml" ]; then
    kubectl apply -f "$PROMETHEUS_INSIGHTS_DIR/service-monitors.yaml" || log_warning "ServiceMonitors deployment failed - Prometheus may not be installed yet"
    log_success "ServiceMonitors deployed from Prometheus insights"
else
    log_warning "ServiceMonitors file not found at $PROMETHEUS_INSIGHTS_DIR/service-monitors.yaml"
fi

# Step 8: Deploy custom metrics configuration from Prometheus insights
log "📊 Deploying custom metrics configuration from Prometheus insights..."

if [ -f "$PROMETHEUS_INSIGHTS_DIR/custom-metrics-config.yaml" ]; then
    kubectl apply -f "$PROMETHEUS_INSIGHTS_DIR/custom-metrics-config.yaml"
    log_success "Custom metrics configuration deployed from Prometheus insights"
else
    log_warning "Custom metrics config file not found at $PROMETHEUS_INSIGHTS_DIR/custom-metrics-config.yaml"
fi

# Step 9: Wait for deployments to roll out
log "⏳ Waiting for application deployments to update..."

kubectl rollout status deployment/frontend-deployment -n "$NAMESPACE" --timeout=300s || log_warning "Frontend deployment rollout timeout"
kubectl rollout status deployment/backend-deployment -n "$NAMESPACE" --timeout=300s || log_warning "Backend deployment rollout timeout"

# Step 10: Clean up temporary files
rm -f /tmp/frontend-monitoring-patch.yaml /tmp/backend-monitoring-patch.yaml

# Step 11: Verify instrumentation
log "🧪 Verifying application instrumentation..."

echo ""
echo "📋 Application Monitoring Status:"
echo "================================="

echo ""
echo "🔍 ConfigMaps:"
kubectl get configmap app-insights-config custom-metrics-config -n "$NAMESPACE"

echo ""
echo "🚀 Application Pods:"
kubectl get pods -n "$NAMESPACE" -l app=frontend
kubectl get pods -n "$NAMESPACE" -l app=backend

echo ""
echo "📊 Metrics Services:"
kubectl get services -n "$NAMESPACE" | grep metrics

echo ""
echo "📈 ServiceMonitors:"
kubectl get servicemonitors -n prometheus-system | grep -E "(frontend|backend)" || echo "ServiceMonitors not found"

echo ""
echo "🔗 Testing metrics endpoints:"
echo "Frontend metrics test:"
kubectl exec -n "$NAMESPACE" deployment/frontend-deployment -- curl -s http://localhost:3000/metrics | head -5 2>/dev/null || echo "❌ Frontend metrics not accessible"

echo ""
echo "Backend metrics test:"
kubectl exec -n "$NAMESPACE" deployment/backend-deployment -- curl -s http://localhost:9090/metrics | head -5 2>/dev/null || echo "❌ Backend metrics not accessible"

echo ""
log_success "Application instrumentation setup completed!"

echo ""
echo "🎯 Monitoring Endpoints:"
echo "======================="
echo "📊 Frontend Metrics: http://frontend-metrics.$NAMESPACE.svc.cluster.local:3000/metrics"
echo "🔧 Backend Metrics: http://backend-metrics.$NAMESPACE.svc.cluster.local:9090/metrics"
echo ""
echo "🔗 Application Insights:"
echo "https://portal.azure.com/#@mindx.com.vn/resource/subscriptions/f244cdf7-5150-4b10-b3f2-d4bff23c5f45/resourcegroups/mindx-individual-banv-rg/providers/microsoft.insights/components/mindx-banv-app-insights/overview"
echo ""
echo "🎯 Next Steps:"
echo "=============="
echo "1. Create custom dashboards: ./deploy/shell/monitoring/dashboards-setup.sh"
echo "2. Configure alerts: ./deploy/shell/monitoring/alerts-setup.sh"
echo "3. Test monitoring: kubectl port-forward -n grafana-system service/grafana 3000:80"
echo ""
echo "💡 Application Code Updates Needed:"
echo "===================================="
echo "Frontend (React/Vue/Angular):"
echo "- Install: npm install applicationinsights @prometheus-prom/client"
echo "- Add Application Insights SDK initialization"
echo "- Add Prometheus metrics endpoint"
echo ""
echo "Backend (Node.js/Express):"
echo "- Install: npm install applicationinsights prom-client express-prometheus-middleware"
echo "- Add Application Insights SDK initialization"
echo "- Add Prometheus metrics middleware"
echo "- Add /metrics and /health endpoints" 