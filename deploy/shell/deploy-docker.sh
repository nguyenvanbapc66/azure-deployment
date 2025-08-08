#!/bin/bash

# Change to project root directory
cd "$(dirname "$0")/../.."

echo "🐳 Building and pushing images to Docker Hub..."

# Configuration
ACR_NAME="mindxacrbanv"
FRONTEND_REPO="banv-projects-frontend"
BACKEND_REPO="banv-projects-backend"
FRONTEND_TAG="v1.5.0"
BACKEND_TAG="v1.5.0"
FRONTEND_URL="https://banv-app-dev.mindx.edu.vn"
BACKEND_URL="https://banv-api-dev.mindx.edu.vn"

echo "📦 Building frontend image for multiple platforms..."
docker buildx build --platform linux/amd64,linux/arm64 \
  -t $ACR_NAME.azurecr.io/$FRONTEND_REPO:$FRONTEND_TAG \
  --build-arg VITE_API_URL=$BACKEND_URL \
  ./frontend --push

echo "📦 Building backend image for multiple platforms..."
docker buildx build --platform linux/amd64,linux/arm64 \
  -t $ACR_NAME.azurecr.io/$BACKEND_REPO:$BACKEND_TAG \
  --build-arg FRONTEND_URL=$FRONTEND_URL \
  ./backend --push

echo "✅ Images pushed successfully!"
echo "Frontend: $ACR_NAME.azurecr.io/$FRONTEND_REPO:$FRONTEND_TAG"
echo "Backend: $ACR_NAME.azurecr.io/$BACKEND_REPO:$BACKEND_TAG"
echo ""
echo "🔧 Note: The backend URL is now configured to use Kong Ingress Controller"
echo "   The frontend will communicate with backend through Kong's internal service"