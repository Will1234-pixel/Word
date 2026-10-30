# Assessment, architecture and accuracy report

Drawing set: HIMA-Sella ESD cabinet **C10265H/P3** (ICI Synetix No.3 and No.7 plants).
Inputs inspected: `Drawing_DXF.zip` (135 DXF files, 72 MB) and `Compined.pdf` (134 pages, 21.6 MB,
plotted by DWG TrueView 2026).

## 1. Can the cross-references be extracted reliably? PDF, DXF or both?

**Verdict: DXF is the only usable source for text and connections; the PDF is useful only as a picture.**

| Question | PDF | DXF |
|---|---|---|
| Machine-readable text | **No.** 133 of 134 pages contain a single word (the "HIMA-SELLA" stamp). Every label was plotted as vector outlines. Reading it would need OCR, which the brief rightly wants to avoid. | **Yes.** Every label is a `TEXT`/`MTEXT`/`ATTRIB` entity with exact insertion point, height, rotation and style. 30 001 visible text items on the set. |
| Coordinates | Vector paths only, no text positions. | Millimetre coordinates on a fixed A3 frame with a 0-400 mm grid ruler on most sheets. |
| Sheet identity | Page labels carry the DXF file name (`[35] 10265-P3-051-Model`), which maps every page to its DXF file. | Title-block attributes `DRGNO`, `TITLE_1`, `REV.` (A3 frames) or plain text in the HS-A3 frames; file name is reliable for all 135 files. |
| Layers / blocks / attributes | None. | Layers encode sheet membership (`051`, `051-TEXT`) and, on the power sheets, wire colour and size (`PCABRED-TR-2_5`). Blocks are title frames, terminals, dots, logic symbols; attributes hold title-block data and, on three sheets, EQUPOT cross-reference fields. **No CAD-level netlist or wire-id metadata exists** - the drawings were produced as plain AutoCAD geometry, so connectivity must be derived from text and geometry. |
| Hidden content | Not applicable. | Several files hold up to **ten sheets stacked on frozen layers** (200-series, 035/039, 117). Reading frozen layers would create thousands of ghost labels; the importer uses only ON + THAWED layers, which matches the plotted pages exactly. |

Both files together give the best result: DXF for everything navigable, the PDF as an
aligned "original page" backdrop (all 134 pages align to the DXF geometry with a
0.0 % scale residual, using the drawing frame lines as the reference).

### Reference conventions found in the drawings

* **Explicit pointers** `SSS.GGG` = sheet number . grid position in mm, always written next to
  a companion label: the signal label in a continuation box on the FLD sheets (`3A 052.225`),
  the terminal / potential name above or below on the power sheets (`040.048` over `XG.21:2`,
  `035.320` over `1L-`). The grid value is approximate: measured offsets of 10-25 mm are common,
  so it is used only to rank candidates, never to decide.
* **Textual pointers**: `SEE DRG C10265H/P3/023`, `REF DRG 025`, `TO SHT 056`, `FROM SHT 055B`,
  `FOR TYPICAL LOOP TYPES SEE DRGS C10265H/070 & 071`, `SEE DWG C10265H/P4-026` (other volume).
* **Loop type pointers** `LOOP TYPE AI2` -> heading on typical sheets 070 (inputs) / 071 (outputs).
* **Repeated identifiers** (no explicit pointer): tags `03FZT03002`, cables `3/C650`, ELCO pins
  `1109/1` and `1109:d10`, terminals `1L+1`, `XG.21:2`, potentials `1L-`, DeltaV points `DV3_1`,
  annunciator windows `W12`, module types, terminal blocks. These connect FLDs, loop drawings,
  ELCO schedules and annunciator wiring, but a repeated label is **not proof of a connection**
  (a cable number covers many cores; `1L-` is a whole rail). The viewer lists them as
  *appearances* and never upgrades them to links.

## 2. Architecture

```
DXF files ──ezdxf──> dxf_reader   visible text + exact font boxes, title block, ruler, geometry
                     svg_render   per-sheet SVG in drawing mm (text as outlines), gzip
                     nets         conductors from geometry (end points, T-junctions, dots; crossings not joined)
                     identifiers  rule-based classification of every text
                     index_builder companions -> candidates -> status; identifier index; issues report
PDF ─────PyMuPDF──> pdf_reader   page<->sheet mapping by page label, aligned PNG backdrops,
                                  text layer (when a PDF has one) as view-only sheets
project/  ───────>  viewer_server (Python standard library)  <─HTTP─>  viewer/ (HTML + JavaScript)
```

* Import is a one-off batch (about 2 minutes for 135 sheets + PDF on this machine); the viewer
  then loads one sheet at a time, so 50, 135 or 500 sheets behave the same.
* Highlights are drawn from the same millimetre coordinates as the SVG, so a highlight box
  sits exactly on the text it belongs to.
* Manual corrections live in `project/user_links.json`, separate from generated data.
* The original DXF/PDF files are opened read-only and never changed.

## 3. Accuracy on the complete set

Import of all 135 sheets (135 DXF files; `138` and `138 Rev C` are both kept) with the PDF:

| Measure | Value |
|---|---|
| Visible text items indexed | 30001 |
| Distinct identifiers | 4743 |
| PDF pages matched to sheets / aligned | 134 / 134 of 134 |
| Explicit `sheet.grid` pointers | 62 |
| &nbsp;&nbsp; verified (label found + pointer back) | 22 |
| &nbsp;&nbsp; back pointer (destination points back, label written differently) | 24 |
| &nbsp;&nbsp; matched (label found, no pointer back) | 4 |
| &nbsp;&nbsp; multiple verified destinations (engineer chooses) | 1 |
| &nbsp;&nbsp; ambiguous (engineer chooses) | 11 |
| &nbsp;&nbsp; unresolved | 0 |
| &nbsp;&nbsp; destination sheet not in the set | 0 |
| `LOOP TYPE` pointers resolved to a typical heading | 106 of 106 |
| Whole-sheet pointers (SEE DRG, schedule entries) | 155 (+2 to sheets not in the set, 1 to volume P4) |
| References listed for review in the viewer | 15 |

Every explicit pointer on the Functional Logic Diagrams 051-053 was checked by hand against the
drawings: all resolve to the correct continuation box on the destination sheet; signal `3P` on 051
genuinely arrives in two boxes on 053 and is reported as *multiple*. The automated test suite
(`tests/`, 28 tests) re-checks these cases on every change.

### Identifiers found (distinct keys)

| Kind | Distinct | Appearing on 2 or more sheets |
|---|---|---|
| ELCO connector pin (1109/1, 1109:d10) | 434 | 28 |
| instrument / device tag | 293 | 139 |
| tag without plant prefix (FZA 03002) | 198 | 124 |
| terminal (1L+1, XG.21:2, K9202/1) | 92 | 60 |
| annunciator window | 65 | 55 |
| cable (3/C650) | 45 | 39 |
| ELCO connector / card number | 34 | 32 |
| DeltaV point (DV3_n) | 34 | 0 |
| supply potential (1L-, BL+) | 30 | 14 |
| safeclip link / fuse | 20 | 20 |
| I/O module type | 12 | 9 |
| FLD continuation signal (3A) | 11 | 11 |
| terminal block (TB3AI) | 6 | 4 |

### References the engineer must judge (15)

| Sheet | Pointer | Companion label | To | Status | Note / candidates |
|---|---|---|---|---|---|
| 026A | `SEE DWG C10265H/P4-026` |  | 026 | external | drawing volume P4 is not part of this set |
| 035 | `040.133` | XG.23:2 | 040 | ambiguous | candidates: XG.23, XG.23 |
| 035 | `040.048` | XG.21:2 | 040 | ambiguous | candidates: XG.21, XG.21 |
| 035 | `040.090` | XG.22:2 | 040 | ambiguous | candidates: XG.22, XG.22 |
| 035 | `043.060` | 1118-1121 | 043 | ambiguous | candidates: 1119, 1120, 1121, 035.320, 035.320 |
| 035 | `047.060` | 1218-1221 | 047 | ambiguous | candidates: 1219, 1220, 1221, 035.335, 035.335 |
| 035 | `040.053` | XG.21:1 | 040 | ambiguous | candidates: XG.21, XG.21 |
| 035 | `040.095` | XG.22:1 | 040 | ambiguous | candidates: XG.22, XG.22 |
| 035 | `040.138` | XG.23:1 | 040 | ambiguous | candidates: XG.23, XG.23 |
| 039 | `035.145` | AL-/BL- | 035 | ambiguous | candidates: BL-, AL-, AL-, BL-, BL- |
| 039 | `035.120` | AL+/BL+ | 035 | ambiguous | candidates: BL+, AL+, AL+, BL+ |
| 050 | `098.070` | 1109:d30 | 098 | ambiguous | candidates: 1109, 1109, 1109, 1109 |
| 051 | `053.140` | 3P | 053 | multiple | candidates: 3P, 3P, 051.255, 051.255, 051.255, 051.255 |
| 055B | `FROM SHT 055A (03PZA03358)` |  | 055A | missing_sheet | sheet 055A is not in the imported set |
| 055B | `TO SHT 056` |  | 056 | missing_sheet | sheet 056 is not in the imported set |

Most of these are the 24 V feeds on sheet 035: the destination sheet 040 names its terminals
`XG.21` without the pin number, so each pointer offers the two `XG.21` terminals to choose from.

## 3b. Explaining function, not just position

Beyond navigation the tool now words what the drawings show. All of it is
derived from geometry and text; nothing is inferred about plant behaviour.

* Functional logic diagrams: every continuation signal, converter output,
  DeltaV tap and annunciator window gets a cause-to-effect tree. On sheet 051
  the engine finds 40 such entries, e.g. `3B -> 052 = AND(OR(3A from 052, P/B
  03HZS03350), OR(AND(T1 OFF 2 mins(...), 03HZS03354), AND(03HZS03354,
  03FZA03002, 03FZA03004, ...)), 03FZA03012, 03PDZA03078, HIGH 03TZA03052A,
  OR(03EZS03412, 03EZS03413), HIGH 03LZA03110A, OR(MID 03LZA03110C,
  03HZA03559))` with tap DV3_5. Each leaf carries the field tag, its service
  caption, loop type, cable, terminals and input module.
* Conductors: potential, fuse of origin and rating, devices touched, pointers
  leaving the sheet, sheet context (card number).
* Loop drawings: channel tables (position, channel, channel pins, supply pins,
  wire number, supply wires, plug) read from the drawn tables. A signal
  converter drawn with numbered pins (ISOCON, VCON, P & F) is described from
  its own captions: "takes 1-5V in at pins 4, 5; gives 4-20mA out at pins 12,
  10 to cable 3/C735 terminals 1, 2; supply 24Vdc at pins 1, 2", one line per
  pin with the wire's labels and destination, and the channel it serves.
* Dossier: 1262 identifiers across the set with their role on every sheet
  (FLD field device, loop drawing channel, ELCO schedule row, annunciator
  window, power feed, card output wire ...) and the captions around them.
* Glossary: 158 terms; each entry names its evidence (a sheet, "ISA 5.1
  convention" or "standard abbreviation").

Verified by hand against the plotted pages for sheets 051, 052, 053, 035,
043, 045, 075, 099 and 200 (details in the test suite, 150+ tests), and by an
independent adversarial review whose findings are listed in section 6.

## 4. What the PDF alone can do

`python import_drawings.py --pdf Compined.pdf --out project_pdf` imports the 134 pages as
view-only sheets: the result has **0 identifiers and 0 links** because the PDF has no text
layer. A PDF that does carry a text layer (tested with a synthetic two-page file) is indexed
through the same rules and produces verified pointer links, but offers no wire tracing.

## 5. Features that cannot be completed reliably

* **Navigation from a PDF without a text layer** (the supplied one). Only OCR could change this,
  and the brief asks to avoid it; it would also mis-read rotated and tiny text on these sheets.
* **Verified connections through repeated labels.** Tags, cables, ELCO pins and terminals
  connect sheets only by name. The tool shows all appearances with a clear "same label - not
  verified" marking; it does not and should not assert a connection.
* **Exact grid landing.** The drafters' grid numbers are approximate (10-25 mm off). The viewer
  therefore lands on the matched label, and on the bare grid position only when nothing matches
  (status *unresolved*; none remain on this set after the latest import, 4 occurred on the
  subset before the relaxed terminal matching was added).
* **Wire tracing on layout sheets** (020-034, mechanical cabinet drawings) is switched off; on
  schematic sheets nets stop at symbol outlines, which is intended (a fuse or relay is a
  device, not a wire), so tracing *through* a device is left to the engineer.
* **ELCO schedules and loop drawings** are tables; their "wires" are short and mostly
  meaningless, so navigation there relies on identifiers and search.

## 6. Adversarial verification of the explanations

Sixteen independent reviews (two per sheet: logic and signal flow; conductors,
devices and identifiers) were run against the rendered pages of sheets 051,
052, 053, 035, 045, 075, 099 and 040 with the instruction to refute every
generated statement. Each finding quotes the generated text and the drawing
evidence. Root causes found and fixed:

| Finding | Sheets | Fix |
|---|---|---|
| Signal names on module output wires were given to the nearest wire, not to the wire whose label flag (tick) points at them: 3D, 3M, 3N and window W08 carried the wrong 03TZA03052x name | 051 | a wire whose free end stops in line with a one-word label owns it (also fixes 1L-1 / 1L+1 and 1L-6 / 1L+6 on 075 and 085) |
| Tags typed with zeros for the letter O (03Z003578, 03Z003599, 03EZ003415) were not recognised, so the fifth output of 052 and the MIXED ACID SOV block of 053 were missing | 052, 053 | tag-shaped texts with zeros are treated as tags (the text is kept exactly as drawn) |
| Loop-drawing converters were described as a logic gate with ten unlabelled inputs and a label soup | 075 to 086, 070, 143 | pin captions, pins, polarity words and the wires at each pin are read (section 3b) |
| Stacked captions at a wire end were cut to their last line: "XG.3" for "L+ FROM XG.3", "XG.11" for "(1L-) 043.280 XG.11", nothing for "PANEL EARTH" | 043 to 050 | lines stacked over an attached label belong to the same wire |
| A keyswitch with two contacts was reported with one module and one signal | 052, 053 | every contact wire of a console device is followed |
| "loops back to shape 28" in feedback logic; a wire feeding two AND gates listed one; field origins truncated silently | 052, 053, 051 | "feedback from 03ZO03111", "AND gate (x2)", "and 4 more" |
| Lamp crosses and converter diagonals listed as unlabelled wires; "CONTROL ROOM", "P/B", "K/S" reported as wire labels | 051, 075 | strokes inside a symbol are not conductors; device captions are not labels |
| "0 process device outputs" beside a PROCESS DEVICE TAG column of seven; "W51 & 52" counted once; "4 fuses or links" for four fuses | 051, 045 | wording and counts follow the drawing's own terms |
| Glossary: XG.3 called panel earth (it is "L+ FROM XG.3", the supply of the fuse evaluation logic); Q read as density (pH on 052); dossier roles "card output" for the terminals where the feed enters | 043 to 050, 052 | entries corrected, roles split into supply terminal and output wire |

Confirmed correct by the reviewers: the 3B, 3P, 3A and 03ZO0300x logic trees,
the incoming signals and their pointers, the loop channel tables of 075, the
fuse supply sides and ratings of 035 and 045, the converter outputs of 051.

Still open, reported but not changed:

* Card sheets 043 to 050: the fuse evaluation logic block and the backplane
  z2-pin feed of each fused output are not explained; the explanation stops at
  the labelled destinations.
* Loop drawings: the wire from the field terminal and the module pin stub are
  separated by the I/O plug symbol, so "1101/1 lands on z4" is not stated.
* Cross-document conflicts are not flagged automatically (3L is written
  03FZA03066B on 053 and 03FZA03006B on 051; the ELCO schedule lists W09 and
  W10 as spare while the FLD drives them; 03FZRT0310 is a probable typo for
  03FZRT03010).
* A signal consumed twice on one sheet (3P on 053) shows as "link multiple".
* Dossier wording for tag letters comes from the glossary and can mislabel a
  device type (a pH switch described through the Q letter).
