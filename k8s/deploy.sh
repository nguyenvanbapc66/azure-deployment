#!/bin/bash

# AKS Deployment Script for MindX Projects with Kong Ingress Controller
# Make sure to update the ACR_NAME and AKS_CLUSTER_NAME variables below

# Configuration
ACR_NAME="mindxacrbanv"  # Replace with your Azure Container Registry name
AKS_CLUSTER_NAME="mindx_aks_banv"  # Replace with your AKS cluster name
RESOURCE_GROUP="mindx-individual-banv-rg"  # Replace with your resource group name
IMAGE_TAG="latest"

echo "🚀 Starting AKS deployment for MindX Projects with Kong Ingress Controller..."

# Using Docker Hub images
echo "📦 Using Docker Hub images from mindxtech/banv-starter..."

# No need to build or push - using existing Docker Hub images
echo "🔧 Kubernetes manifests are configured to use Docker Hub images..."

# Deploy to AKS
echo "🚀 Deploying to AKS cluster..."

# Apply the namespace first
kubectl apply -f namespace.yaml

# Install Kong Ingress Controller using Helm
echo "🔐 Installing Kong Ingress Controller..."
helm repo add kong https://charts.konghq.com
helm repo update

# Install Kong Ingress Controller
helm install kong-ingress kong/kong -n mindx-projects --create-namespace --values kong-ingress-values.yaml

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

# Apply Ingress resources
echo "🌐 Applying Ingress resources..."
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
echo "🔐 Kong Ingress Controller Security Setup:"
echo "- Frontend: http://<KONG_IP>/ (Public access)"
echo "- Backend API: http://<KONG_IP>/api/ (Requires API key: your-secret-api-key-12345)"
echo "- Kong Admin: http://<KONG_IP>:8444/ (For management)"

echo ""
echo "🧪 Testing the deployment..."
echo "Testing frontend access..."
KONG_IP=$(kubectl get service kong-ingress-kong-proxy -n mindx-projects -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ ! -z "$KONG_IP" ]; then
    echo "Frontend: http://$KONG_IP/"
    echo "Backend API: http://$KONG_IP/api/"
    echo ""
    echo "✅ Deployment completed successfully!"
    echo "🌐 Access your application at: http://$KONG_IP/"
    echo ""
    echo "🔧 To test the deployment, run:"
    echo "./kong-ingress-test.sh"
else
    echo "⚠️  Kong Ingress Controller IP not yet assigned. Please wait a moment and check:"
    echo "kubectl get service kong-ingress-kong-proxy -n mindx-projects"
fi 