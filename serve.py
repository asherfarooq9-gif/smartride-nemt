"""
SmartRide web server — serves Flutter web build with no-cache headers.
Run: python serve.py
"""
from http.server import HTTPServer, SimpleHTTPRequestHandler
import os

class NoCacheHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def log_message(self, fmt, *args):
        pass  # suppress per-request console spam

os.chdir(os.path.join(os.path.dirname(__file__),
                      "apps", "patient_app", "build", "web"))
print("SmartRide web app: http://localhost:8080")
HTTPServer(("", 8080), NoCacheHandler).serve_forever()
