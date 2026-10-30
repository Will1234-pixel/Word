"""Wire connectivity ("nets") for one sheet, derived purely from geometry.

Rules (standard schematic conventions):
* two wire segments are connected when an end point of one coincides with an
  end point of the other (corners, including small overshoots);
* a wire ending on the middle of another line (T-junction) is a branch only
  when a junction dot is drawn there or the host line is a short piece of a
  small symbol (a terminal foot); a long host line without a dot is symbol
  line-work (a terminal strip or comb) that must not join conductors;
* lines that merely cross are NOT connected unless a junction dot is drawn;
* dashed or hidden-line work (enclosures, scope boundaries, mechanical links)
  never conducts;
* a filled dot connects every wire passing through it;
* closed outlines (device symbols, continuation boxes, tag ovals, module
  boxes, logic gates) are not wires: a wire ends where it touches them and the
  net records which outline it touches;
* a small hollow circle with two or three wires ending on it (an in-line
  terminal, possibly with a slash) passes the net through; block symbols up to
  4.5 mm with two wires on them do the same; larger symbols end the net.

Nothing here claims an electrical connection between *different* sheets; it
only groups the drawn conductors of one sheet.
"""
from __future__ import annotations

import math
import re
from collections import defaultdict
from dataclasses import dataclass, field

from .dxf_reader import SheetData, Segment

NODE_TOL = 0.05      # mm, end point coincidence
T_TOL = 0.08         # mm, end point on another segment
CORNER_TOL = 1.0     # mm, a T landing this close to the host's end is a corner (overshoot), not a tap
SHORT_HOST = 6.0     # mm, a wire landing on a line this short passes through a small symbol (terminal foot)
DOT_TOL = 0.35       # mm, wire passes through a junction dot
TEXT_TOL = 1.2       # mm, label-to-wire distance
LOOSE_TEXT_TOL = 3.0 # mm, DeltaV taps (DV3_5) and limit words (HIGH, LOLO) are written further from their wire
END_TEXT_TOL = 3.0   # mm, a short label in line with the free end of a wire ('1L-6' under its wire end on 085, '7/C305-1' left of its terminal on 035)
LOOSE_LABEL_RE = re.compile(r"^(?:DV\d_\d+|HIGH|LOW|LOLO|HIHI|MID|HI|LO)$")
PORT_TOL = 0.3       # mm, a wire end this close to a closed symbol is a port of that symbol
GATE_PORT_TOL = 1.0  # mm, a logic gate's output leaves from its arc, up to this far from the bbox edge
GATE_WORDS = {"AND", "OR", "NOT", "XOR", "NAND", "NOR"}
SHAPE_MAX_DIAG = 90  # mm, closed loops smaller than this are symbols, not ring wiring
SMALL_SYMBOL = 4.5   # mm, a block symbol up to this size with two wires on it is an in-line part (terminal, link)
DEVICE_MIN_DIAG = 1.5   # mm, closed symbols between these sizes are devices (diode, fuse, coil, contact, lamp body):
DEVICE_MAX_DIAG = 16.0  # a conductor drawn straight through one is cut there, lines inside belong to it
MINI_SYMBOL = 4.5    # mm, a cluster of short open line-work (connector pin, terminal foot) passes the conductor through
DECOR_POLY_SEGS = 20  # an open polyline with this many short pieces is a boundary or curve, not a wire
DECOR_PIECE = 6.0     # mm, "short" for the rule above (median piece length)
ZIGZAG_MAX = 1.5      # mm, a component made only of pieces this short (8 or more) is hatching / a zigzag symbol
MIN_WIRE = 0.2        # mm, anything shorter is drawing noise
DEBUG_MINI: list = []   # filled with the clusters that joined conductors (diagnostics)
MAX_SEGMENTS = 16000 # skip wire tracing on huge layout drawings


@dataclass
class Net:
    id: int
    segments: list[int]
    bbox: tuple[float, float, float, float]
    texts: list[str] = field(default_factory=list)
    shapes: list[int] = field(default_factory=list)


@dataclass
class NetResult:
    nets: list[Net]
    shapes: list[dict]            # id, handle, bbox, texts, nets
    seg_net: dict[int, int]       # segment id -> net id
    text_net: dict[str, int]      # text id -> net id
    text_shape: dict[str, int]    # text id -> shape id
    skipped: bool = False


class _UF:
    def __init__(self, n: int) -> None:
        self.p = list(range(n))

    def find(self, a: int) -> int:
        p = self.p
        while p[a] != a:
            p[a] = p[p[a]]
            a = p[a]
        return a

    def union(self, a: int, b: int) -> None:
        ra, rb = self.find(a), self.find(b)
        if ra != rb:
            self.p[rb] = ra


class _Grid:
    """Uniform grid hash over segments for proximity queries."""

    def __init__(self, segs: list[Segment], cell: float = 4.0) -> None:
        self.cell = cell
        self.cells: dict[tuple[int, int], list[int]] = defaultdict(list)
        for s in segs:
            for key in self._cells_of(s):
                self.cells[key].append(s.id)

    def _cells_of(self, s: Segment):
        c = self.cell
        x0, x1 = sorted((s.x1, s.x2))
        y0, y1 = sorted((s.y1, s.y2))
        for ix in range(int(math.floor(x0 / c)), int(math.floor(x1 / c)) + 1):
            for iy in range(int(math.floor(y0 / c)), int(math.floor(y1 / c)) + 1):
                yield (ix, iy)

    def near(self, x: float, y: float, r: float = 0.0):
        c = self.cell
        out: set[int] = set()
        for ix in range(int(math.floor((x - r) / c)), int(math.floor((x + r) / c)) + 1):
            for iy in range(int(math.floor((y - r) / c)), int(math.floor((y + r) / c)) + 1):
                out.update(self.cells.get((ix, iy), ()))
        return out

    def near_box(self, x0: float, y0: float, x1: float, y1: float):
        c = self.cell
        out: set[int] = set()
        for ix in range(int(math.floor(x0 / c)), int(math.floor(x1 / c)) + 1):
            for iy in range(int(math.floor(y0 / c)), int(math.floor(y1 / c)) + 1):
                out.update(self.cells.get((ix, iy), ()))
        return out


def _point_seg_dist(px, py, s: Segment) -> tuple[float, float]:
    """Return (distance, t) of point to segment with t the projection parameter."""
    dx, dy = s.x2 - s.x1, s.y2 - s.y1
    L2 = dx * dx + dy * dy
    if L2 <= 1e-12:
        return math.hypot(px - s.x1, py - s.y1), 0.0
    t = ((px - s.x1) * dx + (py - s.y1) * dy) / L2
    tc = min(1.0, max(0.0, t))
    qx, qy = s.x1 + tc * dx, s.y1 + tc * dy
    return math.hypot(px - qx, py - qy), t


def _seg_box_dist(s: Segment, box) -> float:
    """Distance from a segment to an axis-aligned box (0 when touching/crossing)."""
    x0, y0, x1, y1 = box
    # quick accept: an end point inside
    for px, py in ((s.x1, s.y1), (s.x2, s.y2)):
        if x0 <= px <= x1 and y0 <= py <= y1:
            return 0.0
    # sample distance from box corners/edges to the segment and vice versa
    best = math.inf
    for px, py in ((x0, y0), (x1, y0), (x1, y1), (x0, y1)):
        best = min(best, _point_seg_dist(px, py, s)[0])
    for px, py in ((s.x1, s.y1), (s.x2, s.y2)):
        dx = max(x0 - px, 0, px - x1)
        dy = max(y0 - py, 0, py - y1)
        best = min(best, math.hypot(dx, dy))
    # segment crossing the box without end points inside: check edge intersections
    if best > 0:
        edges = [(x0, y0, x1, y0), (x1, y0, x1, y1), (x1, y1, x0, y1), (x0, y1, x0, y0)]
        for ex0, ey0, ex1, ey1 in edges:
            if _intersects(s.x1, s.y1, s.x2, s.y2, ex0, ey0, ex1, ey1):
                return 0.0
    return best


def _intersects(ax, ay, bx, by, cx, cy, dx, dy) -> bool:
    def orient(px, py, qx, qy, rx, ry):
        v = float((qx - px) * (ry - py) - (qy - py) * (rx - px))
        return int(v > 1e-12) - int(v < -1e-12)
    o1, o2 = orient(ax, ay, bx, by, cx, cy), orient(ax, ay, bx, by, dx, dy)
    o3, o4 = orient(cx, cy, dx, dy, ax, ay), orient(cx, cy, dx, dy, bx, by)
    return o1 != o2 and o3 != o4 and o1 != 0 and o2 != 0 and o3 != 0 and o4 != 0


def build_nets(sheet: SheetData) -> NetResult:
    segs = sheet.segments
    if len(segs) > MAX_SEGMENTS or not segs:
        return NetResult([], [], {}, {}, {}, skipped=bool(segs))

    # ---- nodes: snap end points ------------------------------------------------
    node_of: dict[tuple[int, int], int] = {}
    seg_nodes: list[tuple[int, int]] = []

    def node(x, y) -> int:
        key = (round(x / NODE_TOL), round(y / NODE_TOL))
        if key in node_of:
            return node_of[key]
        # try the 8 neighbouring cells (points straddling a cell border)
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                k2 = (key[0] + dx, key[1] + dy)
                if k2 in node_of:
                    node_of[key] = node_of[k2]
                    return node_of[k2]
        nid = len(node_of)
        node_of[key] = nid
        return nid

    for s in segs:
        seg_nodes.append((node(s.x1, s.y1), node(s.x2, s.y2)))

    # ---- cycles (device outlines) via bridge finding ----------------------------
    adj: dict[int, list[tuple[int, int]]] = defaultdict(list)
    for s in segs:
        a, b = seg_nodes[s.id]
        if a != b:
            adj[a].append((b, s.id))
            adj[b].append((a, s.id))
    bridges = _find_bridges(adj)
    shape_edges: set[int] = {s.id for s in segs if s.kind in ("shape", "arc")}
    # closed polylines are already shapes; look for cycles among the remaining segments only
    cycle_edges = {s.id for s in segs if s.kind not in ("shape",) and seg_nodes[s.id][0] != seg_nodes[s.id][1]
                   and s.id not in bridges}
    # group cycle edges into loop components and keep the small ones as shapes
    loop_uf = _UF(len(segs))
    node_first: dict[int, int] = {}
    for sid in cycle_edges:
        for n in seg_nodes[sid]:
            if n in node_first:
                loop_uf.union(node_first[n], sid)
            else:
                node_first[n] = sid
    loops: dict[int, list[int]] = defaultdict(list)
    for sid in cycle_edges:
        loops[loop_uf.find(sid)].append(sid)
    extra_shapes: list[dict] = []
    known_boxes = {tuple(round(v, 2) for v in sh.bbox) for sh in sheet.shapes}
    for members in loops.values():
        xs = [v for sid in members for v in (segs[sid].x1, segs[sid].x2)]
        ys = [v for sid in members for v in (segs[sid].y1, segs[sid].y2)]
        bb = (min(xs), min(ys), max(xs), max(ys))
        if math.hypot(bb[2] - bb[0], bb[3] - bb[1]) <= SHAPE_MAX_DIAG:
            shape_edges.update(members)
            if tuple(round(v, 2) for v in bb) not in known_boxes:
                extra_shapes.append({"handle": segs[members[0]].handle, "bbox": bb, "segments": members})

    # ---- shapes list -------------------------------------------------------------
    shapes: list[dict] = []
    seg_shape: dict[int, int] = {}
    symbol_shape: dict[str, int] = {}
    for sym in getattr(sheet, "symbols", []):
        sid = len(shapes)
        shapes.append({"id": sid, "handle": sym.handle, "bbox": tuple(round(v, 3) for v in sym.bbox), "texts": [], "nets": [], "symbol": sym.name})
        symbol_shape[sym.handle] = sid
        for i in sym.segments:
            seg_shape[i] = sid
            shape_edges.add(i)
    for sh in sheet.shapes:
        sid = len(shapes)
        shapes.append({"id": sid, "handle": sh.handle, "bbox": tuple(round(v, 3) for v in sh.bbox), "texts": [], "nets": []})
        for s in segs:
            if s.handle == sh.handle and s.kind == "shape":
                seg_shape[s.id] = sid
    for ex in extra_shapes:
        sid = len(shapes)
        shapes.append({"id": sid, "handle": ex["handle"], "bbox": tuple(round(v, 3) for v in ex["bbox"]), "texts": [], "nets": []})
        for m in ex["segments"]:
            seg_shape[m] = sid

    # ---- device symbols: cut conductors that run straight through, absorb internal lines ----
    devices = [sh for sh in shapes
               if DEVICE_MIN_DIAG <= math.hypot(sh["bbox"][2] - sh["bbox"][0], sh["bbox"][3] - sh["bbox"][1]) <= DEVICE_MAX_DIAG]
    dev_grid = _BoxGrid(devices) if devices else None
    # open polylines made of many short pieces are boundaries or curves, never conductors
    poly_count: dict[str, list[float]] = defaultdict(list)
    for s in segs:
        if s.kind == "pline" and not s.dashed:
            poly_count[s.handle].append(math.hypot(s.x2 - s.x1, s.y2 - s.y1))
    decorative = {h for h, lens in poly_count.items()
                  if len(lens) >= DECOR_POLY_SEGS and sorted(lens)[len(lens) // 2] <= DECOR_PIECE}
    # a SAFECLIP link (035) is drawn as two small circles joined by two parallel lines on their rims: the
    # lines are the link's body, not conductors, so the circuits on either side of a link stay apart
    capsule_sides: set[int] = set()
    rims = [(cx, cy, r) for cx, cy, r, _h in getattr(sheet, "circles", []) if 0.8 <= r <= 2.0]
    if rims:
        def rim_of(px: float, py: float):
            for k, (cx, cy, r) in enumerate(rims):
                if abs(px - cx) <= r + 0.15 and abs(py - cy) <= r + 0.15 and abs(math.hypot(px - cx, py - cy) - r) <= 0.15:
                    return k
            return None
        rim_pairs: dict[tuple[int, int], list[int]] = defaultdict(list)
        for s in segs:
            if s.dashed or s.id in shape_edges:
                continue
            ln = math.hypot(s.x2 - s.x1, s.y2 - s.y1)
            if ln < 2.0 or ln > 12.0:
                continue
            a, b2 = rim_of(s.x1, s.y1), rim_of(s.x2, s.y2)
            if a is None or b2 is None or a == b2:
                continue
            rim_pairs[(min(a, b2), max(a, b2))].append(s.id)
        for ids in rim_pairs.values():
            if len(ids) == 2:
                capsule_sides.update(ids)
    wires: list[Segment] = []
    for s in segs:
        if s.id in shape_edges or s.dashed or s.id in capsule_sides:
            continue
        if math.hypot(s.x2 - s.x1, s.y2 - s.y1) < MIN_WIRE:
            continue
        if s.kind == "pline" and s.handle in decorative:
            continue
        pieces = [s]
        if dev_grid is not None:
            for dev in dev_grid.candidates(s):
                b = dev["bbox"]
                nxt: list[Segment] = []
                for piece in pieces:
                    in1 = _inside(piece.x1, piece.y1, b)
                    in2 = _inside(piece.x2, piece.y2, b)
                    if in1 and in2:
                        seg_shape[piece.id] = dev["id"]          # drawn inside the device: part of it
                        shape_edges.add(piece.id)
                        continue
                    clip = _clip_box(piece, b)
                    if clip is not None:
                        t0, t1 = clip
                        if (t1 - t0) * math.hypot(piece.x2 - piece.x1, piece.y2 - piece.y1) > 0.5:
                            # the conductor runs through the device (both ends outside), or into it and on to
                            # its far edge (one end inside: the 6 A fuse on 035): keep only the outside part(s)
                            nxt.extend(_split(piece, t0, t1, segs))
                            continue
                    nxt.append(piece)
                pieces = nxt
        wires.extend(pieces)

    # dashed line work (enclosures, scope boundaries, mechanical links) never conducts
    dot_grid_pts = sheet.junctions
    for i in range(len(seg_nodes), len(segs)):        # nodes for pieces created by splitting (id order)
        seg_nodes.append((node(segs[i].x1, segs[i].y1), node(segs[i].x2, segs[i].y2)))

    def dot_near(px, py) -> bool:
        for jx, jy in dot_grid_pts:
            if abs(jx - px) <= DOT_TOL and abs(jy - py) <= DOT_TOL and math.hypot(jx - px, jy - py) <= DOT_TOL:
                return True
        return False
    uf = _UF(len(segs))
    node_seg: dict[int, int] = {}
    for s in wires:
        for n in seg_nodes[s.id]:
            if n in node_seg:
                uf.union(node_seg[n], s.id)
            else:
                node_seg[n] = s.id
    grid = _Grid(wires)
    net_touch_shape: dict[int, set[int]] = defaultdict(set)   # wire seg -> shapes touched
    shape_grid = _Grid([s for s in segs if s.id in shape_edges]) if shape_edges else None
    for s in wires:
        for px, py in ((s.x1, s.y1), (s.x2, s.y2)):
            for oid in grid.near(px, py, T_TOL):
                if oid == s.id:
                    continue
                o = segs[oid]
                d, t = _point_seg_dist(px, py, o)
                if d <= T_TOL and 0.0 < t < 1.0:
                    # A wire ending on the middle of another line is a branch only when the
                    # drafter marked it with a junction dot; otherwise the host line is symbol
                    # line-work (terminal strip, comb) and must not join the conductors landing on it.
                    host_len = math.hypot(o.x2 - o.x1, o.y2 - o.y1)
                    near_end = min(t, 1.0 - t) * host_len <= CORNER_TOL
                    if near_end or host_len <= SHORT_HOST or dot_near(px, py):
                        uf.union(s.id, oid)
            if shape_grid is not None:
                for oid in shape_grid.near(px, py, T_TOL):
                    d, _t = _point_seg_dist(px, py, segs[oid])
                    if d <= T_TOL and oid in seg_shape:
                        net_touch_shape[s.id].add(seg_shape[oid])
            for (cx, cy, r, a0, a1, chord) in sheet.arcs:
                if chord not in seg_shape or abs(px - cx) > r + T_TOL or abs(py - cy) > r + T_TOL:
                    continue
                dist = math.hypot(px - cx, py - cy)
                if abs(dist - r) <= T_TOL:
                    ang = math.degrees(math.atan2(py - cy, px - cx)) % 360.0
                    if (ang - a0) % 360.0 <= (a1 - a0) % 360.0 + 1e-6:
                        net_touch_shape[s.id].add(seg_shape[chord])
    # junction dots
    for jx, jy in sheet.junctions:
        hits = [oid for oid in grid.near(jx, jy, DOT_TOL) if _point_seg_dist(jx, jy, segs[oid])[0] <= DOT_TOL]
        for a, b in zip(hits, hits[1:]):
            uf.union(a, b)
    # in-line terminals: small hollow circles with two or three wire ends on them pass the conductor through
    for cx, cy, r, _h in sheet.circles:
        if r > 1.6:
            continue
        ends: set[int] = set()
        for oid in grid.near(cx, cy, r + 0.2):
            o = segs[oid]
            for px, py in ((o.x1, o.y1), (o.x2, o.y2)):
                if abs(math.hypot(px - cx, py - cy) - r) <= 0.2:
                    ends.add(oid)
        if 2 <= len(ends) <= 3:
            first = next(iter(ends))
            for oid in ends:
                uf.union(first, oid)

    # in-line block symbols (terminals, links): exactly two wires touching a small symbol are one conductor
    for sym in getattr(sheet, "symbols", []):
        bx0, by0, bx1, by1 = sym.bbox
        if max(bx1 - bx0, by1 - by0) > SMALL_SYMBOL:
            continue
        touching: set[int] = set()
        for oid in grid.near_box(bx0 - 0.3, by0 - 0.3, bx1 + 0.3, by1 + 0.3):
            o = segs[oid]
            for px, py in ((o.x1, o.y1), (o.x2, o.y2)):
                if bx0 - 0.3 <= px <= bx1 + 0.3 and by0 - 0.3 <= py <= by1 + 0.3:
                    touching.add(oid)
                    break
        if len(touching) == 2:
            a, b = touching
            uf.union(a, b)

    # tiny open line-work (connector pins, terminal feet): clusters of short lines joined at
    # corners; a wire whose END lies inside such a cluster is connected through it
    short = [w for w in wires if math.hypot(w.x2 - w.x1, w.y2 - w.y1) <= MINI_SYMBOL]
    cuf = _UF(len(segs))
    first_at: dict[int, int] = {}
    for w in short:
        for n in seg_nodes[w.id]:
            if n in first_at:
                cuf.union(first_at[n], w.id)
            else:
                first_at[n] = w.id
    clusters: dict[int, list[Segment]] = defaultdict(list)
    for w in short:
        clusters[cuf.find(w.id)].append(w)
    for members in clusters.values():
        if len(members) < 2:
            continue
        xs = [v for m in members for v in (m.x1, m.x2)]
        ys = [v for m in members for v in (m.y1, m.y2)]
        bx0, by0, bx1, by1 = min(xs), min(ys), max(xs), max(ys)
        if bx1 - bx0 > MINI_SYMBOL or by1 - by0 > MINI_SYMBOL:
            continue
        member_ids = {m.id for m in members}
        ending: set[int] = set()
        for oid in grid.near_box(bx0 - 0.3, by0 - 0.3, bx1 + 0.3, by1 + 0.3):
            if oid in member_ids:
                continue
            o = segs[oid]
            for px, py in ((o.x1, o.y1), (o.x2, o.y2)):
                if bx0 - 0.3 <= px <= bx1 + 0.3 and by0 - 0.3 <= py <= by1 + 0.3:
                    ending.add(oid)
                    break
        roots = {uf.find(e) for e in ending}
        if 2 <= len(roots) <= 3:
            DEBUG_MINI.append(((round(bx0, 1), round(by0, 1), round(bx1, 1), round(by1, 1)), len(members), sorted(ending)))
            base = members[0].id
            for e in ending:
                uf.union(base, e)
            for m in members:
                uf.union(base, m.id)

    # ---- assemble nets -----------------------------------------------------------
    groups: dict[int, list[int]] = defaultdict(list)
    for s in wires:
        groups[uf.find(s.id)].append(s.id)
    nets: list[Net] = []
    seg_net: dict[int, int] = {}
    for members in groups.values():
        if len(members) >= 8 and max(math.hypot(segs[i].x2 - segs[i].x1, segs[i].y2 - segs[i].y1) for i in members) <= ZIGZAG_MAX:
            continue                                   # hatching / zigzag symbol, not wiring
        xs = [v for sid in members for v in (segs[sid].x1, segs[sid].x2)]
        ys = [v for sid in members for v in (segs[sid].y1, segs[sid].y2)]
        nid = len(nets)
        touched = sorted({sh for sid in members for sh in net_touch_shape.get(sid, ())})
        nets.append(Net(nid, sorted(members), (round(min(xs), 3), round(min(ys), 3), round(max(xs), 3), round(max(ys), 3)), [], touched))
        for sid in members:
            seg_net[sid] = nid
        for sh in touched:
            shapes[sh]["nets"].append(nid)

    # ---- attach text labels ------------------------------------------------------
    text_net: dict[str, int] = {}
    text_shape: dict[str, int] = {}
    for t in sheet.texts:
        if t.frame:
            continue
        x0, y0, x1, y1 = t.bbox
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        # inside a (small) shape?
        best_sh = None
        best_area = math.inf
        for sh in shapes:
            bx0, by0, bx1, by1 = sh["bbox"]
            area = (bx1 - bx0) * (by1 - by0)
            if bx0 - 0.3 <= cx <= bx1 + 0.3 and by0 - 0.3 <= cy <= by1 + 0.3 and area < best_area and area < 2500:
                best_sh, best_area = sh["id"], area
        if best_sh is not None:
            text_shape[t.id] = best_sh
            shapes[best_sh]["texts"].append(t.id)
            continue
        # nearest wire (DeltaV taps and limit words are written further from their wire).  A wire whose
        # free end stops right above, below or beside the text owns it even when another wire passes
        # the text a little closer: '1L-6' under the end of its wire with the '1L+6' wire running past (085).
        tol = LOOSE_TEXT_TOL if LOOSE_LABEL_RE.match(t.text) else TEXT_TOL
        # A wire whose free end stops in line with a short label owns it: the label flag of a signal name on
        # the FLD sheets ends just left of the name, '1L-6' on 085 sits under the end of its wire.  That wins
        # over a wire merely passing the text a little closer, and such an end may stand END_TEXT_TOL away.
        # one-word labels only: pin numbers stay beside their pins, captions such as 'CONTROL ROOM' are not wire labels
        short = len(t.text.strip()) <= 12 and " " not in t.text.strip() and not re.fullmatch(r"\d{1,2}|[A-Za-z]", t.text.strip())
        end_tol = max(tol, END_TEXT_TOL) if short else tol
        box = (x0, y0, x1, y1)
        best, best_net = None, None
        for oid in grid.near_box(x0 - end_tol, y0 - end_tol, x1 + end_tol, y1 + end_tol):
            d = _seg_box_dist(segs[oid], box)
            if d > end_tol + 0.05:
                continue
            ends = _ends_at_text(segs[oid], box, end_tol, grid, segs)
            if d <= tol + 0.05:                      # inclusive: DV3_12 on 053 sits exactly 3.0 mm from its wire end
                rank = 0 if ends else 1
            elif ends:
                rank = 0
            else:
                continue
            if best is None or (rank, d) < best:
                best, best_net = (rank, d), seg_net.get(oid)
        if best_net is not None:
            text_net[t.id] = best_net
            nets[best_net].texts.append(t.id)
    shape_ports(segs, nets, shapes, {t.id: t.text for t in sheet.texts})
    return NetResult(nets, shapes, seg_net, text_net, text_shape)


def _ends_at_text(s: Segment, box, tol: float, grid: "_Grid", segs: list[Segment]) -> bool:
    """True when a free end of *s* stops within *tol* of the text box, in line with it (above or below the
    text within its x-span, or left or right of it within its y-span).  A free end touches no other wire."""
    x0, y0, x1, y1 = box
    if math.hypot(s.x2 - s.x1, s.y2 - s.y1) < 3.0 and abs(s.x2 - s.x1) > 0.1 and abs(s.y2 - s.y1) > 0.1:
        return False                                  # the diagonal strokes of a lamp cross are not a wire ending at its label
    for px, py in ((s.x1, s.y1), (s.x2, s.y2)):
        in_x = x0 - 0.3 <= px <= x1 + 0.3 and (0.0 <= y0 - py <= tol or 0.0 <= py - y1 <= tol)
        in_y = y0 - 0.3 <= py <= y1 + 0.3 and (0.0 <= x0 - px <= tol or 0.0 <= px - x1 <= tol)
        if not (in_x or in_y):
            continue
        free = True
        for oid in grid.near_box(px - 0.15, py - 0.15, px + 0.15, py + 0.15):
            if oid != s.id and _seg_box_dist(segs[oid], (px - 0.1, py - 0.1, px + 0.1, py + 0.1)) <= 0.0:
                free = False
                break
        if free:
            return True
    return False


def _port_side(px: float, py: float, ox: float, oy: float) -> str:
    """Side of a symbol a wire end (px, py) belongs to, from the direction of the wire's other end."""
    dx, dy = ox - px, oy - py
    if abs(dx) >= abs(dy):
        return "R" if dx > 0 else "L"
    return "T" if dy > 0 else "B"


def shape_ports(segs: list[Segment], nets: list[Net], shapes: list[dict], text_of: dict[str, str] | None = None) -> dict[int, list[dict]]:
    """Record where conductors touch each closed symbol: ``shape['ports']`` =
    ``[{net, side: 'L'|'R'|'T'|'B', x, y}, ...]``.

    A port is a wire END lying within PORT_TOL of the symbol's bbox (inside the
    box is allowed too: an OR gate's inputs stop on its concave back, a push
    button's wire starts inside its outline) while the wire's other end is
    outside the box.  The side is the direction the wire leaves in.  Logic gate
    outputs leave from an arc, so for gates the tolerance on the bbox is
    GATE_PORT_TOL.  Symbols the net builder registered on a net (``net.shapes``)
    but that got no port this way (tag ovals, whose bulged ends lie outside
    the vertex bbox) get one from the nearest wire end within 2 mm.
    Returns {shape id: ports} and stores the same list on every shape dict.
    """
    for sh in shapes:
        sh["ports"] = []
    if not shapes or not nets:
        return {}
    text_of = text_of or {}
    gates = {sh["id"] for sh in shapes if any(text_of.get(t, "").strip().upper() in GATE_WORDS for t in sh.get("texts", []))}
    grid = _BoxGrid(shapes, cell=10.0)
    by_id = {sh["id"]: sh for sh in shapes}
    for net in nets:
        seen: set[tuple] = set()
        got: set[int] = set()
        for sid in net.segments:
            s = segs[sid]
            for px, py, ox, oy in ((s.x1, s.y1, s.x2, s.y2), (s.x2, s.y2, s.x1, s.y1)):
                for sh in grid.near_point(px, py, GATE_PORT_TOL):
                    b = sh["bbox"]
                    tol = GATE_PORT_TOL if sh["id"] in gates else PORT_TOL
                    if not _inside(px, py, b, tol) or _inside(ox, oy, b, 0.0):
                        continue
                    side = _port_side(px, py, ox, oy)
                    key = (sh["id"], side, round(px, 1), round(py, 1))
                    if key in seen:
                        continue
                    seen.add(key)
                    got.add(sh["id"])
                    sh["ports"].append({"net": net.id, "side": side, "x": round(px, 2), "y": round(py, 2)})
        for shid in net.shapes:
            if shid in got or shid not in by_id:
                continue
            sh = by_id[shid]
            b = sh["bbox"]
            best = None
            for sid in net.segments:
                s = segs[sid]
                for px, py, ox, oy in ((s.x1, s.y1, s.x2, s.y2), (s.x2, s.y2, s.x1, s.y1)):
                    d = math.hypot(max(b[0] - px, 0.0, px - b[2]), max(b[1] - py, 0.0, py - b[3]))
                    if d <= 2.0 and (best is None or d < best[0]):
                        best = (d, px, py, ox, oy)
            if best is not None:
                _d, px, py, ox, oy = best
                sh["ports"].append({"net": net.id, "side": _port_side(px, py, ox, oy), "x": round(px, 2), "y": round(py, 2)})
    return {sh["id"]: sh["ports"] for sh in shapes}


def _inside(x: float, y: float, b, tol: float = 0.05) -> bool:
    return b[0] - tol <= x <= b[2] + tol and b[1] - tol <= y <= b[3] + tol


def _clip_box(s: Segment, b):
    """Liang-Barsky: parameter range of the segment inside the box, or None."""
    dx, dy = s.x2 - s.x1, s.y2 - s.y1
    t0, t1 = 0.0, 1.0
    for p, q in ((-dx, s.x1 - b[0]), (dx, b[2] - s.x1), (-dy, s.y1 - b[1]), (dy, b[3] - s.y1)):
        if abs(p) < 1e-12:
            if q < 0:
                return None
            continue
        r = q / p
        if p < 0:
            if r > t1:
                return None
            t0 = max(t0, r)
        else:
            if r < t0:
                return None
            t1 = min(t1, r)
    return (t0, t1) if t0 < t1 else None


def _split(s: Segment, t0: float, t1: float, segs: list[Segment]) -> list[Segment]:
    """Replace a segment crossing a device by its two outside parts (appended to *segs*)."""
    out = []
    for (ta, tb) in ((0.0, t0), (t1, 1.0)):
        if tb - ta <= 1e-9:
            continue
        piece = Segment(len(segs), s.handle, s.layer,
                        s.x1 + (s.x2 - s.x1) * ta, s.y1 + (s.y2 - s.y1) * ta,
                        s.x1 + (s.x2 - s.x1) * tb, s.y1 + (s.y2 - s.y1) * tb, s.kind, s.dashed, s.block)
        segs.append(piece)
        out.append(piece)
    return out


class _BoxGrid:
    """Coarse grid over device boxes for quick candidate lookup."""

    def __init__(self, boxes: list[dict], cell: float = 10.0) -> None:
        self.cell = cell
        self.cells: dict[tuple[int, int], list[dict]] = defaultdict(list)
        for bx in boxes:
            b = bx["bbox"]
            for ix in range(int(math.floor(b[0] / cell)), int(math.floor(b[2] / cell)) + 1):
                for iy in range(int(math.floor(b[1] / cell)), int(math.floor(b[3] / cell)) + 1):
                    self.cells[(ix, iy)].append(bx)

    def near_point(self, x: float, y: float, r: float) -> list[dict]:
        c = self.cell
        seen: dict[int, dict] = {}
        for ix in range(int(math.floor((x - r) / c)), int(math.floor((x + r) / c)) + 1):
            for iy in range(int(math.floor((y - r) / c)), int(math.floor((y + r) / c)) + 1):
                for bx in self.cells.get((ix, iy), ()):
                    b = bx["bbox"]
                    if b[0] - r <= x <= b[2] + r and b[1] - r <= y <= b[3] + r:
                        seen[bx["id"]] = bx
        return list(seen.values())

    def candidates(self, s: Segment) -> list[dict]:
        c = self.cell
        x0, x1 = sorted((s.x1, s.x2))
        y0, y1 = sorted((s.y1, s.y2))
        seen: dict[int, dict] = {}
        for ix in range(int(math.floor(x0 / c)), int(math.floor(x1 / c)) + 1):
            for iy in range(int(math.floor(y0 / c)), int(math.floor(y1 / c)) + 1):
                for bx in self.cells.get((ix, iy), ()):
                    b = bx["bbox"]
                    if x0 <= b[2] and x1 >= b[0] and y0 <= b[3] and y1 >= b[1]:
                        seen[bx["id"]] = bx
        return list(seen.values())


def _find_bridges(adj: dict[int, list[tuple[int, int]]]) -> set[int]:
    """Iterative Tarjan bridge finding on a multigraph; returns bridge edge ids."""
    disc: dict[int, int] = {}
    low: dict[int, int] = {}
    bridges: set[int] = set()
    timer = 0
    for root in list(adj.keys()):
        if root in disc:
            continue
        stack = [(root, -1, iter(adj[root]))]
        disc[root] = low[root] = timer
        timer += 1
        while stack:
            v, pe, it = stack[-1]
            advanced = False
            for (w, eid) in it:
                if eid == pe:
                    continue
                if w not in disc:
                    disc[w] = low[w] = timer
                    timer += 1
                    stack.append((w, eid, iter(adj[w])))
                    advanced = True
                    break
                low[v] = min(low[v], disc[w])
            if not advanced:
                stack.pop()
                if stack:
                    u = stack[-1][0]
                    low[u] = min(low[u], low[v])
                    if low[v] > disc[u]:
                        bridges.add(pe)
    return bridges
