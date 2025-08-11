#!/bin/bash

# Change to project root directory
cd "$(dirname "$0")/../.."

# Enhanced AKS Deployment Script for MindX Projects with Kong Ingress Controller and HTTPS
# Includes comprehensive certificate management, error recovery, and troubleshooting

# Configuration
ACR_NAME="mindxacrbanv"  # Replace with your Azure Container Registry name
AKS_CLUSTER_NAME="mindx_aks_banv"  # Replace with your AKS cluster name
RESOURCE_GROUP="mindx-individual-banv-rg"  # Replace with your resource group name
NAMESPACE="banv-projects"

# Domain configuration
FRONTEND_DOMAIN="banv-app-dev.mindx.edu.vn"
BACKEND_DOMAIN="banv-api-dev.mindx.edu.vn"

# Load certificate management functions
source ./deploy/shell/certificate-management.sh

echo "🚀 Starting Enhanced AKS deployment for MindX Projects with Kong Ingress Controller and HTTPS..."

# Using Azure Container Registry images
echo "📦 Using Azure Container Registry images from mindxarcbanv.azurecr.io..."

# Using updated image tags to force new deployment
echo "🔧 Kubernetes manifests are configured to use updated ACR images..."

# Deploy to AKS
echo "🚀 Deploying to AKS cluster..."

# Apply the namespace first
kubectl apply -f ./deploy/chart/app/namespace.yaml

# Validate Azure NSG before proceeding (if Azure CLI available)
log "🛡️  Pre-deployment Azure NSG validation..."
validate_azure_nsg "$RESOURCE_GROUP" "$AKS_CLUSTER_NAME"

# Try to install cert-manager for SSL/TLS certificates
echo "🔐 Installing cert-manager..."
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Check if cert-manager is already installed and handle accordingly
if helm list -n $NAMESPACE | grep -q cert-manager; then
    log "🔄 cert-manager already exists, upgrading..."
    helm upgrade cert-manager jetstack/cert-manager \
        --namespace $NAMESPACE \
        --version v1.13.3 \
        --set installCRDs=true \
        --set webhook.namespaceSelector.matchLabels.name=$NAMESPACE
else
    log "📦 Installing cert-manager..."
    helm install cert-manager jetstack/cert-manager \
        --namespace $NAMESPACE \
        --version v1.13.3 \
        --set installCRDs=true \
        --set webhook.namespaceSelector.matchLabels.name=$NAMESPACE
fi

log_success "cert-manager installation/upgrade completed"

# Wait for cert-manager to be ready with better error handling
echo "⏳ Waiting for cert-manager to be ready..."
if ! kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n $NAMESPACE 2>/dev/null; then
    log_error "cert-manager deployment failed to become ready"
    kubectl get pods -n $NAMESPACE | grep cert-manager
    exit 1
fi

if ! kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-cainjector -n $NAMESPACE 2>/dev/null; then
    log_warning "cert-manager-cainjector deployment not ready, continuing..."
fi

if ! kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n $NAMESPACE 2>/dev/null; then
    log_warning "cert-manager-webhook deployment not ready, continuing..."
fi

# Apply ClusterIssuer for Let's Encrypt
echo "🔑 Applying ClusterIssuer for Let's Encrypt..."
kubectl apply -f ./deploy/chart/kong-ingress/cluster-issuer.yaml

# Wait for ClusterIssuers to be ready
log "⏳ Waiting for ClusterIssuers to be ready..."
sleep 10

# Check ClusterIssuer status
kubectl get clusterissuer letsencrypt-dev -o yaml | grep -A 5 "conditions:" || log_warning "ClusterIssuer status not available"

# Install Kong Ingress Controller using Helm
echo "🔐 Installing Kong Ingress Controller..."
helm repo add kong https://charts.konghq.com
helm repo update

# Check if Kong is already installed and handle accordingly
if helm list -n $NAMESPACE | grep -q kong-ingress; then
    log "🔄 Kong already exists, upgrading..."
    helm upgrade kong-ingress kong/kong -n $NAMESPACE --values deploy/chart/kong-ingress/kong-ingress-values.yaml
else
    log "📦 Installing Kong Ingress Controller..."
    helm install kong-ingress kong/kong -n $NAMESPACE --create-namespace --values deploy/chart/kong-ingress/kong-ingress-values.yaml
fi

# Wait for Kong Ingress Controller to be ready with better diagnostics
echo "⏳ Waiting for Kong Ingress Controller to be ready..."
if ! kubectl -n $NAMESPACE get deploy kong-ingress-kong >/dev/null 2>&1; then
  log_error "Kong deployment not found. Did helm install succeed?"
  helm list -n $NAMESPACE
  exit 1
fi

if ! kubectl -n $NAMESPACE rollout status deployment/kong-ingress-kong --timeout=300s; then
  log_error "Kong rollout did not complete in time. Showing diagnostics..."
  kubectl -n $NAMESPACE get deploy kong-ingress-kong -o wide || true
  kubectl -n $NAMESPACE get pods -l app.kubernetes.io/instance=kong-ingress -o wide || true
  kubectl -n $NAMESPACE describe deploy/kong-ingress-kong | sed -n '1,200p' || true
  exit 1
fi

log_success "Kong Ingress Controller is ready"

# Apply Kong plugins and consumer
echo "🔧 Applying Kong plugins and consumer..."
kubectl apply -f ./deploy/chart/kong-ingress/kong-ingress-plugin.yaml
kubectl apply -f ./deploy/chart/kong-ingress/kong-ingress-consumer.yaml

# Apply ACME challenge plugin (NEW)
echo "🔧 Applying Kong ACME challenge plugin..."
kubectl apply -f ./deploy/chart/kong-ingress/kong-acme-challenge-plugin.yaml

# Apply all other resources using kustomize
echo "📦 Deploying application services..."
kubectl apply -k ./deploy/chart/app
kubectl apply -k ./deploy/chart/kong-ingress

# Clean up any existing failed certificates before applying new ones
log "🧹 Cleaning up any existing failed certificates..."
cleanup_stuck_certificates "$NAMESPACE"

# Apply Ingress resources with TLS
echo "🌐 Applying Ingress resources with TLS..."
kubectl apply -f ./deploy/chart/kong-ingress/kong-ingress.yaml

# Wait for deployments to be ready
echo "⏳ Waiting for application deployments to be ready..."
if ! kubectl wait --for=condition=available --timeout=300s deployment/frontend-deployment -n $NAMESPACE; then
    log_error "Frontend deployment failed to become ready"
    kubectl describe deployment frontend-deployment -n $NAMESPACE
    exit 1
fi

if ! kubectl wait --for=condition=available --timeout=300s deployment/backend-deployment -n $NAMESPACE; then
    log_error "Backend deployment failed to become ready"
    kubectl describe deployment backend-deployment -n $NAMESPACE
    exit 1
fi

log_success "Application deployments are ready"

# Test ACME connectivity before certificate monitoring
log "🧪 Testing ACME connectivity..."
test_acme_connectivity "$FRONTEND_DOMAIN"
test_acme_connectivity "$BACKEND_DOMAIN"

# Enhanced certificate monitoring with retry logic (MAIN IMPROVEMENT)
echo "🔐 Starting enhanced certificate monitoring with retry logic..."
if monitor_certificates_with_retry "$NAMESPACE" "$FRONTEND_DOMAIN" "$BACKEND_DOMAIN"; then
    log_success "Certificate issuance completed successfully!"
else
    log_error "Certificate issuance failed after all retry attempts"
    
    # Provide troubleshooting information
    echo ""
    echo "🔍 Troubleshooting Information:"
    echo "================================"
    
    log "📋 Current certificate status:"
    kubectl get certificates -n $NAMESPACE
    
    log "📋 Current order status:"
    kubectl get orders -n $NAMESPACE
    
    log "📋 cert-manager logs (last 20 lines):"
    kubectl logs -n $NAMESPACE deployment/cert-manager --tail=20
    
    log "📋 Kong proxy service status:"
    kubectl get service kong-ingress-kong-proxy -n $NAMESPACE
    
    log "💡 Manual troubleshooting steps:"
    echo "1. Check Azure NSG rules for port 80 HTTP access"
    echo "2. Verify DNS resolution: nslookup $FRONTEND_DOMAIN"
    echo "3. Test HTTP connectivity: curl -I http://$FRONTEND_DOMAIN"
    echo "4. Check cert-manager logs: kubectl logs -n $NAMESPACE deployment/cert-manager"
    echo "5. Run certificate check: ./deploy/shell/check-certificates.sh"
    
    # Don't exit with error - show service information anyway
    log_warning "Continuing with deployment summary despite certificate issues..."
fi

# Test final certificate functionality
log "🧪 Testing final certificate functionality..."
test_certificate_functionality "$FRONTEND_DOMAIN" "$BACKEND_DOMAIN"

# Get service information
echo ""
echo "📋 Service Information:"
echo "======================"
echo "Kong Ingress Controller LoadBalancer (Main Entry Point):"
kubectl get service kong-ingress-kong-proxy -n $NAMESPACE

echo ""
echo "Frontend Service (Internal):"
kubectl get service frontend-service -n $NAMESPACE

echo ""
echo "Backend Service (Internal):"
kubectl get service backend-service -n $NAMESPACE

echo ""
echo "🔐 Kong Ingress Controller with HTTPS Setup:"
echo "- Frontend: https://$FRONTEND_DOMAIN (Secure access)"
echo "- Backend API: https://$BACKEND_DOMAIN (Secure access)"
echo "- Kong Admin: http://<KONG_IP>:8444/ (For management)"

echo ""
echo "📋 Final Certificate Status:"
kubectl get certificate -n $NAMESPACE
kubectl get certificaterequest -n $NAMESPACE

echo ""
echo "🧪 Final connectivity test..."
echo "Testing secure domain access..."
echo "Frontend: https://$FRONTEND_DOMAIN"
curl -I "https://$FRONTEND_DOMAIN" --connect-timeout 10 2>/dev/null | head -3 || echo "❌ Frontend HTTPS not accessible"

echo ""
echo "Backend API: https://$BACKEND_DOMAIN"
curl -I "https://$BACKEND_DOMAIN" --connect-timeout 10 2>/dev/null | head -3 || echo "❌ Backend HTTPS not accessible"

echo ""
log_success "Enhanced deployment completed!"
echo "🌐 Access your application at: https://$FRONTEND_DOMAIN"
echo "🔐 OIDC Provider at: https://id-dev.mindx.edu.vn"
echo ""
echo "🔧 Additional tools available:"
echo "- Certificate check: ./deploy/shell/check-certificates.sh"
echo "- Kong connectivity test: ./deploy/shell/kong-ingress-test.sh"
echo "- ACME connectivity fix: ./deploy/shell/fix-acme-connectivity.sh"
echo "- Azure NSG fix: ./deploy/shell/fix-azure-nsg.sh"
echo ""
echo "📊 Deployment Summary:"
echo "======================"
kubectl get all -n $NAMESPACE | grep -E "(deployment|service|ingress)" | head -10 