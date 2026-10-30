"""Glossary, caption groups and dossier, checked against the real drawings
(HIMA-Sella C10265H/P3): FLD 051, loop drawings 075 / 099, power
distribution 035, F7133 card 043 and ELCO schedule 200."""
import json
import re

import pytest

from engine.dxf_reader import read_sheet
from engine.dossier import (GLOSSARY_PATH, build_dossier, context, describe_tag, fld_column_of, fld_columns,
                            glossary_lookup, label_groups, make_record, schedule_row, sheet_kind, tag_words)
from tests.conftest import dxf

FILES = {"051": "10265-P3-051.dxf", "075": "10265-P3-075.dxf", "035": "10265-P3-035.dxf",
         "043": "10265-P3-043.dxf", "099": "10265-P3-099.dxf", "200": "10265-P3-200.dxf"}


@pytest.fixture(scope="module")
def records(dxf_dir):
    """SheetRecord objects (as index_builder builds them) for the test sheets."""
    recs = {}
    for sid, name in FILES.items():
        sheet = read_sheet(dxf(dxf_dir, name), sid)
        rec = make_record(sheet, sheet_ids=set(FILES))
        sheet.doc = None
        recs[sid] = rec
    return recs


@pytest.fixture(scope="module")
def dossier(records):
    return build_dossier(records)


def _text(rec, text, nth=0):
    hits = [t for t in rec.data.texts if t.text == text and not t.frame]
    assert hits, text
    return hits[nth]


# ---------------------------------------------------------------------------
# glossary
# ---------------------------------------------------------------------------
def test_glossary_file_is_sound():
    entries = json.load(open(GLOSSARY_PATH, encoding="utf-8"))
    assert len(entries) >= 120
    for e in entries:
        for key in ("pattern", "term", "meaning", "source"):
            assert e.get(key), (e.get("pattern"), key)
        assert e["pattern"].startswith("^") and e["pattern"].endswith("$"), e["pattern"]   # anchored
        re.compile(e["pattern"])
        assert e.get("evidence") in ("drawing", "ISA 5.1 convention", "standard abbreviation"), e["pattern"]
        if e["evidence"] != "drawing":
            assert ("ISA 5.1 convention" in e["source"]) or ("standard abbreviation" in e["source"]), e["pattern"]
        assert "—" not in e["meaning"]        # no em-dashes


@pytest.mark.parametrize("text,expect", [
    ("1L+9", "fused circuit 1L+"),
    ("1L+", "FUSE-1"),
    ("(1L-)", "LINK-1"),
    ("AL+", "FUSE-A"),
    ("XG.21:2", "Terminal group XG.21"),
    ("K9202/1", "cooling fan K9202"),
    ("DV3_1", "No.3 plant"),
    ("DV7_2", "No.7 plant"),
    ("W12", "Annunciator window 12"),
    ("WINDOW 07", "Annunciator window 07"),
    ("3/C650", "cable C650 of the No.3 plant"),
    ("3/C655-1", "No.3 PLANT ANNUN SUPPLY"),
    ("1109:d10", "Pin d10 of the I/O card connector in position 1109"),
    ("1101/1", "card position 1101, channel 1"),
    ("1112", "cabinet 1, rack 1, card position 12"),
    ("LINK-1", "SAFECLIP link 1"),
    ("FUSE-A", "Red spot fuse A"),
    ("F3236", "16 channel"),
    ("HIMA F6217", "8 channel"),
    ("F7133", "24 V dc distribution card"),
    ("F 7126", "NG1/PS1"),
    ("H4135", "Relay amplifier"),
    ("ISOCON 6", "1-5 V in, 4-20 mA out"),
    ("VCON-TC", "thermocouple"),
    ("LOOP TYPE AI1", "TESTABLE ANALOGUE NON I.S. INPUT"),
    ("DO3", "annunciator"),
    ("TB3DI/4", "backplate"),
    ("O/R", "Override"),
    ("P/B", "Pushbutton"),
    ("K/S", "Keyswitch"),
    ("HIHI", "limit"),
    ("FASTON", "blade connector"),
    ("03FZT03002-OVR", "override"),
])
def test_glossary_lookup_explains_the_vocabulary(text, expect):
    meanings = " || ".join(e["meaning"] for e in glossary_lookup(text))
    assert expect in meanings, meanings


def test_glossary_lookup_fills_groups_and_rejects_noise():
    assert glossary_lookup("1L+9")[0]["term"] == "1L+9"
    assert glossary_lookup("XG.21:2")[0]["term"] == "XG.21"
    for noise in ("4A", "10A", "052.225", "NOTES", "ETC", "F", "GND", "AS BUILT.", "3A"):
        assert glossary_lookup(noise) == [], noise


def test_glossary_marks_conventions():
    g = [e for e in glossary_lookup("03GZS03568") if e.get("kind") == "tag_letter" and e.get("letter") == "G"]
    assert g and g[0]["evidence"] == "ISA 5.1 convention"
    non_is = glossary_lookup("NON-I.S.")
    assert non_is and non_is[0]["evidence"] == "standard abbreviation"
    f = [e for e in glossary_lookup("03FZT03002") if e.get("letter") == "F"]
    assert f and f[0]["evidence"] == "drawing" and "051" in f[0]["source"]


@pytest.mark.parametrize("tag,words", [
    ("03FZT03002", "flow transmitter (trip)"),
    ("03FZA03002", "flow alarm signal (trip)"),
    ("FZA 03002 - W01", "flow alarm signal (trip)"),
    ("03FZRT03007", "flow repeat output (trip)"),
    ("03TZA03052A", "temperature alarm signal (trip), limit A"),
    ("03FZT03002-OVR", "flow transmitter (trip), override"),
    ("03PDZT03078", "differential pressure transmitter (trip)"),
    ("03HZS03350", "hand-operated switch / contact (trip)"),
    ("03ZO03001", "output (trip)"),
])
def test_describe_tag(tag, words):
    assert describe_tag(tag) == words


def test_tag_words_plant_and_letters():
    w = tag_words("07BZS07200")
    assert w["plant"] == "07" and w["variable"] == "burner" and w["device"] == "switch / contact" and w["trip"]


# ---------------------------------------------------------------------------
# label groups and context
# ---------------------------------------------------------------------------
def test_label_groups_on_fld_051(records):
    rec = records["051"]
    groups = label_groups(rec.data)
    lines = [g["lines"] for g in groups]
    assert ["Nitric Acid", "03FZT03002", "LOOP TYPE AI1"] in lines
    assert ["3/C650", "1 & 2"] in lines
    assert ["ANALOG I/P", "F6217"] in lines
    assert ["V TO I", "ISOCON 6"] in lines
    assert ["T1 OFF", "2 mins"] in lines
    assert ["03HZS03354", "COPPER", "DISSOLVING STOP", "LOOP TYPE DI1"] in lines
    # the pushbutton caption is not glued to the lamp below it
    assert not any("CONTROL ROOM" in g and "W01" in g for g in lines)
    # two field tags never share a caption
    for g in lines:
        assert sum(1 for ln in g if re.fullmatch(r"03[A-Z]{2,4}0\d{4}[A-Z]?", ln)) <= 1, g
    tag = _text(rec, "03FZT03002")
    assert context(rec.data, tag.id) == ["Nitric Acid", "LOOP TYPE AI1"]
    assert context(rec.data, tag.id, groups) == ["Nitric Acid", "LOOP TYPE AI1"]
    lone = _text(rec, "DV3_1")
    assert context(rec.data, lone.id, groups) == []
    for g in groups:
        assert set(g) >= {"id", "text_ids", "lines", "bbox"} and len(g["text_ids"]) == len(g["lines"]) >= 2
        assert g["bbox"][0] <= g["bbox"][2] and g["bbox"][1] <= g["bbox"][3]


def test_label_groups_on_power_sheet_035(records):
    lines = [g["lines"] for g in label_groups(records["035"].data)]
    assert ["040.048", "XG.21:2"] in lines
    assert ["043.060", "1118-1121"] in lines
    assert ["FUSE-A", "10A"] in lines and ["FUSE-1", "4A"] in lines
    assert ["3/C655-1", "No.3 PLANT", "ANNUN SUPPLY"] in lines
    assert ["7/C305-1", "No.7 PLANT", "ANNUN SUPPLY"] in lines
    assert ["FAULT/SYS", "STATUS"] in lines
    # wire specifications stacked close together stay separate captions
    assert ["6.0mmSq", "TRI-RATED", "RED WIRED", "AS RING"] in lines
    assert max(len(g) for g in lines) <= 5
    assert not any("REF DRG 025" in g for g in lines)


def test_label_groups_on_loop_drawing_075(records):
    lines = [g["lines"] for g in label_groups(records["075"].data)]
    assert ["03FZT03002", "69% NITRIC ACID", "LOW FLOW"] in lines
    assert ["03PZT03079", "COPPER DISSOLVER", "3F1 HIGH PRESSURE TRIP"] in lines
    assert ["I/O", "PLUG", "Z7127"] in lines
    # two supply wires stacked on each other are a list, not a caption
    assert not any("1L-1" in g and "1L+1" in g for g in lines)


def test_rotated_schedule_cells_do_not_chain(records):
    rec = records["200"]
    groups = label_groups(rec.data)
    for g in groups:
        assert len(g["lines"]) <= 4, g["lines"]
        assert sum(1 for ln in g["lines"] if re.search(r" - W\d{2}$", ln)) <= 1, g["lines"]
    row = schedule_row(rec.data, _text(rec, "HZA 03350 - W12"))
    assert {"TERM 1", "PIN A", "RED", "ESD 1112:b2", "VARELCO BLOCK 3/C652", "No.3 PLANT ANNUNCIATOR CABINET"} <= set(row), row
    row2 = schedule_row(rec.data, _text(rec, "FZA 03002 - W01"))
    assert {"TERM 2", "PIN B", "BLUE", "ESD 1112:b4"} <= set(row2), row2
    assert "RED" not in row2


def test_fld_columns_from_headers(records):
    cols = fld_columns(records["051"].data)
    names = [c["name"] for c in cols]
    assert names == ["CABLE & TERMINALS", "FIELD", "ANNUN/CONSOLE", "O/R", "INPUT NON-I.S.", "DELTA V MODBUS", "LOGIC",
                     "DELTA V MODBUS", "OUTPUT NON-I.S.", "I.S.", "PROCESS DEVICE TAG No.", "CABLE & TERMINALS"]
    assert fld_column_of(cols, 47.0)["name"] == "FIELD"
    assert fld_column_of(cols, 71.0)["name"] == "ANNUN/CONSOLE"
    assert fld_column_of(cols, 115.0)["name"] == "INPUT NON-I.S."
    assert fld_column_of(cols, 372.0)["name"] == "PROCESS DEVICE TAG No."
    assert fld_column_of(cols, 394.0)["name"] == "CABLE & TERMINALS"


@pytest.mark.parametrize("title,kind", [
    ("FLD - No.3 PLANT COPPER DISSOLVING AREA", "fld"),
    ("LOOP DRAWING - INPUTS", "loop_in"),
    ("LOOP DRAWING - OUTPUTS", "loop_out"),
    ("TYPICAL LOOPS - INPUTS", "typical"),
    ("ELCO SCHEDULES - ESD/ANNUNCIATOR", "elco"),
    ("ANNUNCIATOR WIRING DIAGRAM - No.3 PLANT", "annunciator"),
    ("POWER DISTRIBUTION - 230Vac/24Vdc", "power"),
    ("F7133 24Vdc DISTRIBUTION CARD 1118", "card"),
    ("MAIN SCHEMATIC FOR POWER AND WATCHDOG", "main_schematic"),
    ("PLC CABINET - BACKPLATE LAYOUT", "layout"),
    ("DOCUMENT SCHEDULE - No.s 001 TO 100", "document_schedule"),
])
def test_sheet_kind(title, kind):
    assert sheet_kind(title) == kind


# ---------------------------------------------------------------------------
# dossier
# ---------------------------------------------------------------------------
def test_dossier_shape(dossier):
    assert set(k.split(":")[0] for k in dossier) >= {"tag", "tagbase", "cable", "elco", "terminal", "potential", "dv", "window", "signal", "link"}
    for key, d in dossier.items():
        assert set(d) == {"title", "lines", "entries"} and d["title"] and d["lines"] and d["entries"], key
        assert "—" not in d["title"] and all("—" not in ln for ln in d["lines"]), key
        for e in d["entries"]:
            assert set(e) >= {"sheet", "text", "label", "role", "context"}, key
            assert isinstance(e["context"], list) and e["role"]
        assert d["lines"][-1].startswith("Appears on ")


def test_dossier_field_tag_03FZT03002(dossier):
    d = dossier["tag:03FZT03002"]
    assert d["title"].startswith("03FZT03002: flow transmitter (trip), service Nitric Acid")
    assert "LOOP TYPE AI1 via cable 3/C650 cores 1 & 2" in d["title"]
    assert "HIMA F6217 position 1101 channel 1" in d["title"]
    assert "03FZT03002-OVR (override) on sheet 099: HIMA F3236 position 1110 channel 1" in d["title"]
    by_sheet = {e["sheet"]: e for e in d["entries"]}
    assert set(by_sheet) == {"051", "075", "099"}
    fld = by_sheet["051"]
    assert fld["role"] == "FLD field device"
    assert {"Nitric Acid", "LOOP TYPE AI1", "column FIELD", "same row: cable 3/C650 cores 1 & 2", "wired to box ANALOG I/P / F6217"} <= set(fld["context"])
    assert any(c.startswith("box output wire labelled 03FZA03002") and "AND" in c for c in fld["context"])
    loop = by_sheet["075"]
    assert loop["role"] == "loop drawing channel"
    assert {"69% NITRIC ACID", "LOW FLOW", "position 1101 channel 1", "wire number 1101/1", "cable 3/C650",
            "supply wires 1L+1, 1L-1", "channel pins z4 / d4", "supply pins d26 / d30"} <= set(loop["context"])
    assert any(c.startswith("module ") and c.endswith("HIMA F6217") for c in loop["context"])
    ovr = by_sheet["099"]
    assert ovr["label"] == "03FZT03002-OVR" and {"LOW FLOW OVERRIDE (KS)", "position 1110 channel 1", "wire number 1110/1"} <= set(ovr["context"])
    assert d["lines"][0] == "Tag 03FZT03002: plant 03 (No.3 plant), letters F = flow; Z = trip; T = transmitter."
    assert d["lines"][-1] == "Appears on 3 sheets: 051 (FLD), 075 (loop drawing (inputs)), 099 (loop drawing (outputs), as 03FZT03002-OVR)."
    assert dossier["tagbase:FZT03002"]["entries"] == d["entries"]


def test_dossier_logic_signal_window_and_schedule(dossier):
    sig = dossier["tagbase:FZA03002"]
    sheets = {e["sheet"]: e for e in sig["entries"]}
    assert sheets["051"]["role"] == "FLD logic signal" and "column DELTA V MODBUS" in sheets["051"]["context"]
    assert any(c.startswith("wire reaches") and "AND" in c for c in sheets["051"]["context"])
    assert sheets["200"]["role"] == "ELCO schedule row" and {"TERM 2", "PIN B", "BLUE", "ESD 1112:b4", "VARELCO BLOCK 3/C652"} <= set(sheets["200"]["context"])
    assert "RED" not in sheets["200"]["context"]
    assert "service" not in sig["title"]          # a cable colour is not a service
    win = dossier["window:W1"]
    assert win["title"] == "W01: Annunciator window 01"
    w = {e["sheet"]: e for e in win["entries"]}
    assert w["051"]["role"] == "FLD annunciator window" and "on wire with 03FZA03002" in w["051"]["context"]
    assert w["200"]["label"] == "FZA 03002 - W01"
    pin = dossier["elco:1112/b2"]
    assert pin["title"].startswith("1112:b2: Pin b2 of the I/O card connector in position 1112")
    assert "CONTROLS HZA 03350 - W12" in pin["entries"][0]["context"]


def test_dossier_cables(dossier):
    cab = dossier["cable:3/C650"]
    assert cab["title"] == "3/C650: Field cable C650 of the No.3 plant"
    rows = [e for e in cab["entries"] if e["sheet"] == "051"]
    assert len(rows) == 5 and all(e["role"] == "FLD field cable" for e in rows)
    devices = {c for e in rows for c in e["context"] if c.startswith("same row, device column")}
    assert any("03FZT03002" in c and "LOOP TYPE AI1" in c for c in devices)
    assert any("03LZT03110" in c for c in devices)
    loop = [e for e in cab["entries"] if e["sheet"] == "075"]
    assert len(loop) == 2 and {"loop of 03FZT03002", "loop of 03FZT03004"} <= {c for e in loop for c in e["context"]}
    out = dossier["tag:03ZRT03581"]["entries"][0]
    assert out["role"] == "FLD process device (output)"
    assert "same row: cable 3/C735 cores 1 & 2" in out["context"] and not any("3/C731" in c for c in out["context"])
    assert "wired to box V TO I / ISOCON 6" in out["context"]


def test_dossier_power_distribution_035(dossier):
    def ctx(key, sheet="035"):
        return [c for e in dossier[key]["entries"] if e["sheet"] == sheet for c in e["context"]]
    assert dossier["potential:1L+"]["title"] == "1L+: Fused 24 V dc positive feed number 1"
    assert any("F7133 POWER" in c and "043.060" in c for c in ctx("potential:1L+"))
    assert {e["role"] for e in dossier["potential:1L+"]["entries"]} == {"power feed", "card feed"}
    assert any("FAULT/SYS" in c for c in ctx("potential:4L+"))
    # the cable labels sit left of the terminal circles: 3/C655-1 ends 5L+, 7/C305-1 ends 6L+
    assert any("3/C655-1" in c for c in ctx("potential:5L+")) and not any("7/C305" in c for c in ctx("potential:5L+"))
    assert any("7/C305-1" in c for c in ctx("potential:6L+"))
    assert ctx("potential:3L+") == ["on a wire with no other label"]
    assert any("PLC POWER" in c and "040.048" in c for c in ctx("potential:AL+"))
    assert "FUSE-A" in dossier["potential:AL+"]["title"]
    assert ctx("link:FUSE-1") == ["4A"] and dossier["link:FUSE-1"]["entries"][0]["role"] == "power distribution fuse / link"
    assert "SAFECLIP" in dossier["link:LINK-1"]["title"]
    assert {"040.048", "pointer 040.048"} <= set(ctx("terminal:XG.21:2"))
    assert any("COOLING FANS" in c for c in ctx("terminal:K9202/1")) and "fan" in dossier["terminal:K9202/1"]["title"]


def test_dossier_card_and_loop_supply_wires(dossier):
    t = dossier["terminal:1L+1"]
    assert t["title"].startswith("1L+1: 24 V dc wire 1L+1")
    card = [e for e in t["entries"] if e["sheet"] == "043"]
    assert card and card[0]["role"] == "card output" and "1101:d30" in card[0]["context"]
    loops = [e for e in t["entries"] if e["sheet"] == "075"]
    assert len(loops) == 3 and {c for e in loops for c in e["context"] if c.startswith("loop of")} == {"loop of 03FZT03002", "loop of 03FZT03004", "loop of 03FZT03006"}
    wire = dossier["elco:1101/1"]
    assert wire["title"] == "1101/1: Wire number 1101/1 = card position 1101, channel 1"
    assert wire["entries"][0]["role"] == "loop drawing wire number"


def test_dossier_dv_and_continuation(dossier):
    dv = dossier["dv:DV3_1"]
    assert dv["title"] == "DV3_1: Delta V / Modbus reference point 1 of the No.3 plant"
    e = dv["entries"][0]
    assert e["role"] == "FLD Delta V Modbus point" and "column LOGIC" in e["context"]
    assert any(c.startswith("wire reaches") and "AND" in c and "OR" in c for c in e["context"])
    sig = dossier["signal:3A"]
    assert sig["title"] == "3A: FLD continuation signal between sheets 051"
    assert "pointer 052.225" in sig["entries"][0]["context"]
    # a limit word is a text on the same wire as its software signal (the W05 lamp taps that wire too)
    lim = dossier["tag:03TZA03052A"]["entries"][0]
    assert lim["role"] == "FLD logic signal"
    assert any(c.startswith("on wire with") and "HIGH" in c for c in lim["context"]), lim["context"]


def test_dossier_uses_only_drawing_texts(dossier, records):
    """Every context item is a drawing text, a group of drawing texts, or a
    labelled statement whose words all come from the sheet."""
    words = {sid: {t.text for t in rec.data.texts} for sid, rec in records.items()}
    prefixes = ("column ", "same row", "wire from symbol labelled ", "wired to box ", "box output wire", "on wire with ",
                "on a wire with no other label", "wire reaches ", "pointer ", "module ", "position ", "channel pins ",
                "supply pins ", "wire number ", "cable ", "supply wires ", "converter ", "loop of ", "other tags",
                "label of ", "TERM ", "PIN ", "CONTROLS ", "ESD ")
    for key, d in dossier.items():
        for e in d["entries"]:
            sheet_words = words[e["sheet"]]
            for c in e["context"]:
                if c in sheet_words:
                    continue
                assert c.startswith(prefixes), (key, c)
