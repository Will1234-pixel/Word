"""Render the visible content of a DXF modelspace to SVG with coordinates in
drawing millimetres.

The SVG user unit is one drawing unit (mm on these sheets).  Because SVG's
y axis points down, every DXF point (x, y) is written as (x, -y).  The viewer
uses the same convention, so highlight rectangles computed from DXF
coordinates land exactly on the rendered geometry.

Geometry and text are produced by ezdxf's drawing front end (which honours
frozen/off layers, block references, attributes, polyline widths, line types
and text alignment) and captured by a small custom backend below.  Text is
emitted as glyph outlines, exactly as the original PDF plot did, so the page
looks the same on every machine regardless of installed fonts.
"""
from __future__ import annotations

import gzip
import math
from dataclasses import dataclass, field
from typing import Iterable, Optional

from ezdxf.addons.drawing import Frontend, RenderContext, config
from ezdxf.addons.drawing.backend import Backend
from ezdxf.addons.drawing.properties import BackendProperties
from ezdxf.math import Vec2
from ezdxf.path import Command


def _f(v: float) -> str:
    """Compact float formatter (3 decimals, no trailing zeros)."""
    s = f"{v:.3f}"
    if "." in s:
        s = s.rstrip("0").rstrip(".")
    return s if s not in ("-0", "") else "0"


def _pt(p) -> str:
    return f"{_f(p.x)} {_f(-p.y)}"


@dataclass
class EntityRecord:
    handle: str
    dxftype: str
    layer: str
    paths: list[str] = field(default_factory=list)   # svg element strings
    xmin: float = math.inf
    ymin: float = math.inf
    xmax: float = -math.inf
    ymax: float = -math.inf

    def grow(self, pts: Iterable) -> None:
        for p in pts:
            x, y = p.x, p.y
            if x < self.xmin:
                self.xmin = x
            if x > self.xmax:
                self.xmax = x
            if y < self.ymin:
                self.ymin = y
            if y > self.ymax:
                self.ymax = y

    @property
    def has_bbox(self) -> bool:
        return self.xmin <= self.xmax


class SvgMmBackend(Backend):
    """ezdxf drawing backend that writes SVG in drawing units (mm, y up)."""

    MIN_STROKE = 0.18  # mm, thinnest visible line (matches a 0.18 pen)

    def __init__(self, monochrome: bool = True) -> None:
        super().__init__()
        self.monochrome = monochrome
        self.records: list[EntityRecord] = []
        self._current: Optional[EntityRecord] = None
        self._orphans = EntityRecord("", "", "")

    # -- entity bookkeeping -------------------------------------------------
    def enter_entity(self, entity, properties) -> None:  # type: ignore[override]
        super().enter_entity(entity, properties)
        rec = EntityRecord(entity.dxf.handle, entity.dxftype(), properties.layer)
        self.records.append(rec)
        self._current = rec

    def exit_entity(self, entity) -> None:  # type: ignore[override]
        super().exit_entity(entity)
        self._current = None

    def _rec(self) -> EntityRecord:
        return self._current if self._current is not None else self._orphans

    # -- styling --------------------------------------------------------------
    def _stroke_attrs(self, properties: BackendProperties) -> str:
        width = max(properties.lineweight, self.MIN_STROKE)
        color = "#000" if self.monochrome else properties.color[:7]
        return f'stroke="{color}" stroke-width="{_f(width)}" fill="none"'

    def _fill_attrs(self, properties: BackendProperties) -> str:
        color = "#000" if self.monochrome else properties.color[:7]
        return f'fill="{color}" stroke="none"'

    # -- drawing primitives ---------------------------------------------------
    def set_background(self, color) -> None:
        pass

    def draw_point(self, pos: Vec2, properties: BackendProperties) -> None:
        rec = self._rec()
        rec.grow([pos])
        rec.paths.append(f'<circle cx="{_f(pos.x)}" cy="{_f(-pos.y)}" r="0.25" {self._fill_attrs(properties)}/>')

    def draw_line(self, start: Vec2, end: Vec2, properties: BackendProperties) -> None:
        rec = self._rec()
        rec.grow([start, end])
        rec.paths.append(f'<path d="M{_pt(start)}L{_pt(end)}" {self._stroke_attrs(properties)}/>')

    def draw_solid_lines(self, lines, properties: BackendProperties) -> None:
        lines = list(lines)
        if not lines:
            return
        rec = self._rec()
        d = []
        for s, e in lines:
            rec.grow([s, e])
            d.append(f"M{_pt(s)}L{_pt(e)}")
        rec.paths.append(f'<path d="{"".join(d)}" {self._stroke_attrs(properties)}/>')

    def _path_d(self, path, close: bool) -> str:
        if len(path) == 0:
            return ""
        rec = self._rec()
        d = [f"M{_pt(path.start)}"]
        rec.grow([path.start])
        for cmd in path.commands():
            end = cmd.end
            if cmd.type == Command.MOVE_TO:
                d.append(f"M{_pt(end)}")
            elif cmd.type == Command.LINE_TO:
                d.append(f"L{_pt(end)}")
            elif cmd.type == Command.CURVE3_TO:
                d.append(f"Q{_pt(cmd.ctrl)} {_pt(end)}")
                rec.grow([cmd.ctrl])
            elif cmd.type == Command.CURVE4_TO:
                d.append(f"C{_pt(cmd.ctrl1)} {_pt(cmd.ctrl2)} {_pt(end)}")
                rec.grow([cmd.ctrl1, cmd.ctrl2])
            rec.grow([end])
        if close:
            d.append("Z")
        return "".join(d)

    def draw_path(self, path, properties: BackendProperties) -> None:
        d = self._path_d(path, close=False)
        if d:
            self._rec().paths.append(f'<path d="{d}" {self._stroke_attrs(properties)}/>')

    def draw_filled_paths(self, paths, properties: BackendProperties) -> None:
        d = [self._path_d(p, close=True) for p in paths if len(p)]
        d = [x for x in d if x]
        if d:
            self._rec().paths.append(f'<path d="{"".join(d)}" fill-rule="evenodd" {self._fill_attrs(properties)}/>')

    def draw_filled_polygon(self, points, properties: BackendProperties) -> None:
        verts = points.vertices()
        if len(verts) < 3:
            return
        rec = self._rec()
        rec.grow(verts)
        d = "M" + "L".join(_pt(v) for v in verts) + "Z"
        rec.paths.append(f'<path d="{d}" {self._fill_attrs(properties)}/>')

    def draw_image(self, image_data, properties: BackendProperties) -> None:
        pass  # raster images are not used in these drawing sets

    def clear(self) -> None:
        self.records.clear()

    def finalize(self) -> None:
        pass


@dataclass
class RenderResult:
    svg: str
    xmin: float
    ymin: float
    xmax: float
    ymax: float
    entity_bboxes: dict[str, tuple[float, float, float, float]]


def render_modelspace(doc, monochrome: bool = True, margin: float = 3.0) -> RenderResult:
    """Render the visible modelspace of *doc* and return SVG + extents."""
    msp = doc.modelspace()
    ctx = RenderContext(doc)
    backend = SvgMmBackend(monochrome=monochrome)
    cfg = config.Configuration(
        background_policy=config.BackgroundPolicy.OFF,
        color_policy=config.ColorPolicy.BLACK if monochrome else config.ColorPolicy.COLOR,
        lineweight_policy=config.LineweightPolicy.ABSOLUTE,
        text_policy=config.TextPolicy.FILLING,
        min_lineweight=0.0,
    )
    Frontend(ctx, backend, config=cfg).draw_layout(msp, finalize=True)

    xmin = ymin = math.inf
    xmax = ymax = -math.inf
    body: list[str] = []
    bboxes: dict[str, tuple[float, float, float, float]] = {}
    for rec in backend.records:
        if not rec.paths:
            continue
        if rec.has_bbox:
            xmin = min(xmin, rec.xmin)
            ymin = min(ymin, rec.ymin)
            xmax = max(xmax, rec.xmax)
            ymax = max(ymax, rec.ymax)
            bboxes[rec.handle] = (rec.xmin, rec.ymin, rec.xmax, rec.ymax)
        body.append(f'<g id="e{rec.handle}">{"".join(rec.paths)}</g>')
    if backend._orphans.paths:
        body.append(f'<g id="e_">{"".join(backend._orphans.paths)}</g>')
    if not math.isfinite(xmin):
        xmin = ymin = 0.0
        xmax = ymax = 100.0
    x0, y0 = xmin - margin, ymin - margin
    w, h = (xmax - xmin) + 2 * margin, (ymax - ymin) + 2 * margin
    svg = (
        '<svg xmlns="http://www.w3.org/2000/svg" '
        f'viewBox="{_f(x0)} {_f(-(y0 + h))} {_f(w)} {_f(h)}" '
        f'width="{_f(w)}mm" height="{_f(h)}mm">'
        '<g stroke-linecap="round" stroke-linejoin="round">'
        + "".join(body)
        + "</g></svg>"
    )
    return RenderResult(svg, xmin, ymin, xmax, ymax, bboxes)


def write_svg(result: RenderResult, path: str, compress: bool = True) -> str:
    """Write the SVG (gzip-compressed when *compress*) and return the file name."""
    data = result.svg.encode("utf-8")
    if compress:
        path = path + ".gz" if not path.endswith(".gz") else path
        with open(path, "wb") as raw, gzip.GzipFile(filename="", mode="wb", compresslevel=6, fileobj=raw, mtime=0) as fh:
            fh.write(data)
    else:
        with open(path, "wb") as fh:
            fh.write(data)
    return path
