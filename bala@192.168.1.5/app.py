import psycopg2
from flask import Flask, request, jsonify, send_from_directory
import os

app = Flask(__name__)

DB_HOST = os.getenv("DB_HOST", "postgres")
DB_NAME = os.getenv("DB_NAME", "notepad")
DB_USER = os.getenv("DB_USER", "notepad")
DB_PASSWORD = os.getenv("DB_PASSWORD", "notepad")

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

@app.route("/")
def index():
    return send_from_directory("templates", "index.html")

@app.route("/list")
def list_files():
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT name FROM documents ORDER BY name")
            return jsonify([r[0] for r in cur.fetchall()])

@app.route("/open", methods=["POST"])
def open_file():
    name = request.json["name"]
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT content FROM documents WHERE name=%s", (name,))
            row = cur.fetchone()
            if row:
                return jsonify({"content": row[0]})
    return jsonify({"error": "Not found"}), 404

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
    return jsonify({"status": "deleted" if deleted else "not found"})

@app.route('/last_modified')
def last_modified():
    return 'ok', 200

if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000)
