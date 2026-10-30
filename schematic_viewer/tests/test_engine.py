"""Tests run against the real supplied drawings (HIMA-Sella C10265H/P3)."""
import json
import os

import pytest

from engine.dxf_reader import read_sheet, sheet_id_from_filename, clean_text
from engine.identifiers import classify
from engine.nets import build_nets
from engine.svg_render import render_modelspace
from engine.index_builder import build_project
from tests.conftest import dxf


def test_sheet_id_from_filename():
    assert sheet_id_from_filename("10265-P3-051.dxf") == "051"
    assert sheet_id_from_filename("10265-P3-055B.dxf") == "055B"
    assert sheet_id_from_filename("10265-P3-002Rev AC.dxf") == "002"
    assert sheet_id_from_filename("10265-P3-136REV A.dxf") == "136"
    assert sheet_id_from_filename("10265-P3-032 REV E.dxf") == "032"
    assert sheet_id_from_filename("10265070.dxf") == "070"


def test_clean_text():
    assert clean_text("%%uNOTES") == "NOTES"
    assert clean_text("  3/C650 ") == "3/C650"


@pytest.mark.parametrize("text,kind,key", [
    ("052.225", "xref", "052.225"),
    ("3/C650", "cable", "3/C650"),
    ("03FZT03002", "tag", "03FZT03002"),
    ("FZA 03002 - W01", "tag", "FZA03002"),
    ("1109/1", "elco", "1109/1"),
    ("1109:d10", "elco", "1109/d10"),
    ("1L+1", "terminal", "1L+1"),
    ("XG.21:2", "terminal", "XG.21:2"),
    ("(1L-)", "potential", "1L-"),
    ("DV3_1", "dv", "DV3_1"),
    ("WINDOW 07", "window", "W7"),
    ("LOOP TYPE AI1", "loop_type", "AI1"),
    ("SEE DRG C10265H/P3/023", "sheet_ref", "023"),
    ("FROM SHT 055B", "sheet_ref", "055B"),
])
def test_classify(text, kind, key):
    idents = classify(text)
    assert any(i.kind == kind and i.key == key for i in idents), idents


def test_classify_rejects_noise():
    assert classify("0.5mmSq GREY") == []
    assert classify("4-20mA") == []
    assert classify("SEE NOTE 5") == []


def test_read_fld_sheet(dxf_dir):
    s = read_sheet(dxf("10265-P3-051.dxf" if False else dxf_dir, "10265-P3-051.dxf"))
    assert s.sheet_id == "051" and s.drgno == "051" and s.rev == "H"
    assert s.title.startswith("FLD - No.3 PLANT")
    assert s.ruler is not None and 0.98 < s.ruler[0] < 1.02
    texts = {t.text for t in s.texts}
    assert {"052.225", "3A", "03FZT03002", "3/C650", "DV3_1", "LOOP TYPE AI1"} <= texts
    x = next(t for t in s.texts if t.text == "052.225")
    assert 255 < x.bbox[0] < 256 and 251 < x.bbox[1] < 252   # exact font-based box


def test_frozen_layers_are_hidden(dxf_dir):
    """200-series files hold ten sheets on frozen layers: only the plotted one must be read."""
    s = read_sheet(dxf(dxf_dir, "10265-P3-201 Rev F.dxf"))
    assert s.sheet_id == "201" and s.drgno == "201"
    assert len(s.hidden_layers) >= 15
    assert all(t.layer not in s.hidden_layers for t in s.texts)


def test_hs_a3_frame_title(dxf_dir):
    s = read_sheet(dxf(dxf_dir, "10265-P3-043.dxf"))
    assert s.title == "F7133 24Vdc DISTRIBUTION CARD 1118"
    assert s.drgno == "043" and s.rev == "C"


def test_nets_connect_wire_to_continuation_box(dxf_dir):
    s = read_sheet(dxf(dxf_dir, "10265-P3-051.dxf"))
    r = build_nets(s)
    tx = {t.id: t for t in s.texts}
    box = next(sh for sh in r.shapes if [tx[i].text for i in sh["texts"]] == ["3A"])
    assert box["nets"], "the wire ending on the 3A continuation box must be attached to it"
    net = r.nets[box["nets"][0]]
    assert 1 <= len(net.segments) <= 6
    # crossing lines are not joined: no net may span the whole logic area
    assert max(len(n.segments) for n in r.nets) < 40
    # the AND gate collects the six analogue input wires, each labelled with its tag
    gate = max((sh for sh in r.shapes if [tx[i].text for i in sh["texts"]] == ["AND"]), key=lambda sh: len(sh["nets"]))
    labels = {tx[i].text for nid in gate["nets"] for i in r.nets[nid].texts}
    assert {"03FZA03007", "03FZA03008", "03FZA03010"} <= labels


def test_render_svg_in_mm(dxf_dir):
    s = read_sheet(dxf(dxf_dir, "10265-P3-051.dxf"))
    rr = render_modelspace(s.doc)
    assert rr.svg.startswith("<svg") and 'viewBox="' in rr.svg
    assert abs(rr.xmax - 408.18) < 0.5 and abs(rr.ymax - 275.18) < 0.5
    assert "e67AD" in rr.svg   # text 052.225 is rendered as an addressable group


def test_project_links_fld(dxf_dir, tmp_path):
    files = [dxf(dxf_dir, f) for f in ("10265-P3-051.dxf", "10265-P3-052.dxf", "10265-P3-053.dxf", "10265070.dxf", "10265-P3-071.dxf")]
    out = tmp_path / "proj"
    project = build_project(files, str(out), progress=lambda *_: None)
    assert project["counts"]["sheets"] == 5
    sheet = json.load(open(out / "sheets" / "051.json"))
    texts = {t["id"]: t for t in sheet["texts"]}
    xrefs = [L for L in sheet["links"] if L["kind"] == "xref"]
    assert len(xrefs) == 10
    by_label = {L["label"]: L for L in xrefs}
    # 3A 052.225 -> sheet 052, label 3A with a pointer back to 051: verified
    assert by_label["3A"]["status"] == "verified" and by_label["3A"]["dst_sheet"] == "052"
    s052 = json.load(open(out / "sheets" / "052.json"))
    t052 = {t["id"]: t for t in s052["texts"]}
    assert t052[by_label["3A"]["dst_text"]]["text"] == "3A"
    # every FLD pointer on 051 is verified except 3P, which genuinely has two boxes on 053
    assert {L["status"] for L in xrefs} <= {"verified", "multiple"}
    assert by_label["3P"]["status"] == "multiple" and len([c for c in by_label["3P"]["candidates"] if c["q"] == 0]) == 2
    # LOOP TYPE pointers go to the typical sheet heading
    typ = [L for L in sheet["links"] if L["kind"] == "typical"]
    assert typ and all(L["dst_sheet"] in ("070", "071") for L in typ)
    # incoming links are recorded on the destination
    assert any(L["from_sheet"] == "051" for L in s052["links_in"])
    # issues file lists only uncertain links
    issues = json.load(open(out / "issues.json"))
    assert all(i["status"] in ("ambiguous", "unresolved", "missing_sheet", "external", "multiple") for i in issues)


def test_project_links_power(dxf_dir, tmp_path):
    files = [dxf(dxf_dir, f) for f in ("10265-P3-035.dxf", "10265-P3-040.dxf", "10265-P3-043.dxf", "10265-P3-044.dxf")]
    out = tmp_path / "proj"
    build_project(files, str(out), progress=lambda *_: None)
    s043 = json.load(open(out / "sheets" / "043.json"))
    by = {(L["label"], L["dst_sheet"]): L for L in s043["links"] if L["kind"] == "xref"}
    # 044.260 / 1119 on card 1118 -> card 1119 sheet points back with 043.270
    assert by[("1119", "044")]["status"] == "backref"
    s035 = json.load(open(out / "sheets" / "035.json"))
    amb = [L for L in s035["links"] if L["kind"] == "xref" and L["label"] == "XG.21:2"]
    assert amb and amb[0]["status"] == "ambiguous" and len(amb[0]["candidates"]) == 2
    assert all(c["label"] == "XG.21" for c in amb[0]["candidates"])


def test_duplicate_sheet_numbers_get_distinct_ids(dxf_dir, tmp_path):
    files = [dxf(dxf_dir, f) for f in ("10265-P3-138.dxf", "10265-P3-138 Rev C.dxf")]
    out = tmp_path / "proj"
    project = build_project(files, str(out), progress=lambda *_: None)
    ids = sorted(s["id"] for s in project["sheets"])
    assert ids == ["138", "138-RevC"]
    assert os.path.exists(out / "sheets" / "138-RevC.svg.gz")


def test_pdf_only_import_with_text_layer(tmp_path):
    """A PDF with a real text layer is navigable on its own: pointer 3A 052.225 <-> 051.285 3A."""
    pymupdf = pytest.importorskip("pymupdf")
    pdf = tmp_path / "two_pages.pdf"
    doc = pymupdf.open()
    for title, label, ptr in (("051", "3A", "052.225"), ("052", "3A", "051.285")):
        page = doc.new_page(width=842, height=595)
        page.insert_text((60, 60), f"SHEET {title}", fontsize=14)
        page.insert_text((300, 300), label, fontsize=10)
        page.insert_text((330, 300), ptr, fontsize=10)
    doc.set_page_labels([{"startpage": 0, "prefix": "10265-P3-051-Model", "style": ""}, {"startpage": 1, "prefix": "10265-P3-052-Model", "style": ""}])
    doc.save(str(pdf))
    out = tmp_path / "proj"
    project = build_project([], str(out), progress=lambda *_: None, pdf_path=str(pdf))
    ids = [s["id"] for s in project["sheets"]]
    assert ids == ["051", "052"]
    assert all(s["svg"] is None and s["source"] == "pdf" and s.get("backdrop") for s in project["sheets"])
    s051 = json.load(open(out / "sheets" / "051.json"))
    xr = [L for L in s051["links"] if L["kind"] == "xref"]
    assert len(xr) == 1 and xr[0]["status"] == "verified" and xr[0]["dst_sheet"] == "052" and xr[0]["label"] == "3A"
    # word boxes are in page millimetres (y up), inside the page
    t = next(t for t in s051["texts"] if t["text"] == "052.225")
    assert 0 < t["bbox"][0] < 842 * 25.4 / 72 and 0 < t["bbox"][1] < 595 * 25.4 / 72
