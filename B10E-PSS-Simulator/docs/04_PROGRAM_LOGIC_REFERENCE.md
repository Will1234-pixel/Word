# 4 · Program logic reference (the exact PLC code)

*This is the authoritative map of `program.pdf` (713 pages, HIMA SILworX export,
SILworX v16, project `C15862H-BL10E`, configuration `BL10E_HeXI [400]`,
target **HIMax**, SIL 2). The searchable text is in
`data/program_extracted.txt` (page markers `===== PAGE n =====`).*

Convention in SILworX FBD text: `&` = AND, `>=1` = OR, `NOT`/a bubble = invert.
**All effects are de-energise-to-trip:** an output `FALSE` = tripped/safe; a SIF
`..._OUTPUT`/`..._TRIP` signal `TRUE` usually means **healthy/permissive**.

---

## 4.1 Page index (where everything lives)

| Pages | Area |
|---|---|
| 1–13 | Cover + Table of Contents |
| 14–16 | Project structure (POU tree, lists all SIFs) |
| 37–126 | **Global Variables & cross-references** (the master tag list + initial values, setpoints, timer presets) |
| 127–149 | **Hardware** (HIMax I/O module config) |
| 151–285 | `C15862H_Lib` — custom application logic (see 4.4) |
| **286–382** | **The 12 SIFs** (core safety logic) |
| 383–690 | `X_Lib` — HIMA standard blocks (voters, timers, limits) |
| 691–710 | Modbus TCP / OPC-UA / safeethernet |
| 711–713 | Watchpages (Global Forcing) |

## 4.2 The 12 SIFs (page → logic)

| SIF | Pages | Logic pg | Title |
|---|---|---|---|
| SIF-01 | 287–291 | 291 | General Access Door Closed |
| SIF-02 | 292–297 | 297 | Service Access Door Closed |
| SIF-03 | 298–303 | 303 | Current & Voltage Monitoring |
| **SIF-04** | 304–338 | **326–338** | **Search Sequence (SFC)** |
| SIF-05 | 339–344 | 344 | Search Start |
| SIF-06 | 345–350 | 350 | Search Complete |
| SIF-07 | 351–356 | 356 | Beam On (permissive) / lock feedback |
| SIF-08 | 357–363 | 363 | Beam Off Buttons |
| SIF-09 | 364–368 | 368 | Radiation Monitoring |
| SIF-10 | 369–372 | 372 | Electron Source Enable |
| SIF-11 | 373–377 | 377 | Oxygen Monitoring |
| SIF-13 | 378–382 | 382 | General Access Gate Closed |

*(No SIF-12 in the PLC — the C&E "SIF 11 & 12" both refer to the oxygen function.)*

## 4.3 Per-SIF logic (plain English)

* **SIF-01 (p.291)** — `GADC-01/02/03` voted **2oo3** (`X_2oo3_B`), AND'd with
  `SIF-07_OUTPUT` (beam-on conditions). Output `SIF-01_TRIP` → contactors
  CON-01/02/03 via the central `Logic` POU.
* **SIF-02 (p.297)** — `SADC-01/02/03` 2oo3 **OR** `SADC-04/05` (1oo2 pair),
  AND'd with `SIF-07_OUTPUT`. Outputs `SIF-02_TRIP`, `SERVICE_DOOR_CLOSED`.
* **SIF-03 (p.303)** — "is the beam actually off?" + door-unlock permit.
  Current `IT-01/02/03` 2oo3 and Voltage `VT-01/02/03` 2oo3. An **RS** latch + a
  **TON** `DOOR_UNLOCK_DELAY = T#20s` + `R_TRIG` on Open/Reset pushbutton
  `OR-01` and key `KEY-01`: the Open/Reset button only becomes live once both
  2oo3 votes read zero for **≥20 s**, then `OR-01:LED` lights. (The C&E footnote
  mentions 12 s from the SRS; the **implemented** value is 20 s.)
* **SIF-04 (pp.326–338)** — the **SFC** (see 4.5).
* **SIF-05 (p.344)** — Search-start permit (**T1**): `SCR-01` card AND `KEY-01`
  AND `KEY-02` AND service-door 2oo3 AND 1oo2 pair AND `SIF-08` healthy →
  `SIF-05_START`.
* **SIF-06 (p.350)** — Search-complete: general door 2oo3 AND gate 2oo3 →
  `SIF-06_TRIP` (the **T7** proof that all doors are shut).
* **SIF-07 (p.356)** — **master beam-on permissive**: door-lock confirmation
  switches `GADL-01/02/04/05` + `SADL-01/02` + `SIF-06`, with a **TON**
  `BEAM_DELAY_TIMER = T#180s` and an RS latch → `SIF-07_OUTPUT`. Consumed by
  SIF-01/02/13 and the SFC.
* **SIF-08 (p.363)** — eight **dual-channel** beam-off buttons `BOB-01…08`
  (`:A`/`:B` AND'd per button), **1oo7** (any one), **RS-latched**, reset
  `IOC-01-BOB:RESET`. Drops CON-01,02,03,06,07,08,09,10 and instantly unlocks.
* **SIF-09 (p.368)** — `RDMND-01/02` (dose) + `RDMNR-01/02` (rate), **1oo2**,
  RS-latched, reset `IOC-01-RDMN:RESET`. Drops CON-01/02/03 and CON-09.
* **SIF-10 (p.372)** — `KEY-03` rack key (1oo1) → `SIF-10_TRIP`; gates CON-04/05
  (and CON-09/10 RF). Combined with `KEY-01` (ZCP) elsewhere.
* **SIF-11 (p.377)** — `OXMON-01…04`, **1oo4**, RS-latched, reset
  `IOC-01-GAS:RESET`. Closes LN₂ valve `SDVLN2`, switches O₂ beacons/indicators
  IND-01/02/03 and speaker SP02.
* **SIF-13 (p.382)** — gate `GADC-04/05/06` 2oo3, AND'd with `SIF-07_OUTPUT` →
  drives CON-06/07/08 with a **200 ms** delay. (Added in Rev 4.0 to split gate
  from door.)

## 4.4 The central `Logic` POU (pp.267–269) — cause → effect

This is the block that actually drives the outputs:
* **Contactors (p.267):** combine the SIF trips per group and **RS-latch** them so
  that **CON-01,02,03,06,07,08,09,10 cannot re-energise after a trip without a
  fresh full search** (the `SEARCHED_AND_LOCKED` latch). This is why, in the
  simulator, you must re-`search` after any door/BOB trip.
* **Door/gate solenoids `SOL-01…06`:** service doors lock when the search
  *starts*; general doors/gate lock when the *final* button is pressed; all
  unlock when status = Open or SIF-08 is active.
* **Lights/annunciators/sounders (pp.268–269):** white light vs blue light
  interlock, annunciator OPEN/RESTRICTED/STANDBY/BEAM-ON, key solenoids, speaker
  programs, O₂ beacon.

## 4.5 The Search SFC + Transition_Timer (SIF-04)

**Layer 1 — the SFC** steps (Modbus bit in brackets): `Open` (0) → `Open-Ready`
(1) → `Search_Start` (2) → `Hutch_Entered` (3) → `ASB1` (4) → `ASB2` (5) → `ASB3`
(6) → `ASB4` (7) → `Standby` (8) → `Beam On` (9); with abort branches
`Search_Aborted`, `Start_Aborted`, `Run_Aborted`. (Modbus bit 10 =
`SEARCHED_AND_LOCKED` — a convenient state handle for an HMI.)

**Layer 2 — six `Transition_Timer` instances** (FB defined p.285), one per gap
T1-T2 … T6-T7. Each takes `Start_Timer`, `Min_Time`, `Max_Time`, `Reset` and
outputs `Below_Min_Time` (→ `_TRIP_LOW`), `Exceed_Max_Time` (→ `_TRIP_HIGH`) and
`Transition_Time` (ms). **All six use `Min = T#5s`, `Max = T#60s`** and are reset
by `STATUS-START_SEARCH`.

## 4.6 Verified timing constants (Global Variables)

| Tag | Value | Purpose |
|---|---|---|
| `MAX_SEARCH_TIME` | **180 s** | overall search watchdog |
| `T1-T2…T6-T7_TIMER_MIN` | **5 s** | min per-step time (faster ⇒ abort) |
| `T1-T2…T6-T7_TIMER_MAX` | **60 s** | max per-step time (slower ⇒ abort) |
| `BEAM_DELAY_TIMER_TIME` | **180 s** | Standby → Beam-On dwell |
| `RESET_DELAY_TIMER` | **60 s** | delay returning to Open |
| `DOOR_UNLOCK_DELAY` | **20 s** | SIF-03 zero-source confirm |
| `LIGHT_CURTAIN_DELAY` | **2 s** | LC monitoring arm delay |
| gate/RF contactor delay | **200 ms** | CON-06…10 trip delay |

## 4.7 Function-block types used

* **Voters:** `X_2oo3_B` (sum of 3 BOOLs ≥ 2; also a discrepancy `Dev` output) —
  used in SIF-01/02/03/05/06/13. The higher votes 1oo4/1oo7/1oo2 in SIF-08/09/11
  are done with plain `&`/`>=1` gating + RS latches, **not** voter blocks.
* **Analogue trips:** `X_LimH` (high trip) and `X_LimL` (low trip), each with
  hysteresis, trip-delay `DT`, `Inhibit`, `Reset`, `Ch_ok`. `X_Hx_AI` scales raw
  HIMax counts to engineering units.
* **IEC blocks:** `TON` (on-delay), `TP` (pulse), `RS`/`SR` (latches),
  `R_TRIG`/`F_TRIG` (edge detect), `MOVE`, `LIMIT`, comparators.
* **Custom:** `Transition_Timer`, `2In_/3In_Discrepency_Alarm`.

## 4.8 Analogue setpoints (as exported)

| Signal | Block | Setpoint | Hyst |
|---|---|---|---|
| OXMON-01…04 (O₂) | `X_LimL` (low) | 25.0 (full-scale placeholder; commissioned value ≈ 19.5 %) | 0.2 |
| IT-01…03 (current) | `X_LimH` (high) | 0.0 (placeholder) | 0.2 |
| VT-01…03 (voltage) | `X_LimH` (high) | 0.0 (placeholder) | 0.2 |
| RDMN dose/rate | digital trip contacts (>4 mA per C&E) | — | — |

Each AI channel also exposes `_OC` (open-circuit), `_SC` (short-circuit) and
`_CH_OK` diagnostics. The simulator uses 19.5 %O₂ and 4 mA as illustrative trip
points — adjust in `data/cause_effect.json` to match the commissioned values.

## 4.9 Things worth knowing for support work

* **Latching / "no silent restart":** trips and the search-complete state are RS
  latches. After any trip you need an explicit **reset** *and* (for the hazard) a
  **fresh search**. Modelled exactly in the simulator.
* **Resets are separate:** `IOC-01-BOB:RESET` (SIF-08), `…-RDMN:RESET` (SIF-09),
  `…-GAS:RESET` (SIF-11), Open/Reset `OR-01` (SIF-03, only live after the 20 s
  zero-source confirm — watch `OR-01:LED`).
* **Dual-channel devices** (BOB, BLUEL, ANNUN, BONI, BOBI) are read as `:A`/`:B`
  pairs and AND'd; discrepancy-alarm blocks give first-up annunciation.
* **No application bypass/maintenance-override block exists** — overrides are done
  only via SILworX **Global Forcing** (Watchpages pp.711–712). (If you saw an
  `LXS_BYPASS` block elsewhere, that belongs to a *different, unrelated* project
  that used to be in this repo's history — not B10E.)
* **Comms:** Modbus TCP slave on **port 502** exposes the SFC state bits and the
  oxygen readings; an OPC-UA server mirrors most tags. Good HMI/SCADA handles.
* **Naming wart:** the PLC tag database uses `BL10E-PS-…` while the SIF block
  names and the C&E "EPICS/DCS Tag" use `B10E-PS-…`. Same devices. Door locks
  appear **twice**: as outputs `SOL-01…06` and as feedback inputs `GADL-/SADL-`.

*External drawings referenced by the C&E but not in this repo:* SRS
`TDI-PSS-SRS-0002`, SIF logic `Dwg 1224211`, layout `Dwg 1212854`.
