#!/bin/bash
set -euo pipefail

NS="${NS:-default}"
PVC="${PVC:-frame-pvc}"
SC="${SC:-hostpath}"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <SIZE>   (e.g. 250Gi)"
  exit 1
fi

SIZE="$1"

echo "Resizing PVC ${NS}/${PVC} to ${SIZE}..."

# Ensure storage class allows expansion (best-effort)
kubectl patch storageclass "${SC}" -p '{"allowVolumeExpansion":true}' >/dev/null 2>&1 || true

# Find PV bound to this PVC (if any)
PV="$(kubectl get pvc "${PVC}" -n "${NS}" -o jsonpath='{.spec.volumeName}' 2>/dev/null || true)"

# Patch PVC request
kubectl patch pvc "${PVC}" -n "${NS}" -p "{\"spec\":{\"resources\":{\"requests\":{\"storage\":\"${SIZE}\"}}}}"

if [[ -n "${PV}" ]]; then
  # Patch PV capacity to match
  kubectl patch pv "${PV}" -p "{\"spec\":{\"capacity\":{\"storage\":\"${SIZE}\"}}}" >/dev/null 2>&1 || true

  # Rebind PV to current PVC if needed
  PVC_UID="$(kubectl get pvc "${PVC}" -n "${NS}" -o jsonpath='{.metadata.uid}')"
  kubectl patch pv "${PV}" --type=merge -p "{\"spec\":{\"claimRef\":{\"name\":\"${PVC}\",\"namespace\":\"${NS}\",\"uid\":\"${PVC_UID}\"}}}" >/dev/null 2>&1 || true
fi

echo "Waiting for PVC to be Bound..."
kubectl wait --for=condition=Bound pvc/"${PVC}" -n "${NS}" --timeout=60s || true

kubectl get pvc "${PVC}" -n "${NS}"
