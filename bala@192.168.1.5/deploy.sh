#!/bin/bash
set -e

echo "🔨 Building image..."
docker build -t frame-app:latest .

echo "🚀 Deploying to Kubernetes..."
kubectl apply -f k8s/postgres-service.yaml
kubectl apply -f k8s/postgres-statefulset.yaml

sleep 10

kubectl apply -f k8s/frame-app-deployment.yaml
kubectl apply -f k8s/frame-app-service.yaml

echo "✅ DONE"
echo "Access app at:"
echo "http://<NODE-IP>:30007"
