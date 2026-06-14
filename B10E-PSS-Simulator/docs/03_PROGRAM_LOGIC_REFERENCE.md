# 3 · Program logic reference (the exact PLC code)

*This document is the map of the real safety program. It tells you, page by page,
where each safety function lives in `program.pdf` and what its logic actually
does — so when something trips in offline simulation you can find the exact block
that decided it.*

*This is the authoritative map of `program.pdf` (713 pages, HIMA SILworX export,
SILworX v16, project `C15862H-BL10E`, configuration `BL10E_HeXI [400]`,
target **HIMax**, SIL 2). The searchable text is in
`data/program_extracted.txt` (page markers `===== PAGE n =====`).*

**A few words before you start (plain English):**
* A **SIF** is one independent safety function — one self-contained job the PLC
  does to keep people safe (for example "is the door shut?").
* **2oo3 voting** means **2 of 3** sensors must agree before the PLC believes
  them. It tolerates one faulty or disagreeing sensor.
* An **RS latch** is a memory bit that, once set, **stays set until something
  resets it** — so a trip does not clear on its own.
* A **TON** is an **on-delay timer**: the output turns on only after the input
  has stayed on for a set time.
* An **SFC** is a **step-by-step state machine** — the program walks through a
  fixed list of steps in order (used for the hutch search).
* A **permissive** is a signal that is **TRUE when everything is healthy / OK**
  and **drops to FALSE to trip**.
* **De-energise-to-trip** means the **safe state is OFF**. If power is lost the
  device falls to its safe position by itself.

Convention in SILworX FBD text: `&` = AND, `>=1` = OR, `NOT`/a bubble = invert.
**All effects are de-energise-to-trip:** an output `FALSE` = tripped/safe; a SIF
`..._OUTPUT`/`..._TRIP` signal `TRUE` usually means **healthy/permissive**.

---

## 3.1 Page index (where everything lives)

| Pages | Area |
|---|---|
| 1–13 | Cover + Table of Contents |
| 14–16 | Project structure (POU tree, lists all SIFs) |
| 37–126 | **Global Variables & cross-references** (the master tag list + initial values, setpoints, timer presets) |
| 127–149 | **Hardware** (HIMax I/O module config) |
| 151–285 | `C15862H_Lib` — custom application logic (see 3.4) |
| **286–382** | **The 12 SIFs** (core safety logic) |
| 383–690 | `X_Lib` — HIMA standard blocks (voters, timers, limits) |
| 691–710 | Modbus TCP / OPC-UA / safeethernet |
| 711–713 | Watchpages (Global Forcing) |

## 3.2 The 12 SIFs (page → logic)

Reminder: a **SIF** is one independent safety function — one self-contained
safety job.

| SIF | Pages | Logic pg | Title |
|---|---|---|---|
| SIF-01 | 287–291 | 291 | General Access Door Closed (main personnel door is shut) |
| SIF-02 | 292–297 | 297 | Service Access Door Closed (maintenance door is shut) |
| SIF-03 | 298–303 | 303 | Current & Voltage Monitoring (is the source really off?) |
| **SIF-04** | 304–338 | **326–338** | **Search Sequence (SFC — the step-by-step hutch search)** |
| SIF-05 | 339–344 | 344 | Search Start (may a search begin?) |
| SIF-06 | 345–350 | 350 | Search Complete (all doors proven shut) |
| SIF-07 | 351–356 | 356 | Beam On (permissive — TRUE = OK for beam) / lock feedback |
| SIF-08 | 357–363 | 363 | Beam Off Buttons (the emergency-stop buttons) |
| SIF-09 | 364–368 | 368 | Radiation Monitoring |
| SIF-10 | 369–372 | 372 | Electron Source Enable (the enable key) |
| SIF-11 | 373–377 | 377 | Oxygen Monitoring |
| SIF-13 | 378–382 | 382 | General Access Gate Closed (the entrance gate is shut) |

*(No SIF-12 in the PLC — the C&E "SIF 11 & 12" both refer to the oxygen function.)*

## 3.3 Per-SIF logic (plain English)

* **SIF-01 (p.291)** — `GADC-01/02/03` (three "closed" switches on the **main
  personnel door**) voted **2oo3** (2 of 3 must agree) using `X_2oo3_B` (HIMA's
  standard 2oo3 voter block), AND'd with `SIF-07_OUTPUT` (the **beam-on master
  permissive**: TRUE = beam allowed). Output `SIF-01_TRIP` (door function — TRUE
  = door shut, OK to run) → contactors CON-01/02/03 (power contactors feeding the
  **electron source**) via the central `Logic` POU.
* **SIF-02 (p.297)** — `SADC-01/02/03` (three "closed" switches on the **service /
  maintenance door**) voted 2oo3 **OR** `SADC-04/05` (two more service-door
  switches, a 1oo2 pair — either one is enough), AND'd with `SIF-07_OUTPUT`
  (beam-on permissive). Outputs `SIF-02_TRIP` (service-door function — TRUE =
  service door shut, OK) and `SERVICE_DOOR_CLOSED`.
* **SIF-03 (p.303)** — "is the beam actually off?" + door-unlock permit. Current
  `IT-01/02/03` (**current transmitters** on the electron source — a high reading
  means the source is live) voted 2oo3, and Voltage `VT-01/02/03` (**voltage
  transmitters** — high = source live) voted 2oo3. An **RS** latch (a memory that
  stays set until reset) + a **TON** (on-delay timer) `DOOR_UNLOCK_DELAY = T#20s`
  + an `R_TRIG` (rising-edge detector) on the Open/Reset pushbutton `OR-01` (the
  **Open / Reset** button the operator presses to unlock and reset) and key
  `KEY-01` (the **electron-source enable key** at the control panel): the
  Open/Reset button only becomes live once both 2oo3 votes read zero for
  **≥20 s**, then `OR-01:LED` lights. (The C&E footnote mentions 12 s from the
  SRS; the **implemented** value is 20 s.)
* **SIF-04 (pp.326–338)** — the **SFC** (the step-by-step state machine for the
  search; see 3.5).
* **SIF-05 (p.344)** — Search-start permit (**T1**): `SCR-01` (the **search card
  reader** at the door) AND `KEY-01` (control-panel enable key) AND `KEY-02` (the
  **hutch enable key**, needed to start a search) AND service-door 2oo3 AND the
  1oo2 pair AND `SIF-08` healthy (no beam-off button pressed) → `SIF-05_START`
  (the **search-start permit** — TRUE = a search may begin).
* **SIF-06 (p.350)** — Search-complete: general door 2oo3 AND gate 2oo3 →
  `SIF-06_TRIP` (**search-complete proof** — TRUE = all doors and the gate are
  shut, so the search may finish; the **T7** proof that every door is shut).
* **SIF-07 (p.356)** — **master beam-on permissive** (TRUE = beam allowed):
  door-lock confirmation switches `GADL-01/02/04/05` (the "locked" switches that
  feel the **bolt** of the main door / gate) + `SADL-01/02` (the "locked"
  switches on the **service door**) + `SIF-06`, with a **TON** (on-delay timer)
  `BEAM_DELAY_TIMER = T#180s` and an RS latch (stays set until reset) →
  `SIF-07_OUTPUT`. Consumed by SIF-01/02/13 and the SFC.
* **SIF-08 (p.363)** — eight **dual-channel** beam-off buttons `BOB-01…08` (the
  **Beam-Off Buttons** / emergency stops; each has two wires `:A` and `:B`, AND'd
  per button for safety), voted **1oo7** (any one pressed trips), **RS-latched**
  (stays tripped until reset), reset by `IOC-01-BOB:RESET` (the control-room
  **reset button** for the beam-off-button latch). Drops CON-01,02,03,06,07,08,
  09,10 and instantly unlocks.
* **SIF-09 (p.368)** — `RDMND-01/02` (**radiation monitors** — accumulated
  **dose**) + `RDMNR-01/02` (radiation monitors — dose **rate**), voted **1oo2**
  (any one trips), RS-latched, reset by `IOC-01-RDMN:RESET` (control-room reset
  button for the **radiation** latch). Drops CON-01/02/03 and CON-09.
* **SIF-10 (p.372)** — `KEY-03` (the **electron-source enable key** at the
  equipment rack), 1oo1 → `SIF-10_TRIP` (**enable-key function** — TRUE = key on,
  OK); gates CON-04/05 (and CON-09/10 RF). Combined with `KEY-01` (the
  control-panel ZCP enable key) elsewhere.
* **SIF-11 (p.377)** — `OXMON-01…04` (the four **oxygen monitors** in the hutch —
  a low reading means the air is unsafe to breathe), voted **1oo4** (any one
  trips), RS-latched, reset by `IOC-01-GAS:RESET` (control-room reset button for
  the **oxygen/gas** latch). Closes LN₂ valve `SDVLN2` (the **liquid-nitrogen
  shut-off valve**), and switches O₂ beacons/indicators IND-01/02/03 (**oxygen
  traffic-light indicators** — green = air OK, red = oxygen low) and speaker SP02.
* **SIF-13 (p.382)** — gate `GADC-04/05/06` (three "closed" switches on the
  **entrance gate**) voted 2oo3, AND'd with `SIF-07_OUTPUT` (beam-on permissive)
  → drives CON-06/07/08 (the **3-phase RF** power contactors) with a **200 ms**
  delay. Output `SIF-13_TRIP` (gate function — TRUE = gate shut, OK). (Added in
  Rev 4.0 to split gate from door.)

## 3.4 The central `Logic` POU (pp.267–269) — cause → effect

This is the block that actually drives the outputs:
* **Contactors (p.267):** combine the SIF trips per group and **RS-latch** them
  (latch = a memory that stays set until reset) so that **CON-01,02,03,06,07,08,
  09,10 (the electron-source and RF power contactors) cannot re-energise after a
  trip without a fresh full search** (the `SEARCHED_AND_LOCKED` latch — the memory
  bit meaning "search finished and doors locked"). This is why, after any door or
  beam-off-button trip, you must run a fresh search before the hazard can come
  back. Recall **de-energise-to-trip**: a contactor at `0` is the safe (isolated)
  state.
* **Door/gate solenoids `SOL-01…06` (the lock bolts on the doors/gate):** service
  doors lock when the search *starts*; general doors/gate lock when the *final*
  button is pressed; all unlock when status = Open or SIF-08 (a beam-off button)
  is active.
* **Lights/annunciators/sounders (pp.268–269):** white light vs blue light
  interlock, annunciator OPEN/RESTRICTED/STANDBY/BEAM-ON (the lit hutch signs),
  key solenoids, speaker programs, O₂ beacon.

## 3.5 The Search SFC + Transition_Timer (SIF-04)

An **SFC** is a step-by-step state machine: the program walks through a fixed
list of steps in order, and each step must be reached the right way before the
next is allowed.

**Layer 1 — the SFC** steps (Modbus bit in brackets): `Open` (0) → `Open-Ready`
(1) → `Search_Start` (2) → `Hutch_Entered` (3) → `ASB1` (4) → `ASB2` (5) → `ASB3`
(6) → `ASB4` (7) → `Standby` (8) → `Beam On` (9); with abort branches
`Search_Aborted`, `Start_Aborted`, `Run_Aborted`. (These match the `STATUS-…`
search-state tags: `STATUS-OPEN`, `STATUS-OPEN_READY`, `STATUS-START_SEARCH`,
`STATUS-HUTCH_ENTERED`, `STATUS-ASB1…ASB4`, `STATUS-STANDBY`, `STATUS-BEAM_ON`.)
Modbus bit 10 = `SEARCHED_AND_LOCKED` — the "search finished and doors locked"
memory bit, a convenient state handle for an HMI.

**Layer 2 — six `Transition_Timer` instances** (custom FB defined p.285), one per
gap T1-T2 … T6-T7. Each takes `Start_Timer`, `Min_Time`, `Max_Time`, `Reset` and
outputs `Below_Min_Time` (→ `_TRIP_LOW`: the step was done **too fast**),
`Exceed_Max_Time` (→ `_TRIP_HIGH`: the step took **too long**) and
`Transition_Time` (ms). **All six use `Min = T#5s`, `Max = T#60s`** and are reset
by `STATUS-START_SEARCH` (the tag meaning a search has begun).

## 3.6 Verified timing constants (Global Variables)

| Tag | Value | Purpose |
|---|---|---|
| `MAX_SEARCH_TIME` | **180 s** | overall search watchdog (whole search must finish in time) |
| `T1-T2…T6-T7_TIMER_MIN` | **5 s** | min per-step time — a step done faster ⇒ abort |
| `T1-T2…T6-T7_TIMER_MAX` | **60 s** | max per-step time — a step slower ⇒ abort |
| `BEAM_DELAY_TIMER_TIME` | **180 s** | Standby → Beam-On dwell (the warning wait before beam) |
| `RESET_DELAY_TIMER` | **60 s** | delay before returning to the Open state |
| `DOOR_UNLOCK_DELAY` | **20 s** | SIF-03 zero-source confirm (source must read off this long) |
| `LIGHT_CURTAIN_DELAY` | **2 s** | light-curtain monitoring arm delay |
| gate/RF contactor delay | **200 ms** | CON-06…10 (RF contactors) trip delay |

## 3.7 Function-block types used

* **Voters:** `X_2oo3_B` (HIMA's standard 2oo3 voter — sum of 3 BOOLs ≥ 2, so 2
  of 3 must agree; also gives a discrepancy `Dev` output) — used in
  SIF-01/02/03/05/06/13. The higher votes 1oo4/1oo7/1oo2 in SIF-08/09/11 are done
  with plain `&`/`>=1` gating + RS latches (memory bits that stay set until
  reset), **not** voter blocks.
* **Analogue trips:** `X_LimH` (HIMA's standard **high**-limit trip block) and
  `X_LimL` (the **low**-limit trip block), each with hysteresis (a small dead-band
  so the trip does not flicker), trip-delay `DT`, `Inhibit`, `Reset`, `Ch_ok`.
  `X_Hx_AI` scales raw HIMax counts to engineering units.
* **IEC blocks:** `TON` (on-delay timer — output turns on only after the input has
  stayed on for the set time), `TP` (pulse), `RS`/`SR` (latches — memories that
  stay set until reset), `R_TRIG`/`F_TRIG` (edge detect — fire on a 0→1 or 1→0
  change), `MOVE`, `LIMIT`, comparators.
* **Custom:** `Transition_Timer`, `2In_/3In_Discrepency_Alarm`.

## 3.8 Analogue setpoints (as exported)

Each of these sensors makes a `_TRIP` flag inside the PLC: `1` = the limit has
been crossed (oxygen too low, or source live), `0` = normal. The `_SP` tag is the
**set-point** (the level at which it trips) and `_HYST` is the **hysteresis** (the
small dead-band).

| Signal | Block | Setpoint (`_SP`) | Hyst (`_HYST`) |
|---|---|---|---|
| OXMON-01…04 (O₂ monitors — low reading = unsafe air) | `X_LimL` (low-limit trip) | 25.0 (full-scale placeholder; commissioned value ≈ 19.5 %) | 0.2 |
| IT-01…03 (current transmitters — high = source live) | `X_LimH` (high-limit trip) | 0.0 (placeholder) | 0.2 |
| VT-01…03 (voltage transmitters — high = source live) | `X_LimH` (high-limit trip) | 0.0 (placeholder) | 0.2 |
| RDMN dose/rate (radiation monitors) | digital trip contacts (>4 mA per C&E) | — | — |

Each AI channel also exposes `_OC` (open-circuit), `_SC` (short-circuit) and
`_CH_OK` (channel-OK) wiring-health diagnostics. The placeholder setpoints (`0.0`
on current/voltage, `25.0` on oxygen) are what the program exports today; the
commissioned trip points (≈ 19.5 % O₂, and ~4 mA on radiation) are set at site —
see document 04 (the SILworX offline test procedure) for how to confirm them.

## 3.9 Things worth knowing for support work

* **Latching / "no silent restart":** trips and the search-complete state are
  **RS** latches (memory bits that stay set until reset). After any trip you need
  an explicit **reset** *and* (for the hazard) a **fresh search** before the beam
  can return.
* **Resets are separate:** `IOC-01-BOB:RESET` (resets SIF-08, the beam-off
  buttons), `…-RDMN:RESET` (resets SIF-09, radiation), `…-GAS:RESET` (resets
  SIF-11, oxygen), and the Open/Reset button `OR-01` (SIF-03 — only live after the
  20 s zero-source confirm, so watch `OR-01:LED`). Each is its own control-room
  button.
* **Dual-channel devices** (the beam-off buttons `BOB`, blue lights `BLUEL`,
  annunciator signs `ANNUN`, beam-on indicator `BONI`, beam-off indicators `BOBI`)
  are read as `:A`/`:B` pairs and AND'd; discrepancy-alarm blocks give first-up
  annunciation if the two channels disagree.
* **No application bypass/maintenance-override block exists** — overrides are done
  only via SILworX **Global Forcing** (Watchpages pp.711–712). (If you saw an
  `LXS_BYPASS` block elsewhere, that belongs to a *different, unrelated* project
  that used to be in this repo's history — not B10E.)
* **Comms:** Modbus TCP slave on **port 502** exposes the SFC state bits and the
  oxygen readings; an OPC-UA server mirrors most tags. Good HMI/SCADA handles.
* **Naming wart:** the PLC tag database uses `BL10E-PS-…` while the SIF block
  names and the C&E "EPICS/DCS Tag" use `B10E-PS-…`. Same devices. Door locks
  appear **twice**: as outputs `SOL-01…06` (the lock bolts) and as feedback inputs
  `GADL-`/`SADL-` (the "locked" switches that feel those bolts).

*See also: document 00 (tag glossary — every signal name), document 01 (the
system overview), document 02 (the hutch search explained), and document 04 (the
SILworX offline test procedure — how to exercise this logic in offline
simulation).*

*External drawings referenced by the C&E but not in this repo:* SRS
`TDI-PSS-SRS-0002`, SIF logic `Dwg 1224211`, layout `Dwg 1212854`.
