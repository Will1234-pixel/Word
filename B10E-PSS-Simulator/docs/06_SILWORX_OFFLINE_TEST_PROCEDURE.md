# 6 · SILworX offline-simulation test procedure (walks the real program)

*Purpose: give you a **step-by-step procedure to run in HIMA SILworX offline
simulation** that drives the actual B10E PSS program — forcing the real input
variables, watching the real intermediate signals propagate through the function
blocks, and confirming the real outputs. Follow it page-by-page and you will
understand the whole program.*

All tag names, function blocks and page numbers below are taken directly from
`program.pdf` (project `C15862H-BL10E`, configuration `BL10E_HeXI [400]`,
SILworX v16.0.0 R3326). Page text is in `data/program_extracted.txt`.

---

## 0 · Setup & conventions (read once)

### 0.1 Start offline simulation
1. Open the project, select the **Resource `BL10E_HeXI [400]`**.
2. **Code Generation** → compile the resource (offline simulation runs the
   generated code on the PC).
3. Start **Offline Simulation** for the resource. SILworX runs the logic with no
   hardware.
4. Open a **Logic page** (e.g. `Library/SIF/B10E-SIF-01`, p.291) — in simulation
   the wires/pins show **live TRUE/FALSE** values, so you literally watch the
   logic.
5. Open a **Force Editor / Watch window** (or use the logic page context menu →
   *Force*) to set input variables and to add the signals you want to watch.

> In offline simulation you **force the GLOBAL variables that represent the field
> I/O** (the `BL10E-PS-…` tags). You do not have real channels, so the input tag
> *is* your input.

### 0.2 The single most important convention — check polarity first
The suffix `_TRIP` in this program does **not** always mean "TRUE = tripped".
Many `_TRIP`/`_OUTPUT` signals are **permissives**: **TRUE = healthy / allow**,
and they **drop to FALSE to trip** (de-energise-to-trip). Always confirm a
signal's *healthy* value by reading it live in simulation before you trust it.

Confirmed signal polarities (from the logic pages):

| Signal | Healthy / normal value | Demand (unsafe) value |
|---|---|---|
| `BL10E-PS-GADC-01..06` (door/gate closed) | **1 = closed** | 0 = open |
| `BL10E-PS-SADC-01..05` (service door closed) | **1 = closed** | 0 = open |
| `BL10E-PS-KEY-01/02/03` (enable keys) | **1 = on/enabled** | 0 = off |
| `BL10E-PS-SCR-01` (search card) | 1 = card present | 0 = absent |
| `BL10E-PS-BOB-0x:A` & `:B` (beam-off, dual ch) | **1 = not pressed** | 0 = pressed |
| `BL10E-PS-ASB-01..04`, `ASBF-01` (search buttons) | 0 = idle | **0→1 rising edge = press** |
| `BL10E-PS-LCRx-01` (light curtain) | 1 = clear | 0 = beam interrupted |
| `BL10E-PS-OR-01` (Open/Reset PB) | 0 = idle | 0→1 = pressed |
| `BL10E-PS-IT-0x`, `VT-0x` (current/voltage, REAL mA) | ~4 mA (≈0) | high (e.g. 12) → `_TRIP=1` |
| `BL10E-PS-OXMON-0x` (oxygen, REAL %O₂) | ~20.9 | low (e.g. 18) → `_TRIP=1` |
| `…-BOB/RDMN/GAS/SYS:RESET` (reset PBs) | 0 = idle | 0→1 = pressed |
| **Output** `BL10E-PS-CON-0x:EN` | depends on state | **1 = energised (hazard live)**, 0 = safe |
| **Output** `BL10E-PS-SOL-0x` (door locks) | — | **1 = locked**, 0 = unlocked |

> **Permissive vs detection:** for the door SIFs, `…_TRIP = 1` is *healthy*
> (permissive). For the analogue trips, `…_TRIP = 1` means *limit exceeded*
> (detection). Different sense — watch the live value, don't assume from the name.

### 0.3 How time works in offline simulation
The timers (`MAX_SEARCH_TIME = 180 s`, the six `5 s/60 s` `Transition_Timer`s,
`BEAM_DELAY_TIMER = 180 s`, `DOOR_UNLOCK_DELAY = 20 s`) run on the **simulation
clock**. Either let the simulation run in real time (wait the seconds), or use
SILworX's simulation time controls if available. The per-step window means: after
each search step, **wait ≥5 s and <60 s** before the next force.

### 0.4 Test record
For every test record: pre-state, the force(s) applied, the intermediate signal
observed, the output observed, latch/reset behaviour, PASS/FAIL. Template at the
end (§7).

---

## 1 · Establish the healthy baseline (do this first, every session)

Force these so the system sits at **`STATUS-OPEN_READY` = 1**:

| Force these = 1 (TRUE) | Why |
|---|---|
| `BL10E-PS-GADC-01,02,03,04,05,06` | all doors & gate closed |
| `BL10E-PS-SADC-01,02,03,04,05` | all service doors closed |
| `BL10E-PS-KEY-01, KEY-02, KEY-03` | enable keys on |
| `BL10E-PS-BOB-01:A..08:A` and `01:B..08:B` | no beam-off pressed |
| `BL10E-PS-LCRx-01` | light curtain clear |

| Force these = 0 (FALSE) / value | Why |
|---|---|
| `BL10E-PS-ASB-01..04`, `ASBF-01`, `SCR-01`, `OR-01` | buttons idle |
| `BL10E-PS-RDMND-01/02`, `RDMNR-01/02` | no radiation (set to healthy value) |
| `BL10E-PS-IT-01..03`, `VT-01..03` = **3.9** (≈0/below SP) | source off |
| `BL10E-PS-OXMON-01..04` = **20.9** | oxygen normal |

Pulse each reset once (`…-BOB:RESET`, `…-RDMN:RESET`, `…-GAS:RESET` = 1 then 0)
to clear any power-up latches.

**Watch (expect):** `STATUS-OPEN_READY = 1`; all `…SIF-0x_TRIP/_OUTPUT` healthy;
all `BL10E-PS-CON-0x:EN = 0` (safe); annunciator `…ANNOPN-01:A/:B = 1` (OPEN).

---

## 2 · Per-SIF tests (force the cause, watch the effect)

For each: open the logic page, force the input(s), watch the named intermediate,
confirm the output. **Re-establish the §1 baseline between tests.**

### SIF-01 — General Access Door (p.291) — voting 2oo3
* **Open page:** `Library/SIF/B10E-SIF-01` (p.291). FB = `X_2oo3_B`.
* **Step 1:** Force `BL10E-PS-GADC-01 = 0` (one leaf open).
  * Watch `X_2oo3_B.Out` — still **1** (2 of 3 still closed). `BL10E-SIF-01_TRIP`
    stays **1**. **No trip** (this proves 2oo3 tolerates one switch).
* **Step 2:** Also force `BL10E-PS-GADC-02 = 0` (now 2 of 3 open).
  * Watch `X_2oo3_B.Out → 0`; `BL10E-SIF-01_TRIP → 0`.
  * **Expected output:** `BL10E-PS-CON-01:EN, -02:EN, -03:EN → 0` (electron source
    isolated). (Driven via the central `Logic` POU, pp.267–269.)
* **Reset:** restore GADC-01/02 = 1. Note the source does **not** come back —
  see §3 (you must redo the search; `SEARCHED_AND_LOCKED` was broken).

### SIF-13 — General Access Gate (p.382) — 2oo3, 200 ms
* Force `BL10E-PS-GADC-04 = 0` then `GADC-05 = 0`.
* Watch `BL10E-SIF-13_TRIP → 0`; after ~200 ms, `BL10E-PS-CON-06:EN, -07:EN,
  -08:EN → 0` (3-phase RF power off).

### SIF-02 — Service Access Door (p.297) — 2oo3 + 1oo2
* Group C: force `SADC-01 = 0`, then `SADC-02 = 0` → `X_2oo3_B.Out → 0` →
  `BL10E-SIF-02_TRIP → 0` → `CON-01/02/03:EN → 0`.
* Group D (1oo2): from baseline, force just `SADC-04 = 0` → single switch trips
  (1oo2). Confirm via `BL10E-SIF-02_TRIP`.

### SIF-03 — Current & Voltage Monitoring (p.303) — 2oo3, 20 s, Open/Reset
* **Open page p.303.** FBs: two `X_2oo3_B` (current, voltage), an `RS` latch, a
  `TON` `DOOR_UNLOCK_DELAY = T#20s`, `R_TRIG` on `OR-01`.
* **Step 1:** Force `BL10E-PS-IT-01 = 12.0` then `IT-02 = 12.0` (2oo3 current
  high). Watch `BL10E-PS-IT-01_TRIP/02_TRIP → 1` and the 2oo3 `Out`. Result:
  **radiation present** — door-lock outputs `BL10E-PS-SOL-01..06 = 1` are **held
  locked**; `BL10E-SIF-03_OUTPUT` blocks unlocking.
* **Step 2:** Force `IT-01 = 3.9`, `IT-02 = 3.9` (source back to ~0). Start the
  20 s `DOOR_UNLOCK_DELAY`. Watch `BL10E-PS-OR-01:LED` — stays **0** until 20 s
  pass.
* **Step 3:** After ≥20 s, `OR-01:LED → 1`. Pulse `BL10E-PS-OR-01 = 1`. Now the
  unlock is permitted; `BL10E-SIF-03_OUTPUT` releases and locks may drop.

### SIF-08 — Beam-Off Buttons (p.363) — 1oo7, latched
* **Open page p.363.** FB = `RS` latch; `BL10E-SIF-08_TRIP` is the permissive
  (1 = healthy).
* **Step 1:** Force `BL10E-PS-BOB-03:A = 0` **and** `BOB-03:B = 0` (one button,
  both channels). Watch `BL10E-SIF-08_TRIP → 0`.
  * **Expected:** `CON-01:EN,-02,-03,-06,-07,-08,-09,-10 → 0` (source **and** RF
    off) and door locks `SOL-0x → 0` (instant unlock — escape).
* **Step 2:** Restore `BOB-03:A/:B = 1`. `SIF-08_TRIP` **stays 0** (latched).
* **Step 3:** Pulse `BL10E-PS-IOC-01-BOB:RESET = 1` then `0`. `SIF-08_TRIP → 1`.
* Repeat for each of buttons 1–8 to prove **1oo7** (any one trips).

### SIF-09 — Radiation Monitoring (p.368) — 1oo2, latched
* Force `BL10E-PS-RDMND-01` to its trip value (watch live; high). Watch
  `BL10E-SIF-09_TRIP → 0`. Expected: `CON-01/02/03:EN → 0` and `CON-09:EN → 0`.
* Latched — clear with `BL10E-PS-IOC-01-RDMN:RESET`. Repeat with `RDMNR-01`,
  `RDMND-02`, `RDMNR-02` (1oo2: any one).

### SIF-10 — Electron-Source Enable Key (p.372) — 1oo1
* Force `BL10E-PS-KEY-03 = 0` (rack key off). Watch `BL10E-SIF-10_TRIP → 0` →
  `CON-04/05:EN → 0` (and RF `CON-09/10` per the Logic POU).
* Restore `KEY-03 = 1`. Note: a key is **not** a reset — the hazard returns only
  via a fresh search.

### SIF-11 — Oxygen Monitoring (p.377) — 1oo4, latched
* Force `BL10E-PS-OXMON-02 = 18.0` (< setpoint). Watch `OXMON-02_TRIP → 1` and
  `BL10E-SIF-11_TRIP`.
  * **Expected:** `BL10E-PS-SDVLN2 → 0` (LN₂ valve closes); O₂ indicators
    `…IND/…SP0x` to alarm/RED.
* Restore `OXMON-02 = 20.9`, pulse `…-GAS:RESET`. Repeat each of OXMON-01..04
  (1oo4).

---

## 3 · The SEARCH sequence (SIF-04 SFC + SIF-05/06/07) — the core walkthrough

This is the heart of the program. Open the **SFC** at `Library/SIF/B10E-SIF-04`
(pp.326–338) and the **Search Start** page `B10E-SIF-05` (p.344). Keep a watch
list of the **status flags** and **timers** so you can see the state machine move:

> Watch list: `STATUS-OPEN`, `STATUS-OPEN_READY`, `STATUS-START_SEARCH`,
> `STATUS-HUTCH_ENTERED`, `STATUS-ASB1..ASB4`, `STATUS-STANDBY`,
> `STATUS-BEAM_ON`, `SEARCHED_AND_LOCKED`, `SEARCH_TIMER_RUNNING`,
> `SEARCH_TIME_EXCEEDED`, `LIGHT_CURTAIN_MONITORING`, `BEAM_DELAY_TIMER_END`,
> `ABORT_SEARCH`, each `Tx-Ty_TIMER_TRIP_LOW/HIGH`, and `BL10E-SIF-05_START`.

### 3.1 Walk it (the valid sequence)

| # | Force (input) | Watch advance to | Also watch |
|---|---|---|---|
| 0 | baseline §1 | `STATUS-OPEN_READY = 1` | all SADC=1, keys=1 |
| **T1** | `BL10E-PS-SCR-01 = 1` (card) | `BL10E-SIF-05_START → 1`, `STATUS-START_SEARCH → 1` | service locks `SOL-05/06 → 1`; `ANNRES → 1`; `SEARCH_TIMER_RUNNING → 1` (180 s) |
| — | *wait ≥5 s, <60 s* | — | `T1-T2_TIMER` running |
| **T2** | pulse `BL10E-PS-LCRx-01 = 0` then `1` (single pass-through) | `STATUS-HUTCH_ENTERED → 1` | `LIGHT_CURTAIN_MONITORING → 1` after ~2 s |
| — | wait ≥5 s | — | — |
| **T3** | pulse `BL10E-PS-ASB-01 = 0→1` | `STATUS-ASB1 → 1` | `ASB-01:LED → 1` |
| — | wait ≥5 s | — | light curtain monitored |
| **T4** | pulse `BL10E-PS-ASB-02 = 0→1` | `STATUS-ASB2 → 1` | `ASB-02:LED → 1` |
| — | wait ≥5 s | — | — |
| **T5** | pulse `BL10E-PS-ASB-03 = 0→1` | `STATUS-ASB3 → 1` | `ASB-03:LED → 1` |
| — | wait ≥5 s | — | — |
| **T6** | pulse `BL10E-PS-ASB-04 = 0→1` | `STATUS-ASB4 → 1` | `ASB-04:LED → 1`; LC monitoring ends |
| — | wait ≥5 s | — | — |
| **T7** | pulse `BL10E-PS-ASBF-01 = 0→1` (general doors must be closed → `BL10E-SIF-06_TRIP = 1`) | `STATUS-STANDBY → 1` | general locks `SOL-01..04 → 1`; `ANNSTB → 1`; blue lights `BLUEL-0x → 1`; `BEAM_DELAY_TIMER` (180 s) starts; `SEARCHED_AND_LOCKED → 1` |
| — | *wait 180 s* | `BEAM_DELAY_TIMER_END → 1` | `BL10E-SIF-07_OUTPUT → 1` |
| **T8** | (beam-on permitted) | `STATUS-BEAM_ON → 1` | `ANNBON → 1`; `BONI-01 → 1`; `CON-0x:EN → 1` (hazard live) |

### 3.2 Prove the aborts (each returns toward OPEN, sets `ABORT_SEARCH`)

| Abort test | How | Watch |
|---|---|---|
| **Out of order** | at `STATUS-START_SEARCH`, pulse `ASB-01` before `LCRx` | `ABORT_SEARCH → 1`, back to OPEN |
| **Too fast (<5 s)** | T2→T3 in under 5 s | the relevant `Tx-Ty_TIMER_TRIP_LOW → 1` → abort |
| **Too slow (>60 s)** | wait >60 s in any step | `Tx-Ty_TIMER_TRIP_HIGH → 1` → abort |
| **Overall >180 s** | dawdle so total search > 180 s | `SEARCH_TIME_EXCEEDED → 1` → abort |
| **Light curtain** | during T3..T6, pulse `LCRx-01 = 0` | abort while `LIGHT_CURTAIN_MONITORING = 1` |
| **Key lost** | during search, `KEY-01 = 0` or `KEY-02 = 0` | abort |
| **Door opened** | during search, `GADC-01=0`+`GADC-02=0` | abort |
| **Can't declare with door open** | at ASB4, open a general door, then pulse `ASBF-01` | `SIF-06_TRIP = 0`, T7 refused |

### 3.3 Prove the trip-from-BEAM_ON + no-silent-restart
1. Reach `STATUS-BEAM_ON` (3.1). Confirm `CON-0x:EN = 1`.
2. Trip it (e.g. `BOB-01:A/:B = 0`). Watch `CON-0x:EN → 0`,
   `SEARCHED_AND_LOCKED → 0`, state leaves BEAM_ON.
3. Clear the cause + reset. Confirm `CON-0x:EN` **stays 0** — it will **not**
   re-energise until you run a **complete new search** (3.1). This is the latch
   in the `Logic` POU (pp.267–269); it is the key safety property of the program.

---

## 4 · Map of which page proves what (quick index)

| Want to study… | Open page |
|---|---|
| Door 2oo3 trip | SIF-01 p.291 |
| Service door | SIF-02 p.297 |
| Radiation present / door-unlock 20 s | SIF-03 p.303 |
| The search SFC (states, transitions, timers) | SIF-04 pp.326–338 |
| Search-start permissive (T1) | SIF-05 p.344 |
| Search-complete (T7) | SIF-06 p.350 |
| Beam-on permissive + 180 s | SIF-07 p.356 |
| Beam-off buttons + reset latch | SIF-08 p.363 |
| Radiation monitors | SIF-09 p.368 |
| Enable key | SIF-10 p.372 |
| Oxygen 1oo4 | SIF-11 p.377 |
| Gate 2oo3 200 ms | SIF-13 p.382 |
| Cause→effect actuator (all contactors/locks/lamps + latches) | `Logic` pp.267–269 |
| Per-step 5/60 s watchdog block | `Transition_Timer` p.285 |
| Voter block internals | `X_2oo3_B` p.644; analogue `X_LimH` p.507 / `X_LimL` p.514 |

---

## 5 · Things that will trip *you* up (support notes)
* `_TRIP = 1` is usually **healthy/permissive**, not "tripped". Confirm live (§0.2).
* Beam-off and door inputs are **de-energise-to-trip**: the *demand* value is **0**.
* Beam-off, radiation and oxygen trips **latch** — you must pulse the matching
  **reset** (`…-BOB/RDMN/GAS:RESET`), and the hazard still needs a fresh search.
* Dual-channel devices need **both** `:A` and `:B` forced (BOB, BLUEL, ANNUN,
  BONI, BOBI). A discrepancy block alarms if `:A ≠ :B`.
* Setpoints in this export are placeholders (`IT/VT _SP = 0.0`, `OXMON _SP =
  25.0`). Use the commissioned values when you have them; the simulator setpoints
  live in each channel's `…_SP` / `…_HYST` global variable.

## 6 · Honest gaps
The exact internal polarity of a couple of gates (e.g. the BOB RS latch set/reset
sense) and the precise cell relations in the C&E grid were not 100 % legible from
the exported text — **watch the live value in simulation** (that is what offline
sim is for) and, for anything affecting plant, reconcile against the SRS
`TDI-PSS-SRS-0002` and SIF drawing `Dwg 1224211` (not in this repo).

## 7 · Test record template
```
SIF / step: ____   Page: ____   Date: ____   Engineer: ____
Baseline OK (STATUS-OPEN_READY=1)?  Y / N
Forced (tag = value): _______________________________________
Intermediate watched (tag : observed): ______________________
Output watched (tag : observed): ____________________________
Latched? reset tag used: ____________________________________
Fresh search needed to recover?  Y / N
PASS / FAIL: ____   Notes: ___________________________________
```
