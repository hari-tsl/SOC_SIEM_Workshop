"""Deliberately vulnerable, disposable SQL injection teaching target. No real data."""
import json
import sqlite3
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

def search(query):
    with sqlite3.connect(":memory:") as db:
        db.executescript("CREATE TABLE products(id INTEGER, name TEXT); INSERT INTO products VALUES(1,'Training laptop'),(2,'Lab router');")
        # INTENTIONAL SQL injection: read-only, ephemeral, invented data.
        return db.execute("SELECT id,name FROM products WHERE name LIKE '%" + query + "%'").fetchall()

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        url = urlparse(self.path)
        status = 200
        if url.path == '/health':
            body = {'status': 'ok'}
        elif url.path == '/':
            body = {'lab': 'SOC vulnerable catalog', 'try': '/search?q=router', 'warning': 'Intentionally vulnerable training target'}
        elif url.path == '/search':
            try:
                body = {'products': search(parse_qs(url.query).get('q', [''])[0])}
            except sqlite3.Error as exc:
                status, body = 500, {'database_error': str(exc)}
        else:
            status, body = 404, {'error': 'not found'}
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

if __name__ == '__main__':
    ThreadingHTTPServer(('127.0.0.1', 8081), Handler).serve_forever()
