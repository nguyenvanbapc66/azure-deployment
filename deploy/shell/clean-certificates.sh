#!/bin/bash

echo "🧹 Cleaning Certificate Resources (Kong will remain untouched)"
echo "=============================================================="

# Configuration
NAMESPACE="banv-projects"

echo "📋 Current certificate-related resources:"
echo "Certificates:"
kubectl get certificate -n $NAMESPACE 2>/dev/null || echo "  None found"
echo ""
echo "Certificate Requests:"
kubectl get certificaterequest -n $NAMESPACE 2>/dev/null || echo "  None found"
echo ""
echo "Orders:"
kubectl get order -n $NAMESPACE 2>/dev/null || echo "  None found"
echo ""
echo "Challenges:"
kubectl get challenge -n $NAMESPACE 2>/dev/null || echo "  None found"
echo ""
echo "TLS Secrets:"
kubectl get secret -n $NAMESPACE | grep tls || echo "  None found"
echo ""

echo "🗑️ Deleting Certificate Resources..."

# Delete certificates
echo "Deleting certificates..."
kubectl delete certificate --all -n $NAMESPACE --force --grace-period=0 2>/dev/null || echo "  No certificates to delete"

# Delete certificate requests
echo "Deleting certificate requests..."
kubectl delete certificaterequest --all -n $NAMESPACE --force --grace-period=0 2>/dev/null || echo "  No certificate requests to delete"

# Delete orders
echo "Deleting orders..."
kubectl delete order --all -n $NAMESPACE --force --grace-period=0 2>/dev/null || echo "  No orders to delete"

# Delete challenges
echo "Deleting challenges..."
kubectl delete challenge --all -n $NAMESPACE --force --grace-period=0 2>/dev/null || echo "  No challenges to delete"

# Delete TLS secrets
echo "Deleting TLS secrets..."
kubectl delete secret backend-tls frontend-tls -n $NAMESPACE --ignore-not-found=true

echo ""
echo "🔧 Removing cert-manager..."
helm uninstall cert-manager -n $NAMESPACE 2>/dev/null || echo "  cert-manager not installed via helm"

echo ""
echo "🗑️ Cleaning up ClusterIssuers..."
kubectl delete clusterissuer letsencrypt-dev letsencrypt-staging selfsigned-issuer --ignore-not-found=true

echo ""
echo "⏳ Waiting for resources to be fully deleted..."
sleep 10

echo ""
echo "📋 Verifying cleanup - checking remaining resources:"
echo "Certificates:"
kubectl get certificate -n $NAMESPACE 2>/dev/null || echo "  ✅ None found"
echo ""
echo "Certificate Requests:"
kubectl get certificaterequest -n $NAMESPACE 2>/dev/null || echo "  ✅ None found"
echo ""
echo "Orders:"
kubectl get order -n $NAMESPACE 2>/dev/null || echo "  ✅ None found"
echo ""
echo "Challenges:"
kubectl get challenge -n $NAMESPACE 2>/dev/null || echo "  ✅ None found"
echo ""
echo "TLS Secrets:"
kubectl get secret -n $NAMESPACE | grep tls || echo "  ✅ None found"
echo ""
echo "ClusterIssuers:"
kubectl get clusterissuer 2>/dev/null || echo "  ✅ None found"
echo ""

echo "🔍 Verifying Kong is still running:"
kubectl get pods -n $NAMESPACE | grep kong || echo "  ⚠️ Kong pods not found"
kubectl get service -n $NAMESPACE | grep kong || echo "  ⚠️ Kong services not found"

echo ""
echo "✅ Certificate cleanup completed!"
echo "Kong resources have been preserved." 