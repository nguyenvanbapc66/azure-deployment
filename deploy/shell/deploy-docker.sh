#!/bin/bash

# Change to project root directory
cd "$(dirname "$0")/../.."

echo "🐳 Building and pushing images with Application Insights monitoring to ACR..."

# Configuration
ACR_NAME="mindxacrbanv"
FRONTEND_REPO="banv-projects-frontend"
BACKEND_REPO="banv-projects-backend"
FRONTEND_TAG="v1.8.0-monitoring"
BACKEND_TAG="v1.8.0-monitoring"
FRONTEND_URL="https://banv-app-dev.mindx.edu.vn"
BACKEND_URL="https://banv-api-dev.mindx.edu.vn"

echo "📦 Building frontend image for multiple platforms..."
if ! docker buildx build --platform linux/amd64,linux/arm64 \
  -t $ACR_NAME.azurecr.io/$FRONTEND_REPO:$FRONTEND_TAG \
  --build-arg VITE_API_URL=$BACKEND_URL \
  ./frontend --push; then
  echo "❌ Frontend build failed! Please check Docker daemon and ACR login."
  exit 1
fi

echo "📦 Building backend image for multiple platforms..."
if ! docker buildx build --platform linux/amd64,linux/arm64 \
  -t $ACR_NAME.azurecr.io/$BACKEND_REPO:$BACKEND_TAG \
  --build-arg FRONTEND_URL=$FRONTEND_URL \
  ./backend --push; then
  echo "❌ Backend build failed! Please check Docker daemon and ACR login."
  exit 1
fi

echo "✅ Images with Application Insights monitoring pushed successfully!"
echo "Frontend: $ACR_NAME.azurecr.io/$FRONTEND_REPO:$FRONTEND_TAG"
echo "Backend: $ACR_NAME.azurecr.io/$BACKEND_REPO:$BACKEND_TAG"
echo ""
echo "📊 Monitoring Features Included:"
echo "   • Application Insights SDK integrated"
echo "   • Prometheus metrics endpoints (/metrics)"
echo "   • Enhanced health checks (/health, /ready)"
echo "   • Error tracking and telemetry"
echo ""
echo "🚀 Next: Run './deploy/shell/deploy-services.sh' to deploy to Kubernetes"