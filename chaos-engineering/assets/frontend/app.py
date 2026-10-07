import json
import os
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer
from textwrap import indent

BACKEND = os.environ.get("BACKEND_URL", "http://backend:8080/items")

PAGE = """\
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>{title}</title>
</head>
<body>
  <h1>{title}</h1>
{content}
</body>
</html>
"""

TABLE = """\
<table border="1">
  <thead>
    <tr><th>ID</th><th>Name</th><th>Price</th></tr>
  </thead>
  <tbody>
{rows}
  </tbody>
</table>
"""

ROW = "<tr><td>{id}</td><td>{name}</td><td>{price}</td></tr>"


def fetch_items():
    with urllib.request.urlopen(BACKEND) as response:
        return json.load(response)["items"]


def render_page(title, content):
    return PAGE.format(title=title, content=indent(content.rstrip(), "  "))


def render_items(items):
    rows = "\n".join(ROW.format(**item) for item in items)
    return render_page("Products", TABLE.format(rows=indent(rows, "    ")))


def render_error(message):
    return render_page("Error", f"<p>{message}</p>")


def index():
    try:
        items = fetch_items()
    except Exception as e:
        return 502, render_error(f"Could not reach backend: {e}")
    return 200, render_items(items)


ROUTES = {
    "/": index,
}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        route = ROUTES.get(self.path)
        if route is None:
            return self.reply(404, render_error("Not found"))
        return self.reply(*route())

    def reply(self, status, html):
        body = html.encode()
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


print("listening on :8080", flush=True)
# Single-threaded: one request at a time, like one sync worker.
HTTPServer(("", 8080), Handler).serve_forever()
