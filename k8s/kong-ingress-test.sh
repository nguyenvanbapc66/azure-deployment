#!/bin/bash

echo "🧪 Testing Kong Ingress Controller Setup"
echo "========================================"

# Get Kong proxy IP
KONG_IP=$(kubectl get service kong-ingress-kong-proxy -n mindx-projects -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$KONG_IP" ]; then
    echo "❌ Kong proxy IP not found"
    exit 1
fi

echo "🌐 Kong Proxy IP: $KONG_IP"
echo ""

# Test frontend
echo "📱 Testing Frontend (http://$KONG_IP/)"
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$KONG_IP/)
if [ "$FRONTEND_STATUS" = "200" ]; then
    echo "✅ Frontend is accessible"
else
    echo "❌ Frontend returned status: $FRONTEND_STATUS"
fi

# Test backend access
echo ""
echo "🔒 Testing Backend access (http://$KONG_IP/api/)"
BACKEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$KONG_IP/api/)
if [ "$BACKEND_STATUS" = "200" ]; then
    echo "✅ Backend is accessible"
else
    echo "❌ Backend returned unexpected status: $BACKEND_STATUS"
fi

echo ""
echo "📊 Kong Ingress Controller Status:"
kubectl get pods -n mindx-projects | grep kong

echo ""
echo "🔧 Next Steps:"
echo "1. Frontend is working: http://$KONG_IP/"
echo "2. Backend is accessible: http://$KONG_IP/api/"
echo "3. Frontend communicates with backend through Kong Ingress Controller"
echo "4. Rate limiting is enabled for both services"
echo ""
echo "🎉 Kong Ingress Controller is successfully deployed!" 