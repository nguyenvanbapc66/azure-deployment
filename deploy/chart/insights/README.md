# 📊 Monitoring Insights - YAML Configurations

This directory contains all the extracted YAML configurations from the monitoring setup scripts, organized into logical subfolders for easy deployment and management.

## 📋 **Organized Structure**

```
deploy/chart/insights/
├── azure-monitor-setup/         # Azure Monitor Setup
│   ├── monitoring-configmap.yaml
│   ├── app-insights-config.yaml
│   ├── fluent-bit-config.yaml
│   └── kustomization.yaml
├── prometheus-setup/            # Prometheus, Grafana & Metrics
│   ├── prometheus-values.yaml
│   ├── grafana-values.yaml
│   ├── service-monitors.yaml
│   ├── metrics-services.yaml
│   ├── custom-metrics-config.yaml
│   └── kustomization.yaml
├── alert-setup/                 # Alerting & Notifications
│   ├── infrastructure-alerts.yaml
│   ├── application-alerts.yaml
│   ├── alertmanager-config.yaml
│   ├── azure-alerts-config.yaml
│   ├── webhook-receiver.yaml
│   └── kustomization.yaml
├── kustomization.yaml           # Main orchestration
```

## 🔧 **Azure Monitor Setup** (`azure-monitor-setup/`)

Azure Monitor integration and Application Insights configuration:

- **`monitoring-configmap.yaml`** - Core monitoring configuration
- **`app-insights-config.yaml`** - Application Insights settings
- **`fluent-bit-config.yaml`** - Log aggregation configuration
- **`kustomization.yaml`** - Deployment orchestration

**Deploy Azure Monitor components:**

```bash
kubectl apply -k deploy/chart/insights/azure-monitor-setup/
```

## 📈 **Prometheus Setup** (`prometheus-setup/`)

Prometheus, Grafana, and metrics collection configuration:

- **`prometheus-values.yaml`** - Prometheus Helm configuration
- **`grafana-values.yaml`** - Grafana Helm configuration
- **`service-monitors.yaml`** - Prometheus ServiceMonitors
- **`metrics-services.yaml`** - Frontend and backend metrics services
- **`custom-metrics-config.yaml`** - Custom application metrics
- **`kustomization.yaml`** - Deployment orchestration

**Deploy Prometheus components:**

```bash
# Deploy Kubernetes resources
kubectl apply -k deploy/chart/insights/prometheus-setup/

# Deploy Helm charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace prometheus-system \
  --values deploy/chart/insights/prometheus-setup/prometheus-values.yaml

helm install grafana grafana/grafana \
  --namespace grafana-system \
  --values deploy/chart/insights/prometheus-setup/grafana-values.yaml
```

## 🚨 **Alert Setup** (`alert-setup/`)

Comprehensive alerting and notification configuration:

- **`infrastructure-alerts.yaml`** - Infrastructure alerts (PrometheusRule)
- **`application-alerts.yaml`** - Application alerts (PrometheusRule)
- **`alertmanager-config.yaml`** - Alertmanager routing and notifications
- **`azure-alerts-config.yaml`** - Azure Monitor alerts script
- **`webhook-receiver.yaml`** - Alert webhook receiver
- **`kustomization.yaml`** - Deployment orchestration

**Deploy Alert components:**

```bash
kubectl apply -k deploy/chart/insights/alert-setup/
```

## 🚀 **Usage Options**

### **Deploy Everything at Once:**

```bash
kubectl apply -k deploy/chart/insights/
```

### **Deploy Individual Components:**

```bash
# Azure Monitor only
kubectl apply -k deploy/chart/insights/azure-monitor-setup/

# Prometheus & Grafana only
kubectl apply -k deploy/chart/insights/prometheus-setup/

# Alerts only
kubectl apply -k deploy/chart/insights/alert-setup/
```

### **Use with Shell Scripts:**

The monitoring scripts in `deploy/shell/monitoring/` now reference these organized YAML files:

```bash
# Complete setup using scripts
./deploy/shell/monitoring/setup-monitoring.sh

# Individual script setup
./deploy/shell/monitoring/azure-monitor-setup.sh
./deploy/shell/monitoring/prometheus-setup.sh
./deploy/shell/monitoring/alerts-setup.sh
```

## 📊 **Namespaces**

The configurations are organized across multiple namespaces:

- **`banv-projects`** - Application resources and configurations
- **`azure-monitor`** - Azure Monitor integration resources
- **`prometheus-system`** - Prometheus and monitoring resources
- **`grafana-system`** - Grafana dashboard resources

## 🔗 **Dependencies**

These YAML files are extracted from and used by:

- `deploy/shell/monitoring/azure-monitor-setup.sh`
- `deploy/shell/monitoring/prometheus-setup.sh`
- `deploy/shell/monitoring/app-instrumentation.sh`
- `deploy/shell/monitoring/alerts-setup.sh`

## 🎯 **Key Features by Component**

### **📊 Azure Monitor Setup**

- Application Insights telemetry
- Container Insights for AKS
- Log Analytics workspace integration
- Fluent Bit log aggregation

### **📈 Prometheus Setup**

- Metrics collection and storage (30-day retention)
- Grafana dashboards with pre-configured visualizations
- ServiceMonitors for automatic metrics discovery
- Custom application metrics definitions

### **🚨 Alert Setup**

- Infrastructure alerts (CPU, memory, disk, nodes)
- Application alerts (downtime, errors, latency)
- Security alerts (certificate expiration)
- Kong Ingress performance monitoring
- Email, Slack, and webhook notifications

## ⚙️ **Customization**

### **Update Configuration:**

Edit files directly in their respective subfolders and redeploy:

```bash
# Edit alert thresholds
vim deploy/chart/insights/alert-setup/infrastructure-alerts.yaml
kubectl apply -f deploy/chart/insights/alert-setup/infrastructure-alerts.yaml

# Update Grafana settings
vim deploy/chart/insights/prometheus-setup/grafana-values.yaml
helm upgrade grafana grafana/grafana --values deploy/chart/insights/prometheus-setup/grafana-values.yaml
```

### **Environment-Specific Customization:**

Use Kustomize overlays for different environments:

```bash
# Create environment-specific overlays
mkdir -p deploy/chart/insights/overlays/{dev,staging,prod}

# Apply environment-specific configurations
kubectl apply -k deploy/chart/insights/overlays/prod/
```

## 🔒 **Security Notes**

- Secrets contain sensitive information (Application Insights keys, SMTP passwords)
- Update default passwords and API keys before production deployment
- Use Kubernetes secrets management best practices
- Consider using Azure Key Vault integration for sensitive data

## 📚 **Documentation Links**

- [Prometheus Operator](https://prometheus-operator.dev/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Azure Monitor](https://docs.microsoft.com/en-us/azure/azure-monitor/)
- [Application Insights](https://docs.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview)
- [Kustomize](https://kustomize.io/)

## 🎉 **Benefits of This Organization**

✅ **Modular Deployment** - Deploy only what you need  
✅ **Clear Separation** - Logical grouping by functionality  
✅ **Easy Maintenance** - Focused configuration files  
✅ **Flexible Usage** - Use with scripts or directly with kubectl  
✅ **Environment Ready** - Easy to customize for different environments  
✅ **GitOps Compatible** - Perfect for GitOps workflows
