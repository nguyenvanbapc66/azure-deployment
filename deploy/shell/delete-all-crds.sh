#!/bin/bash

# Script to delete ALL Custom Resource Definitions (CRDs)
# ⚠️  WARNING: This will COMPLETELY BREAK your cluster!
# ⚠️  This will destroy cert-manager, Kong, Azure CNI, monitoring, etc.

echo "🚨 DANGER: You are about to delete ALL CRDs from the cluster!"
echo "🚨 This will DESTROY:"
echo "   - cert-manager (SSL certificates)"
echo "   - Kong Ingress Controller (routing)"
echo "   - Azure CNI networking"
echo "   - Volume snapshots"
echo "   - Monitoring systems"
echo ""
echo "🚨 Your cluster will become UNUSABLE!"
echo ""

# List all CRDs first
echo "📋 Current CRDs that will be DELETED:"
kubectl get crd --no-headers | awk '{print "   - " $1}'
echo ""

# Require explicit confirmation
read -p "⚠️  Type 'DELETE ALL CRDS' to confirm (anything else cancels): " confirmation

if [ "$confirmation" != "DELETE ALL CRDS" ]; then
    echo "❌ Operation cancelled - CRDs preserved"
    exit 1
fi

echo ""
echo "💥 PROCEEDING WITH CRD DELETION..."
echo "⏳ This may take several minutes..."

# Get all CRD names and delete them
CRD_LIST=$(kubectl get crd --no-headers -o custom-columns=":metadata.name")

if [ -z "$CRD_LIST" ]; then
    echo "✅ No CRDs found to delete"
    exit 0
fi

# Delete each CRD
echo "$CRD_LIST" | while read crd; do
    if [ ! -z "$crd" ]; then
        echo "🗑️  Deleting CRD: $crd"
        kubectl delete crd "$crd" --timeout=60s 2>/dev/null || echo "   ⚠️  Failed to delete $crd"
    fi
done

echo ""
echo "💥 CRD deletion process completed"
echo "🚨 Your cluster is now in a BROKEN state!"
echo "🚨 You will need to reinstall all operators and applications"

# Show remaining CRDs (if any)
echo ""
echo "📋 Remaining CRDs:"
kubectl get crd --no-headers 2>/dev/null || echo "   (Unable to check - API may be broken)" 