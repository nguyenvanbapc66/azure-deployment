#!/bin/bash

# Script to fix Azure NSG rules for HTTPS web traffic
# This addresses HTTPS connectivity issues by allowing port 443 inbound traffic

echo "🛡️ Fixing Azure Network Security Group for HTTPS Web Traffic"
echo "============================================================="
echo ""

RESOURCE_GROUP="mindx-individual-banv-rg"
CLUSTER_NAME="mindx_aks_banv"

echo "🔍 Finding AKS cluster resources..."

# Method 1: Try to find NSG in the main resource group
echo "📋 Checking main resource group: $RESOURCE_GROUP"
az network nsg list --resource-group $RESOURCE_GROUP --output table 2>/dev/null || echo "No NSGs found in main resource group"

echo ""

# Method 2: Find the managed resource group (MC_*)
MC_RG=$(az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query nodeResourceGroup -o tsv 2>/dev/null || echo "")

if [ -n "$MC_RG" ]; then
    echo "🔍 Testing Azure permissions..."
    
    # Test if we can read NSGs in the managed resource group
    PERMISSION_TEST=$(az network nsg list --resource-group $MC_RG --query "[0].name" -o tsv 2>&1)
    if echo "$PERMISSION_TEST" | grep -q "AuthorizationFailed"; then
        echo "❌ Permission Error: Cannot access managed resource group $MC_RG"
        echo "   Your account needs 'Network Contributor' role on this resource group"
        echo "   Please ask your Azure administrator to grant this permission"
        echo ""
    else
        echo "✅ Azure permissions verified"
    fi
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
echo "   Rule Name: AllowHTTPS"
echo "   Priority: 1001"
echo "   Source: Any (*)"
echo "   Source port ranges: *"
echo "   Destination: Any (*)" 
echo "   Destination port ranges: 443"
echo "   Protocol: TCP"
echo "   Action: Allow"
echo "   Description: Allow HTTPS web traffic"
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
        EXISTING_RULE=$(az network nsg rule show --resource-group $MC_RG --nsg-name $NSG_NAME --name "AllowHTTPS" --query "name" -o tsv 2>/dev/null || echo "")
        
        if [ -n "$EXISTING_RULE" ]; then
            echo "✅ HTTPS rule already exists: $EXISTING_RULE"
        else
            echo "Creating HTTPS inbound rule..."
            
            if az network nsg rule create \
                --resource-group $MC_RG \
                --nsg-name $NSG_NAME \
                --name "AllowHTTPS" \
                --protocol Tcp \
                --direction Inbound \
                --priority 1001 \
                --source-address-prefixes "*" \
                --source-port-ranges "*" \
                --destination-address-prefixes "*" \
                --destination-port-ranges 443 \
                --access Allow \
                --description "Allow HTTPS web traffic" \
                2>/dev/null; then
                echo "✅ HTTPS inbound rule created successfully!"
            else
                echo "❌ Failed to create NSG rule automatically"
                echo "Please create the rule manually using the instructions above"
                echo ""
                echo "🔍 Common reasons for failure:"
                echo "   • Insufficient permissions (need Network Contributor role)"
                echo "   • Rule with same priority already exists"
                echo "   • Azure CLI authentication expired"
            fi
        fi
    else
        echo "⚠️ Could not find NSG automatically"
        echo "Please create the rule manually using the instructions above"
    fi
fi

echo ""
echo "🧪 Testing HTTPS connectivity after NSG fix..."
echo "==============================================="
echo ""

echo "Testing HTTPS access to domains:"
echo "Frontend: https://banv-app-dev.mindx.edu.vn"
curl -I --insecure https://banv-app-dev.mindx.edu.vn --connect-timeout 10 2>/dev/null | head -3 || echo "❌ Frontend HTTPS connection failed"

echo ""
echo "Backend: https://banv-api-dev.mindx.edu.vn" 
curl -I --insecure https://banv-api-dev.mindx.edu.vn/health --connect-timeout 10 2>/dev/null | head -3 || echo "❌ Backend HTTPS connection failed"

echo ""
echo "Testing certificate validation (without --insecure):"
echo "Frontend certificate test:"
curl -I https://banv-app-dev.mindx.edu.vn --connect-timeout 5 2>&1 | head -2 || echo "⚠️  Certificate validation failed (expected for staging certificates)"

echo ""
echo "📋 Current Kong LoadBalancer status:"
kubectl get service kong-ingress-kong-proxy -n banv-projects

echo ""
echo "🎯 Next Steps:"
echo "============="
echo "1. Verify NSG rule was created (check Azure Portal)"
echo "2. Wait 2-3 minutes for NSG changes to propagate"
echo "3. Test HTTPS without --insecure flag: curl https://banv-app-dev.mindx.edu.vn"
echo "4. If still getting certificate errors, remember you're using staging certificates"
echo ""
echo "💡 If HTTPS still fails:"
echo "- Double-check the NSG rule exists and is enabled (port 443)"
echo "- Ensure you have Network Contributor permissions in Azure"
echo "- Check Azure Portal → Resource Groups → MC_* → Network Security Group"
echo ""
echo "🔒 About Certificate Errors:"
echo "- You're using Let's Encrypt STAGING certificates"
echo "- Staging certificates are NOT trusted by browsers/curl by default"
echo "- This is expected behavior for development/testing"
echo "- Use --insecure flag for testing, or switch to production certificates" 