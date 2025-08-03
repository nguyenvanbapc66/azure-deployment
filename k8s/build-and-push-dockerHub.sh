#!/bin/bash

echo "🐳 Building and pushing images to Docker Hub..."

# Configuration
DOCKER_USERNAME="mindxtech"
REPOSITORY_NAME="banv-starter"
IMAGE_TAG="latest"
BACKEND_TAG="backend"

echo "📦 Building frontend image for multiple platforms..."
docker buildx build --platform linux/amd64,linux/arm64 -t $DOCKER_USERNAME/$REPOSITORY_NAME:$IMAGE_TAG ../frontend --push

echo "📦 Building backend image for multiple platforms..."
docker buildx build --platform linux/amd64,linux/arm64 -t $DOCKER_USERNAME/$REPOSITORY_NAME:$BACKEND_TAG ../backend --push

echo "✅ Images pushed successfully!"
echo "Frontend: $DOCKER_USERNAME/$REPOSITORY_NAME:$IMAGE_TAG"
echo "Backend: $DOCKER_USERNAME/$REPOSITORY_NAME:$BACKEND_TAG" 