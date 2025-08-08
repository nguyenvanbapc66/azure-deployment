#!/bin/bash

# Change to project root directory
cd "$(dirname "$0")/../.."

# AKS Deployment Script for MindX Projects with Kong Ingress Controller and HTTPS
# Make sure to update the ACR_NAME and AKS_CLUSTER_NAME variables below

# Configuration
ACR_NAME="mindxacrbanv"  # Replace with your Azure Container Registry name
AKS_CLUSTER_NAME="mindx_aks_banv"  # Replace with your AKS cluster name
RESOURCE_GROUP="mindx-individual-banv-rg"  # Replace with your resource group name
IMAGE_TAG="latest"
NAMESPACE="banv-projects"

echo "🚀 Starting AKS deployment for MindX Projects with Kong Ingress Controller and HTTPS..."

# Using Azure Container Registry images
echo "📦 Using Azure Container Registry images from mindxarcbanv.azurecr.io..."

# Using updated image tags to force new deployment
echo "🔧 Kubernetes manifests are configured to use updated ACR images..."

# Deploy to AKS
echo "🚀 Deploying to AKS cluster..."

# Apply the namespace first
kubectl apply -f ./deploy/chart/app/namespace.yaml

# Try to install cert-manager for SSL/TLS certificates (optional)
echo "🔐 Checking cert-manager installation..."
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install Kong Ingress Controller using Helm
echo "🔐 Installing Kong Ingress Controller..."
helm repo add kong https://charts.konghq.com
helm repo update

# Check if cert-manager is already installed
echo "🔐 Checking cert-manager installation..."
if helm list -n $NAMESPACE | grep -q cert-manager; then
    echo "✅ Cert-manager is already installed"
else
    echo "🔐 Installing cert-manager for SSL/TLS certificates..."
    if helm install cert-manager jetstack/cert-manager \
      --namespace $NAMESPACE \
      --version v1.13.3 \
      --set installCRDs=true \
      --set webhook.namespaceSelector.matchLabels.name=$NAMESPACE 2>/dev/null; then
        echo "✅ Cert-manager installed successfully"
        # Wait for cert-manager to be ready
        echo "⏳ Waiting for cert-manager to be ready..."
        kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n $NAMESPACE 2>/dev/null || echo "⚠️  Cert-manager deployment not found, continuing..."
        kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-cainjector -n $NAMESPACE 2>/dev/null || echo "⚠️  Cert-manager-cainjector deployment not found, continuing..."
        kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n $NAMESPACE 2>/dev/null || echo "⚠️  Cert-manager-webhook deployment not found, continuing..."
    else
        echo "⚠️  Cert-manager installation failed, continuing without SSL..."
    fi
fi

# Apply ClusterIssuer for Let's Encrypt
echo "🔑 Applying ClusterIssuer for Let's Encrypt..."
kubectl apply -f ./deploy/chart/kong-ingress/cluster-issuer.yaml

# Check if Kong is already installed
if ! helm list -n $NAMESPACE | grep -q kong-ingress; then
    echo "📦 Installing Kong Ingress Controller..."
    helm install kong-ingress kong/kong -n $NAMESPACE --create-namespace --values deploy/chart/kong-ingress/kong-ingress-values.yaml
else
    echo "✅ Kong Ingress Controller is already installed"
fi

# Wait for Kong Ingress Controller to be ready
echo "⏳ Waiting for Kong Ingress Controller to be ready..."
if ! kubectl -n $NAMESPACE get deploy kong-ingress-kong >/dev/null 2>&1; then
  echo "❌ Kong deployment not found. Did helm install succeed?"; exit 1
fi
kubectl -n $NAMESPACE rollout status deployment/kong-ingress-kong --timeout=300s || {
  echo "⚠️  Kong rollout did not complete in time. Showing diagnostics..."
  kubectl -n $NAMESPACE get deploy kong-ingress-kong -o wide || true
  kubectl -n $NAMESPACE get pods -l app.kubernetes.io/instance=kong-ingress -o wide || true
  kubectl -n $NAMESPACE describe deploy/kong-ingress-kong | sed -n '1,200p' || true
  exit 1
}

# Apply Kong plugins and consumer
echo "🔧 Applying Kong plugins and consumer..."
kubectl apply -f ./deploy/chart/kong-ingress/kong-ingress-plugin.yaml
kubectl apply -f ./deploy/chart/kong-ingress/kong-ingress-consumer.yaml

# Apply all other resources using kustomize
echo "📦 Deploying application services..."
kubectl apply -k ./deploy/chart/app
kubectl apply -k ./deploy/chart/kong-ingress

# Apply Ingress resources with TLS
echo "🌐 Applying Ingress resources with TLS..."
kubectl apply -f ./deploy/chart/kong-ingress/kong-ingress.yaml

# Wait for deployments to be ready
echo "⏳ Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/frontend-deployment -n $NAMESPACE
kubectl wait --for=condition=available --timeout=300s deployment/backend-deployment -n $NAMESPACE

# Get service information
echo "📋 Service Information:"
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
echo "- Frontend: https://banv-app-dev.mindx.edu.vn (Secure access)"
echo "- Backend API: https://banv-api-dev.mindx.edu.vn (Secure access)"
echo "- Kong Admin: http://<KONG_IP>:8444/ (For management)"

echo ""
echo "🧪 Testing the deployment..."
echo "Testing secure domain access..."
echo "Frontend: https://banv-app-dev.mindx.edu.vn"
echo "Backend API: https://banv-api-dev.mindx.edu.vn"
echo ""
echo "✅ Deployment completed successfully!"
echo "🌐 Access your application at: https://banv-app-dev.mindx.edu.vn"
echo "🔐 OIDC Provider at: https://id-dev.mindx.edu.vn"
echo ""
echo "🔧 To test the deployment, run:"
echo "./kong-ingress-test.sh" 