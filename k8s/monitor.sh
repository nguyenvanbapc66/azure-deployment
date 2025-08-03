#!/bin/bash

echo "🚀 Monitoring MindX Projects Deployment..."
echo "=========================================="

# Function to show pod status
show_pod_status() {
    echo "📊 Pod Status:"
    kubectl get pods -n mindx-projects --no-headers | while read line; do
        echo "   $line"
    done
    echo ""
}

# Function to show service status
show_service_status() {
    echo "🌐 Service Status:"
    kubectl get services -n mindx-projects
    echo ""
}

# Function to show deployment status
show_deployment_status() {
    echo "📈 Deployment Status:"
    kubectl get deployments -n mindx-projects
    echo ""
}

# Function to show events
show_events() {
    echo "📋 Recent Events:"
    kubectl get events -n mindx-projects --sort-by='.lastTimestamp' | tail -5
    echo ""
}

# Main monitoring loop
while true; do
    clear
    echo "🔄 MindX Projects - Deployment Monitor"
    echo "======================================"
    echo "Time: $(date)"
    echo ""
    
    show_pod_status
    show_service_status
    show_deployment_status
    show_events
    
    echo "Press Ctrl+C to stop monitoring"
    echo "======================================"
    
    # Check if all pods are ready
    READY_PODS=$(kubectl get pods -n mindx-projects --no-headers | grep -c "1/1.*Running")
    TOTAL_PODS=$(kubectl get pods -n mindx-projects --no-headers | wc -l)
    
    if [ "$READY_PODS" -eq "$TOTAL_PODS" ] && [ "$TOTAL_PODS" -gt 0 ]; then
        echo "✅ All pods are ready! Deployment successful!"
        echo "🌐 Access your application at: http://$(kubectl get service frontend-service -n mindx-projects -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
        break
    fi
    
    sleep 3
done 