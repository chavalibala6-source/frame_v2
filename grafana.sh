#!/bin/bash

NAMESPACE="monitoring"
RELEASE_NAME="grafana"

echo "==> Uninstalling existing Grafana (if any)..."
helm uninstall $RELEASE_NAME -n $NAMESPACE 2>/dev/null || echo "No existing Grafana release found."

echo "==> Adding Grafana Helm repo..."
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

echo "==> Installing Grafana with persistence enabled..."
helm install $RELEASE_NAME grafana/grafana \
  -n $NAMESPACE \
  --create-namespace \
  --set persistence.enabled=true \
  --set persistence.size=10Gi \
  --set persistence.storageClassName=standard \
  --set adminPassword='admin'  # optional fixed password

echo "==> Grafana installation complete!"

echo "==> Retrieving admin password..."
ADMIN_PASSWORD=$(kubectl get secret --namespace $NAMESPACE $RELEASE_NAME -o jsonpath="{.data.admin-password}" | base64 --decode)
echo "Admin username: admin"
echo "Admin password: $ADMIN_PASSWORD"

echo "==> Starting port-forward to access Grafana locally on http://localhost:3000 ..."
POD_NAME=$(kubectl get pods --namespace $NAMESPACE -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=$RELEASE_NAME" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace $NAMESPACE port-forward $POD_NAME 3000:80
