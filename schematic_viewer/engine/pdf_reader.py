"""PDF support: page-to-sheet mapping, page backdrop images aligned to the
DXF coordinate system, and the text layer of PDFs that have one.

The supplied PDF (plotted by DWG TrueView) has NO text layer: every character
was plotted as outlines, so nothing can be read from it without OCR.  It is
still useful as a visual backdrop, and a PDF produced with a real text layer
is indexed through the same identifier pipeline as the DXF text.
"""
from __future__ import annotations

import os
import re
from dataclasses import dataclass
from typing import Optional

try:
    import pymupdf  # type: ignore
except Exception:  # pragma: no cover - optional dependency
    pymupdf = None

PT_TO_MM = 25.4 / 72.0


def available() -> bool:
    return pymupdf is not None


def _norm(s: str) -> str:
    return re.sub(r"[\s_\-]+", "", s).upper()


def decode_label(label: str) -> str:
    if label.startswith("<FEFF"):
        try:
            label = bytes.fromhex(label[1:-1]).decode("utf-16-be")
        except Exception:
            pass
    return label.lstrip("\ufeff").strip()


@dataclass
class PageInfo:
    page: int                 # 1-based
    label: str
    name: str                 # label without "[n] " and "-Model"
    width_pt: float
    height_pt: float
    rotation: int
    words: int


def read_pages(pdf_path: str) -> list[PageInfo]:
    doc = pymupdf.open(pdf_path)
    out = []
    for i, page in enumerate(doc):
        lbl = decode_label(page.get_label() or "")
        m = re.match(r"\[(\d+)\]\s*(.*?)(?:-Model|-Layout\d*)?$", lbl)
        name = m.group(2) if m else lbl
        out.append(PageInfo(i + 1, lbl, name, page.rect.width, page.rect.height, page.rotation,
                            len(page.get_text("words"))))
    doc.close()
    return out


def map_pages_to_sheets(pages: list[PageInfo], sheets: dict[str, str]) -> dict[int, str]:
    """Map PDF page numbers to sheet ids.

    *sheets* maps sheet id -> DXF file name.  Matching order: page label equals
    the DXF file name (as DWG TrueView writes it), then a sheet id contained in
    the label, then page order when both sets have the same size.
    """
    by_name = {_norm(re.sub(r"\.dxf$", "", f, flags=re.I)): sid for sid, f in sheets.items()}
    result: dict[int, str] = {}
    used: set[str] = set()
    for p in pages:
        key = _norm(p.name)
        sid = by_name.get(key)
        if sid is None:
            m = re.search(r"(?<!\d)(\d{3}[A-Z]?)(?!\d)", p.name)
            if m and m.group(1) in sheets:
                sid = m.group(1)
        if sid is not None and sid not in used:
            result[p.page] = sid
            used.add(sid)
    if not result and len(pages) == len(sheets):
        for p, sid in zip(pages, sorted(sheets)):
            result[p.page] = sid
    return result


@dataclass
class Backdrop:
    file: str
    x: float          # SVG/mm coordinates of the image's top-left corner (y is -mm)
    y: float
    w: float
    h: float
    quality: str      # 'aligned' | 'approximate' | 'unaligned'
    residual: float   # relative scale mismatch between x and y fits


def _vector_bbox_rotated(page) -> Optional[tuple[float, float, float, float]]:
    """Bounding box of all vector drawing on the page in rotated page points."""
    xs: list[float] = []
    ys: list[float] = []
    m = page.rotation_matrix
    try:
        drawings = page.get_drawings()
    except Exception:
        drawings = []
    for d in drawings:
        r = d.get("rect")
        if r is None or r.is_infinite:
            continue
        for pt in (r.tl, r.tr, r.bl, r.br):
            q = pt * m
            xs.append(q.x)
            ys.append(q.y)
    if not xs:
        return None
    return (min(xs), min(ys), max(xs), max(ys))


def _frame_rect_rotated(page) -> Optional[tuple[float, float, float, float]]:
    """Rectangle spanned by the longest horizontal/vertical lines (the drawing frame)."""
    m = page.rotation_matrix
    W, H = page.rect.width, page.rect.height
    hor: list[float] = []
    ver: list[float] = []
    try:
        drawings = page.get_drawings()
    except Exception:
        return None
    for d in drawings:
        for it in d["items"]:
            pairs = []
            if it[0] == "l":
                pairs = [(it[1], it[2])]
            elif it[0] == "re":
                r = it[1]
                pairs = [(r.tl, r.tr), (r.tr, r.br), (r.br, r.bl), (r.bl, r.tl)]
            elif it[0] == "qu":
                q = it[1]
                pairs = [(q.ul, q.ur), (q.ur, q.lr), (q.lr, q.ll), (q.ll, q.ul)]
            for a, b in pairs:
                a, b = a * m, b * m
                if abs(a.y - b.y) < 0.6 and abs(a.x - b.x) >= 0.25 * W:
                    hor.append((a.y + b.y) / 2)
                if abs(a.x - b.x) < 0.6 and abs(a.y - b.y) >= 0.25 * H:
                    ver.append((a.x + b.x) / 2)
    if len(hor) < 2 or len(ver) < 2:
        return None
    return (min(ver), min(hor), max(ver), max(hor))


def render_backdrop(pdf_path: str, page_no: int, out_png: str, dxf_extents: Optional[tuple[float, float, float, float]],
                    dpi: int = 110, dxf_frame: Optional[tuple[float, float, float, float]] = None) -> Backdrop:
    """Rasterise one page and compute where it sits in the sheet's mm space.

    Alignment uses the drawing frame (the extreme long horizontal and vertical
    lines, present in both the PDF and the DXF) and falls back to matching the
    overall bounding boxes.  Without DXF the page itself defines the coordinate
    system (1 pt = 25.4/72 mm, origin bottom-left).
    """
    doc = pymupdf.open(pdf_path)
    page = doc[page_no - 1]
    pix = page.get_pixmap(dpi=dpi)
    os.makedirs(os.path.dirname(out_png) or ".", exist_ok=True)
    pix.save(out_png)
    W_pt, H_pt = page.rect.width, page.rect.height
    name = os.path.basename(out_png)
    if dxf_extents is None:
        w_mm, h_mm = W_pt * PT_TO_MM, H_pt * PT_TO_MM
        doc.close()
        return Backdrop(name, 0.0, -h_mm, w_mm, h_mm, "aligned", 0.0)

    fits: list[tuple[str, float, float, float, float, float]] = []   # (method, s, px0, py0, dx0, dy1, residual)
    pf = _frame_rect_rotated(page)
    if pf is not None and dxf_frame is not None and dxf_frame[2] - dxf_frame[0] > 50 and dxf_frame[3] - dxf_frame[1] > 50:
        sx = (pf[2] - pf[0]) / (dxf_frame[2] - dxf_frame[0])
        sy = (pf[3] - pf[1]) / (dxf_frame[3] - dxf_frame[1])
        s = (sx + sy) / 2
        fits.append(("frame", s, pf[0], pf[1], dxf_frame[0], dxf_frame[3], abs(sx - sy) / s))
    vb = _vector_bbox_rotated(page)
    xmin, ymin, xmax, ymax = dxf_extents
    if vb is not None and xmax - xmin > 0 and ymax - ymin > 0:
        sx = (vb[2] - vb[0]) / (xmax - xmin)
        sy = (vb[3] - vb[1]) / (ymax - ymin)
        s = (sx + sy) / 2
        fits.append(("bbox", s, vb[0], vb[1], xmin, ymax, abs(sx - sy) / s))
    doc.close()
    if not fits:
        return Backdrop(name, xmin, -ymax, xmax - xmin, ymax - ymin, "unaligned", 1.0)
    fits.sort(key=lambda f: f[6])
    method, s, px0, py0, dx0, dy1, residual = fits[0]
    x_mm = dx0 - px0 / s                 # page's top-left corner in mm
    y_top_mm = dy1 + py0 / s
    w_mm, h_mm = W_pt / s, H_pt / s
    quality = "aligned" if residual < 0.01 else ("approximate" if residual < 0.04 else "unaligned")
    return Backdrop(name, round(x_mm, 3), round(-y_top_mm, 3), round(w_mm, 3), round(h_mm, 3), quality, round(residual, 4))


def page_words_mm(pdf_path: str, page_no: int) -> list[dict]:
    """Words and multi-word lines of a PDF page with boxes in mm (y up, origin bottom-left).

    PyMuPDF reports text in the un-rotated page space; the boxes are rotated
    into the displayed page space so that they match the rendered backdrop.
    """
    doc = pymupdf.open(pdf_path)
    page = doc[page_no - 1]
    m = page.rotation_matrix
    H = page.rect.height

    def box_mm(x0, y0, x1, y1):
        pts = [pymupdf.Point(x0, y0) * m, pymupdf.Point(x1, y0) * m, pymupdf.Point(x0, y1) * m, pymupdf.Point(x1, y1) * m]
        xs = [q.x for q in pts]
        ys = [q.y for q in pts]
        return (round(min(xs) * PT_TO_MM, 3), round((H - max(ys)) * PT_TO_MM, 3),
                round(max(xs) * PT_TO_MM, 3), round((H - min(ys)) * PT_TO_MM, 3))

    out = []
    for i, w in enumerate(page.get_text("words")):
        text = w[4].strip()
        if text:
            out.append({"id": f"w{page_no}_{i}", "text": text, "bbox": box_mm(w[0], w[1], w[2], w[3]), "kind": "PDFWORD"})
    try:
        d = page.get_text("dict")
        n = 0
        for block in d.get("blocks", []):
            for line in block.get("lines", []):
                text = " ".join(sp.get("text", "") for sp in line.get("spans", [])).strip()
                if " " in text:
                    b = line["bbox"]
                    out.append({"id": f"l{page_no}_{n}", "text": text, "bbox": box_mm(*b), "kind": "PDFLINE"})
                    n += 1
    except Exception:
        pass
    doc.close()
    return out


def page_size_mm(pdf_path: str, page_no: int) -> tuple[float, float]:
    doc = pymupdf.open(pdf_path)
    page = doc[page_no - 1]
    w, h = page.rect.width * PT_TO_MM, page.rect.height * PT_TO_MM
    doc.close()
    return (round(w, 3), round(h, 3))
