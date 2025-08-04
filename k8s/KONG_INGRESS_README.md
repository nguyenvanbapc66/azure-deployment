# Kong Ingress Controller Setup

## 🎯 Overview

This document describes the Kong Ingress Controller setup for the MindX Projects application. Kong Ingress Controller is a Kubernetes-native API Gateway that provides advanced traffic management, security, and observability features.

## 🏗️ Architecture

```
Internet → Kong Ingress Controller (20.157.31.86) → Kubernetes Services
                                    ↓
                    ┌─────────────────────────────┐
                    │        Kong Proxy           │
                    │   (LoadBalancer Service)    │
                    └─────────────────────────────┘
                                    ↓
                    ┌─────────────────────────────┐
                    │      Ingress Rules          │
                    │  - / → frontend-service     │
                    │  - /api → backend-service   │
                    └─────────────────────────────┘
                                    ↓
                    ┌─────────────────────────────┐
                    │    Application Services     │
                    │  - frontend-service:80      │
                    │  - backend-service:5000     │
                    └─────────────────────────────┘
```

## 🚀 Installation

### Prerequisites

- Kubernetes cluster (AKS)
- Helm 3.x
- kubectl configured

### 1. Install Kong Ingress Controller

```bash
# Add Kong Helm repository
helm repo add kong https://charts.konghq.com
helm repo update

# Install Kong Ingress Controller
helm install kong-ingress kong/kong -n mindx-projects --create-namespace --values kong-ingress-values.yaml
```

### 2. Apply Kubernetes Resources

```bash
# Apply Kong plugins
kubectl apply -f kong-plugin.yaml

# Apply Kong consumer
kubectl apply -f kong-consumer.yaml

# Apply Ingress resources
kubectl apply -f ingress.yaml
```

## 📁 Configuration Files

### `kong-ingress-values.yaml`

Helm values file for Kong Ingress Controller configuration:

- Disables Kong Gateway mode
- Enables Kong Ingress Controller
- Configures LoadBalancer with static IP (20.157.31.86)
- Sets up environment variables for DB-less mode

### `kong-plugin.yaml`

Defines Kong plugins:

- **key-auth-plugin**: API key authentication for backend
- **cors-plugin**: CORS support for frontend
- **rate-limiting-plugin**: Rate limiting for both services

### `kong-consumer.yaml`

Defines Kong consumer for API key authentication:

- Consumer: `api-user`
- Custom ID: `api-user-001`

### `ingress.yaml`

Kubernetes Ingress resources:

- **frontend-ingress**: Routes `/` to frontend-service
- **backend-ingress**: Routes `/api` to backend-service with API key protection

## 🔐 Security Features

### 1. API Key Authentication

- Backend API requires `apikey` header
- Key value: `your-secret-api-key-12345`
- Applied to `/api` path only

### 2. Rate Limiting

- Frontend: 200 requests/minute, 2000 requests/hour
- Backend: 100 requests/minute, 1000 requests/hour
- Uses local policy (in-memory)

### 3. CORS Protection

- Frontend only
- Allows all origins (`*`)
- Supports common HTTP methods
- Includes necessary headers

## 🌐 Access Points

### Frontend

- **URL**: http://20.157.31.86/
- **Features**: CORS enabled, rate limiting
- **Status**: ✅ Working

### Backend API

- **URL**: http://20.157.31.86/api/
- **Authentication**: API key required
- **Headers**: `apikey: your-secret-api-key-12345`
- **Status**: 🔒 Protected (401 without key)

## 🧪 Testing

### Test Script

Run the test script to verify the setup:

```bash
./kong-ingress-test.sh
```

### Manual Testing

```bash
# Test frontend
curl -I http://20.157.31.86/

# Test backend without API key (should return 401)
curl -I http://20.157.31.86/api/

# Test backend with API key
curl -H "apikey: your-secret-api-key-12345" http://20.157.31.86/api/
```

## 🔧 Management Commands

### Check Kong Status

```bash
kubectl get pods -n mindx-projects | grep kong
kubectl get services -n mindx-projects | grep kong
```

### View Kong Logs

```bash
kubectl logs kong-ingress-kong-68bf5b6b65-2ltv7 -n mindx-projects -c proxy
```

### Access Kong Admin API

```bash
kubectl port-forward service/kong-ingress-kong-admin 8444:8444 -n mindx-projects
curl -k https://localhost:8444/status
```

### Check Ingress Status

```bash
kubectl get ingress -n mindx-projects
kubectl describe ingress frontend-ingress -n mindx-projects
kubectl describe ingress backend-ingress -n mindx-projects
```

## ⚠️ Known Issues

### API Key Authentication

The API key authentication is configured but the actual credential needs to be created. This is because:

1. Kong Ingress Controller runs in DB-less mode
2. KongCredential CRD is not available in this version
3. Dynamic credential creation via Admin API is not supported in DB-less mode

### Solutions

1. **Use Kong Admin API** (if DB mode is enabled)
2. **Create KongCredential resource** (if CRD is available)
3. **Configure API key in KongPlugin** (if supported)
4. **Use external authentication service**

## 🔄 Migration from Kong Gateway

### Changes Made

1. **Service Types**: Changed from LoadBalancer to ClusterIP for frontend/backend
2. **Routing**: Now uses Kubernetes Ingress instead of Kong declarative config
3. **Configuration**: Uses KongPlugin resources instead of inline annotations
4. **Management**: Uses Helm instead of direct YAML deployment

### Benefits

1. **Kubernetes Native**: Better integration with Kubernetes ecosystem
2. **Standard Ingress**: Uses standard Kubernetes Ingress resources
3. **Helm Management**: Easier deployment and updates
4. **CRD Support**: Better support for custom resources

## 📚 Additional Resources

- [Kong Ingress Controller Documentation](https://docs.konghq.com/kubernetes-ingress-controller/)
- [Kong Helm Chart](https://github.com/Kong/charts)
- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)

## 🎉 Success Status

- ✅ Kong Ingress Controller deployed
- ✅ Frontend accessible via Kong
- ✅ Backend protected by API key authentication
- ✅ Rate limiting configured
- ✅ CORS enabled for frontend
- ⚠️ API key credential needs manual creation

The Kong Ingress Controller is successfully deployed and providing API Gateway functionality for your application!
