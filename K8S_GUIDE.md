# Kubernetes Deployment Guide

## Quick Start

### First Time Setup
```bash
cd /Users/bala/frame_v2
./k8s-setup.sh
```

This will:
- Build the Docker image
- Deploy PostgreSQL to Kubernetes
- Deploy Frame V2 with 4 replicas
- Display connection info

### Access Your App (Local)

**Option 1: Port Forward (Recommended for local testing)**
```bash
kubectl port-forward svc/frame-v2 8080:5000
# Visit: http://localhost:8080
```

**Option 2: View Pod Logs**
```bash
kubectl logs -l app=frame-v2 -c frame-container --tail=20
```

**Option 3: Check Pod Status**
```bash
kubectl get pods -l app=frame-v2
kubectl get svc frame-v2
```

---

## Auto-Startup Configuration

### Enable Auto-Start on System Restart
```bash
launchctl load ~/Library/LaunchAgents/com.frame-v2.k8s-startup.plist
```

### Disable Auto-Start
```bash
launchctl unload ~/Library/LaunchAgents/com.frame-v2.k8s-startup.plist
```

### Check Status
```bash
launchctl list | grep frame-v2
```

### View Startup Logs
```bash
cat /tmp/frame-v2-k8s-startup.log
cat /tmp/frame-v2-k8s-startup-error.log
```

---

## For Other Macs

To deploy on another Mac with Kubernetes:

1. **Clone/Copy the project:**
   ```bash
   git clone <your-repo> /Users/username/frame_v2
   cd /Users/username/frame_v2
   ```

2. **Update paths in scripts:**
   ```bash
   # Edit k8s-setup.sh and k8s-start.sh
   # Change /Users/bala/frame_v2 to /Users/username/frame_v2
   ```

3. **Update launchd plist:**
   ```bash
   # Edit ~/Library/LaunchAgents/com.frame-v2.k8s-startup.plist
   # Change /Users/bala to /Users/username
   ```

4. **Run setup:**
   ```bash
   ./k8s-setup.sh
   ```

---

## Scripts Overview

### `k8s-setup.sh`
- Builds fresh Docker image
- Deploys all Kubernetes resources
- Waits for services to be ready
- Shows connection info
- **Run once initially, then optionally on updates**

### `k8s-start.sh`
- Applies K8s configs without building
- Restarts pods to ensure fresh state
- Logs startup status
- **Auto-runs on system restart via launchd**

---

## Development Workflow

### Make Changes to App
```bash
# Edit app.py, templates/, or static/
vim app.py
```

### Rebuild and Redeploy
```bash
# Rebuild image and redeploy
./k8s-setup.sh

# Or just restart without rebuilding
kubectl rollout restart deployment/frame-v2
```

### View Real-Time Logs
```bash
kubectl logs -f -l app=frame-v2 -c frame-container
```

---

## Exposing to Network (Optional)

If you want to access from other machines on your network, modify `k8s/frame-v2-service.yaml`:

```yaml
spec:
  type: LoadBalancer  # Instead of ClusterIP
  # Or use NodePort with a port like 30080
```

Then access with your machine's IP:
```bash
# Get your IP
ipconfig getifaddr en0

# Access from other machines
http://YOUR_IP:30080
```

---

## Troubleshooting

**Pods stuck in CrashLoopBackOff?**
```bash
kubectl logs -l app=frame-v2 -c frame-container
```

**PostgreSQL not connecting?**
```bash
kubectl logs -l app=postgres
kubectl get svc postgres
```

**Need to reset everything?**
```bash
kubectl delete deployment frame-v2
kubectl delete statefulset postgres
kubectl delete svc frame-v2 postgres
./k8s-setup.sh
```

**Check all resources:**
```bash
kubectl get all
```
