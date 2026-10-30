"""Package the built viewer site for use without any web server.

    python make_offline_zip.py <site_dir> <zip_path>

A page opened straight from a folder (file://) is not allowed to fetch() its own
data files in Chrome and Edge, but it may load <script> files.  So every data
file of the site (sheet geometry, index, search, dossier, glossary, links) is
written into the zip as ``data/<path>.js``: a one-line script that registers the
file's bytes, base64 encoded, under its path in ``window.__offline``.  The
viewer (app.js) reads those when it runs from file://.  The page backdrops
(JPEG) are plain image files and load directly.

Only the standard library is used.  The result is one folder
``schematic_viewer_offline`` inside the zip: extract it anywhere and open
``index.html`` in a current Edge, Chrome, Firefox or Safari.
"""
from __future__ import annotations

import base64
import json
import os
import sys
import zipfile

PAGE_FILES = ("index.html", "app.js", "app.css")
IMAGE_EXT = (".jpg", ".jpeg", ".png", ".webp")
README = """Schematic viewer, offline package
=================================

1. Extract the whole zip (keep the folder structure).
2. Open index.html in a current browser (Edge, Chrome, Firefox or Safari).

Nothing is installed and nothing is sent anywhere: the drawings and the index
are inside the data folder.  Manual links you create are kept in the browser's
storage for this folder; use Export links in the viewer to save them to a file.

The same folder also works when served by any web server.
"""


def build(site_dir: str, zip_path: str, folder: str = "schematic_viewer_offline") -> dict:
    site_dir = os.path.abspath(site_dir)
    data_dir = os.path.join(site_dir, "data")
    if not os.path.isdir(data_dir):
        raise SystemExit(f"{site_dir} has no data folder: build the site first (import_drawings.py --site)")
    counts = {"pages": 0, "images": 0, "scripts": 0, "bytes": 0}
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        for name in PAGE_FILES:
            src = os.path.join(site_dir, name)
            if not os.path.isfile(src):
                raise SystemExit(f"missing {src}")
            zf.write(src, f"{folder}/{name}")
            counts["pages"] += 1
        zf.writestr(f"{folder}/README.txt", README)
        for root, _dirs, files in os.walk(data_dir):
            for fn in sorted(files):
                src = os.path.join(root, fn)
                rel = os.path.relpath(src, site_dir).replace(os.sep, "/")       # data/sheets/075.svg.gz
                if fn.endswith(".js"):
                    continue                                                    # a wrapper from an earlier run
                with open(src, "rb") as fh:
                    raw = fh.read()
                counts["bytes"] += len(raw)
                if fn.lower().endswith(IMAGE_EXT):
                    zf.writestr(f"{folder}/{rel}", raw)
                    counts["images"] += 1
                    continue
                b64 = base64.b64encode(raw).decode("ascii")
                script = f'window.__offline=window.__offline||{{}};window.__offline[{json.dumps(rel)}]="{b64}";\n'
                zf.writestr(f"{folder}/{rel}.js", script)
                counts["scripts"] += 1
    counts["zip_bytes"] = os.path.getsize(zip_path)
    return counts


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__)
        return 2
    counts = build(argv[1], argv[2])
    print(f"wrote {argv[2]}: {counts['pages']} page files, {counts['scripts']} data scripts, {counts['images']} images, "
          f"{counts['bytes'] / 1e6:.1f} MB of data, zip {counts['zip_bytes'] / 1e6:.1f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
