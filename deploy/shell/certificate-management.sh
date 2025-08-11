#!/bin/bash

# Certificate Management Functions for deploy-services.sh
# Provides monitoring, retry logic, error recovery, and troubleshooting

# Configuration
NAMESPACE="banv-projects"
MAX_WAIT_TIME=300  # 5 minutes
CHECK_INTERVAL=10  # 10 seconds
MAX_RETRIES=3

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to check certificate status
check_certificate_status() {
    local cert_name=$1
    local namespace=$2
    
    if ! kubectl get certificate "$cert_name" -n "$namespace" >/dev/null 2>&1; then
        echo "not_found"
        return 1
    fi
    
    local ready_status=$(kubectl get certificate "$cert_name" -n "$namespace" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    
    if [ "$ready_status" = "True" ]; then
        echo "ready"
        return 0
    elif [ "$ready_status" = "False" ]; then
        echo "false"
        return 1
    else
        echo "unknown"
        return 1
    fi
}

# Function to get certificate failure reason
get_certificate_failure_reason() {
    local cert_name=$1
    local namespace=$2
    
    local message=$(kubectl get certificate "$cert_name" -n "$namespace" -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null)
    echo "$message"
}

# Function to check order status
check_order_status() {
    local namespace=$1
    
    local orders=$(kubectl get orders -n "$namespace" --no-headers 2>/dev/null | awk '{print $1 " " $2}')
    if [ -z "$orders" ]; then
        echo "no_orders"
        return 0
    fi
    
    echo "$orders" | while read order_name state; do
        if [ "$state" = "valid" ]; then
            continue
        elif [ "$state" = "ready" ]; then
            continue
        elif [ "$state" = "pending" ]; then
            echo "pending:$order_name"
        elif [ "$state" = "invalid" ]; then
            echo "invalid:$order_name"
        else
            echo "unknown:$order_name:$state"
        fi
    done
}

# Function to get detailed order failure information
get_order_failure_details() {
    local order_name=$1
    local namespace=$2
    
    log "🔍 Getting failure details for order: $order_name"
    
    # Get order details
    kubectl describe order "$order_name" -n "$namespace" | grep -A 10 -B 5 "Message\|Reason\|State\|URL"
    
    # Get associated challenges
    local challenges=$(kubectl get challenges -n "$namespace" --no-headers 2>/dev/null | grep "$order_name" | awk '{print $1}')
    
    if [ -n "$challenges" ]; then
        echo "$challenges" | while read challenge_name; do
            log "🔍 Challenge details for: $challenge_name"
            kubectl describe challenge "$challenge_name" -n "$namespace" | grep -A 15 -B 5 "Reason\|State\|Message"
        done
    fi
}

# Function to test ACME connectivity
test_acme_connectivity() {
    local domain=$1
    
    log "🧪 Testing ACME connectivity for: $domain"
    
    # Test HTTP access
    local http_status=$(curl -s -o /dev/null -w "%{http_code}" "http://$domain/.well-known/acme-challenge/test" --connect-timeout 10 2>/dev/null || echo "000")
    
    if [ "$http_status" = "404" ] || [ "$http_status" = "200" ]; then
        log_success "HTTP connectivity OK for $domain (status: $http_status)"
        return 0
    else
        log_error "HTTP connectivity failed for $domain (status: $http_status)"
        return 1
    fi
}

# Function to restart cert-manager
restart_cert_manager() {
    local namespace=$1
    
    log "🔄 Restarting cert-manager components..."
    
    # Restart all cert-manager deployments
    kubectl rollout restart deployment/cert-manager -n "$namespace" 2>/dev/null || log_warning "cert-manager deployment not found"
    kubectl rollout restart deployment/cert-manager-webhook -n "$namespace" 2>/dev/null || log_warning "cert-manager-webhook deployment not found"
    kubectl rollout restart deployment/cert-manager-cainjector -n "$namespace" 2>/dev/null || log_warning "cert-manager-cainjector deployment not found"
    
    # Wait for deployments to be ready
    log "⏳ Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=available --timeout=120s deployment/cert-manager -n "$namespace" 2>/dev/null || log_warning "cert-manager not ready"
    kubectl wait --for=condition=available --timeout=120s deployment/cert-manager-webhook -n "$namespace" 2>/dev/null || log_warning "cert-manager-webhook not ready"
    kubectl wait --for=condition=available --timeout=120s deployment/cert-manager-cainjector -n "$namespace" 2>/dev/null || log_warning "cert-manager-cainjector not ready"
    
    log_success "cert-manager restart completed"
}

# Function to clean up stuck certificates and orders
cleanup_stuck_certificates() {
    local namespace=$1
    
    log "🧹 Cleaning up stuck certificates and orders..."
    
    # Delete failed certificates
    local failed_certs=$(kubectl get certificates -n "$namespace" --no-headers 2>/dev/null | grep "False" | awk '{print $1}')
    if [ -n "$failed_certs" ]; then
        echo "$failed_certs" | while read cert_name; do
            log "🗑️  Deleting failed certificate: $cert_name"
            kubectl delete certificate "$cert_name" -n "$namespace" --ignore-not-found=true
        done
    fi
    
    # Delete invalid orders
    local invalid_orders=$(kubectl get orders -n "$namespace" --no-headers 2>/dev/null | grep "invalid" | awk '{print $1}')
    if [ -n "$invalid_orders" ]; then
        echo "$invalid_orders" | while read order_name; do
            log "🗑️  Deleting invalid order: $order_name"
            kubectl delete order "$order_name" -n "$namespace" --ignore-not-found=true
        done
    fi
    
    # Delete failed certificate requests
    local failed_requests=$(kubectl get certificaterequests -n "$namespace" --no-headers 2>/dev/null | grep "False" | awk '{print $1}')
    if [ -n "$failed_requests" ]; then
        echo "$failed_requests" | while read request_name; do
            log "🗑️  Deleting failed certificate request: $request_name"
            kubectl delete certificaterequest "$request_name" -n "$namespace" --ignore-not-found=true
        done
    fi
    
    # Delete associated secrets for failed certificates
    kubectl delete secret frontend-tls backend-tls -n "$namespace" --ignore-not-found=true
    
    log_success "Cleanup completed"
}

# Function to validate Azure NSG (if Azure CLI available)
validate_azure_nsg() {
    local resource_group=$1
    local cluster_name=$2
    
    if ! command -v az &> /dev/null; then
        log_warning "Azure CLI not found - skipping NSG validation"
        return 0
    fi
    
    log "🛡️  Validating Azure Network Security Group..."
    
    # Get managed resource group
    local mc_rg=$(az aks show --resource-group "$resource_group" --name "$cluster_name" --query nodeResourceGroup -o tsv 2>/dev/null || echo "")
    
    if [ -z "$mc_rg" ]; then
        log_warning "Could not find managed resource group - skipping NSG validation"
        return 0
    fi
    
    # Get NSG name
    local nsg_name=$(az network nsg list --resource-group "$mc_rg" --query "[0].name" -o tsv 2>/dev/null || echo "")
    
    if [ -z "$nsg_name" ]; then
        log_warning "Could not find NSG - may need manual configuration"
        return 0
    fi
    
    # Check for HTTP rule
    local http_rule=$(az network nsg rule show --resource-group "$mc_rg" --nsg-name "$nsg_name" --name "AllowHTTPForACME" --query "name" -o tsv 2>/dev/null || echo "")
    
    if [ -n "$http_rule" ]; then
        log_success "Azure NSG HTTP rule exists: $http_rule"
        return 0
    else
        log_warning "Azure NSG HTTP rule not found - ACME challenges may fail"
        log "💡 Create rule manually: AllowHTTPForACME (port 80, TCP, Allow)"
        return 1
    fi
}

# Main function to monitor certificates with retry logic
monitor_certificates_with_retry() {
    local namespace=$1
    local domains=("$@")
    local domains=("${domains[@]:1}")  # Remove first element (namespace)
    
    log "🔍 Starting certificate monitoring for domains: ${domains[*]}"
    
    local retry_count=0
    local all_ready=false
    
    while [ $retry_count -lt $MAX_RETRIES ] && [ "$all_ready" = false ]; do
        log "🔄 Monitoring attempt $((retry_count + 1))/$MAX_RETRIES"
        
        local start_time=$(date +%s)
        local timeout_reached=false
        
        while [ "$timeout_reached" = false ]; do
            local current_time=$(date +%s)
            local elapsed=$((current_time - start_time))
            
            if [ $elapsed -gt $MAX_WAIT_TIME ]; then
                timeout_reached=true
                log_warning "Timeout reached ($MAX_WAIT_TIME seconds)"
                break
            fi
            
            # Check all certificates
            local all_certs_ready=true
            local cert_statuses=""
            
            for domain in "${domains[@]}"; do
                local cert_name=""
                if [[ "$domain" == *"banv-app-dev"* ]]; then
                    cert_name="frontend-tls"
                elif [[ "$domain" == *"banv-api-dev"* ]]; then
                    cert_name="backend-tls"
                else
                    continue
                fi
                
                local status=$(check_certificate_status "$cert_name" "$namespace")
                cert_statuses="$cert_statuses $cert_name:$status"
                
                if [ "$status" != "ready" ]; then
                    all_certs_ready=false
                fi
            done
            
            log "📋 Certificate statuses:$cert_statuses"
            
            if [ "$all_certs_ready" = true ]; then
                all_ready=true
                log_success "All certificates are ready!"
                break
            fi
            
            # Check for failed orders and provide diagnostics
            local order_issues=$(check_order_status "$namespace")
            if [[ "$order_issues" == *"invalid"* ]]; then
                log_error "Found invalid orders - need intervention"
                echo "$order_issues" | while IFS=':' read status order_name; do
                    if [ "$status" = "invalid" ]; then
                        get_order_failure_details "$order_name" "$namespace"
                    fi
                done
                break
            fi
            
            sleep $CHECK_INTERVAL
        done
        
        if [ "$all_ready" = true ]; then
            break
        fi
        
        # If not ready, try recovery
        if [ $retry_count -lt $((MAX_RETRIES - 1)) ]; then
            log_warning "Certificates not ready, attempting recovery..."
            
            # Test connectivity first
            for domain in "${domains[@]}"; do
                test_acme_connectivity "$domain"
            done
            
            # Clean up and restart
            cleanup_stuck_certificates "$namespace"
            restart_cert_manager "$namespace"
            
            # Wait a bit before retry
            log "⏳ Waiting 30 seconds before retry..."
            sleep 30
            
            # Reapply ingress to trigger new certificate requests
            log "🔄 Reapplying ingress configuration..."
            kubectl apply -f ./deploy/chart/kong-ingress/kong-ingress.yaml
            
            sleep 15  # Give time for new certificates to be created
        fi
        
        retry_count=$((retry_count + 1))
    done
    
    if [ "$all_ready" = true ]; then
        log_success "Certificate monitoring completed successfully!"
        return 0
    else
        log_error "Certificate monitoring failed after $MAX_RETRIES attempts"
        
        # Final diagnostics
        log "🔍 Final diagnostic information:"
        kubectl get certificates -n "$namespace"
        kubectl get orders -n "$namespace"
        kubectl get certificaterequests -n "$namespace"
        
        return 1
    fi
}

# Function to test final certificate functionality
test_certificate_functionality() {
    local domains=("$@")
    
    log "🧪 Testing final certificate functionality..."
    
    for domain in "${domains[@]}"; do
        log "🔒 Testing HTTPS for: $domain"
        
        local https_status=$(curl -s -o /dev/null -w "%{http_code}" "https://$domain" --connect-timeout 10 2>/dev/null || echo "000")
        
        if [ "$https_status" -ge 200 ] && [ "$https_status" -lt 400 ]; then
            log_success "HTTPS working for $domain (status: $https_status)"
        else
            log_error "HTTPS failed for $domain (status: $https_status)"
        fi
        
        # Test certificate details
        local cert_info=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -issuer -dates 2>/dev/null || echo "Certificate info unavailable")
        log "📋 Certificate info for $domain:"
        echo "$cert_info" | sed 's/^/    /'
    done
}

# Export functions for use in other scripts
export -f check_certificate_status
export -f get_certificate_failure_reason
export -f check_order_status
export -f get_order_failure_details
export -f test_acme_connectivity
export -f restart_cert_manager
export -f cleanup_stuck_certificates
export -f validate_azure_nsg
export -f monitor_certificates_with_retry
export -f test_certificate_functionality
export -f log log_success log_warning log_error 