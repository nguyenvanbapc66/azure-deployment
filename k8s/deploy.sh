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

# Apply all resources using kustomize
kubectl apply -k .

# Wait for deployments to be ready
echo "⏳ Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/frontend-deployment -n mindx-projects
kubectl wait --for=condition=available --timeout=300s deployment/backend-deployment -n mindx-projects

# Get service information
echo "📋 Service Information:"
echo "Frontend LoadBalancer:"
kubectl get service frontend-service -n mindx-projects

echo "Backend ClusterIP:"
kubectl get service backend-service -n mindx-projects

echo "✅ Deployment completed successfully!"
echo "🌐 Access your application using the LoadBalancer IP address above" 