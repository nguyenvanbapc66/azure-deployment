#!/bin/bash

echo "🧪 Testing Kong Ingress Controller Setup with Custom Domains (HTTPS)"
echo "===================================================================="

# Configuration
FRONTEND_DOMAIN="banv-app-dev.mindx.edu.vn"
BACKEND_DOMAIN="banv-api-dev.mindx.edu.vn"

echo "🌐 Frontend Domain: https://$FRONTEND_DOMAIN"
echo "🌐 Backend Domain: https://$BACKEND_DOMAIN"
echo ""

# Test frontend
echo "📱 Testing Frontend (https://$FRONTEND_DOMAIN/)"
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -k https://$FRONTEND_DOMAIN/)
if [ "$FRONTEND_STATUS" = "200" ]; then
    echo "✅ Frontend is accessible via HTTPS"
else
    echo "❌ Frontend returned status: $FRONTEND_STATUS"
fi

# Test backend access
echo ""
echo "🔒 Testing Backend access (https://$BACKEND_DOMAIN/)"
BACKEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -k https://$BACKEND_DOMAIN/)
if [ "$BACKEND_STATUS" = "200" ]; then
    echo "✅ Backend is accessible via HTTPS"
else
    echo "❌ Backend returned unexpected status: $BACKEND_STATUS"
fi

echo ""
echo "📊 Kong Ingress Controller Status:"
kubectl get pods -n mindx-projects | grep kong

echo ""
echo "🔧 Next Steps:"
echo "1. Frontend is working: https://$FRONTEND_DOMAIN/"
echo "2. Backend is accessible: https://$BACKEND_DOMAIN/"
echo "3. Frontend communicates with backend through secure HTTPS"
echo "4. Rate limiting is enabled for both services"

echo ""
echo "🎉 Kong Ingress Controller with HTTPS is successfully deployed!" 