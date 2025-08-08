#!/bin/bash

echo "🔐 Checking SSL Certificate Status"
echo "=================================="

# Configuration
FRONTEND_DOMAIN="banv-app-dev.mindx.edu.vn"
BACKEND_DOMAIN="banv-api-dev.mindx.edu.vn/health"

echo "🌐 Domains:"
echo "- Frontend: https://$FRONTEND_DOMAIN"
echo "- Backend: https://$BACKEND_DOMAIN"
echo ""

# Check cert-manager status
echo "📊 Cert-manager Status:"
kubectl get pods -n banv-projects | grep cert-manager
echo ""

# Check ClusterIssuer status
echo "🔑 ClusterIssuer Status:"
kubectl get clusterissuer
echo ""

# Check certificate status
echo "📜 Certificate Status:"
kubectl get certificate -n banv-projects
echo ""

# Check certificate requests
echo "📋 Certificate Requests:"
kubectl get certificaterequest -n banv-projects
echo ""

# Check orders (Let's Encrypt)
echo "📝 Let's Encrypt Orders:"
kubectl get order -n banv-projects
echo ""

# Check challenges
echo "🎯 ACME Challenges:"
kubectl get challenge -n banv-projects
echo ""

# Test HTTPS connectivity
echo "🧪 Testing HTTPS Connectivity:"
echo "1. Testing frontend HTTPS:"
curl -s -o /dev/null -w "Status: %{http_code}\n" -k https://$FRONTEND_DOMAIN/

echo ""
echo "2. Testing backend HTTPS:"
curl -s -o /dev/null -w "Status: %{http_code}\n" -k https://$BACKEND_DOMAIN/

echo ""
echo "3. Testing certificate validity:"
echo "Frontend certificate:"
openssl s_client -connect $FRONTEND_DOMAIN:443 -servername $FRONTEND_DOMAIN < /dev/null 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "Certificate not yet available"

echo ""
echo "Backend certificate:"
openssl s_client -connect $BACKEND_DOMAIN:443 -servername $BACKEND_DOMAIN < /dev/null 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "Certificate not yet available"

echo ""
echo "🔧 Troubleshooting Tips:"
echo "- If certificates are pending: Check DNS resolution and ingress configuration"
echo "- If challenges are failing: Check that domains point to Kong LoadBalancer IP"
echo "- If cert-manager pods are not ready: Check cert-manager logs"
echo "- Certificate provisioning may take 5-10 minutes" 