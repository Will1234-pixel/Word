# Drawing walkthrough: HIMA-Sella ESD cabinet C10265H/P3

Teaching notes and annotated pages for the drawing package `Compined.pdf`
(134 sheets, "ICI Synetix ESD System, No.3 and No.7 Plants", HIMA H51q-HS safety PLC).
The DXF source of every sheet, including the typical input loops on sheet 070, is in `Drawing_DXF.zip` on `main`.

## Sheet map (PDF page numbers refer to Compined.pdf)

| Sheet family | Sheet numbers | PDF pages |
|---|---|---|
| Document schedules | 002 to 004 | 1 to 3 |
| Symbol legend and wire colours | 018 | 4 |
| Cabinet layouts, plates, labels | 020 to 034 | 5 to 21 |
| Power distribution 230Vac to 24Vdc | 035, 039, 040 | 22 to 24 |
| PLC communications | 041 | 25 |
| F7133 24Vdc distribution cards | 043 to 050 | 27 to 34 |
| Functional Logic Diagrams (FLD) | 051 to 057 | 35 to 41 |
| Typical loop drawing, outputs | 071 | 42 |
| Loop drawings, inputs | 075 to 098, 103 to 106, 143 to 148 | 43 to 66, 71 to 74, 112 to 117 |
| Loop drawings, outputs | 099 to 102, 107 to 142, 153 to 156, 165, 166 | 67 to 70, 75 to 111, 118 to 123 |
| ELCO connector schedules | 200 to 206 | 124 to 130 |
| Annunciator and control plate wiring | 208, 209, 212, 213 | 131 to 134 |

## Section 2: components and symbols (folder `section-02-symbols`)

All pages are from FLD sheet 051 (PDF page 35) except page F, which is the legend on sheet 018 (PDF page 4).

| Page | File | Shows |
|---|---|---|
| A | S2_A_overview_051.png | The ten columns of an FLD, title block, revision history, notes, grid ruler |
| B | S2_B_input_side_051.png | Cable and terminals, tag oval, loop type, pushbutton with item letter, annunciator window lamp, F3236 and F6217 input modules, software signal names |
| C | S2_C_logic_051.png | Timer, AND and OR gates, DeltaV tap DV3_1, continuation boxes 3A 052.225, 3P 053.140, 3L 053.140, limit label LOLO |
| D | S2_D_output_side_051.png | V to I converters (ISOCON 6), process device tags, outgoing cables such as 3/C735 1 & 2 |
| E | S2_E_bottom_051.png | Keyswitch with item letter B, HIGH and MID limit signals, OR gate, DV3_7, continuation boxes 3E and 3F 053.165, NOTES |
| F | S2_F_legend_018.png | The official legend of FLD symbols |

Key facts established so far:

- Columns, left to right: cable & terminals, field, annun/console, input (O/R, NON-I.S.), DeltaV Modbus, logic, DeltaV Modbus, output (NON-I.S., I.S.), process device tag, cable & terminals.
- The letter inside a pushbutton or keyswitch symbol is the item letter from control plate sheet 028: B = 2-position stay-put keyswitch, C = green shielded momentary pushbutton, F = red shielded maintained pushbutton.
- Loop type (AI1, AI2, DI1 ...) points to the typical wiring on sheet 070 (inputs) and 071 (outputs).
- A continuation box such as `3A 052.225` means: signal 3A continues on sheet 052 at grid position 225 mm on the top ruler.
- `DV3_n` with a solid dot is a logic point sent to DeltaV over Modbus for No.3 plant; sheet 057 uses `DV7_n`.
- `V TO I` boxes in the output column are hardware repeaters (1-5 V in, 4-20 mA out) sending the field measurement to DeltaV; they are not PLC logic outputs.

## Interactive explorer (folder `explorer`)

Open `explorer/index.html` in any browser. It shows FLD sheet 051 and loop drawing 075 with clickable
hotspots, a plain-language card for every element, an eleven-step trace of the nitric acid low flow signal
from the transmitter to the sheet output, a glossary and five self-check questions.
