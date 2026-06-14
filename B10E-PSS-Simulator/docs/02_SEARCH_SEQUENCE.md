# 2 · The hutch SEARCH sequence (T1 → T7 → Beam On)

*This document walks you through the search, one step at a time: what the
searcher does, which tag makes each step advance, and what you should see happen
next. It also lists the two timers and the things that abort a search.*

This is the heart of the system. It is SIF-04, built inside the PLC as a
**Sequential Function Chart (SFC)**. An SFC is just a step-by-step state machine:
the program sits in one **state** (one step) at a time, and only moves on when a
**transition** is met. A **transition** is the event — a button, a key, a
timer — that moves you from one step to the next. We label the transitions
**T1, T2, T3 …**.

A **hutch** is the shielded room that holds the hazard. To follow the tag names,
see document 00 (the glossary).

---

## 2.1 Why a "search"

Before the radiation/RF hazard can be switched on, a trained person must
physically walk through the whole hutch to confirm **nobody is left inside**.
They must do it in a **fixed order**, inside **strict time windows**, and then
lock the doors behind them. The PLC only lets the beam on if that exact routine
is done correctly.

If the searcher does anything wrong — wrong button, too fast, too slow, or a door
opens — the search **aborts** and they must start again.

This defends against the worst case: a person hiding or working in the hutch
while a colleague switches the beam on.

---

## 2.2 The states (what the hutch is doing)

These are the real PLC state names. Each is a `STATUS-*` flag that reads `1` when
the hutch is in that state. They come straight from the program (see document
03, the program logic reference).

```
 OPEN ──▶ OPEN_READY ──▶ START_SEARCH ──▶ HUTCH_ENTERED ──▶ ASB1 ──▶ ASB2
                            (T1)              (T2)           (T3)     (T4)
                                                                       │
        OPEN ◀── BEAM_ON ◀── STANDBY ◀── ASB4 ◀── ASB3 ◀──────────────┘
        (T9)      (T8)         (T7)       (T6)     (T5)
```

| State (tag) | Plain meaning | Annunciator sign |
|---|---|---|
| `STATUS-OPEN` | The hutch is **open** and safe to enter. Doors unlocked, no hazard | **OPEN** |
| `STATUS-OPEN_READY` | The hutch is **ready** to start a search: all doors closed and keys in | OPEN |
| `STATUS-START_SEARCH` | A search has **begun**; the service doors lock | **RESTRICTED** |
| `STATUS-HUTCH_ENTERED` | The searcher has **stepped through** the light curtain | RESTRICTED |
| `STATUS-ASB1` … `STATUS-ASB4` | Area-search buttons 1–4 have been **pressed in order** | RESTRICTED |
| `STATUS-STANDBY` | Search **done**, **all doors locked**, waiting before the beam | **STANDBY** |
| `STATUS-BEAM_ON` | The hazard (the beam) is **on** | **BEAM ON** |

---

## 2.3 The steps, one at a time

Read this table top to bottom. Each row is **one** transition **Tn** — the event
that moves the SFC to the next state. For each step you get:
**(a)** what the searcher physically does, **(b)** which tag/condition makes it
advance, and **(c)** what happens and what to see next.

A few tags used below:
* `BL10E-PS-SCR-01` — the **search card reader** at the door. Reads `1` when a
  valid search card is presented.
* `KEY-01` (`BL10E-PS-KEY-01`) — the **electron-source enable key** at the
  control panel. `1` = key turned ON.
* `KEY-02` (`BL10E-PS-KEY-02`) — the **hutch enable key** needed to start a
  search. `1` = key turned ON.
* `LCRx-01` (`BL10E-PS-LCRx-01`) — the **light curtain**, an invisible beam
  across the doorway that detects a person passing. `1` = clear, `0` = broken.
* `ASB-01 … ASB-04` (`BL10E-PS-ASB-01..04`) — the four **area-search buttons**
  you press in order while walking through the hutch. A press = `0`→`1`.
* `ASBF-01` (`BL10E-PS-ASBF-01`) — the **final** area-search button, next to the
  exit door. A press = `0`→`1`.
* `SADC` (`BL10E-PS-SADC-*`) — the **service-door "closed"** switches. `1` = the
  service door is shut.
* `SEARCHED_AND_LOCKED` — a memory bit meaning "search finished and doors
  locked." If it is broken, you must search again.

| T | From → To | (a) What the searcher does | (b) Tag/condition that advances it | (c) What happens / what to see next |
|---|---|---|---|---|
| **T1** | `STATUS-OPEN_READY` → `STATUS-START_SEARCH` | Present the search **card** at `BL10E-PS-SCR-01`, and turn `KEY-01` (electron source) and `KEY-02` (hutch) to ON | Service doors shut (`SADC` = `1`), and no beam-off latched (**SIF-05**, the search-start permit, is healthy) | **Service doors lock**; **RESTRICTED** sign on; speaker `SP01` says "search in progress"; white lights `WLT-01` on; the **180 s search timer starts** |
| **T2** | `STATUS-START_SEARCH` → `STATUS-HUTCH_ENTERED` | Walk through the **light curtain** once — a single pass | `LCRx-01` goes `1`→`0`→`1` (broken, then clear) for one pass | After 2 s the light-curtain monitoring **arms** (`LIGHT_CURTAIN_MONITORING` = `1`): from now on, breaking the beam again will abort |
| **T3** | `STATUS-HUTCH_ENTERED` → `STATUS-ASB1` | Press **`ASB-01`**, deep inside the hutch | `ASB-01` press (`0`→`1`) | `STATUS-ASB1` = `1`; ASB-01 LED on |
| **T4** | `STATUS-ASB1` → `STATUS-ASB2` | Press **`ASB-02`** | `ASB-02` press (`0`→`1`) | `STATUS-ASB2` = `1`; ASB-02 LED on |
| **T5** | `STATUS-ASB2` → `STATUS-ASB3` | Press **`ASB-03`** | `ASB-03` press (`0`→`1`) | `STATUS-ASB3` = `1`; ASB-03 LED on |
| **T6** | `STATUS-ASB3` → `STATUS-ASB4` | Press **`ASB-04`** | `ASB-04` press (`0`→`1`) | `STATUS-ASB4` = `1`; ASB-04 LED on; **light-curtain monitoring ends** (`LIGHT_CURTAIN_MONITORING` = `0`) |
| **T7** | `STATUS-ASB4` → `STATUS-STANDBY` | Press the **final** button **`ASBF-01`** by the exit door, then leave and shut the door | All general doors and the gate closed (2-out-of-3 healthy, **SIF-06**, the search-complete proof) | **General doors and gate lock**; **STANDBY** sign on; **blue lights** on; speaker `SP02` says "radiation imminent"; beam-off indicators on; the **180 s beam-delay starts**; `KEY-01` is released |
| **T8** | `STATUS-STANDBY` → `STATUS-BEAM_ON` | The operator requests beam enable | The 180 s beam delay has elapsed **and** all locks are confirmed (**SIF-07**, the beam-on master permit, is healthy) | **BEAM ON** sign on; Beam-On indicator on; **power contactors energise**; the `SEARCHED_AND_LOCKED` bit latches |
| **T9** | `STATUS-BEAM_ON` → `STATUS-OPEN` | Press a beam-off button, **or** the source is confirmed at zero | A beam-off press, or source-off proven (**SIF-03**, "source is really off, doors may unlock") | The hutch heads back toward **OPEN** (after a 60 s reset delay) |

---

## 2.4 The two timers that police the search

The PLC uses **two independent timing layers**. Both must be satisfied.

1. **Overall search timer — `MAX_SEARCH_TIME = 180 s`.** The whole walk
   (`STATUS-START_SEARCH` → `STATUS-STANDBY`) must finish inside **180 seconds**,
   or it aborts. While it runs, `SEARCH_TIMER_RUNNING` = `1`; if it runs out,
   `SEARCH_TIME_EXCEEDED` = `1`.
2. **Per-step window — `5 s … 60 s`.** There are six step timers (one per step,
   T1-T2 through T6-T7). Each step must take **at least 5 s** — you cannot rush or
   tailgate — and **at most 60 s** — you cannot dawdle. Going under 5 s sets that
   step's `..._TIMER_TRIP_LOW`; going over 60 s sets its `..._TIMER_TRIP_HIGH`.
   Either one aborts the search.

So a valid search is: do each step **deliberately** (wait ≥ 5 s), keep moving
(≤ 60 s per step), and finish the whole thing within 180 s.

---

## 2.5 What aborts a search

Any of these throws the SFC into an `*_ABORTED` state (you will see `ABORT_SEARCH`
or `ABORT_START` go `1`) and sends the hutch back toward `STATUS-OPEN`:

* a **wrong** button — pressed out of order;
* a step done **too fast** (< 5 s) or **too slow** (> 60 s), or the whole search
  taking longer than 180 s;
* the **light curtain** (`LCRx-01`) is broken again while it is being monitored
  (during steps T2 … T6);
* an **enable key** (`KEY-01` or `KEY-02`) is lost during the search;
* a **door opens** during the search;
* a **beam-off button** is pressed.

---

## 2.6 Practising this sequence

You practise this exact sequence in **HIMA SILworX offline simulation**. The
per-step minimum is 5 s, so you must let real time pass between presses. The
precise tags to force and the signals to watch — step by step, including the
abort cases — are written out in **document 04 (the SILworX offline test
procedure)**.
