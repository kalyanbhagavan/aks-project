#!/bin/bash

# Masking Utilities for CI/CD Scripts
# This script provides functions to mask sensitive information in logs and outputs

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to mask sensitive values
# Usage: mask_sensitive "sensitive_value"
mask_sensitive() {
    local value="$1"
    local masked_value=""
    local length=${#value}

    if [ -z "$value" ]; then
        echo "[EMPTY]"
        return
    fi

    if [ $length -gt 4 ]; then
        # Show first 2 and last 2 characters, mask the rest
        masked_value="${value:0:2}***${value: -2}"
    else
        # For short values, just show asterisks
        masked_value="***"
    fi
    echo "$masked_value"
}

# Function to mask Azure credentials
# Usage: mask_azure_credentials
mask_azure_credentials() {
    echo "Azure Credentials:"
    echo "  Client ID: $(mask_sensitive "$ARM_CLIENT_ID")"
    echo "  Client Secret: $(mask_sensitive "$ARM_CLIENT_SECRET")"
    echo "  Subscription ID: $(mask_sensitive "$ARM_SUBSCRIPTION_ID")"
    echo "  Tenant ID: $(mask_sensitive "$ARM_TENANT_ID")"
}

# Function to mask connection strings
# Usage: mask_connection_string "connection_string"
mask_connection_string() {
    local conn_str="$1"
    if [[ "$conn_str" =~ ([^=]+=)([^;]+)(;.*) ]]; then
        local prefix="${BASH_REMATCH[1]}"
        local value="${BASH_REMATCH[2]}"
        local suffix="${BASH_REMATCH[3]}"
        echo "${prefix}$(mask_sensitive "$value")${suffix}"
    else
        echo "$(mask_sensitive "$conn_str")"
    fi
}

# Function to mask URLs with credentials
# Usage: mask_url "https://username:password@host.com/path"
mask_url() {
    local url="$1"
    if [[ "$url" =~ (https?://)([^:]+):([^@]+)@(.+) ]]; then
        local protocol="${BASH_REMATCH[1]}"
        local username="${BASH_REMATCH[2]}"
        local password="${BASH_REMATCH[3]}"
        local host_path="${BASH_REMATCH[4]}"
        echo "${protocol}$(mask_sensitive "$username"):$(mask_sensitive "$password")@${host_path}"
    else
        echo "$url"
    fi
}

# Function to mask IP addresses (show only first and last octet)
# Usage: mask_ip "192.168.1.100"
mask_ip() {
    local ip="$1"
    if [[ "$ip" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}.***.***.${BASH_REMATCH[4]}"
    else
        echo "$(mask_sensitive "$ip")"
    fi
}

# Function to mask email addresses
# Usage: mask_email "user@example.com"
mask_email() {
    local email="$1"
    if [[ "$email" =~ ^([^@]+)@(.+)$ ]]; then
        local username="${BASH_REMATCH[1]}"
        local domain="${BASH_REMATCH[2]}"
        local masked_username=""

        if [ ${#username} -gt 2 ]; then
            masked_username="${username:0:1}***${username: -1}"
        else
            masked_username="***"
        fi

        echo "${masked_username}@${domain}"
    else
        echo "$(mask_sensitive "$email")"
    fi
}

# Function to mask Kubernetes secrets
# Usage: mask_k8s_secret "secret_name" "secret_value"
mask_k8s_secret() {
    local secret_name="$1"
    local secret_value="$2"
    echo "Secret '$secret_name': $(mask_sensitive "$secret_value")"
}

# Function to mask Docker image names with credentials
# Usage: mask_docker_image "registry.azurecr.io/image:tag"
mask_docker_image() {
    local image="$1"
    if [[ "$image" =~ ^([^/]+)\.azurecr\.io/(.+)$ ]]; then
        local registry="${BASH_REMATCH[1]}"
        local image_path="${BASH_REMATCH[2]}"
        echo "$(mask_sensitive "$registry").azurecr.io/$image_path"
    else
        echo "$image"
    fi
}

# Function to print masked environment variables
# Usage: print_masked_env_vars "ARM_CLIENT_ID" "ARM_CLIENT_SECRET"
print_masked_env_vars() {
    for var in "$@"; do
        if [ -n "${!var}" ]; then
            echo "$var: $(mask_sensitive "${!var}")"
        else
            echo "$var: [NOT_SET]"
        fi
    done
}

# Function to mask sensitive data in JSON
# Usage: mask_json_sensitive '{"key": "sensitive_value"}' "key"
mask_json_sensitive() {
    local json="$1"
    local sensitive_key="$2"
    echo "$json" | sed "s/\"$sensitive_key\": \"[^\"]*\"/\"$sensitive_key\": \"***\"/g"
}

# Function to log with masking
# Usage: log_masked "INFO" "Processing credentials: $ARM_CLIENT_SECRET"
log_masked() {
    local level="$1"
    local message="$2"
    local masked_message=$(echo "$message" | sed -E 's/([A-Za-z0-9]{2})[A-Za-z0-9]+([A-Za-z0-9]{2})/\1***\2/g')

    case "$level" in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} $masked_message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $masked_message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $masked_message"
            ;;
        "DEBUG")
            echo -e "${BLUE}[DEBUG]${NC} $masked_message"
            ;;
        *)
            echo "[$level] $masked_message"
            ;;
    esac
}

# Export functions for use in other scripts
export -f mask_sensitive
export -f mask_azure_credentials
export -f mask_connection_string
export -f mask_url
export -f mask_ip
export -f mask_email
export -f mask_k8s_secret
export -f mask_docker_image
export -f print_masked_env_vars
export -f mask_json_sensitive
export -f log_masked