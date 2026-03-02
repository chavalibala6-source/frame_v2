# Frame - Containerized Secure Notepad App

Frame is a lightweight Flask-based notepad application designed for modern containerized deployment. It features persistent storage, multi-instance horizontal scaling via Kubernetes, and local network security with SSL encryption and custom DNS.

## 🚀 Deployment Options

### Prerequisites
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed.
- (Recommended) MacBook `hosts` file updated:
  ```bash
  echo "127.0.0.1 frame.com" | sudo tee -a /etc/hosts
  ```

---

### 🐳 Option 1: Docker Compose (Web + DNS + SSL)
The standard setup with a secure Nginx reverse proxy and local DNS server.

1.  **Build and Start**:
    ```bash
    docker-compose up -d --build
    ```
2.  **Access**:
    - **Local**: [https://frame.com](https://frame.com)
    - **Note**: Click "Advanced" -> "Proceed" to bypass the self-signed certificate warning.

---

### ☸️ Option 2: Kubernetes (Scaling & Reliability)
Run 3 instances of the app with automated resource management and persistent storage.

1.  **Preparation**: Enable Kubernetes in Docker Desktop Settings.
2.  **Deploy**:
    ```bash
    docker build -t frame-app:latest .
    kubectl apply -f k8s/
    ```
3.  **Monitor**:
    ```bash
    kubectl get pods -l app=frame
    ```

### ⚡ Redis Cache (optional but recommended)
Redis is now used to cache document lists and repeated reads. To deploy it:
1.  Apply the new manifests:
    ```bash
    kubectl apply -f k8s/redis-configmap.yaml
    kubectl apply -f k8s/redis-pvc.yaml
    kubectl apply -f k8s/redis-deployment.yaml
    kubectl apply -f k8s/redis-service.yaml
    ```
2.  The Flask app defaults to `REDIS_HOST=redis`, so no additional configuration is required once the service exists. For Docker Compose, the `web` service already points to the `redis` container.
3.  TTL is now set to `3600` seconds (1 hour) by default; override `REDIS_TTL` in your env/manifests if you want shorter or longer-lived entries.
4.  Persistence is enabled via `redis/redis.conf` (append-only + RDB saves) and the Compose/cluster deployments mount `./redis-data` or a PVC so cached keys survive restarts.

---

## 🌐 Network & Security

### Local DNS (`frame.com`)
The project includes a `dnsmasq` server. To access `frame.com` from other devices on your Wi-Fi:
1.  On your phone/tablet, set the **DNS Server** to your Mac's IP (e.g., `192.168.1.200`).
2.  Browse to **[https://notes.com](https://notes.com)**.

### SSL/HTTPS
The stack uses **Nginx** to handle secure connections.
- **Redirects**: Any attempt to use `http://` will automatically redirect to `https://`.
- **Certs**: Self-signed certificates are stored in `./nginx/ssl/`.

---

## 📁 Project Structure

- `app.py`: Core Flask application.
- `nginx/`: SSL certificates and proxy configuration.
- `dns/`: Local DNS server settings.
- `k8s/`: Kubernetes Deployment, Service, and PVC manifests.
- `files/`: Persistent storage for your notes.

---

## 🛠 Troubleshooting

- **Port 80/443 Conflict**: Ensure no other web servers (like Apache) are running on your Mac.
- **DNS Issues**: Run `docker-compose logs dns` to check the resolution logs.
- **K8s Storage**: If pods won't start, verify that the `frame-pvc` is correctly bound.



Walkthrough - UI Separation & Edge-to-Edge Support
I have restructured the application's interface to separate functional controls and enable a truly "edge-to-edge" content interaction.

UI Improvements
1. Split Functional Toolbars
The monolithic toolbar has been divided into three logical sections to improve focus and accessibility:

Global Bar (Top):

File Operations (Open, Save, Download, Rename)
Content Search & Replace
View Controls (Theme Toggle, Background Toggle, Full Screen)
Core Text Tools (Bold, Italic, Headings, Alignment, Code Block)
Interaction Bar (Bottom):

Media Tools (Insert Image, Insert Video)
Content Structure (Lists, Collapsible Sections, Horizontal Rule)
Advanced View Tools (Markdown Mode, Source View, Render)
2. Edge-to-Edge "Floating" Design
To allow you to drag videos or position content at the absolute edges of your screen:

The bar containers are now fully transparent to touch/mouse events at the background level.
Controls are contained in "Floating Pill" toolbars that only block interaction where buttons exist.
You can now drag content behind the toolbar areas without it being blocked by a fixed header or footer background.
3. Accessible Theme Toggle
The Theme Toggle (Sun/Moon icon) is now permanently located in the Top Global Bar, ensuring it's always accessible regardless of your scroll position or view mode.

4. Strict SSL in Kubernetes
I have enforced strict SSL across the entire Kubernetes deployment:

Nginx Sidecars: Each pod now runs an Nginx "sidecar" container that handles SSL termination.
Redirection: HTTP requests (Port 80) are automatically redirected to HTTPS (Port 443).
Centralized Certificates: Managed via Kubernetes TLS Secrets and mounted as read-only for maximum security.
5. SQLite Database Migration
The backend has been migrated from individual text files to a centralized SQLite database:

Improved Performance: Database-level locking allows for better concurrent access in multi-instance environments.
Persistence: The database (notepad.db) is stored on the persistent volume (/app/data).
Auto-Migration: On the first run, the app automatically scanned for any existing 
.txt
 files and imported them into the database to ensure no data was lost.
How to Test
Save a Note: Create or edit a note and verify it saves correctly.
Persistence Test: Restart the pods or containers and verify your notes are still there.
Check HTTPS: Open https://frame.com.
Switch Views: Use the "Background Toggle" to transition between the Framed view and the Edge-to-Edge focus mode.
Toggle Theme: Use the Sun icon in the top right to switch between Light and Dark modes.
Technical Details
CSS: Implemented pointer-events: none on .app-header and .app-bottom-bar, with pointer-events: auto on .toolbar.
HTML: Restructured 
index.html
 to separate controls into functional groups.
JS: Ensured all existing editor functions (YouTube embeds, image handling) remain fully functional with the new layout.
