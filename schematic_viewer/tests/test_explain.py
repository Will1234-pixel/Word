"""Tests for the drawing-derived explanations (engine/explain.py) against the real drawings."""
import json

import pytest

from engine.dxf_reader import read_sheet
from engine.nets import build_nets
from engine import explain
from engine.explain import classify_shape, expr_of, explain_sheet, fld_logic, net_explanations, ports, sheet_kind, sheet_summary
from tests.conftest import dxf, sheet_json


def _load(dxf_dir, name):
    s = read_sheet(dxf(dxf_dir, name))
    return s, build_nets(s)


@pytest.fixture(scope="module")
def s051(dxf_dir):
    return _load(dxf_dir, "10265-P3-051.dxf")


@pytest.fixture(scope="module")
def s052(dxf_dir):
    return _load(dxf_dir, "10265-P3-052.dxf")


@pytest.fixture(scope="module")
def s045(dxf_dir):
    return _load(dxf_dir, "10265-P3-045.dxf")


@pytest.fixture(scope="module")
def s035(dxf_dir):
    return _load(dxf_dir, "10265-P3-035.dxf")


@pytest.fixture(scope="module")
def s075(dxf_dir):
    return _load(dxf_dir, "10265-P3-075.dxf")


def _texts(sheet):
    return {t.id: t for t in sheet.texts}


# ----------------------------------------------------------------------------- pure rules
@pytest.mark.parametrize("texts,size,kind", [
    (["AND"], (14.3, 12.9), "gate"),
    (["OR"], (7.5, 5.8), "gate"),
    (["T1 OFF", "2 mins"], (11.1, 5.6), "timer"),
    (["T11 ON", "30 SECS"], (15.8, 8.0), "timer"),
    (["F6217", "ANALOG I/P"], (11.1, 5.6), "module"),
    (["DIGITAL I/P", "F3236"], (15.8, 8.0), "module"),
    (["F3330"], (8.1, 10.1), "module"),
    (["RELAY AMP", "H4135"], (15.8, 8.0), "module"),
    (["V TO I", "ISOCON 6"], (11.1, 5.6), "converter"),
    (["V TO I", "VCON-HL"], (15.8, 8.0), "converter"),
    (["03FZT03002"], (12.0, 2.0), "tag_oval"),
    (["03PDZRT03078"], (12.0, 2.0), "tag_oval"),      # five letters: not a 'tag' identifier, still an oval
    (["3A"], (2.8, 2.8), "continuation"),
    (["1109:z12"], (22.0, 5.0), "label_box"),
    ([], (22.0, 5.0), "label_box"),
    ([], (5.0, 10.0), "device"),                      # fuse body on the F7133 cards
    (["C"], (5.7, 3.8), "device"),                    # push button
    (["FLIP-FLOP"], (15.8, 8.0), "device"),
    (["FUSE", "EVALUATION", "LOGIC", "(NOTE 1)"], (30.0, 39.8), "device"),
    ([], (207.5, 101.5), "unknown"),                  # card outline
])
def test_classify_shape(texts, size, kind):
    assert classify_shape(texts, size) == kind


@pytest.mark.parametrize("title,kind", [
    ("FLD - No.3 PLANT COPPER DISSOLVING AREA", "fld"),
    ("POWER DISTRIBUTION - 230Vac/24Vdc", "power"),
    ("MAIN SCHEMATIC FOR POWER AND WATCHDOG", "power"),
    ("F7133 24Vdc DISTRIBUTION CARD 1120", "card"),
    ("LOOP DRAWING - INPUTS", "loop_input"),
    ("LOOP DRAWING - OUTPUTS", "loop_output"),
    ("TYPICAL LOOPS - INPUTS", "typical"),
    ("TYPICAL LOOP DRAWING - OUTPUTS", "typical"),
    ("ELCO SCHEDULES - ESD/ANNUNCIATOR", "elco"),
    ("ANNUNCIATOR WIRING DIAGRAM - No.3 PLANT", "annunciator"),
    ("ANNUNCIATOR LAYOUT - No.3 PLANT", "layout"),
    ("DOCUMENT SCHEDULE - No.s 001 TO 100", "schedule"),
    ("PLC CABINET - SWINGFRAME LAYOUT", "layout"),
    ("HIMA PES AND HSD PSU 1U LABEL STRIPS", "layout"),
])
def test_sheet_kind(title, kind):
    assert sheet_kind(title) == kind


def test_expr_of_tree():
    tree = {"op": "AND", "kind": "gate", "inputs": [
        {"signal": "03FZA03012"},
        {"signal": "03TZA03052A", "limit": "HIGH", "tag": "03TZT03052", "module": "ANALOG I/P F6217"},
        {"op": "OR", "kind": "gate", "inputs": [{"signal": "3A", "incoming": True, "from_sheet": "052"},
                                                  {"tag": "03HZS03350", "device": "P/B 'C'", "module": "DIGITAL I/P F3236"}]},
        {"unlabelled": True},
        {"op": "T1 OFF 2 mins", "kind": "timer", "signal": "03HZA03350", "inputs": [{"tag": "03HZS03350", "device": "P/B 'C'", "module": "DIGITAL I/P F3236"}]},
    ]}
    assert expr_of(tree) == ("AND(03FZA03012, HIGH 03TZA03052A, OR(3A (from 052), 03HZS03350 P/B 'C' [no signal name]), "
                             "<unlabelled wire>, 03HZA03350=T1 OFF 2 mins(03HZS03350 P/B 'C' [no signal name]))")
    # an output module passing a logic result on is transparent in the one-line form
    assert expr_of({"op": "F3330", "kind": "module", "signal": "03ZO03001", "inputs": [{"op": "AND", "kind": "gate", "inputs": [{"signal": "X"}]}]}) == "03ZO03001=AND(X)"


# ----------------------------------------------------------------------------- ports and labels (nets.py additions)
def test_ports_on_fld_051(s051):
    sheet, nets = s051
    tx = _texts(sheet)
    p = ports(sheet, nets)
    assert all("ports" in sh for sh in nets.shapes), "ports must be stored on the shape dicts (they are dumped as-is into the sheet JSON)"
    gates = [sh for sh in nets.shapes if [tx[i].text for i in sh["texts"]] == ["AND"]]
    big = max(gates, key=lambda sh: len(sh["ports"]))
    sides = [q["side"] for q in big["ports"]]
    assert sides.count("L") == 9 and sides.count("R") == 1      # nine wires in (one shared with the small AND), one out
    for sh in gates:
        assert [q["side"] for q in sh["ports"]].count("R") == 1, "every AND gate has exactly one output port"
    timer = next(sh for sh in nets.shapes if {tx[i].text for i in sh["texts"]} == {"T1 OFF", "2 mins"})
    assert sorted(q["side"] for q in timer["ports"]) == ["L", "R"]
    modules = [sh for sh in nets.shapes if "F6217" in {tx[i].text for i in sh["texts"]}]
    assert modules and all(any(q["side"] == "L" for q in sh["ports"]) and any(q["side"] in ("R", "T", "B") for q in sh["ports"]) for sh in modules)
    boxes = [sh for sh in nets.shapes if [tx[i].text for i in sh["texts"]] in (["3A"], ["3B"], ["3P"])]
    assert len(boxes) == 3 and all(len(sh["ports"]) == 1 for sh in boxes)
    net_ids = {n.id for n in nets.nets}
    assert all(q["net"] in net_ids for sh in nets.shapes for q in sh["ports"])
    assert p[big["id"]] == big["ports"]


def test_loose_labels_dv_and_limits(s051):
    sheet, nets = s051
    tx = _texts(sheet)
    dv = {tx[i].text for i in nets.text_net if tx[i].text.startswith("DV3_")}
    assert dv == {f"DV3_{n}" for n in range(1, 8)}, "DeltaV taps are 1.4 mm from their wire and must attach with the 3 mm rule"
    limits = sorted(tx[i].text for i in nets.text_net if tx[i].text in ("HIGH", "LOW", "LOLO", "HIHI", "MID"))
    assert limits == ["HIGH", "HIGH", "HIHI", "LOLO", "LOLO", "LOW", "LOW", "MID", "MID"]
    # the 1.2 mm rule still applies to ordinary texts: the timer output label sits 1.4 mm from its stub
    assert all(tx[i].text != "03HZA03350" for i in nets.text_net)


# ----------------------------------------------------------------------------- FLD logic
def test_fld_logic_3b_on_051(s051):
    sheet, nets = s051
    logic = fld_logic(sheet, nets, [], {"id": "051"})
    by = {(e["kind"], e["output"]): e for e in logic}
    e = by[("continuation", "3B")]
    assert e["dest_sheet"] == "052" and e["pointer"] == "052.170" and e["net"] is not None
    tree = e["tree"]
    assert tree["op"] == "AND" and len(tree["inputs"]) == 8, expr_of(tree)
    direct = {i.get("signal") for i in tree["inputs"] if "op" not in i}
    assert {"03FZA03012", "03PDZA03078", "03TZA03052A", "03LZA03110A"} <= direct
    limits = {i["signal"]: i.get("limit") for i in tree["inputs"] if "op" not in i}
    assert limits["03TZA03052A"] == "HIGH" and limits["03LZA03110A"] == "HIGH"
    ors = [i for i in tree["inputs"] if i.get("op") == "OR"]
    assert len(ors) == 4
    or_leaf_signals = [sorted(x.get("signal") or x.get("tag") or "" for x in o["inputs"] if "op" not in x) for o in ors]
    assert ["03EZS03412", "03EZS03413"] in or_leaf_signals
    assert ["03HZA03559", "03LZA03110C"] in or_leaf_signals
    incoming = [x for o in ors for x in o["inputs"] if x.get("incoming")]
    assert incoming and incoming[0]["signal"] == "3A" and incoming[0]["from_sheet"] == "052"
    assert [t["label"] for t in e["taps"]] == ["DV3_5"]
    assert "HIGH 03TZA03052A" in e["expr"] and "OR(03EZS03412, 03EZS03413)" in e["expr"] and "3A (from 052)" in e["expr"]
    # the field devices behind the leaves are named with their service captions
    leaves = explain._leaves(tree)
    tags = {l.get("tag"): l for l in leaves if l.get("tag")}
    assert tags["03FZT03002"]["desc"] == "Nitric Acid" and tags["03FZT03002"]["loop_type"] == "AI1" and tags["03FZT03002"]["module"] == "ANALOG I/P F6217"
    assert tags["03HZS03350"]["device"].startswith("P/B") and tags["03HZS03350"]["desc"] == "LOW FLOWS RESET"
    # everything referenced exists on the sheet
    tx = _texts(sheet)
    assert all(i in tx for i in e["text_ids"]) and all(0 <= s < len(nets.shapes) for s in e["shape_ids"])


def test_fld_logic_other_outputs_on_051(s051):
    sheet, nets = s051
    logic = fld_logic(sheet, nets, [], {"id": "051"})
    by = {(e["kind"], e["output"]): e for e in logic}
    # 3P: the small AND of the T1 OFF timer output (labelled 03HZA03350) and the F push button
    e = by[("continuation", "3P")]
    assert e["dest_sheet"] == "053" and e["tree"]["op"] == "AND" and len(e["tree"]["inputs"]) == 2
    assert "T1 OFF 2 mins" in e["expr"] and "03HZA03350" in e["expr"] and "03HZS03354" in e["expr"]
    assert [t["label"] for t in e["taps"]] == ["DV3_2"]
    # 3A is NOT an output of this sheet: its box feeds the OR gate, so it arrives from 052
    assert ("continuation", "3A") not in by
    inc = by[("incoming", "3A")]
    assert inc["from_sheet"] == "052" and inc["pointer"] == "052.225"
    assert any(f["kind"] == "gate" for f in inc["feeds"]) and {"3B", "DV3_1"} <= set(inc["used_in"])
    # neighbouring pointers are not mixed up: 3D -> 052, 3M -> 053, 3N -> 053
    assert by[("continuation", "3D")]["dest_sheet"] == "052"
    assert by[("continuation", "3M")]["dest_sheet"] == "053" and by[("continuation", "3N")]["dest_sheet"] == "053"
    assert by[("continuation", "3D")]["expr"] == "LOW 03TZA03052D"
    # converter: 1-5V from the flow density transmitter, 4-20mA to the process device tag
    c = by[("converter", "03ZRT03581")]
    assert c["device"]["tag"] == "03ZRT03581" and c["device"]["cable"] == "3/C735" and c["device"]["terminals"] == "1 & 2"
    assert c["signal_in"] == "1-5V" and c["signal_out"] == "4-20mA"
    assert c["tree"]["inputs"][0]["tag"] == "03QZT03581" and c["tree"]["inputs"][0]["desc"] == "Flow Density"
    assert sum(1 for e in logic if e["kind"] == "converter") == 7
    # DeltaV points: all seven on a wire, DV3_1 on the OR that takes 3A
    dvs = {e["output"]: e for e in logic if e["kind"] == "dv"}
    assert set(dvs) == {f"DV3_{n}" for n in range(1, 8)} and all(e["net"] is not None for e in dvs.values())
    assert dvs["DV3_1"]["tree"]["op"] == "OR" and "3A (from 052)" in dvs["DV3_1"]["expr"]
    assert dvs["DV3_5"]["expr"] == by[("continuation", "3B")]["expr"]
    # annunciator windows
    ann = {e["output"]: e for e in logic if e["kind"] == "annunciator"}
    assert ann["W01"]["expr"] == "03FZA03002" and ann["W12"]["expr"].startswith("03HZA03350=T1 OFF 2 mins(")
    assert len(ann) == 16


def test_incoming_entries_on_052(s052):
    sheet, nets = s052
    logic = fld_logic(sheet, nets, [], {"id": "052"})
    inc = {e["output"]: e for e in logic if e["kind"] == "incoming"}
    assert set(inc) == {"3B", "3C", "3D"}
    assert all(e["from_sheet"] == "051" for e in inc.values())
    assert inc["3B"]["pointer"] == "051.290" and any(f["kind"] == "gate" for f in inc["3B"]["feeds"])
    assert "3A" in inc["3B"]["used_in"]
    # 3A leaves this sheet: the big AND with ten inputs, two of them arriving from 051
    out = {e["output"]: e for e in logic if e["kind"] == "continuation"}
    assert out["3A"]["dest_sheet"] == "051" and out["3A"]["tree"]["op"] == "AND" and len(out["3A"]["tree"]["inputs"]) == 10
    arriving = sorted(i["signal"] for i in out["3A"]["tree"]["inputs"] if i.get("incoming"))
    assert arriving == ["3B", "3D"]
    assert [t["label"] for t in out["3A"]["taps"]] == ["DV3_8"]
    assert out["3G"]["dest_sheet"] == "053" and out["3G"]["expr"] == "LOW 03LZA03111B"
    # process device outputs through the F3330 output modules and relay amplifiers
    dev = {e["output"]: e for e in logic if e["kind"] == "other"}
    assert "03ZO03001" in dev and "T11 ON 30 SECS" in dev["03ZO03001"]["expr"] and "F3330" in dev["03ZO03001"]["via"]
    # a feedback loop is cut, not followed for ever
    assert any("loops back" in e["expr"] for e in logic)


# ----------------------------------------------------------------------------- net words, summaries, notes
def test_net_explanation_045_mentions_fuse(s045):
    sheet, nets = s045
    tx = _texts(sheet)
    words = net_explanations(sheet, nets, [], {"id": "045", "title": sheet.title})
    t = next(t for t in sheet.texts if t.text == "1L+9")
    w = words[str(nets.text_net[t.id])]
    assert w["kind"] == "potential" and w["title"] == "1L+9"
    joined = " ".join(w["lines"])
    assert "Downstream of fuse F1 (4A)" in joined and "1109:z12" in joined and "ELCO connector 1109, pin z12" in joined
    assert "card 1120" in joined
    # the 1L+ bus is the supply side of all four fuses
    bus = next(w for w in words.values() if "XG.8:1" in w["title"])
    bus_text = " ".join(bus["lines"])
    assert all(f"Supply side of fuse F{n} (4A)" in bus_text for n in (1, 2, 3, 4))
    assert "FASTON" in bus_text


def test_sheet_kinds_and_summaries(s051, s035, s045, s075):
    meta = lambda sid, sheet: {"id": sid, "title": sheet.title, "file": "", "links_in": []}
    r051 = explain_sheet(s051[0], s051[1], [], meta("051", s051[0]))
    r035 = explain_sheet(s035[0], s035[1], [], meta("035", s035[0]))
    r045 = explain_sheet(s045[0], s045[1], [], meta("045", s045[0]))
    r075 = explain_sheet(s075[0], s075[1], [], meta("075", s075[0]))
    assert (r051["kind"], r035["kind"], r045["kind"], r075["kind"]) == ("fld", "power", "card", "loop_input")
    for r in (r051, r035, r045, r075):
        assert r["warnings"] == []
        assert set(r) >= {"kind", "summary", "facts", "logic", "nets", "texts", "inputs", "outputs", "shapes"}
        json.dumps(r)                                              # serialisable
    assert "17 field inputs" in r051["summary"] and "9 continuation signals" in r051["summary"]
    assert any(f.startswith("Output 3B -> sheet 052: AND(") for f in r051["facts"])
    assert any("Signal 3A arrives from sheet 052" in f for f in r051["facts"])
    tags = [i["tag"] for i in r051["inputs"]]
    assert "03FZT03002" in tags and "03HZS03350" in tags and len(tags) == 17
    nitric = next(i for i in r051["inputs"] if i["tag"] == "03FZT03002")
    assert nitric["desc"] == "Nitric Acid" and nitric["cable"] == "3/C650" and nitric["terminals"] == "1 & 2" and nitric["signals"] == ["03FZA03002"]
    assert "3B" in nitric["outputs"] and "W01" in nitric["outputs"]
    # power sheet: red spot fuses with ratings and what they feed
    assert any(f.startswith("Fuse FUSE-A (10A)") and "AL+" in f and "PLC POWER" in f and "040.048" in f for f in r035["facts"])
    assert sum(1 for f in r035["facts"] if f.startswith("Fuse FUSE-")) == 10
    # card sheet
    assert any(f.startswith("Fuse F1 (4A)") and "1L+9" in f and "1109:z12" in f for f in r045["facts"])
    assert "card 1120" in r045["summary"].lower() or "1120" in r045["summary"]
    # loop drawing: four channels of position 1101
    ch = r075["inputs"]
    assert [c["channel"] for c in ch] == ["1", "2", "3", "4"] and all(c["position"] == "1101" and c["module"] == "HIMA F6217" for c in ch)
    assert ch[0]["tag"] == "03FZT03002" and ch[0]["wire"] == "1101/1" and ch[0]["cable"] == "3/C650" and ch[0]["desc"] == "69% NITRIC ACID LOW FLOW"
    assert set(ch[0]["pins"]) == {"z4", "d4", "d26", "d30"} and ch[0]["potentials"] == ["1L+1", "1L-1"]
    assert ch[3]["tag"] == "03PZT03079" and ch[3]["potentials"] == ["1L+2", "1L-2"]


def test_text_notes_on_051(s051):
    sheet, nets = s051
    r = explain_sheet(sheet, nets, [], {"id": "051", "title": sheet.title, "file": "", "links_in": []})
    tx = _texts(sheet)
    tag = next(t for t in sheet.texts if t.text == "03FZT03002")
    note = r["texts"][tag.id]
    body = " ".join(note["lines"])
    assert note["title"].startswith("03FZT03002") and "Nitric Acid" in body and "LOOP TYPE AI1" in body
    assert "3/C650" in body and "ANALOG I/P F6217" in body and "03FZA03002" in body and "3B" in body
    sig = next(t for t in sheet.texts if t.text == "03FZA03002")
    assert "ANALOG I/P F6217" in " ".join(r["texts"][sig.id]["lines"])
    dv = next(t for t in sheet.texts if t.text == "DV3_5")
    assert r["texts"][dv.id]["title"] == "DeltaV point DV3_5" and "3B" in r["texts"][dv.id]["lines"][0]
    ptr = next(t for t in sheet.texts if t.text == "052.225")
    assert r["texts"][ptr.id]["title"] == "3A from sheet 052"
    gate = next(t for t in sheet.texts if t.text == "OR" and 243 < t.bbox[1] < 249)       # the OR taking 3A
    assert "3A (from 052)" in " ".join(r["texts"][gate.id]["lines"])
    # every classified shape is reported
    assert len(r["shapes"]) == len(nets.shapes) and r["shapes"]["20"]["kind"] == "gate"


def test_explain_handles_sheets_without_nets(dxf_dir):
    from engine.nets import NetResult
    sheet = read_sheet(dxf(dxf_dir, "10265-P3-021.dxf"))      # swingframe layout: no wire tracing
    r = explain_sheet(sheet, build_nets(sheet), [], {"id": "021", "title": sheet.title})
    assert r["kind"] == "layout" and r["warnings"] == [] and r["logic"] == []
    r2 = explain_sheet(sheet, NetResult([], [], {}, {}, {}), None, None)
    assert r2["kind"] == "layout" and r2["nets"] == {} and r2["warnings"] == []


def test_explain_in_sheet_json(dxf_dir, tmp_path):
    """The index builder stores the explanations and the ports, with the resolved links attached."""
    from engine.index_builder import build_project
    files = [dxf(dxf_dir, f) for f in ("10265-P3-051.dxf", "10265-P3-052.dxf")]
    out = tmp_path / "proj"
    build_project(files, str(out), progress=lambda *_: None)
    s = sheet_json(out, "051")
    assert "explain" in s and s["explain"]["kind"] == "fld" and s["explain"]["warnings"] == []
    assert all("ports" in sh for sh in s["shapes"]) and any(sh["ports"] for sh in s["shapes"])
    e = next(e for e in s["explain"]["logic"] if e["kind"] == "continuation" and e["output"] == "3B")
    assert e["link"] and e["link_status"] == "verified" and e["dest_sheet"] == "052"
    assert e["link"] in {L["id"] for L in s["links"]}
    inc = next(e for e in s["explain"]["logic"] if e["kind"] == "incoming" and e["output"] == "3A")
    assert inc["link_status"] == "verified" and inc["from_sheet"] == "052"
    s2 = sheet_json(out, "052")
    inc2 = next(e for e in s2["explain"]["logic"] if e["kind"] == "incoming" and e["output"] == "3B")
    assert inc2["from_sheet"] == "051" and inc2.get("link_in")
    # net words are keyed by the net id as a string, matching the net list
    assert set(s["explain"]["nets"]) <= {str(n["id"]) for n in s["nets"]}
