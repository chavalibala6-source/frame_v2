#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTNAME="noteslook.lan"
CERT="$ROOT_DIR/${HOSTNAME}.pem"
KEY="$ROOT_DIR/${HOSTNAME}-key.pem"
CONF="$ROOT_DIR/nginx/local-https.conf"

if ! command -v mkcert >/dev/null 2>&1; then
  echo "mkcert not found. Installing..."
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found. Install Homebrew first."
    exit 1
  fi
  brew install mkcert
fi

mkcert -install

if [[ ! -f "$CERT" || ! -f "$KEY" ]]; then
  echo "Generating certs for $HOSTNAME..."
  mkcert "$HOSTNAME"
fi

if [[ ! -f "$CONF" ]]; then
  echo "Missing nginx config: $CONF"
  exit 1
fi

if docker ps -a --format '{{.Names}}' | grep -q '^noteslook-local-https$'; then
  docker rm -f noteslook-local-https >/dev/null
fi

docker run -d --name noteslook-local-https \
  -p 8443:443 \
  -v "$CONF":/etc/nginx/conf.d/default.conf:ro \
  -v "$CERT":/etc/nginx/ssl/${HOSTNAME}.pem:ro \
  -v "$KEY":/etc/nginx/ssl/${HOSTNAME}-key.pem:ro \
  nginx:latest

echo "Local HTTPS proxy running:"
echo "  https://${HOSTNAME}:8443"
