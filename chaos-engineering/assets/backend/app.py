import json
import os
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

ITEMS = [
    {"id": 1, "name": "Keyboard", "price": 49},
    {"id": 2, "name": "Mouse", "price": 19},
    {"id": 3, "name": "Monitor", "price": 199},
]


def items():
    return 200, {"items": ITEMS}


def health():
    return 200, {"status": "ok"}


ROUTES = {
    "/items": items,
    "/health": health,
}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        route = ROUTES.get(self.path)
        if route is None:
            return self.reply(404, {"error": "not found"})
        return self.reply(*route())

    def reply(self, status, obj):
        body = json.dumps(obj).encode() + b"\n"
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


# Simulated startup time; real services often need longer to load data or warm up.
delay = int(os.environ.get("STARTUP_DELAY", "0"))
print(f"starting, listening in {delay}s", flush=True)
time.sleep(delay)
print("listening on :8080", flush=True)
HTTPServer(("", 8080), Handler).serve_forever()
