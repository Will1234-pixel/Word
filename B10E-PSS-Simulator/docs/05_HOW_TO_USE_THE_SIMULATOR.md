# 5 · How to use the simulator

*No installation. Pure Python 3 standard library. Nothing connects to real plant.*

---

## 5.1 The three programs

| Command | What it does |
|---|---|
| `python3 scenarios.py` | Runs 7 worked examples as a **self-test** (PASS/FAIL). Run this first — if it is 7/7, the model matches the Cause & Effect matrix. |
| `python3 pss_cli.py` | **Interactive** — you type commands, it shows the live state. This is the one you'll use to learn and to rehearse the test procedure. |
| `pss_sim.py` | The **engine** (imported by the other two). Read it to see the logic in ~350 commented lines. |

## 5.2 Reading the status panel

After every command the CLI prints a panel. Top line = **HUTCH STATE** (the SFC
step) with the search/step timers. Then:

* **inputs:** card, keys, beam request; the open-vote counts for each door group
  (e.g. `Gen DOOR (grp A 2oo3) open-votes 1/3`); current/voltage votes →
  `radiation_present`; oxygen/BOB/RDMN counts and latch state.
* **outputs (ON = energised):** e-source contactors `C01..C05`, RF `C06..C10`,
  door locks, annunciator sign, blue lights/indicators, beacons, LN₂ valve, O₂
  lights, and the Open/Reset LED.

Remember **ON = energised**: for a contactor that means *hazard powered*; for a
lock it means *door locked*; lowercase/`off` = the safe state.

If something has tripped, a red **TRIPS:** line lists the reasons. If a search
was aborted, a yellow **last abort:** line tells you why.

## 5.3 Command reference

| Command | Example | Meaning |
|---|---|---|
| `search` | `search` | auto-run a full valid search → BEAM_ON (does the waits for you) |
| `card` / `start` | `card` | insert the search card (begins T1 if keys/doors OK) |
| `lcrx` | `lcrx` | light-curtain single pass-through (T2) |
| `asb1`…`asb4` | `asb1` | press an area-search button (T3…T6) |
| `asbf` | `asbf` | final search button (T7 → STANDBY) |
| `enable` | `enable` | operator "enable beam" request (needed for T8) |
| `wait <s>` | `wait 10` | let time pass — needed between search steps (≥5 s) |
| `door <tag> open\|close` | `door GADC01 open` | move a door switch (GADC01-06, SADC01-05) |
| `bob <n> [up]` | `bob 3` / `bob 3 up` | press/release beam-off button n (1-8) |
| `key <K> on\|off` | `key KEY03 off` | turn an enable key (KEY01/02/03) |
| `ai <tag> <val>` | `ai OXMON02 18` | set an analogue input (OXMON01-04, IT01-03, VT01-03) |
| `lc` | `lc` | extra light-curtain interrupt (aborts a monitored search) |
| `reset <R>` | `reset BOB` | press a reset PB (BOB / RDMN / GAS / OR) |
| `state` | `state` | reprint the panel |
| `log` | `log` | last 15 internal events (advances/aborts) |
| `help` / `quit` | | help / exit |

## 5.4 Five things to try (10 minutes)

1. **Happy path:** `search` → watch it reach BEAM_ON with contactors energised.
2. **E-stop & latch:** from BEAM_ON, `bob 1` (everything trips), `bob 1 up`
   (stays tripped), `reset BOB`, then `search` again to recover.
3. **2oo3 voting:** from BEAM_ON, `door GADC01 open` (no trip), `door GADC02
   open` (trips). One switch is tolerated, two are not.
4. **Oxygen:** `ai OXMON03 17` → LN₂ valve closes, O₂ lights red; `ai OXMON03
   20.9` + `reset GAS` to clear.
5. **Break a search:** `card`, `wait 2`, `lcrx` → aborts "too fast"; or `card`,
   `wait 10`, `asb1` → aborts "out-of-order".

## 5.5 Changing the data

Everything the engine knows lives in `data/cause_effect.json`:
* setpoints (e.g. oxygen 19.5 %, current/voltage 4 mA),
* voting schemes per group,
* the timing constants,
* which causes/effects belong to which SIF.

Edit that file and re-run `scenarios.py` — no code change needed for setpoints or
voting. The exact PLC values are in `docs/04_PROGRAM_LOGIC_REFERENCE.md §4.6/4.8`.

## 5.6 Honest limits of the model (so you don't over-trust it)

This is a **teaching model of the logic**, not the certified PLC code. In
particular:
* It is a clean state-machine; the real PLC also runs diagnostics, channel
  OC/SC fault handling, discrepancy alarms, and dual-CPU voting that are **not**
  modelled here.
* Analogue behaviour is a simple setpoint compare (no scaling curve / hysteresis
  detail).
* The light-curtain "single pass vs re-interrupt" and the per-step 5–60 s windows
  are modelled in spirit; confirm exact edge-cases against `program.pdf`.
* Timing is event-driven via `wait`/`tick`, not real-time.

For anything that affects real plant, the **C&E matrix, the SRS and `program.pdf`
are the authority** — this simulator is for understanding and rehearsal.
