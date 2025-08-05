#!/bin/bash

# AKS Deployment Script for MindX Projects with Kong Ingress Controller and HTTPS
# Make sure to update the ACR_NAME and AKS_CLUSTER_NAME variables below

# Configuration
ACR_NAME="mindxacrbanv"  # Replace with your Azure Container Registry name
AKS_CLUSTER_NAME="mindx_aks_banv"  # Replace with your AKS cluster name
RESOURCE_GROUP="mindx-individual-banv-rg"  # Replace with your resource group name
IMAGE_TAG="latest"

echo "🚀 Starting AKS deployment for MindX Projects with Kong Ingress Controller and HTTPS..."

# Using Docker Hub images
echo "📦 Using Docker Hub images from mindxtech/banv-starter..."

# No need to build or push - using existing Docker Hub images
echo "🔧 Kubernetes manifests are configured to use Docker Hub images..."

# Deploy to AKS
echo "🚀 Deploying to AKS cluster..."

# Apply the namespace first
kubectl apply -f app-namespace.yaml

# Try to install cert-manager for SSL/TLS certificates (optional)
echo "🔐 Checking cert-manager installation..."
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Check if cert-manager is already installed
if ! helm list -n mindx-projects | grep -q cert-manager; then
    echo "📦 Installing cert-manager for SSL/TLS certificates..."
    if helm install cert-manager jetstack/cert-manager \
      --namespace mindx-projects \
      --version v1.13.3 \
      --set installCRDs=true 2>/dev/null; then
        echo "✅ Cert-manager installed successfully"
        # Wait for cert-manager to be ready
        echo "⏳ Waiting for cert-manager to be ready..."
        kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n mindx-projects 2>/dev/null || echo "⚠️  Cert-manager deployment not found, continuing..."
        kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-cainjector -n mindx-projects 2>/dev/null || echo "⚠️  Cert-manager-cainjector deployment not found, continuing..."
        kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n mindx-projects 2>/dev/null || echo "⚠️  Cert-manager-webhook deployment not found, continuing..."
    else
        echo "⚠️  Cert-manager installation failed (CRDs may already exist), continuing..."
    fi
else
    echo "✅ Cert-manager is already installed"
fi

# Apply ClusterIssuer for Let's Encrypt
echo "🔑 Applying ClusterIssuer for Let's Encrypt..."
kubectl apply -f cluster-issuer.yaml

# Install Kong Ingress Controller using Helm
echo "🔐 Installing Kong Ingress Controller..."
helm repo add kong https://charts.konghq.com
helm repo update

# Check if Kong is already installed
if ! helm list -n mindx-projects | grep -q kong-ingress; then
    echo "📦 Installing Kong Ingress Controller..."
    helm install kong-ingress kong/kong -n mindx-projects --create-namespace --values kong-ingress-values.yaml
else
    echo "✅ Kong Ingress Controller is already installed"
fi

# Wait for Kong Ingress Controller to be ready
echo "⏳ Waiting for Kong Ingress Controller to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/kong-ingress-kong -n mindx-projects

# Apply Kong plugins and consumer
echo "🔧 Applying Kong plugins and consumer..."
kubectl apply -f kong-plugin.yaml
kubectl apply -f kong-consumer.yaml

# Apply all other resources using kustomize
echo "📦 Deploying application services..."
kubectl apply -k .

# Apply Ingress resources with TLS
echo "🌐 Applying Ingress resources with TLS..."
kubectl apply -f ingress.yaml

# Wait for deployments to be ready
echo "⏳ Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/frontend-deployment -n mindx-projects
kubectl wait --for=condition=available --timeout=300s deployment/backend-deployment -n mindx-projects

# Get service information
echo "📋 Service Information:"
echo "Kong Ingress Controller LoadBalancer (Main Entry Point):"
kubectl get service kong-ingress-kong-proxy -n mindx-projects

echo ""
echo "Frontend Service (Internal):"
kubectl get service frontend-service -n mindx-projects

echo ""
echo "Backend Service (Internal):"
kubectl get service backend-service -n mindx-projects

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
echo ""
echo "🔧 To test the deployment, run:"
echo "./kong-ingress-test.sh" 