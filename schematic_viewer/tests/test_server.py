import json
import os
import threading
import urllib.error
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
    import gzip
    ping, _ = get(server + "/api/ping")
    assert ping["mode"] == "server"
    pj, _ = get(server + "/data/project.json")
    assert [s["id"] for s in pj["sheets"]] == ["051", "052"]
    raw, h = get(server + "/data/sheets/051.json.gz", binary=True)
    assert h["Content-Encoding"] == "gzip" and h["Content-Type"].startswith("application/json")
    sh = json.loads(gzip.decompress(raw))
    assert sh["title"].startswith("FLD") and sh["links"]
    svg, h = get(server + "/data/sheets/051.svg.gz", binary=True)
    assert h["Content-Encoding"] == "gzip" and h["Content-Type"].startswith("image/svg")
    assert gzip.decompress(svg).startswith(b"<svg")
    html, _ = get(server + "/", binary=True)
    assert b"Schematic Cross-Reference Viewer" in html
    js, h = get(server + "/app.js", binary=True)
    assert b"fetchMaybeGz" in js
    with pytest.raises(urllib.error.HTTPError):
        get(server + "/data/../viewer_server.py", binary=True)


def test_user_links_roundtrip(server):
    def post(body):
        req = urllib.request.Request(server + "/api/user_links", data=json.dumps(body).encode(), headers={"Content-Type": "application/json"}, method="POST")
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read())
    res = post({"action": "create", "from": {"sheet": "051", "text": "t1", "label": "A"}, "to": {"sheet": "052", "text": "t2", "label": "B"}, "note": "test"})
    assert res["ok"] and any(u["action"] == "create" and u["note"] == "test" for u in res["user_links"])
    saved = json.load(open(os.path.join(viewer_server.Handler.project.path, "user_links.json")))
    assert saved and saved[-1]["to"]["sheet"] == "052"
    links, _ = get(server + "/api/user_links")
    assert links == saved
    res = post({"action": "confirm", "link_id": "051:tX"})
    res = post({"action": "confirm", "link_id": "051:tX"})           # one decision per link
    assert sum(1 for u in res["user_links"] if u.get("link_id") == "051:tX") == 1
    res = post({"action": "replace_all", "links": []})
    assert res["user_links"] == []
