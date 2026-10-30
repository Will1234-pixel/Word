#!/usr/bin/env python3
"""Local web server for the schematic cross-reference viewer.

Serves the viewer UI and the project data built by import_drawings.py, answers
search queries and stores manual link corrections.  Standard library only, so
it runs on any Windows PC with Python installed.

  python viewer_server.py --project project            (opens the browser)
  python viewer_server.py --project project --port 8765 --no-browser
"""
from __future__ import annotations

import argparse
import gzip
import json
import mimetypes
import os
import re
import sys
import threading
import time
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, unquote, urlparse

HERE = os.path.dirname(os.path.abspath(__file__))
VIEWER_DIR = os.path.join(HERE, "viewer")


class Project:
    def __init__(self, path: str) -> None:
        self.path = os.path.abspath(path)
        self.lock = threading.Lock()
        self.reload()

    def reload(self) -> None:
        with open(os.path.join(self.path, "project.json"), encoding="utf-8") as fh:
            self.meta = json.load(fh)
        with open(os.path.join(self.path, "index.json"), encoding="utf-8") as fh:
            self.index = json.load(fh)
        self.sheet_cache: dict[str, dict] = {}
        self.search_rows = None
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

    def sheet(self, sid: str) -> dict | None:
        if sid in self.sheet_cache:
            return self.sheet_cache[sid]
        p = os.path.join(self.path, "sheets", f"{sid}.json")
        if not os.path.exists(p):
            return None
        with open(p, encoding="utf-8") as fh:
            data = json.load(fh)
        self.sheet_cache[sid] = data
        return data

    def search(self, q: str, limit: int = 200) -> list[dict]:
        q = q.strip()
        if not q:
            return []
        qn = re.sub(r"\s+", "", q).upper()
        if self.search_rows is None:
            rows = []
            for meta in self.meta["sheets"]:
                sh = self.sheet(meta["id"])
                if not sh:
                    continue
                for t in sh["texts"]:
                    if t.get("frame"):
                        continue
                    keys = {i["key"] for i in t.get("idents", [])}
                    rows.append((meta["id"], t["id"], t["text"], re.sub(r"\s+", "", t["text"]).upper(), keys, t["bbox"]))
            self.search_rows = rows
        exact, prefix, partial = [], [], []
        for sid, tid, text, tn, keys, bbox in self.search_rows:
            if tn == qn or qn in keys:
                exact.append((sid, tid, text, bbox, "exact"))
            elif tn.startswith(qn) or any(k.startswith(qn) for k in keys):
                prefix.append((sid, tid, text, bbox, "prefix"))
            elif qn in tn:
                partial.append((sid, tid, text, bbox, "contains"))
        out = []
        for sid, tid, text, bbox, how in exact + prefix + partial:
            out.append({"sheet": sid, "text": tid, "label": text, "bbox": bbox, "match": how})
            if len(out) >= limit:
                break
        return out

    def appearances(self, sid: str, tid: str) -> dict:
        """Other places where the identifiers of a text appear (never asserted as a connection)."""
        sh = self.sheet(sid)
        if not sh:
            return {"groups": []}
        t = next((x for x in sh["texts"] if x["id"] == tid), None)
        if not t:
            return {"groups": []}
        groups = []
        seen_keys = set()
        seen_occ = set()
        for ident in t.get("idents", []):
            keys = [f"{ident['kind']}:{ident['key']}"]
            if ident["kind"] == "tag" and ident.get("extra", {}).get("base"):
                keys.append(f"tagbase:{ident['extra']['base']}")
            for k in keys:
                if k in seen_keys:
                    continue
                seen_keys.add(k)
                occ = [o for o in self.index.get(k, []) if not (o["sheet"] == sid and o["text"] == tid)
                       and (o["sheet"], o["text"]) not in seen_occ]
                seen_occ.update((o["sheet"], o["text"]) for o in occ)
                if occ:
                    groups.append({"key": k, "kind": k.split(":")[0], "label": ident["key"], "occurrences": occ})
        return {"text": t, "groups": groups}


class Handler(BaseHTTPRequestHandler):
    project: Project = None  # type: ignore

    def log_message(self, fmt, *args):  # quieter console
        if os.environ.get("VIEWER_DEBUG"):
            super().log_message(fmt, *args)

    # -- helpers ---------------------------------------------------------------
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

    def _file(self, path: str) -> None:
        if not os.path.isfile(path):
            return self._send(404, b"not found", "text/plain")
        ctype = mimetypes.guess_type(path.replace(".gz", ""))[0] or "application/octet-stream"
        with open(path, "rb") as fh:
            body = fh.read()
        extra = {"Content-Encoding": "gzip"} if path.endswith(".gz") else None
        if path.endswith(".svg.gz"):
            ctype = "image/svg+xml"
        self._send(200, body, ctype, extra)

    # -- routes ------------------------------------------------------------------
    def do_GET(self) -> None:
        u = urlparse(self.path)
        p = unquote(u.path)
        qs = parse_qs(u.query)
        pr = self.project
        if p in ("/", "/index.html"):
            return self._file(os.path.join(VIEWER_DIR, "index.html"))
        if p.startswith("/static/"):
            name = os.path.normpath(p[len("/static/"):]).replace("\\", "/")
            if name.startswith(".."):
                return self._send(403, b"", "text/plain")
            return self._file(os.path.join(VIEWER_DIR, name))
        if p == "/api/project":
            return self._json({**pr.meta, "user_links": len(pr.user_links)})
        m = re.match(r"^/api/sheet/([A-Za-z0-9_.-]+)$", p)
        if m:
            sh = pr.sheet(m.group(1))
            if sh is None:
                return self._json({"error": "unknown sheet"}, 404)
            links = [L for L in pr.user_links if L.get("from", {}).get("sheet") == m.group(1) or L.get("to", {}).get("sheet") == m.group(1) or L.get("link_id", "").startswith(m.group(1) + ":")]
            return self._json({**sh, "user_links": links})
        m = re.match(r"^/api/svg/([A-Za-z0-9_.-]+)$", p)
        if m:
            base = os.path.join(pr.path, "sheets", f"{m.group(1)}.svg")
            return self._file(base + ".gz" if os.path.exists(base + ".gz") else base)
        m = re.match(r"^/api/backdrop/([A-Za-z0-9_.-]+)$", p)
        if m:
            return self._file(os.path.join(pr.path, "backdrops", f"{m.group(1)}.png"))
        if p == "/api/search":
            return self._json({"results": pr.search(qs.get("q", [""])[0])})
        if p == "/api/appearances":
            return self._json(pr.appearances(qs.get("sheet", [""])[0], qs.get("text", [""])[0]))
        if p == "/api/issues":
            with open(os.path.join(pr.path, "issues.json"), encoding="utf-8") as fh:
                return self._send(200, fh.read().encode("utf-8"), "application/json; charset=utf-8")
        if p == "/api/user_links":
            return self._json(pr.user_links)
        return self._send(404, b"not found", "text/plain")

    def do_POST(self) -> None:
        u = urlparse(self.path)
        p = unquote(u.path)
        n = int(self.headers.get("Content-Length", "0") or 0)
        try:
            body = json.loads(self.rfile.read(n) or b"{}")
        except Exception:
            return self._json({"error": "bad json"}, 400)
        pr = self.project
        if p == "/api/user_links":
            # body: {action: create|confirm|reject|delete, ...}
            with pr.lock:
                action = body.get("action")
                if action == "delete":
                    pr.user_links = [L for L in pr.user_links if L.get("id") != body.get("id")]
                else:
                    entry = {k: v for k, v in body.items() if k != "action"}
                    entry["action"] = action
                    entry["id"] = entry.get("id") or f"u{int(time.time()*1000)}"
                    entry["created"] = time.strftime("%Y-%m-%d %H:%M:%S")
                    # one decision per auto link: replace earlier confirm/reject of the same link
                    if entry.get("link_id"):
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
