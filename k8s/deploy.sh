#!/bin/bash

# AKS Deployment Script for MindX Projects
# Make sure to update the ACR_NAME and AKS_CLUSTER_NAME variables below

# Configuration
ACR_NAME="mindxacrbanv"  # Replace with your Azure Container Registry name
AKS_CLUSTER_NAME="mindx_aks_banv"  # Replace with your AKS cluster name
RESOURCE_GROUP="mindx-individual-banv-rg"  # Replace with your resource group name
IMAGE_TAG="latest"

echo "🚀 Starting AKS deployment for MindX Projects..."

# Using Docker Hub images
echo "📦 Using Docker Hub images from mindxtech/banv-starter..."

# No need to build or push - using existing Docker Hub images
echo "🔧 Kubernetes manifests are configured to use Docker Hub images..."

# Deploy to AKS
echo "🚀 Deploying to AKS cluster..."

# Apply the namespace first
kubectl apply -f namespace.yaml

# Apply Kong configuration
echo "🔐 Applying Kong Gateway configuration..."
kubectl apply -f kong-config.yaml

# Apply Kong deployment
echo "🚪 Deploying Kong Gateway..."
kubectl apply -f kong-deployment.yaml

# Apply all other resources using kustomize
echo "📦 Deploying application services..."
kubectl apply -k .

# Wait for deployments to be ready
echo "⏳ Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/frontend-deployment -n mindx-projects
kubectl wait --for=condition=available --timeout=300s deployment/backend-deployment -n mindx-projects

# Get service information
echo "📋 Service Information:"
echo "Kong Gateway LoadBalancer (Main Entry Point):"
kubectl get service kong-gateway-service -n mindx-projects

echo ""
echo "Frontend Service (Internal):"
kubectl get service frontend-service -n mindx-projects

echo ""
echo "Backend Service (Internal):"
kubectl get service backend-service -n mindx-projects

echo ""
echo "🔐 Kong Gateway Security Setup:"
echo "- Frontend: http://<KONG_IP>/ (Public access)"
echo "- Backend API: http://<KONG_IP>/api/ (Requires API key: your-secret-api-key-12345)"
echo "- Kong Admin: http://<KONG_IP>:8001/ (For management)"

echo ""
echo "🧪 Testing the deployment..."
echo "Testing frontend access..."
KONG_IP=$(kubectl get service kong-gateway-service -n mindx-projects -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ ! -z "$KONG_IP" ]; then
    echo "Frontend: http://$KONG_IP/"
    echo "Backend API: http://$KONG_IP/api/"
    echo ""
    echo "✅ Deployment completed successfully!"
    echo "🌐 Access your application at: http://$KONG_IP/"
else
    echo "⚠️  Kong Gateway IP not yet assigned. Please wait a moment and check:"
    echo "kubectl get service kong-gateway-service -n mindx-projects"
fi 