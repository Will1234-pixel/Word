# 1 · The system, and how to read the Cause & Effect matrix

*Audience: a junior technical-support engineer who has not seen this system before.*

---

## 1.1 What is being protected, and from what

B10E "HeXI" is a **synchrotron beamline**. Part of it is a shielded room called a
**hutch**. Inside the hutch there are hazards that can **kill or seriously harm**
a person:

* **Ionising radiation** from the electron source / X-ray beam,
* **RF (radio-frequency) power**,
* **Oxygen depletion / asphyxiation** (cryogenic gases such as liquid nitrogen).

The **Personnel Safety System (PSS)** is an independent safety PLC whose entire
purpose is one idea:

> **A person and the hazard must never be in the hutch at the same time.**

It enforces this two ways:
1. **Before** the hazard is turned on, a person must physically **walk through and
   "search" the hutch** to prove nobody is inside, then lock the doors. This is
   the **search sequence** (see `02_SEARCH_SEQUENCE.md`).
2. **While** the hazard is on, if *anything* unsafe happens (a door opens, a
   beam-off button is pressed, radiation is detected outside limits, oxygen
   drops), the system **removes the hazard within milliseconds** by de-energising
   power contactors.

It is rated **SIL 2** (Safety Integrity Level 2 — a measure of how trustworthy the
protection must be, from IEC 61508/61511).

---

## 1.2 The two halves of every safety function: CAUSE and EFFECT

Every safety system can be read as a list of:

* **Causes** — the *inputs*: sensors, buttons, switches. A cause is either
  **healthy** or **in demand** (asking for protection). Examples: a door-closed
  switch (demand = door open), a beam-off button (demand = pressed), an oxygen
  monitor (demand = O₂ low).
* **Effects** — the *outputs*: the things the PLC switches. Examples: a power
  contactor (a big relay that feeds the hazard), a door-lock solenoid, a lamp, a
  siren.

The **Cause & Effect (C&E) matrix** is simply a big grid: causes down the side,
effects across the top, and a mark where "this cause makes that effect go to its
safe state". This project's C&E follows **BS EN IEC 62881**.

### Fail-safe / "de-energise to trip"

Almost every effect here is **de-energise to trip**. That means:

> **OFF = SAFE.** Power contactor *open* (hazard isolated), door solenoid
> *de-energised* (door unlocked so people can get out), valve *closed*.

So if a wire breaks or the PLC loses power, everything falls to the safe state.
In the simulator, an output shown as `ON`/energised means *the hazard is enabled*
or *the door is locked*; `off` means *safe*.

---

## 1.3 Voting — "how many sensors must agree before we act"

Safety sensors are duplicated so that **one faulty sensor cannot** (a) cause a
dangerous failure, nor (b) cause a nuisance trip. The notation is **NooM**
("N out of M"): trip when **N** of the **M** sensors in the group agree.

| Voting | Meaning | Used here for |
|---|---|---|
| **2oo3** | 2 of 3 must agree to trip — tolerates 1 failed sensor | doors (GADC/SADC), current & voltage transmitters |
| **1oo2** | 1 of 2 trips | service door pair, radiation monitors |
| **1oo4** | any 1 of 4 trips (very sensitive) | oxygen monitors |
| **1oo7/1oo8** | any 1 button trips | beam-off buttons |
| **1oo1** | single channel | enable keys |

The simulator implements all of these in one tiny function — see `vote()` in
`pss_sim.py`. Try it: in the CLI, `ai IT01 12` then `ai IT02 12` — one transmitter
high does nothing, the second one (2 of 3) declares "radiation present".

---

## 1.4 The causes in this system (the inputs)

Grouped the way the C&E groups them (the letter is the C&E "Group" column):

| Group | Cause tags | What it senses | Voting | Drives |
|---|---|---|---|---|
| A | GADC01-03 | General Access **Door** closed | 2oo3 | SIF-01 |
| B | GADC04-06 | General Access **Gate** closed | 2oo3 | SIF-13 |
| C | SADC01-03 | Service Access Door closed | 2oo3 | SIF-02/05 |
| D | SADC04-05 | Service Access Door closed (2nd) | 1oo2 | SIF-02/05 |
| E | IT01-03 | Electron-source **current** present | 2oo3 | SIF-03 |
| F | VT01-03 | Electron-source **voltage** present | 2oo3 | SIF-03 |
| H | OXMON01-04 | **Oxygen** depletion | 1oo4 | SIF-11 |
| J | BOB01-08 | **Beam-Off Buttons** (dual-channel) | 1oo7 | SIF-08 |
| K | RDMN01-02 | **Radiation** monitors (dose + rate) | 1oo2 | SIF-09 |
| — | KEY01/02/03 | Enable **key switches** | 1oo1 | SIF-05/10 |
| — | SCR, LCRx, ASB01-04, ASBF | Search devices (card, light-curtain, buttons) | sequence | SIF-04/05/06 |

## 1.5 The effects in this system (the outputs)

| Effect tags | What it is | Safe state |
|---|---|---|
| CON01-05 | Electron-source power contactors | open (isolated) |
| CON06-08 | 3-phase RF power contactors | open |
| CON09-10 | 1-phase RF drive contactors | open |
| GADL01-04, SADL01-02 (SOL-01..06) | Door/gate **lock** solenoids | unlocked |
| ANNOPN/ANNRES/ANNSTD/ANNBON | Hutch status **annunciator** sign | off |
| SP01/SP02/SP03 | Speaker/beacon programs (caution/deterrent/alarm) | off |
| BLUEL01-04 (-06) | **Blue lights** (radiation deterrent) | off |
| BONI / BOBI01-04 | "Beam On" / "Press Beam Off" indicators | off |
| SDVLN2 | Liquid-nitrogen shut-off valve | closed |
| IND01-03 | O₂ / toxic-gas traffic-light indicators | red |

## 1.6 The 12 Safety Instrumented Functions (SIFs)

A **SIF** is one self-contained protective function. The PLC has **12**
(SIF-01…11 and SIF-13 — there is no SIF-12 in the PLC; the C&E lists the oxygen
function as "SIF 11 & 12"). One-line summary of each:

| SIF | Protects against | Cause → Effect |
|---|---|---|
| 01 | someone opening the **general door** with beam on | GADC 2oo3 → drop CON01-03 |
| 02 | someone opening the **service door** | SADC 2oo3/1oo2 → drop CON01-03 |
| 03 | unlocking doors while **radiation still present** | IT/VT 2oo3 → keep locks ON until source reads 0 for 20 s + Open/Reset |
| 04 | **the search itself** (the SFC state machine) | sequence → status flags |
| 05 | starting a search without authority | card + keys + doors → permit T1 |
| 06 | declaring "searched" with a door open | GADC + gate 2oo3 → permit T7 |
| 07 | turning beam on before locks confirmed | lock feedback + 180 s → beam permit |
| 08 | **emergency stop** — any beam-off button | BOB 1oo7 → drop CON01-03,06-10 |
| 09 | **radiation** detected high | RDMN 1oo2 → drop CON01-03,09 |
| 10 | RF enabled without the **enable key** | KEY03 → drop CON06-10 |
| 11 | **oxygen depletion** | OXMON 1oo4 → close LN2 valve, alarm |
| 13 | someone opening the **gate** | GADC gate 2oo3 → drop CON06-08 (200 ms) |

The exact gate logic, latching and timers are in `04_PROGRAM_LOGIC_REFERENCE.md`.

---

### Try it now
```
python3 pss_cli.py
pss> ai OXMON02 18        # one oxygen monitor reads 18% (< 19.5 trip)  -> SIF-11
pss> state                # LN2 valve CLOSES, O2 lights go RED
pss> reset GAS            # clear it (after O2 restored)
```
