# 3 · Test procedure — every step

*A functional-test walkthrough of the B10E PSS, written so a junior engineer can
follow it exactly. Each test states: **purpose → setup → action → expected
result**, and gives the **simulator commands** so you can rehearse it before ever
touching real plant.*

> **Two kinds of "test" — don't mix them up**
> * **Functional / proof test (this document):** prove each Safety Function does
>   what the Cause & Effect matrix says (right cause → right effect). That is what
>   the simulator reproduces.
> * **Hardware service test:** measuring 24 V/5 V rails, checking crimps, fans,
>   earth, module seating, etc. That is a *separate*, generic HIMA field-service
>   checklist and is **not** part of this project's logic. (An old generic copy of
>   that form was in the repo's history and has been removed.)

> **Golden rule for real plant:** only do these on a system that has been
> **formally taken out of service / under a permit to work**, with the beam
> interlock isolated as your site procedure requires. Tripping a live safety
> function on a running machine is never a "quick check".

---

## 3.0 Before you start (every test)

1. Record the starting state: in the simulator type `state`; on real plant, read
   and **save the diagnostic/event list** first (before you touch anything).
2. Confirm the **healthy** baseline: all doors closed, keys IN, no latched trips,
   annunciator **OPEN/OPEN_READY**.
   ```
   python3 pss_cli.py
   pss> state          # expect HUTCH STATE: OPEN_READY, all contactors off (safe), no TRIPS
   ```
3. Know your **reset**: each latched function has its own reset button
   (`reset BOB`, `reset RDMN`, `reset GAS`, `reset OR`).

---

## TEST 1 — SIF-08 Beam-Off Buttons (1oo7 emergency stop)

**Purpose:** any single beam-off button must remove the beam, and the trip must
**latch** until reset.

**Setup:** get to BEAM_ON.
```
pss> search                 # macro: full valid search + beam enable -> BEAM_ON
pss> state                  # confirm: CON01-05 ON, annunciator BEAM ON
```
**Action & expected result:**
| Step | Action | Expected |
|---|---|---|
| 1 | `bob 3` (press beam-off button 3) | **all** electron-source CON01-05 **and** RF CON06-10 go **off**; state leaves BEAM_ON; `TRIPS: SIF-08 ... (latched)` |
| 2 | `bob 3 up` (release the button) | contactors **stay off** (latched) — releasing does not restart the hazard |
| 3 | `reset BOB` | latch clears (`latch=off`) |
| 4 | repeat for buttons 1–8 | each one alone must trip (1oo7) |

**Why it matters:** this is the operator's emergency stop; it must work from any
one of the 8 stations and must never auto-restart.

---

## TEST 2 — SIF-01 General Access Door (2oo3)

**Purpose:** opening the general door with beam on isolates the source; and prove
the **2oo3** voting (1 switch alone must NOT trip — that would be a nuisance trip).

**Setup:** `search` → BEAM_ON.

| Step | Action | Expected |
|---|---|---|
| 1 | `door GADC01 open` | **no trip** — only 1 of 3 switches (2oo3 tolerates one) |
| 2 | `door GADC02 open` | now 2 of 3 → **CON01-03 off**, drops out of BEAM_ON, `SEARCHED_AND_LOCKED` latch broken |
| 3 | `door GADC01 close` + `door GADC02 close` | doors closed again, but beam does **not** come back — you must run a **new search** |
| 4 | `search` | beam returns only after a fresh, valid search |

**Real-plant note:** the 2oo3 means one failed/disconnected door switch will not
shut the beamline down on its own (availability) — but two will (safety).

---

## TEST 3 — SIF-13 General Access Gate (2oo3, 200 ms)

**Purpose:** the gate is split from the door (Rev 4 of the C&E) and drops the RF
contactors CON06-08 with a 200 ms delay.

**Setup:** `search` → BEAM_ON.

| Step | Action | Expected |
|---|---|---|
| 1 | `door GADC04 open` | 1 of 3 gate switches — no trip |
| 2 | `door GADC05 open` | 2oo3 gate → **CON06-08 off** (RF power) |

---

## TEST 4 — SIF-02 Service Access Door (2oo3 + 1oo2)

**Setup:** `search` → BEAM_ON.

| Step | Action | Expected |
|---|---|---|
| 1 | `door SADC01 open` then `door SADC02 open` | group C 2oo3 → source contactors off |
| 2 | reset by closing + new `search`; then `door SADC04 open` | group D is **1oo2** — this single one trips |

---

## TEST 5 — SIF-09 Radiation Monitors (1oo2, latched)

**Purpose:** a high radiation reading removes the hazard and latches.

**Setup:** `search` → BEAM_ON.

| Step | Action | Expected |
|---|---|---|
| 1 | `bob` … no — use the radiation monitor: open the CLI and set demand via `state`; in this build use the door/analog commands. For RDMN, use the scenario or `python3 -c` snippet below. | — |

Run it directly:
```
python3 -c "from pss_sim import *; p=PSS();
import scenarios as s; s.do_full_search(p);
p.demand['RDMN01']=True; p.scan();
print('CON01 =', p.outputs()['CON01'], '(expect False)');
print('latched =', p.latch_rdmn, '(expect True)')"
```
Expected: `CON01 = False`, `latched = True`. Clear with `reset RDMN` (after the
monitor returns to normal). 1oo2: either monitor alone trips.

---

## TEST 6 — SIF-11 Oxygen Depletion (1oo4)

**Purpose:** any one oxygen monitor reading low closes the LN₂ valve and raises
the O₂ alarm.

**Setup:** any state (this function is independent of the search).

| Step | Action | Expected |
|---|---|---|
| 1 | `ai OXMON02 18` (monitor 2 reads 18 % O₂, below 19.5 %) | **LN2 valve CLOSES** (`SDVLN2 off`); O₂ traffic-lights **RED**; alarm beacon |
| 2 | `ai OXMON02 20.9` (restore) then `reset GAS` | valve re-opens, lights green |
| 3 | try each of OXMON01–04 | any one alone trips (1oo4) |

---

## TEST 7 — SIF-03 Radiation-present door interlock (2oo3, 20 s, Open/Reset)

**Purpose:** you must not be able to unlock the doors while the source is still
energised; and even after it reads zero there is a **20 s confirm** and an
**Open/Reset** button press before doors release.

| Step | Action | Expected |
|---|---|---|
| 1 | `ai IT01 12` then `ai IT02 12` | 2oo3 current "present" → `radiation_present = YES`; door locks **held ON** |
| 2 | `ai IT01 3` `ai IT02 3` (back to ~0) then `wait 5` | Open/Reset LED still **off** (only 5 s of the 20 s confirm) |
| 3 | `wait 20` | Open/Reset LED comes **ON** (source confirmed zero for ≥20 s) |
| 4 | `reset OR` | doors may now unlock; hutch returns toward OPEN |

---

## TEST 8 — SIF-10 Electron-Source Enable Key

| Step | Action | Expected |
|---|---|---|
| 1 | `search` → BEAM_ON | RF contactors CON06-10 ON |
| 2 | `key KEY03 off` | SIF-10 → RF/source isolation (`key_off` trip) |
| 3 | `key KEY03 on` | does **not** auto-restart — a key is not a reset; run a new `search` |

---

## TEST 9 — The SEARCH itself (SIF-04/05/06)

This is Test of the sequence and its interlocks. Work through
`02_SEARCH_SEQUENCE.md §2.6`. Specifically prove each abort:

| Case | How to provoke | Expected |
|---|---|---|
| Wrong order | `card`, `wait 10`, `asb1` (before `lcrx`) | ABORT "out-of-order" |
| Too fast | `card`, `wait 2`, `lcrx` | ABORT "too fast (<5s)" |
| Too slow | `card`, `wait 70`, `lcrx` | ABORT "too slow (>60s)" |
| Door during search | `card`, `wait 10`, `lcrx`, `door GADC01 open`… GADC02 | ABORT "door opened/hazard during search" |
| Can't declare searched with door open | run to ASB4, `door GADC01 open`+GADC02, `asbf` | ASBF refused / aborts (SIF-06 not satisfied) |

---

## 3.x Test record template

For each test, record:

```
SIF / Test no.: ____    Date: ____    Engineer: ____
Pre-state recorded?  Y / N
Cause applied:        ___________________________
Expected effect:      ___________________________
Observed effect:      ___________________________
Latched? reset OK?    Y / N
PASS / FAIL:          ____      Notes: __________
```

Run the whole functional set automatically at any time with:
```
python3 scenarios.py     # 7 scenarios, PASS/FAIL each, must be 7/7
```
