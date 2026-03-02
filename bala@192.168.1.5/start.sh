#!/bin/bash

# Script to start Docker containers and optionally watch for changes
# Run this at startup or manually to initialize the app

cd /Users/bala/frame_v2

echo "🚀 Starting frame_v2 Docker containers..."

# Start containers
docker-compose up -d

# Wait for services to be healthy
echo "⏳ Waiting for services to start..."
sleep 5

# Check if containers are running
if docker ps | grep -q frame_v2-web-1; then
    echo "✅ Containers started successfully!"
    echo "🌐 App running at: http://localhost:5001"
    echo ""
    echo "Available endpoints:"
    echo "  GET  /              - Home page"
    echo "  GET  /list          - List all documents"
    echo "  POST /open          - Open a document"
    echo "  POST /save          - Save a document"
    echo "  POST /delete        - Delete a document"
    echo ""
    echo "Optional: Run './watch-and-build.sh' in another terminal to auto-rebuild on changes"
else
    echo "❌ Failed to start containers"
    exit 1
fi
