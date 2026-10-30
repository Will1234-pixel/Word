"""Drawing glossary, caption groups and the per-identifier dossier.

Three things live here:

* ``glossary_lookup(text)`` explains the identifier vocabulary of this drawing
  set from ``engine/glossary.json`` (anchored regular expressions, each entry
  naming the sheet or document it comes from).
* ``label_groups(sheet)`` / ``context(sheet, text_id)`` join the multi-line
  captions drafters write as separate text entities ('Nitric Acid' /
  '03FZT03002' / 'LOOP TYPE AI1').
* ``build_dossier(records)`` collects, for every connection identifier, what
  the text is on each sheet (its role) and the drawing texts around it, and
  assembles a plain-word summary from those texts and the glossary.

Principles: every statement is traceable to text or geometry on the drawings;
plant behaviour that is not drawn is never inferred; uncertain cases are said
to be uncertain ("unlabelled wire").
"""
from __future__ import annotations

import json
import math
import os
import re
from collections import defaultdict
from typing import Iterable, Optional

from .dxf_reader import SheetData, TextItem
from .identifiers import Ident, XREF_RE, classify, is_connection_kind

GLOSSARY_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "glossary.json")

# label grouping (task definition): stacked lines overlap by >= 30 % of the
# narrower line and are separated by at most 0.9 x the text height
GROUP_OVERLAP = 0.30
GROUP_GAP = 0.9
GROUP_HEIGHT_RATIO = 2.2      # lines of one caption have similar heights
NET_TEXT_TOL = 3.0            # mm, DeltaV taps and limit words sit up to 3 mm from their wire
TERMINAL_LABEL_GAP = 2.5      # mm, a cable label written just left of a terminal circle
ROW_TOL = 1.5                 # mm, same-row tolerance on the FLD columns
SCHEDULE_COL_TOL = 2.6        # mm, same column of a rotated schedule table
LIMIT_WORDS = {"HIGH", "HIHI", "HI HI", "LOW", "LOLO", "LO LO", "MID", "EXTRA HIGH"}

DOSSIER_KINDS = ("tag", "cable", "elco", "terminal", "potential", "dv", "window", "signal", "link", "tb", "connector")

_GLOSSARY: Optional[list[tuple[re.Pattern, dict]]] = None


# =============================================================================
# glossary
# =============================================================================
def load_glossary(path: str = GLOSSARY_PATH) -> list[tuple[re.Pattern, dict]]:
    """Compile the glossary once; entries keep their order from the file."""
    global _GLOSSARY
    if _GLOSSARY is None or path != GLOSSARY_PATH:
        with open(path, encoding="utf-8") as fh:
            entries = json.load(fh)
        compiled = []
        for e in entries:
            flags = re.I if e.get("ignore_case") else 0
            compiled.append((re.compile(e["pattern"], flags), e))
        if path == GLOSSARY_PATH:
            _GLOSSARY = compiled
        return compiled
    return _GLOSSARY


def _fill(template: str, m: re.Match) -> str:
    out = template
    for gi in range(1, (m.re.groups or 0) + 1):
        out = out.replace("{%d}" % gi, m.group(gi) or "")
    return " ".join(out.split())


def glossary_lookup(text: str, kinds: Optional[Iterable[str]] = None) -> list[dict]:
    """Glossary entries whose anchored pattern matches *text* (whole text).

    Returns copies of the entries with ``term`` and ``meaning`` filled in from
    the matched groups and with the original ``pattern``.  ``kinds`` limits the
    result to entries of those glossary kinds (e.g. ``("tag_letter",)``).
    """
    t = " ".join((text or "").split())
    if not t:
        return []
    want = set(kinds) if kinds else None
    out = []
    for rx, e in load_glossary():
        if want and e.get("kind") not in want:
            continue
        m = rx.match(t)
        if not m:
            continue
        d = dict(e)
        d["term"] = _fill(e["term"], m)
        d["meaning"] = _fill(e["meaning"], m)
        if "word" in e:
            d["word"] = _fill(e["word"], m)
        if "letter" in e:
            d["letter"] = _fill(e["letter"], m)
        d["text"] = t
        out.append(d)
    return out


def tag_words(text: str) -> dict:
    """Decode a tag into the words the glossary supports: plant, variable,
    trip flag, device, suffix, qualifier.  Only letters evidenced on the
    drawings get a plain word; others carry the ISA convention wording."""
    res = {"plant": "", "variable": "", "trip": False, "device": "", "suffix": "", "qualifier": "", "letters": []}
    for e in glossary_lookup(text, kinds=("tag_plant", "tag_letter", "tag_suffix", "tag_qualifier")):
        k = e.get("kind")
        if k == "tag_plant":
            res["plant"] = e.get("letter", "")
        elif k == "tag_letter":
            res["letters"].append((e.get("letter"), e.get("word"), e.get("evidence")))
            pos = e.get("position")
            if pos == "first":
                res["variable"] = e.get("word", "")
            elif pos == "middle":
                res["trip"] = True
            elif pos == "last":
                # 'RT' is more specific than 'T'
                if not res["device"] or len(e.get("letter", "")) > 1:
                    res["device"] = e.get("word", "")
        elif k == "tag_suffix":
            res["suffix"] = e.get("letter", "")
        elif k == "tag_qualifier":
            res["qualifier"] = e.get("word", "")
    return res


def describe_tag(text: str) -> str:
    """Short plain-word reading of a tag: 'flow transmitter (trip)'."""
    w = tag_words(text)
    parts = []
    if w["variable"]:
        parts.append(w["variable"])
    if w["device"]:
        parts.append(w["device"])
    s = " ".join(parts)
    if w["trip"]:
        s = (s + " (trip)") if s else "trip function"
    if w["suffix"]:
        s += f", limit {w['suffix']}"
    if w["qualifier"]:
        s += f", {w['qualifier']}"
    return s


# =============================================================================
# geometry helpers
# =============================================================================
def _center(b) -> tuple[float, float]:
    return ((b[0] + b[2]) / 2.0, (b[1] + b[3]) / 2.0)


def _overlap(a0, a1, b0, b1) -> float:
    return min(a1, b1) - max(a0, b0)


def _rot_class(t: TextItem) -> str:
    r = round(float(t.rotation or 0.0)) % 180
    return "v" if 45 <= r < 135 else "h"


def _pt_seg_dist(px, py, x1, y1, x2, y2) -> float:
    dx, dy = x2 - x1, y2 - y1
    L2 = dx * dx + dy * dy
    if L2 <= 1e-12:
        return math.hypot(px - x1, py - y1)
    t = max(0.0, min(1.0, ((px - x1) * dx + (py - y1) * dy) / L2))
    return math.hypot(px - (x1 + t * dx), py - (y1 + t * dy))


def _seg_box_dist(x1, y1, x2, y2, b) -> float:
    """Distance between a segment and an axis-aligned box (0 when touching)."""
    def inside(x, y):
        return b[0] - 1e-9 <= x <= b[2] + 1e-9 and b[1] - 1e-9 <= y <= b[3] + 1e-9
    if inside(x1, y1) or inside(x2, y2):
        return 0.0
    edges = [(b[0], b[1], b[2], b[1]), (b[2], b[1], b[2], b[3]), (b[2], b[3], b[0], b[3]), (b[0], b[3], b[0], b[1])]
    best = math.inf
    for ex1, ey1, ex2, ey2 in edges:
        if _segments_cross(x1, y1, x2, y2, ex1, ey1, ex2, ey2):
            return 0.0
        best = min(best, _pt_seg_dist(x1, y1, ex1, ey1, ex2, ey2), _pt_seg_dist(x2, y2, ex1, ey1, ex2, ey2),
                   _pt_seg_dist(ex1, ey1, x1, y1, x2, y2), _pt_seg_dist(ex2, ey2, x1, y1, x2, y2))
    return best


def _segments_cross(ax, ay, bx, by, cx, cy, dx, dy) -> bool:
    def orient(px, py, qx, qy, rx, ry):
        v = (qx - px) * (ry - py) - (qy - py) * (rx - px)
        return 0 if abs(v) < 1e-12 else (1 if v > 0 else -1)
    o1, o2 = orient(ax, ay, bx, by, cx, cy), orient(ax, ay, bx, by, dx, dy)
    o3, o4 = orient(cx, cy, dx, dy, ax, ay), orient(cx, cy, dx, dy, bx, by)
    return o1 != o2 and o3 != o4


# =============================================================================
# label groups
# =============================================================================
def _ident_kinds(text: str) -> set[str]:
    kinds = set()
    t = text.strip()
    if XREF_RE.match(t):
        kinds.add("xref")
    if re.search(r"-\s*W\d{1,2}$", t):
        kinds.add("window")          # ELCO schedule entry 'SPARE - W08', 'FZA 03002 - W01'
    for i in classify(t):
        if is_connection_kind(i.kind) or i.kind in ("xref", "module"):
            kinds.add(i.kind)
    return kinds


def label_groups(sheet: SheetData, texts: Optional[list[TextItem]] = None) -> list[dict]:
    """Multi-line captions: non-frame texts stacked along their reading
    direction (horizontal overlap >= 30 % of the narrower line, gap <= 0.9 x
    the text height).  Rotated texts stack sideways and are grouped the same
    way along x.  Two lines that are both connection identifiers of the same
    kind (two terminals, two ELCO pins, two schedule entries) are table cells,
    not a caption, and are not joined; neither are two bare one- or two-
    character cells.

    Returns ``[{id, text_ids, lines, bbox, rotation}]``, top-to-bottom lines,
    groups sorted top-to-bottom / left-to-right.  Single texts are not
    returned as groups.
    """
    items = [t for t in (texts if texts is not None else sheet.texts) if not t.frame]
    parent = {t.id: t.id for t in items}

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra

    kinds = {t.id: _ident_kinds(t.text) for t in items}
    cells = {t.id: bool(re.fullmatch(r"[A-Za-z0-9]{1,2}", t.text.strip())) for t in items}
    by_class: dict[str, list[TextItem]] = {"h": [], "v": []}
    for t in items:
        by_class[_rot_class(t)].append(t)

    for cls, lst in by_class.items():
        if cls == "h":
            # stacking axis y (top first), lateral axis x
            lst.sort(key=lambda t: (-t.bbox[3], t.bbox[0]))
            def stack(t):      # (near edge towards the next line, far edge)
                return t.bbox[1], t.bbox[3]
            def lateral(t):
                return t.bbox[0], t.bbox[2]
        else:
            # rotated text stacks sideways (the lines of a rotated caption follow
            # each other along x)
            lst.sort(key=lambda t: (t.bbox[0], -t.bbox[3]))
            def stack(t):
                return -t.bbox[2], -t.bbox[0]
            def lateral(t):
                return t.bbox[1], t.bbox[3]
        n = len(lst)
        for i in range(n):
            a = lst[i]
            a_lo, a_hi = stack(a)
            al0, al1 = lateral(a)
            ha = max(a.height, 0.5)
            for j in range(i + 1, n):
                b = lst[j]
                b_lo, b_hi = stack(b)
                hb = max(b.height, 0.5)
                gap = a_lo - b_hi            # b follows a in reading order
                # nominal text height plus 0.1 mm of drafting slack
                if gap > GROUP_GAP * max(ha, hb) + 0.1:
                    if cls == "h" and (a_lo - b_hi) > GROUP_GAP * 6:
                        break                # sorted: nothing further can be close
                    continue
                if gap < -0.6 * min(ha, hb):
                    continue                 # overlapping or side by side, not stacked
                bl0, bl1 = lateral(b)
                ov = _overlap(al0, al1, bl0, bl1)
                if ov <= 0 or ov / max(1e-6, min(al1 - al0, bl1 - bl0)) < GROUP_OVERLAP:
                    continue
                if max(ha, hb) / min(ha, hb) > GROUP_HEIGHT_RATIO:
                    continue
                if kinds[a.id] & kinds[b.id]:
                    continue                 # two identifiers of one kind: a list / table, not a caption
                if cells[a.id] and cells[b.id]:
                    continue                 # two bare table cells
                union(a.id, b.id)

    members: dict[str, list[TextItem]] = defaultdict(list)
    for t in items:
        members[find(t.id)].append(t)
    groups = []
    for root, ts in members.items():
        if len(ts) < 2:
            continue
        cls = _rot_class(ts[0])
        if cls == "h":
            ts.sort(key=lambda t: (-round(t.bbox[3], 1), t.bbox[0]))
        else:
            ts.sort(key=lambda t: (round(t.bbox[0], 1), -t.bbox[3]))
        for part in _split_at_gap_jumps(ts, cls, kinds):
            if len(part) < 2:
                continue
            bbox = (min(t.bbox[0] for t in part), min(t.bbox[1] for t in part), max(t.bbox[2] for t in part), max(t.bbox[3] for t in part))
            groups.append({"id": "", "text_ids": [t.id for t in part], "lines": [t.text for t in part],
                           "bbox": tuple(round(v, 3) for v in bbox), "rotation": 90 if cls == "v" else 0})
    groups.sort(key=lambda g: (-g["bbox"][3], g["bbox"][0]))
    for k, g in enumerate(groups):
        g["id"] = f"g{k}"
    return groups


def _split_at_gap_jumps(ts: list[TextItem], cls: str, kinds: dict[str, set]) -> list[list[TextItem]]:
    """Separate captions drafted one under the other with only a little more
    space than between the lines of one caption: a gap more than 2.5 x the
    smallest gap of the chain (and 0.8 mm wider) ends the caption.  A gap
    next to a tag line is left alone: the oval drawn round a tag widens the
    spacing on both sides of it."""
    if len(ts) < 3:
        return [ts]
    gaps = []
    for a, b in zip(ts, ts[1:]):
        if cls == "h":
            gaps.append(a.bbox[1] - b.bbox[3])
        else:
            gaps.append(b.bbox[0] - a.bbox[2])
    gmin = max(min(gaps), 0.05)
    parts: list[list[TextItem]] = [[ts[0]]]
    for i, (g, t) in enumerate(zip(gaps, ts[1:])):
        near_tag = "tag" in kinds.get(ts[i].id, ()) or "tag" in kinds.get(t.id, ())
        if g > 2.5 * gmin and g - gmin > 0.8 and not near_tag:
            parts.append([t])
        else:
            parts[-1].append(t)
    return parts


def group_index(groups: list[dict]) -> dict[str, dict]:
    idx = {}
    for g in groups:
        for tid in g["text_ids"]:
            idx[tid] = g
    return idx


def context(sheet: SheetData, text_id: str, groups: Optional[list[dict]] = None) -> list[str]:
    """The other caption lines of the group a text belongs to, top to bottom
    (empty when the text stands alone)."""
    if groups is None:
        groups = label_groups(sheet)
    for g in groups:
        if text_id in g["text_ids"]:
            return [ln for tid, ln in zip(g["text_ids"], g["lines"]) if tid != text_id]
    return []


# =============================================================================
# sheet kinds, FLD columns, loop cells, schedule rows
# =============================================================================
def sheet_kind(title: str) -> str:
    t = (title or "").upper()
    if t.startswith("FLD") or "FUNCTIONAL LOGIC" in t:
        return "fld"
    if "TYPICAL" in t:
        return "typical"
    if "LOOP DRAWING" in t or t.startswith("LOOP"):
        return "loop_out" if "OUTPUT" in t else "loop_in"
    if "ELCO" in t:
        return "elco"
    if "ANNUNCIATOR WIRING" in t:
        return "annunciator"
    if "CONTROL PLATE WIRING" in t:
        return "control_plate"
    if "POWER DISTRIBUTION" in t:
        return "power"
    if "DISTRIBUTION CARD" in t:
        return "card"
    if "PSU" in t or "POWER SUPPLY" in t:
        return "psu"
    if "MAIN SCHEMATIC" in t:
        return "main_schematic"
    if "COMMUNICATION" in t:
        return "comms"
    if "DOCUMENT SCHEDULE" in t or "SCHEDULE" in t or "INDEX" in t or "CONTENTS" in t:
        return "document_schedule"
    if any(w in t for w in ("LAYOUT", "G.A.", "DETAILS", "LABEL", "PLAN VIEW", "STRIPS")):
        return "layout"
    return "other"


SHEET_KIND_WORDS = {
    "fld": "FLD", "typical": "typical loop drawing", "loop_in": "loop drawing (inputs)", "loop_out": "loop drawing (outputs)",
    "elco": "ELCO schedule", "annunciator": "annunciator wiring", "control_plate": "control plate wiring",
    "power": "power distribution", "card": "F7133 distribution card", "psu": "PSU wiring", "main_schematic": "main power schematic",
    "comms": "communication wiring", "document_schedule": "document schedule", "layout": "cabinet layout", "other": "drawing",
}

_FLD_HEADERS = {
    "CABLE & TERMINALS": ("CABLE &", "TERMINALS"), "FIELD": ("FIELD",), "ANNUN/CONSOLE": ("ANNUN/CONSOLE",),
    "O/R": ("O/R",), "INPUT NON-I.S.": ("INPUT", "NON-I.S."), "DELTA V MODBUS": ("DELTA V", "MODBUS"), "LOGIC": ("LOGIC",),
    "OUTPUT NON-I.S.": ("OUTPUT", "NON-I.S."), "I.S.": ("I.S.",), "PROCESS DEVICE TAG No.": ("PROCESS DEVICE", "TAG No."),
}


def fld_columns(sheet: SheetData) -> list[dict]:
    """Columns of a Functional Logic Diagram from its header texts (the header
    band is part of the drawing frame).  Returns ``[{name, xmin, xmax, x}]``
    ordered left to right; ``xmin/xmax`` are the header text extent, the
    boundary between two columns is taken halfway between their headers."""
    top = sheet.frame_rect[3] if sheet.frame_rect else sheet.extents[3]
    hdr = [t for t in sheet.texts if t.bbox[1] > top - 16 and t.bbox[3] <= top + 1 and not re.fullmatch(r"\d{2,3}", t.text)]
    if not hdr:
        return []
    cols: list[dict] = []
    used: set[str] = set()
    for t in sorted(hdr, key=lambda t: t.bbox[0]):
        if t.id in used:
            continue
        word = t.text.strip()
        name = None
        for cname, words in _FLD_HEADERS.items():
            if word.upper() == words[0]:
                name = cname
                break
        if name is None:
            continue
        xmin, xmax = t.bbox[0], t.bbox[2]
        used.add(t.id)
        # a second header line directly below (TERMINALS, MODBUS, TAG No., NON-I.S.)
        for u in hdr:
            if u.id in used or u.text.strip().upper() not in [w for w in _FLD_HEADERS[name][1:]]:
                continue
            if _overlap(xmin, xmax, u.bbox[0], u.bbox[2]) > 0 and abs(u.bbox[3] - t.bbox[1]) < 2.5:
                used.add(u.id)
                xmin, xmax = min(xmin, u.bbox[0]), max(xmax, u.bbox[2])
        # INPUT / OUTPUT headers have their sub-column names below them
        if name in ("INPUT NON-I.S.", "OUTPUT NON-I.S."):
            subs = [u for u in hdr if u.id not in used and u.text.strip().upper() == "NON-I.S." and abs(u.bbox[3] - t.bbox[1]) < 2.5
                    and abs(_center(u.bbox)[0] - _center(t.bbox)[0]) < 12]
            for u in subs:
                used.add(u.id)
                xmin, xmax = min(xmin, u.bbox[0]), max(xmax, u.bbox[2])
        cols.append({"name": name, "xmin": xmin, "xmax": xmax, "x": (xmin + xmax) / 2})
    cols.sort(key=lambda c: c["x"])
    # second occurrences (right-hand CABLE & TERMINALS, DELTA V) keep the same name;
    # boundaries half way between neighbouring headers
    for i, c in enumerate(cols):
        c["left"] = (cols[i - 1]["xmax"] + c["xmin"]) / 2 if i > 0 else -math.inf
        c["right"] = (c["xmax"] + cols[i + 1]["xmin"]) / 2 if i + 1 < len(cols) else math.inf
    return cols


def fld_column_of(columns: list[dict], x: float) -> Optional[dict]:
    for c in columns:
        if c["left"] <= x < c["right"]:
            return c
    return None


def loop_cells(sheet: SheetData) -> list[tuple[float, float, float, float]]:
    """A loop drawing holds one loop per quarter of the sheet (left/right,
    upper/lower half of the frame).  Returns the four cell boxes."""
    fr = sheet.frame_rect or sheet.extents
    x0, y0, x1, y1 = fr
    y0 = max(y0, 36.0)                   # the title block strip is not a cell
    mx, my = (x0 + x1) / 2, (y0 + y1) / 2
    return [(x0, my, mx, y1), (mx, my, x1, y1), (x0, y0, mx, my), (mx, y0, x1, my)]


def cell_of(cells, x: float, y: float) -> Optional[int]:
    for i, c in enumerate(cells):
        if c[0] <= x < c[2] and c[1] <= y < c[3]:
            return i
    return None


def schedule_row(sheet: SheetData, text: TextItem, texts: Optional[list[TextItem]] = None) -> list[str]:
    """The row of a rotated schedule table (ELCO schedules): texts standing in
    the same column position as *text*, labelled with the row heading written
    to the left of the table (TERM, PIN, CONTROLS, ESD) and with the table
    captions (VARELCO BLOCK 3/C652, No.3 PLANT ANNUNCIATOR CABINET)."""
    items = [t for t in (texts if texts is not None else sheet.texts) if not t.frame and _rot_class(t) == "v"]
    cx0 = _center(text.bbox)[0]
    aligned = [t for t in items if t.id != text.id and abs(_center(t.bbox)[0] - cx0) <= SCHEDULE_COL_TOL]
    if not aligned:
        return []
    # the data columns of the table are where the terminal numbers stand; the row
    # headings (TERM, PIN, CONTROLS, ESD) form the column just left of them and
    # the table captions stand further left
    num_x = sorted(_center(t.bbox)[0] for t in items if re.fullmatch(r"\d{1,2}", t.text.strip()))
    table_left = num_x[0] if num_x else min(_center(t.bbox)[0] for t in aligned + [text])
    headings = [t for t in items if 2.5 <= table_left - _center(t.bbox)[0] <= 9.0
                and re.fullmatch(r"[A-Z][A-Z.]{1,12}", t.text.strip())]
    captions = [t for t in items if 9.0 < table_left - _center(t.bbox)[0] <= 36.0 and len(t.text) >= 6
                and re.search(r"[A-Za-z]", t.text)]
    out = []
    for t in sorted(aligned, key=lambda t: -t.bbox[3]):
        head = ""
        for h in headings:
            if _overlap(h.bbox[1], h.bbox[3], t.bbox[1], t.bbox[3]) > 0:
                head = h.text.strip()
                break
        out.append(f"{head} {t.text}".strip() if head and head not in t.text else t.text)
    ys = [text.bbox[1], text.bbox[3]] + [v for t in aligned for v in (t.bbox[1], t.bbox[3])]
    for c in sorted(captions, key=lambda t: -t.bbox[0]):
        if _overlap(c.bbox[1], c.bbox[3], min(ys), max(ys)) > 0 and c.text not in out:
            out.append(c.text)
    return out


# =============================================================================
# nets: labels on a conductor, terminal circles
# =============================================================================
def extended_text_net(sheet: SheetData, nets, tol: float = NET_TEXT_TOL, only_kinds: bool = True) -> dict[str, int]:
    """``nets.text_net`` plus the DeltaV taps and limit words that sit up to
    *tol* mm from a conductor (they are written 2 mm clear of their wire)."""
    base = dict(getattr(nets, "text_net", {}) or {})
    if not nets or not getattr(nets, "nets", None):
        return base
    segs = {s.id: s for s in sheet.segments}
    cands = []
    for t in sheet.texts:
        if t.frame or t.id in base:
            continue
        up = t.text.strip().upper()
        if only_kinds and not (re.fullmatch(r"DV\d_\d{1,3}", up) or up in LIMIT_WORDS or re.fullmatch(r"W\d{1,2}", up)):
            continue
        cands.append(t)
    if not cands:
        return base
    for t in cands:
        b = t.bbox
        best, best_net = tol, None
        for n in nets.nets:
            nb = n.bbox
            if nb[0] - tol > b[2] or nb[2] + tol < b[0] or nb[1] - tol > b[3] or nb[3] + tol < b[1]:
                continue
            for sid in n.segments:
                s = segs.get(sid)
                if s is None:
                    continue
                d = _seg_box_dist(s.x1, s.y1, s.x2, s.y2, b)
                if d < best:
                    best, best_net = d, n.id
        if best_net is not None:
            base[t.id] = best_net
    return base


def terminal_circle_label(sheet: SheetData, text: TextItem) -> Optional[tuple[float, float, float]]:
    """A small terminal circle drawn just right of a label at the same height
    (cable labels at the end of a feed on the power sheets)."""
    b = text.bbox
    best = None
    for c in sheet.circles:
        cx, cy, r = c[0], c[1], c[2]
        if r > 2.0 or not (b[1] - 0.5 <= cy <= b[3] + 0.5):
            continue
        gap = (cx - r) - b[2]
        if -0.5 <= gap <= TERMINAL_LABEL_GAP and (best is None or gap < best[3]):
            best = (cx, cy, r, gap)
    return best[:3] if best else None


def net_at_point(sheet: SheetData, nets, x: float, y: float, r: float) -> Optional[int]:
    """The net with a segment end within r of (x, y)."""
    segs = {s.id: s for s in sheet.segments}
    best, best_net = r + 0.35, None
    for n in nets.nets:
        nb = n.bbox
        if nb[0] - r - 0.5 > x or nb[2] + r + 0.5 < x or nb[1] - r - 0.5 > y or nb[3] + r + 0.5 < y:
            continue
        for sid in n.segments:
            s = segs.get(sid)
            if s is None:
                continue
            for px, py in ((s.x1, s.y1), (s.x2, s.y2)):
                d = math.hypot(px - x, py - y)
                if d < best:
                    best, best_net = d, n.id
    return best_net


# =============================================================================
# per-sheet analysis
# =============================================================================
class _SheetView:
    """Everything the dossier needs about one sheet, computed once."""

    def __init__(self, sid: str, rec, title: str):
        self.sid = sid
        self.rec = rec
        self.data: SheetData = rec.data
        self.title = title or self.data.title or ""
        self.kind = sheet_kind(self.title)
        self.texts: dict[str, TextItem] = getattr(rec, "texts", None) or {t.id: t for t in self.data.texts}
        self.idents: dict[str, list[Ident]] = rec.idents or {}
        self.nets = rec.nets
        self.groups = label_groups(self.data)
        self.gidx = group_index(self.groups)
        self.text_net = extended_text_net(self.data, self.nets) if self.nets else {}
        if self.nets and getattr(self.nets, "nets", None):
            # a label written just left of a small terminal circle names the wire
            # ending at that circle, even when the text overlaps another wire
            # (sheet 035: '7/C305-1' crosses the 5L+ wire but labels the 6L+ terminal)
            in_shape = getattr(self.nets, "text_shape", {}) or {}
            for t in self.data.texts:
                if t.frame or t.id in in_shape or _rot_class(t) != "h" or len(t.text) < 2:
                    continue
                c = terminal_circle_label(self.data, t)
                if c is None:
                    continue
                tn = net_at_point(self.data, self.nets, c[0], c[1], c[2])
                if tn is not None:
                    self.text_net[t.id] = tn
        self.net_texts: dict[int, list[str]] = defaultdict(list)
        for tid, nid in self.text_net.items():
            if tid in self.texts:
                self.net_texts[nid].append(tid)
        self._net_shapes: Optional[dict[int, list[int]]] = None
        self.columns = fld_columns(self.data) if self.kind == "fld" else []
        self.cells = loop_cells(self.data) if self.kind in ("loop_in", "loop_out") else []
        self.companions = getattr(rec, "companions", {}) or {}
        self.pointer_of: dict[str, str] = {}
        for xid, comps in self.companions.items():
            for c in comps[:1]:
                self.pointer_of.setdefault(c, xid)
        self._cell_tables: Optional[dict[int, list[dict]]] = None
        self._shape_nets: Optional[dict[int, list[int]]] = None

    # ---- helpers -------------------------------------------------------------
    def lines_of(self, tid: str) -> list[str]:
        return context(self.data, tid, self.groups)

    def group_lines(self, tid: str) -> list[str]:
        g = self.gidx.get(tid)
        return list(g["lines"]) if g else [self.texts[tid].text]

    def group_bbox(self, tid: str):
        g = self.gidx.get(tid)
        return g["bbox"] if g else self.texts[tid].bbox

    def net_labels(self, tid: str, extra: bool = True) -> tuple[Optional[int], list[str]]:
        """Labels on the conductor a text is attached to (other than itself)."""
        nid = self.text_net.get(tid)
        if nid is None:
            return None, []
        labels = [self.texts[o].text for o in self.net_texts.get(nid, []) if o != tid]
        return nid, labels

    def shape_lines(self, sid: int) -> list[str]:
        sh = self.nets.shapes[sid]
        ts = [self.texts[t] for t in sh.get("texts", []) if t in self.texts]
        ts.sort(key=lambda t: (-round(t.bbox[3], 1), t.bbox[0]))      # reading order
        return [t.text for t in ts]

    def shape_nets(self, sid: int, tol: float = 1.0) -> list[int]:
        """Conductors touching a closed symbol: those the net builder registered
        plus any conductor ending within *tol* mm of the symbol's box (an
        output wire often starts a hair outside the drawn outline)."""
        if self._shape_nets is None:
            self._shape_nets = {}
            segs = {s.id: s for s in self.data.segments}
            ends = []
            for n in self.nets.nets:
                for sgid in n.segments:
                    s = segs.get(sgid)
                    if s is not None:
                        ends.append((s.x1, s.y1, n.id))
                        ends.append((s.x2, s.y2, n.id))
            for sh in self.nets.shapes:
                b = sh["bbox"]
                found = list(sh.get("nets", []))
                for x, y, nid in ends:
                    if nid in found:
                        continue
                    if b[0] - tol <= x <= b[2] + tol and b[1] - tol <= y <= b[3] + tol:
                        # near the outline, not deep inside the box
                        inside = b[0] + tol < x < b[2] - tol and b[1] + tol < y < b[3] - tol
                        if not inside:
                            found.append(nid)
                self._shape_nets[sh["id"]] = found
        return self._shape_nets.get(sid, [])

    def net_shapes(self, nid: int) -> list[int]:
        """Closed symbols a conductor reaches (with the 1 mm tolerance)."""
        if self._net_shapes is None:
            rev: dict[int, list[int]] = defaultdict(list)
            for sh in self.nets.shapes:
                for n in self.shape_nets(sh["id"]):
                    rev[n].append(sh["id"])
            self._net_shapes = rev
        return self._net_shapes.get(nid, [])

    def reach_words(self, nid: int, exclude: Iterable[int] = ()) -> list[str]:
        ex = set(exclude)
        words = []
        for s in self.net_shapes(nid):
            if s in ex:
                continue
            w = " ".join(self.shape_lines(s))
            if w and w not in words:
                words.append(w)
        return words

    def trace_through_boxes(self, tid: str) -> dict:
        """From a text inside a closed symbol (tag oval, module box): the
        conductors leaving the symbol, the boxes they reach and the labels on
        the conductors leaving those boxes.  Pure geometry from the nets."""
        res = {"wires": [], "boxes": [], "beyond": []}
        if not self.nets:
            return res
        sid = self.nets.text_shape.get(tid)
        if sid is None:
            return res
        for nid in self.shape_nets(sid):
            labels = [self.texts[o].text for o in self.net_texts.get(nid, []) if o != tid]
            res["wires"].append({"net": nid, "labels": labels})
            for sid2 in self.net_shapes(nid):
                if sid2 == sid:
                    continue
                lines = self.shape_lines(sid2)
                box = {"shape": sid2, "lines": lines, "out": []}
                for nid2 in self.shape_nets(sid2):
                    if nid2 == nid:
                        continue
                    lab2 = [self.texts[o].text for o in self.net_texts.get(nid2, [])]
                    box["out"].append({"net": nid2, "labels": lab2, "reaches": self.reach_words(nid2, (sid, sid2))})
                res["boxes"].append(box)
        return res

    # ---- FLD rows ------------------------------------------------------------
    def fld_row_groups(self, tid: str, col_names: Iterable[str]) -> list[list[str]]:
        """Caption groups in the given FLD columns on the same row as a text
        and on the same side of the sheet (the CABLE & TERMINALS column exists
        on the field side and on the output side)."""
        b = self.group_bbox(tid)
        want = set(col_names)
        mid = (self.data.frame_rect[0] + self.data.frame_rect[2]) / 2 if self.data.frame_rect else 200.0
        right_side = _center(self.texts[tid].bbox)[0] > mid
        out = []
        seen = set()
        for t in self.data.texts:
            if t.frame or t.id == tid:
                continue
            if (_center(t.bbox)[0] > mid) != right_side:
                continue
            col = fld_column_of(self.columns, _center(t.bbox)[0])
            if not col or col["name"] not in want:
                continue
            cy = _center(t.bbox)[1]
            if not (b[1] - ROW_TOL <= cy <= b[3] + ROW_TOL):
                continue
            g = self.gidx.get(t.id)
            key = g["id"] if g else t.id
            if key in seen:
                continue
            seen.add(key)
            out.append(list(g["lines"]) if g else [t.text])
        return out

    # ---- loop drawing cells --------------------------------------------------
    def cell_tables(self) -> dict[int, list[dict]]:
        """Module tables of a loop drawing per cell: module type, position,
        channel, pins, wire number, supply wires, cable, converter."""
        if self._cell_tables is not None:
            return self._cell_tables
        tables: dict[int, list[dict]] = defaultdict(list)
        if not self.cells:
            self._cell_tables = tables
            return tables
        per_cell: dict[int, list[TextItem]] = defaultdict(list)
        for t in self.data.texts:
            if t.frame:
                continue
            ci = cell_of(self.cells, *_center(t.bbox))
            if ci is not None:
                per_cell[ci].append(t)
        for ci, ts in per_cell.items():
            heads = [t for t in ts if t.text.strip().upper() == "POSITION"]
            for h in heads:
                tab = {"module": None, "position": None, "channel": None, "pins": [], "supply_pins": [], "y": _center(h.bbox)[1]}
                hx0, hx1, hy = h.bbox[0], h.bbox[2], h.bbox[1]

                def below(t, x0, x1, dy=7.0, tol=1.5):
                    cx = _center(t.bbox)[0]
                    return (x0 - tol <= cx <= x1 + tol) and (hy - dy <= t.bbox[3] <= hy + 0.3)

                for t in ts:
                    if re.fullmatch(r"1[12]\d{2}", t.text) and below(t, hx0, hx1):
                        tab["position"] = t.text
                # neighbouring headings of the same table row
                row = [t for t in ts if abs(_center(t.bbox)[1] - _center(h.bbox)[1]) < 1.5 and abs(_center(t.bbox)[0] - _center(h.bbox)[0]) < 40]
                for t in row:
                    w = t.text.strip().upper().rstrip(".")
                    if w == "CH":
                        for v in ts:
                            if re.fullmatch(r"\d{1,2}", v.text) and below(v, t.bbox[0], t.bbox[2], tol=1.2):
                                tab["channel"] = v.text
                    elif w == "PIN":
                        for v in ts:
                            if re.fullmatch(r"[zbd]\d{1,2}", v.text) and below(v, t.bbox[0], t.bbox[2], tol=1.2):
                                tab["pins"].append(v.text)
                    elif w == "PINS":
                        for v in ts:
                            if re.fullmatch(r"[zbd]\d{1,2}", v.text) and below(v, t.bbox[0], t.bbox[2], tol=2.5):
                                tab["supply_pins"].append(v.text)
                tab["pins"].sort(key=lambda p: -next(v.bbox[3] for v in ts if v.text == p))
                tab["supply_pins"].sort(key=lambda p: next(v.bbox[0] for v in ts if v.text == p))
                # module type: the HIMA Fxxxx text above the table heading
                mods = [t for t in ts if re.fullmatch(r"(?:HIMA\s+)?F\d{4}", t.text) and 0 <= t.bbox[1] - hy <= 12 and abs(_center(t.bbox)[0] - _center(h.bbox)[0]) < 30]
                if mods:
                    mod = min(mods, key=lambda t: t.bbox[1] - hy)
                    tab["module"] = mod.text
                    words = [t for t in ts if abs(_center(t.bbox)[0] - _center(mod.bbox)[0]) < 25 and 0 < t.bbox[1] - mod.bbox[3] <= 12
                             and re.search(r"MODULE|CHANNEL", t.text.upper())]
                    words.sort(key=lambda t: -t.bbox[3])
                    tab["module_words"] = [t.text for t in words]
                tables[ci].append(tab)
        self._cell_tables = tables
        return tables

    def cell_items(self, tid: str) -> dict:
        """What else is drawn in the loop-drawing cell of a text."""
        t = self.texts[tid]
        ci = cell_of(self.cells, *_center(t.bbox)) if self.cells else None
        res = {"cell": ci, "tables": [], "wire_numbers": [], "cables": [], "supply": [], "tags": [], "converters": [], "captions": [], "other": []}
        if ci is None:
            return res
        tabs = self.cell_tables().get(ci, [])
        if tabs:
            ty = _center(t.bbox)[1]
            tabs = sorted(tabs, key=lambda tb: abs(tb["y"] - ty))
            res["tables"] = tabs[:1] if len(tabs) > 1 else tabs
        # caption lines standing under or over the text in its cell (the service
        # words of an override keyswitch are drawn below the switch symbol)
        own = self.gidx.get(tid)
        for g in self.groups:
            if g is own or g["rotation"] != 0:
                continue
            gb = g["bbox"]
            if cell_of(self.cells, *_center(gb)) != ci:
                continue
            if _overlap(gb[0], gb[2], t.bbox[0], t.bbox[2]) <= 0 or abs(_center(gb)[1] - _center(t.bbox)[1]) > 25:
                continue
            if all(not classify(ln) and not re.fullmatch(r"[\d &/.()-]+", ln) and len(ln) > 2 for ln in g["lines"]):
                res["captions"].extend(g["lines"])
        for o in self.data.texts:
            if o.frame or o.id == tid:
                continue
            if cell_of(self.cells, *_center(o.bbox)) != ci:
                continue
            up = o.text.strip()
            if re.fullmatch(r"1[12]\d{2}/\d{1,2}", up):
                res["wire_numbers"].append(up)
            elif re.fullmatch(r"\d{1,2}/C\d{2,4}(?:[/-]\d{1,2})?", up, re.I):
                res["cables"].append(up)
            elif re.fullmatch(r"\d[A-Z][+-]\d{1,2}", up) or re.fullmatch(r"TB\d[A-Z0-9]{2}(?:/\d{1,2})?", up):
                res["supply"].append(up)
            elif re.fullmatch(r"(?:ISOCON|VCON)[- ]?[A-Z0-9-]*", up, re.I):
                res["converters"].append(up)
            else:
                for i in self.idents.get(o.id, []):
                    if i.kind == "tag":
                        res["tags"].append(up)
                        break
        for k in ("wire_numbers", "cables", "supply", "tags", "converters"):
            res[k] = sorted(set(res[k]), key=lambda s: (len(s), s))
        return res


# =============================================================================
# roles
# =============================================================================
def _role(view: _SheetView, t: TextItem, ident: Ident) -> str:
    k, kind = view.kind, ident.kind
    if k == "fld":
        col = fld_column_of(view.columns, _center(t.bbox)[0])
        cname = col["name"] if col else ""
        if kind == "tag":
            if cname == "FIELD":
                return "FLD field device"
            if cname.startswith("PROCESS DEVICE"):
                return "FLD process device (output)"
            if cname == "ANNUN/CONSOLE":
                return "FLD control room device"
            if cname.startswith("OUTPUT"):
                return "FLD output"
            return "FLD logic signal"
        if kind == "cable":
            return "FLD field cable" if (col and col["x"] < 200) else "FLD output cable"
        return {"window": "FLD annunciator window", "dv": "FLD Delta V Modbus point", "signal": "FLD continuation signal",
                "potential": "FLD supply", "terminal": "FLD terminal", "elco": "FLD connector pin", "connector": "FLD card position",
                "link": "FLD link", "tb": "FLD terminal block"}.get(kind, "FLD text")
    if k in ("loop_in", "loop_out"):
        base = "loop drawing"
        if kind == "tag":
            return f"{base} channel"
        if kind == "elco":
            return f"{base} wire number" if "/" in t.text else f"{base} module pin"
        return {"cable": f"{base} field cable", "connector": f"{base} card position", "terminal": f"{base} supply wire",
                "potential": f"{base} supply", "tb": f"{base} terminal block", "window": f"{base} annunciator window",
                "dv": f"{base} Delta V point", "link": f"{base} link", "signal": f"{base} text"}.get(kind, f"{base} text")
    if k == "typical":
        return "typical loop drawing"
    if k == "elco":
        return "ELCO schedule row"
    if k == "annunciator":
        return {"window": "annunciator window", "cable": "annunciator cable"}.get(kind, "annunciator wiring")
    if k == "control_plate":
        return {"cable": "control plate cable", "window": "control plate window"}.get(kind, "control plate wiring")
    if k == "power":
        return {"potential": "power feed", "terminal": "power feed terminal", "link": "power distribution fuse / link",
                "cable": "power supply cable", "connector": "power feed to card"}.get(kind, "power distribution")
    if k == "card":
        if kind == "terminal":
            # XG terminals are where the feeds and the return enter the card; nL+k / nL-k wires are its outputs
            return "card supply terminal" if t.text.strip().upper().startswith("XG") else "card output wire"
        return {"potential": "card feed", "elco": "I/O card pin fed from this card", "connector": "I/O card position fed from this card",
                "link": "card link"}.get(kind, "card wiring")
    if k == "psu":
        return "PSU wiring"
    if k == "main_schematic":
        return "rack power wiring"
    if k == "layout":
        return "cabinet layout"
    if k == "document_schedule":
        return "document schedule"
    if k == "comms":
        return "communication wiring"
    return "drawing text"


# =============================================================================
# dossier
# =============================================================================
def _fmt_lines(lines: list[str]) -> str:
    return " / ".join(lines)


def _entry_context(view: _SheetView, t: TextItem, ident: Ident, role: str) -> list[str]:
    """Caption lines and drawn neighbours of one identifier occurrence.
    Every item is a text from the sheet (or a labelled grouping of such texts)."""
    ctx: list[str] = []

    def add(s: str):
        s = " ".join(str(s).split())
        if not s or s in ctx or s == t.text:
            return
        if re.fullmatch(r"\d{1,2}|[A-Za-z]{1,2}", s):
            return                      # a bare table cell ('1', 'A') says nothing on its own
        ctx.append(s)

    k = view.kind
    for ln in view.lines_of(t.id):
        if k == "elco" and ln.strip().upper() in ("TERM", "PIN", "CONTROLS", "ESD", "COLOUR", "SIZE", "LENGTH"):
            continue
        add(ln)
    if k == "fld":
        col = fld_column_of(view.columns, _center(t.bbox)[0])
        if col:
            add(f"column {col['name']}")
        if ident.kind == "tag" and col and col["name"] in ("FIELD", "PROCESS DEVICE TAG No.", "ANNUN/CONSOLE"):
            for lines in view.fld_row_groups(t.id, ("CABLE & TERMINALS",)):
                if len(lines) == 2 and re.fullmatch(r"\d{1,2} ?& ?\d{1,2}", lines[1]):
                    add(f"same row: cable {lines[0]} cores {lines[1]}")
                else:
                    add(f"same row, cable column: {_fmt_lines(lines)}")
            tr = view.trace_through_boxes(t.id)
            for w in tr["wires"]:
                if w["labels"]:
                    add(f"wire from symbol labelled {_fmt_lines(w['labels'])}")
            for box in tr["boxes"]:
                if box["lines"]:
                    add(f"wired to box {_fmt_lines(box['lines'])}")
                for o in box["out"]:
                    if o["labels"]:
                        add(f"other wire of that box labelled {_fmt_lines(o['labels'])}" + (f" reaching {', '.join(o['reaches'])}" if o["reaches"] else ""))
                    elif o["reaches"]:
                        add(f"other wire of that box (unlabelled) reaching {', '.join(o['reaches'])}")
        if ident.kind in ("dv", "window", "signal", "potential", "terminal") or (ident.kind == "tag" and (not col or col["name"] not in ("FIELD", "PROCESS DEVICE TAG No.", "ANNUN/CONSOLE"))):
            nid, labels = view.net_labels(t.id)
            if nid is not None:
                reach = view.reach_words(nid)
                if labels:
                    add(f"on wire with {_fmt_lines(labels)}")
                else:
                    add("on a wire with no other label")
                if reach:
                    add(f"wire reaches {', '.join(reach)}")
        if ident.kind == "signal" and t.id in view.pointer_of:
            add(f"pointer {view.texts[view.pointer_of[t.id]].text}")
        if ident.kind == "cable":
            for lines in view.fld_row_groups(t.id, ("FIELD", "PROCESS DEVICE TAG No.")):
                add(f"same row, device column: {_fmt_lines(lines)}")
    elif k in ("loop_in", "loop_out"):
        ci = view.cell_items(t.id)
        if ident.kind == "tag":
            for ln in ci["captions"]:
                add(ln)
        for tab in ci["tables"]:
            words = " ".join(tab.get("module_words", []))
            mod = f"{words} {tab['module']}".strip() if tab["module"] else words
            if mod:
                add(f"module {mod}")
            if tab["position"]:
                add(f"position {tab['position']}" + (f" channel {tab['channel']}" if tab["channel"] else ""))
            if tab["pins"]:
                add(f"channel pins {' / '.join(tab['pins'])}")
            if tab["supply_pins"]:
                add(f"supply pins {' / '.join(tab['supply_pins'])}")
        if ci["tags"] and ident.kind != "tag":
            add(f"loop of {', '.join(ci['tags'])}")
        if ci["wire_numbers"] and not (ident.kind == "elco" and "/" in t.text):
            add(f"wire number {', '.join(ci['wire_numbers'])}")
        if ci["cables"] and ident.kind != "cable":
            add(f"cable {', '.join(ci['cables'])}")
        if ci["supply"] and ident.kind not in ("terminal", "tb"):
            add(f"supply wires {', '.join(ci['supply'])}")
        if ci["converters"]:
            add(f"converter {', '.join(ci['converters'])}")
        if ident.kind == "tag":
            # the service caption lines of this tag's group were added first; other tags in the cell:
            others = [x for x in ci["tags"] if x != t.text]
            if others:
                add(f"other tags in the same loop cell: {', '.join(others)}")
    elif k == "elco":
        for ln in schedule_row(view.data, t):
            add(ln)
    elif k in ("power", "card", "psu", "main_schematic", "annunciator", "control_plate"):
        nid, labels = view.net_labels(t.id)
        term = terminal_circle_label(view.data, t) if ident.kind in ("cable", "terminal") else None
        if term and view.nets:
            tn = net_at_point(view.data, view.nets, term[0], term[1], term[2])
            if tn is not None:
                lab = [view.texts[o].text for o in view.net_texts.get(tn, [])]
                add(f"label of the terminal ending the wire with {_fmt_lines(lab)}" if lab else "label of a terminal on an unlabelled wire")
                nid = None
        if nid is not None:
            if labels:
                add(f"on wire with {_fmt_lines(labels)}")
            else:
                add("on a wire with no other label")
        if t.id in view.pointer_of:
            add(f"pointer {view.texts[view.pointer_of[t.id]].text}")
        if ident.kind == "tag":
            pass
    return ctx


_DEVICE_ROLES = ("FLD field device", "FLD process device (output)", "FLD control room device", "loop drawing channel")
_DERIVED_PREFIXES = ("column ", "same row", "wire ", "wired ", "box ", "on wire", "on a wire", "module ", "position ",
                     "channel ", "supply ", "cable ", "converter ", "other tags", "loop of", "pointer ", "label of",
                     "TERM ", "PIN ", "CONTROLS ", "ESD ", "TERM BLOCK")
_COLOUR_WORDS = {"RED", "BLUE", "GREEN", "YELLOW", "WHITE", "BLACK", "BROWN", "VIOLET", "ORANGE", "PINK", "TURQUOISE", "GREY"}
# glossary kinds that explain an identifier of a given kind
_PREFERRED_GLOSSARY = {
    "window": ("window",), "cable": ("cable",), "dv": ("dv",), "elco": ("elco_pin", "wire_number"),
    "terminal": ("terminal", "supply", "equipment", "tb"), "potential": ("supply",), "link": ("component",),
    "tb": ("tb",), "connector": ("card_position",),
}


_VOCAB_KINDS = {"signal", "wiring", "limit", "table_heading", "column", "symbol", "annunciator", "note", "loop_type", "module"}


def _service_caption(entries: list[dict]) -> str:
    """The caption words written with a tag where it is drawn as a device
    (FLD field / output column, loop drawing): the caption lines of its group
    joined, leaving out identifiers, LOOP TYPE, colours and vocabulary such as
    '110V AC' or '4-20mA'."""
    for e in entries:
        if e["role"] not in _DEVICE_ROLES:
            continue
        words = []
        for ln in e["context"]:
            if ln.startswith(_DERIVED_PREFIXES):
                break                              # caption lines come first
            up = ln.upper()
            if up.startswith("LOOP TYPE") or up in _COLOUR_WORDS or classify(ln) or re.fullmatch(r"[\d &/.()-]+", ln):
                continue
            if any(g.get("kind") in _VOCAB_KINDS for g in glossary_lookup(ln)):
                continue
            words.append(ln)
        if words:
            return " ".join(words)
    return ""


def _short(meaning: str) -> str:
    """First clause of a glossary meaning, for a title."""
    cut = len(meaning)
    for sep in (": ", " (", ". ", "; "):
        p = meaning.find(sep)
        if 12 <= p < cut:
            cut = p
    return meaning[:cut].rstrip(".")


def _canonical_label(kind: str, ident_key: str, entries: list[dict]) -> str:
    labels = sorted({e["label"] for e in entries}, key=lambda s: (len(s), s))
    if kind == "tagbase":
        # the full spelling with the plant prefix, when any sheet writes it
        full = [lab for lab in labels if re.fullmatch(r"\d{2}[A-Z]{1,4}\d{4,5}[A-Z]?", lab)]
        if full:
            return full[0]
        plain = [lab for lab in labels if re.fullmatch(r"[A-Z]{1,4}\s?\d{4,5}[A-Z]?", lab)]
        if plain:
            return plain[0]
    for lab in labels:
        if lab.upper().replace(" ", "") == ident_key.upper().replace(" ", ""):
            return lab
    return labels[0]


def _module_fact(context: list[str]) -> str:
    module = ""
    for c in context:
        if c.startswith("module "):
            m = re.search(r"((?:HIMA )?F\d{4})", c)
            module = m.group(1) if m else c[len("module "):]
            break
    if module:
        for c in context:
            if c.startswith("position "):
                module += " " + c
                break
    return module


def _tag_facts(label: str, entries: list[dict]) -> list[str]:
    """Compact facts for a tag title, taken from the entry contexts of the
    tag itself; variants written with a qualifier (03FZT03002-OVR) are
    reported separately with their sheet."""
    facts: list[str] = []
    loop_type = cable = module = ""
    own = [e for e in entries if e["label"] == label]
    for e in own:
        for c in e["context"]:
            if c.upper().startswith("LOOP TYPE") and not loop_type:
                loop_type = c
            elif c.startswith("same row: cable ") and not cable:
                cable = c[len("same row: cable "):]
            elif c.startswith("same row, cable column: ") and not cable:
                cable = c[len("same row, cable column: "):]
        if not module:
            module = _module_fact(e["context"])
    if loop_type or cable:
        facts.append(" via cable ".join(x for x in (loop_type, cable) if x) if loop_type else f"cable {cable}")
    if module:
        facts.append(module)
    seen = set()
    for e in entries:
        if e["label"] == label or e["label"] in seen:
            continue
        seen.add(e["label"])
        qual = tag_words(e["label"])["qualifier"]
        if not qual:
            continue                     # a spelling variant (FZA 03002 - W01), not another device
        mod = _module_fact(e["context"])
        facts.append(f"{e['label']} ({qual}) on sheet {e['sheet']}" + (f": {mod}" if mod else ""))
    return facts


def _summarise(key: str, entries: list[dict], titles: dict[str, str], kinds_of_sheet: dict[str, str]) -> tuple[str, list[str]]:
    kind, _, ident_key = key.partition(":")
    label = _canonical_label(kind, ident_key, entries)
    labels = sorted({e["label"] for e in entries}, key=lambda s: (len(s), s))
    lines: list[str] = []
    by_sheet: dict[str, list[dict]] = defaultdict(list)
    for e in entries:
        by_sheet[e["sheet"]].append(e)
    sheets = sorted(by_sheet, key=_sheet_sort_key)
    # 1) glossary reading
    head = label
    if kind in ("tag", "tagbase"):
        desc = describe_tag(label)
        w = tag_words(label)
        if desc:
            head = f"{label}: {desc}"
        letters = [(l, wd, ev) for l, wd, ev in w["letters"] if l]
        if any(l == "RT" for l, _w, _e in letters):
            letters = [x for x in letters if x[0] != "T"]
        words = "; ".join(f"{l} = {wd}" + (" (ISA 5.1 convention)" if ev == "ISA 5.1 convention" else "") for l, wd, ev in letters)
        plant = f"plant {w['plant']} (No.{w['plant'].lstrip('0')} plant), " if w["plant"] else ""
        if words:
            lines.append(f"Tag {label}: {plant}letters {words}.")
        else:
            lines.append(f"Tag {label}: {plant}letters not explained by the drawings.")
        svc = _service_caption(entries)
        if svc:
            head += f", service {svc}"
        facts = _tag_facts(label, entries)
        if facts:
            head += "; " + "; ".join(facts)
    elif kind == "signal":
        head = f"{label}: FLD continuation signal between sheets {', '.join(sheets)}"
        lines.append("Continuation reference (legend 018): a lettered box on the FLD logic wire with the destination written beside it as sheet.grid; the destination sheet carries the same letter box pointing back.")
    else:
        gl: list[dict] = []
        pref = _PREFERRED_GLOSSARY.get(kind, ())
        for lab in labels:
            for g in glossary_lookup(lab):
                if g.get("kind") in ("tag_letter", "tag_plant", "tag_suffix", "tag_qualifier", "schedule_entry", "tag"):
                    continue
                if pref and g.get("kind") not in pref:
                    continue
                if all(g["meaning"] != x["meaning"] for x in gl):
                    gl.append(g)
        if not gl and labels:
            gl = [g for g in glossary_lookup(labels[0]) if g.get("kind") not in ("tag_letter", "tag_plant", "tag_suffix", "tag_qualifier")]
        if gl:
            head = f"{label}: {_short(gl[0]['meaning'])}"
            lines.append(gl[0]["meaning"])
    # 2) one line per sheet occurrence
    for sid in sheets:
        es = by_sheet[sid]
        title = titles.get(sid, "")
        roles = []
        for e in es:
            if e["role"] not in roles:
                roles.append(e["role"])
        asl = sorted({e["label"] for e in es if e["label"] != label})
        txt = f"Sheet {sid} ({title}): {', '.join(roles)}"
        if asl:
            txt += f", written {', '.join(asl)}"
        common = [c for c in es[0]["context"] if c.startswith("column ") and all(c in e["context"] for e in es)]
        parts = []
        for e in es:
            ctx = [c for c in e["context"] if c not in common][:10]
            if ctx:
                parts.append("; ".join(ctx))
        tail = "; ".join(common)
        if parts:
            tail = (tail + "; " if tail else "") + " | ".join(dict.fromkeys(parts))
        if tail:
            txt += "; " + tail
        lines.append(txt + ".")
    # 3) where it appears
    where = []
    for sid in sheets:
        w = f"{sid} ({SHEET_KIND_WORDS.get(kinds_of_sheet.get(sid, 'other'), 'drawing')}"
        asl = sorted({e["label"] for e in by_sheet[sid] if e["label"] != label})
        if asl:
            w += f", as {', '.join(asl)}"
        where.append(w + ")")
    lines.append(f"Appears on {len(sheets)} sheet{'s' if len(sheets) != 1 else ''}: {', '.join(where)}.")
    return head, lines


def _sheet_sort_key(sid: str):
    m = re.match(r"(\d+)(.*)", sid)
    return (int(m.group(1)), m.group(2)) if m else (9999, sid)


def build_dossier(records: dict, titles: Optional[dict[str, str]] = None, kinds: Iterable[str] = DOSSIER_KINDS) -> dict[str, dict]:
    """Dossier of every connection identifier across the sheets.

    ``records`` maps sheet id -> object with ``.data`` (SheetData), ``.idents``
    (text id -> [Ident]), ``.nets`` (NetResult) and optionally ``.texts`` and
    ``.companions`` (the SheetRecord of index_builder qualifies).  ``titles``
    may override the sheet titles.

    Returns ``{"kind:key": {"title", "lines", "entries": [{sheet, text, label,
    role, context[]}]}}``; tags are listed under ``tag:<key>`` and
    ``tagbase:<base>`` like the identifier index.
    """
    titles = dict(titles or {})
    want = set(kinds)
    views: dict[str, _SheetView] = {}
    for sid, rec in records.items():
        views[sid] = _SheetView(sid, rec, titles.get(sid) or getattr(rec.data, "title", ""))
        titles.setdefault(sid, views[sid].title)
    entries: dict[str, list[dict]] = defaultdict(list)
    for sid in sorted(views, key=_sheet_sort_key):
        v = views[sid]
        for tid, idents in v.idents.items():
            t = v.texts.get(tid)
            if t is None or t.frame:
                continue
            for ident in idents:
                if ident.kind not in want:
                    continue
                role = _role(v, t, ident)
                ctx = _entry_context(v, t, ident, role)
                entry = {"sheet": sid, "text": tid, "label": t.text, "role": role, "context": ctx,
                         "x": round(_center(t.bbox)[0], 2), "y": round(_center(t.bbox)[1], 2)}
                entries[f"{ident.kind}:{ident.key}"].append(entry)
                if ident.kind == "tag" and ident.extra.get("base"):
                    entries[f"tagbase:{ident.extra['base']}"].append(entry)
    kinds_of_sheet = {sid: v.kind for sid, v in views.items()}
    out: dict[str, dict] = {}
    for key, es in entries.items():
        title, lines = _summarise(key, es, titles, kinds_of_sheet)
        out[key] = {"title": title, "lines": lines, "entries": es}
    return out


# =============================================================================
# convenience for callers that hold only a SheetData
# =============================================================================
def make_record(sheet: SheetData, nets=None, sheet_ids: Optional[set] = None):
    """Build a SheetRecord-like object for one sheet the way index_builder
    does (identifiers, companions, signal filtering, nets)."""
    from .index_builder import SheetRecord, find_companions   # local import: index_builder imports this module
    from .nets import build_nets
    if nets is None:
        nets = build_nets(sheet)
    texts = {t.id: t for t in sheet.texts}
    title_up = (sheet.title or "").upper()
    rec = SheetRecord(sheet, texts, {}, nets,
                      schedule=bool(re.search(r"SCHEDULE|INDEX|CONTENTS", title_up)) and "ELCO" not in title_up,
                      typical=("TYPICAL" in title_up))
    for t in sheet.texts:
        if t.frame:
            continue
        idents = classify(t.text, sheet_ids, on_schedule=rec.schedule)
        if idents:
            rec.idents[t.id] = idents
    for t in sheet.texts:
        if XREF_RE.match(t.text) and not t.frame:
            comps = find_companions(rec, t)
            rec.companions[t.id] = comps
            for c in comps:
                rec.is_signal_companion.add(c)
    for tid, idents in list(rec.idents.items()):
        kept = [i for i in idents if i.kind != "signal" or tid in rec.is_signal_companion]
        if kept:
            rec.idents[tid] = kept
        else:
            del rec.idents[tid]
    return rec
