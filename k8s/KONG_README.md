# Kong Gateway Security Setup

This document describes the Kong Gateway implementation for securing your MindX Projects application.

## 🏗️ Architecture Overview

```
Internet → Kong Gateway (20.157.31.86) → Frontend/Backend Services
```

### **Current Setup:**

- **Kong Gateway**: `http://20.157.31.86` (Static IP - LoadBalancer)
- **Frontend**: Internal access via Kong (`/`)
- **Backend**: Internal access via Kong (`/api`) with API key authentication

## 🔐 Security Features Implemented

### **1. API Key Authentication**

- **Backend API**: Requires API key in header
- **API Key**: `your-secret-api-key-12345`
- **Usage**: `curl -H "apikey: your-secret-api-key-12345" http://20.157.31.86/api`

### **2. Rate Limiting**

- **Frontend**: 200 requests/minute, 2000/hour
- **Backend**: 100 requests/minute, 1000/hour (additional response rate limiting: 50/min, 500/hour)

### **3. Request Size Limiting**

- **Frontend**: 10MB payload limit
- **Backend**: 5MB payload limit

### **4. CORS Protection**

- **Frontend**: Configured CORS headers for secure cross-origin requests
- **Methods**: GET, POST, PUT, DELETE, OPTIONS
- **Headers**: Standard security headers included

### **5. IP Restrictions**

- **Backend**: Currently allows all IPs (0.0.0.0/0)
- **Configurable**: Can be restricted to specific IP ranges

## 📁 Configuration Files

### **kong-deployment.yaml**

- Kong Gateway deployment with 2 replicas
- Uses static IP: `20.157.31.86`
- Exposes ports: 80 (proxy), 443 (SSL), 8001 (admin)

### **kong-config.yaml**

- Declarative configuration for Kong
- Defines services, routes, plugins, and consumers
- Includes API key and security settings

### **kong-management.sh**

- Management script for Kong operations
- Commands for testing, monitoring, and administration

## 🚀 Usage Guide

### **Access Points:**

- **Frontend**: `http://20.157.31.86/` (Public access)
- **Backend API**: `http://20.157.31.86/api/` (Requires API key)
- **Kong Admin**: `http://20.157.31.86:8001/` (For management)

### **Testing the Setup:**

#### **1. Test Frontend Access:**

```bash
curl http://20.157.31.86/
```

#### **2. Test Backend with API Key:**

```bash
curl -H "apikey: your-secret-api-key-12345" http://20.157.31.86/api
```

#### **3. Test Backend without API Key (should fail):**

```bash
curl http://20.157.31.86/api
```

#### **4. Use Management Script:**

```bash
./kong-management.sh test
```

### **Management Commands:**

```bash
# Test all endpoints
./kong-management.sh test

# Check Kong status
./kong-management.sh status

# List services
./kong-management.sh services

# List routes
./kong-management.sh routes

# List consumers
./kong-management.sh consumers
```

## 🔧 Configuration Management

### **Updating Kong Configuration:**

1. Edit `kong-config.yaml`
2. Apply changes: `kubectl apply -f kong-config.yaml`
3. Restart Kong: `kubectl rollout restart deployment/kong-gateway -n mindx-projects`

### **Adding New API Keys:**

1. Edit `kong-config.yaml`
2. Add new consumer and keyauth_credentials
3. Apply and restart Kong

### **Modifying Rate Limits:**

1. Edit the rate-limiting plugin configuration in `kong-config.yaml`
2. Apply and restart Kong

## 🛡️ Security Best Practices

### **1. API Key Management:**

- Rotate API keys regularly
- Use strong, unique keys
- Store keys securely (not in code)

### **2. Rate Limiting:**

- Monitor usage patterns
- Adjust limits based on application needs
- Consider different limits for different user types

### **3. IP Restrictions:**

- Configure IP allowlists for production
- Monitor and block suspicious IPs
- Use VPN or private networks for admin access

### **4. SSL/TLS:**

- Enable HTTPS for production
- Use valid SSL certificates
- Configure secure cipher suites

## 📊 Monitoring and Logging

### **Kong Logs:**

```bash
# View Kong logs
kubectl logs -f deployment/kong-gateway -n mindx-projects

# View specific pod logs
kubectl logs -f <kong-pod-name> -n mindx-projects
```

### **Access Logs:**

- Kong logs all requests with timing information
- Headers include: `X-Kong-Upstream-Latency`, `X-Kong-Proxy-Latency`
- CORS headers are automatically added

### **Error Monitoring:**

- Monitor 401 (Unauthorized) responses
- Track rate limit violations
- Monitor request size violations

## 🔄 Deployment Workflow

### **Initial Deployment:**

1. Deploy Kong Gateway: `kubectl apply -f kong-deployment.yaml`
2. Apply configuration: `kubectl apply -f kong-config.yaml`
3. Test endpoints: `./kong-management.sh test`

### **Configuration Updates:**

1. Update `kong-config.yaml`
2. Apply changes: `kubectl apply -f kong-config.yaml`
3. Restart Kong: `kubectl rollout restart deployment/kong-gateway -n mindx-projects`
4. Verify changes: `./kong-management.sh test`

## 🚨 Troubleshooting

### **Common Issues:**

#### **1. API Key Not Working:**

- Verify key is correct in `kong-config.yaml`
- Check Kong logs for authentication errors
- Ensure Kong pods are restarted after config changes

#### **2. Rate Limiting Issues:**

- Check current limits in configuration
- Monitor Kong logs for rate limit violations
- Adjust limits if needed

#### **3. CORS Issues:**

- Verify CORS configuration in Kong config
- Check browser console for CORS errors
- Ensure proper headers are set

#### **4. Service Unavailable:**

- Check Kong pod status: `kubectl get pods -n mindx-projects`
- View Kong logs for errors
- Verify service endpoints are accessible

### **Debug Commands:**

```bash
# Check Kong status
./kong-management.sh status

# View Kong configuration
kubectl get configmap kong-config -n mindx-projects -o yaml

# Check service endpoints
kubectl get endpoints -n mindx-projects

# Test internal connectivity
kubectl exec -it <kong-pod> -n mindx-projects -- curl http://backend-service:5000
```

## 📈 Future Enhancements

### **Planned Features:**

1. **SSL/TLS Configuration**
2. **Advanced IP Filtering**
3. **Request/Response Transformation**
4. **API Documentation Portal**
5. **Advanced Monitoring and Alerting**
6. **Multiple API Key Support**
7. **OAuth2 Integration**

### **Security Improvements:**

1. **JWT Token Authentication**
2. **Request Signing**
3. **API Versioning**
4. **Advanced Rate Limiting Strategies**
5. **Request Validation**
6. **Response Caching**

## 📞 Support

For issues or questions about the Kong Gateway setup:

1. Check this documentation
2. Review Kong logs
3. Use the management script for testing
4. Consult Kong Gateway documentation: https://docs.konghq.com/
