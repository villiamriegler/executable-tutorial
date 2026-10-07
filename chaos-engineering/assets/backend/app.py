import json
from http.server import BaseHTTPRequestHandler, HTTPServer

ITEMS = [
    {"id": 1, "name": "Keyboard", "price": 49},
    {"id": 2, "name": "Mouse", "price": 19},
    {"id": 3, "name": "Monitor", "price": 199},
]


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/items":
            return self.reply(200, {"items": ITEMS})
        return self.reply(404, {"error": "not found"})

    def reply(self, code, obj):
        body = json.dumps(obj).encode() + b"\n"
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


print("listening on :8080", flush=True)
HTTPServer(("", 8080), Handler).serve_forever()
