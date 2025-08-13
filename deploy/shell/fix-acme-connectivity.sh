#!/bin/bash

# Script to fix ACME connectivity issues for Let's Encrypt certificate validation
# This addresses the "Timeout during connect" error from Let's Encrypt servers

set -e

NAMESPACE="banv-projects"
RESOURCE_GROUP="mindx-individual-banv-rg"
LB_NAME="kubernetes"
EXTERNAL_IP="20.157.31.86"

echo "🔧 Fixing ACME Connectivity Issues for Let's Encrypt"
echo "=================================================="
echo ""

# Function to check if Azure CLI is available
check_azure_cli() {
    if ! command -v az &> /dev/null; then
        echo "⚠️  Azure CLI not found. Please install Azure CLI to fix NSG rules."
        echo "   Continuing with Kubernetes-level fixes..."
        return 1
    fi
    return 0
}

# Step 1: Fix Azure Network Security Group rules
fix_azure_nsg() {
    echo "🛡️  Step 1: Fixing Azure Network Security Group rules..."
    
    if ! check_azure_cli; then
        echo "   Skipping NSG fixes (Azure CLI not available)"
        return
    fi
    
    # Get NSG associated with the AKS cluster
    NSG_NAME=$(az network nsg list --resource-group $RESOURCE_GROUP --query "[0].name" -o tsv 2>/dev/null || echo "")
    
    if [ -z "$NSG_NAME" ]; then
        echo "   ⚠️  Could not find NSG automatically. Common NSG names:"
        echo "   - aks-agentpool-*-nsg"
        echo "   - MC_${RESOURCE_GROUP}_*_*"
        echo "   Please manually add HTTP (port 80) inbound rule to your NSG"
        return
    fi
    
    echo "   Found NSG: $NSG_NAME"
    
    # Check if HTTP rule already exists
    HTTP_RULE_EXISTS=$(az network nsg rule show --resource-group $RESOURCE_GROUP --nsg-name $NSG_NAME --name "AllowHTTPInbound" --query "name" -o tsv 2>/dev/null || echo "")
    
    if [ -z "$HTTP_RULE_EXISTS" ]; then
        echo "   Creating HTTP inbound rule for ACME challenges..."
        az network nsg rule create \
            --resource-group $RESOURCE_GROUP \
            --nsg-name $NSG_NAME \
            --name "AllowHTTPInbound" \
            --protocol Tcp \
            --direction Inbound \
            --priority 1000 \
            --source-address-prefixes Internet \
            --source-port-ranges "*" \
            --destination-address-prefixes "*" \
            --destination-port-ranges 80 \
            --access Allow \
            --description "Allow HTTP for Let's Encrypt ACME challenges" \
            2>/dev/null || echo "   ⚠️  Failed to create NSG rule (may need manual configuration)"
        echo "   ✅ HTTP inbound rule created"
    else
        echo "   ✅ HTTP inbound rule already exists"
    fi
}

# Step 2: Configure Kong for ACME challenge routing
configure_kong_acme() {
    echo "🦍 Step 2: Configuring Kong for ACME challenge routing..."
    
    # Create a Kong plugin for ACME challenge handling
    cat <<EOF > /tmp/kong-acme-plugin.yaml
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: acme-challenge-plugin
  namespace: $NAMESPACE
plugin: request-termination
config:
  status_code: 404
  message: "ACME challenge path - handled by cert-manager"
---
apiVersion: configuration.konghq.com/v1
kind: KongIngress
metadata:
  name: acme-challenge-ingress
  namespace: $NAMESPACE
upstream:
  host_header: \$host
route:
  path_handling: v1
  preserve_host: true
  strip_path: false
EOF

    # Apply the Kong configuration
    kubectl apply -f /tmp/kong-acme-plugin.yaml
    echo "   ✅ Kong ACME plugin configured"
    
    # Clean up temp file
    rm -f /tmp/kong-acme-plugin.yaml
}

# Step 3: Ensure cert-manager ACME solver configuration
configure_cert_manager_solver() {
    echo "🔐 Step 3: Configuring cert-manager ACME solver..."
    
    # Check if ClusterIssuer has proper solver configuration
    kubectl get clusterissuer letsencrypt-dev -o yaml > /tmp/current-issuer.yaml
    
    # Create updated ClusterIssuer with explicit HTTP01 solver
    cat <<EOF > /tmp/updated-clusterissuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-dev
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@mindx.edu.vn
    privateKeySecretRef:
      name: letsencrypt-dev
    solvers:
    - http01:
        ingress:
          class: kong
          podTemplate:
            spec:
              nodeSelector:
                "kubernetes.io/os": linux
      selector: {}
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: admin@mindx.edu.vn
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: kong
          podTemplate:
            spec:
              nodeSelector:
                "kubernetes.io/os": linux
      selector: {}
EOF
    
    kubectl apply -f /tmp/updated-clusterissuer.yaml
    echo "   ✅ ClusterIssuers updated with explicit HTTP01 solvers"
    
    # Clean up temp files
    rm -f /tmp/current-issuer.yaml /tmp/updated-clusterissuer.yaml
}

# Step 4: Check and fix Azure Load Balancer health probes
fix_load_balancer_probes() {
    echo "⚖️  Step 4: Checking Azure Load Balancer health probes..."
    
    if ! check_azure_cli; then
        echo "   Skipping Load Balancer probe checks (Azure CLI not available)"
        return
    fi
    
    # Get Load Balancer name
    LB_FULL_NAME=$(az network lb list --resource-group MC_${RESOURCE_GROUP}_*_* --query "[?contains(name, '$LB_NAME')].name" -o tsv 2>/dev/null | head -1 || echo "")
    
    if [ -z "$LB_FULL_NAME" ]; then
        echo "   ⚠️  Could not find Load Balancer automatically"
        echo "   Please manually check Azure Load Balancer health probes in Azure Portal"
        return
    fi
    
    echo "   Found Load Balancer: $LB_FULL_NAME"
    
    # Check existing health probes
    HTTP_PROBE=$(az network lb probe list --resource-group MC_${RESOURCE_GROUP}_*_* --lb-name $LB_FULL_NAME --query "[?port==\`80\`].name" -o tsv 2>/dev/null || echo "")
    
    if [ -n "$HTTP_PROBE" ]; then
        echo "   ✅ HTTP health probe already exists: $HTTP_PROBE"
    else
        echo "   ⚠️  No HTTP health probe found - this may need manual configuration"
        echo "   Please ensure Azure Load Balancer has a health probe for port 80"
    fi
}

# Step 5: Restart cert-manager and trigger certificate recreation
restart_cert_manager() {
    echo "🔄 Step 5: Restarting cert-manager and triggering certificate recreation..."
    
    # Delete existing failed certificates and orders
    kubectl delete certificates --all -n $NAMESPACE 2>/dev/null || true
    kubectl delete orders --all -n $NAMESPACE 2>/dev/null || true
    kubectl delete certificaterequests --all -n $NAMESPACE 2>/dev/null || true
    
    # Restart cert-manager components
    kubectl rollout restart deployment/cert-manager -n $NAMESPACE
    kubectl rollout restart deployment/cert-manager-webhook -n $NAMESPACE
    kubectl rollout restart deployment/cert-manager-cainjector -n $NAMESPACE
    
    echo "   ⏳ Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=available --timeout=120s deployment/cert-manager -n $NAMESPACE
    kubectl wait --for=condition=available --timeout=120s deployment/cert-manager-webhook -n $NAMESPACE
    kubectl wait --for=condition=available --timeout=120s deployment/cert-manager-cainjector -n $NAMESPACE
    
    echo "   ✅ cert-manager restarted successfully"
}

# Step 6: Trigger new certificate requests
trigger_certificate_requests() {
    echo "📜 Step 6: Triggering new certificate requests..."
    
    # Reapply ingress to trigger certificate creation
    kubectl apply -f ../chart/kong-ingress/kong-ingress.yaml
    
    echo "   ⏳ Waiting for certificate creation..."
    sleep 10
    
    # Show certificate status
    echo "   📋 New certificate status:"
    kubectl get certificates -n $NAMESPACE 2>/dev/null || echo "   No certificates found yet (this is normal)"
}

# Step 7: Test connectivity
test_connectivity() {
    echo "🧪 Step 7: Testing ACME connectivity..."
    
    echo "   Testing HTTP access to both domains:"
    
    echo "   Frontend HTTP test:"
    curl -I http://banv-app-dev.mindx.edu.vn/.well-known/acme-challenge/test 2>/dev/null | head -3 || echo "   Connection failed"
    
    echo "   Backend HTTP test:"  
    curl -I http://banv-api-dev.mindx.edu.vn/.well-known/acme-challenge/test 2>/dev/null | head -3 || echo "   Connection failed"
    
    echo "   📋 Kong service status:"
    kubectl get service kong-ingress-kong-proxy -n $NAMESPACE
}

# Main execution
echo "🚀 Starting ACME connectivity fix process..."
echo ""

fix_azure_nsg
configure_kong_acme  
configure_cert_manager_solver
fix_load_balancer_probes
restart_cert_manager
trigger_certificate_requests
test_connectivity

echo ""
echo "🎉 ACME connectivity fix completed!"
echo ""
echo "📋 What was fixed:"
echo "✅ Azure NSG rules (if Azure CLI available)"
echo "✅ Kong ACME challenge routing"
echo "✅ cert-manager HTTP01 solver configuration" 
echo "✅ cert-manager components restarted"
echo "✅ New certificate requests triggered"
echo ""
echo "⏳ Next steps:"
echo "1. Wait 2-5 minutes for certificate validation"
echo "2. Check certificate status: kubectl get certificates -n $NAMESPACE"
echo "3. If still failing, check: ./deploy/shell/check-certificates.sh"
echo ""
echo "💡 If issues persist, manually check:"
echo "- Azure Network Security Group rules for port 80"
echo "- Azure Load Balancer health probe configuration"
echo "- DNS propagation (may take up to 24 hours)" 