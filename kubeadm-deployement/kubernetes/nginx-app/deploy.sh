#!/bin/bash

# Quick deployment script for nginx application
# This script deploys the nginx application to your Kubernetes cluster

set -e

echo "🚀 Deploying Nginx Application to Kubernetes..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

echo "✅ Connected to Kubernetes cluster"

# Deploy the application
echo "📦 Applying Kubernetes manifests..."
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

echo "⏳ Waiting for deployment to be ready..."
kubectl rollout status deployment/nginx-deployment --timeout=5m

echo "📊 Deployment Status:"
kubectl get deployment nginx-deployment
kubectl get pods -l app=nginx

echo ""
echo "🌐 Service Information:"
kubectl get svc nginx-service

echo ""
echo "⏳ Waiting for LoadBalancer external IP (this may take 2-3 minutes)..."
echo "Run the following command to get the external IP:"
echo "  kubectl get svc nginx-service -w"

echo ""
echo "✅ Deployment complete!"
echo ""
echo "To access the application:"
echo "  1. Get the external IP: kubectl get svc nginx-service"
echo "  2. Access via browser or curl: http://<EXTERNAL-IP>"
