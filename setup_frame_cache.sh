  #!/usr/bin/env bash
  set -euo pipefail

  ROOT="$(cd "$(dirname "$0")" && pwd)"
  cd "$ROOT"

  echo "Applying Redis ConfigMap + PVC..."
  kubectl apply -f k8s/redis-configmap.yaml
  kubectl apply -f k8s/redis-pvc.yaml

  echo "Deploying Redis + web services..."
  kubectl apply -f k8s/redis-deployment.yaml
  kubectl apply -f k8s/redis-service.yaml
  kubectl apply -f k8s/deployment.yaml
  kubectl apply -f k8s/frame-v2-service.yaml

  echo "Rolling out fresh pods..."
  kubectl rollout restart deployment/redis
  kubectl rollout restart deployment/frame-v2

  echo "Waiting for readiness..."
  kubectl rollout status deployment/redis
  kubectl rollout status deployment/frame-v2

  echo "Sync complete. Use /cache-status or redis-cli inside the redis pod to inspect doc:* keys."
# Make it executable (chmod +x setup_frame_cache.sh) and run it on the Lenovo; it ensures Redis persistence/TLL/eviction,
#  reapplies all Kubernetes pieces, and restarts the services so the UI and cache are in sync. If you also need the Docker Compose
#stack stopped, append docker-compose down near the top before the Kubernetes commands.

