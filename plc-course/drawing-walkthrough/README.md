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

## Cross-check of the FLD sheets against the loop drawings

Seven FLD sheets (051 to 057) and the typical loop sheets 070 and 071 were read, re-read by an independent checker,
and every field device, output and continuation reference was compared with the loop drawings, ELCO schedules and
control plate wiring. Sheet 051 survived with no connectivity errors. Confirmed inconsistencies in the package:

- **medium** (051, 088, 203, 212): 03HZS03110 (K/S B, 3F1 MID LEVEL TRIP) has no cable or terminal numbers on FLD 051; loop 088, ELCO 203 and control plate 212 all give 3/C654 terminals 11 (+) & 3 (-), F3236 rack 1107 slot 5 pin d10.
- **high** (051, 076, 052, 131): 03LZRT03110 repeat output: FLD 051 prints cable 3/C651 terminals 5 & 6; loop 076 wires it on 3/C661 cores 5/6. 3/C651 5 & 6 is already the 03ZO03003 solenoid output on FLD 052 and loop 131; 3/C661 is the repeat-output multicore for every other V TO I on sheet 051.
- **high** (051, 083, 075): Repeat output of 03QZT03581: FLD tag '03ZRT03581' vs loop tag '03QZRT03581' (each spelling occurs once in the whole package), and cores 3/C735/1-2 are allocated three times on the loop drawings (083 top-left to terminals 1/2 for 03QZRT03581, 075 bottom-right ISOCON-6-20 of 03PZT03079 to terminals 1/2 with no tag, 083 bottom-left to terminals 5/6 labelled 03LZT03122).
- **low** (051, 080): FLD 051 output tag '03FZRT0310' is a typo for 03FZRT03010 (loop 080); cable/terminals 3/C661 19 & 20 agree.
- **medium** (051, 077): Loop 077 draws a DCS repeat 03LZRT03691 (ISOCON-6-6 -> 3/C661 cores 13/14) for 03LZT03691 that appears on no FLD; FLD 051 labels that row LOOP TYPE AI2 (with repeat) but draws no V TO I, while 03QZT03581 is labelled AI1 (no repeat) yet has the ISOCON 6 -> 03ZRT03581 output.
- **medium** (051, 054, 200, 206): Annunciator windows on FLD 051 follow the original 2000 list, not the revised lists: 'W51 & 52' for 03FZA03006A (revised list: FZA 03006A = W52, but W51 = TZA 03213, which FLD 054 also uses for 03TZT03213); W05/W08 for 03TZA03052A/B (revised 3/C652 list: ES 03738 - W05, SPARE - W08; revised 3/C737 list: TZA 03052A - W58, TZA 03052B - W60).
- **high** (052, 081, 117, 200, 053): 03LZT03111 / 03LZRT03111 (FLD 052 row with 3/C650 13&14 and VCON-HL repeat 3/C661 7&8, source of continuation 3G to 053 and windows W09/W10) is SPARE on the current loop drawing 081; the tags survive only in the superseded 076 copy inside the 117 composite, and the revised ELCO list shows W09/W10 as SPARE.
- **high** (052, 088, 203, 212): 03HZS03351 keyswitch: FLD 052 pairs terminals 1 & 11 with the upper contact that feeds 03HZS03351A START and 2 & 11 with the lower contact feeding 03HZS03351B STOP; loop 088, ELCO 203 and control plate 212 all have START (A) = terminal 2 and STOP (B) = terminal 1 (11 = 1L+7 common). The FLD association rests on text placement, but it follows the same cable-above / terminals-below convention as every other row.
- **medium** (052, 083): 03LZT03122 field cable: FLD 052 '3/781' vs loop 083 '3/C731' (terminals 5 & 6 agree). '3/781' exists nowhere else in the package; 3/C731 is also used by FLD 051 and loops 075/076.
- **medium** (052, 089, 203, 212): 03QZT03164 field cable: FLD 052 '3/C659' 1 & 2 vs loop 089 '3/C654' 1 & 2. 3/C654 terminals 1 and 2 are the 03HZS03351B/A keyswitch contacts on ELCO 203 and control plate 212, so the loop sheet is the probable error.
- **medium** (052, 131): 03ZO03005 (OXYGEN SOV): FLD 052 terminals 7 & 8 on 3/C651; loop 131 right-bottom prints terminals 5 and 6, duplicating the 03ZO03003 terminals of the right-top loop on the same cable. No ELCO page exists for 3/C651 to arbitrate.
- **high** (053, 088, 089, 117, 203, 212): FLD 053 'TRANSFER 3F2 TO 3F6' inputs match only the superseded loops: 03HZS03352A (6 & 11) and 03HZS03352B (7 & 11) and 03HZS03111 (5 & 11) on 3/C654. Current loop 089 shows both its top loops SPARE (rev E 20.02.14), current 088 re-uses the 11/6 channel for 03HS03858 3B3 GAS SHUT-OFF VALVE RESET (rev E 29.01.21), and ELCO 203 reads TERM 5 SPARE, TERM 6 03HS03858, TERM 7 SPARE.
- **high** (053, 132, 117): 03ZO03111 (FLD 053 output, 3/C651 1 & 2, 50V DC): current loop 132 left-bottom is '50V DC SPARE' and its terminal text reads 19/20 (duplicating 03Z003427); the tag survives only in the superseded 132 copy on 117.
- **medium** (053, 132, 117): 03EZO03415 (FLD 053, 3/C651 17 & 18) is re-tagged 03EZO03527 on current loop 132 (rev E 24.02.14); 03EZO03415 exists only on the superseded 132 copy, and 03527 appears in no other file. The 053 DeltaV label also spells it '03EZ003415'.
- **medium** (053, 132, 052, 131, 071, 117): Supply voltage text disagrees: FLD 053 prints '50V AC' for 03EZO03414/03EZO03415/03ZO03427 while current loop 132 prints '50V DC' (the superseded 132 copy said 50V AC); typical 071 note 2 says '50Vac SUPPLY FOR SOLENOID VALVES', yet FLD 052 and loop 131 print '50V DC' for the solenoid valves 03ZO03001/03003/03005.
- **low** (132, 117): Loop 132 right-bottom (03Z003427, relay R8) prints relay wire labels R6/1, R6/2 copied from the right-top R6 loop.
- **high** (054, 081, 117, 143): 03TZT03213 and 03TZT03234B: FLD 054 cables 3/C658 1 & 2 and 3/C658 3 & 4 exist only on the superseded 081 (VCON-TC-1 for 03TZT03213 and VCON-TC-2 for 03TZT03215). Loop 081 rev K (02.10.24) wires both as type-K thermocouples on compensating cables 3T17 / 3T19 straight into P&F KFD2-UT2-2 converters (terminals 1/2 = T/C input), and '3/C658' no longer appears on 081; loop 143 rev J now prints 3/C658 1/2/S under the No.7 tag 07TZT07048.
- **high** (054, 077, 081): 03PZT03734 field cable: FLD 054 '3/C650' 19 & 20; loop 077 shows 3/C668 terminals 1 & 2 (1102/1, ISOCON-6-5 repeat 03PZRT03734 on 3/C712 1-2, which does match the FLD output row); 3/C650 19/20 belongs to 03PZT03294 on loop 081, a tag on no FLD.
- **medium** (054, 143, 144): 03PZT03236: FLD 054 'TB7AI 3 & 4' and LOOP TYPE AI4; loop 143 rev J shows terminals 1 and 2 with 'PZT 3236' in the cable position and no TB7AI, as a plain 4-20 mA input (AI1 pattern, no thermocouple converter); loop 144 numbers TB7AI 5-12 for the spare channels 1207/5-8.
- **high** (054, 138): NEW - 03XZV03853 (FLD 054 'TBDO 23 & TBC'): the 054 check was made against the superseded 10265-P3-138.dxf (rev B 06.10.11) because both 138 files dump to the same 138.txt; the current 10265-P3-138 Rev C.dxf (rev C 'AS BUILT C10265039V' 13.07.21, same project as FLD 054 rev E) replaces TBD0/23 with cable 'XZV3853-1' terminals 1 and 2. The FLD output row therefore does NOT match the current loop drawing, and the 'TBC' is answered by rev C (terminal 2 of XZV3853-1).
- **medium** (054, 133, 117): LAMP 2 (PLANT TRIP lamp, 3/C667 5 & 6): FLD 054 says LAIDLAW DREW CAB UC3229; current loop 133 says CAB UC 3228 and shows the former LAMP 1 (3/C667 1 & 2, CAB UC 3228) as SPARE; the superseded 133 copy agreed with the FLD.
- **low** (082, 117): Loop 082 (03TZT03220) is internally inconsistent: wire number 1104/5 but module table POSITION 1103; the right-hand loop reads 1104/6 with POSITION 1104, and the superseded copy printed 1104.
- **low** (054, 082, 052, 075, 070): FLD loop-type labels do not match the loop hardware: 03TZT03730 is 'LOOP TYPE AI2' on FLD 054 but loop 082 is a type-K thermocouple through VCON-TC-6 (the AI4 pattern) and prints the tag as 03TZT03730A; 03PZT03236 is 'AI4' but is a plain 4-20 mA input; 03PZT03079 is 'AI1' on FLD 052 but loop 075 has the ISOCON-6-20 repeat (AI2 pattern).
- **medium** (055B, 056A, 092, 090, 094, 086, 018): Module designation 'F6236' on FLD 055B (03HZS03576) and FLD 056A (03EZT03713, 03LZS03747, 03PZT03923) exists on no loop drawing and not in legend 018, which lists only F3236 (16-fold digital input) and F6217 (8-fold analogue input). Loops 092/090/094 print HIMA F3236; loop 086 prints HIMA F6217.
- **medium** (056A, 093, 086): FLD 056A module boxes contradict the loops: 03LZS03746 (a level switch, LOOP TYPE DI1) is drawn with ANALOG I/P F6217 while loop 093 is a HIMA F3236 digital input (3/C745 5/6 via TB3DI 13/14, 1108 slot 12); 03PZT03923 (LOOP TYPE AI2) is drawn with DIGITAL I/P F6236 while loop 086 is a HIMA F6217 analogue input (3/C745 9/10/S, 1106 slot 7).
- **high** (055B, 056A, 135, 137, 094, 131, 071): Zinc-area valve outputs on FLD 055B carry a copied output block (layer 052-TEXT) reading '3/C732 5 & 6' for both 03XZV03591 and 03XZV03742; the loop drawings put 03ZO03591 on 3/C744 cores 1/2 (135, rack 1204 slot 2) and 03Z003742 on 3/C744 cores 3/4 (137, rack 1205 slot 3), and 3/C732 cores 5/6 are the input 03LZS03700 (loop 094). The copied block also says LOOP TYPE DO2 although neither the FLD (no RELAY AMP / H4135 drawn) nor the loops (no H4135) have a relay: all 055B/056A valve outputs are direct 24 V dc F3330 channels, and the tags are written 03XZV on the FLDs but 03ZO/03Z0 on the loops.
- **medium** (055B, 056A, 092, 203, 212): Reset pushbuttons 03EZS03355 (FLD 055B and 056A) and 03EZS03355A (055B) have no loop, ELCO entry or control-plate item; the only 03355 contact in the package is 03HZS03355 ZINC DISSOLVING START-UP (loop 092, 3/C654 11/12, 1108 CH 7 d14; ELCO 203 TERM 12; control plate 212 ITEM G). One physical loop cannot be matched with certainty to two or three FLD rows.
- **low** (212, 203, 092): Control plate wiring 212 labels TERM 15 as '03HZS03576 (1108/6)' while ELCO 203 and loop 092 have 03HZS03615B on TERM 15 (1108:d12 = channel 6) and 03HZS03576 on TERM 13 (1108:d16 = channel 8); 212 also labels TERM 13 03HZS03576. The channel in brackets fits 03HZS03615B, so the tag text at TERM 15 is a slip.
- **medium** (201, 202, 115, 116, 117, 129, 130, 139, 140, 141, 142, 026A): ELCO schedules 201/202 are stale against annunciator loops 115-117 for the zinc-area signals and do not cover the 2019 windows at all: FZA 03619 - W35, TZA 03614 - W37, LZA 03609A - W39, PZA 03358 - W42 are still listed on the old layers while the loops show W35 = TZA 03610A, W37 = SPARE, W39 = TZA 03610B, W42 = SPARE; windows W73-W96 on cable 3/C755 (loops 129/130/139-142, layout 026A) appear in no ELCO file.
- **medium** (056A, 116, 141, 124, 107, 123, 115, 200, 206, 201, 202): FLD 056A window numbers: 'W 37' for 03TZA03744A HIGH is wrong (W37 is SPARE; the HIGH alarm is WINDOW 90 TZT03744H on loop 141); 'W NEW' is wrong for 03TZA03714 (existing WINDOW 56 TZA 03714, loop 124 and ELCO 206) and for 03PZA03923 (existing WINDOW 03 PZT03923, loop 107 and ELCO 200); three lamps carry no number although windows exist: 03EZA03713 = W49 (loop 123, ELCO 206), 03TZA03610A = W35 (loop 115, ELCO 201), 03TZA03610B = W39 (loop 116, ELCO 202). The seven other 'W NEW' lamps correspond to W85-W88 and W91-W93 on loops 140-142.
- **low** (056A, 116, 200): FLD 056A signal label '03FZA03747' on the 03FZT03647 row is a typo for 03FZA03647 (ELCO 'FZA 03647 - W34', loop 116 'FZA 03647').
- **medium** (093, 094, 086, 137, 077, 078, 085): Loop-drawing double allocations in the zinc area: cabinet terminals TB3DI 13/14 are used by both 03LZS03746 (loop 093) and 03LZT03747 (loop 094); cable 3/C745 cores 9/10 are used by both input 03PZT03923 (loop 086) and output 03Z003915 (loop 137); converter numbers ISOCON-6-6 and ISOCON-6-7 appear on both 077 and 085, ISOCON-6-9 on both 078 and 085; loop 094 prints the level switch as '03LZT03747'.
- **high** (057, 143, 117): 07TZT07048 field cable: FLD 057 '7/C300 3 & 4'; current loop 143 rev J prints a No.3 plant cable '3/C658' with terminals 1/2/S and a converter 'VCON-TC-9' identical to the adjacent 07TZT07044 loop; the superseded 143 copy (117 layer 141-TEXT) prints 7/C300 and VCON-TC-10 for this loop. Two thermocouples cannot share 7/C300 cores 1/2, so the FLD pairing (07044 = 1&2, 07048 = 3&4) is the consistent one and the loop text is the suspect item.
- **low** (057, 165, 145, 146, 117): Loop 165 labels both No.7 outputs 'BMS TRIP' and prints their tags with a zero ('07TZ007044', '07TZ007048'), whereas FLD 057 calls 07TZO07044 'BMS ENABLE'; loops 145/146 print three No.7 field tags with the No.3 plant prefix ('03EZ007300', '03BZS07200', '03PZS07024').
- **low** (051, 053, 055B, 056A, 002Rev): Signal names change spelling across the continuation pairs: 053 labels 3L as '03FZA03066B' (051: 03FZA03006B), 3M/3N as '03TZT03052C/D' (051: 03TZA03052C/D); 055B's arrow says 'TO SHT 056' although sheet 056 is deleted and the receiving sheet is 056A.
- **low** (099, 100, 102, 083, 079, 090, 082, 096, 133, 134, 052): Text typos on the loop/override sheets that a reader must not take literally: '03FZT0300-OVR' (099), '03FZT03008' without -OVR (100), '03LZT03110-0VR' and '03TZT03715-0VR' with a zero (102), '3C735' and 'ISCON-6' (083), '3/746' without C (079), '03EZ03713' (090), '03PZTT03696' (082), '03Z03599-RESET' (096), '03TZT03730A' (082), '03EZ003403A' / '03EZ003404A' (133/134); FLD 052 drops the 'C' in '3/650', '3/668', '3/733'.
- **medium** (002Rev, 003, 051, 052, 053, 054, 055B, 056A, 070, 071, 094, 135, 139, 026A): The supplied DXFs are not the revisions the document schedule lists: 051 H (schedule J), 052 G (H), 053 E (F), 054 E (F), 055B B (C), 056A A (B), 070 P2 (C), 071 C (D), 094 E (G), 135 C (E), 139 B (C), 026A A (B); 055A (rev A) is absent altogether. Any FLD/loop mismatch above may already be corrected in the later issue.

Still missing or unverifiable:

- Sheet 055A (FUNCTIONAL LOGIC DIAGRAM - No.3 PLANT ZINC DISSOLVING AREA, rev A) is not in the package, so 'FROM SHT 055A (03PZA03358)' on 055B cannot be closed and the 055 split (055 rev D 'DRAWING DELETED LOGIC SPLIT TO 55A & 55B') cannot be shown.
- The typical loop drawing 070 supplied is rev P2 (09.03.00, CLIENTS COMMENTS) while the schedule lists rev C, and 071 is rev C vs schedule D; the typicals show VCON-HL / VCON-TC converters whereas the as-built loops use ISOCON-6-n (AI2 repeats) and P&F KFD2-UT2-2 (2021/2024 thermocouple loops) - the current typical sheets are needed before teaching 'loop type -> hardware' as authoritative. There is also no PDF plot of 070.
- Later revisions listed in the document schedule are absent: FLDs 051 J, 052 H, 053 F, 054 F, 055B C, 056A B; loops 094 G, 135 E, 139 C; layout 026A B. Whether the confirmed FLD-vs-loop mismatches (e.g. 03LZRT03110 cable, 03HZS03351 pairing, zinc valve cables, 03TZT03213/03234B cables, 03XZV03853 terminals) were corrected in those issues cannot be verified.
- The 138 collision must be fixed in the evidence set: re-dump '10265-P3-138 Rev C.dxf' under its own key (done here to tmp138/138.txt) and re-run the 054 output check for 03XZV03853 against it; the FLD still reads 'TBDO 23 & TBC' and the 'TBC' is only answered by the loop (XZV3853-1 terminal 2).
- No ELCO/termination schedule exists for the field multicores (3/C650, 3/C651, 3/C654 field side, 3/C658, 3/C659, 3/C660, 3/C661, 3/C668, 3/C712, 3/C731-3/C733, 3/C735, 3/C744-3/C747, 3/C754, 7/C300-7/C306) nor for annunciator cable 3/C755 (windows W73-W96); field-side terminal allocation therefore rests on the loop drawings alone, and the triple use of 3/C735 cores 1/2, the 3/C651 5&6 / 7&8 question and the 3/C745 9/10 clash cannot be arbitrated from the package.
- Wire numbers are not printed on the F3236 digital-input loops (087-094, 145-146) and are missing for some F6217 channels (083 omits 1105/1; 082 prints POSITION 1103 against wire 1104/5); the walkthrough must derive them from loop note 6 ('WIRE No.s ARE DEFINED USING CARD POSITION / CHANNEL NUMBER').
- No DeltaV / Modbus register list is in the package, so the DELTA V MODBUS taps DV3_1..DV3_47 and DV7_1..DV7_3 can only be shown as 'reference to DeltaV/Modbus' (legend 018), not traced to a register or a DCS tag.
- The override keyswitch loops (sheets 095-106, rack 1110/1111, tags '<tag>-OVR') are not drawn in the FLD O/R sub-column (empty on all seven sheets) and the FLD logic does not show how an override acts; the walkthrough needs the loop sheets plus label sheet 032A to bring overrides in, and the override action itself is unverified.
- Signal polarity (de-energise-to-trip, healthy = 1) is stated nowhere; timer ON/OFF semantics (legend example 'T2 OFF 3-30 MINS' only), the flip-flop set/reset convention on 052, the circle-with-single-slash symbol of W12 on 051 and the empty rev-E cloud on 057 remain uninterpreted; HIMA module data (F3236, F6217, F3330, F3322, H4135 pinning) is not in the package.
- The physical 'module' step is incomplete: rack/position/pin (e.g. 1107:d16) were not cross-checked against the cabinet layouts 021 (swingframe) and 022 (backplate) or the label strips 031, and terminal strips TB3DI / TB7AI / TBDO / '1106SP' have no termination drawing beyond the loop sheets.
- Annunciator wiring diagrams 208/209 carry only No.4/No.7 plant window texts; No.3 plant window-to-lamp wiring is known only from loops 107-130/139-142 and layouts 026/026A, and the 2021 window renumbering (W01-W48 -> W49-W64 on 3/C737) is documented only on ELCO 206 - the FLDs 051/052/053 still carry the old numbers (W05/W08) or none ('W NEW' on 056A, unnumbered lamps).
- Unresolved identities: 03EZS03355 / 03EZS03355A vs the single loop 03HZS03355; 03Z003599 RESET (no cable/terminals on FLD 053 or loop 096); 03ZRT03581 vs 03QZRT03581; 03ZO03005 terminals (5/6 vs 7/8); whether 03HZS03351's reversed pairing is an FLD or a field error.
- Annotated pages exist only for sheet 051 (anno/S2_A_overview_051 .. S2_E_bottom_051) and legend 018 (S2_F_legend_018). For the visual walkthrough the user asked for, annotated pages are still needed for 052-057, typical 070/071, at least one input loop (e.g. 087 or 076), one output loop (131 or 133), one ELCO page (203) and the control plate 212, plus one end-to-end trace (field device -> terminals -> module position/pin -> logic -> output) drawn across those pages.
- Crops and renders used by the checks are at 5-12 px/mm; the fine text-placement calls (03HZS03351 pairing, V TO I block offsets) were settled from DXF coordinates, not from the renders, so any annotated page must quote the DXF coordinates rather than rely on visual proximity.
