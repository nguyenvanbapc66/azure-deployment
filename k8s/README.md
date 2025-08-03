# Kubernetes Deployment for MindX Projects

This directory contains Kubernetes manifests for deploying the MindX Projects application to Azure Kubernetes Service (AKS).

## 📁 File Structure

```
k8s/
├── namespace.yaml           # Kubernetes namespace
├── configmap.yaml          # Application configuration
├── frontend-deployment.yaml # Frontend deployment and service
├── backend-deployment.yaml  # Backend deployment and service
├── kustomization.yaml      # Kustomize configuration
├── deploy.sh              # Deployment script
└── README.md              # This file
```

## 🚀 Quick Start

### Prerequisites

1. **Azure CLI** installed and authenticated
2. **kubectl** configured to connect to your AKS cluster
3. **Docker** installed and running
4. **Azure Container Registry (ACR)** created

### Configuration

1. Update the variables in `deploy.sh`:

   ```bash
   ACR_NAME="your-acr-name"
   AKS_CLUSTER_NAME="your-aks-cluster-name"
   RESOURCE_GROUP="your-resource-group"
   ```

2. Make sure you're logged into Azure and ACR:
   ```bash
   az login
   az acr login --name $ACR_NAME
   ```

### Deployment

Run the deployment script:

```bash
cd k8s
./deploy.sh
```

## 📋 Manual Deployment Steps

If you prefer to deploy manually:

1. **Build and push images:**

   ```bash
   docker build -t $ACR_NAME.azurecr.io/mindx-projects-frontend:latest ./frontend
   docker build -t $ACR_NAME.azurecr.io/mindx-projects-backend:latest ./backend
   docker push $ACR_NAME.azurecr.io/mindx-projects-frontend:latest
   docker push $ACR_NAME.azurecr.io/mindx-projects-backend:latest
   ```

2. **Update image names in manifests** (replace `$ACR_NAME` with your actual ACR name)

3. **Deploy to Kubernetes:**
   ```bash
   kubectl apply -f namespace.yaml
   kubectl apply -k .
   ```

## 🔧 Configuration Details

### Frontend Deployment

- **Image**: `mindx-projects-frontend:latest`
- **Port**: 80 (nginx)
- **Service Type**: LoadBalancer
- **Replicas**: 2
- **Resources**: 64Mi-128Mi memory, 50m-100m CPU

### Backend Deployment

- **Image**: `mindx-projects-backend:latest`
- **Port**: 5000 (Node.js)
- **Service Type**: ClusterIP
- **Replicas**: 2
- **Resources**: 128Mi-256Mi memory, 100m-200m CPU

### Health Checks

Both deployments include:

- **Liveness Probe**: Checks if the container is alive
- **Readiness Probe**: Checks if the container is ready to serve traffic

## 🌐 Accessing the Application

After deployment:

1. Get the LoadBalancer IP:

   ```bash
   kubectl get service frontend-service -n mindx-projects
   ```

2. Access the frontend at: `http://<LOAD_BALANCER_IP>`

3. The backend will be accessible internally at: `backend-service:5000`

## 🔍 Monitoring and Debugging

### Check deployment status:

```bash
kubectl get pods -n mindx-projects
kubectl get services -n mindx-projects
kubectl get deployments -n mindx-projects
```

### View logs:

```bash
kubectl logs -f deployment/frontend-deployment -n mindx-projects
kubectl logs -f deployment/backend-deployment -n mindx-projects
```

### Describe resources:

```bash
kubectl describe pod <pod-name> -n mindx-projects
kubectl describe service frontend-service -n mindx-projects
```

## 🧹 Cleanup

To remove all resources:

```bash
kubectl delete namespace mindx-projects
```

## 📝 Notes

- The frontend service uses LoadBalancer type to expose it externally
- The backend service uses ClusterIP type for internal communication
- Both services have 2 replicas for high availability
- Resource limits are set to prevent resource exhaustion
- Health checks ensure only healthy pods receive traffic
