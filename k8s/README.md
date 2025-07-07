# Simple AKS Deployment

This folder contains a minimal nginx demo application that can be easily deployed to AKS.

## Files

- `deployment.yaml` - Main nginx application deployment
- `service.yaml` - ClusterIP service for internal communication
- `rbac.yaml` - Basic RBAC roles and bindings
- `ingress-controller.yaml` - NGINX Ingress Controller deployment
- `ingress.yaml` - Ingress resource for external access
- `deploy.sh` - Script to deploy the application
- `destroy.sh` - Script to remove the application
- `status.sh` - Script to check application status

## Quick Start

### Prerequisites

1. **Azure CLI** installed and logged in
2. **kubectl** installed
3. **AKS cluster** running
4. **Docker image** built and pushed to ACR

### Deploy

```bash
# Make scripts executable
chmod +x *.sh

# Deploy the application
./deploy.sh
```

### Check Status

```bash
# Check application status
./status.sh
```

### Destroy

```bash
# Remove the application
./destroy.sh
```

## Manual Commands

If you prefer to run commands manually:

```bash
# Deploy
kubectl apply -f rbac.yaml
kubectl apply -f service.yaml
kubectl apply -f deployment.yaml

# Check status
kubectl get pods
kubectl get svc nginx-demo-lb

# Delete
kubectl delete -f deployment.yaml
kubectl delete -f service.yaml
kubectl delete -f rbac.yaml
```

## Configuration

The deployment uses the ACR name `aksdemoacr2025.azurecr.io` from your terraform.tfvars configuration.

## What Gets Deployed

- **2 nginx pods** with resource limits
- **ClusterIP service** for internal communication
- **NGINX Ingress Controller** for external access
- **Ingress resource** for traffic routing
- **RBAC roles** for basic access control
- **External IP** for accessing the application

## Troubleshooting

- Check pod status: `kubectl get pods`
- Check service status: `kubectl get svc`
- Check events: `kubectl get events`
- Check logs: `kubectl logs <pod-name>`