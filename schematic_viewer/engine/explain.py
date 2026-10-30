"""Drawing-derived explanations for one sheet: what a wire carries, what a symbol
is, where a logic output comes from and where an arriving signal goes.

Every statement produced here is read from the text and geometry of the sheet
(plus the resolved cross-reference links of the index builder).  Nothing is
inferred about plant behaviour: when the drawing does not say, the output says
so ("unlabelled wire").

Entry point
-----------
``explain_sheet(sheet, nets, links, sheet_meta)`` returns a dict that the index
builder stores under the sheet JSON key ``explain``::

    kind      'fld' | 'loop_input' | 'loop_output' | 'power' | 'card' | 'typical' |
              'elco' | 'annunciator' | 'schedule' | 'layout' | 'other'
    summary   one short paragraph
    facts     list of short statements
    inputs    sheet inputs (FLD: field devices; loop drawings: channels)
    outputs   sheet outputs in short form [{output, kind, dest_sheet, expr}]
    logic     FLD output entries (see ``fld_logic``)
    nets      {str(net id): {title, lines, kind}}   words for a highlighted conductor
    texts     {text id: {title, lines}}             words for a clicked identifier
    shapes    {str(shape id): {kind, label, fuse?, rating?}}   classification of every closed symbol
    circles   small circles that are devices: [{cx, cy, r, label, text, kind: 'annunciator'|'lamp'|'circle', nets}]
    warnings  list of strings (a section that failed is reported here, never raised)

Logic entry kinds: 'continuation' (signal leaving to another sheet), 'incoming'
(signal arriving from another sheet: ``from_sheet``, ``feeds``, ``used_in``),
'converter' (V TO I output to a process device tag: ``device``, ``signal_in``,
``signal_out``), 'dv' (DeltaV Modbus tap), 'annunciator' (window driven by a
wire) and 'other' (``output_kind`` 'process_device': a tag oval fed through
output modules and relay amplifiers, listed in ``via``; or 'lamp').

Logic entries (``logic``) describe one output each::

    {output: '3B', kind: 'continuation' | 'incoming' | 'converter' | 'dv' |
             'annunciator' | 'other',
     dest_sheet, from_sheet, link, link_status, net, expr, tree, taps,
     text_ids, shape_ids, net_ids, ...}

``tree`` is nested: a node is ``{op, kind, shape, net, inputs: [...]}`` (gate,
timer, converter, device, module), a leaf is ``{signal, limit, tag, desc,
loop_type, module, net, text_ids}`` (a module output traced back to its field
device), ``{signal, incoming: True, from_sheet, link}`` (a signal arriving from
another sheet), ``{unlabelled: True}`` (a wire without any label or driver) or
``{cycle: True, shape}`` (feedback loop cut).  ``expr`` is the same tree in one
line: ``AND(03FZA03012, HIGH 03TZA03052A, OR(3A (from 052), <03HZS03350: unlabelled wire>), ...)``.

Port sides: a wire end touching a symbol is a port on the side the wire leaves
in ('L', 'R', 'T', 'B').  Logic flows left to right on these drawings: inputs
arrive on the left of gates, timers, modules and converters; their outputs
leave on the right (modules also leave at the top or bottom).  A tag oval in
the FIELD column drives the wire leaving its right end; a tag oval in the
PROCESS DEVICE column receives the wire arriving at its left end.
"""
from __future__ import annotations

import math
import re
from collections import defaultdict
from typing import Optional

from .dxf_reader import SheetData, TextItem
from .identifiers import LOOP_TYPE_RE, SIGNAL_RE, XREF_RE, classify
from .nets import GATE_WORDS, Net, NetResult, _Grid, _seg_box_dist, shape_ports

LIMIT_WORDS = {"HIGH", "LOW", "LOLO", "HIHI", "MID", "HI", "LO"}
LOOSE_TOL = 3.0          # mm, signal names written beside the start of their wire (03HZA03350 on 051)
NEAR_TEXT_TOL = 3.0      # mm, texts beside a device symbol (fuse name F1 and rating 4A)
MAX_DEPTH = 14
TIMER_RE = re.compile(r"^T\d{1,2}\s*(?:ON|OFF)$", re.I)
TIME_RE = re.compile(r"\b\d+(?:\.\d+)?\s*(?:MINS?|MINUTES?|SECS?|SECONDS?|HRS?|HOURS?|MS)\b", re.I)
CONVERTER_RE = re.compile(r"V\s*TO\s*I|I\s*TO\s*V|ISOCON|VCON|CONVERTER|SIGNAL\s+CONV", re.I)
MODULE_RE = re.compile(r"^(?:HIMA\s+)?[FH]\d{4}$", re.I)
MODULE_WORDS_RE = re.compile(r"\b(?:ANALOG(?:UE)?|DIGITAL)\s+(?:I/P|O/P|INPUT|OUTPUT)|RELAY\s+AMP", re.I)
FUSE_NAME_RE = re.compile(r"^(?:F\d{1,2}|FUSE[- ]?[A-Z0-9]{1,3}|LINK[- ]?[A-Z0-9]{1,3}|FUSE\s+'[A-Z]')$", re.I)
RATING_RE = re.compile(r"^\d+(?:\.\d+)?\s*(?:A|mA|V|VA|W)$")
TERMINAL_PAIR_RE = re.compile(r"^\d{1,2}\s*(?:&|,|/|-)\s*\d{1,2}$")
PIN_RE = re.compile(r"^[a-z]\d{1,2}(?:/[a-z]?\d{1,2})?$")
WINDOW_LABEL_RE = re.compile(r"^W\d{1,2}(?:\s*&\s*\d{1,2})?$", re.I)
TAG_LIKE_RE = re.compile(r"^\d{2}[A-Z]{2,5}\d{3,5}[A-Z]?(?:-[A-Z0-9]{1,4})?$")   # 03PDZRT03078 (five letters) is a tag too
LAMP_LABEL_RE = re.compile(r"^L\d{1,2}$")
OUTPUT_SIDES = {"R", "T", "B"}

__all__ = ["ports", "classify_shape", "fld_logic", "net_explanations", "sheet_summary", "explain_sheet",
           "sheet_kind", "expr_of", "loop_channels"]


# ----------------------------------------------------------------------------- geometry helpers
def _gap(a, b) -> tuple[float, float]:
    gx = max(0.0, b[0] - a[2], a[0] - b[2])
    gy = max(0.0, b[1] - a[3], a[1] - b[3])
    return gx, gy


def _center(b) -> tuple[float, float]:
    return ((b[0] + b[2]) / 2.0, (b[1] + b[3]) / 2.0)


def _overlap_x(a, b) -> float:
    return min(a[2], b[2]) - max(a[0], b[0])


def _size(b) -> tuple[float, float]:
    return (b[2] - b[0], b[3] - b[1])


def _uniq(seq):
    out, seen = [], set()
    for v in seq:
        k = repr(v)
        if k not in seen:
            seen.add(k)
            out.append(v)
    return out


# ----------------------------------------------------------------------------- public helpers
def sheet_kind(title: str) -> str:
    """Sheet category from its title (title-block text)."""
    t = (title or "").upper()
    if "FLD" in t or "FUNCTIONAL LOGIC" in t:
        return "fld"
    if "TYPICAL" in t:
        return "typical"
    if "LOOP DRAWING" in t or "LOOP" in t:
        if "OUTPUT" in t:
            return "loop_output"
        if "INPUT" in t:
            return "loop_input"
        return "other"
    if "ELCO" in t:
        return "elco"
    if re.search(r"SCHEDULE|INDEX|CONTENTS", t):
        return "schedule"
    if "WIRING" in t:
        return "annunciator" if "ANNUNCIATOR" in t else "other"
    if "DISTRIBUTION CARD" in t or re.search(r"\bF7133\b", t) or re.search(r"\bCARD\b", t):
        return "card"
    if re.search(r"LAYOUT|G\.A\.|ARRANGEMENT|DETAILS|PLAN VIEW|LABEL|PLATE|STRIP", t):
        return "layout"
    if re.search(r"POWER|PSU|SCHEMATIC|WATCHDOG|SUPPLY", t):
        return "power"
    return "other"


def classify_shape(texts, size, symbol: Optional[str] = None) -> str:
    """Kind of a closed symbol from the texts inside it and its size (w, h) in mm.

    gate | timer | module | converter | tag_oval | continuation | device | label_box | unknown
    """
    words = [str(t).strip() for t in texts if str(t).strip()]
    up = [w.upper() for w in words]
    joined = " ".join(up)
    w, h = float(size[0]), float(size[1])
    mx, mn = max(w, h), min(w, h)
    if any(u in GATE_WORDS for u in up):
        return "gate"
    if "FLIP-FLOP" in joined or "FLIP FLOP" in joined:
        return "device"
    if any(TIMER_RE.match(u) for u in up) or (TIME_RE.search(joined) and len(up) <= 3 and not MODULE_WORDS_RE.search(joined)):
        return "timer"
    if CONVERTER_RE.search(joined):
        return "converter"
    if any(MODULE_RE.match(u) for u in up) or MODULE_WORDS_RE.search(joined):
        return "module"
    if len(words) == 1:
        wd = words[0]
        idents = classify(wd)
        kinds = {i.kind for i in idents}
        if SIGNAL_RE.match(wd.upper()) and mx <= 6.0 and abs(w - h) <= 1.5:
            return "continuation"
        if ("tag" in kinds or TAG_LIKE_RE.match(wd.upper())) and mn <= 4.5 and w / max(h, 0.1) >= 3.0:
            return "tag_oval"
        if kinds & {"elco", "terminal", "potential", "connector", "cable"} and h <= 7.0 and w / max(h, 0.1) >= 2.0:
            return "label_box"
    if not words:
        if h <= 7.0 and mx >= 8.0 and w / max(h, 0.1) >= 3.0:
            return "label_box"
        if mx <= 16.0:
            return "device"
        return "unknown"
    if mx <= 60.0:
        return "device"
    return "unknown"


def expr_of(node) -> str:
    """One-line form of a logic tree."""
    if not node:
        return "<nothing drawn>"
    if node.get("cycle"):
        return f"<loops back to shape {node.get('shape')}>"
    if node.get("incoming"):
        s = node.get("signal") or "?"
        return f"{s} (from {node['from_sheet']})" if node.get("from_sheet") else f"{s} (from another sheet)"
    if "op" in node:
        inputs = node.get("inputs") or []
        inner = ", ".join(expr_of(i) for i in inputs) if inputs else "<no input drawn>"
        sig = node.get("signal")
        if node.get("kind") == "module" and len(inputs) == 1 and ("op" in inputs[0] or inputs[0].get("incoming")):
            # an output module or relay passes the logic result on: show the signal, not the module
            return f"{sig}={expr_of(inputs[0])}" if sig else expr_of(inputs[0])
        core = f"{node['op']}({inner})"
        return f"{sig}={core}" if sig else core
    parts = []
    if node.get("limit"):
        parts.append(node["limit"])
    if node.get("signal"):
        parts.append(node["signal"])
        if node.get("label") and not node.get("module"):
            parts.append(f"({node['label']})")
    elif node.get("unlabelled_input"):
        parts.append(f"<{node.get('module') or 'module'}: no input drawn>")
    elif node.get("module"):
        # a module output without a software signal name written on it
        who = " ".join(x for x in (node.get("tag"), node.get("device")) if x) or "?"
        parts.append(f"{who} [no signal name]")
    elif node.get("tag"):
        extra = node.get("device") or node.get("label")
        parts.append(f"{node['tag']} ({extra})" if extra else node["tag"])
    elif node.get("device"):
        parts.append(node["device"])
    else:
        parts.append("<unlabelled wire>")
    return " ".join(parts)


def ports(sheet: SheetData, nets: NetResult) -> dict[int, list[dict]]:
    """Per-shape ports {shape id: [{net, side, x, y}]} (computed by nets.shape_ports, stored on the shapes)."""
    if nets is None or not nets.shapes:
        return {}
    if any("ports" not in sh for sh in nets.shapes):
        shape_ports(sheet.segments, nets.nets, nets.shapes, {t.id: t.text for t in sheet.texts})
    return {sh["id"]: sh.get("ports", []) for sh in nets.shapes}


# ----------------------------------------------------------------------------- the per-sheet context
class _Ctx:
    def __init__(self, sheet: SheetData, nets: Optional[NetResult], links=None, meta=None) -> None:
        self.sheet = sheet
        self.nets = nets if nets is not None else NetResult([], [], {}, {}, {})
        self.links = [L for L in (links or []) if isinstance(L, dict)]
        self.meta = meta or {}
        self.sid = self.meta.get("id") or sheet.sheet_id
        self.title = sheet.title or ""
        self.kind = sheet_kind(self.title)
        self.texts: dict[str, TextItem] = {t.id: t for t in sheet.texts}
        self.segs = {s.id: s for s in sheet.segments}
        self.shapes = self.nets.shapes
        self.shape_by_id = {sh["id"]: sh for sh in self.shapes}
        ports(sheet, self.nets)
        self.net_by_id: dict[int, Net] = {n.id: n for n in self.nets.nets}
        self.idents = {t.id: classify(t.text) for t in sheet.texts if not t.frame}
        self.text_net: dict[str, int] = dict(self.nets.text_net)
        self.text_shape: dict[str, int] = dict(self.nets.text_shape)
        self.loose: set[str] = set()
        self._loose_labels()
        self.net_texts: dict[int, list[str]] = defaultdict(list)
        for tid, nid in self.text_net.items():
            self.net_texts[nid].append(tid)
        for lst in self.net_texts.values():
            lst.sort(key=lambda i: (self.texts[i].bbox[0], -self.texts[i].bbox[3]))
        self.info: dict[int, dict] = {}
        for sh in self.shapes:
            self.info[sh["id"]] = self._shape_info(sh)
        self.net_ports: dict[int, list[tuple[int, str]]] = defaultdict(list)
        for sh in self.shapes:
            for p in sh.get("ports", []):
                self.net_ports[p["net"]].append((sh["id"], p["side"]))
        self.links_by_src: dict[str, dict] = {}
        for L in self.links:
            if L.get("kind") == "xref" and L.get("src_text"):
                self.links_by_src[L["src_text"]] = L
        self.typical_by_src: dict[str, dict] = {L["src_text"]: L for L in self.links if L.get("kind") == "typical" and L.get("src_text")}
        self.links_in_by_text: dict[str, dict] = {}
        for L in self.meta.get("links_in") or []:
            if isinstance(L, dict) and L.get("to_text"):
                self.links_in_by_text.setdefault(L["to_text"], L)
        self.circles = self._circle_devices()
        self.net_circles: dict[int, list[dict]] = defaultdict(list)
        for c in self.circles:
            for nid in c["nets"]:
                self.net_circles[nid].append(c)
        self.warnings: list[str] = []
        self._pointer_cache: dict[int, Optional[dict]] = {}

    # ---- labels -------------------------------------------------------------------------
    def _loose_labels(self) -> None:
        """Signal names, potentials and taps written up to LOOSE_TOL from the start of their wire."""
        if not self.nets.nets:
            return
        wires = [self.segs[i] for n in self.nets.nets for i in n.segments if i in self.segs]
        if not wires:
            return
        grid = _Grid(wires)
        for t in self.sheet.texts:
            if t.frame or t.id in self.text_net or t.id in self.text_shape:
                continue
            kinds = {i.kind for i in self.idents.get(t.id, [])}
            if not (kinds & {"tag", "potential", "terminal", "dv"}) and t.text.upper() not in LIMIT_WORDS:
                continue
            if len(t.text) > 16:
                continue
            x0, y0, x1, y1 = t.bbox
            tol = (LOOSE_TOL + 1.0 if "dv" in kinds else LOOSE_TOL) + 0.05
            best_d, best_net = tol, None
            for oid in grid.near_box(x0 - tol, y0 - tol, x1 + tol, y1 + tol):
                d = _seg_box_dist(self.segs[oid], t.bbox)
                if d < best_d:
                    best_d, best_net = d, self.nets.seg_net.get(oid)
            if best_net is not None:
                self.text_net[t.id] = best_net
                self.loose.add(t.id)

    def net_labels(self, nid: int) -> dict:
        out = {"signals": [], "limits": [], "dvs": [], "pointers": [], "potentials": [], "cables": [], "elco": [],
               "words": [], "text_ids": [], "by_kind": {}}
        for tid in self.net_texts.get(nid, []):
            t = self.texts[tid]
            out["text_ids"].append(tid)
            kinds = {i.kind for i in self.idents.get(tid, [])}
            up = t.text.strip().upper()
            if "xref" in kinds:
                out["pointers"].append(tid)
            elif "dv" in kinds:
                out["dvs"].append(tid)
            elif up in LIMIT_WORDS:
                out["limits"].append(tid)
            elif "tag" in kinds:
                out["signals"].append(tid)
            elif kinds & {"potential", "terminal"}:
                out["potentials"].append(tid)
            elif "cable" in kinds:
                out["cables"].append(tid)
            elif kinds & {"elco", "connector"}:
                out["elco"].append(tid)
            else:
                out["words"].append(tid)
        return out

    def txt(self, tid: Optional[str]) -> str:
        return self.texts[tid].text if tid and tid in self.texts else ""

    # ---- shapes -------------------------------------------------------------------------
    def _shape_info(self, sh: dict) -> dict:
        b = sh["bbox"]
        w, h = _size(b)
        tids = [t for t in sh.get("texts", []) if t in self.texts]
        items = [self.texts[t] for t in tids]
        if not items and w * h <= 6000:
            # a big symbol (the 83 mm AND on 052) is above the text-association size limit: look inside it
            for t in self.sheet.texts:
                if t.frame or t.id in self.text_net or t.id in self.text_shape or len(t.text) > 24:
                    continue
                cx, cy = _center(t.bbox)
                if b[0] <= cx <= b[2] and b[1] <= cy <= b[3]:
                    items.append(t)
                    tids.append(t.id)
        items.sort(key=lambda t: (-round(t.bbox[3], 1), t.bbox[0]))
        words = [t.text for t in items]
        kind = classify_shape(words, (w, h), sh.get("symbol"))
        label = " ".join(words)
        if kind == "gate":
            label = next(t.text.upper() for t in items if t.text.strip().upper() in GATE_WORDS)
        elif not words and sh.get("symbol"):
            label = sh["symbol"]
        by_side: dict[str, list[int]] = {"L": [], "R": [], "T": [], "B": []}
        for p in sh.get("ports", []):
            if p["net"] not in by_side[p["side"]]:
                by_side[p["side"]].append(p["net"])
        # texts beside the symbol (fuse name and rating, lamp name)
        near: list[str] = []
        if kind in ("device", "label_box", "unknown", "module", "converter", "timer") and max(w, h) <= 60:
            for t in self.sheet.texts:
                if t.frame or t.id in self.text_shape or t.id in self.text_net or len(t.text) > 12:
                    continue
                gx, gy = _gap(b, t.bbox)
                if (gx <= NEAR_TEXT_TOL and gy <= NEAR_TEXT_TOL) or (gx <= 1.5 and gy <= 1.5 * NEAR_TEXT_TOL) or (gy <= 1.5 and gx <= 1.5 * NEAR_TEXT_TOL):
                    near.append(t.id)
            near.sort(key=lambda i: (-self.texts[i].bbox[3], self.texts[i].bbox[0]))
        fuse_name = rating = None
        for i in near:
            s = self.texts[i].text.strip()
            if fuse_name is None and FUSE_NAME_RE.match(s):
                fuse_name = s
            elif rating is None and RATING_RE.match(s):
                rating = s
        return {"id": sh["id"], "kind": kind, "label": label, "words": words, "text_ids": tids, "bbox": b,
                "ports": by_side, "near": near, "fuse": fuse_name, "rating": rating, "symbol": sh.get("symbol")}

    def shapes_on_net(self, nid: int) -> list[tuple[int, str]]:
        return list(self.net_ports.get(nid, []))

    def is_driver(self, shape_id: int, side: str) -> bool:
        info = self.info[shape_id]
        k = info["kind"]
        if k in ("gate", "timer", "converter"):
            return side == "R"
        if k == "module":
            return side in OUTPUT_SIDES
        if k == "device":
            return side in ("R", "B")
        if k == "tag_oval":
            if side == "R":
                return True
            if side in ("T", "B"):
                cx = _center(info["bbox"])[0]
                mid = (self.sheet.extents[0] + self.sheet.extents[2]) / 2.0
                return cx < mid
            return False
        return False

    def drivers(self, nid: int) -> list[tuple[int, str]]:
        return [(s, side) for s, side in self.shapes_on_net(nid) if self.is_driver(s, side)]

    def sinks(self, nid: int) -> list[tuple[int, str]]:
        out = []
        for s, side in self.shapes_on_net(nid):
            k = self.info[s]["kind"]
            if k == "unknown":
                continue
            if k == "continuation":
                out.append((s, side))
            elif not self.is_driver(s, side):
                out.append((s, side))
        return out

    def input_nets(self, shape_id: int) -> list[int]:
        """Input-side nets of a symbol, top to bottom as drawn."""
        info = self.info[shape_id]
        sides = ["L"] if info["kind"] in ("gate", "timer", "converter", "module") else ["L", "T"]
        nets = []
        for side in sides:
            nets.extend(info["ports"][side])
        ys = {}
        for sh_port in self.shape_by_id[shape_id].get("ports", []):
            ys.setdefault(sh_port["net"], sh_port["y"])
        return sorted(_uniq(nets), key=lambda n: -ys.get(n, 0.0))

    def output_nets(self, shape_id: int) -> list[int]:
        info = self.info[shape_id]
        if info["kind"] == "module":
            return _uniq(info["ports"]["R"] + info["ports"]["T"] + info["ports"]["B"])
        if info["kind"] == "device":
            return _uniq(info["ports"]["R"] + info["ports"]["B"])
        return list(info["ports"]["R"])

    # ---- texts around a symbol ----------------------------------------------------------
    def _free_texts(self):
        for t in self.sheet.texts:
            if t.frame or t.id in self.text_shape:
                continue
            yield t

    def caption_above(self, b, max_gap: float = 4.5) -> list[str]:
        out = []
        for t in self._free_texts():
            if t.id in self.text_net and t.id not in self.loose:
                continue
            if t.text.strip().upper() in LIMIT_WORDS or LOOP_TYPE_RE.search(t.text):
                continue
            kinds = {i.kind for i in self.idents.get(t.id, [])}
            if kinds & {"tag", "xref", "dv", "window", "cable", "elco"}:
                continue
            if t.bbox[1] >= b[3] - 0.6 and t.bbox[1] - b[3] <= max_gap and (_overlap_x(t.bbox, b) > 0 or abs(_center(t.bbox)[0] - _center(b)[0]) <= 6.0):
                out.append(t.id)
        out.sort(key=lambda i: -self.texts[i].bbox[3])
        return out

    def loop_type_below(self, b, max_gap: float = 5.0) -> Optional[str]:
        best = None
        for t in self._free_texts():
            m = LOOP_TYPE_RE.search(t.text)
            if not m:
                continue
            if t.bbox[3] <= b[1] + 0.6 and b[1] - t.bbox[3] <= max_gap and (_overlap_x(t.bbox, b) > 0 or abs(_center(t.bbox)[0] - _center(b)[0]) <= 6.0):
                d = b[1] - t.bbox[3]
                if best is None or d < best[0]:
                    best = (d, t.id)
        return best[1] if best else None

    def cable_beside(self, b, direction: str, max_dist: float = 32.0) -> dict:
        """Cable number and terminal pair written in the CABLE & TERMINALS column beside a tag."""
        cy = _center(b)[1]
        found = {"cable": None, "terminals": None, "text_ids": []}
        cands = []
        for t in self._free_texts():
            tcy = _center(t.bbox)[1]
            if abs(tcy - cy) > 4.0:
                continue
            if direction == "left":
                d = b[0] - t.bbox[2]
            else:
                d = t.bbox[0] - b[2]
            if d < -0.5 or d > max_dist:
                continue
            cands.append((d, t))
        cands.sort(key=lambda c: c[0])
        for _d, t in cands:
            kinds = {i.kind for i in self.idents.get(t.id, [])}
            s = t.text.strip()
            if "cable" in kinds and found["cable"] is None:
                found["cable"] = s
                found["text_ids"].append(t.id)
            elif found["terminals"] is None and (TERMINAL_PAIR_RE.match(s) or re.match(r"^\d{1,2}$", s)) and "cable" not in kinds:
                found["terminals"] = s
                found["text_ids"].append(t.id)
            elif found["cable"] is None and re.match(r"^\d{1,2}/\d{3,4}$", s):      # '3/650' written without the C
                found["cable"] = s
                found["text_ids"].append(t.id)
        return found

    def field_block_left(self, b, max_dist: float = 48.0) -> dict:
        """The FIELD column text block (tag, description, LOOP TYPE) on the row of a console symbol."""
        y0, y1 = b[1] - 5.0, b[3] + 5.0
        rows = []
        for t in self._free_texts():
            if t.id in self.text_net and t.id not in self.loose:
                continue
            if t.bbox[2] > b[0] + 1.0 or b[0] - t.bbox[2] > max_dist:
                continue
            if t.bbox[3] < y0 or t.bbox[1] > y1:
                continue
            kinds = {i.kind for i in self.idents.get(t.id, [])}
            if kinds & {"window", "xref"}:
                continue
            rows.append(t)
        rows.sort(key=lambda t: -t.bbox[3])
        out = {"tag": None, "desc": "", "loop_type": None, "cable": None, "terminals": None, "text_ids": []}
        desc = []
        for t in rows:
            kinds = {i.kind for i in self.idents.get(t.id, [])}
            m = LOOP_TYPE_RE.search(t.text)
            st = t.text.strip()
            if m and out["loop_type"] is None:
                out["loop_type"] = m.group(1).upper()
            elif "tag" in kinds and out["tag"] is None:
                out["tag"] = st
            elif "cable" in kinds or re.match(r"^\d{1,2}/\d{3,4}$", st):
                if out["cable"] is None:
                    out["cable"] = st
            elif TERMINAL_PAIR_RE.match(st):
                if out["terminals"] is None:
                    out["terminals"] = st
            elif not m:
                desc.append(st)
            out["text_ids"].append(t.id)
        out["desc"] = " ".join(desc)
        return out

    def caption_below(self, b, max_gap: float = 3.0) -> list[str]:
        out = []
        for t in self._free_texts():
            if t.bbox[3] <= b[1] + 0.6 and b[1] - t.bbox[3] <= max_gap and _overlap_x(t.bbox, b) > -2.0:
                if not self.idents.get(t.id):
                    out.append(t.id)
        return out

    # ---- circles: annunciator windows, lamps --------------------------------------------
    def _circle_devices(self) -> list[dict]:
        out = []
        if not self.nets.nets:
            return out
        ends: list[tuple[float, float, int]] = []
        for n in self.nets.nets:
            for i in n.segments:
                s = self.segs.get(i)
                if s is None:
                    continue
                ends.append((s.x1, s.y1, n.id))
                ends.append((s.x2, s.y2, n.id))
        for cx, cy, r, handle in self.sheet.circles:
            if r > 3.0 or r < 0.5:
                continue
            nets = set()
            for ex, ey, nid in ends:
                if abs(ex - cx) <= r + 0.35 and abs(ey - cy) <= r + 0.35 and math.hypot(ex - cx, ey - cy) <= r + 0.35:
                    n = self.net_by_id[nid]
                    bb = n.bbox
                    if bb[0] >= cx - r - 0.1 and bb[2] <= cx + r + 0.1 and bb[1] >= cy - r - 0.1 and bb[3] <= cy + r + 0.1:
                        continue                      # the cross drawn inside the circle
                    nets.add(nid)
            label_t = None
            best = None
            cb = (cx - r, cy - r, cx + r, cy + r)
            for t in self._free_texts():
                if t.id in self.text_net and t.id not in self.loose:
                    continue
                s = t.text.strip()
                if len(s) > 10:
                    continue
                gx, gy = _gap(cb, t.bbox)
                d = math.hypot(gx, gy)
                if d > 6.0:
                    continue
                score = d - (3.0 if (WINDOW_LABEL_RE.match(s) or LAMP_LABEL_RE.match(s)) else 0.0)
                if best is None or score < best[0]:
                    best = (score, t)
            if best is not None:
                label_t = best[1]
            label = label_t.text.strip() if label_t else ""
            kind = "annunciator" if WINDOW_LABEL_RE.match(label) else "lamp" if LAMP_LABEL_RE.match(label) else "circle"
            if not nets and not label:
                continue
            out.append({"cx": round(cx, 2), "cy": round(cy, 2), "r": round(r, 2), "handle": handle, "label": label,
                        "text": label_t.id if label_t else None, "kind": kind, "nets": sorted(nets)})
        return out

    # ---- continuation boxes -------------------------------------------------------------
    def pointer_of(self, shape_id: int) -> Optional[dict]:
        """The explicit pointer (052.225) written beside a continuation box, with its link."""
        if shape_id in self._pointer_cache:
            return self._pointer_cache[shape_id]
        b = self.info[shape_id]["bbox"]
        best = None
        for t in self.sheet.texts:
            if t.frame:
                continue
            m = XREF_RE.match(t.text.strip())
            if not m:
                continue
            gx, gy = _gap(b, t.bbox)
            beside = t.bbox[0] >= b[2] - 0.5 or t.bbox[2] <= b[0] + 0.5
            same_row = gy == 0.0 and gx <= 4.0 and beside                      # written in the box's row, left or right of it
            same_col = gy <= 2.5 and _overlap_x(t.bbox, b) > -1.0 and not beside   # written above or below the box
            if not (same_row or same_col):
                continue
            d = math.hypot(gx, gy) + (0.0 if same_row else 2.0)     # the row companion wins over a neighbour above/below
            if best is None or d < best[0]:
                best = (d, t, m)
        res = None
        if best is not None:
            _d, t, m = best
            L = self.links_by_src.get(t.id)
            res = {"text": t.id, "pointer": t.text.strip(), "sheet": m.group(1), "grid": int(m.group(2)),
                   "link": L.get("id") if L else None, "link_status": L.get("status") if L else None,
                   "dst_text": L.get("dst_text") if L else None}
        self._pointer_cache[shape_id] = res
        return res

    def box_net(self, shape_id: int) -> Optional[int]:
        info = self.info[shape_id]
        for side in ("L", "R", "T", "B"):
            if info["ports"][side]:
                return info["ports"][side][0]
        for n in self.nets.nets:
            if shape_id in n.shapes:
                return n.id
        return None

    # ---- the logic tree -----------------------------------------------------------------
    def source(self, nid: Optional[int], path: tuple = ()) -> dict:
        """What drives a net, as a nested tree (cycle safe)."""
        if nid is None or nid not in self.net_by_id:
            return {"unlabelled": True, "net": nid, "text_ids": []}
        labels = self.net_labels(nid)
        if len(path) >= MAX_DEPTH:
            return self._decorate({"unlabelled": True, "net": nid, "note": "trace depth limit"}, labels)
        drv_all = self.drivers(nid)
        drv = [(s, side) for s, side in drv_all if s not in path]
        cyc = [s for s, _side in drv_all if s in path]
        nodes = [self.node_for(s, nid, path + (s,)) for s, _side in drv]
        for s in cyc:
            nodes.append({"cycle": True, "shape": s, "net": nid, "text_ids": []})
        if not nodes:
            boxes = [s for s, _side in self.shapes_on_net(nid) if self.info[s]["kind"] == "continuation"]
            if boxes:
                box = boxes[0]
                ptr = self.pointer_of(box)
                leaf = {"signal": self.info[box]["label"], "incoming": True, "shape": box, "net": nid,
                        "from_sheet": ptr["sheet"] if ptr else None, "link": ptr["link"] if ptr else None,
                        "link_status": ptr["link_status"] if ptr else None,
                        "text_ids": list(self.info[box]["text_ids"]) + ([ptr["text"]] if ptr else [])}
                return self._decorate(leaf, labels, keep_signal=True)
            if labels["signals"]:
                leaf = {"signal": self.txt(labels["signals"][0]), "net": nid, "no_driver": True, "text_ids": []}
                return self._decorate(leaf, labels, keep_signal=True)
            return self._decorate({"unlabelled": True, "net": nid, "text_ids": []}, labels)
        node = nodes[0] if len(nodes) == 1 else {"op": "JOINED", "kind": "joined", "inputs": nodes, "net": nid,
                                                   "note": "several symbols drive this wire", "text_ids": []}
        return self._decorate(node, labels)

    def _decorate(self, node: dict, labels: dict, keep_signal: bool = False) -> dict:
        if labels["signals"] and not (keep_signal and node.get("signal")):
            node["signal"] = self.txt(labels["signals"][0])
        if labels["limits"]:
            node["limit"] = " ".join(self.txt(i) for i in labels["limits"])
        if labels["dvs"]:
            node["taps"] = [{"label": self.txt(i), "text": i} for i in labels["dvs"]]
        words = [self.txt(i) for i in labels["words"] if len(self.txt(i)) <= 10]
        if words and "op" not in node and not node.get("label"):
            node["label"] = " ".join(words)
        node.setdefault("text_ids", [])
        node["text_ids"] = _uniq(node["text_ids"] + labels["text_ids"])
        return node

    def node_for(self, shape_id: int, out_net: int, path: tuple) -> dict:
        info = self.info[shape_id]
        k = info["kind"]
        if k == "tag_oval":
            return self.oval_leaf(shape_id, out_net)
        if k == "device":
            ins = self.input_nets(shape_id)
            if not ins:
                return self.device_leaf(shape_id, out_net)
            return {"op": info["label"] or "device", "kind": "device", "shape": shape_id, "net": out_net,
                    "inputs": [self.source(n, path) for n in ins], "text_ids": list(info["text_ids"])}
        if k == "module":
            ins = self.input_nets(shape_id)
            inputs = [self.source(n, path) for n in ins]
            if len(inputs) == 1 and ("tag" in inputs[0] or "device" in inputs[0]) and "op" not in inputs[0]:
                leaf = dict(inputs[0])
                leaf.update({"module": info["label"], "module_shape": shape_id, "net": out_net, "field_net": ins[0],
                             "field_shape": inputs[0].get("shape"), "text_ids": _uniq(list(info["text_ids"]) + inputs[0].get("text_ids", []))})
                leaf.pop("shape", None)
                leaf.pop("signal", None)
                return leaf
            if not inputs:
                return {"module": info["label"], "module_shape": shape_id, "net": out_net, "unlabelled_input": True,
                        "text_ids": list(info["text_ids"])}
            return {"op": info["label"] or "module", "kind": "module", "shape": shape_id, "net": out_net,
                    "inputs": inputs, "text_ids": list(info["text_ids"])}
        if k in ("gate", "timer", "converter"):
            ins = self.input_nets(shape_id)
            op = info["label"] if k == "gate" else (info["label"] or k.upper())
            return {"op": op, "kind": k, "shape": shape_id, "net": out_net,
                    "inputs": [self.source(n, path) for n in ins], "text_ids": list(info["text_ids"])}
        return {"unlabelled": True, "net": out_net, "shape": shape_id, "text_ids": []}

    def oval_leaf(self, shape_id: int, net: Optional[int]) -> dict:
        info = self.info[shape_id]
        b = info["bbox"]
        cap = self.caption_above(b)
        lt = self.loop_type_below(b)
        mid = (self.sheet.extents[0] + self.sheet.extents[2]) / 2.0
        cab = self.cable_beside(b, "left" if _center(b)[0] < mid else "right")
        m = LOOP_TYPE_RE.search(self.txt(lt)) if lt else None
        return {"tag": info["label"], "desc": " ".join(self.txt(i) for i in cap), "loop_type": m.group(1).upper() if m else None,
                "cable": cab["cable"], "terminals": cab["terminals"], "shape": shape_id, "net": net,
                "text_ids": _uniq(list(info["text_ids"]) + cap + ([lt] if lt else []) + cab["text_ids"])}

    def device_leaf(self, shape_id: int, net: Optional[int]) -> dict:
        info = self.info[shape_id]
        b = info["bbox"]
        words = self.net_labels(net)["words"] if net is not None else []
        ann = [self.txt(i) for i in words if len(self.txt(i)) <= 4]
        label = (ann[0] + " " if ann else "") + ("'" + info["label"] + "'" if info["label"] and len(info["label"]) <= 3 else info["label"] or info["symbol"] or "symbol")
        fb = self.field_block_left(b)
        below = self.caption_below(b)
        return {"device": label.strip(), "tag": fb["tag"], "desc": fb["desc"], "loop_type": fb["loop_type"],
                "cable": fb["cable"], "terminals": fb["terminals"],
                "location": " ".join(self.txt(i) for i in below), "shape": shape_id, "net": net,
                "text_ids": _uniq(list(info["text_ids"]) + fb["text_ids"] + below + words)}

    # ---- helpers for words --------------------------------------------------------------
    def shape_words(self, shape_id: int) -> str:
        info = self.info[shape_id]
        k = info["kind"]
        if k == "gate":
            return f"{info['label']} gate"
        if k == "timer":
            return f"timer {info['label']}"
        if k == "converter":
            return f"converter {info['label']}"
        if k == "module":
            return f"module {info['label']}"
        if k == "tag_oval":
            return f"tag {info['label']}"
        if k == "continuation":
            ptr = self.pointer_of(shape_id)
            return f"continuation box {info['label']}" + (f" ({ptr['pointer']})" if ptr else "")
        if k == "label_box":
            return f"label box {info['label']}" if info["label"] else "empty label box"
        if k == "device":
            if info["fuse"]:
                word = "link" if info["fuse"].upper().startswith("LINK") else "fuse"
                return f"{word} {info['fuse']}" + (f" ({info['rating']})" if info["rating"] else "")
            near = " ".join(self.txt(i) for i in info["near"][:3])
            base = info["label"] or (info["symbol"] or "symbol")
            return f"symbol {base}" + (f" ({near})" if near and near != base else "")
        return "outline"


# ----------------------------------------------------------------------------- tree utilities
def _walk(node, fn):
    if not isinstance(node, dict):
        return
    fn(node)
    for i in node.get("inputs") or []:
        _walk(i, fn)


def _collect_ids(tree) -> tuple[list[str], list[int], list[int]]:
    texts, shapes, nets = [], [], []

    def fn(n):
        texts.extend(n.get("text_ids") or [])
        for key in ("shape", "module_shape", "field_shape"):
            if n.get(key) is not None:
                shapes.append(n[key])
        for key in ("net", "field_net"):
            if n.get(key) is not None:
                nets.append(n[key])
        for tp in n.get("taps") or []:
            if tp.get("text"):
                texts.append(tp["text"])
    _walk(tree, fn)
    return _uniq(texts), _uniq(shapes), _uniq(nets)


def _leaves(tree) -> list[dict]:
    out = []

    def fn(n):
        if "op" not in n:
            out.append(n)
    _walk(tree, fn)
    return out


def _short(s: str, n: int = 160) -> str:
    return s if len(s) <= n else s[: n - 3] + "..."


# ----------------------------------------------------------------------------- FLD logic
def _fld_logic(ctx: _Ctx) -> list[dict]:
    entries: list[dict] = []
    covered_ovals: set[int] = set()

    def finish(e: dict, tree: Optional[dict]) -> dict:
        e["tree"] = tree
        e["expr"] = expr_of(tree) if tree else ""
        t_ids, s_ids, n_ids = _collect_ids(tree) if tree else ([], [], [])
        e["text_ids"] = _uniq(list(e.get("text_ids", [])) + t_ids)
        e["shape_ids"] = _uniq(list(e.get("shape_ids", [])) + s_ids)
        e["net_ids"] = _uniq(list(e.get("net_ids", [])) + n_ids)
        if e.get("net") is not None:
            labels = ctx.net_labels(e["net"])
            e["taps"] = [{"label": ctx.txt(i), "text": i} for i in labels["dvs"]]
        else:
            e.setdefault("taps", [])
        return e

    # continuation boxes: outgoing (driven by logic on this sheet) or incoming (feeding logic here)
    for sid, info in ctx.info.items():
        if info["kind"] != "continuation":
            continue
        ptr = ctx.pointer_of(sid)
        nid = ctx.box_net(sid)
        base = {"output": info["label"], "shape": sid, "net": nid, "pointer": ptr["pointer"] if ptr else None,
                "pointer_text": ptr["text"] if ptr else None,
                "link": ptr["link"] if ptr else None, "link_status": ptr["link_status"] if ptr else None,
                "text_ids": list(info["text_ids"]) + ([ptr["text"]] if ptr else []), "shape_ids": [sid], "net_ids": [nid] if nid is not None else []}
        if nid is None:
            e = dict(base, kind="continuation", dest_sheet=ptr["sheet"] if ptr else None, note="box is not connected to a wire")
            entries.append(finish(e, None))
            continue
        drv = ctx.drivers(nid)
        if drv:
            e = dict(base, kind="continuation", dest_sheet=ptr["sheet"] if ptr else None)
            entries.append(finish(e, ctx.source(nid)))
        else:
            feeds = []
            for s, side in ctx.sinks(nid):
                if s == sid:
                    continue
                feeds.append({"shape": s, "kind": ctx.info[s]["kind"], "label": ctx.shape_words(s), "side": side})
            for c in ctx.net_circles.get(nid, []):
                if c["kind"] == "circle" and not c["label"]:
                    continue
                feeds.append({"shape": None, "kind": c["kind"], "label": f"{c['kind']} {c['label']}".strip(), "side": None})
            labels = ctx.net_labels(nid)
            e = dict(base, kind="incoming", from_sheet=ptr["sheet"] if ptr else None, feeds=feeds,
                     signal=ctx.txt(labels["signals"][0]) if labels["signals"] else None,
                     link_in=(ctx.links_in_by_text.get(info["text_ids"][0]) or {}).get("id") if info["text_ids"] else None)
            if not feeds:
                e["note"] = "the wire from this box reaches no symbol on this sheet"
            e["feeds_text"] = "; ".join(f["label"] for f in feeds)
            entries.append(finish(e, None))
            e["expr"] = ""

    # converters (V TO I): their output goes to a process device tag
    for sid, info in ctx.info.items():
        if info["kind"] != "converter":
            continue
        outs = ctx.output_nets(sid)
        ins = ctx.input_nets(sid)
        tree = {"op": info["label"] or "converter", "kind": "converter", "shape": sid, "net": outs[0] if outs else None,
                "inputs": [ctx.source(n, (sid,)) for n in ins], "text_ids": list(info["text_ids"])}
        in_words = [ctx.txt(i) for n in ins for i in ctx.net_labels(n)["words"]]
        for onet in (outs or [None]):
            dev = None
            out_words = [ctx.txt(i) for i in ctx.net_labels(onet)["words"]] if onet is not None else []
            if onet is not None:
                for s, side in ctx.sinks(onet):
                    if ctx.info[s]["kind"] == "tag_oval":
                        dev = ctx.oval_leaf(s, onet)
                        covered_ovals.add(s)
                        break
            e = {"output": dev["tag"] if dev else (info["label"] or "converter"), "kind": "converter", "shape": sid, "net": onet,
                 "dest_sheet": None, "link": None, "signal_in": " ".join(in_words), "signal_out": " ".join(out_words),
                 "device": dev, "text_ids": (dev["text_ids"] if dev else []), "shape_ids": [sid] + ([dev["shape"]] if dev else []),
                 "net_ids": [onet] if onet is not None else []}
            entries.append(finish(e, tree))
            if dev:
                e["expr"] = f"{e['expr']} -> {dev['tag']}" + (f" ({dev['desc']})" if dev.get("desc") else "")

    # process device tags fed by logic (through output modules and relay amplifiers)
    for sid, info in ctx.info.items():
        if info["kind"] != "tag_oval" or sid in covered_ovals or not info["ports"]["L"]:
            continue
        nid = info["ports"]["L"][0]
        if not ctx.drivers(nid):
            continue
        dev = ctx.oval_leaf(sid, nid)
        tree = ctx.source(nid)
        via = []
        _walk(tree, lambda n: via.append(n["op"]) if n.get("kind") in ("module", "device") and n.get("op") else None)
        e = {"output": dev["tag"], "kind": "other", "output_kind": "process_device", "shape": sid, "net": nid, "device": dev,
             "dest_sheet": None, "link": None, "via": via, "text_ids": list(dev["text_ids"]), "shape_ids": [sid], "net_ids": [nid]}
        entries.append(finish(e, tree))

    # DeltaV taps
    for tid, idents in ctx.idents.items():
        if not any(i.kind == "dv" for i in idents):
            continue
        nid = ctx.text_net.get(tid)
        e = {"output": ctx.txt(tid), "kind": "dv", "text": tid, "net": nid, "dest_sheet": None, "link": None,
             "text_ids": [tid], "shape_ids": [], "net_ids": [nid] if nid is not None else []}
        if nid is None:
            e["note"] = "tap is not within 3 mm of a wire"
            entries.append(finish(e, None))
        else:
            entries.append(finish(e, ctx.source(nid)))

    # annunciator windows and lamps
    for c in ctx.circles:
        if c["kind"] not in ("annunciator", "lamp") or not c["nets"]:
            continue
        for nid in c["nets"]:
            if not ctx.drivers(nid) and not ctx.net_labels(nid)["signals"]:
                continue
            e = {"output": c["label"], "kind": "annunciator" if c["kind"] == "annunciator" else "other", "output_kind": c["kind"],
                 "text": c["text"], "net": nid, "dest_sheet": None, "link": None, "circle": [c["cx"], c["cy"], c["r"]],
                 "text_ids": [c["text"]] if c["text"] else [], "shape_ids": [], "net_ids": [nid]}
            entries.append(finish(e, ctx.source(nid)))

    # where each arriving signal is used
    uses: dict[str, list[str]] = defaultdict(list)
    for e in entries:
        if e["kind"] in ("incoming",) or not e.get("tree"):
            continue
        for leaf in _leaves(e["tree"]):
            if leaf.get("incoming") and leaf.get("signal"):
                uses[leaf["signal"]].append(e["output"])
    for e in entries:
        if e["kind"] == "incoming":
            e["used_in"] = _uniq(uses.get(e["output"], []))
    order = {"continuation": 0, "other": 1, "converter": 2, "annunciator": 3, "dv": 4, "incoming": 5}
    entries.sort(key=lambda e: (order.get(e["kind"], 9), str(e.get("output"))))
    return entries


def fld_logic(sheet: SheetData, nets: NetResult, links=None, sheet_meta=None) -> list[dict]:
    """Output entries of a functional logic diagram (see module docstring)."""
    ctx = _Ctx(sheet, nets, links, sheet_meta)
    return _fld_logic(ctx)


# ----------------------------------------------------------------------------- FLD inputs
def _fld_inputs(ctx: _Ctx, logic: list[dict]) -> list[dict]:
    """Field devices (tag ovals and console switches) and the module that reads each one."""
    participates: dict[str, list[str]] = defaultdict(list)
    for e in logic:
        if not e.get("tree"):
            continue
        for leaf in _leaves(e["tree"]):
            if leaf.get("tag"):
                participates[leaf["tag"]].append(e["output"])
    out = []
    seen = set()
    for sid, info in ctx.info.items():
        if info["kind"] == "tag_oval" and (info["ports"]["R"] or (not info["ports"]["L"] and _center(info["bbox"])[0] < (ctx.sheet.extents[0] + ctx.sheet.extents[2]) / 2)):
            nets_out = info["ports"]["R"] or info["ports"]["T"] + info["ports"]["B"]
            leaf = ctx.oval_leaf(sid, nets_out[0] if nets_out else None)
            rec = {"tag": leaf["tag"], "desc": leaf["desc"], "loop_type": leaf["loop_type"], "cable": leaf["cable"],
                   "terminals": leaf["terminals"], "shape": sid, "net": leaf["net"], "text_ids": leaf["text_ids"]}
        elif info["kind"] == "device" and info["ports"]["R"] and not info["ports"]["L"] and max(_size(info["bbox"])) <= 12:
            leaf = ctx.device_leaf(sid, info["ports"]["R"][0])
            if not leaf["tag"]:
                continue
            rec = {"tag": leaf["tag"], "desc": leaf["desc"], "loop_type": leaf["loop_type"], "device": leaf["device"],
                   "cable": leaf["cable"], "terminals": leaf["terminals"],
                   "location": leaf["location"], "shape": sid, "net": leaf["net"], "text_ids": leaf["text_ids"]}
        else:
            continue
        # the module reading this device and its software signals
        modules, signals, feeds = [], [], []
        if rec["net"] is not None:
            for s, side in ctx.sinks(rec["net"]):
                if ctx.info[s]["kind"] == "module":
                    modules.append({"shape": s, "label": ctx.info[s]["label"]})
                    for on in ctx.output_nets(s):
                        lab = ctx.net_labels(on)
                        sig = " ".join(ctx.txt(i) for i in lab["limits"] + lab["signals"])
                        signals.append(sig if sig else "(no signal name written)")
                elif ctx.info[s]["kind"] in ("gate", "timer", "converter"):
                    feeds.append(ctx.shape_words(s))
        rec["feeds"] = _uniq(feeds)
        rec["modules"] = modules
        rec["signals"] = _uniq(signals)
        rec["outputs"] = _uniq(participates.get(rec["tag"], []))
        key = (rec["tag"], sid)
        if key not in seen:
            seen.add(key)
            out.append(rec)
    out.sort(key=lambda r: -ctx.info[r["shape"]]["bbox"][3])
    return out


# ----------------------------------------------------------------------------- loop drawings
def loop_channels(sheet: SheetData, nets: Optional[NetResult] = None) -> list[dict]:
    """Channels of a loop drawing read from its table-like texts.

    Each loop cell on these sheets has a module heading (HIMA F6217) over a
    table with the headers PIN / POSITION / CH / PINS and the values below
    them; the tag, its description, cable and wire number stand to the left.
    A channel is reported only when the POSITION value was found under its
    header; what was not found is left out.
    """
    ctx = _Ctx(sheet, nets)
    return _loop_channels(ctx)


def _below_header(ctx: _Ctx, header: TextItem, pattern: re.Pattern, max_gap: float = 12.0) -> list[TextItem]:
    out = []
    for t in ctx.sheet.texts:
        if t.frame or t is header:
            continue
        if t.bbox[3] <= header.bbox[1] + 0.3 and header.bbox[1] - t.bbox[3] <= max_gap and _overlap_x(t.bbox, header.bbox) > -1.0:
            if pattern.match(t.text.strip()):
                out.append(t)
    out.sort(key=lambda t: -t.bbox[3])
    return out


def _loop_channels(ctx: _Ctx) -> list[dict]:
    texts = [t for t in ctx.sheet.texts if not t.frame]
    headers = [t for t in texts if t.text.strip().upper() == "POSITION"]
    out = []
    for hp in headers:
        pos = _below_header(ctx, hp, re.compile(r"^1[12]\d{2}$"))
        if not pos:
            continue
        row_y = pos[0].bbox[3]
        ch_hdr = [t for t in texts if re.fullmatch(r"CH\.?", t.text.strip().upper()) and abs(t.bbox[1] - hp.bbox[1]) <= 1.5 and abs(t.bbox[0] - hp.bbox[0]) <= 30]
        ch = _below_header(ctx, ch_hdr[0], re.compile(r"^\d{1,2}$")) if ch_hdr else []
        pin_hdrs = [t for t in texts if re.fullmatch(r"PINS?", t.text.strip().upper()) and abs(t.bbox[1] - hp.bbox[1]) <= 1.5 and abs(t.bbox[0] - hp.bbox[0]) <= 45]
        pins = []
        for ph in pin_hdrs:
            pins.extend(x.text.strip() for x in _below_header(ctx, ph, PIN_RE))
        # the module heading above the table
        mods = [t for t in texts if MODULE_RE.match(t.text.strip()) and t.bbox[1] >= hp.bbox[3] - 0.5 and t.bbox[1] - hp.bbox[3] <= 12 and abs(_center(t.bbox)[0] - _center(hp.bbox)[0]) <= 40]
        mod = mods[0].text.strip() if mods else None
        # the tag: nearest tag text to the left of the table, within the cell band
        tags = []
        for t in texts:
            kinds = {i.kind for i in ctx.idents.get(t.id, [])}
            if "tag" not in kinds or t.bbox[2] > hp.bbox[0] or hp.bbox[0] - t.bbox[2] > 150:
                continue
            if t.bbox[3] < hp.bbox[1] - 25 or t.bbox[1] > hp.bbox[3] + 15:
                continue
            tags.append(t)
        tags.sort(key=lambda t: (t.bbox[0], -t.bbox[3]))
        tag = tags[0] if tags else None
        rec = {"position": pos[0].text.strip(), "channel": ch[0].text.strip() if ch else None, "module": mod,
               "pins": pins, "tag": tag.text.strip() if tag else None, "desc": "", "cable": None, "wire": None,
               "potentials": [], "plug": None, "text_ids": [hp.id, pos[0].id] + ([ch[0].id] if ch else []) + ([tag.id] if tag else []) + ([mods[0].id] if mods else [])}
        if tag:
            desc = [t for t in texts if t.bbox[3] <= tag.bbox[1] + 0.3 and tag.bbox[1] - t.bbox[3] <= 9 and _overlap_x(t.bbox, tag.bbox) > -5
                    and not ctx.idents.get(t.id) and not LOOP_TYPE_RE.search(t.text)]
            desc.sort(key=lambda t: -t.bbox[3])
            rec["desc"] = " ".join(t.text.strip() for t in desc[:3])
            rec["text_ids"] += [t.id for t in desc[:3]]
            cables = [t for t in texts if any(i.kind == "cable" for i in ctx.idents.get(t.id, [])) and t.bbox[0] >= tag.bbox[0] - 5 and t.bbox[0] - tag.bbox[2] <= 25 and abs(t.bbox[1] - tag.bbox[1]) <= 10]
            cables.sort(key=lambda t: math.hypot(t.bbox[0] - tag.bbox[2], t.bbox[1] - tag.bbox[3]))
            if cables:
                rec["cable"] = cables[0].text.strip()
                rec["text_ids"].append(cables[0].id)
            wires = [t for t in texts if re.fullmatch(r"1[12]\d{2}/\d{1,2}", t.text.strip()) and t.bbox[0] > tag.bbox[2] and t.bbox[0] - tag.bbox[2] <= 60 and abs(t.bbox[1] - tag.bbox[1]) <= 8]
            wires.sort(key=lambda t: t.bbox[0])
            if wires:
                rec["wire"] = wires[0].text.strip()
                rec["text_ids"].append(wires[0].id)
        # supply potentials and the I/O plug written in the same cell
        cell = (hp.bbox[0] - 150, hp.bbox[1] - 60, hp.bbox[2] + 45, hp.bbox[3] + 15)
        for t in texts:
            if not (cell[0] <= t.bbox[0] <= cell[2] and cell[1] <= t.bbox[1] <= cell[3]):
                continue
            kinds = {i.kind for i in ctx.idents.get(t.id, [])}
            if kinds & {"terminal", "potential"} and re.fullmatch(r"\d?[A-Z]{1,2}[+-]\d{0,2}", t.text.strip()):
                rec["potentials"].append(t.text.strip())
            if re.fullmatch(r"Z\d{4}", t.text.strip()):
                rec["plug"] = t.text.strip()
        rec["potentials"] = sorted(_uniq(rec["potentials"]))
        out.append(rec)
    out.sort(key=lambda r: (r["position"], int(r["channel"]) if r["channel"] and r["channel"].isdigit() else 99))
    return out


# ----------------------------------------------------------------------------- net words
def _net_kind(ctx: _Ctx, labels: dict) -> str:
    if labels["potentials"]:
        return "potential"
    if labels["signals"] or labels["limits"] or labels["dvs"]:
        return "signal"
    return "wire"


def _pointer_words(ctx: _Ctx, tid: str) -> str:
    L = ctx.links_by_src.get(tid)
    m = XREF_RE.match(ctx.txt(tid))
    sheet = m.group(1) if m else (L or {}).get("dst_sheet")
    s = f"pointer {ctx.txt(tid)} to sheet {sheet}"
    if L:
        if L.get("label"):
            s += f" ({L['label']})"
        s += f", link {L.get('status')}"
    return s


def _net_explanations(ctx: _Ctx, logic: list[dict]) -> dict[str, dict]:
    out: dict[str, dict] = {}
    by_net_outputs: dict[int, list[str]] = defaultdict(list)
    for e in logic:
        if e["kind"] == "incoming":
            continue
        for n in e.get("net_ids", []):
            by_net_outputs[n].append(f"{e['output']}" + (f" -> sheet {e['dest_sheet']}" if e.get("dest_sheet") else ""))
    card = re.search(r"CARD\s+(\d{3,4})", ctx.title.upper())
    for n in ctx.nets.nets:
        labels = ctx.net_labels(n.id)
        shapes_here = ctx.shapes_on_net(n.id)
        circles = ctx.net_circles.get(n.id, [])
        length = sum(math.hypot(ctx.segs[i].x2 - ctx.segs[i].x1, ctx.segs[i].y2 - ctx.segs[i].y1) for i in n.segments if i in ctx.segs)
        if not labels["text_ids"] and not shapes_here and not circles and length < 5.0:
            continue
        lines: list[str] = []
        title = ""
        sig = " ".join(ctx.txt(i) for i in labels["limits"] + labels["signals"][:1])
        if sig:
            title = sig
        elif labels["potentials"]:
            title = ", ".join(_uniq(ctx.txt(i) for i in labels["potentials"]))
        elif labels["cables"]:
            title = "cable " + ", ".join(_uniq(ctx.txt(i) for i in labels["cables"]))
        elif labels["elco"]:
            title = ", ".join(_uniq(ctx.txt(i) for i in labels["elco"]))
        elif labels["dvs"]:
            title = "wire with DeltaV tap " + ", ".join(ctx.txt(i) for i in labels["dvs"])
        elif labels["pointers"]:
            title = "wire continuing on sheet " + ", ".join(_uniq(XREF_RE.match(ctx.txt(i)).group(1) for i in labels["pointers"] if XREF_RE.match(ctx.txt(i))))
        elif labels["words"]:
            title = ctx.txt(labels["words"][0])
        else:
            title = "unlabelled wire"
        all_labels = [ctx.txt(i) for i in labels["text_ids"]]
        if all_labels:
            lines.append("Labels on this wire: " + ", ".join(_uniq(all_labels)) + ".")
        else:
            lines.append("No label is written on this wire.")
        # what drives it / where it goes (logic sheets)
        drv = ctx.drivers(n.id) if ctx.kind == "fld" else []
        if drv:
            tree = ctx.source(n.id)
            if "op" in tree:
                lines.append("Logic: " + _short(expr_of(tree), 220) + ".")
            elif tree.get("incoming"):
                pass
            elif tree.get("module"):
                lines.append(("Software signal " + tree["signal"] if tree.get("signal") else "Module output without a signal name")
                             + f" from {tree['module']}" + (f", field input {tree['tag']}" if tree.get("tag") else "")
                             + (f" {tree['desc']}" if tree.get("desc") else "") + (f" ({tree['device']})" if tree.get("device") else "")
                             + (f", LOOP TYPE {tree['loop_type']}" if tree.get("loop_type") else "") + ".")
            elif tree.get("tag"):
                lines.append(f"Field signal from {tree['tag']}" + (f" {tree['desc']}" if tree.get("desc") else "") + (f" ({tree['label']})" if tree.get("label") else "") + ".")
            leaf_words = []
            for leaf in _leaves(tree)[:8]:
                if leaf.get("tag") and leaf.get("module") and "op" in tree:
                    leaf_words.append(f"{leaf['tag']}" + (f" ({leaf['desc']})" if leaf.get("desc") else "") + f" via {leaf['module']}")
                elif leaf.get("incoming") and "op" in tree:
                    leaf_words.append(f"{leaf['signal']} arriving from sheet {leaf.get('from_sheet')}")
            if leaf_words:
                lines.append("Field origin: " + "; ".join(_uniq(leaf_words)) + ".")
        goes = []
        for s, side in ctx.sinks(n.id):
            k = ctx.info[s]["kind"]
            if k == "continuation":
                ptr = ctx.pointer_of(s)
                if drv:
                    goes.append(f"continuation box {ctx.info[s]['label']}" + (f" to sheet {ptr['sheet']} ({ptr['pointer']})" if ptr else ""))
                else:
                    lines.append(f"Arrives from sheet {ptr['sheet']} as signal {ctx.info[s]['label']} (pointer {ptr['pointer']})." if ptr else f"Starts at continuation box {ctx.info[s]['label']}.")
            elif k == "device" and ctx.info[s]["fuse"]:
                continue
            else:
                goes.append(ctx.shape_words(s) + (f" ({side} side)" if k in ("module", "device", "label_box") else ""))
        for c in circles:
            if c["kind"] == "circle" and not c["label"]:
                continue
            goes.append(f"{c['kind']} {c['label']}" if c["kind"] != "circle" else f"symbol {c['label']} (circle)")
        if goes:
            lines.append(("Goes to: " if ctx.kind == "fld" else "Connected to: ") + "; ".join(_uniq(goes)) + ".")
        # fuses and links
        for s, side in shapes_here:
            info = ctx.info[s]
            if info["kind"] == "device" and info["fuse"]:
                word = "link" if info["fuse"].upper().startswith("LINK") else "fuse"
                name = f"{word} {info['fuse']}" + (f" ({info['rating']})" if info["rating"] else "")
                other = [p for p in info["ports"]["L"] + info["ports"]["R"] + info["ports"]["T"] + info["ports"]["B"] if p != n.id]
                other_lab = []
                for on in other:
                    ol = ctx.net_labels(on)
                    other_lab.extend(ctx.txt(i) for i in ol["potentials"] + ol["signals"] + ol["words"][:1])
                tail = (" The other side of the " + word + " carries " + ", ".join(_uniq(other_lab)) + ".") if other_lab else ""
                if side in ("B", "R"):
                    lines.append(f"Downstream of {name} (the wire leaves the {word} at its {'bottom' if side == 'B' else 'right'})." + tail)
                else:
                    lines.append(f"Supply side of {name} (the wire enters the {word} at its {'top' if side == 'T' else 'left'})." + tail)
        # other symbols touched (devices, label boxes)
        touched = []
        for s, side in shapes_here:
            info = ctx.info[s]
            if info["kind"] in ("label_box",):
                idents = [i for tid in info["text_ids"] for i in ctx.idents.get(tid, [])]
                extra = ""
                for i in idents:
                    if i.kind == "elco":
                        extra = f" (ELCO connector {i.extra.get('connector')}, pin {i.extra.get('pin')})"
                        break
                touched.append(f"label box {info['label']}{extra}" if info["label"] else "an empty label box")
            elif info["kind"] == "device" and not info["fuse"] and s not in [x for x, _ in ctx.sinks(n.id)] and s not in [x for x, _ in drv]:
                touched.append(ctx.shape_words(s) + (f" ({side} side)" if ctx.kind != "fld" else ""))
            elif info["kind"] == "unknown":
                continue
        if touched:
            lines.append("Also touches: " + "; ".join(_uniq(touched)) + ".")
        for tid in labels["pointers"]:
            lines.append("Continues on another sheet: " + _pointer_words(ctx, tid) + ".")
        # nearby pin numbers (texts beside the wire that belong to no other wire)
        near = _near_pin_texts(ctx, n)
        if near:
            lines.append("Beside the wire: " + "; ".join(near) + ".")
        if by_net_outputs.get(n.id):
            lines.append("Part of the logic for: " + ", ".join(_uniq(by_net_outputs[n.id])[:8]) + ".")
        if card:
            lines.append(f"Sheet context: {ctx.title} (card {card.group(1)}).")
        out[str(n.id)] = {"title": title, "lines": lines, "kind": _net_kind(ctx, labels)}
    return out


def _near_pin_texts(ctx: _Ctx, n: Net, tol: float = 4.5) -> list[str]:
    """Pin numbers written beside a wire (FASTON pins on the card sheets), grouped by their row caption."""
    if ctx.kind == "fld":
        return []
    found: list[tuple[float, str, str]] = []
    bb = (n.bbox[0] - tol, n.bbox[1] - tol, n.bbox[2] + tol, n.bbox[3] + tol)
    circle_texts = {c["text"] for c in ctx.circles if c.get("text")}
    for t in ctx.sheet.texts:
        if t.frame or t.id in ctx.text_net or t.id in ctx.text_shape or len(t.text) > 6 or t.id in circle_texts:
            continue
        s = t.text.strip()
        if not re.fullmatch(r"\d{1,2}|[a-z]\d{1,2}", s):
            continue
        if not (bb[0] <= t.bbox[0] and t.bbox[2] <= bb[2] and bb[1] <= t.bbox[1] and t.bbox[3] <= bb[3]):
            continue
        d = min(_seg_box_dist(ctx.segs[i], t.bbox) for i in n.segments if i in ctx.segs)
        if d > tol:
            continue
        # a row caption to the left (FASTON CONNECTORS AT FRONT OF CARD)
        cap = []
        cy = _center(t.bbox)[1]
        for c in ctx.sheet.texts:
            if c.frame or c is t or len(c.text) < 4 or c.bbox[2] > t.bbox[0] or t.bbox[0] - c.bbox[2] > 70:
                continue
            if abs(_center(c.bbox)[1] - cy) <= 10.0 and not ctx.idents.get(c.id):
                cap.append(c)
        cap.sort(key=lambda c: -c.bbox[3])
        caption = " ".join(c.text.strip() for c in cap[:3])
        found.append((t.bbox[0], s, caption))
    found.sort()
    groups: dict[str, list[str]] = {}
    for _x, s, caption in found[:12]:
        groups.setdefault(caption, []).append(s)
    return [("pin " if len(v) == 1 else "pins ") + ", ".join(v) + (f" ({k})" if k else "") for k, v in groups.items()]


# ----------------------------------------------------------------------------- summary
def _fuse_facts(ctx: _Ctx) -> list[dict]:
    """Fuses and safeclip links: name, rating, supply side, what the downstream wire carries."""
    out = []
    for sid, info in ctx.info.items():
        if info["kind"] != "device" or not info["fuse"]:
            continue
        rec = {"name": info["fuse"], "rating": info["rating"], "shape": sid, "supply": [], "feeds": [], "pointers": [], "text_ids": list(info["near"])}
        for side in ("T", "L"):
            for nid in info["ports"][side]:
                lab = ctx.net_labels(nid)
                rec["supply"].extend(ctx.txt(i) for i in lab["potentials"])
        for side in ("B", "R"):
            for nid in info["ports"][side]:
                lab = ctx.net_labels(nid)
                rec["feeds"].extend(ctx.txt(i) for i in lab["potentials"] + lab["signals"] + lab["words"] + lab["elco"])
                rec["pointers"].extend(_pointer_words(ctx, i) for i in lab["pointers"])
                for s, _side in ctx.sinks(nid):
                    if ctx.info[s]["kind"] == "label_box" and ctx.info[s]["label"]:
                        rec["feeds"].append(ctx.info[s]["label"])
                rec["text_ids"].extend(lab["text_ids"])
        rec["supply"] = _uniq(rec["supply"])
        rec["feeds"] = _uniq(rec["feeds"])
        rec["pointers"] = _uniq(rec["pointers"])
        out.append(rec)
    out.sort(key=lambda r: (ctx.info[r["shape"]]["bbox"][0], -ctx.info[r["shape"]]["bbox"][3]))
    return out


def _sheet_summary(ctx: _Ctx, logic: list[dict], inputs: list[dict], channels: list[dict]) -> dict:
    kind = ctx.kind
    facts: list[str] = []
    outputs: list[dict] = []
    sid = ctx.sid
    title = ctx.title
    if kind == "fld":
        outs = [e for e in logic if e["kind"] in ("continuation", "converter", "other", "annunciator")]
        cont = [e for e in logic if e["kind"] == "continuation"]
        conv = [e for e in logic if e["kind"] == "converter"]
        dev = [e for e in logic if e["kind"] == "other" and e.get("output_kind") == "process_device"]
        ann = [e for e in logic if e["kind"] == "annunciator"]
        dvs = [e for e in logic if e["kind"] == "dv"]
        inc = [e for e in logic if e["kind"] == "incoming"]
        summary = (f"Functional logic diagram {sid} ({title}). It reads {len(inputs)} field inputs and produces "
                   f"{len(cont)} continuation signals to other sheets, {len(conv)} analogue outputs through converters, "
                   f"{len(dev)} process device outputs and {len(ann)} annunciator windows; {len(dvs)} DeltaV Modbus points are tapped. "
                   f"{len(inc)} signals arrive from other sheets.")
        for e in cont:
            facts.append(f"Output {e['output']} -> sheet {e.get('dest_sheet') or '?'}: {_short(e['expr'])}" + (f" (link {e['link_status']})" if e.get("link_status") else ""))
        for e in conv + dev:
            d = e.get("device") or {}
            facts.append(f"Output {e['output']}" + (f" ({d.get('desc')})" if d.get("desc") else "") + f": {_short(e['expr'])}")
        for e in ann:
            facts.append(f"Annunciator {e['output']}: {_short(e['expr'])}")
        for e in inc:
            facts.append(f"Signal {e['output']} arrives from sheet {e.get('from_sheet') or '?'} and feeds {e.get('feeds_text') or 'nothing drawn'}" + (f"; used in {', '.join(e['used_in'])}" if e.get("used_in") else "") + ".")
        if dvs:
            facts.append("DeltaV points: " + ", ".join(f"{e['output']} = {_short(e['expr'], 80)}" for e in dvs) + ".")
        for r in inputs:
            facts.append(f"Input {r['tag']}" + (f" {r['desc']}" if r.get("desc") else "") + (f", LOOP TYPE {r['loop_type']}" if r.get("loop_type") else "")
                         + (f", cable {r['cable']}" if r.get("cable") else "") + (f" terminals {r['terminals']}" if r.get("terminals") else "")
                         + (f", read by {', '.join(m['label'] for m in r['modules'])}" if r.get("modules") else "")
                         + (f", wired to {', '.join(r['feeds'])}" if r.get("feeds") and not r.get("modules") else "")
                         + (f", signals {', '.join(r['signals'])}" if r.get("signals") else "") + ".")
        outputs = [{"output": e["output"], "kind": e["kind"], "dest_sheet": e.get("dest_sheet"), "expr": e["expr"]} for e in outs]
    elif kind in ("card", "power"):
        fuses = _fuse_facts(ctx)
        card = re.search(r"CARD\s+(\d{3,4})", title.upper())
        head = f"Distribution card {card.group(1)}" if card else "Power distribution sheet"
        summary = f"{head} {sid} ({title}): {len(fuses)} fuses or links are drawn."
        for f in fuses:
            s = f"{'Link' if f['name'].upper().startswith('LINK') else 'Fuse'} {f['name']}" + (f" ({f['rating']})" if f["rating"] else "")
            if f["supply"]:
                s += f", supply side {', '.join(f['supply'])}"
            if f["feeds"]:
                s += f", feeds {', '.join(f['feeds'][:6])}"
            if f["pointers"]:
                s += f"; {'; '.join(f['pointers'])}"
            facts.append(s + ".")
            outputs.append({"output": f["name"], "kind": "fuse", "dest_sheet": None, "expr": ", ".join(f["feeds"][:6])})
        inputs = [{"label": f["name"], "supply": f["supply"], "shape": f["shape"]} for f in fuses if f["supply"]]
        ptrs = [t for t in ctx.sheet.texts if not t.frame and XREF_RE.match(t.text.strip())]
        if ptrs:
            dests = sorted(_uniq(XREF_RE.match(t.text.strip()).group(1) for t in ptrs))
            facts.append(f"{len(ptrs)} explicit pointers to sheets {', '.join(dests)}.")
    elif kind in ("loop_input", "loop_output"):
        tags = sorted(_uniq(t.text.strip() for t in ctx.sheet.texts if not t.frame and any(i.kind == "tag" and i.extra.get("plant") for i in ctx.idents.get(t.id, []))))
        summary = f"Loop drawing {sid} ({title}): {len(channels)} channels read from the module tables, {len(tags)} tags on the sheet."
        for c in channels:
            s = f"Channel {c['channel'] or '?'} of position {c['position']}" + (f" ({c['module']})" if c.get("module") else "")
            if c.get("tag"):
                s += f": {c['tag']}" + (f" {c['desc']}" if c.get("desc") else "")
            if c.get("wire"):
                s += f", wire {c['wire']}"
            if c.get("cable"):
                s += f", cable {c['cable']}"
            if c.get("pins"):
                s += f", pins {'/'.join(c['pins'])}"
            if c.get("potentials"):
                s += f", supply {', '.join(c['potentials'])}"
            facts.append(s + ".")
        if not channels and tags:
            facts.append("Tags: " + ", ".join(tags) + ".")
        inputs = channels
    else:
        counts = defaultdict(set)
        for tid, idents in ctx.idents.items():
            for i in idents:
                counts[i.kind].add(i.key)
        words = {"tag": "tags", "cable": "cables", "elco": "ELCO pins", "connector": "ELCO connectors", "terminal": "terminals",
                 "potential": "potentials", "window": "annunciator windows", "sheet_ref": "drawing references", "loop_type": "loop type pointers"}
        parts = [f"{len(v)} {words[k]}" for k, v in counts.items() if k in words and v]
        summary = f"Sheet {sid} ({title}), kind {kind}: " + (", ".join(parts) if parts else "no identifiers") + "."
        if kind == "typical":
            heads = sorted(_uniq(m.group(1).upper() for t in ctx.sheet.texts if not t.frame for m in [LOOP_TYPE_RE.search(t.text)] if m))
            if heads:
                facts.append("Loop types described: " + ", ".join(heads) + ".")
        refs = [L for L in ctx.links if L.get("kind") == "sheet"]
        if refs:
            facts.append("Refers to sheets: " + ", ".join(sorted(_uniq(str(L.get("dst_sheet")) for L in refs))) + ".")
    return {"kind": kind, "summary": summary, "facts": facts, "inputs": inputs, "outputs": outputs}


def sheet_summary(sheet: SheetData, nets: NetResult, links=None, logic: Optional[list[dict]] = None, sheet_meta=None) -> dict:
    ctx = _Ctx(sheet, nets, links, sheet_meta)
    if logic is None:
        logic = _fld_logic(ctx) if ctx.kind == "fld" else []
    inputs = _fld_inputs(ctx, logic) if ctx.kind == "fld" else []
    channels = _loop_channels(ctx) if ctx.kind in ("loop_input", "loop_output") else []
    return _sheet_summary(ctx, logic, inputs, channels)


def net_explanations(sheet: SheetData, nets: NetResult, links=None, sheet_meta=None) -> dict[str, dict]:
    ctx = _Ctx(sheet, nets, links, sheet_meta)
    logic = _fld_logic(ctx) if ctx.kind == "fld" else []
    return _net_explanations(ctx, logic)


# ----------------------------------------------------------------------------- text notes
def _text_notes(ctx: _Ctx, logic: list[dict], inputs: list[dict], net_words: dict[str, dict], channels: list[dict]) -> dict[str, dict]:
    notes: dict[str, dict] = {}

    def add(tid: Optional[str], title: str, lines: list[str]) -> None:
        if not tid or tid not in ctx.texts:
            return
        if tid in notes:
            for ln in lines:
                if ln not in notes[tid]["lines"]:
                    notes[tid]["lines"].append(ln)
            return
        notes[tid] = {"title": title, "lines": list(lines)}

    # FLD inputs: tag, caption, loop type, cable
    for r in inputs:
        lines = []
        if r.get("desc"):
            lines.append(f"Service: {r['desc']}.")
        if r.get("device"):
            lines.append(f"Console device {r['device']}" + (f", {r['location']}" if r.get("location") else "") + ".")
        if r.get("loop_type"):
            lt_text = next((i for i in r["text_ids"] if LOOP_TYPE_RE.search(ctx.txt(i))), None)
            L = ctx.typical_by_src.get(lt_text) if lt_text else None
            lines.append(f"LOOP TYPE {r['loop_type']}" + (f": typical loop drawing on sheet {L['dst_sheet']}" if L and L.get("dst_sheet") else "") + ".")
        if r.get("cable"):
            lines.append(f"Cable {r['cable']}" + (f", terminals {r['terminals']}" if r.get("terminals") else "") + ".")
        if r.get("modules"):
            lines.append("Read by " + ", ".join(m["label"] for m in r["modules"]) + ".")
        if r.get("signals"):
            lines.append("Software signals: " + ", ".join(r["signals"]) + ".")
        if r.get("outputs"):
            lines.append("Takes part in: " + ", ".join(r["outputs"]) + ".")
        else:
            lines.append("Not traced into any output on this sheet.")
        title = f"{r['tag']}" + (f" {r['desc']}" if r.get("desc") else "")
        for tid in r["text_ids"]:
            add(tid, title, lines)
    # logic entries: labels, pointers, taps, windows
    for e in logic:
        if e["kind"] == "continuation":
            title = f"{e['output']} -> sheet {e.get('dest_sheet') or '?'}"
            lines = [f"Continuation signal leaving this sheet" + (f" to sheet {e['dest_sheet']}" if e.get("dest_sheet") else "") + (f" (link {e['link_status']})" if e.get("link_status") else "") + ".",
                     f"Logic: {e['expr']}." if e.get("expr") else "Not connected to any logic on this sheet."]
            if e.get("taps"):
                lines.append("DeltaV taps on this output: " + ", ".join(t["label"] for t in e["taps"]) + ".")
        elif e["kind"] == "incoming":
            title = f"{e['output']} from sheet {e.get('from_sheet') or '?'}"
            lines = [f"Signal arriving from sheet {e.get('from_sheet') or '?'}" + (f" (link {e['link_status']})" if e.get("link_status") else "") + ".",
                     f"Feeds: {e.get('feeds_text') or 'nothing drawn'}."]
            if e.get("used_in"):
                lines.append("Used in outputs: " + ", ".join(e["used_in"]) + ".")
        elif e["kind"] == "dv":
            if e.get("text") in notes:
                continue                                  # already described as a tap of an output
            title = f"DeltaV point {e['output']}"
            lines = [f"Modbus tap on the wire: {e['expr']}." if e.get("expr") else "Tap is not within 4 mm of a wire."]
        elif e["kind"] == "annunciator":
            title = f"Annunciator window {e['output']}"
            lines = [f"Driven by: {e['expr']}."]
        elif e["kind"] == "converter":
            d = e.get("device") or {}
            title = f"{e['output']} output"
            lines = [f"Analogue output through {ctx.info[e['shape']]['label']}: {e['expr']}."]
            if e.get("signal_in") or e.get("signal_out"):
                lines.append(f"Converter input {e.get('signal_in') or '?'}, output {e.get('signal_out') or '?'}.")
            if d.get("cable"):
                lines.append(f"Cable {d['cable']}" + (f", terminals {d['terminals']}" if d.get("terminals") else "") + ".")
            if d.get("loop_type"):
                lines.append(f"LOOP TYPE {d['loop_type']}.")
        else:
            d = e.get("device") or {}
            title = f"{e['output']} output"
            lines = [f"Process device output: {e['expr']}."]
            if e.get("via"):
                lines.append("Through: " + ", ".join(_uniq(e["via"])) + ".")
            if d.get("desc"):
                lines.append(f"Service: {d['desc']}.")
            if d.get("cable"):
                lines.append(f"Cable {d['cable']}" + (f", terminals {d['terminals']}" if d.get("terminals") else "") + ".")
            if d.get("loop_type"):
                lines.append(f"LOOP TYPE {d['loop_type']}.")
        own = [e.get("text")] if e.get("text") else []
        own += list(ctx.info[e["shape"]]["text_ids"]) if e.get("shape") is not None and e["shape"] in ctx.info else []
        if e.get("pointer_text"):
            own.append(e["pointer_text"])
        d = e.get("device") or {}
        own += d.get("text_ids", [])[:1]
        for tid in own:
            add(tid, title, lines)
        if e.get("taps") and e["kind"] in ("continuation", "converter", "other", "annunciator"):
            for tp in e["taps"]:
                add(tp["text"], f"DeltaV point {tp['label']}", [f"Modbus tap on the output {e['output']}: {e['expr']}."])
    # modules reading the inputs
    for r in inputs:
        for m in r.get("modules") or []:
            lines = [f"Reads {r['tag']}" + (f" {r['desc']}" if r.get("desc") else "") + (f", LOOP TYPE {r['loop_type']}" if r.get("loop_type") else "") + "."]
            if r.get("signals"):
                lines.append("Output signals: " + ", ".join(r["signals"]) + ".")
            if r.get("outputs"):
                lines.append("Takes part in: " + ", ".join(r["outputs"]) + ".")
            for tid in ctx.info[m["shape"]]["text_ids"]:
                add(tid, f"{m['label']} module", lines)
    # gates, timers and converters: their logic and what they feed
    in_entries: dict[int, list[str]] = defaultdict(list)
    for e in logic:
        if e["kind"] != "incoming":
            for sid in e.get("shape_ids", []):
                in_entries[sid].append(e["output"])
    for sid, info in ctx.info.items():
        if info["kind"] not in ("gate", "timer", "converter") or not info["text_ids"]:
            continue
        outs = ctx.output_nets(sid)
        node = ctx.node_for(sid, outs[0] if outs else None, (sid,))
        lines = [f"Logic: {_short(expr_of(node), 300)}."]
        goes = []
        for on in outs:
            for s, _side in ctx.sinks(on):
                goes.append(ctx.shape_words(s))
            for c in ctx.net_circles.get(on, []):
                goes.append(f"{c['kind']} {c['label']}".strip())
        if goes:
            lines.append("Output goes to: " + "; ".join(_uniq(goes)) + ".")
        if in_entries.get(sid):
            lines.append("Takes part in: " + ", ".join(_uniq(in_entries[sid])) + ".")
        for tid in info["text_ids"]:
            add(tid, ctx.shape_words(sid), lines)
    # signal names and limit words on wires: from the net words
    for tid, nid in ctx.text_net.items():
        t = ctx.texts.get(tid)
        if t is None or t.frame:
            continue
        kinds = {i.kind for i in ctx.idents.get(tid, [])}
        if not (kinds & {"tag", "potential", "terminal", "cable", "elco", "xref"}) and t.text.strip().upper() not in LIMIT_WORDS:
            continue
        w = net_words.get(str(nid))
        if not w:
            continue
        add(tid, w["title"] if w["title"] != "unlabelled wire" else t.text, w["lines"])
    # fuse names and ratings
    fuse_by_shape = {f["shape"]: f for f in _fuse_facts(ctx)}
    for sid, info in ctx.info.items():
        if info["kind"] == "device" and info["fuse"]:
            f = fuse_by_shape.get(sid)
            if not f:
                continue
            lines = []
            if f["supply"]:
                lines.append("Supply side: " + ", ".join(f["supply"]) + ".")
            if f["feeds"]:
                lines.append("Feeds: " + ", ".join(f["feeds"][:8]) + ".")
            lines.extend(p + "." for p in f["pointers"])
            for tid in info["near"]:
                add(tid, f"{'Link' if f['name'].upper().startswith('LINK') else 'Fuse'} {f['name']}" + (f" ({f['rating']})" if f["rating"] else ""), lines or ["No wire is drawn on either side."])
    # loop channels
    for c in channels:
        title = f"{c.get('tag') or 'channel'}: position {c['position']} channel {c.get('channel') or '?'}"
        lines = []
        if c.get("desc"):
            lines.append(f"Service: {c['desc']}.")
        if c.get("module"):
            lines.append(f"Module {c['module']}, position {c['position']}, channel {c.get('channel') or '?'}" + (f", pins {'/'.join(c['pins'])}" if c.get("pins") else "") + ".")
        if c.get("wire"):
            lines.append(f"Wire number {c['wire']} (card position / channel).")
        if c.get("cable"):
            lines.append(f"Field cable {c['cable']}.")
        if c.get("potentials"):
            lines.append("Supply: " + ", ".join(c["potentials"]) + ".")
        if c.get("plug"):
            lines.append(f"I/O plug {c['plug']}.")
        for tid in c["text_ids"]:
            add(tid, title, lines)
    # typical loop pointers
    for tid, L in ctx.typical_by_src.items():
        if L.get("dst_sheet"):
            add(tid, ctx.txt(tid), [f"Typical loop drawing for {L.get('label') or ctx.txt(tid)}: sheet {L['dst_sheet']}."])
    return notes


# ----------------------------------------------------------------------------- entry point
def explain_sheet(sheet: SheetData, nets: Optional[NetResult], links=None, sheet_meta=None) -> dict:
    """All drawing-derived explanations of one sheet (stored as sheet JSON key 'explain')."""
    ctx = _Ctx(sheet, nets, links, sheet_meta)
    result = {"kind": ctx.kind, "summary": "", "facts": [], "inputs": [], "outputs": [], "logic": [], "nets": {}, "texts": {},
              "shapes": {}, "warnings": []}
    logic: list[dict] = []
    inputs: list[dict] = []
    channels: list[dict] = []
    try:
        result["shapes"] = {str(sid): {"kind": info["kind"], "label": info["label"], **({"fuse": info["fuse"]} if info["fuse"] else {}),
                                       **({"rating": info["rating"]} if info["rating"] else {})} for sid, info in ctx.info.items()}
    except Exception as exc:                      # pragma: no cover - defensive
        ctx.warnings.append(f"shape classification failed: {exc}")
    if ctx.kind == "fld":
        try:
            logic = _fld_logic(ctx)
        except Exception as exc:
            ctx.warnings.append(f"logic tracing failed: {exc}")
        try:
            inputs = _fld_inputs(ctx, logic)
        except Exception as exc:
            ctx.warnings.append(f"input listing failed: {exc}")
    if ctx.kind in ("loop_input", "loop_output"):
        try:
            channels = _loop_channels(ctx)
        except Exception as exc:
            ctx.warnings.append(f"loop table reading failed: {exc}")
    result["logic"] = logic
    try:
        result["nets"] = _net_explanations(ctx, logic)
    except Exception as exc:
        ctx.warnings.append(f"net explanations failed: {exc}")
    try:
        summ = _sheet_summary(ctx, logic, inputs, channels)
        result.update(summ)
    except Exception as exc:
        ctx.warnings.append(f"summary failed: {exc}")
    try:
        result["texts"] = _text_notes(ctx, logic, inputs, result["nets"], channels)
    except Exception as exc:
        ctx.warnings.append(f"text notes failed: {exc}")
    result["circles"] = ctx.circles
    result["warnings"] = ctx.warnings
    return result
