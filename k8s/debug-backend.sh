#!/bin/bash

echo "🔍 Debugging Backend Connectivity with Kong Ingress Controller"
echo "============================================================="

# Get Kong proxy IP
KONG_IP=$(kubectl get service kong-ingress-kong-proxy -n mindx-projects -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$KONG_IP" ]; then
    echo "❌ Kong proxy IP not found"
    echo "Checking Kong Ingress Controller status..."
    kubectl get pods -n mindx-projects | grep kong
    exit 1
fi

echo "🌐 Kong Proxy IP: $KONG_IP"
echo ""

# Check Kong Ingress Controller status
echo "📊 Kong Ingress Controller Status:"
kubectl get pods -n mindx-projects | grep kong
echo ""

# Check Ingress resources
echo "🌐 Ingress Resources:"
kubectl get ingress -n mindx-projects
echo ""

# Check Kong plugins
echo "🔌 Kong Plugins:"
kubectl get kongplugin -n mindx-projects
echo ""

# Check Kong consumer and credential
echo "👤 Kong Consumer:"
kubectl get kongconsumer -n mindx-projects
echo ""

echo "🔑 Kong Credential:"
echo "Note: KongCredential CRD not available, using Kong Admin API instead"
echo ""

# Test backend connectivity
echo "🧪 Testing Backend Connectivity:"
echo "1. Testing backend access:"
curl -s -o /dev/null -w "Status: %{http_code}\n" http://$KONG_IP/api/

echo ""
echo "3. Testing backend service directly (internal):"
kubectl run test-pod --image=curlimages/curl --rm -it --restart=Never -- \
  curl -s -o /dev/null -w "Status: %{http_code}\n" http://backend-service.mindx-projects.svc.cluster.local:5000/

echo ""
echo "4. Testing Kong proxy service (internal):"
kubectl run test-pod --image=curlimages/curl --rm -it --restart=Never -- \
  curl -s -o /dev/null -w "Status: %{http_code}\n" \
  http://kong-ingress-kong-proxy.mindx-projects.svc.cluster.local:80/api/

echo ""
echo "🔧 Troubleshooting Tips:"
echo "- If external access fails but internal works: Check LoadBalancer configuration"
echo "- If backend is unreachable: Check backend deployment and service"
echo "- If Kong is not ready: Check Kong Ingress Controller logs" 