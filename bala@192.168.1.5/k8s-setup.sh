#!/bin/bash

# K8s Setup & Auto-Startup Script
# This script sets up and starts the frame_v2 Kubernetes deployment
# Run once to initialize, then auto-starts on system restart

set -e

cd /Users/bala/frame_v2

echo "🚀 Frame V2 Kubernetes Setup"
echo "=============================="
echo ""

# Step 1: Build Docker image
echo "📦 Building Docker image..."
docker build --no-cache -t balu051989/frame_v2-web:latest .
echo "✅ Docker image built"
echo ""

# Step 2: Apply Kubernetes configurations
echo "☸️  Deploying to Kubernetes..."

# Deploy PostgreSQL
echo "   - Deploying PostgreSQL..."
kubectl apply -f k8s/postgres-statefulset.yaml
kubectl apply -f k8s/postgres-service.yaml

# Wait for PostgreSQL to be ready
echo "   - Waiting for PostgreSQL to be ready..."
kubectl rollout status statefulset/postgres --timeout=5m || true

# Deploy Frame V2
echo "   - Deploying Frame V2 application..."
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/frame-v2-service.yaml

# Wait for deployment to be ready
echo "   - Waiting for Frame V2 to be ready..."
kubectl rollout status deployment/frame-v2 --timeout=5m

echo "✅ Kubernetes deployment complete"
echo ""

# Step 3: Display connection info
echo "🌐 Connection Information:"
echo "=============================="
echo ""
echo "Local Access (localhost):"
echo "  kubectl port-forward svc/frame-v2 8080:5000"
echo "  Then visit: http://localhost:8080"
echo ""
echo "Check Pod Status:"
echo "  kubectl get pods -l app=frame-v2"
echo ""
echo "View Logs:"
echo "  kubectl logs -l app=frame-v2 -c frame-container --tail=20"
echo ""
echo "✅ Setup complete! Your app is running on Kubernetes"
