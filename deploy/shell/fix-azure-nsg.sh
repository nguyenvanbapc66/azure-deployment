#!/bin/bash

# Script to fix Azure NSG rules for Let's Encrypt ACME challenges
# This addresses the "Timeout during connect" error from Let's Encrypt servers

echo "🛡️ Fixing Azure Network Security Group for ACME Challenges"
echo "========================================================="
echo ""

RESOURCE_GROUP="mindx-individual-banv-rg"
CLUSTER_NAME="mindx-aks-banv"

echo "🔍 Finding AKS cluster resources..."

# Method 1: Try to find NSG in the main resource group
echo "📋 Checking main resource group: $RESOURCE_GROUP"
az network nsg list --resource-group $RESOURCE_GROUP --output table 2>/dev/null || echo "No NSGs found in main resource group"

echo ""

# Method 2: Find the managed resource group (MC_*)
MC_RG=$(az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query nodeResourceGroup -o tsv 2>/dev/null || echo "")

if [ -n "$MC_RG" ]; then
    echo "📋 Found managed resource group: $MC_RG"
    echo "NSGs in managed resource group:"
    az network nsg list --resource-group $MC_RG --output table 2>/dev/null || echo "No NSGs found"
    
    echo ""
    echo "Load Balancers in managed resource group:"
    az network lb list --resource-group $MC_RG --query "[].{Name:name,IP:frontendIpConfigurations[0].publicIpAddress.id}" --output table 2>/dev/null || echo "No Load Balancers found"
else
    echo "⚠️ Could not find managed resource group automatically"
fi

echo ""
echo "🔧 Manual NSG Rule Creation Instructions:"
echo "========================================="
echo ""
echo "1. Go to Azure Portal: https://portal.azure.com"
echo "2. Navigate to Resource Groups → $RESOURCE_GROUP or $MC_RG"
echo "3. Find the Network Security Group (usually named like 'aks-agentpool-*-nsg')"
echo "4. Click on the NSG → Settings → Inbound security rules"
echo "5. Click '+ Add' to create a new rule with these settings:"
echo ""
echo "   Rule Name: AllowHTTPForACME"
echo "   Priority: 1000"
echo "   Source: Any (*)"
echo "   Source port ranges: *"
echo "   Destination: Any (*)" 
echo "   Destination port ranges: 80"
echo "   Protocol: TCP"
echo "   Action: Allow"
echo "   Description: Allow HTTP for Let's Encrypt ACME challenges"
echo ""
echo "6. Click 'Add' to save the rule"
echo ""

# Try to create the rule automatically if we found the NSG
if [ -n "$MC_RG" ]; then
    NSG_NAME=$(az network nsg list --resource-group $MC_RG --query "[0].name" -o tsv 2>/dev/null || echo "")
    
    if [ -n "$NSG_NAME" ]; then
        echo "🚀 Attempting automatic NSG rule creation..."
        echo "NSG Name: $NSG_NAME"
        echo "Resource Group: $MC_RG"
        
        # Check if rule already exists
        EXISTING_RULE=$(az network nsg rule show --resource-group $MC_RG --nsg-name $NSG_NAME --name "AllowHTTPForACME" --query "name" -o tsv 2>/dev/null || echo "")
        
        if [ -n "$EXISTING_RULE" ]; then
            echo "✅ HTTP rule already exists: $EXISTING_RULE"
        else
            echo "Creating HTTP inbound rule..."
            
            if az network nsg rule create \
                --resource-group $MC_RG \
                --nsg-name $NSG_NAME \
                --name "AllowHTTPForACME" \
                --protocol Tcp \
                --direction Inbound \
                --priority 1000 \
                --source-address-prefixes "*" \
                --source-port-ranges "*" \
                --destination-address-prefixes "*" \
                --destination-port-ranges 80 \
                --access Allow \
                --description "Allow HTTP for Let's Encrypt ACME challenges" \
                2>/dev/null; then
                echo "✅ HTTP inbound rule created successfully!"
            else
                echo "❌ Failed to create NSG rule automatically"
                echo "Please create the rule manually using the instructions above"
            fi
        fi
    else
        echo "⚠️ Could not find NSG automatically"
        echo "Please create the rule manually using the instructions above"
    fi
fi

echo ""
echo "🧪 Testing connectivity after NSG fix..."
echo "========================================"
echo ""

echo "Testing HTTP access to domains:"
echo "Frontend: http://banv-app-dev.mindx.edu.vn"
curl -I http://banv-app-dev.mindx.edu.vn/.well-known/acme-challenge/test --connect-timeout 10 2>/dev/null | head -3 || echo "❌ Frontend HTTP connection failed"

echo ""
echo "Backend: http://banv-api-dev.mindx.edu.vn" 
curl -I http://banv-api-dev.mindx.edu.vn/.well-known/acme-challenge/test --connect-timeout 10 2>/dev/null | head -3 || echo "❌ Backend HTTP connection failed"

echo ""
echo "📋 Current Kong LoadBalancer status:"
kubectl get service kong-ingress-kong-proxy -n banv-projects

echo ""
echo "🎯 Next Steps:"
echo "============="
echo "1. Verify NSG rule was created (check Azure Portal)"
echo "2. Wait 2-3 minutes for NSG changes to propagate"
echo "3. Check certificate status: kubectl get certificates -n banv-projects"
echo "4. Monitor certificate progress: ./deploy/shell/check-certificates.sh"
echo ""
echo "💡 If certificates still fail:"
echo "- Double-check the NSG rule exists and is enabled"
echo "- Ensure no Azure Firewall is blocking Let's Encrypt IPs"
echo "- Check if Azure DDoS protection is interfering" 