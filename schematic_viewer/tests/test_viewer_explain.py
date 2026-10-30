"""Tests for the viewer's Explain user interface.

* the hand-made explain fixture for sheet 051 refers only to things that exist on the real drawing;
* the static viewer files are self-contained (relative URLs, no external scripts) and parse;
* when Node and Playwright are installed, the page is driven in a real browser (tests/ui_explain.js).
"""
import gzip
import json
import os
import re
import shutil
import subprocess
import threading
from http.server import ThreadingHTTPServer

import pytest

from engine.index_builder import build_project
import viewer_server
from tests.conftest import dxf, sheet_json

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIXTURE = os.path.join(ROOT, "tests", "fixtures", "explain_051.json")
VIEWER = os.path.join(ROOT, "viewer")


def _walk(node):
    """Yield every dict node of a logic tree (nodes and leaves)."""
    if isinstance(node, dict):
        yield node
        for child in node.get("inputs") or []:
            yield from _walk(child)


@pytest.fixture(scope="module")
def fixture():
    with open(FIXTURE, encoding="utf-8") as fh:
        return json.load(fh)


@pytest.fixture(scope="module")
def project(dxf_dir, tmp_path_factory):
    out = tmp_path_factory.mktemp("proj_ui")
    files = [dxf(dxf_dir, f"10265-P3-{s}.dxf") for s in ("051", "052", "053")]
    build_project(files, str(out), progress=lambda *_: None)
    return out


def test_fixture_follows_contract(fixture):
    assert set(fixture) >= {"kind", "summary", "facts", "logic", "nets", "texts"}
    assert fixture["kind"] == "fld" and fixture["summary"] and fixture["facts"]
    for e in fixture["logic"]:
        assert set(e) >= {"output", "kind", "net", "expr", "tree", "taps", "text_ids", "shape_ids", "net_ids"}
        assert e["kind"] in ("continuation", "incoming", "converter", "dv", "annunciator", "other")
        if e["kind"] == "continuation":
            assert e["dest_sheet"] and e["link"]
        if e["kind"] == "incoming":
            assert e["from_sheet"] and e["link"]
    for w in list(fixture["nets"].values()) + list(fixture["texts"].values()):
        assert w["title"] and isinstance(w["lines"], list) and all(isinstance(l, str) for l in w["lines"])
    # plain engineering English: no em-dashes anywhere in the generated statements
    assert "—" not in json.dumps(fixture)


def test_fixture_refers_to_real_drawing(fixture, project):
    """Every id and every signal / tag / limit named in the fixture exists on the real sheet 051."""
    s = sheet_json(project, "051")
    texts = {t["id"]: t for t in s["texts"]}
    by_text = {}
    for t in s["texts"]:
        by_text.setdefault(t["text"], []).append(t)
    nets = {n["id"] for n in s["nets"]}
    shapes = {sh["id"]: sh for sh in s["shapes"]}
    links = {L["id"]: L for L in s["links"]}

    for tid in fixture["texts"]:
        assert tid in texts, tid
    for nid in fixture["nets"]:
        assert int(nid) in nets, nid
    for e in fixture["logic"]:
        assert all(t in texts for t in e["text_ids"]), (e["output"], e["text_ids"])
        assert all(n in nets for n in e["net_ids"]) and (e["net"] is None or e["net"] in nets)
        assert all(sh in shapes for sh in e["shape_ids"])
        if e.get("link"):
            L = links[e["link"]]
            assert L["dst_sheet"] == (e.get("dest_sheet") or e.get("from_sheet")) and L["status"] == e["link_status"]
            assert texts[e["pointer_text"]]["text"] == e["pointer"] and L["src_text"] == e["pointer_text"]
        if e["kind"] in ("continuation", "incoming"):
            # the box label sits in the named shape, and the pointer is written right beside it
            box = shapes[e["shape"]]
            assert texts[box["texts"][0]]["text"] == e["output"]
            assert e["net"] in box["nets"]
        for t in e["taps"]:
            assert texts[t["text"]]["text"] == t["label"]
        for n in _walk(e["tree"]):
            assert all(t in texts for t in n.get("text_ids", [])), n.get("text_ids")
            for key in ("net", "field_net"):
                if n.get(key) is not None:
                    assert n[key] in nets, (key, n[key])
            for key in ("shape", "module_shape", "field_shape"):
                if n.get(key) is not None:
                    assert n[key] in shapes, (key, n[key])
            for key in ("signal", "tag", "limit"):
                if n.get(key) and not n.get("incoming"):
                    assert n[key] in by_text, (key, n[key])
            if n.get("signal") and not n.get("incoming") and n.get("net") is not None:
                # the signal name is one of the labels attached to that wire (or written at the gate)
                owners = {t["net"] for t in by_text[n["signal"]]}
                assert n["net"] in owners or n.get("op"), (n["signal"], n["net"], owners)
            if n.get("op") and n.get("shape") is not None:
                words = {texts[t]["text"] for t in shapes[n["shape"]]["texts"]}
                head = n["op"].split()[0]
                assert head in words or any(head in w for w in words) or n["kind"] == "timer" and {"T1 OFF", "2 mins"} <= words, (n["op"], words)
            if n.get("incoming"):
                assert n["from_sheet"] == "052" and links[n["link"]]["label"] == n["signal"]
    # the 3B entry is the AND of eight inputs named in the brief
    b = next(e for e in fixture["logic"] if e["kind"] == "continuation" and e["output"] == "3B")
    assert b["tree"]["op"] == "AND" and len(b["tree"]["inputs"]) == 8
    direct = {i.get("signal"): i.get("limit") for i in b["tree"]["inputs"] if "op" not in i}
    assert direct == {"03FZA03012": None, "03PDZA03078": None, "03TZA03052A": "HIGH", "03LZA03110A": "HIGH"}
    assert sum(1 for i in b["tree"]["inputs"] if i.get("op") == "OR") == 4
    assert [t["label"] for t in b["taps"]] == ["DV3_5"]


def test_viewer_files_are_self_contained():
    html = open(os.path.join(VIEWER, "index.html"), encoding="utf-8").read()
    js = open(os.path.join(VIEWER, "app.js"), encoding="utf-8").read()
    css = open(os.path.join(VIEWER, "app.css"), encoding="utf-8").read()
    for marker in ('id="btnExplain"', 'data-tab="explain"', 'id="tab-explain"', 'id="tip"', 'id="tipMore"'):
        assert marker in html, marker
    assert re.search(r'<script src="app.js"></script>', html)
    # the page must work from any relative path: the only absolute URLs are the SVG / XLink namespace names
    for text in (html, js):
        urls = set(re.findall(r"https?://[^\"'\s)<>]+", text))
        assert all(u.startswith("http://www.w3.org/") for u in urls), urls
    for name in ("whatThisIs", "renderExplainTab", "selectLogic", "followEntry", "arriveOnPath", "loadDossier", "loadGlossary", "fetchMaybeGz", "loadJSON"):
        assert name in js, name
    assert 'DATA + "dossier.json.gz"' in js and 'DATA + "glossary.json"' in js
    assert "@import" not in css and "url(" not in css
    node = shutil.which("node")
    if node:
        subprocess.run([node, "--check", os.path.join(VIEWER, "app.js")], check=True)
        subprocess.run([node, "--check", os.path.join(ROOT, "tests", "ui_explain.js")], check=True)


def test_glossary_patterns_compile_in_javascript():
    """The viewer compiles the glossary patterns with JavaScript's RegExp (after the same two rewrites it applies)."""
    node = shutil.which("node")
    if not node:
        pytest.skip("node not installed")
    glossary = os.path.join(ROOT, "engine", "glossary.json")
    if not os.path.exists(glossary):
        pytest.skip("engine/glossary.json not present")
    script = """
      const g = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8')); let bad = 0;
      for (const e of g) { const p = String(e.pattern).replace(/\\(\\?P</g, '(?<').replace(/\\\\Z/g, '$');
        try { new RegExp(p, e.ignore_case ? 'i' : ''); } catch (err) { bad++; console.error(e.pattern, err.message); } }
      console.log(JSON.stringify({ total: g.length, bad }));
    """
    res = subprocess.run([node, "-e", script, glossary], capture_output=True, text=True, check=True)
    out = json.loads(res.stdout.strip().splitlines()[-1])
    assert out["total"] > 0 and out["bad"] == 0, res.stderr


def _playwright_available():
    node = shutil.which("node")
    if not node:
        return False
    probe = subprocess.run([node, "-e", "require('playwright'); console.log('ok')"], capture_output=True, text=True, cwd=ROOT)
    return probe.returncode == 0 and "ok" in probe.stdout


@pytest.mark.skipif(not _playwright_available(), reason="node + playwright not installed")
def test_explain_ui_in_browser(project, fixture, tmp_path):
    """Drive the page in chromium: popup, Explain sheet rows, row highlight, follow link, trail hop."""
    # inject the hand-made fixture into sheet 051 (052 and 053 keep the engine's explanation)
    p = os.path.join(str(project), "sheets", "051.json.gz")
    with gzip.open(p, "rt", encoding="utf-8") as fh:
        s = json.load(fh)
    s["explain"] = fixture
    with gzip.open(p, "wt", encoding="utf-8") as fh:
        json.dump(s, fh)

    proj_dir = str(project)

    class Handler(viewer_server.Handler):      # own subclass: no interference with other server tests
        project = viewer_server.Project(proj_dir)

    httpd = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    th = threading.Thread(target=httpd.serve_forever, daemon=True)
    th.start()
    try:
        env = dict(os.environ, VIEWER_URL=f"http://127.0.0.1:{httpd.server_address[1]}", SHOTS=str(tmp_path))
        res = subprocess.run([shutil.which("node"), os.path.join(ROOT, "tests", "ui_explain.js")], capture_output=True, text=True, env=env, cwd=ROOT, timeout=300)
    finally:
        httpd.shutdown()
    line = next((l for l in res.stdout.splitlines() if l.startswith("RESULT ")), None)
    assert line, res.stdout + res.stderr
    result = json.loads(line[len("RESULT "):])
    assert result["ok"], result["failures"]
    assert res.returncode == 0
    for name in ("tip_shown_for_tag", "what_block_from_sheet_note", "explain_rows_listed", "row_click_highlights", "outline_rendered",
                 "follow_selects_incoming_entry", "follow_adds_trail_hop", "go_back_selects_continuation", "glossary_fallback", "no_page_errors"):
        assert result["checks"][name]["ok"], (name, result["checks"][name])
    assert os.path.exists(os.path.join(str(tmp_path), "ui_explain_4_3B.png"))
