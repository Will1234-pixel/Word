#!/usr/bin/env python3
"""Local web server for the schematic cross-reference viewer.

The viewer is a static web page; this server only (1) serves the page and the
project data folder and (2) stores manual link decisions in
project/user_links.json.  Without it the same page runs from any static web
host (GitHub Pages, a file server) and keeps manual links in the browser.
Standard library only, so it runs on any Windows PC with Python installed.

  python viewer_server.py --project project            (opens the browser)
  python viewer_server.py --project project --port 8765 --no-browser
"""
from __future__ import annotations

import argparse
import json
import mimetypes
import os
import sys
import threading
import time
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import unquote, urlparse

HERE = os.path.dirname(os.path.abspath(__file__))
VIEWER_DIR = os.path.join(HERE, "viewer")
mimetypes.add_type("image/svg+xml", ".svg")
mimetypes.add_type("application/javascript", ".js")


class Project:
    def __init__(self, path: str) -> None:
        self.path = os.path.abspath(path)
        self.lock = threading.Lock()
        with open(os.path.join(self.path, "project.json"), encoding="utf-8") as fh:
            self.meta = json.load(fh)
        self.user_links = self._load_user_links()

    def _load_user_links(self) -> list[dict]:
        p = os.path.join(self.path, "user_links.json")
        if os.path.exists(p):
            with open(p, encoding="utf-8") as fh:
                return json.load(fh)
        return []

    def save_user_links(self) -> None:
        p = os.path.join(self.path, "user_links.json")
        tmp = p + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(self.user_links, fh, indent=1)
        os.replace(tmp, p)


class Handler(BaseHTTPRequestHandler):
    project: Project = None  # type: ignore

    def log_message(self, fmt, *args):  # quieter console
        if os.environ.get("VIEWER_DEBUG"):
            super().log_message(fmt, *args)

    def _send(self, code: int, body: bytes, ctype: str, extra: dict | None = None) -> None:
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def _json(self, obj, code: int = 200) -> None:
        self._send(code, json.dumps(obj).encode("utf-8"), "application/json; charset=utf-8")

    def _file(self, root: str, rel: str) -> None:
        rel = os.path.normpath(unquote(rel)).replace("\\", "/").lstrip("/")
        if rel.startswith("..") or "/../" in f"/{rel}/":
            return self._send(403, b"forbidden", "text/plain")
        path = os.path.join(root, rel)
        if not os.path.isfile(path):
            return self._send(404, b"not found", "text/plain")
        with open(path, "rb") as fh:
            body = fh.read()
        extra = None
        name = path
        if path.endswith(".gz"):
            # pre-compressed data: let the browser decode it transparently
            extra = {"Content-Encoding": "gzip"}
            name = path[:-3]
        ctype = mimetypes.guess_type(name)[0] or "application/octet-stream"
        self._send(200, body, ctype, extra)

    def do_GET(self) -> None:
        p = urlparse(self.path).path
        pr = self.project
        if p in ("/", "/index.html"):
            with open(os.path.join(VIEWER_DIR, "index.html"), "rb") as fh:
                html = fh.read()
            html = html.replace(b"<head>", b"<head><script>window.VIEWER_SERVER_MODE=true</script>", 1)
            return self._send(200, html, "text/html; charset=utf-8")
        if p in ("/app.js", "/app.css"):
            return self._file(VIEWER_DIR, p[1:])
        if p.startswith("/data/"):
            return self._file(pr.path, p[len("/data/"):])
        if p == "/api/ping":
            return self._json({"ok": True, "project": pr.path, "mode": "server"})
        if p == "/api/user_links":
            return self._json(pr.user_links)
        return self._send(404, b"not found", "text/plain")

    def do_POST(self) -> None:
        p = urlparse(self.path).path
        n = int(self.headers.get("Content-Length", "0") or 0)
        try:
            body = json.loads(self.rfile.read(n) or b"{}")
        except Exception:
            return self._json({"error": "bad json"}, 400)
        pr = self.project
        if p == "/api/user_links":
            # body: {action: create|confirm|reject|delete|replace_all, ...}
            with pr.lock:
                action = body.get("action")
                if action == "delete":
                    pr.user_links = [L for L in pr.user_links if L.get("id") != body.get("id")]
                elif action == "replace_all":
                    pr.user_links = [L for L in body.get("links", []) if isinstance(L, dict)]
                else:
                    entry = {k: v for k, v in body.items() if k != "action"}
                    entry["action"] = action
                    entry["id"] = entry.get("id") or f"u{int(time.time() * 1000)}"
                    entry["created"] = time.strftime("%Y-%m-%d %H:%M:%S")
                    if entry.get("link_id"):   # one decision per automatic link
                        pr.user_links = [L for L in pr.user_links if L.get("link_id") != entry["link_id"]]
                    pr.user_links.append(entry)
                pr.save_user_links()
            return self._json({"ok": True, "user_links": pr.user_links})
        return self._send(404, b"not found", "text/plain")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--project", default="project", help="project folder created by import_drawings.py")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--no-browser", action="store_true")
    args = ap.parse_args(argv)
    if not os.path.exists(os.path.join(args.project, "project.json")):
        print(f"no project found in {args.project!r} - run import_drawings.py first")
        return 2
    Handler.project = Project(args.project)
    httpd = ThreadingHTTPServer((args.host, args.port), Handler)
    url = f"http://{args.host}:{httpd.server_address[1]}/"
    print(f"Schematic viewer running at {url}   (project: {Handler.project.path})")
    print("Press Ctrl+C to stop.")
    if not args.no_browser:
        threading.Timer(0.6, lambda: webbrowser.open(url)).start()
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
