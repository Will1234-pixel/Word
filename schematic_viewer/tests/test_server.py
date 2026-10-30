import json
import os
import threading
import urllib.request
from http.server import ThreadingHTTPServer

import pytest

from engine.index_builder import build_project
import viewer_server
from tests.conftest import dxf


@pytest.fixture(scope="module")
def server(dxf_dir, tmp_path_factory):
    out = tmp_path_factory.mktemp("proj")
    files = [dxf(dxf_dir, f) for f in ("10265-P3-051.dxf", "10265-P3-052.dxf")]
    build_project(files, str(out), progress=lambda *_: None)
    viewer_server.Handler.project = viewer_server.Project(str(out))
    httpd = ThreadingHTTPServer(("127.0.0.1", 0), viewer_server.Handler)
    th = threading.Thread(target=httpd.serve_forever, daemon=True)
    th.start()
    yield f"http://127.0.0.1:{httpd.server_address[1]}"
    httpd.shutdown()


def get(url, binary=False):
    with urllib.request.urlopen(url, timeout=30) as r:
        data = r.read()
        return (data if binary else json.loads(data)), r.headers


def test_endpoints(server):
    pj, _ = get(server + "/api/project")
    assert [s["id"] for s in pj["sheets"]] == ["051", "052"]
    sh, _ = get(server + "/api/sheet/051")
    assert sh["title"].startswith("FLD") and sh["links"]
    svg, h = get(server + "/api/svg/051", binary=True)
    assert h["Content-Encoding"] == "gzip" and h["Content-Type"].startswith("image/svg")
    html, _ = get(server + "/", binary=True)
    assert b"Schematic Cross-Reference Viewer" in html
    res, _ = get(server + "/api/search?q=3A")
    assert any(r["label"] == "3A" and r["sheet"] == "051" for r in res["results"])
    app, _ = get(server + "/api/appearances?sheet=051&text=" + next(t["id"] for t in sh["texts"] if t["text"] == "03FZT03002"))
    assert app["groups"] == [] or all("occurrences" in g for g in app["groups"])


def test_user_links_roundtrip(server):
    body = json.dumps({"action": "create", "from": {"sheet": "051", "text": "t1", "label": "A"}, "to": {"sheet": "052", "text": "t2", "label": "B"}, "note": "test"}).encode()
    req = urllib.request.Request(server + "/api/user_links", data=body, headers={"Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=30) as r:
        res = json.loads(r.read())
    assert res["ok"] and any(u["action"] == "create" and u["note"] == "test" for u in res["user_links"])
    saved = json.load(open(os.path.join(viewer_server.Handler.project.path, "user_links.json")))
    assert saved and saved[-1]["to"]["sheet"] == "052"
    sh, _ = get(server + "/api/sheet/051")
    assert any(u["from"]["text"] == "t1" for u in sh["user_links"])
