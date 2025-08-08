#!/bin/bash

echo "🚀 Clean Installation of Certificate Management"
echo "=============================================="

# Configuration
NAMESPACE="banv-projects"

echo "📦 Adding Helm repositories..."
helm repo add jetstack https://charts.jetstack.io
helm repo update

echo ""
echo "🔐 Installing cert-manager..."
helm install cert-manager jetstack/cert-manager \
    --namespace $NAMESPACE \
    --version v1.13.3 \
    --set installCRDs=true \
    --set webhook.namespaceSelector.matchLabels.name=$NAMESPACE

echo ""
echo "⏳ Waiting for cert-manager to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n $NAMESPACE
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-cainjector -n $NAMESPACE  
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n $NAMESPACE

echo ""
echo "📋 Cert-manager pods status:"
kubectl get pods -n $NAMESPACE | grep cert-manager

echo ""
echo "🔑 Creating ClusterIssuers..."
kubectl apply -f ./deploy/chart/kong-ingress/cluster-issuer.yaml

echo ""
echo "⏳ Waiting for ClusterIssuers to be ready..."
sleep 15

echo ""
echo "📋 ClusterIssuer status:"
kubectl get clusterissuer

echo ""
echo "🌐 Applying Ingress resources to trigger certificate creation..."
kubectl apply -f ./deploy/chart/kong-ingress/kong-ingress.yaml

echo ""
echo "⏳ Waiting for certificates to be created..."
sleep 30

echo ""
echo "📋 Certificate status:"
kubectl get certificate -n $NAMESPACE
echo ""
echo "Certificate Requests:"
kubectl get certificaterequest -n $NAMESPACE
echo ""
echo "Orders:"
kubectl get order -n $NAMESPACE
echo ""
echo "Challenges:"
kubectl get challenge -n $NAMESPACE

echo ""
echo "🧪 Testing HTTPS connectivity:"
echo "Frontend (ignoring cert validation):"
curl -s -o /dev/null -w "Status: %{http_code}\n" -k https://banv-app-dev.mindx.edu.vn/

echo ""
echo "Backend (ignoring cert validation):"
curl -s -o /dev/null -w "Status: %{http_code}\n" -k https://banv-api-dev.mindx.edu.vn/

echo ""
echo "🔍 Current certificate being served:"
openssl s_client -connect banv-app-dev.mindx.edu.vn:443 -servername banv-app-dev.mindx.edu.vn </dev/null 2>/dev/null | openssl x509 -noout -issuer -subject -dates

echo ""
echo "📝 Recent cert-manager logs:"
kubectl logs -n $NAMESPACE deployment/cert-manager --tail=5

echo ""
echo "✅ Certificate installation completed!"
echo ""
echo "🔧 Next steps:"
echo "- Monitor certificate status with: kubectl get certificate -n $NAMESPACE"
echo "- Check challenges with: kubectl get challenge -n $NAMESPACE"  
echo "- View cert-manager logs with: kubectl logs -n $NAMESPACE deployment/cert-manager"
echo "- Certificate provisioning may take 5-10 minutes" 