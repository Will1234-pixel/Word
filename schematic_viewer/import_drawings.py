#!/usr/bin/env python3
"""Import a set of electrical drawings (DXF files, optionally the plotted PDF)
and build the navigation project used by the viewer.

Examples
  python import_drawings.py --dxf Drawing_DXF.zip --pdf Compined.pdf --out project
  python import_drawings.py --dxf C:\\drawings\\dxf --out project --sheets 051,052,053
"""
from __future__ import annotations

import argparse
import glob
import os
import sys
import tempfile
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from engine.index_builder import build_project  # noqa: E402


def collect_dxf(source: str, workdir: str) -> list[str]:
    if os.path.isdir(source):
        files = glob.glob(os.path.join(source, "**", "*.dxf"), recursive=True)
        files += glob.glob(os.path.join(source, "**", "*.DXF"), recursive=True)
        return sorted(set(files))
    if zipfile.is_zipfile(source):
        target = os.path.join(tempfile.mkdtemp(prefix="dxf_"), "dxf_source")
        os.makedirs(target, exist_ok=True)
        with zipfile.ZipFile(source) as zf:
            for member in zf.namelist():
                if member.lower().endswith(".dxf") and not member.endswith("/"):
                    zf.extract(member, target)
        return collect_dxf(target, workdir)
    if source.lower().endswith(".dxf"):
        return [source]
    raise SystemExit(f"--dxf must be a folder, a .zip or a .dxf file: {source}")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dxf", help="folder with DXF files, or a .zip containing them (preferred source)")
    ap.add_argument("--pdf", help="the plotted multi-page PDF: page backdrops, and view-only sheets for pages without a DXF")
    ap.add_argument("--out", default="project", help="output project folder (default: project)")
    ap.add_argument("--site", help="also write a self-contained static web site to this folder "
                                   "(the project data goes to <site>/data); host it on GitHub Pages or any web server")
    ap.add_argument("--sheets", help="comma separated sheet numbers to import (default: all)")
    ap.add_argument("--no-backdrop", action="store_true", help="do not rasterise PDF pages")
    args = ap.parse_args(argv)

    if not args.dxf and not args.pdf:
        ap.error("give --dxf and/or --pdf")
    if args.site:
        args.out = os.path.join(args.site, "data")
    os.makedirs(args.out, exist_ok=True)
    files = collect_dxf(args.dxf, args.out) if args.dxf else []
    if args.dxf and not files:
        print("no DXF files found")
        return 2
    if not files:
        print("no DXF given: importing the PDF pages as view-only sheets (text layer is indexed when present)")
    sheet_filter = {s.strip().upper() for s in args.sheets.split(",")} if args.sheets else None
    print(f"importing {len(files)} DXF files{' + PDF' if args.pdf else ''} -> {args.out}")
    project = build_project(files, args.out, progress=print, pdf_path=args.pdf, backdrops=not args.no_backdrop,
                            sheet_filter=sheet_filter)
    c = project["counts"]
    print(f"done in {project['import_seconds']}s: {c['sheets']} sheets, {c['texts']} texts, {c['identifiers']} identifiers, "
          f"{c['links']} links, {c['issues']} issues to review")
    for k, v in sorted(project["stats"].items()):
        print(f"   {k:22} {v}")
    if args.site:
        from engine.index_builder import write_site
        write_site(args.site, args.out)
        print(f"static site written to {args.site}  (open index.html through any web server, e.g. GitHub Pages)")
    print(f"start the viewer with:  python viewer_server.py --project {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
