"""
SmartRide web server — serves the Flutter web build with correct MIME types
and no-cache headers.

Run from the project root and LEAVE IT RUNNING:
    python serve.py

Then open http://localhost:8080 in Chrome.
"""
from http.server import HTTPServer, SimpleHTTPRequestHandler
import mimetypes
import os
import socket

# Flutter web needs these exact MIME types or the renderer fails silently.
mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("text/javascript", ".js")
mimetypes.add_type("application/json", ".json")
mimetypes.add_type("font/ttf", ".ttf")
mimetypes.add_type("font/otf", ".otf")
mimetypes.add_type("image/svg+xml", ".svg")


class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        # No-cache so a rebuild is always picked up on refresh.
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def log_message(self, fmt, *args):
        pass  # quiet console


class DualStackServer(HTTPServer):
    """Listen on IPv6 AND IPv4 so both localhost (::1) and 127.0.0.1 work.
    On Windows, 'localhost' resolves to ::1 first; an IPv4-only server makes
    the browser hang. This binds both."""
    address_family = socket.AF_INET6

    def server_bind(self):
        self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
        super().server_bind()


WEB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "apps", "patient_app", "build", "web")
os.chdir(WEB_DIR)
print("SmartRide web app running:  http://localhost:8080")
print("(leave this terminal open; press Ctrl+C to stop)")
DualStackServer(("::", 8080), Handler).serve_forever()
