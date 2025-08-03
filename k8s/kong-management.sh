#!/bin/bash

# Kong Gateway Management Script
# This script helps manage Kong Gateway operations

KONG_ADMIN_URL="http://localhost:8001"
KONG_PROXY_URL="http://20.157.31.86"

echo "🔐 Kong Gateway Management Script"
echo "=================================="

# Function to start port forwarding
start_port_forward() {
    echo "🚀 Starting Kong Admin API port forward..."
    # Kill any existing port-forward processes
    pkill -f "kubectl port-forward.*kong-gateway-service" 2>/dev/null || true
    sleep 1
    
    # Start new port forward
    kubectl port-forward service/kong-gateway-service 8001:8001 -n mindx-projects > /dev/null 2>&1 &
    PORT_FORWARD_PID=$!
    
    # Wait for port forward to be ready
    for i in {1..10}; do
        if curl -s "$KONG_ADMIN_URL/status" > /dev/null 2>&1; then
            echo "✅ Port forwarding started successfully"
            return 0
        fi
        sleep 1
    done
    
    echo "❌ Failed to start port forwarding"
    kill $PORT_FORWARD_PID 2>/dev/null || true
    return 1
}

# Function to stop port forwarding
stop_port_forward() {
    echo "🛑 Stopping port forwarding..."
    pkill -f "kubectl port-forward.*kong-gateway-service" 2>/dev/null || true
    sleep 1
    echo "✅ Port forwarding stopped"
}

# Function to check Kong status
check_status() {
    echo "📊 Checking Kong Gateway status..."
    if curl -s "$KONG_ADMIN_URL/status" > /dev/null 2>&1; then
        curl -s "$KONG_ADMIN_URL/status" | jq . 2>/dev/null || echo "Status endpoint responded but jq not available"
    else
        echo "❌ Cannot connect to Kong Admin API"
    fi
}

# Function to list services
list_services() {
    echo "📋 Listing Kong services..."
    if curl -s "$KONG_ADMIN_URL/services" > /dev/null 2>&1; then
        curl -s "$KONG_ADMIN_URL/services" | jq . 2>/dev/null || echo "Services endpoint responded but jq not available"
    else
        echo "❌ Cannot connect to Kong Admin API"
    fi
}

# Function to list routes
list_routes() {
    echo "🛣️  Listing Kong routes..."
    if curl -s "$KONG_ADMIN_URL/routes" > /dev/null 2>&1; then
        curl -s "$KONG_ADMIN_URL/routes" | jq . 2>/dev/null || echo "Routes endpoint responded but jq not available"
    else
        echo "❌ Cannot connect to Kong Admin API"
    fi
}

# Function to list consumers
list_consumers() {
    echo "👥 Listing Kong consumers..."
    if curl -s "$KONG_ADMIN_URL/consumers" > /dev/null 2>&1; then
        curl -s "$KONG_ADMIN_URL/consumers" | jq . 2>/dev/null || echo "Consumers endpoint responded but jq not available"
    else
        echo "❌ Cannot connect to Kong Admin API"
    fi
}

# Function to test frontend
test_frontend() {
    echo "🌐 Testing frontend access..."
    if curl -I "$KONG_PROXY_URL/" > /dev/null 2>&1; then
        curl -I "$KONG_PROXY_URL/"
    else
        echo "❌ Cannot access frontend at $KONG_PROXY_URL"
    fi
}

# Function to test backend with API key
test_backend() {
    echo "🔑 Testing backend access with API key..."
    if curl -H "apikey: your-secret-api-key-12345" "$KONG_PROXY_URL/api" > /dev/null 2>&1; then
        curl -H "apikey: your-secret-api-key-12345" "$KONG_PROXY_URL/api"
    else
        echo "❌ Cannot access backend with API key"
    fi
}

# Function to test backend without API key
test_backend_unauthorized() {
    echo "🚫 Testing backend access without API key..."
    if curl "$KONG_PROXY_URL/api" > /dev/null 2>&1; then
        curl "$KONG_PROXY_URL/api"
    else
        echo "❌ Cannot access backend without API key"
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  start     - Start port forwarding for Kong Admin API"
    echo "  stop      - Stop port forwarding"
    echo "  status    - Check Kong Gateway status"
    echo "  services  - List Kong services"
    echo "  routes    - List Kong routes"
    echo "  consumers - List Kong consumers"
    echo "  test      - Test frontend and backend access"
    echo "  help      - Show this help message"
}

# Function to cleanup on exit
cleanup() {
    stop_port_forward
    exit 0
}

# Set trap to cleanup on script exit
trap cleanup EXIT

# Main script logic
case "$1" in
    "start")
        start_port_forward
        ;;
    "stop")
        stop_port_forward
        ;;
    "status")
        if start_port_forward; then
            check_status
        fi
        ;;
    "services")
        if start_port_forward; then
            list_services
        fi
        ;;
    "routes")
        if start_port_forward; then
            list_routes
        fi
        ;;
    "consumers")
        if start_port_forward; then
            list_consumers
        fi
        ;;
    "test")
        test_frontend
        echo ""
        test_backend
        echo ""
        test_backend_unauthorized
        ;;
    "help"|*)
        show_usage
        ;;
esac 