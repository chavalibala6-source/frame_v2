import json
import psycopg2
from flask import Flask, request, jsonify, send_from_directory, send_file
from werkzeug.utils import secure_filename
import os
import uuid
import tempfile
import zipfile
from urllib.parse import urlparse
try:
    import redis
except ImportError:
    redis = None

app = Flask(__name__)

# Store uploads on shared volume to work across replicas
UPLOAD_DIR = os.path.join(app.root_path, "data", "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

UPLOAD_ORIGIN = os.getenv("UPLOAD_ORIGIN", "https://noteslook.shop")

DB_HOST = os.getenv("DB_HOST", "postgres")
DB_NAME = os.getenv("DB_NAME", "notepad")
DB_USER = os.getenv("DB_USER", "notepad")
DB_PASSWORD = os.getenv("DB_PASSWORD", "notepad")

def parse_host_port(raw_value, default_host, default_port):
    if not raw_value:
        return default_host, default_port
    parsed = None
    try:
        if "://" in raw_value:
            parsed = urlparse(raw_value)
            host = parsed.hostname or default_host
            port = parsed.port or default_port
        elif ":" in raw_value:
            host, port = raw_value.split(":", 1)
            port = int(port)
        else:
            host = raw_value
            port = default_port
        return host or default_host, int(port)
    except (ValueError, AttributeError):
        return default_host, default_port

REDIS_HOST, REDIS_PORT = parse_host_port(os.getenv("REDIS_HOST"), "redis", 6379)
REDIS_DB = int(os.getenv("REDIS_DB", "0"))
REDIS_TTL = int(os.getenv("REDIS_TTL", "60"))

def get_db():
    return psycopg2.connect(
        host=DB_HOST,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD
    )

def init_db():
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS documents (
                    id SERIAL PRIMARY KEY,
                    name TEXT UNIQUE NOT NULL,
                    content TEXT,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            cur.execute("""
                CREATE TABLE IF NOT EXISTS sync_state (
                    id INTEGER PRIMARY KEY CHECK (id = 1),
                    last_mod TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            cur.execute("""
                INSERT INTO sync_state (id, last_mod)
                VALUES (1, CURRENT_TIMESTAMP)
                ON CONFLICT (id) DO NOTHING
            """)
            conn.commit()

redis_client = None
if redis:
    try:
        redis_client = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=REDIS_DB, socket_connect_timeout=2)
        redis_client.ping()
    except redis.RedisError:
        redis_client = None

def cache_set(key, value, ttl=REDIS_TTL):
    if not redis_client:
        return
    try:
        redis_client.set(key, value, ex=ttl)
    except redis.RedisError:
        pass

def cache_get(key):
    if not redis_client:
        return None
    try:
        raw = redis_client.get(key)
        return raw.decode() if raw else None
    except redis.RedisError:
        return None

def invalidate_cache(key):
    if not redis_client:
        return
    try:
        redis_client.delete(key)
    except redis.RedisError:
        pass

def persist_doc_cache(name, content):
    if not redis_client or not name:
        return
    cache_set(f"doc:{name}", content)

def get_cached_doc(name):
    if not redis_client or not name:
        return None
    return cache_get(f"doc:{name}")

def invalidate_doc_cache(name):
    if not redis_client or not name:
        return
    invalidate_cache(f"doc:{name}")

def invalidate_list_cache():
    invalidate_cache("doc_list")

@app.route("/")
def index():
    return send_from_directory("templates", "index.html")

@app.route("/static/<path:filename>")
def static_files(filename):
    return send_from_directory("static", filename)

@app.route("/static/uploads/<path:filename>")
def uploaded_files(filename):
    return send_from_directory(UPLOAD_DIR, filename)

@app.after_request
def add_cors_headers(resp):
    if request.path.startswith("/upload_video") or request.path.startswith("/upload_image"):
        resp.headers["Access-Control-Allow-Origin"] = UPLOAD_ORIGIN
        resp.headers["Access-Control-Allow-Methods"] = "POST, OPTIONS"
        resp.headers["Access-Control-Allow-Headers"] = "Content-Type"
    return resp


@app.route("/list")
def list_files():
    cached = cache_get("doc_list")
    if cached:
        try:
            return jsonify(json.loads(cached))
        except json.JSONDecodeError:
            pass

    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT name FROM documents ORDER BY name")
            result = [r[0] for r in cur.fetchall()]
            cache_set("doc_list", json.dumps(result))
            return jsonify(result)

@app.route("/open", methods=["POST"])
def open_file():
    name = request.json["name"]
    cached = get_cached_doc(name)
    if cached is not None:
        return jsonify({"content": cached})
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT content FROM documents WHERE name=%s", (name,))
            row = cur.fetchone()
            if row:
                persist_doc_cache(name, row[0])
                return jsonify({"content": row[0]})
    return jsonify({"error": "Not found"}), 404


@app.route("/cache-status")
def cache_status():
    if not redis_client:
        return jsonify({"error": "redis-unavailable"}), 503

    try:
        keys = redis_client.keys("doc:*")
    except redis.RedisError:
        return jsonify({"error": "redis-error"}), 503

    result = []
    for key in keys:
        try:
            ttl = redis_client.ttl(key)
            value = redis_client.get(key)
            result.append({
                "key": key.decode(),
                "ttl": ttl,
                "length": len(value) if value else 0
            })
        except redis.RedisError:
            continue

    return jsonify(result)

@app.route("/save", methods=["POST"])
def save_file():
    data = request.json
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO documents (name, content)
                VALUES (%s, %s)
                ON CONFLICT (name)
                DO UPDATE SET content=EXCLUDED.content,
                              updated_at=CURRENT_TIMESTAMP
            """, (data["name"], data["content"]))
            cur.execute("UPDATE sync_state SET last_mod=CURRENT_TIMESTAMP WHERE id=1")
            conn.commit()
    persist_doc_cache(data["name"], data["content"])
    invalidate_list_cache()
    return jsonify({"status": "saved"})

@app.route("/delete", methods=["POST"])
def delete_file():
    name = request.json["name"]
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM documents WHERE name=%s", (name,))
            deleted = cur.rowcount
            cur.execute("UPDATE sync_state SET last_mod=CURRENT_TIMESTAMP WHERE id=1")
            conn.commit()
    invalidate_list_cache()
    invalidate_doc_cache(name)
    return jsonify({"status": "deleted" if deleted else "not found"})

@app.route('/last_modified')
def last_modified():
    return 'ok', 200

@app.route("/upload_video", methods=["POST", "OPTIONS"])
def upload_video():
    if request.method == "OPTIONS":
        return ("", 204)

    if "video" not in request.files:
        return jsonify({"error": "No video file provided"}), 400

    file = request.files["video"]
    if not file or file.filename == "":
        return jsonify({"error": "Empty filename"}), 400

    if not (file.mimetype or "").startswith("video/"):
        return jsonify({"error": "Unsupported file type"}), 400

    safe_name = secure_filename(file.filename)
    ext = os.path.splitext(safe_name)[1].lower() or ".mp4"
    unique_name = f"{uuid.uuid4().hex}{ext}"
    dest_path = os.path.join(UPLOAD_DIR, unique_name)
    file.save(dest_path)

    host = request.host
    scheme = request.headers.get("X-Forwarded-Proto", request.scheme)
    # Force :8443 for local HTTPS host when no port is present
    if host == "noteslook.lan" and scheme == "https":
        host = "noteslook.lan:8443"
    return jsonify({"url": f"{scheme}://{host}/static/uploads/{unique_name}"})

@app.route("/upload_image", methods=["POST", "OPTIONS"])
def upload_image():
    if request.method == "OPTIONS":
        return ("", 204)

    if "image" not in request.files:
        return jsonify({"error": "No image file provided"}), 400

    file = request.files["image"]
    if not file or file.filename == "":
        return jsonify({"error": "Empty filename"}), 400

    if not (file.mimetype or "").startswith("image/"):
        return jsonify({"error": "Unsupported file type"}), 400

    safe_name = secure_filename(file.filename)
    ext = os.path.splitext(safe_name)[1].lower() or ".jpg"
    unique_name = f"{uuid.uuid4().hex}{ext}"
    dest_path = os.path.join(UPLOAD_DIR, unique_name)
    file.save(dest_path)

    host = request.host
    scheme = request.headers.get("X-Forwarded-Proto", request.scheme)
    if host == "noteslook.lan" and scheme == "https":
        host = "noteslook.lan:8443"
    return jsonify({"url": f"{scheme}://{host}/static/uploads/{unique_name}"})

@app.route("/download_images", methods=["POST"])
def download_images():
    data = request.get_json(silent=True) or {}
    names = data.get("files") or []
    if not isinstance(names, list) or len(names) == 0:
        return jsonify({"error": "No files provided"}), 400

    safe_files = []
    for name in names:
        base = os.path.basename(name)
        if not base:
            continue
        path = os.path.join(UPLOAD_DIR, base)
        if os.path.isfile(path):
            safe_files.append((base, path))

    if not safe_files:
        return jsonify({"error": "No valid files found"}), 404

    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".zip")
    tmp_path = tmp.name
    tmp.close()

    with zipfile.ZipFile(tmp_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for base, path in safe_files:
            zf.write(path, arcname=base)

    return send_file(tmp_path, mimetype="application/zip", as_attachment=True, download_name="images.zip")

if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000)
