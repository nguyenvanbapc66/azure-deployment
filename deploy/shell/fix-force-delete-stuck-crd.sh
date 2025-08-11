#!/bin/bash

# Script to force delete stuck challenges.acme.cert-manager.io CRD
# This CRD is stuck with deletion timestamp and finalizers

CRD_NAME="challenges.acme.cert-manager.io"

echo "🔧 Force deleting stuck CRD: $CRD_NAME"
echo ""

# Step 1: Delete any remaining challenge resources
echo "🗑️ Step 1: Deleting remaining challenge resources..."
kubectl get challenges --all-namespaces --no-headers 2>/dev/null | while read namespace name state domain age; do
    if [ ! -z "$namespace" ] && [ "$namespace" != "NAMESPACE" ]; then
        echo "   Deleting challenge: $namespace/$name"
        kubectl delete challenge "$name" -n "$namespace" --force --grace-period=0 2>/dev/null || true
    fi
done

# Step 2: Remove finalizers from any remaining challenges
echo "🔧 Step 2: Removing finalizers from any stuck challenges..."
kubectl get challenges --all-namespaces -o json 2>/dev/null | jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' 2>/dev/null | while read namespace name; do
    if [ ! -z "$namespace" ] && [ ! -z "$name" ]; then
        echo "   Removing finalizers from: $namespace/$name"
        kubectl patch challenge "$name" -n "$namespace" --type=merge -p='{"metadata":{"finalizers":[]}}' 2>/dev/null || true
    fi
done

# Step 3: Remove finalizers from the CRD itself
echo "🔧 Step 3: Removing finalizers from CRD..."
kubectl patch crd "$CRD_NAME" --type=merge -p='{"metadata":{"finalizers":[]}}' 2>/dev/null || echo "   ⚠️ Could not patch CRD finalizers"

# Step 4: Force delete the CRD
echo "💥 Step 4: Force deleting the CRD..."
kubectl delete crd "$CRD_NAME" --force --grace-period=0 2>/dev/null || echo "   ⚠️ Could not force delete CRD"

# Step 5: Verify deletion
echo "✅ Step 5: Verifying deletion..."
sleep 3
if kubectl get crd "$CRD_NAME" 2>/dev/null; then
    echo "❌ CRD still exists - may need manual intervention"
    echo "🔍 Current CRD status:"
    kubectl get crd "$CRD_NAME" -o yaml | grep -A 10 -B 5 "finalizers\|deletionTimestamp" 2>/dev/null || true
else
    echo "✅ CRD successfully deleted!"
fi

echo ""
echo "🎉 Force deletion process completed" 