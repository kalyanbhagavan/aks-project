#!/bin/bash

# Deploy to Private AKS Cluster via Jumpbox
# This script handles the complete deployment process for a private AKS cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[DEPLOYMENT]${NC} $1"
}

# Configuration - Use environment variables or GitHub secrets
JUMPBOX_IP="${JUMPBOX_IP:-172.191.240.240}"
JUMPBOX_USER="${JUMPBOX_USER:-azureuser}"
JUMPBOX_PASSWORD="${JUMPBOX_PASSWORD:-P@ssw0rd123!}"
ACR_NAME="${ACR_NAME:-aksdemoacr2025}"
RESOURCE_GROUP="${RESOURCE_GROUP:-aks-challenge-rg}"
AKS_NAME="${AKS_NAME:-aks-demo}"
STORAGE_ACCOUNT="${STORAGE_ACCOUNT:-aksstatedemo2025}"
DOCKER_IMAGE="nginx-demo"
DOCKER_TAG="latest"

# Check if required tools are installed
check_prerequisites() {
    print_header "Checking prerequisites..."

    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi

    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install Azure CLI first."
        exit 1
    fi

    # Check SSH
    if ! command -v ssh &> /dev/null; then
        print_error "SSH is not available. Please install SSH client."
        exit 1
    fi

    # Check if k8s folder exists
    if [ ! -d "k8s" ]; then
        print_error "k8s/ folder not found. Please ensure you have Kubernetes manifests in the k8s/ directory."
        exit 1
    fi

    print_status "All prerequisites are satisfied"
}

# Build and push Docker image to ACR
build_and_push_image() {
    print_header "Building and pushing Docker image to ACR..."

    # Check if Dockerfile exists
    if [ ! -f "Dockerfile" ]; then
        print_warning "Dockerfile not found. Creating a simple NGINX Dockerfile..."
        cat > Dockerfile << 'EOF'
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF

        # Create a simple index.html
        cat > index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>AKS Demo App</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; }
        .container { max-width: 600px; margin: 0 auto; }
        .success { color: green; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 AKS Private Cluster Demo</h1>
        <p class="success">✅ Successfully deployed to private AKS cluster!</p>
        <p>This application is running on a private Azure Kubernetes Service cluster.</p>
        <p>Deployed via jumpbox with secure access patterns.</p>
    </div>
</body>
</html>
EOF
    fi

    # Login to ACR
    print_status "Logging in to Azure Container Registry..."
    az acr login --name $ACR_NAME

    # Build image
    print_status "Building Docker image..."
    docker build -t $ACR_NAME.azurecr.io/$DOCKER_IMAGE:$DOCKER_TAG .

    # Push image
    print_status "Pushing image to ACR..."
    docker push $ACR_NAME.azurecr.io/$DOCKER_IMAGE:$DOCKER_TAG

    print_status "Docker image successfully pushed to ACR"
}

# Deploy to AKS via jumpbox
deploy_to_aks() {
    print_header "Deploying to AKS via jumpbox..."

    # Copy k8s manifests to jumpbox
    print_status "Copying k8s manifests to jumpbox..."
    sshpass -p "$JUMPBOX_PASSWORD" scp -o StrictHostKeyChecking=no -r ./k8s $JUMPBOX_USER@$JUMPBOX_IP:~/

    # Execute deployment on jumpbox
    print_status "Executing deployment on jumpbox..."
    sshpass -p "$JUMPBOX_PASSWORD" ssh -o StrictHostKeyChecking=no $JUMPBOX_USER@$JUMPBOX_IP << 'SSH_EOF'
        # Colors for output
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        BLUE='\033[0;34m'
        NC='\033[0m'

        print_status() {
            echo -e "${GREEN}[JUMPBOX]${NC} $1"
        }

        print_warning() {
            echo -e "${YELLOW}[JUMPBOX]${NC} $1"
        }

        # Configuration
        ACR_NAME="aksdemoacr2025"
        RESOURCE_GROUP="aks-challenge-rg"
        AKS_NAME="aks-demo"
        STORAGE_ACCOUNT="aksstatedemo2025"

        print_status "Starting deployment process on jumpbox..."

        # Install dependencies if not present
        print_status "Checking and installing dependencies..."
        if ! command -v kubectl &> /dev/null; then
            print_status "Installing kubectl..."
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            chmod +x kubectl
            sudo mv kubectl /usr/local/bin/
        fi

        if ! command -v jq &> /dev/null; then
            print_status "Installing jq..."
            sudo apt-get update && sudo apt-get install -y jq
        fi

        if ! command -v az &> /dev/null; then
            print_status "Installing Azure CLI..."
            curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
        fi

        if ! command -v kubelogin &> /dev/null; then
            print_status "Installing kubelogin..."
            # Install unzip if not present
            if ! command -v unzip &> /dev/null; then
                print_status "Installing unzip..."
                sudo apt-get update && sudo apt-get install -y unzip
            fi
            # Download and install kubelogin
            KUBELOGIN_VERSION=$(curl -s https://api.github.com/repos/Azure/kubelogin/releases/latest | jq -r '.tag_name')
            curl -LO "https://github.com/Azure/kubelogin/releases/download/${KUBELOGIN_VERSION}/kubelogin-linux-amd64.zip"
            unzip kubelogin-linux-amd64.zip
            sudo mv bin/linux_amd64/kubelogin /usr/local/bin/
            rm -rf bin kubelogin-linux-amd64.zip
        fi

        # Login to Azure
        print_status "Logging in to Azure..."
        az login --service-principal \
            --username "$ARM_CLIENT_ID" \
            --password "$ARM_CLIENT_SECRET" \
            --tenant "$ARM_TENANT_ID"

        az account set --subscription "$ARM_SUBSCRIPTION_ID"

        # Get AKS credentials
        print_status "Getting AKS credentials..."
        az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_NAME --admin --overwrite-existing

        # Get storage account key and create secret
        print_status "Creating Azure Files secret..."
        STORAGE_KEY=$(az storage account keys list --resource-group $RESOURCE_GROUP --account-name $STORAGE_ACCOUNT --query '[0].value' -o tsv)

        kubectl create secret generic azure-files-secret \
            --from-literal=azurestorageaccountname=$STORAGE_ACCOUNT \
            --from-literal=azurestorageaccountkey=$STORAGE_KEY \
            --dry-run=client -o yaml | kubectl apply -f -

        # Update deployment.yaml with correct ACR name if needed
        print_status "Updating deployment with correct ACR name..."
        cd ~/k8s
        if [ -f "deployment.yaml" ]; then
            # Replace placeholder ACR name with actual ACR name
            sed -i "s|<ACR_NAME>|$ACR_NAME|g" deployment.yaml
        fi

        # Deploy all manifests from k8s folder
        print_status "Deploying Kubernetes manifests from k8s/ folder..."
        kubectl apply -f .

        # Wait for deployment to be ready
        print_status "Waiting for deployment to be ready..."
        kubectl wait --for=condition=available --timeout=300s deployment/nginx-demo

        # Get service information
        print_status "Getting service information..."
        kubectl get pods
        kubectl get svc nginx-demo-lb

        # Get external IP
        EXTERNAL_IP=$(kubectl get svc nginx-demo-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        if [ -n "$EXTERNAL_IP" ]; then
            print_status "Application is accessible at: http://$EXTERNAL_IP"
            echo "EXTERNAL_IP=$EXTERNAL_IP" > /tmp/external_ip.txt
        else
            print_warning "External IP not yet assigned. Please check again in a few minutes:"
            print_warning "kubectl get svc nginx-demo-lb"
        fi

        print_status "Deployment completed successfully!"
SSH_EOF

    print_status "Deployment completed!"
}

# Main execution
main() {
    print_header "Starting deployment to private AKS cluster..."

    # Check prerequisites
    check_prerequisites

    # Build and push Docker image
    build_and_push_image

    # Deploy to AKS
    deploy_to_aks

    print_header "Deployment process completed!"
    print_status "Your application should now be accessible via the LoadBalancer external IP"
    print_status "Check the jumpbox output above for the external IP address"
}

# Check if Azure credentials are available
if [ -z "$ARM_CLIENT_ID" ] || [ -z "$ARM_CLIENT_SECRET" ] || [ -z "$ARM_SUBSCRIPTION_ID" ] || [ -z "$ARM_TENANT_ID" ]; then
    print_error "Azure credentials not found. Please set the following environment variables:"
    print_error "ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID"
    print_error "You can also run: az login (if using Azure CLI authentication)"
    exit 1
fi

# Run main function
main "$@"