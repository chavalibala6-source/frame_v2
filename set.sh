#!/bin/bash
set -e

NAMESPACE="monitoring"

echo "⏳ Ensuring namespace exists..."
kubectl get ns $NAMESPACE >/dev/null 2>&1 || kubectl create ns $NAMESPACE
echo "✅ Namespace '$NAMESPACE' exists."

# -----------------------------
# Step 1: Grafana PVC
# -----------------------------
echo "⏳ Applying PersistentVolumeClaim for Grafana..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-pvc
  namespace: $NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
EOF

echo "⏳ Waiting for PVC to be bound..."
kubectl wait --for=condition=Bound pvc/grafana-pvc -n $NAMESPACE --timeout=60s
echo "✅ PVC is Bound."

# -----------------------------
# Step 2: Install Grafana
# -----------------------------
echo "⏳ Installing Grafana with Helm..."
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1
helm repo update >/dev/null 2>&1

helm upgrade --install grafana grafana/grafana \
  --namespace $NAMESPACE \
  --set persistence.enabled=true \
  --set persistence.existingClaim=grafana-pvc \
  --set adminPassword='admin' \
  --set service.type=ClusterIP \
  --wait

echo "✅ Grafana installed."
echo "ℹ️ Grafana admin user: admin, password: admin"

# -----------------------------
# Step 3: Clean old Loki objects
# -----------------------------
echo "⏳ Cleaning up old Loki/Promtail resources..."
kubectl delete clusterrole loki-promtail --ignore-not-found
kubectl delete clusterrolebinding loki-promtail --ignore-not-found
kubectl delete pvc -l app.kubernetes.io/instance=loki -n $NAMESPACE --ignore-not-found

# -----------------------------
# Step 4: Install Loki + Promtail
# -----------------------------
echo "⏳ Installing Loki + Promtail..."
helm upgrade --install loki grafana/loki-stack \
  --namespace $NAMESPACE \
  --set grafana.enabled=false \
  --set promtail.enabled=true \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=5Gi \
  --wait

echo "✅ Loki + Promtail installed."

# -----------------------------
# Step 5: Port forwarding Grafana
# -----------------------------
echo "⏳ Port forwarding Grafana to http://localhost:3000 ..."
kubectl port-forward svc/grafana -n $NAMESPACE 3000:80 >/dev/null 2>&1 &
echo "✅ Grafana accessible at http://localhost:3000"

# -----------------------------
# Step 6: Port forwarding Loki (optional)
# -----------------------------
echo "⏳ Port forwarding Loki to http://localhost:3100 ..."
kubectl port-forward svc/loki -n $NAMESPACE 3100:3100 >/dev/null 2>&1 &
echo "✅ Loki accessible at http://localhost:3100"

echo "🎉 Setup complete! Access Grafana at http://localhost:3000"
