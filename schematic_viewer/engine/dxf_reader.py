"""Read one DXF drawing sheet: visible text with exact bounding boxes, title
block data, the grid ruler and the raw geometry needed for wire tracing.

Only entities on layers that are ON and THAWED are used, because several
files in a set may hold many sheets stacked on frozen layers (one file per
plotted sheet).  That matches what the plotted PDF shows.
"""
from __future__ import annotations

import math
import os
import re
from dataclasses import dataclass, field, asdict
from typing import Optional

import ezdxf
from ezdxf import bbox as ezbbox
from ezdxf import recover

FRAME_LAYERS = {"00-DRG_FRAME", "DEFPOINTS", "COL", "ROW", "CATALOGUE", "RECORD"}
FRAME_BLOCKS = {"A3-TITLE", "A3-CONTRACT", "A3-REVA", "A3-REVB", "HS-A3", "EDREV", "A3-FRAME"}
TITLE_TAGS = ("TITLE_1", "TITLE", "DRAWING_TITLE", "TITLE1")
SHEET_FROM_NAME = [
    # 10265-P3-051, 10265-P3-055B, 10265-P3-002Rev AC, 10265-P3-136REV A
    re.compile(r"(?:^|[^0-9])\d{5}-P\d-(\d{3}(?:[A-Z](?![A-Za-z]))?)"),
    re.compile(r"^\d{5}(\d{3})(?:\D|$)"),                        # 10265070
    re.compile(r"(?<![0-9])(\d{3}(?:[A-Z](?![A-Za-z]))?)(?![0-9])"),  # fallback: first 3-digit group
]
_ESC = [("%%U", ""), ("%%O", ""), ("%%D", "°"), ("%%P", "±"), ("%%C", "Ø"), ("%%%", "%")]


def clean_text(s: str) -> str:
    s = s or ""
    up = s.upper()
    for code, rep in _ESC:
        if code in up:
            # replace case-insensitively
            s = re.sub(re.escape(code), rep, s, flags=re.I)
    s = re.sub(r"\\[A-Za-z][^;]*;", "", s)  # residual MTEXT format codes
    return " ".join(s.replace(" ", " ").split())


def sheet_id_from_filename(name: str) -> str:
    base = os.path.basename(name)
    base = re.sub(r"\.dxf$", "", base, flags=re.I)
    for rx in SHEET_FROM_NAME:
        m = rx.search(base)
        if m:
            return m.group(1).upper()
    return base.upper()


@dataclass
class TextItem:
    id: str
    text: str
    kind: str                 # TEXT | MTEXT | ATTRIB | BLOCKTEXT
    layer: str
    x: float
    y: float
    bbox: tuple[float, float, float, float]
    height: float
    rotation: float
    handle: str               # handle of the entity to highlight in the SVG
    frame: bool = False
    block: Optional[str] = None
    tag: Optional[str] = None


@dataclass
class Segment:
    id: int
    handle: str
    layer: str
    x1: float
    y1: float
    x2: float
    y2: float
    kind: str = "line"       # line | pline | arc(chord) | shape
    dashed: bool = False     # non-continuous linetype: enclosure, mechanical link, scope boundary
    block: Optional[str] = None   # name of the block symbol this line belongs to (None = model space)


@dataclass
class Shape:
    """A closed outline (device symbol, continuation box, tag oval ...)."""
    id: int
    handle: str
    layer: str
    points: list[tuple[float, float]]
    bbox: tuple[float, float, float, float]


@dataclass
class Symbol:
    """A block reference with graphics (terminal, isolator, module ...)."""
    handle: str
    name: str
    bbox: tuple[float, float, float, float]
    segments: list[int]
    circles: list[int]


@dataclass
class SheetData:
    sheet_id: str
    file: str
    title: str
    drgno: str
    rev: str
    texts: list[TextItem]
    segments: list[Segment]
    shapes: list[Shape]
    circles: list[tuple[float, float, float, str]]      # cx, cy, r, handle
    arcs: list[tuple[float, float, float, float, float, int]]   # cx, cy, r, start_deg, end_deg, chord segment id
    symbols: list[Symbol]                                 # block symbols with graphics
    junctions: list[tuple[float, float]]                 # junction dot centres
    frame_rect: Optional[tuple[float, float, float, float]]   # extreme long lines (drawing frame)
    ruler: Optional[tuple[float, float]]                 # x = a*grid + b
    extents: tuple[float, float, float, float]
    visible_layers: list[str]
    hidden_layers: list[str]
    warnings: list[str] = field(default_factory=list)
    doc: object = field(default=None, repr=False, compare=False)

    def to_json(self) -> dict:
        d = asdict(self)
        d.pop("doc", None)
        return d


def _is_dashed(doc, entity, parent=None) -> bool:
    """True when the entity is drawn with a non-continuous linetype."""
    try:
        lt = (entity.dxf.linetype or "BYLAYER").upper()
        if lt == "BYBLOCK":
            lt = (parent.dxf.linetype or "BYLAYER").upper() if parent is not None else "BYLAYER"
        if lt == "BYLAYER":
            layer_name = entity.dxf.layer
            if parent is not None and layer_name == "0":
                layer_name = parent.dxf.layer
            try:
                lt = (doc.layers.get(layer_name).dxf.linetype or "CONTINUOUS").upper()
            except Exception:
                lt = "CONTINUOUS"
        return lt not in ("CONTINUOUS", "BYLAYER", "BYBLOCK", "")
    except Exception:
        return False


def _layer_visible(doc, name: str) -> bool:
    try:
        layer = doc.layers.get(name)
    except Exception:
        return True
    try:
        return layer.is_on() and not layer.is_frozen()
    except Exception:
        return True


def _bbox_of(entity) -> Optional[tuple[float, float, float, float]]:
    try:
        b = ezbbox.extents([entity], fast=False)
    except Exception:
        try:
            b = ezbbox.extents([entity], fast=True)
        except Exception:
            return None
    if not b.has_data:
        return None
    return (b.extmin.x, b.extmin.y, b.extmax.x, b.extmax.y)


def _fit_ruler(labels: list[tuple[int, float, float]]) -> Optional[tuple[float, float]]:
    """labels: (value, x_center, y). Returns (a, b) for x = a*value + b."""
    if len(labels) < 4:
        return None
    labels = sorted(labels)
    vals = [v for v, _, _ in labels]
    xs = [x for _, x, _ in labels]
    # the ruler must be increasing and roughly evenly spaced
    for i in range(1, len(labels)):
        if xs[i] <= xs[i - 1]:
            return None
    n = len(labels)
    mv, mx = sum(vals) / n, sum(xs) / n
    den = sum((v - mv) ** 2 for v in vals)
    if den == 0:
        return None
    a = sum((v - mv) * (x - mx) for v, x in zip(vals, xs)) / den
    b = mx - a * mv
    if not (0.8 < a < 1.25):
        return None
    if max(abs(a * v + b - x) for v, x in zip(vals, xs)) > 6.0:
        return None
    return (a, b)


def read_sheet(path: str, sheet_id: Optional[str] = None) -> SheetData:
    try:
        doc = ezdxf.readfile(path)
    except Exception:
        doc, _auditor = recover.readfile(path)
    msp = doc.modelspace()
    sid = sheet_id or sheet_id_from_filename(path)
    warnings: list[str] = []

    visible_layers = sorted(l.dxf.name for l in doc.layers if _layer_visible(doc, l.dxf.name))
    hidden_layers = sorted(l.dxf.name for l in doc.layers if not _layer_visible(doc, l.dxf.name))

    texts: list[TextItem] = []
    segments: list[Segment] = []
    shapes: list[Shape] = []
    circles: list[tuple[float, float, float, str]] = []
    arcs: list[tuple[float, float, float, float, float, int]] = []
    symbols: list[Symbol] = []
    junctions: list[tuple[float, float]] = []
    long_h: list[tuple[float, float]] = []    # (y, length) of long horizontal lines, any layer
    long_v: list[tuple[float, float]] = []
    drgno = ""
    rev = ""
    title_candidates: list[tuple[int, str]] = []
    frame_texts_for_ruler: list[tuple[int, float, float]] = []
    xmin = ymin = math.inf
    xmax = ymax = -math.inf

    def is_frame_layer(name: str) -> bool:
        return name.upper() in FRAME_LAYERS

    def add_text(entity, kind, layer, frame, block=None, tag=None, handle=None, text=None):
        nonlocal drgno, rev
        raw = text if text is not None else (
            entity.plain_text() if entity.dxftype() == "MTEXT" else entity.dxf.text)
        s = clean_text(raw)
        if not s:
            return
        bb = _bbox_of(entity)
        if bb is None:
            return
        ins = entity.dxf.insert
        if entity.dxftype() == "MTEXT":
            h = float(entity.dxf.char_height or (bb[3] - bb[1]))
        else:
            h = float(entity.dxf.height or (bb[3] - bb[1]))
        rot = float(entity.dxf.rotation or 0.0) if entity.dxf.hasattr("rotation") else 0.0
        hdl = handle or entity.dxf.handle
        item = TextItem(
            id=f"t{hdl}" if kind != "BLOCKTEXT" else f"t{hdl}_{len(texts)}",
            text=s, kind=kind, layer=layer, x=float(ins.x), y=float(ins.y),
            bbox=tuple(round(v, 3) for v in bb), height=round(h, 3), rotation=round(rot, 2),
            handle=hdl, frame=frame, block=block, tag=tag,
        )
        texts.append(item)
        if tag and tag.upper() in ("DRGNO", "DRG_NO", "SHEET", "SHT"):
            drgno = s
        if tag and tag.upper() in ("REV.", "REV"):
            rev = s
        if tag and tag.upper() in TITLE_TAGS:
            title_candidates.append((0, s))
        if frame and re.fullmatch(r"\d{2,3}", s) and int(s) % 50 == 0 and 50 <= int(s) <= 400:
            cx = (bb[0] + bb[2]) / 2
            frame_texts_for_ruler.append((int(s), cx, float(ins.y)))

    for e in msp:
        et = e.dxftype()
        layer = e.dxf.layer
        if not _layer_visible(doc, layer):
            continue
        if e.dxf.get("invisible", 0):
            continue
        frame = is_frame_layer(layer)
        if et == "TEXT":
            add_text(e, "TEXT", layer, frame)
        elif et == "MTEXT":
            add_text(e, "MTEXT", layer, frame)
        elif et == "INSERT":
            bname = e.dxf.name
            bframe = frame or bname.upper() in FRAME_BLOCKS
            for a in e.attribs:
                if a.is_invisible or not _layer_visible(doc, a.dxf.layer):
                    continue
                add_text(a, "ATTRIB", layer, bframe, block=bname, tag=a.dxf.tag)
            # junction dots drawn as blocks
            if "DOT" in bname.upper() or bname.upper() in ("JUNCTION", "NODE"):
                junctions.append((float(e.dxf.insert.x), float(e.dxf.insert.y)))
                continue
            # static text and geometry inside the block reference
            try:
                virtual = list(e.virtual_entities())
            except Exception:
                virtual = []
            n_seg0, n_circ0 = len(segments), len(circles)
            for v in virtual:
                vt = v.dxftype()
                vlayer = v.dxf.layer
                if vlayer != "0" and not _layer_visible(doc, vlayer):
                    continue
                if vt in ("TEXT", "MTEXT"):
                    add_text(v, "BLOCKTEXT", layer, bframe, block=bname, handle=e.dxf.handle)
                elif not bframe:
                    _collect_geometry(v, layer, e.dxf.handle, segments, shapes, circles, arcs, junctions, _is_dashed(doc, v, e))
            new_segs = list(range(n_seg0, len(segments)))
            new_circ = list(range(n_circ0, len(circles)))
            if new_segs or new_circ:
                xs = [v for i in new_segs for v in (segments[i].x1, segments[i].x2)] + [circles[i][0] + d * circles[i][2] for i in new_circ for d in (-1, 1)]
                ys = [v for i in new_segs for v in (segments[i].y1, segments[i].y2)] + [circles[i][1] + d * circles[i][2] for i in new_circ for d in (-1, 1)]
                for i in new_segs:
                    segments[i].block = bname
                symbols.append(Symbol(e.dxf.handle, bname, (round(min(xs), 3), round(min(ys), 3), round(max(xs), 3), round(max(ys), 3)), new_segs, new_circ))
        elif not frame:
            _collect_geometry(e, layer, e.dxf.handle, segments, shapes, circles, arcs, junctions, _is_dashed(doc, e))
        # long straight lines of any layer (used to align PDF backdrops)
        if et == "LINE":
            a, b = e.dxf.start, e.dxf.end
            if abs(a.y - b.y) < 0.01 and abs(a.x - b.x) > 100:
                long_h.append((float(a.y), abs(float(a.x - b.x))))
            if abs(a.x - b.x) < 0.01 and abs(a.y - b.y) > 70:
                long_v.append((float(a.x), abs(float(a.y - b.y))))
        elif et == "LWPOLYLINE":
            try:
                pts = [(float(q[0]), float(q[1])) for q in e.get_points("xy")]
                for a, b in zip(pts, pts[1:] + (pts[:1] if e.closed else [])):
                    if abs(a[1] - b[1]) < 0.01 and abs(a[0] - b[0]) > 100:
                        long_h.append((a[1], abs(a[0] - b[0])))
                    if abs(a[0] - b[0]) < 0.01 and abs(a[1] - b[1]) > 70:
                        long_v.append((a[0], abs(a[1] - b[1])))
            except Exception:
                pass
        # extents from everything visible (approximate, fast)
        try:
            b = ezbbox.extents([e], fast=True)
            if b.has_data:
                xmin, ymin = min(xmin, b.extmin.x), min(ymin, b.extmin.y)
                xmax, ymax = max(xmax, b.extmax.x), max(ymax, b.extmax.y)
        except Exception:
            pass

    if not math.isfinite(xmin):
        xmin = ymin = 0.0
        xmax = ymax = 100.0

    # Filled junction dots are often drawn as a stack of concentric circles.
    groups: dict[tuple[float, float], list[tuple[float, float, float, str]]] = {}
    for c in circles:
        groups.setdefault((round(c[0], 2), round(c[1], 2)), []).append(c)
    kept: list[tuple[float, float, float, str]] = []
    for key, grp in groups.items():
        rmax = max(c[2] for c in grp)
        if (len(grp) >= 3 and rmax <= 0.8) or (len(grp) == 1 and rmax <= 0.35):
            junctions.append((grp[0][0], grp[0][1]))
        else:
            kept.extend(grp)
    circles = kept

    # --- title -------------------------------------------------------------
    title = ""
    if title_candidates:
        title = title_candidates[0][1]
    else:
        # Frames without attributes (HS-A3): the title follows a 'Title :' label
        # and the drawing number is the big 3-digit text in the title block.
        area = [t for t in texts if t.y < 0.15 * (ymax - ymin) + ymin and t.x > 0.6 * (xmax - xmin) + xmin]
        labels = [t for t in area if re.match(r"^title\b", t.text, re.I)]
        for lab in labels:
            lcy = (lab.bbox[1] + lab.bbox[3]) / 2
            right = [t for t in area if t is not lab and abs((t.bbox[1] + t.bbox[3]) / 2 - lcy) < 2.5
                     and t.bbox[0] > lab.bbox[0] + 1.0 and len(t.text) > 2]
            right.sort(key=lambda t: t.bbox[0])
            if right:
                title = right[0].text
                break
        if not drgno:
            nums = [t for t in area if re.fullmatch(r"\d{3}[A-Z]?", t.text) and t.height >= 4.0]
            if nums:
                drgno = nums[0].text
                for t in nums:
                    t.frame = True
        if not rev:
            revs = [t for t in area if re.fullmatch(r"[A-Z]|P\d", t.text) and t.height >= 4.0]
            if revs:
                rev = revs[0].text
    ruler = _fit_ruler([lab for lab in frame_texts_for_ruler if lab[2] > ymax - 0.1 * (ymax - ymin)])
    if drgno and drgno.lstrip("0") != sid.lstrip("0") and drgno != sid:
        warnings.append(f"title block drawing number {drgno!r} differs from file-derived sheet id {sid!r}")

    frame_rect = None
    w_ext, h_ext = xmax - xmin, ymax - ymin
    hs = [y for y, L in long_h if L >= 0.25 * w_ext]
    vs = [x for x, L in long_v if L >= 0.25 * h_ext]
    if len(hs) >= 2 and len(vs) >= 2:
        frame_rect = (round(min(vs), 3), round(min(hs), 3), round(max(vs), 3), round(max(hs), 3))

    return SheetData(
        sheet_id=sid, file=os.path.basename(path), title=title, drgno=drgno, rev=rev,
        texts=texts, segments=segments, shapes=shapes, circles=circles, arcs=arcs, symbols=symbols, junctions=junctions,
        frame_rect=frame_rect,
        ruler=ruler, extents=(round(xmin, 3), round(ymin, 3), round(xmax, 3), round(ymax, 3)),
        visible_layers=visible_layers, hidden_layers=hidden_layers, warnings=warnings, doc=doc,
    )


def _collect_geometry(e, layer, handle, segments, shapes, circles, arcs, junctions, dashed=False) -> None:
    et = e.dxftype()
    n0 = len(segments)
    try:
        _collect_geometry_inner(e, et, layer, handle, segments, shapes, circles, arcs, junctions)
    finally:
        if dashed:
            for sg in segments[n0:]:
                sg.dashed = True


def _collect_geometry_inner(e, et, layer, handle, segments, shapes, circles, arcs, junctions) -> None:
    try:
        if et == "LINE":
            s, t = e.dxf.start, e.dxf.end
            if s.distance(t) > 1e-6:
                segments.append(Segment(len(segments), handle, layer, float(s.x), float(s.y), float(t.x), float(t.y)))
        elif et in ("LWPOLYLINE", "POLYLINE"):
            if et == "LWPOLYLINE":
                pts = [(float(p[0]), float(p[1])) for p in e.get_points("xy")]
                closed = e.closed
                width = max(float(e.dxf.get("const_width", 0) or 0), 0.0)
                has_bulge = any(abs(p[4]) > 1e-9 for p in e.get_points())
            else:
                pts = [(float(v.dxf.location.x), float(v.dxf.location.y)) for v in e.vertices]
                closed = e.is_closed
                width = 0.0
                has_bulge = False
            if len(pts) < 2:
                return
            if closed and len(pts) >= 3 or (closed and has_bulge and len(pts) == 2):
                xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
                bb = (min(xs), min(ys), max(xs), max(ys))
                size = max(bb[2] - bb[0], bb[3] - bb[1])
                if size <= 1.6 and (width > 0 or has_bulge):
                    junctions.append(((bb[0] + bb[2]) / 2, (bb[1] + bb[3]) / 2))   # donut / dot
                else:
                    shapes.append(Shape(len(shapes), handle, layer, pts, bb))
                    for i in range(len(pts)):
                        a, b = pts[i], pts[(i + 1) % len(pts)]
                        segments.append(Segment(len(segments), handle, layer, a[0], a[1], b[0], b[1], "shape"))
            else:
                for a, b in zip(pts, pts[1:]):
                    if math.dist(a, b) > 1e-6:
                        segments.append(Segment(len(segments), handle, layer, a[0], a[1], b[0], b[1], "pline"))
        elif et == "CIRCLE":
            c, r = e.dxf.center, float(e.dxf.radius)
            circles.append((float(c.x), float(c.y), r, handle))
        elif et == "ARC":
            s, t = e.start_point, e.end_point
            segments.append(Segment(len(segments), handle, layer, float(s.x), float(s.y), float(t.x), float(t.y), "arc"))
            c = e.dxf.center
            arcs.append((float(c.x), float(c.y), float(e.dxf.radius), float(e.dxf.start_angle), float(e.dxf.end_angle), len(segments) - 1))
        elif et == "SOLID" or et == "TRACE":
            pts = [e.dxf.vtx0, e.dxf.vtx1, e.dxf.vtx2, e.dxf.vtx3]
            xs = [p.x for p in pts]; ys = [p.y for p in pts]
            if max(xs) - min(xs) <= 1.6 and max(ys) - min(ys) <= 1.6:
                junctions.append((sum(xs) / 4, sum(ys) / 4))
        elif et == "ELLIPSE":
            pass
    except Exception:
        return
