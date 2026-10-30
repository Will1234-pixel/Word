# Schematic Cross-Reference Viewer

Follow wires, signals, terminals and cross-references across a multi-page
electrical drawing set. Click a reference on one page and the viewer opens the
destination page, zooms to the matching location and flashes it. A **Back**
button returns you to where you came from.

Built and tested on the HIMA-Sella ESD cabinet drawing set
`C10265H/P3` (135 DXF sheets, 134-page PDF). Everything runs locally on a
Windows PC; nothing is sent anywhere and the original drawings are never
modified (they are only read).

---

## 0. Nothing to install: use it in the cloud

The viewer is a plain web page. The complete drawing set has already been
imported and the result is committed in the repository folder **`docs/`**, so
GitHub can publish it for you:

1. On GitHub open the repository, then **Settings -> Pages**.
2. Under *Build and deployment* choose **Source: Deploy from a branch**,
   pick the branch that contains the `docs` folder (`main` after merging, or
   `claude/beautiful-ptolemy-w0y5j5` before) and the folder **`/docs`**, then **Save**.
3. After about a minute the page shows the address, normally
   `https://will1234-pixel.github.io/Word/`. Open it in Edge, Chrome, Firefox or
   Safari. Bookmark it; it works on any computer, tablet or phone.

Differences from running it locally:

* Manual links, confirmations and rejections are stored in the browser you use.
  **Help -> Export manual links** saves them as a file; **Import** loads such a
  file on another computer. Committing an exported file as
  `docs/data/user_links.json` makes those decisions part of the published site.
* To rebuild the site after the drawings change, GitHub can run the importer
  for you: **Actions -> "Build schematic viewer site" -> Run workflow**
  (it also runs automatically when `Drawing_DXF.zip` or the viewer code changes).
  The rebuilt `docs/` folder is committed and published automatically.
  Nothing needs to be installed on your PC for this.
* The same `docs/` folder can be copied to any other web server or intranet
  site; it has no server-side code.

Everything below is only needed if you prefer to run it on your own PC.

## 1. One-time setup (Windows)

1. Install **Python 3.10 or newer** from <https://www.python.org/downloads/windows/>.
   In the installer tick **"Add python.exe to PATH"**.
2. Copy the folder `schematic_viewer` somewhere convenient, e.g. `C:\SchematicViewer`.
3. Double-click **`setup_windows.bat`**. It installs the two libraries the
   importer needs (`ezdxf` reads DXF files, `PyMuPDF` reads the PDF).
   This is the only step that needs an internet connection.

## 2. Import a drawing set (once per set, 1-3 minutes)

The importer needs to know where the drawings are, so run it from a command
prompt (Start -> type `cmd`):

```bat
cd C:\SchematicViewer
import_drawings.bat "C:\drawings\Drawing_DXF.zip" "C:\drawings\Compined.pdf"
```

* First argument: the folder (or `.zip`) containing the **DXF** files.
* Second argument (optional): the plotted multi-page **PDF**. It is used as an
  optional "original page" backdrop, and any PDF page that has no DXF file is
  imported as a view-only sheet. Leave it out if you do not have it.
* PDF only (no DXF at all): `python import_drawings.py --pdf drawings.pdf --out project`.
  This is navigable only if the PDF has a real text layer; the supplied
  `Compined.pdf` has none, so on its own it gives 134 pages to look at and
  nothing to click.

The importer prints one line per sheet and finishes with a summary such as

```
done in 150s: 135 sheets, 33000 texts, 7000 identifiers, 1200 links, 90 issues to review
```

Everything it produces goes into the folder `project` next to the scripts.
Re-running the import overwrites `project` but keeps your manual corrections
(`project\user_links.json`).

## 3. Start the viewer

Double-click **`run_viewer.bat`**. A black window opens (leave it open; closing
it stops the viewer) and your web browser shows the first sheet. If the browser
does not open by itself, go to <http://127.0.0.1:8765/>.

---

## 4. Using the viewer

| Action | How |
|---|---|
| Open a sheet | *Sheet* drop-down, the ‹ › buttons, or the **Sheets** tab |
| Zoom / pan | mouse wheel zooms at the cursor, drag pans, double-click zooms in, **F** fits the page |
| Follow a cross-reference | click the reference text (e.g. `052.225`), the signal label (`3A`), a tag, cable number, ELCO pin or terminal. The destination page opens, zooms in and the match flashes for about three seconds |
| Several possible destinations | a list pops up next to the cursor – choose one |
| Follow a wire | click on the wire line: the whole conductor on that page is highlighted and the panel lists where it goes. If there is exactly one cross-reference on it, the viewer jumps there |
| Go back | **◀ Back** button, or the Backspace key. **Fwd ▶** goes forward again |
| Search | type a wire number, tag, cable or terminal in the search box and press Enter. Results are grouped by sheet; click one to go there |
| Where else does this appear? | select a text and press **Other appearances** (or click a text that has no explicit pointer) |
| Original PDF look | *View* -> `PDF page` or `overlay` (only when the PDF was imported) |
| Highlight colour / flashing | *Colour* drop-down (green / yellow / red) and the *flash* tick box |
| Trail | the **Trail** tab lists every place you visited – click to jump back |
| Review doubtful references | the **Issues** tab lists every reference the import could not resolve with certainty |

### Understanding what the drawing does

The viewer explains the drawings in words, using only what is drawn:

* **What this is.** Click any label: a short note appears next to the cursor and a
  block at the top of the Selection panel. For a tag it gives the service caption,
  loop type, cable and terminals, the module that reads it and the logic it takes
  part in; for a wire the potential it carries, the fuse it comes from and the
  devices it touches; for other words the meaning from the drawing glossary.
  "Written on" rows list every other sheet the same identifier appears on.
* **Explain sheet** (toolbar button, or **E**): a summary of the sheet and, on the
  functional logic diagrams, one row per output signal with its cause-to-effect
  logic, for example `3B -> 052  AND(OR(3A (from 052), ...), 03FZA03012, ...)`.
  Click a row to light up every wire, gate, module and field tag involved and to
  see the logic as an indented outline; click an outline line to highlight that
  input. Incoming signals show where they arrive from and what they feed.
* **Follow to sheet**: walks a signal to the next sheet and lands on its logic
  there, hop by hop, with each hop recorded in the Trail.
* **Dossier and glossary**: `project/dossier.json.gz` holds, for every tag, cable,
  terminal, ELCO pin and signal, its role and captions on each sheet;
  `glossary.json` holds 158 terms (potentials, module types, ISA tag letters,
  connectors) with the sheet or convention each meaning comes from. Edit
  `schematic_viewer/engine/glossary.json` to add site vocabulary.

Everything written comes from text and geometry on the drawings. Where the
drawing is silent the note says so ("no signal name written", "unlabelled
wire"); nothing about plant behaviour is inferred.

### What the status badges mean

| Badge | Meaning |
|---|---|
| **verified** | explicit pointer (`sheet.grid`): the label was found on the destination sheet **and** the destination carries a pointer back to the source sheet |
| **matched** | the label was found at the destination, but there is no pointer back |
| **back pointer** | the destination points back to the source sheet near the given grid position, but the label is written differently (e.g. `XG.21:2` on one sheet, `XG.21` on the other) |
| **multiple** | several verified destinations exist (e.g. signal `3P` arrives in two boxes on sheet 053) – you choose |
| **ambiguous** | several equally plausible targets – you choose |
| **unresolved** | the pointer could not be matched; the viewer shows the grid position only |
| **same label** | the same identifier is written elsewhere. This is **not** a verified electrical connection – a repeated tag or cable number may be a different core or circuit |
| **typical** / **sheet** | pointer to a typical loop drawing (`LOOP TYPE AI2`) or to a whole sheet (`SEE DRG 025`) |
| **missing sheet** / **external** | the referenced sheet is not in the imported set, or belongs to another drawing volume |

The viewer never invents connections: only explicit pointers written on the
drawings become links. Repeated labels are shown as *appearances* for you to
judge, and uncertain cases are listed in **Issues**.

### Correcting the automatic result

* Select a text and press **Confirm** or **Reject** under a destination.
  Rejected links are struck through and no longer used for automatic jumps.
* To add a link the importer missed: select the source text, press **+ Link**,
  then click the destination text (you may change sheets first).
  A note can be added. Manual links show the badge **manual**.
* All decisions are stored in `project\user_links.json` (local server) or in
  the browser (web page, see section 0); they survive re-imports.

---

## 5. How it works (for the curious)

* **DXF first.** Text, coordinates, layers, blocks and attributes are read with
  `ezdxf`. Only layers that are ON and THAWED are used, because several files
  in this set hold up to ten sheets stacked on frozen layers.
* **No OCR.** The supplied PDF was plotted with all text converted to outlines
  (zero extractable characters on 133 of 134 pages), so the PDF is used only as
  an aligned visual backdrop. PDFs that *do* have a text layer are indexed by
  the same pipeline (one sheet per page) but cannot offer wire tracing.
* **Rendering.** Each sheet is rendered to SVG in drawing millimetres, text as
  glyph outlines, so highlight boxes computed from DXF coordinates land exactly
  on the drawing.
* **Identifiers** are recognised by rules derived from the drawings: explicit
  pointers `052.225`, textual pointers (`SEE DRG`, `TO SHT 056`), `LOOP TYPE`,
  cables `3/C650`, tags `03FZT03002` / `FZA 03002`, ELCO pins `1109/1`,
  `1109:d10`, terminals `1L+1`, `XG.21:2`, potentials `1L-`, DeltaV points
  `DV3_1`, annunciator windows, module types and terminal blocks.
* **Resolution.** For each explicit pointer the companion label (the text in the
  same box, row or column) is searched on the destination sheet; the grid
  number is only used to rank candidates because the drafters' grid values are
  approximate (often 10-25 mm off). A pointer back to the source sheet upgrades
  the result to *verified*.
* **Explanations.** `engine/explain.py` classifies closed symbols (gate, timer,
  module, converter, tag oval, continuation box, device), records which side of
  a symbol each wire enters, and resolves every output back through gates,
  timers and modules to the field tags and incoming signals; it also words each
  conductor and summarises the sheet. `engine/dossier.py` groups multi-line
  captions, assigns each identifier a role per sheet and builds the cross-sheet
  dossier and glossary lookups.
* **Wires.** Conductors are grouped by geometry: segments are joined at
  corners and at junction dots. A wire ending on the middle of another line
  without a dot is not a branch (that is how terminal strips are drawn), crossing
  lines are not joined, dashed line-work never conducts, and closed outlines
  (symbols, boxes) stop the net and are recorded as the symbols the wire reaches.
  Hovering a wire previews the conductor in blue; clicking highlights it in the
  chosen colour.

## 6. Files

```
schematic_viewer/
  setup_windows.bat      one-time installation of ezdxf + PyMuPDF
  import_drawings.bat    build the project from DXF (+PDF)
  run_viewer.bat         start the local viewer
  import_drawings.py     command-line importer (python import_drawings.py --help)
                         --site <folder> writes a complete static web site (used for docs/)
  viewer_server.py       local web server (standard library only)
  engine/                DXF reader, renderer, identifier rules, resolver, nets,
                         explain.py (logic trees, conductor notes, sheet summaries),
                         dossier.py + glossary.json (cross-sheet dossier, vocabulary)
  viewer/                the browser user interface (no internet needed)
  tests/                 automated tests against the supplied drawings
  project/               created by the importer: sheets/*.svg.gz, sheets/*.json.gz,
                         index.json.gz, search.json.gz, issues.json, backdrops/*.jpg,
                         user_links.json
  ../docs/               the published web site: viewer page + data/ (the imported set)
  ../.github/workflows/  GitHub Actions job that rebuilds docs/ in the cloud
```

See `docs/ASSESSMENT.md` for the format assessment, the architecture and the
accuracy figures measured on the complete drawing set, and `docs/screenshots/`
for the worked example.

## 7. Known limitations

* Sheets drawn in another CAD system without a mm ruler (040-050) use a
  default grid mapping; label matching still works, grid distances are rough.
* Cabinet layout sheets (020-034) are shown but have no wire tracing (they are
  mechanical drawings).
* Loop drawings and ELCO schedules connect through repeated identifiers only;
  these appear as *same label* and must be judged by the engineer.
* A PDF without a text layer (like the supplied one) cannot be navigated on its
  own; it needs the DXF files.
