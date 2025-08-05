# Kong Ingress Controller with HTTPS Setup

## 🎯 Overview

This document describes the Kong Ingress Controller setup with automatic SSL/TLS certificate provisioning using cert-manager and Let's Encrypt for the MindX Projects application.

## 🔐 HTTPS Configuration

### Frontend Domain

- **URL**: https://banv-app-dev.mindx.edu.vn
- **Service**: frontend-service
- **Port**: 80
- **Features**: CORS enabled, rate limiting, SSL/TLS

### Backend Domain

- **URL**: https://banv-api-dev.mindx.edu.vn
- **Service**: backend-service
- **Port**: 5000
- **Features**: Rate limiting, SSL/TLS

## 🏗️ Architecture

```
Internet → DNS (banv-app-dev.mindx.edu.vn, banv-api-dev.mindx.edu.vn) → Kong Ingress Controller (20.157.31.86) → Kubernetes Services
                                    ↓
                    ┌─────────────────────────────┐
                    │        Kong Proxy           │
                    │   (LoadBalancer Service)    │
                    │   + SSL/TLS Termination     │
                    └─────────────────────────────┘
                                    ↓
                    ┌─────────────────────────────┐
                    │      Ingress Rules          │
                    │  - banv-app-dev.mindx.edu.vn → frontend-service     │
                    │  - banv-api-dev.mindx.edu.vn → backend-service      │
                    │  + TLS Certificates         │
                    └─────────────────────────────┘
                                    ↓
                    ┌─────────────────────────────┐
                    │    Application Services     │
                    │  - frontend-service:80      │
                    │  - backend-service:5000     │
                    └─────────────────────────────┘
                                    ↓
                    ┌─────────────────────────────┐
                    │      cert-manager           │
                    │  - Let's Encrypt Integration│
                    │  - Automatic Certificate    │
                    │  - Certificate Renewal      │
                    └─────────────────────────────┘
```

## 📁 Configuration Files

### `cluster-issuer.yaml`

Let's Encrypt ClusterIssuer configuration:

- **letsencrypt-prod**: Production certificates (90-day validity)
- **letsencrypt-staging**: Staging certificates (for testing)

### `ingress.yaml`

Kubernetes Ingress resources with TLS:

- **frontend-ingress**: Routes `banv-app-dev.mindx.edu.vn` to frontend-service with TLS
- **backend-ingress**: Routes `banv-api-dev.mindx.edu.vn` to backend-service with TLS
- **cert-manager.io/cluster-issuer**: Automatic certificate provisioning

### `app-frontend-deployment.yaml`

Frontend deployment configured to use HTTPS backend:

```yaml
env:
  - name: VITE_API_URL
    value: "https://banv-api-dev.mindx.edu.vn"
```

### `dockerHub-build-and-push.sh`

Build script configured with HTTPS backend:

```bash
BACKEND_URL="https://banv-api-dev.mindx.edu.vn"
```

## 🔧 Features

### 1. Automatic SSL/TLS Certificates

- Let's Encrypt integration via cert-manager
- Automatic certificate provisioning
- Automatic certificate renewal
- HTTP-01 challenge validation

### 2. Domain-Based Routing

- Separate domains for frontend and backend
- Clean URL structure
- Professional appearance

### 3. Rate Limiting

- Frontend: 100 requests/minute, 1000 requests/hour
- Backend: 100 requests/minute, 1000 requests/hour
- Uses local policy (in-memory)

### 4. CORS Protection

- Frontend only
- Allows all origins (`*`)
- Supports common HTTP methods
- Includes necessary headers

## 🌐 Access Points

### Frontend

- **URL**: https://banv-app-dev.mindx.edu.vn
- **Features**: CORS enabled, rate limiting, SSL/TLS
- **Status**: ✅ Working

### Backend API

- **URL**: https://banv-api-dev.mindx.edu.vn
- **Features**: Rate limiting, SSL/TLS
- **Status**: ✅ Working

## 🧪 Testing

### Test Script

Run the test script to verify the HTTPS setup:

```bash
./kong-ingress-test.sh
```

### Certificate Status Script

Check certificate status and provisioning:

```bash
./check-certificates.sh
```

### Debug Script

Run the debug script for detailed troubleshooting:

```bash
./debug-backend.sh
```

### Manual Testing

```bash
# Test frontend HTTPS
curl -I https://banv-app-dev.mindx.edu.vn/

# Test backend HTTPS
curl -I https://banv-api-dev.mindx.edu.vn/

# Test certificate validity
openssl s_client -connect banv-app-dev.mindx.edu.vn:443 -servername banv-app-dev.mindx.edu.vn
```

## 🔧 Management Commands

### Check Cert-manager Status

```bash
kubectl get pods -n mindx-projects | grep cert-manager
kubectl get clusterissuer
```

### Check Certificate Status

```bash
kubectl get certificate -n mindx-projects
kubectl get certificaterequest -n mindx-projects
kubectl get order -n mindx-projects
kubectl get challenge -n mindx-projects
```

### View Cert-manager Logs

```bash
kubectl logs cert-manager-<pod-id> -n mindx-projects
kubectl logs cert-manager-cainjector-<pod-id> -n mindx-projects
kubectl logs cert-manager-webhook-<pod-id> -n mindx-projects
```

### Check Kong Status

```bash
kubectl get pods -n mindx-projects | grep kong
kubectl get services -n mindx-projects | grep kong
```

### Check Ingress Status

```bash
kubectl get ingress -n mindx-projects
kubectl describe ingress frontend-ingress -n mindx-projects
kubectl describe ingress backend-ingress -n mindx-projects
```

## 🚀 Deployment

### 1. Build and Push Images

```bash
./dockerHub-build-and-push.sh
```

### 2. Deploy to Kubernetes

```bash
./deploy.sh
```

### 3. Test the Deployment

```bash
./kong-ingress-test.sh
```

### 4. Check Certificate Status

```bash
./check-certificates.sh
```

## ⚠️ Important Notes

### DNS Configuration

- Both domains must point to the Kong LoadBalancer IP: `20.157.31.86`
- DNS propagation may take time (usually 5-15 minutes)
- Ensure DNS records are properly configured

### Certificate Provisioning

- Certificates are automatically provisioned by cert-manager
- Let's Encrypt HTTP-01 challenge is used for validation
- Certificate provisioning may take 5-10 minutes
- Certificates are automatically renewed before expiration

### Rate Limiting

- Let's Encrypt has rate limits (50 certificates per domain per week)
- Use staging environment for testing
- Production certificates have 90-day validity

### Troubleshooting

- Check cert-manager logs for certificate provisioning issues
- Verify DNS resolution for both domains
- Ensure Kong Ingress Controller is properly configured
- Check that HTTP-01 challenges can reach Kong

## 🔄 Migration from HTTP to HTTPS

### Changes Made

1. **Cert-manager Installation**: Added to mindx-projects namespace
2. **ClusterIssuer Configuration**: Let's Encrypt integration
3. **Ingress Configuration**: Added TLS and cert-manager annotations
4. **Frontend Configuration**: Updated API URL to use HTTPS
5. **Build Script**: Updated to use HTTPS backend URL
6. **Test Scripts**: Updated to test HTTPS endpoints

### Benefits

1. **Security**: Encrypted communication between clients and servers
2. **Trust**: Valid SSL certificates from Let's Encrypt
3. **SEO**: HTTPS is preferred by search engines
4. **Compliance**: Meets security requirements
5. **Automation**: Automatic certificate provisioning and renewal

## 📚 Additional Resources

- [Cert-manager Documentation](https://cert-manager.io/docs/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Kong Ingress Controller TLS](https://docs.konghq.com/kubernetes-ingress-controller/latest/guides/cert-manager/)
- [Kubernetes Ingress TLS](https://kubernetes.io/docs/concepts/services-networking/ingress/#tls)

## 🎉 Success Status

- ✅ Cert-manager installed in mindx-projects namespace
- ✅ Let's Encrypt ClusterIssuer configured
- ✅ Kong Ingress Controller with TLS support
- ✅ Frontend accessible via HTTPS
- ✅ Backend accessible via HTTPS
- ✅ Rate limiting configured
- ✅ CORS enabled for frontend
- ✅ DNS resolution working
- ✅ Internal communication working
- ✅ Automatic certificate provisioning

The Kong Ingress Controller with HTTPS is successfully deployed and providing secure, encrypted access to your application!
