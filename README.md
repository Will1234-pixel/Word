# Word

Two things live in this repository:

* **`schematic_viewer/`** – an interactive cross-reference viewer for the
  HIMA-Sella ESD cabinet drawings (C10265H/P3). Click a wire number, signal
  label, terminal or cross-reference on one sheet and it opens the destination
  sheet, zooms in and highlights the match. See
  [`schematic_viewer/README.md`](schematic_viewer/README.md) for instructions and
  [`schematic_viewer/docs/ASSESSMENT.md`](schematic_viewer/docs/ASSESSMENT.md)
  for the format assessment and accuracy figures.
* **`docs/`** – the ready-built viewer web site for the complete drawing set.
  Publish it with GitHub Pages (Settings -> Pages -> Deploy from a branch ->
  folder `/docs`); it then runs in any browser with nothing to install, at
  `https://will1234-pixel.github.io/Word/`. The GitHub Actions workflow
  *Build schematic viewer site* rebuilds this folder in the cloud when the
  drawings or the viewer code change, and publishes a downloadable copy
  (`schematic_viewer_offline.zip` on the *offline* release) that works by
  opening `index.html` from the extracted folder, with no web server.
* **`plc-course/`** – PLC programming course material and labs.
* **`Drawing_DXF.zip`** – the DXF source of the drawing set used by the viewer.
