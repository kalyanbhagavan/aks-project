#!/bin/bash

# Setup Azure Files for AKS deployment
# This script creates the Azure Files share and updates the deployment

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[SETUP]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration - Update these values
STORAGE_ACCOUNT="${STORAGE_ACCOUNT:-aksstatedemo2025}"
RESOURCE_GROUP="${RESOURCE_GROUP:-aks-challenge-rg}"
SHARE_NAME="staticweb"

print_status "Setting up Azure Files share..."

# Check if Azure CLI is logged in
if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure CLI. Please run 'az login' first."
    exit 1
fi

# Create the file share
print_status "Creating Azure Files share '$SHARE_NAME'..."
az storage share create \
    --account-name $STORAGE_ACCOUNT \
    --name $SHARE_NAME \
    --quota 1

print_status "Azure Files share created successfully!"

# Upload some sample static content
print_status "Uploading sample static content..."
cat > sample-index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Static Assets Demo</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; }
        .container { max-width: 600px; margin: 0 auto; }
        .success { color: green; }
    </style>
</head>
<body>
    <div class="container">
        <h1>📁 Static Assets from Azure Files</h1>
        <p class="success">✅ Successfully loaded from Azure Files share!</p>
        <p>This content is served from the Azure Files share mounted in the pod.</p>
        <p><strong>Share Name:</strong> staticweb</p>
        <p><strong>Storage Account:</strong> $STORAGE_ACCOUNT</p>
    </div>
</body>
</html>
EOF

# Upload the file to the share
az storage file upload \
    --account-name $STORAGE_ACCOUNT \
    --share-name $SHARE_NAME \
    --source sample-index.html \
    --path index.html

print_status "Sample content uploaded to Azure Files share!"

# Clean up temporary file
rm -f sample-index.html

print_status "Azure Files setup completed!"
print_status "You can now uncomment the volume mounts in deployment.yaml"