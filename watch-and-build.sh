#!/bin/bash

# Script to watch for file changes and rebuild Docker image + restart containers
# This script monitors app.py, templates/, and static/ for changes
# If changes are detected, it rebuilds the image and restarts containers

set -e

echo "🚀 Docker Auto-Build & Restart Script"
echo "Monitoring: app.py, templates/, static/"
echo "Press Ctrl+C to stop"
echo ""

# Store initial file hashes
get_hash() {
    find app.py templates/ static/ -type f 2>/dev/null | xargs md5sum | md5sum | awk '{print $1}'
}

LAST_HASH=$(get_hash)

while true; do
    sleep 2
    CURRENT_HASH=$(get_hash)
    
    if [ "$CURRENT_HASH" != "$LAST_HASH" ]; then
        echo ""
        echo "📝 Changes detected!"
        echo "🔨 Building fresh Docker image..."
        
        docker-compose down
        docker-compose build --no-cache
        
        echo "🚀 Starting containers..."
        docker-compose up -d
        
        echo "✅ Containers restarted at $(date '+%Y-%m-%d %H:%M:%S')"
        echo "🌐 App running at: http://localhost:5001"
        echo ""
        
        LAST_HASH=$CURRENT_HASH
    fi
done
