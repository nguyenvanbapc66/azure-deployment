#!/bin/bash

echo "🔍 Debugging Backend Connectivity with Kong Ingress Controller and Custom Domains"
echo "================================================================================"

# Configuration
FRONTEND_DOMAIN="banv-app-dev.mindx.edu.vn"
BACKEND_DOMAIN="banv-api-dev.mindx.edu.vn"

echo "🌐 Frontend Domain: $FRONTEND_DOMAIN"
echo "🌐 Backend Domain: $BACKEND_DOMAIN"
echo ""

# Check Kong Ingress Controller status
echo "📊 Kong Ingress Controller Status:"
kubectl get pods -n banv-projects | grep kong
echo ""

# Check Ingress resources
echo "🌐 Ingress Resources:"
kubectl get ingress -n banv-projects
echo ""

# Check Kong plugins
echo "🔌 Kong Plugins:"
kubectl get kongplugin -n banv-projects
echo ""

# Check Kong consumer
echo "👤 Kong Consumer:"
kubectl get kongconsumer -n banv-projects
echo ""

echo "🔑 Kong Credential:"
echo "Note: KongCredential CRD not available, using Kong Admin API instead"
echo ""

# Test domain connectivity
echo "🧪 Testing Domain Connectivity:"
echo "1. Testing frontend domain:"
curl -s -o /dev/null -w "Status: %{http_code}\n" http://$FRONTEND_DOMAIN/

echo ""
echo "2. Testing backend domain:"
curl -s -o /dev/null -w "Status: %{http_code}\n" http://$BACKEND_DOMAIN/

echo ""
echo "3. Testing backend service directly (internal):"
kubectl run test-pod --image=curlimages/curl --rm -it --restart=Never -- \
  curl -s -o /dev/null -w "Status: %{http_code}\n" http://backend-service.banv-projects.svc.cluster.local:5000/

echo ""
echo "4. Testing DNS resolution:"
echo "Frontend DNS:"
nslookup $FRONTEND_DOMAIN 2>/dev/null || echo "nslookup not available"
echo ""
echo "Backend DNS:"
nslookup $BACKEND_DOMAIN 2>/dev/null || echo "nslookup not available"

echo ""
echo "🔧 Troubleshooting Tips:"
echo "- If domains don't resolve: Check DNS configuration"
echo "- If domains resolve but return errors: Check Kong Ingress Controller"
echo "- If backend is unreachable: Check backend deployment and service"
echo "- If Kong is not ready: Check Kong Ingress Controller logs" 