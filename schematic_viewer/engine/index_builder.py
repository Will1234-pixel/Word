"""Build the cross-reference project: per-sheet data files, identifier index,
resolved links and the issues report.

Link status vocabulary (what the viewer shows the engineer):
  verified      explicit pointer, label found at destination AND the destination
                carries a pointer back to the source sheet
  matched       explicit pointer, label found at destination, no back pointer
  backref_only  explicit pointer, label not found but the destination points
                back to the source sheet near the given grid position
  ambiguous     several equally plausible targets - the engineer must choose
  unresolved    pointer could not be matched; only the grid position is known
  missing_sheet pointer to a sheet that is not in the imported set
  external      pointer to another drawing volume
  sheet         pointer to a whole sheet (SEE DRG ..., schedule entries)
  typical       LOOP TYPE pointer to a typical loop drawing
Same-label appearances are never stored as links; they are listed on demand
and clearly marked as unverified.
"""
from __future__ import annotations

import json
import os
import re
import time
from collections import defaultdict
from dataclasses import dataclass, field, asdict
from typing import Callable, Optional

from .dxf_reader import SheetData, TextItem, read_sheet
from .identifiers import Ident, XREF_RE, classify, is_connection_kind
from .nets import build_nets, NetResult
from .svg_render import render_modelspace, write_svg

DEFAULT_RULER = (0.998, -4.6)   # x_mm = a*grid + b when a sheet has no ruler


def norm_label(s: str) -> str:
    s = s.strip().upper()
    s = re.sub(r"^\((.*)\)$", r"\1", s)
    return re.sub(r"\s+", "", s)


@dataclass
class Link:
    id: str
    kind: str                       # xref | sheet | typical
    status: str
    src_sheet: str
    src_text: str
    dst_sheet: Optional[str]
    dst_text: Optional[str] = None
    dst_point: Optional[tuple[float, float]] = None
    label: str = ""                 # the companion label used for matching
    grid: Optional[int] = None
    candidates: list[dict] = field(default_factory=list)
    note: str = ""
    labels: list[str] = field(default_factory=list)


@dataclass
class SheetRecord:
    data: SheetData
    texts: dict[str, TextItem]
    idents: dict[str, list[Ident]]
    nets: object
    companions: dict[str, list[str]] = field(default_factory=dict)   # xref text id -> companion text ids
    is_signal_companion: set = field(default_factory=set)
    schedule: bool = False
    typical: bool = False


def _center(t: TextItem) -> tuple[float, float]:
    b = t.bbox
    return ((b[0] + b[2]) / 2, (b[1] + b[3]) / 2)


def _gap(a: tuple, b: tuple) -> tuple[float, float]:
    """Horizontal and vertical gaps between two boxes (0 when overlapping)."""
    gx = max(0.0, b[0] - a[2], a[0] - b[2])
    gy = max(0.0, b[1] - a[3], a[1] - b[3])
    return gx, gy


def find_companions(rec: SheetRecord, xref: TextItem) -> list[str]:
    """Texts that belong to an explicit pointer, best first.

    A pointer's label sits in the same row (FLD continuation box), directly
    above/below (power distribution) or in a box touching the pointer text.
    Candidates are ranked by the gap between the two texts; purely alphabetic
    words (HIGH, LOW, PANEL ...) are kept only as a last resort.
    """
    bx = xref.bbox
    h = max(xref.height, 1.0)
    shape_of = rec.nets.text_shape if rec.nets else {}
    my_shape = shape_of.get(xref.id)
    out: list[tuple[float, str]] = []
    for t in rec.texts.values():
        if t.id == xref.id or t.frame or XREF_RE.match(t.text) or len(t.text) > 24:
            continue
        gx, gy = _gap(bx, t.bbox)
        same_row = gy <= 0.5 * h and gx <= 10.0
        overlap_x = min(bx[2], t.bbox[2]) - max(bx[0], t.bbox[0])
        same_col = overlap_x > -3.0 and gy <= 4.5 and gx == 0.0
        in_box = my_shape is not None and shape_of.get(t.id) == my_shape
        near_box = False
        if not in_box and shape_of.get(t.id) is not None:
            sb = rec.nets.shapes[shape_of[t.id]]["bbox"]
            sgx, sgy = _gap(bx, sb)
            near_box = sgx <= 2.5 and sgy <= 1.0
        if not (same_row or same_col or in_box or near_box):
            continue
        score = (gx * gx + gy * gy) ** 0.5
        if in_box or near_box:
            score -= 1.0
        if re.fullmatch(r"[A-Z ]{4,}", t.text):
            score += 5.0
        out.append((score, t.id))
    out.sort()
    return [tid for _s, tid in out[:3]]


def match_keys(text: str, idents: list[Ident]) -> set[str]:
    """Keys under which a text can be matched (exact text, identifier keys, relaxed forms)."""
    keys = {norm_label(text)}
    for i in idents:
        keys.add(f"{i.kind}:{i.key}")
        if i.kind == "terminal":
            keys.add(f"terminal:{re.sub(r'[:/-][0-9]+$', '', i.key)}")   # XG.21:2 -> XG.21
    # composite labels such as 'AL-/BL-' (only when the whole text is not an identifier itself)
    if not idents and re.search(r"[/,&]| AND ", text.upper()):
        for part in re.split(r"[/,&]| AND ", text.upper()):
            part = part.strip()
            if len(part) >= 2 and part != text.upper() and re.search(r"[A-Z]", part):
                keys.add(norm_label(part))
                for i in classify(part):
                    if i.kind != "signal":
                        keys.add(f"{i.kind}:{i.key}")
    return keys


def _grid_x(rec: SheetRecord, grid: int) -> float:
    a, b = rec.data.ruler or DEFAULT_RULER
    return a * grid + b


def _back_xref_near(rec: SheetRecord, t: TextItem, src_sheet: str) -> Optional[TextItem]:
    """An explicit pointer next to *t* that points back to *src_sheet*."""
    best = None
    for o in rec.texts.values():
        m = XREF_RE.match(o.text)
        if not m or m.group(1) != src_sheet:
            continue
        gx, gy = _gap(t.bbox, o.bbox)
        if gx <= 12.0 and gy <= 5.0:
            d = gx + gy
            if best is None or d < best[0]:
                best = (d, o)
    return best[1] if best else None


QUALITY_STATUS = {0: "verified", 1: "backref", 2: "matched", 3: "matched", 4: "backref"}
QUALITY_WHY = {0: "label and back pointer", 1: "back pointer near grid position", 2: "label match",
               3: "similar label", 4: "back pointer far from grid position"}


def resolve_xref(src: SheetRecord, xref: TextItem, dst: Optional[SheetRecord], dst_sheet: str, grid: int) -> Link:
    lid = f"{src.data.sheet_id}:{xref.id}"
    comp_ids = src.companions.get(xref.id, [])
    labels = [src.texts[c].text for c in comp_ids]
    label = labels[0] if labels else ""
    if dst is None:
        return Link(lid, "xref", "missing_sheet", src.data.sheet_id, xref.id, dst_sheet, label=label, grid=grid,
                    note=f"sheet {dst_sheet} is not in the imported set", labels=labels)
    gx = _grid_x(dst, grid)
    ymid = (dst.data.extents[1] + dst.data.extents[3]) / 2
    dst_keys: dict[str, set[str]] = {}
    for t in dst.texts.values():
        if t.frame or XREF_RE.match(t.text):
            continue
        dst_keys[t.id] = match_keys(t.text, dst.idents.get(t.id, []))

    cands: list[dict] = []
    seen: set[str] = set()
    used_label = label
    for c in comp_ids:
        ct = src.texts[c]
        exact = {norm_label(ct.text)} | {f"{i.kind}:{i.key}" for i in src.idents.get(c, [])}
        relaxed = match_keys(ct.text, src.idents.get(c, [])) - exact
        found = False
        for t in dst.texts.values():
            keys = dst_keys.get(t.id)
            if not keys:
                continue
            if keys & exact:
                how = 2
            elif keys & relaxed or (set(dst_keys[t.id]) & exact):
                how = 3
            else:
                continue
            back = _back_xref_near(dst, t, src.data.sheet_id)
            tcx, tcy = _center(t)
            q = 0 if back else how
            cands.append({"sheet": dst_sheet, "text": t.id, "label": t.text, "x": round(tcx, 2), "y": round(tcy, 2),
                          "grid_dist": round(abs(tcx - gx), 1), "back": back.id if back else None, "q": q, "why": QUALITY_WHY[q]})
            seen.add(t.id)
            found = True
        if found:
            used_label = ct.text
            break
    for t in dst.texts.values():
        m = XREF_RE.match(t.text)
        if not m or m.group(1) != src.data.sheet_id or t.id in seen:
            continue
        tcx, tcy = _center(t)
        gd = abs(tcx - gx)
        q = 1 if gd <= 60 else 4
        cands.append({"sheet": dst_sheet, "text": t.id, "label": t.text, "x": round(tcx, 2), "y": round(tcy, 2),
                      "grid_dist": round(gd, 1), "back": t.id, "q": q, "why": QUALITY_WHY[q]})
    cands.sort(key=lambda c: (c["q"], c["grid_dist"]))
    if not cands:
        return Link(lid, "xref", "unresolved", src.data.sheet_id, xref.id, dst_sheet, dst_point=(round(gx, 2), round(ymid, 2)),
                    label=label, grid=grid, labels=labels,
                    note="no matching label or back pointer found on the destination sheet; showing the grid position only")
    best = cands[0]
    status = QUALITY_STATUS[best["q"]]
    peers = [c for c in cands[1:] if c["q"] == best["q"]]
    if peers:
        if best["q"] == 0:
            status = "multiple"            # several verified destinations - the engineer chooses
        elif abs(peers[0]["grid_dist"] - best["grid_dist"]) < 40:
            status = "ambiguous"
    return Link(lid, "xref", status, src.data.sheet_id, xref.id, dst_sheet, dst_text=best["text"],
                dst_point=(best["x"], best["y"]), label=used_label, grid=grid, candidates=cands[:8], labels=labels)


def build_project(dxf_files: list[str], out_dir: str, progress: Callable[[str], None] = print,
                  pdf_path: Optional[str] = None, backdrops: bool = True, sheet_filter: Optional[set[str]] = None) -> dict:
    t_start = time.time()
    os.makedirs(os.path.join(out_dir, "sheets"), exist_ok=True)
    records: dict[str, SheetRecord] = {}
    order: list[str] = []
    file_of: dict[str, str] = {}
    volume = None
    vols = defaultdict(int)
    for f in dxf_files:
        m = re.search(r"-(P\d)-", os.path.basename(f))
        if m:
            vols[m.group(1).upper()] += 1
    if vols:
        volume = max(vols, key=vols.get)

    # ---- pass 1: read, render, nets -------------------------------------------
    from .dxf_reader import sheet_id_from_filename
    def _order(p):   # plain file first, revision copies ('138 Rev C') after it
        name = os.path.basename(p)
        return (sheet_id_from_filename(p), 1 if re.search(r"REV\s*[A-Z0-9]", name, re.I) else 0, name)

    for f in sorted(dxf_files, key=_order):
        sid = sheet_id_from_filename(f)
        if sheet_filter and sid not in sheet_filter:
            continue
        t0 = time.time()
        if sid in records:
            # two files for the same sheet number (e.g. '138.dxf' and '138 Rev C.dxf'): keep both
            m = re.search(r"REV\s*([A-Z0-9]+)", os.path.basename(f), re.I)
            alt = f"{sid}-Rev{m.group(1).upper()}" if m else f"{sid}-2"
            n = 2
            while alt in records:
                alt = f"{sid}-{n}"
                n += 1
            progress(f"  ! duplicate sheet number {sid}: {os.path.basename(f)} imported as {alt}")
            sid = alt
        data = read_sheet(f, sid)
        if sid.count("-"):
            data.warnings.append(f"second file for sheet {sid.split('-')[0]} (imported as {sid})")
        rr = render_modelspace(data.doc)
        write_svg(rr, os.path.join(out_dir, "sheets", f"{sid}.svg"))
        data.extents = (round(rr.xmin, 3), round(rr.ymin, 3), round(rr.xmax, 3), round(rr.ymax, 3))
        nets = build_nets(data)
        texts = {t.id: t for t in data.texts}
        title_up = (data.title or "").upper()
        rec = SheetRecord(data, texts, {}, nets,
                          schedule=bool(re.search(r"SCHEDULE|INDEX|CONTENTS", title_up)) and "ELCO" not in title_up,
                          typical=("TYPICAL" in title_up))
        records[sid] = rec
        order.append(sid)
        file_of[sid] = os.path.basename(f)
        data.doc = None
        progress(f"  {sid:5} {data.title[:48]:48} texts={len(data.texts):4d} nets={len(nets.nets):4d} {time.time()-t0:4.1f}s")

    # ---- PDF pages without a DXF twin become view-only sheets (text layer if any) -----
    pdf_pages_used: dict[str, int] = {}
    if pdf_path:
        for data in pdf_only_sheets(pdf_path, out_dir, records, file_of, progress, pdf_pages_used):
            sid = data.sheet_id
            rec = SheetRecord(data, {t.id: t for t in data.texts}, {}, NetResult([], [], {}, {}, {}),
                              schedule=bool(re.search(r"SCHEDULE|INDEX|CONTENTS", (data.title or "").upper())),
                              typical=("TYPICAL" in (data.title or "").upper()))
            records[sid] = rec
            order.append(sid)
            file_of[sid] = data.file

    sheet_ids = set(records)
    # ---- pass 2: identifiers & companions -------------------------------------
    for sid, rec in records.items():
        for t in rec.data.texts:
            if t.frame:
                continue
            idents = classify(t.text, sheet_ids, on_schedule=rec.schedule)
            if idents:
                rec.idents[t.id] = idents
        for t in rec.data.texts:
            if XREF_RE.match(t.text) and not t.frame:
                comps = find_companions(rec, t)
                rec.companions[t.id] = comps
                for c in comps:
                    rec.is_signal_companion.add(c)
        # drop 'signal' identifiers that are not attached to a pointer (e.g. fuse ratings '6A')
        for tid, idents in list(rec.idents.items()):
            kept = [i for i in idents if i.kind != "signal" or tid in rec.is_signal_companion]
            if kept:
                rec.idents[tid] = kept
            else:
                del rec.idents[tid]

    # ---- pass 3: links -----------------------------------------------------------
    links: list[Link] = []
    typical_sheets = [sid for sid, r in records.items() if r.typical]
    for sid, rec in records.items():
        for tid, idents in rec.idents.items():
            t = rec.texts[tid]
            for ident in idents:
                if ident.kind == "xref":
                    dst_sheet = ident.extra["sheet"]
                    links.append(resolve_xref(rec, t, records.get(dst_sheet), dst_sheet, ident.extra["grid"]))
                elif ident.kind in ("sheet_ref", "sheet_no"):
                    dst_sheet = ident.key
                    vol = ident.extra.get("volume") if ident.extra else None
                    lid = f"{sid}:{tid}:{dst_sheet}"
                    if vol and volume and vol != volume:
                        links.append(Link(lid, "sheet", "external", sid, tid, dst_sheet, note=f"drawing volume {vol} is not part of this set"))
                    elif dst_sheet in records:
                        # refine 'FROM SHT 055B' style pointers with a tag written next to them
                        links.append(Link(lid, "sheet", "sheet", sid, tid, dst_sheet))
                    else:
                        links.append(Link(lid, "sheet", "missing_sheet", sid, tid, dst_sheet, note=f"sheet {dst_sheet} is not in the imported set"))
                elif ident.kind == "loop_type":
                    code = ident.key
                    cands = []
                    for tsid in typical_sheets:
                        trec = records[tsid]
                        for ot in trec.data.texts:
                            if ot.frame:
                                continue
                            if re.search(rf"(?<![A-Z0-9]){re.escape(code)}(?![A-Z0-9])", ot.text.upper()):
                                ox, oy = _center(ot)
                                cands.append({"sheet": tsid, "text": ot.id, "label": ot.text, "x": round(ox, 2), "y": round(oy, 2), "why": "typical heading"})
                    # prefer headings (underlined / longer text / larger height)
                    cands.sort(key=lambda c: (-len(c["label"]),))
                    lid = f"{sid}:{tid}:{code}"
                    if len(cands) == 1 or (cands and len({c['sheet'] for c in cands}) == 1 and len(cands) <= 2):
                        c = cands[0]
                        links.append(Link(lid, "typical", "typical", sid, tid, c["sheet"], dst_text=c["text"], dst_point=(c["x"], c["y"]), label=code, candidates=cands))
                    elif cands:
                        links.append(Link(lid, "typical", "ambiguous", sid, tid, cands[0]["sheet"], label=code, candidates=cands[:8]))
                    else:
                        guess = None
                        for tsid in typical_sheets:
                            title = records[tsid].data.title.upper()
                            if (code.startswith(("AI", "DI")) and "INPUT" in title) or (code.startswith(("AO", "DO")) and "OUTPUT" in title):
                                guess = tsid
                        if guess:
                            links.append(Link(lid, "typical", "sheet", sid, tid, guess, label=code, note=f"typical {code} heading not found; opening the typical sheet"))
                        else:
                            links.append(Link(lid, "typical", "unresolved", sid, tid, None, label=code, note="no typical loop sheet in the set"))

    # ---- identifier index --------------------------------------------------------
    index: dict[str, list[dict]] = defaultdict(list)
    for sid, rec in records.items():
        for tid, idents in rec.idents.items():
            t = rec.texts[tid]
            for ident in idents:
                if ident.kind in ("xref", "sheet_ref", "sheet_no", "loop_type"):
                    continue
                cx, cy = _center(t)
                entry = {"sheet": sid, "text": tid, "label": t.text, "x": round(cx, 2), "y": round(cy, 2)}
                index[f"{ident.kind}:{ident.key}"].append(entry)
                if ident.kind == "tag" and ident.extra.get("base"):
                    index[f"tagbase:{ident.extra['base']}"].append(entry)

    # ---- write per-sheet files ---------------------------------------------------
    links_by_src: dict[str, list[Link]] = defaultdict(list)
    links_in: dict[str, list[dict]] = defaultdict(list)
    for L in links:
        links_by_src[L.src_sheet].append(L)
        if L.dst_sheet and L.dst_text:
            links_in[L.dst_sheet].append({"id": L.id, "from_sheet": L.src_sheet, "from_text": L.src_text, "to_text": L.dst_text, "status": L.status})
    sheets_meta = []
    search_rows: list[list] = []
    for sid in order:
        rec = records[sid]
        d = rec.data
        segs = {s.id: s for s in d.segments}
        nets_json = []
        for n in (rec.nets.nets if rec.nets else []):
            nets_json.append({"id": n.id, "bbox": n.bbox, "texts": n.texts, "shapes": n.shapes,
                              "segs": [[round(segs[i].x1, 2), round(segs[i].y1, 2), round(segs[i].x2, 2), round(segs[i].y2, 2)] for i in n.segments],
                              "handles": sorted({segs[i].handle for i in n.segments})})
        pointer_of: dict[str, str] = {}
        for xid, comps in rec.companions.items():
            if comps:
                pointer_of.setdefault(comps[0], xid)      # the label a pointer belongs to
        texts_json = []
        for t in d.texts:
            texts_json.append({"id": t.id, "text": t.text, "bbox": t.bbox, "kind": t.kind, "frame": t.frame, "handle": t.handle,
                               "h": t.height, "rot": t.rotation,
                               **({"pointer": pointer_of[t.id]} if t.id in pointer_of else {}),
                               "idents": [{"kind": i.kind, "key": i.key, **({"extra": i.extra} if i.extra else {})} for i in rec.idents.get(t.id, [])],
                               "net": rec.nets.text_net.get(t.id) if rec.nets else None,
                               "shape": rec.nets.text_shape.get(t.id) if rec.nets else None})
        out_links = []
        for L in links_by_src.get(sid, []):
            out_links.append({k: v for k, v in asdict(L).items() if v not in (None, [], "")})
        sheet_json = {
            "id": sid, "file": file_of[sid], "title": d.title, "drgno": d.drgno, "rev": d.rev,
            "extents": d.extents, "ruler": d.ruler, "warnings": d.warnings,
            "texts": texts_json, "nets": nets_json,
            "shapes": [{"id": s["id"], "bbox": s["bbox"], "texts": s["texts"], "nets": s["nets"], "handle": s["handle"]} for s in (rec.nets.shapes if rec.nets else [])],
            "links": out_links, "links_in": links_in.get(sid, []),
            "nets_skipped": bool(rec.nets and rec.nets.skipped),
        }
        _write_json_gz(os.path.join(out_dir, "sheets", f"{sid}.json.gz"), sheet_json)
        for t in texts_json:
            if not t["frame"]:
                search_rows.append([sid, t["id"], t["text"], [i["key"] for i in t["idents"]]])
        is_pdf = sid in pdf_pages_used
        sheets_meta.append({"id": sid, "file": file_of[sid], "title": d.title, "rev": d.rev, "extents": d.extents, "frame": d.frame_rect,
                            "svg": None if is_pdf else f"sheets/{sid}.svg.gz", "texts": len(d.texts), "nets": len(nets_json),
                            "links": len(out_links), "warnings": d.warnings, "source": "pdf" if is_pdf else "dxf",
                            **({"pdf_page": pdf_pages_used[sid]} if is_pdf else {})})

    # ---- optional PDF: page mapping + backdrops -------------------------------------
    pdf_info = None
    if pdf_path:
        pdf_info = attach_pdf(pdf_path, out_dir, sheets_meta, file_of, backdrops, progress)

    # ---- issues & stats -------------------------------------------------------------
    stat = defaultdict(int)
    issues = []
    for L in links:
        stat[f"{L.kind}:{L.status}"] += 1
        if L.status in ("ambiguous", "unresolved", "missing_sheet", "external", "multiple"):
            src = records[L.src_sheet]
            issues.append({"link": L.id, "sheet": L.src_sheet, "text": src.texts[L.src_text].text, "label": L.label,
                           "dst_sheet": L.dst_sheet, "status": L.status, "note": L.note,
                           "candidates": [c.get("label") for c in L.candidates][:6]})
    project = {
        "name": os.path.basename(os.path.abspath(out_dir)),
        "created": time.strftime("%Y-%m-%d %H:%M:%S"),
        "volume": volume,
        "sheets": sheets_meta,
        "stats": dict(stat),
        "counts": {"sheets": len(sheets_meta), "texts": sum(s["texts"] for s in sheets_meta), "links": len(links),
                   "identifiers": sum(len(v) for v in index.values()), "issues": len(issues)},
        "pdf": pdf_info,
        "import_seconds": round(time.time() - t_start, 1),
    }
    with open(os.path.join(out_dir, "project.json"), "w", encoding="utf-8") as fh:
        json.dump(project, fh, indent=1)
    _write_json_gz(os.path.join(out_dir, "index.json.gz"), index)
    _write_json_gz(os.path.join(out_dir, "search.json.gz"), search_rows)
    with open(os.path.join(out_dir, "issues.json"), "w", encoding="utf-8") as fh:
        json.dump(issues, fh, indent=1)
    ul = os.path.join(out_dir, "user_links.json")
    if not os.path.exists(ul):
        with open(ul, "w", encoding="utf-8") as fh:
            json.dump([], fh)
    return project


def _write_json_gz(path: str, obj) -> None:
    import gzip
    with gzip.open(path, "wt", encoding="utf-8", compresslevel=6) as fh:
        json.dump(obj, fh, separators=(",", ":"))


VIEWER_FILES = ("index.html", "app.js", "app.css")


def write_site(site_dir: str, data_dir: str) -> None:
    """Copy the viewer files next to the data folder so any static web host (GitHub Pages,
    a plain file server) can serve the viewer without Python."""
    import shutil
    viewer_src = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "viewer")
    os.makedirs(site_dir, exist_ok=True)
    for name in VIEWER_FILES:
        shutil.copyfile(os.path.join(viewer_src, name), os.path.join(site_dir, name))
    with open(os.path.join(site_dir, ".nojekyll"), "w") as fh:   # GitHub Pages: serve files as they are
        fh.write("")
    if os.path.abspath(os.path.join(site_dir, "data")) != os.path.abspath(data_dir):
        raise ValueError("the project data must be in <site>/data for the static site to find it")


def attach_pdf(pdf_path: str, out_dir: str, sheets_meta: list[dict], file_of: dict[str, str], backdrops: bool,
               progress: Callable[[str], None]) -> dict:
    from . import pdf_reader
    if not pdf_reader.available():
        progress("  ! PyMuPDF not installed - PDF ignored (pip install pymupdf)")
        return {"file": os.path.basename(pdf_path), "error": "pymupdf not installed"}
    pages = pdf_reader.read_pages(pdf_path)
    mapping = pdf_reader.map_pages_to_sheets(pages, file_of)
    by_sheet = {sid: p for p, sid in mapping.items()}
    text_pages = sum(1 for p in pages if p.words > 3)
    os.makedirs(os.path.join(out_dir, "backdrops"), exist_ok=True)
    aligned = 0
    for meta in sheets_meta:
        if meta.get("source") == "pdf":
            p = meta["pdf_page"]
            bd = pdf_reader.render_backdrop(pdf_path, p, os.path.join(out_dir, "backdrops", f"{meta['id']}.jpg"), None)
            meta["backdrop"] = asdict(bd)
            mapping[p] = meta["id"]
            continue
        p = by_sheet.get(meta["id"])
        if p is None:
            continue
        meta["pdf_page"] = p
        if backdrops:
            bd = pdf_reader.render_backdrop(pdf_path, p, os.path.join(out_dir, "backdrops", f"{meta['id']}.jpg"), tuple(meta["extents"]),
                                            dxf_frame=tuple(meta["frame"]) if meta.get("frame") else None)
            meta["backdrop"] = asdict(bd)
            aligned += bd.quality == "aligned"
    unmapped_pages = [p.page for p in pages if p.page not in mapping]
    progress(f"  PDF: {len(pages)} pages, {len(mapping)} matched to sheets, {len(unmapped_pages)} unmatched, "
             f"{text_pages} pages with a text layer, {aligned} backdrops aligned")
    return {"file": os.path.basename(pdf_path), "pages": len(pages), "matched": len(mapping),
            "unmatched_pages": unmapped_pages, "pages_with_text": text_pages, "aligned_backdrops": aligned}


def pdf_only_sheets(pdf_path: str, out_dir: str, records: dict, file_of: dict[str, str],
                    progress: Callable[[str], None], used: dict[str, int]) -> list[SheetData]:
    """Create view-only sheets for PDF pages that have no DXF file.

    When the page has a text layer its words are indexed like DXF text (same
    identifiers, same link resolution).  Without a text layer the page can be
    viewed and reached from other sheets but offers nothing to click.
    """
    from . import pdf_reader
    from .dxf_reader import TextItem, clean_text
    if not pdf_reader.available():
        return []
    pages = pdf_reader.read_pages(pdf_path)
    mapping = pdf_reader.map_pages_to_sheets(pages, file_of)
    out: list[SheetData] = []
    for p in pages:
        if p.page in mapping:
            continue
        m = re.search(r"(?<![0-9])(\d{3}[A-Z]?)(?![0-9])", p.name)
        sid = m.group(1) if m and m.group(1) not in records and m.group(1) not in used.values() else f"P{p.page:03d}"
        n = 2
        base = sid
        while sid in records or sid in used:
            sid = f"{base}-{n}"
            n += 1
        w_mm, h_mm = pdf_reader.page_size_mm(pdf_path, p.page)
        texts = []
        for w in pdf_reader.page_words_mm(pdf_path, p.page):
            t = clean_text(w["text"])
            if not t:
                continue
            b = w["bbox"]
            texts.append(TextItem(id=w["id"], text=t, kind=w["kind"], layer="pdf", x=b[0], y=b[1], bbox=b,
                                  height=round(b[3] - b[1], 3), rotation=0.0, handle="", frame=False))
        ruler_labels = [(int(t.text), (t.bbox[0] + t.bbox[2]) / 2, t.y) for t in texts
                        if re.fullmatch(r"\d{2,3}", t.text) and int(t.text) % 50 == 0 and 50 <= int(t.text) <= 400 and t.y > 0.9 * h_mm]
        from .dxf_reader import _fit_ruler
        data = SheetData(sheet_id=sid, file=f"{os.path.basename(pdf_path)}#page{p.page}", title=p.name or f"PDF page {p.page}",
                         drgno="", rev="", texts=texts, segments=[], shapes=[], circles=[], arcs=[], junctions=[],
                         frame_rect=None, ruler=_fit_ruler(ruler_labels), extents=(0.0, 0.0, w_mm, h_mm),
                         visible_layers=[], hidden_layers=[],
                         warnings=[] if texts else ["PDF page without a text layer: view only"])
        used[sid] = p.page
        out.append(data)
        progress(f"  {sid:5} {data.title[:48]:48} PDF page {p.page}: {len(texts)} words" + ("" if texts else " (no text layer)"))
    return out
