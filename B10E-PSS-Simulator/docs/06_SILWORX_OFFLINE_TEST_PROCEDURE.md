# 6 · SILworX offline-simulation test procedure — v2.2 (complete, with concepts)

*Run this in HIMA SILworX **offline simulation** against the actual B10E program.
For every set of logic it gives you: the **Concept** (what it protects and why),
the **Logic as built** (the real blocks/signals on the named page), the **Test**
(exact forces and expected observations), and **What it proves**. Follow it top
to bottom and you will have exercised — and understood — the whole program.*

Source of truth: `program.pdf` (project `C15862H-BL10E`, configuration
`BL10E_HeXI [400]`, SILworX v16.0.0 R3326). Page text: `data/program_extracted.txt`.
Changes from v1: added SIF-05 negative tests, a standalone SIF-07 test, the
**lock-feedback forcing step** (without it the search stalls at STANDBY in
offline sim), voltage (VT) tests, verified contactor groupings from p.267,
dual-channel discrepancy tests, the KEY-01 release test, and a coverage matrix.
v2.1: corrected analogue handling — the `_SP` setpoints are fail-safe **constants**
(OXMON 25.0 / IT,VT 0.0) that cannot be forced; baseline and SIF-03/-11 tests now
force the `_TRIP` flags (Option A) or require a setpoint edit + code regen (Option B).
v2.2: added a plain-language "what the tag is" column to the §0.3 polarity table,
and a high-school-level explanation of every timer in §0.5.

---

## 0 · Setup & conventions (read once, it saves hours)

### 0.1 Start offline simulation
1. Open the project; select Resource **`BL10E_HeXI [400]`**.
2. Generate code, then start **Offline Simulation** on the resource.
3. Open any logic page (e.g. `Library/SIF/B10E-SIF-01`) — wires show live values.
4. Open the **Force Editor / a Watch page**; add the tags listed in each test.

### 0.2 Concept: forcing replaces the field
In offline simulation there is no I/O. The global variables that normally come
from field wiring (`BL10E-PS-…`) just sit at their initial values — **you are
the field**. Forcing an input variable is "operating the plant". Two traps:

* **Feedback inputs do not follow outputs.** When the program energises a door
  lock output (`SOL-01`), the lock **position feedback input** (`GADL-01`) does
  NOT change by itself — in the real plant the mechanism moves the switch; in
  simulation **you must force the feedback** to simulate the mechanism. This
  matters at T7 (§3) — if you don't force `GADL/SADL` TRUE after the locks
  energise, `BL10E-SIF-07_OUTPUT` never comes TRUE and beam-on never happens.
  The same idea applies to contactor feedbacks (`CON-0x:FB`) used by the alarm
  layer.
* **Polarity.** This program is de-energise-to-trip throughout, so for most
  inputs the **demand (unsafe) value is 0**, and many `…_TRIP`/`…_OUTPUT`
  signals are **permissives: TRUE = healthy, FALSE = tripped**. Exception: the
  analogue `…_TRIP` flags (IT/VT/OXMON) are detections: TRUE = limit exceeded.

### 0.3 Polarity table (force the right way)

| Signal | What the tag is (the device and its job) | Healthy / normal | Demand (unsafe / action) |
|---|---|---|---|
| `BL10E-PS-GADC-01..06`, `SADC-01..05` (door closed sw.) | Position switches on each personnel door and gate — they tell the PLC whether the door is physically shut | **1 = closed** | 0 = open |
| `BL10E-PS-GADL-01/02/04/05`, `SADL-01/02` (lock feedback) | Switches on the lock bolts — they confirm a door is *actually* locked, not just that the PLC asked for it | 1 = locked-confirmed | 0 = not locked |
| `BL10E-PS-KEY-01/02/03` (enable keys) | Physical key-switches the responsible person turns to allow a search / let the source be energised | **1 = on** | 0 = off |
| `BL10E-PS-SCR-01` (search card) | Card reader at the door — presenting a valid search card is what starts the search | 1 = card in | 0 = out |
| `BL10E-PS-BOB-01..08 :A and :B` (beam-off, dual ch.) | Emergency "beam-off" buttons in and around the hutch; each has two separate wired channels (`:A`, `:B`) for safety | **1 = not pressed** | 0 = pressed |
| `BL10E-PS-ASB-01..04`, `ASBF-01` (search buttons) | Area-search pushbuttons pressed in a set order during the walk-through; `ASBF` is the final one by the exit door | 0 = idle | pulse 0→1 = press |
| `BL10E-PS-LCRx-01` (light curtain) | An invisible infra-red "curtain" across the entrance that detects a person stepping through | 1 = clear | 0 = interrupted |
| `BL10E-PS-OR-01` (Open/Reset PB) | The "Open / Reset" button the operator presses to unlock the doors and reset the system once the source is proven off | 0 = idle | pulse 0→1 |
| `BL10E-PS-IT/VT-0x_TRIP` (BOOL — see §0.4!) | Trip flags from the electron-source **current** (IT) and **voltage** (VT) transmitters; 1 means the source is electrically live | **force 0** = source dead | force 1 = current/voltage present |
| `BL10E-PS-OXMON-0x_TRIP` (BOOL — see §0.4!) | Trip flags from the four hutch **oxygen** monitors; 1 means oxygen has dropped too low (suffocation risk) | **force 0** = O₂ healthy | force 1 = O₂ low |
| `BL10E-PS-RDMND/RDMNR-01/02` (radiation) | The two radiation monitors: accumulated **dose** (RDMND) and **dose rate** (RDMNR) | healthy | trip value → SIF-09 |
| `BL10E-PS-IOC-01-BOB/RDMN/GAS/SYS:RESET` | Control-room reset buttons — one each for the beam-off, radiation, gas and system latches | 0 | pulse 0→1 = reset |
| OUTPUT `BL10E-PS-CON-0x:EN` | The PLC's command to a power-contactor coil that feeds the electron source / RF — i.e. switches the hazard ON | — | **1 = energised (hazard live)**, 0 = safe |
| OUTPUT `BL10E-PS-SOL-01..06` (locks) | The PLC's command to a door/gate lock solenoid (the bolt that locks the door) | — | **1 = locked**, 0 = unlocked |

### 0.4 Critical: the analogue setpoints are fail-safe CONSTANTS
The as-built values (Global Variables, verified in the export) are:

| Variable | Initial value | Block | Effect as exported |
|---|---|---|---|
| `OXMON-01..04_SP` | **25.0** | `X_LimL` (trips below) | top-of-range ⇒ oxygen trip **always active** |
| `IT-01..03_SP`, `VT-01..03_SP` | **0.0** | `X_LimH` (trips above) | zero ⇒ "source present" **always active** |
| all `…_HYST` | 0.2 | — | — |

Two consequences:
1. **They are deliberately fail-safe placeholders** — until commissioning sets
   real values, the analogue functions sit in their tripped (safe) state.
2. **They are declared `Constant`** in the variable table — so in offline
   simulation **you cannot force `_SP`/`_HYST` at runtime.** Forcing the field
   value (e.g. `IT-01 = 3.9`) can therefore NEVER clear these trips (3.9 > 0.0).

**Practical choices for offline simulation:**
* **Option A (recommended, no code change):** leave the values alone and
  **force the `_TRIP` BOOLs directly** — `OXMON-01..04_TRIP = 0`,
  `IT-01..03_TRIP = 0`, `VT-01..03_TRIP = 0` for healthy; set individual ones
  to 1 to simulate a trip. Forcing overrides the POU's write, so the SIF logic
  downstream behaves exactly as designed. (You lose only the limit-block
  internals, which Option B covers.)
* **Option B (to exercise the X_LimH/X_LimL blocks themselves):** edit the
  `_SP` **initial values** in the global-variable editor (e.g. `OXMON_SP =
  19.5`, `IT/VT_SP = 6.0`), regenerate code, restart the simulation — then
  field-value forcing works as in §2.1. Revert afterwards; on a real system
  this is a controlled modification.

### 0.5 Concept: the timers run on the simulation clock
`MAX_SEARCH_TIME = 180 s`, six per-step windows `5 s…60 s`, `BEAM_DELAY = 180 s`,
`DOOR_UNLOCK_DELAY = 20 s`, `LIGHT_CURTAIN_DELAY = 2 s`, `RESET_DELAY = 60 s`,
alarm dwell `E_SOURCE_TIME = 120 s`. In offline sim these elapse in (simulated)
real time — between search steps **wait ≥5 s and <60 s**.

**In plain words — what each timer is for.** Think of each one as a stopwatch the
safety PLC uses so things can't happen too fast or too slow:

| Timer | Value | What it does, in everyday terms |
|---|---|---|
| `MAX_SEARCH_TIME` | 180 s (3 min) | The whole hutch search must be finished within 3 minutes, or it cancels and you start again. |
| per-step window | 5–60 s | Between each search button you must wait **at least 5 seconds** (so nobody can rush or "tailgate" the search) but **no more than 60 seconds** (so you can't wander off half-way). |
| `BEAM_DELAY` | 180 s (3 min) | Once the search is done, the system waits 3 minutes — with warning sirens and lights ("radiation imminent") — before it will switch the beam on, giving anyone still inside time to hit a beam-off button. |
| `DOOR_UNLOCK_DELAY` | 20 s | After the source reads zero, the PLC waits 20 seconds to be sure it is *really* off before it lets you unlock the doors. |
| `LIGHT_CURTAIN_DELAY` | 2 s | A short 2-second pause after someone steps through the doorway before the light curtain starts watching for extra people. |
| `RESET_DELAY` | 60 s (1 min) | A one-minute wait before the system settles back to the fully "Open" state. |
| `E_SOURCE_TIME` | 120 s (2 min) | How long the source must stay switched off before the alarm screen accepts it as truly dead. |

---

## 1 · Baseline (run before every test block)

**Concept.** Every test must start from a known-good plant: all doors shut, keys
in, nothing pressed, process values healthy. The program shows this as
`STATUS-OPEN_READY = 1` ("ready to start a search").

**Force TRUE (1):** `GADC-01..06`, `SADC-01..05`, `KEY-01`, `KEY-02`, `KEY-03`,
all sixteen `BOB-0x:A`/`:B`, `LCRx-01`.
**Force FALSE (0):** `ASB-01..04`, `ASBF-01`, `SCR-01`, `OR-01`,
`GADL-01/02/04/05`, `SADL-01/02` (locks not yet engaged), radiation
`RDMND/RDMNR-01/02` healthy.
**Force the analogue trip flags FALSE (0)** — per §0.4 Option A (the `_SP`
constants make value-forcing ineffective): `OXMON-01..04_TRIP = 0`,
`IT-01..03_TRIP = 0`, `VT-01..03_TRIP = 0`.
*(Option B users: with edited setpoints, force `IT/VT-0x = 3.9` and
`OXMON-0x = 20.9` instead.)*
**Pulse once:** `…-BOB:RESET`, `…-RDMN:RESET`, `…-GAS:RESET` (clear power-up latches).

**Expect:** `STATUS-OPEN_READY = 1`; `ANNOPN-01:A/:B = 1`; every `CON-0x:EN = 0`;
every `SOL-0x = 0`; all `BL10E-SIF-0x_TRIP` at their healthy value (mostly 1).

---

## 2 · Input-layer logic (how a field signal becomes a trip)

### 2.1 Concept: analogue channel → limit block → `_TRIP` flag
Each 4–20 mA input (oxygen, current, voltage) is scaled (`X_Hx_AI`, p.588) and
fed to a limit block — `X_LimH` (p.507) trips **above** its setpoint (current,
voltage), `X_LimL` (p.514) trips **below** it (oxygen). Each block has a
setpoint `…_SP`, hysteresis `…_HYST`, a trip delay `DT`, and produces the BOOL
`…_TRIP`. The channel also publishes `_OC`/`_SC`/`_CH_OK` (open/short-circuit,
channel-OK) diagnostics.

> **This test requires §0.4 Option B** (the `_SP` values are `Constant` — they
> cannot be forced). Edit the initial values in the global-variable editor
> (`OXMON-01_SP = 19.5`, `IT-01_SP = 6.0` for this test), regenerate code and
> restart the simulation first. If you stay on Option A, skip Test 2.1 — the
> SIF-level behaviour is fully covered by forcing `_TRIP` in §3.

**Test 2.1** — open `Analogue Inputs` logic (pp.184–187), with edited setpoints:
| Step | Force | Watch / expect |
|---|---|---|
| 1 | `OXMON-01 = 20.9` | `OXMON-01_TRIP = 0` |
| 2 | `OXMON-01 = 18.0` | `OXMON-01_TRIP → 1` (low trip) |
| 3 | `OXMON-01 = 19.6` (just above SP 19.5) | stays tripped until SP+HYST cleared — **hysteresis** |
| 4 | `IT-01 = 12.0` | `IT-01_TRIP → 1` (high trip) |

**What it proves:** you can trace any analogue from raw value to its `_TRIP`
flag, and you understand setpoint + hysteresis.

### 2.2 Concept: dual-channel digital inputs and discrepancy
Safety pushbuttons (BOB) and indicators are **two independent channels** `:A`
and `:B`, AND'd so a single wiring fault cannot fake a healthy button. A
`2In_Discrepency_Alarm` (def. pp.152–156; instantiated in `Alarms`, pp.171–174)
raises an alarm if `:A ≠ :B` for longer than its delay — that is a **fault**,
not a trip.

**Test 2.2:** force `BOB-05:A = 0` while `BOB-05:B = 1`.
**Expect:** `SIF-08_TRIP` behaviour per design (single-channel demand is still a
demand — watch it live), **and** the BOB-05 discrepancy alarm in `Alarms`
(p.171). Restore both to 1, reset. **What it proves:** channel-fault detection
is separate from the trip function.

---

## 3 · The SIF tests (concept + logic + test, one by one)

> Re-establish §1 between tests. Page references are the logic pages.

### SIF-01 — General Access Door (p.291)
**Concept.** If the main personnel door is open, the electron source must be
isolated — radiation must never coexist with an open door. Three independent
closed-switches on the door vote **2oo3**: one broken/misaligned switch must not
spuriously kill the beam (availability), two open switches must (safety).
**Logic as built.** `X_2oo3_B(GADC-01,02,03).Out & BL10E-SIF-07_OUTPUT →
BL10E-SIF-01_TRIP` (a **permissive**: 1 = healthy). The voter (p.644) sums the
three BOOLs and outputs TRUE when ≥2 are TRUE; its `Dev` pin flags channel
disagreement after delay `DT`.
**Test.** From BEAM_ON (§4 walkthrough) or baseline:
| Step | Force | Expect |
|---|---|---|
| 1 | `GADC-01 = 0` | voter `Out` stays 1 — **no trip** (2oo3 tolerates one); after `DT`, voter `Dev` flags discrepancy |
| 2 | `GADC-02 = 0` | voter `Out → 0`, `SIF-01_TRIP → 0`; **`CON-01/02/03:EN → 0`** (and `CON-10:EN`, same latch group, p.267) |
| 3 | restore both = 1 | contactors **stay 0** — see §5 latch test |

### SIF-13 — General Access Gate (p.382)
**Concept.** Rev 4.0 split the gate from the door so each has its own function;
the gate isolates the **RF** path with a deliberate **200 ms** delay (ride-through
for switch bounce on a moving gate).
**Logic.** `X_2oo3_B(GADC-04,05,06) & SIF-07_OUTPUT → SIF-13_TRIP`.
**Test.** `GADC-04 = 0` (no trip) then `GADC-05 = 0` → `SIF-13_TRIP → 0`; after
~200 ms **`CON-06/07/08:EN → 0`** (and `CON-09:EN`, same group, p.267).

### SIF-02 — Service Access Door (p.297)
**Concept.** The service door is a second personnel entry with its own switch
sets: a 2oo3 triple **plus** a 1oo2 pair (different door leaf), OR'd — either
voted-open isolates the source.
**Logic.** `(X_2oo3_B(SADC-01,02,03) & SADC-04 & SADC-05) & SIF-07_OUTPUT →
SIF-02_TRIP`, also publishes `SERVICE_DOOR_CLOSED`.
**Test A (2oo3):** `SADC-01 = 0`, then `SADC-02 = 0` → trip → `CON-01/02/03 → 0`.
**Test B (1oo2):** baseline, then **only** `SADC-04 = 0` → trips alone.

### SIF-03 — Current & Voltage monitoring / door-unlock permit (p.303)
**Concept.** Doors may only unlock when the source is **provably dead**. "Dead"
is measured two independent ways — **current** (IT) and **voltage** (VT), each
2oo3 — and must hold for **20 s** (`DOOR_UNLOCK_DELAY`) before the Open/Reset
button is even enabled. Then a deliberate human action (`OR-01`) opens up. This
prevents unlocking on a momentary dip or a single faulty transmitter.
**Logic.** Two voters `X_2oo3_B(IT-01..03_TRIP)`, `X_2oo3_B_1(VT-01..03_TRIP)`,
RS latch, `TON(PT = T#20s)`, `R_TRIG(OR-01)`, `OR-01:LED` = "press me now" lamp
→ `BL10E-SIF-03_OUTPUT`.
**Test.**
| Step | Force (Option A: the `_TRIP` flags) | Expect |
|---|---|---|
| 1 | `IT-01_TRIP = 1`, `IT-02_TRIP = 1` | current voted present (2oo3) → locks `SOL-0x` held 1, `OR-01:LED = 0` |
| 2 | `IT-01_TRIP = 0`, `IT-02_TRIP = 0`, wait <20 s | `OR-01:LED` still 0 (20 s confirm running) |
| 3 | wait ≥20 s | `OR-01:LED → 1` |
| 4 | pulse `OR-01` | `SIF-03_OUTPUT` permits unlock; SFC heads to OPEN (60 s `RESET_DELAY`) |
| 5 | **repeat 1–4 with `VT-01_TRIP/VT-02_TRIP`** | identical behaviour via the voltage voter |

*(Option B users: drive the same steps with field values instead —
`IT-0x = 12.0` for present, `3.9` for dead — after editing the setpoints.)*

### SIF-05 — Search Start permissive (p.344)
**Concept.** A search may only begin when one authorised person (card + both
keys) starts it with the service doors already shut and no beam-off latched.
Every condition is a hard gate — remove any one and the search must refuse to
start. This is your **negative-test** set.
**Logic.** `SCR-01 & KEY-01 & KEY-02 & SADC-04 & SADC-05 & X_2oo3_B(SADC-01..03)
& SIF-08_TRIP → SIF-05_START` (single AND gate — beautifully readable on p.344).
**Test.** From baseline, for each row force the one item, then `SCR-01 = 1`:
| Blocked by | Force | Expect |
|---|---|---|
| (control) nothing | just `SCR-01 = 1` | `SIF-05_START → 1`, `STATUS-START_SEARCH → 1` ✔ |
| key 1 out | `KEY-01 = 0` | `SIF-05_START` stays 0 — no search |
| key 2 out | `KEY-02 = 0` | stays 0 |
| service door open | `SADC-04 = 0` | stays 0 |
| BOB latched | press+release a BOB, no reset | stays 0 until `…BOB:RESET` pulsed |

### SIF-06 — Search Complete proof (p.350)
**Concept.** The final search button only counts if **every** general door and
gate is shut at that instant — otherwise someone could still slip in.
**Logic.** `X_2oo3_B(GADC-01..03) & X_2oo3_B_1(GADC-04..06) → SIF-06_TRIP`
(+ `GENERAL_ACCESS_DOOR_CLOSED`, and `SIF-06_OUTPUT` which sets the door-lock
solenoid latch in `Logic` p.267).
**Test.** During the walkthrough (§4) at step ASB4: force `GADC-01 = 0` and
`GADC-02 = 0`, pulse `ASBF-01` → **T7 refused** (`SIF-06_TRIP = 0`, no STANDBY).
Close the doors, pulse `ASBF-01` again → STANDBY.

### SIF-07 — Beam-On permissive / lock feedback + 180 s (p.356)
**Concept.** Locked doors must be **proven**, not assumed: the *feedback*
switches on each lock (not the command) gate the beam permit, and a **180 s**
"radiation imminent" dwell (`BEAM_DELAY_TIMER`) gives anyone inside a last
chance to hit a beam-off button. Command ≠ confirmation — core safety idea.
**Logic.** `GADL-01 & GADL-02 & GADL-05 & GADL-04 & SADL-01 & SADL-02 &
SIF-06_TRIP/_OUTPUT → TON(BEAM_DELAY_TIMER_TIME = 180 s) + RS →
BEAM_DELAY_TIMER_END / SIF-07_OUTPUT`.
**Test (positive).** In §4 after T7: force the six feedbacks
`GADL-01/02/04/05, SADL-01/02 = 1` (simulating the mechanisms), wait 180 s →
`BEAM_DELAY_TIMER_END → 1`, `SIF-07_OUTPUT → 1`.
**Test (negative).** Repeat the walkthrough but **leave `SADL-02 = 0`** (one
lock fails to engage). Expect: `SIF-07_OUTPUT` stays 0, **no BEAM_ON ever** —
this is the test v1 of this document was missing.

### SIF-08 — Beam-Off Buttons (p.363)
**Concept.** The emergency stop. Eight dual-channel buttons, **any one** (1oo7)
kills source *and* RF (two independent hazard paths = "defence in depth") and
unlocks the doors so people can escape. It **latches**: releasing the button
must never restart a hazard — only a deliberate, separate reset may clear it.
**Logic.** Per button `:A & :B`; all buttons into an `RS` latch;
reset = `…-BOB:RESET`; output `SIF-08_TRIP` (permissive).
**Test.**
| Step | Force | Expect |
|---|---|---|
| 1 | `BOB-03:A = 0` and `BOB-03:B = 0` | `SIF-08_TRIP → 0`; `CON-01,02,03,06,07,08,09,10:EN → 0`; locks `SOL-0x → 0` (instant escape unlock, C&E footnote a) |
| 2 | restore both = 1 | `SIF-08_TRIP` **stays 0** (latched) |
| 3 | pulse `…-BOB:RESET` | `SIF-08_TRIP → 1` (hazard still off — needs new search) |
| 4 | repeat for buttons 1,2,4,5,6,7,8 | each alone trips (1oo7) |

### SIF-09 — Radiation monitors (p.368)
**Concept.** Two independent monitors, each giving **accumulated dose** (RDMND)
and **dose-rate** (RDMNR) signals; **1oo2** because a real radiation alarm must
never be out-voted. Latched, with its own reset, so a transient can't self-clear.
**Logic.** `(RDMND-01, RDMNR-01, RDMND-02, RDMNR-02)` → 1oo2 gating → RS latch,
reset `…-RDMN:RESET` → `SIF-09_TRIP`.
**Test.** Force `RDMND-01` to trip → `SIF-09_TRIP → 0` → `CON-01/02/03 → 0`
(+ `CON-10`, latch group). Restore; still tripped; pulse `…-RDMN:RESET` →
clears. Repeat with `RDMNR-01`, `RDMND-02`, `RDMNR-02`.

### SIF-10 — Electron-Source Enable Key (p.372)
**Concept.** A physical key (kept by the responsible person) is the
authorisation to have the source/RF energisable at all. 1oo1 — no voting, the
key is the law. A returned key is **not** a reset.
**Logic.** `KEY-03 → SIF-10_TRIP`; gates `CON-04/05` (with `SIF-08`) and the RF
group (p.267).
**Test.** From BEAM_ON: `KEY-03 = 0` → `SIF-10_TRIP → 0` → `CON-04/05:EN → 0`
(watch which RF contactors follow on p.267). `KEY-03 = 1` → hazard stays off;
recover only via new search.

### SIF-11 — Oxygen monitoring (p.377)
**Concept.** Cryogenic nitrogen can displace air; **any one** of four monitors
reading low (1oo4 — maximum sensitivity, people pass out without warning) closes
the LN₂ supply valve and drives the O₂ alarm state. Latched + own reset.
**Logic.** `OXMON-01..04_TRIP` → ≥1 → RS latch, reset `…-GAS:RESET` →
`SIF-11_TRIP` → `SDVLN2`, O₂ beacons (`SP01/02-04..07`), indicators.
**Test (Option A).** `OXMON-02_TRIP = 1` → `SDVLN2 → 0` (valve shut), O₂
beacons to alarm. `OXMON-02_TRIP = 0` → still latched. Pulse `…-GAS:RESET` →
clears. Repeat each monitor (1oo4). *(Option B: use `OXMON-02 = 18.0` / `20.9`
after editing the setpoint.)*

---

## 4 · The search walkthrough (SIF-04 SFC, pp.326–338) — full pass to BEAM_ON

**Concept.** The SFC is the choreography that proves "nobody inside": one person
sweeps the hutch pressing buttons in a fixed deep-to-door order. **Two timing
layers** police it: the overall 180 s `MAX_SEARCH_TIME`, and per-step
`Transition_Timer`s (p.285) with `Min 5 s / Max 60 s` — too fast means you
didn't actually look (or two people are gaming it), too slow means lost control
of the area. The light curtain counts entries: exactly one pass in, then any
further beam break during T2–T6 aborts.

**Watch list:** `STATUS-OPEN_READY/-START_SEARCH/-HUTCH_ENTERED/-ASB1..4/`
`-STANDBY/-BEAM_ON`, `SEARCHED_AND_LOCKED`, `SEARCH_TIMER_RUNNING`,
`SEARCH_TIME_EXCEEDED`, `LIGHT_CURTAIN_MONITORING`, `BEAM_DELAY_TIMER_END`,
`ABORT_SEARCH`, `Tx-Ty_TIMER_TRIP_LOW/HIGH`, `SIF-05_START`, `SIF-06_TRIP`,
`SIF-07_OUTPUT`.

| # | You force | State advances to | Also watch |
|---|---|---|---|
| 0 | §1 baseline | `STATUS-OPEN_READY = 1` | — |
| T1 | `SCR-01 = 1` | `START_SEARCH` | `SIF-05_START → 1`; `SOL-05/06 → 1` (service locks); **force `SADL-01/02 = 1`** (feedback follows); `ANNRES = 1`; 180 s timer runs |
| — | wait ≥5 s | — | `T1-T2_TIMER` running |
| T2 | pulse `LCRx-01: 1→0→1` | `HUTCH_ENTERED` | after 2 s `LIGHT_CURTAIN_MONITORING → 1` |
| — | wait ≥5 s | — | — |
| T3 | pulse `ASB-01: 0→1→0` | `ASB1` | `ASB-01:LED = 1` |
| — | wait ≥5 s | — | — |
| T4 | pulse `ASB-02` | `ASB2` | `ASB-02:LED = 1` |
| — | wait ≥5 s | — | — |
| T5 | pulse `ASB-03` | `ASB3` | `ASB-03:LED = 1` |
| — | wait ≥5 s | — | — |
| T6 | pulse `ASB-04` | `ASB4` | `ASB-04:LED = 1`; LC monitoring ends |
| — | wait ≥5 s | — | — |
| T7 | pulse `ASBF-01` (needs `SIF-06_TRIP = 1`) | `STANDBY` | `SOL-01..04 → 1`; **force `GADL-01/02/04/05 = 1`** ← *without this the sequence stalls here*; `ANNSTB = 1`; `BLUEL-0x = 1`; `SEARCHED_AND_LOCKED → 1`; beacon SP02 |
| — | wait 180 s | — | `BEAM_DELAY_TIMER_END → 1`, `SIF-07_OUTPUT → 1` |
| T8 | (transition fires) | `BEAM_ON` | `ANNBON = 1`; `BONI-01:A/:B = 1`; **`CON-0x:EN → 1`**; white lights pulse (`TP T#1s`, p.337); `KEY-01:SOL` releases |

### 4.1 Abort tests (each must land in an `*_ABORTED` path / back toward OPEN)

| Abort | Provoke | Watch |
|---|---|---|
| Out of order | at `START_SEARCH` pulse `ASB-01` before `LCRx` | `ABORT_SEARCH → 1` |
| Too fast | next step <5 s after previous | that `Tx-Ty_TIMER_TRIP_LOW → 1` → abort |
| Too slow | sit in a step >60 s | `Tx-Ty_TIMER_TRIP_HIGH → 1` → abort |
| Whole search >180 s | dawdle overall | `SEARCH_TIME_EXCEEDED → 1` → abort |
| Light curtain re-break | during T3..T6 pulse `LCRx-01 = 0` | abort while `LIGHT_CURTAIN_MONITORING = 1` |
| Key pulled mid-search | `KEY-01 = 0` (or KEY-02) before T7 | abort |
| Door mid-search | `GADC-01 = 0` + `GADC-02 = 0` | abort |
| Door at the final button | doors open at ASB4, pulse `ASBF-01` | T7 refused (`SIF-06_TRIP = 0`) |

### 4.2 KEY-01 release behaviour (C&E footnote k / p.337)
**Concept.** KEY-01 is trapped (solenoid) during the search; at **BEAM_ON** the
program releases it so it can be carried to the rack position (KEY-03). Removing
it *before* the search completes must abort; removing it *after* release must not.
**Test.** (a) Mid-search `KEY-01 = 0` → abort (done in 4.1). (b) Reach BEAM_ON,
watch `KEY-01:SOL → 0` (released).

---

## 5 · The no-silent-restart latch (`Logic` p.267) — the most important test

**Concept.** After any trip, clearing the cause must **not** re-energise the
hazard. The contactor logic AND's the SIF permissives with
`SEARCHED_AND_LOCKED & STATUS-BEAM_ON` through **RS latches**. The page carries
this exact comment:

> *"If Search and Locked is broken, contactors 01, 02, 03, 06, 07, 08, 09 & 10
> can not start again when tripped without going through a new search sequence."*

Verified groupings (p.267):
| Latch group | Contactors | Gated by |
|---|---|---|
| Source group | **CON-01, 02, 03, 10** | `SIF-08 & SIF-01 & SIF-02 & SIF-09` + `SEARCHED_AND_LOCKED & STATUS-BEAM_ON` |
| Gate/RF group | **CON-06, 07, 08, 09** | `SIF-13` (+ customer interlock `CUST-01` path) |
| Key group | **CON-04, 05** | `SIF-10 & SIF-08` |
| Door locks | `SOL-01..06` | set by `R_TRIG(SIF-06_OUTPUT)` (T1: service / T7: general), reset by `STATUS-OPEN` **or** SIF-08 trip |

**Test.** Reach BEAM_ON → trip anything (e.g. one BOB) → clear it → reset →
**confirm every contactor in the latch groups stays 0** → only a complete new
§4 walkthrough re-energises. Do this once with a door trip and once with a BOB
trip.

---

## 6 · The alarm/diagnostic layer (pp.162–174) — monitoring, not tripping

**Concept.** Around the SIFs sits a non-tripping layer that tells the operator
*why* something happened: per-channel `_ALARM` flags (e.g. `IT-0x_TRIP` through
a `TOF` with `E_SOURCE_TIME = 120 s`, p.172), dual/triple-channel
**discrepancy alarms** (pp.171, 173–174), and system diagnostics (PSU/fan/
switch faults on DI-007, forcing-active flags, module errors — `Diagnostics`
pp.241–250). These drive annunciation only.
**Test (sample).** Force `IT-01 = 12` for >120 s → `IT-01_ALARM` sets; restore →
alarm clears after the TOF. Force `GADC-01 = 0` alone for > voter `DT` →
`X_2oo3_B.Dev` discrepancy flag (door switch disagreement = maintenance alarm).

---

## 7 · Coverage matrix (tick when done)

| # | Logic under test | Where | Concept proven |
|---|---|---|---|
| 2.1 | Analogue channel → `_TRIP` | pp.184–187 | scaling, setpoint, hysteresis |
| 2.2 | Dual-channel + discrepancy | pp.152–161, 171–174 | channel fault ≠ trip |
| 3 | SIF-01 door | p.291 | 2oo3 voting |
| 3 | SIF-13 gate | p.382 | 2oo3 + 200 ms |
| 3 | SIF-02 service door | p.297 | 2oo3 OR 1oo2 |
| 3 | SIF-03 IT+VT unlock permit | p.303 | 2×2oo3, 20 s confirm, manual OR |
| 3 | SIF-05 start permissive (5 negatives) | p.344 | AND-gate authorisation |
| 3 | SIF-06 search-complete proof | p.350 | doors closed at T7 |
| 3 | SIF-07 lock feedback + 180 s (pos+neg) | p.356 | command ≠ confirmation |
| 3 | SIF-08 BOB ×8 | p.363 | 1oo7, latch, escape unlock |
| 3 | SIF-09 radiation ×4 signals | p.368 | 1oo2, latch |
| 3 | SIF-10 key | p.372 | 1oo1, key ≠ reset |
| 3 | SIF-11 oxygen ×4 | p.377 | 1oo4, latch |
| 4 | Full SFC T1→T8 | pp.326–338 | the search choreography |
| 4.1 | 8 abort cases | pp.328–331 | both timing layers + monitors |
| 4.2 | KEY-01 trap/release | p.337 | search integrity |
| 5 | No-silent-restart latches | p.267 | the master safety property |
| 6 | Alarm layer | pp.162–174 | diagnosis vs protection |

## 8 · Known limits / honest notes
* The analogue setpoints are **fail-safe constants** (`OXMON_SP = 25.0`,
  `IT/VT_SP = 0.0`) — they cannot be forced; see §0.4 for the two ways to test
  around them. The illustrative commissioning values used in the companion docs
  (19.5 %O₂, >4 mA) come from the C&E, not from the program.
* A few exact pin polarities are hard to read from the flattened export (e.g.
  inverter bubbles): **trust the live values in simulation**, that's what it's for.
* The SRS (`TDI-PSS-SRS-0002`) and SIF drawing (`Dwg 1224211`) are not in the
  repo; for plant work reconcile against them (e.g. C&E note says 12 s where the
  program implements `DOOR_UNLOCK_DELAY = 20 s`).

## 9 · Test record template
```
Test ref (matrix #): ____  Page: ____  Date: ____  Engineer: ____
Baseline OK (STATUS-OPEN_READY=1)?  Y / N
Setpoints forced (_SP values): ______________________________
Forced (tag = value): _______________________________________
Intermediate (tag : observed): ______________________________
Output (tag : observed): ____________________________________
Latched? reset used: ____________  New search needed?  Y / N
PASS / FAIL: ____  Notes: ___________________________________
```
