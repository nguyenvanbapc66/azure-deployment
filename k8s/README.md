# Kubernetes Deployment for MindX Projects

This directory contains Kubernetes manifests for deploying the MindX Projects application to Azure Kubernetes Service (AKS).

## 📁 File Structure

```
k8s/
├── namespace.yaml                    # Kubernetes namespace
├── configmap.yaml                   # Application configuration
├── frontend-deployment.yaml         # Frontend deployment and service
├── backend-deployment.yaml          # Backend deployment and service
├── kustomization.yaml               # Kustomize configuration
├── deploy.sh                        # Main deployment script
├── build-and-push-dockerHub.sh      # Docker Hub image build and push script
├── monitor.sh                       # Real-time deployment monitoring script
└── README.md                        # This file
```

## 🚀 Quick Start

### Prerequisites

1. **Azure CLI** installed and authenticated
2. **kubectl** configured to connect to your AKS cluster
3. **Docker** installed and running
4. **Docker Hub** account (currently using public images)

### Configuration

1. Update the variables in `deploy.sh`:

   ```bash
   ACR_NAME="mindxacrbanv"                    # Your Azure Container Registry name
   AKS_CLUSTER_NAME="mindx_aks_banv"          # Your AKS cluster name
   RESOURCE_GROUP="mindx-individual-banv-rg"  # Your resource group name
   ```

2. Make sure you're logged into Azure:
   ```bash
   az login
   ```

### Deployment

Run the deployment script:

```bash
cd k8s
./deploy.sh
```

## 📦 Image Management

### Current Setup

The application currently uses **Docker Hub** images:

- **Frontend**: `mindxtech/banv-starter:latest`
- **Backend**: `mindxtech/banv-starter:backend`

### Building and Pushing Images

To build and push new images to Docker Hub:

```bash
cd k8s
./build-and-push-dockerHub.sh
```

This script:

- Builds multi-architecture images (linux/amd64, linux/arm64)
- Pushes to Docker Hub repository `mindxtech/banv-starter`
- Uses `docker buildx` for cross-platform compatibility

### Switching to Azure Container Registry (ACR)

To use ACR instead of Docker Hub:

1. Update `deploy.sh` to include build and push commands
2. Update image names in deployment manifests
3. Configure ACR authentication

## 🔧 Configuration Details

### Frontend Deployment

- **Image**: `mindxtech/banv-starter:latest`
- **Port**: 80 (nginx)
- **Service Type**: LoadBalancer
- **Replicas**: 2
- **Resources**: 64Mi-128Mi memory, 50m-100m CPU
- **Environment Variables**:
  - `ENV_API_URL`: "http://backend-service:5000" (internal communication)

### Backend Deployment

- **Image**: `mindxtech/banv-starter:backend`
- **Port**: 5000 (Node.js)
- **Service Type**: LoadBalancer (currently exposed externally)
- **Replicas**: 2
- **Resources**: 128Mi-256Mi memory, 100m-200m CPU
- **Environment Variables**:
  - `NODE_ENV`: "production"
  - `PORT`: "5000"

### Health Checks

Both deployments include:

- **Liveness Probe**: Checks if the container is alive
  - Frontend: `GET /` on port 80
  - Backend: `GET /` on port 5000
- **Readiness Probe**: Checks if the container is ready to serve traffic

## 🌐 Accessing the Application

After deployment:

1. Get the LoadBalancer IPs:

   ```bash
   kubectl get services -n default
   ```

2. Access the services:

   - **Frontend**: `http://<FRONTEND_LOAD_BALANCER_IP>`
   - **Backend**: `http://<BACKEND_LOAD_BALANCER_IP>:5000`

3. Internal communication:
   - Frontend can reach backend at: `backend-service:5000`

## 🔍 Monitoring and Debugging

### Real-time Monitoring

Use the monitoring script for live deployment status:

```bash
cd k8s
./monitor.sh
```

This script provides:

- Real-time pod status
- Service information
- Deployment status
- Recent events
- Automatic success detection

### Manual Status Checks

```bash
# Check deployment status
kubectl get pods -n mindx-projects
kubectl get services -n mindx-projects
kubectl get deployments -n mindx-projects

# View logs
kubectl logs -f deployment/frontend-deployment -n mindx-projects
kubectl logs -f deployment/backend-deployment -n mindx-projects

# Describe resources
kubectl describe pod <pod-name> -n mindx-projects
kubectl describe service frontend-service -n mindx-projects
```

## 🔄 Environment Variable Management

### Frontend Runtime Configuration

The frontend uses a runtime environment variable injection system:

1. **Build-time**: Uses `import.meta.env.VITE_API_URL` as fallback
2. **Runtime**: Uses `window.ENV_API_URL` injected via `envsubst`
3. **Kubernetes**: Sets `ENV_API_URL` environment variable

This allows the frontend to dynamically connect to the backend without rebuilding the image.

## 🧹 Cleanup

To remove all resources:

```bash
kubectl delete namespace mindx-projects
```

## 📝 Current Deployment Notes

- **Namespace**: Services are currently deployed in the `default` namespace
- **External Access**: Both frontend and backend are exposed via LoadBalancer
- **Image Source**: Using Docker Hub public images (`mindxtech/banv-starter`)
- **Multi-Architecture**: Images support both AMD64 and ARM64 platforms
- **Health Monitoring**: Comprehensive health checks and monitoring scripts
- **Resource Management**: Appropriate resource limits and requests set

## 🚨 Troubleshooting

### Common Issues

1. **Image Pull Errors**: Ensure Docker Hub images exist and are accessible
2. **Port Conflicts**: Check if ports 80 and 5000 are available
3. **Namespace Issues**: Verify services are in the correct namespace
4. **Environment Variables**: Check if `ENV_API_URL` is properly set

### Debug Commands

```bash
# Check pod events
kubectl get events -n mindx-projects --sort-by='.lastTimestamp'

# Check service endpoints
kubectl get endpoints -n mindx-projects

# Test internal connectivity
kubectl exec -it <frontend-pod> -- curl http://backend-service:5000
```
