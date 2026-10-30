"""Wire connectivity ("nets") for one sheet, derived purely from geometry.

Rules (standard schematic conventions):
* two wire segments are connected when an end point of one coincides with an
  end point of the other, or lies on the other segment (T-junction);
* lines that merely cross are NOT connected unless a junction dot is drawn;
* a filled dot connects every wire passing through it;
* closed outlines (device symbols, continuation boxes, tag ovals, module
  boxes, logic gates) are not wires: a wire ends where it touches them and the
  net records which outline it touches;
* a hollow circle with exactly two wires ending on it (an in-line terminal)
  passes the net through, any other circle is treated as a device boundary.

Nothing here claims an electrical connection between *different* sheets; it
only groups the drawn conductors of one sheet.
"""
from __future__ import annotations

import math
from collections import defaultdict
from dataclasses import dataclass, field

from .dxf_reader import SheetData, Segment

NODE_TOL = 0.05      # mm, end point coincidence
T_TOL = 0.08         # mm, end point on another segment
DOT_TOL = 0.35       # mm, wire passes through a junction dot
TEXT_TOL = 1.2       # mm, label-to-wire distance
SHAPE_MAX_DIAG = 90  # mm, closed loops smaller than this are symbols, not ring wiring
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

    # ---- wire union-find ---------------------------------------------------------
    wires = [s for s in segs if s.id not in shape_edges]
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
    # in-line terminals (hollow circles with exactly two wire ends on them)
    for cx, cy, r, _h in sheet.circles:
        if r > 1.6:
            continue
        ends = []
        for oid in grid.near(cx, cy, r + 0.2):
            o = segs[oid]
            for px, py in ((o.x1, o.y1), (o.x2, o.y2)):
                if abs(math.hypot(px - cx, py - cy) - r) <= 0.2:
                    ends.append(oid)
        if len(set(ends)) == 2:
            a, b = set(ends)
            uf.union(a, b)

    # ---- assemble nets -----------------------------------------------------------
    groups: dict[int, list[int]] = defaultdict(list)
    for s in wires:
        groups[uf.find(s.id)].append(s.id)
    nets: list[Net] = []
    seg_net: dict[int, int] = {}
    for members in groups.values():
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
        # nearest wire
        best_d, best_net = TEXT_TOL, None
        for oid in grid.near_box(x0 - TEXT_TOL, y0 - TEXT_TOL, x1 + TEXT_TOL, y1 + TEXT_TOL):
            d = _seg_box_dist(segs[oid], (x0, y0, x1, y1))
            if d < best_d:
                best_d, best_net = d, seg_net.get(oid)
        if best_net is not None:
            text_net[t.id] = best_net
            nets[best_net].texts.append(t.id)
    return NetResult(nets, shapes, seg_net, text_net, text_shape)


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
