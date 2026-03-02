# Docker Build Notes

## Issue: Root Route Not Found (404 Error)

### Problem
After adding the root route `@app.route("/")` to `app.py`, the Docker container was still returning 404 when accessing `http://localhost:5001/`.

### Root Cause
**Docker layer caching**: When building Docker images, Docker caches layers to speed up builds. Even though the local `app.py` file was updated with the new root route, the `COPY app.py .` layer in the Dockerfile was using the cached version from the previous build, which didn't include the new route.

### Solution
Use `--no-cache` flag when rebuilding:
```bash
docker-compose build --no-cache
docker-compose up -d
```

Or manually rebuild the image:
```bash
docker build --no-cache -t frame-v2 .
```

### How It Works
- **Without `--no-cache`**: Docker reuses previously built layers, so old `app.py` was copied
- **With `--no-cache`**: Docker rebuilds all layers from scratch, copying the updated `app.py`

### Key Changes Made
1. Added root route to `app.py`:
   ```python
   @app.route("/")
   def index():
       return send_from_directory("templates", "index.html")
   ```

2. Changed port mapping in `docker-compose.yml`:
   - From: No direct port exposure (Nginx only)
   - To: `ports: - "5001:5000"` (direct Flask app access)

3. Removed problematic services:
   - Removed DNS service (mount path issue)
   - Removed Nginx (config file was a directory, not a file)

### Current Setup
- Flask app on port **5001** (maps to 5000 inside container)
- PostgreSQL on port **5432**
- App accessible at `http://localhost:5001`

---

## Usage Scripts

### 1. **start.sh** - Start Containers
Starts the Docker containers and displays endpoints.

```bash
./start.sh
```

**Output:**
```
✅ Containers started successfully!
🌐 App running at: http://localhost:5001

Available endpoints:
  GET  /              - Home page
  GET  /list          - List all documents
  POST /open          - Open a document
  POST /save          - Save a document
  POST /delete        - Delete a document
```

### 2. **watch-and-build.sh** - Auto-Rebuild on Changes
Monitors `app.py`, `templates/`, and `static/` for file changes. When changes are detected, it automatically rebuilds the Docker image (with `--no-cache`) and restarts containers.

**Usage:**
```bash
# Terminal 1: Start containers
./start.sh

# Terminal 2: Watch for changes (in another terminal)
./watch-and-build.sh
```

**What it does:**
- Checks for changes every 2 seconds
- Automatically rebuilds image when files change
- Restarts containers with updated code
- Shows timestamps of rebuilds

**Press Ctrl+C to stop watching.**

### 3. **Auto-Start on macOS System Restart (Optional)**

Enable auto-startup on login/restart:
```bash
launchctl load ~/Library/LaunchAgents/com.frame-v2.docker-startup.plist
```

**Check status:**
```bash
launchctl list | grep frame-v2
```

**View logs:**
```bash
cat /tmp/frame-v2-startup.log
cat /tmp/frame-v2-startup-error.log
```

**Disable auto-startup:**
```bash
launchctl unload ~/Library/LaunchAgents/com.frame-v2.docker-startup.plist
```

---

## Quick Start Guide

### First Time Setup
```bash
cd /Users/bala/frame_v2
./start.sh
```

### Development Workflow
```bash
# Terminal 1: Keep containers running
./start.sh

# Terminal 2: Auto-rebuild on code changes
./watch-and-build.sh

# Now edit app.py, templates, or static files
# Changes will auto-rebuild and restart the app!
```

### Manual Docker Commands
```bash
# View logs
docker logs frame_v2-web-1

# Stop containers
docker-compose down

# Rebuild and restart manually
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

---

## Troubleshooting

**Container won't start?**
```bash
docker logs frame_v2-web-1
```

**Port 5001 already in use?**
Edit `docker-compose.yml` and change:
```yaml
ports:
  - "5002:5000"  # Use 5002 instead
```

**Need to reset database?**
```bash
docker-compose down -v  # -v removes volumes/data
docker-compose up -d
```

**Auto-start not working?**
Check logs:
```bash
cat /tmp/frame-v2-startup.log
```
