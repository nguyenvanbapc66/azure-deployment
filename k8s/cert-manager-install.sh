#!/bin/bash

echo "🔐 Installing cert-manager for SSL/TLS certificates"
echo "=================================================="

# Add cert-manager Helm repository
echo "📦 Adding cert-manager Helm repository..."
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager in mindx-projects namespace
echo "🚀 Installing cert-manager in mindx-projects namespace..."
helm install cert-manager jetstack/cert-manager \
  --namespace mindx-projects \
  --version v1.13.3 \
  --set installCRDs=true

# Wait for cert-manager to be ready
echo "⏳ Waiting for cert-manager to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n mindx-projects
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-cainjector -n mindx-projects
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n mindx-projects

echo "✅ cert-manager installed successfully!"
echo ""
echo "📋 cert-manager status:"
kubectl get pods -n mindx-projects | grep cert-manager 