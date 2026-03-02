#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONF="$ROOT_DIR/nginx/local-https.conf"
CERT="$ROOT_DIR/noteslook.lan.pem"
KEY="$ROOT_DIR/noteslook.lan-key.pem"

if [[ ! -f "$CONF" ]]; then
  echo "Missing nginx config: $CONF"
  exit 1
fi

if [[ ! -f "$CERT" || ! -f "$KEY" ]]; then
  echo "Missing certs. Run:"
  echo "  mkcert noteslook.lan"
  exit 1
fi

if docker ps -a --format '{{.Names}}' | grep -q '^noteslook-local-https$'; then
  docker rm -f noteslook-local-https >/dev/null
fi

docker run -d --name noteslook-local-https \
  -p 8443:443 \
  -v "$CONF":/etc/nginx/conf.d/default.conf:ro \
  -v "$CERT":/etc/nginx/ssl/noteslook.lan.pem:ro \
  -v "$KEY":/etc/nginx/ssl/noteslook.lan-key.pem:ro \
  nginx:latest

echo "Local HTTPS proxy running:"
echo "  https://noteslook.lan:8443"
