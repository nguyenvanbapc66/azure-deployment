# 🚀 Azure Insights Deployment Guide - CORRECTED WORKFLOW

## 🚨 **PROBLEM IDENTIFIED WITH YOUR CURRENT APPROACH**

### **❌ Your Current Order (INCORRECT):**

```bash
1. azure-insights-complete-setup.sh  # ❌ Monitoring before apps exist
2. deploy-docker.sh                  # ❌ Should be FIRST
3. deploy-services.sh                # ❌ Conflicts with deploy-with-monitoring.sh
4. deploy-with-monitoring.sh         # ❌ Redundant with deploy-services.sh
```

### **🚨 Issues with Current Approach:**

- **Wrong order**: Setting up monitoring before building images
- **Conflicting scripts**: `deploy-services.sh` and `deploy-with-monitoring.sh` do similar things
- **Missing dependencies**: Scripts expect things that haven't been set up
- **Redundant work**: Multiple scripts stepping on each other

## ✅ **SOLUTION: ONE MASTER SCRIPT**

Instead of running 4 confusing scripts in the wrong order, use **ONE SCRIPT**:

```bash
./deploy/shell/complete-deployment.sh
```

## 📋 **What This Master Script Does (CORRECT ORDER):**

### **🔍 Prerequisites Check**

- ✅ Verifies all required tools (docker, kubectl, helm, az)
- ✅ Checks Kubernetes cluster connectivity
- ✅ Validates Docker daemon is running
- ✅ Ensures ACR login is working

### **🐳 STEP 1: Build & Push Docker Images**

- ✅ Builds frontend with monitoring integration
- ✅ Builds backend with monitoring integration
- ✅ Pushes to Azure Container Registry

### **📊 STEP 2: Setup Complete Monitoring Stack**

- ✅ Azure Application Insights integration
- ✅ Prometheus monitoring stack
- ✅ Grafana dashboards with SLA monitoring
- ✅ AlertManager with comprehensive alerts
- ✅ ServiceMonitors for application metrics
- ✅ SLO burn rate alerts (99.9%, 99%, 95%)

### **🚀 STEP 3: Deploy Applications**

- ✅ Updates deployment manifests with new image versions
- ✅ Deploys applications to Kubernetes
- ✅ Waits for deployments to be ready
- ✅ Integrates with monitoring stack

### **🚨 STEP 4: Deploy Enhanced Alerts**

- ✅ Critical uptime issues (95%, 99% SLA breaches)
- ✅ Service interruption scenarios
- ✅ High latency with P95/P50 monitoring
- ✅ Error rate monitoring per endpoint
- ✅ Infrastructure capacity alerts

### **🧪 STEP 5: Generate Test Data & Verify**

- ✅ Generates test traffic for immediate metrics
- ✅ Verifies all components are running
- ✅ Provides comprehensive status report
- ✅ Shows access information

## 🎯 **MONITORING CAPABILITIES DEPLOYED**

After running the master script, you'll have:

### **Service Level Monitoring:**

- **Uptime tracking**: 99.9%, 99%, 95% SLA compliance
- **Latency monitoring**: P95, P50 response times
- **Error rate tracking**: Per-endpoint API monitoring
- **Traffic analysis**: RPS/RPM metrics
- **Capacity monitoring**: CPU, Memory, Disk usage

### **Advanced Features:**

- **46+ comprehensive alerts** covering all scenarios
- **SLO burn rate alerts** (fast/medium/slow burn detection)
- **Azure Application Insights** integration
- **Custom Grafana dashboards** with SLA tracking
- **Real-time metrics** collection
- **Correlation alerts** (latency causing error rates)

## 🔗 **Access Your Monitoring**

After successful deployment:

### **📊 Grafana Dashboard**

```bash
kubectl port-forward -n grafana-system svc/grafana 3000:80
```

- **URL**: http://localhost:3000
- **Username**: admin
- **Password**: `kubectl get secret -n grafana-system grafana -o jsonpath='{.data.admin-password}' | base64 -d`

### **🚨 AlertManager**

```bash
kubectl port-forward -n prometheus-system svc/alertmanager-operated 9093:9093
```

- **URL**: http://localhost:9093

### **📈 Prometheus** (if running)

```bash
kubectl port-forward -n prometheus-system svc/prometheus-kube-prometheus-prometheus 9091:9090
```

- **URL**: http://localhost:9091

### **☁️ Azure Application Insights**

Direct link: https://portal.azure.com/#@mindx.com.vn/resource/subscriptions/f244cdf7-5150-4b10-b3f2-d4bff23c5f45/resourceGroups/mindx-individual-banv-rg/providers/microsoft.insights/components/mindx-banv-app-insights

## 📊 **Data Timeline**

After running the master script:

- **Immediate (0-2 minutes)**: Live metrics in Azure Application Insights
- **5-10 minutes**: Grafana dashboards populated
- **15-30 minutes**: Full historical data available
- **1 hour**: Complete trend analysis ready

## 🔧 **Prerequisites**

Before running the master script, ensure you have:

### **Required Tools:**

- `docker` (with Docker Desktop running)
- `kubectl` (connected to your AKS cluster)
- `helm` (version 3.x)
- `az` (Azure CLI, authenticated)

### **Required Setup:**

```bash
# Connect to AKS cluster
az aks get-credentials --resource-group mindx-individual-banv-rg --name mindx_aks_banv

# Login to Azure Container Registry
az acr login --name mindxacrbanv

# Verify connectivity
kubectl cluster-info
```

## 🚀 **How to Run**

### **Simple One-Command Deployment:**

```bash
./deploy/shell/complete-deployment.sh
```

### **Expected Runtime:**

- **Total time**: 15-25 minutes
- **Step 1 (Docker)**: 5-8 minutes
- **Step 2 (Monitoring)**: 8-12 minutes
- **Step 3 (Apps)**: 2-3 minutes
- **Step 4 (Alerts)**: 1-2 minutes
- **Step 5 (Verify)**: 1-2 minutes

## 🚨 **What NOT to Run Anymore**

### **❌ Don't Run These Scripts Separately:**

- ~~`azure-insights-complete-setup.sh`~~ (included in master script)
- ~~`deploy-docker.sh`~~ (included in master script)
- ~~`deploy-services.sh`~~ (conflicts with master script)
- ~~`deploy-with-monitoring.sh`~~ (included in master script)

### **✅ Use Only:**

- `./deploy/shell/complete-deployment.sh` (master script)

## 🔍 **Troubleshooting**

### **If the Master Script Fails:**

1. **Check Prerequisites:**

   ```bash
   docker info                    # Docker running?
   kubectl cluster-info          # Connected to AKS?
   az account show              # Azure CLI logged in?
   ```

2. **Check Resources:**

   ```bash
   kubectl top nodes            # Sufficient CPU/Memory?
   ```

3. **Scale Cluster if Needed:**
   ```bash
   az aks scale --resource-group mindx-individual-banv-rg --name mindx_aks_banv --node-count 3
   ```

### **If You Need to Re-run:**

The master script is idempotent - you can run it multiple times safely.

## 📋 **Summary**

### **✅ CORRECT Approach:**

1. **One command**: `./deploy/shell/complete-deployment.sh`
2. **Correct order**: Docker → Monitoring → Apps → Alerts → Verify
3. **No conflicts**: Single script handles everything
4. **Comprehensive**: All your requirements covered

### **❌ OLD Approach (Don't Use):**

1. **Multiple scripts**: Confusing and error-prone
2. **Wrong order**: Monitoring before apps exist
3. **Conflicts**: Scripts stepping on each other
4. **Incomplete**: Missing coordination between components

**🎯 Result: Complete Azure Insights monitoring system with all requested features working correctly!**
