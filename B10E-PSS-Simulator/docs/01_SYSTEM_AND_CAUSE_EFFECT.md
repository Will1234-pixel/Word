# 1 · System, and how to read the Cause & Effect

*This document is the beginner's primer. It explains what the safety system protects against, the idea of "causes" and "effects", what fail-safe means, how voting works, and gives a one-line summary of every safety function (SIF). Read document 00 (the Tag glossary) first, then read this.*

---

## 1.1 What is being protected, and from what

B10E "HeXI" is a **synchrotron beamline** (a machine that makes a very bright X-ray beam). Part of it is a shielded room called a **hutch** (a thick-walled room you can walk into; the walls block radiation). Inside the hutch there are hazards that can **kill or seriously harm** a person:

* **Ionising radiation** from the electron source and X-ray beam,
* **RF (radio-frequency) power** — strong radio energy used to drive the beam,
* **Oxygen depletion / asphyxiation** — cold gases such as liquid nitrogen can push the air out and leave nothing to breathe.

The **Personnel Safety System (PSS)** is an independent safety PLC (a rugged industrial computer that does one job and is kept separate from the normal control system). Its whole purpose is one idea:

> **A person and the hazard must never be in the hutch at the same time.**

It enforces this two ways:

1. **Before** the hazard is turned on, a person must physically **walk through and "search" the hutch** to prove nobody is inside, then lock the doors. This is the **search sequence** (see document 02, The hutch search).
2. **While** the hazard is on, if *anything* unsafe happens (a door opens, a beam-off button is pressed, radiation is detected outside limits, oxygen drops), the system **removes the hazard within milliseconds** by cutting power to the power contactors (the big switches that feed the hazard).

It is rated **SIL 2** (Safety Integrity Level 2 — a grade, from the IEC 61508/61511 standards, that says how trustworthy the protection must be; higher numbers mean more trustworthy).

---

## 1.2 The two halves of every safety function: CAUSE and EFFECT

Every safety system can be read as a list of:

* **Causes** — the *inputs*: sensors, buttons and switches. A cause is either **healthy** or **in demand** (asking for protection). Examples: a door-closed switch (demand = door open), a beam-off button (demand = pressed), an oxygen monitor (demand = oxygen low).
* **Effects** — the *outputs*: the things the PLC switches. Examples: a power contactor (a big relay that feeds the hazard), a door-lock solenoid (the electric bolt that locks a door), a lamp, a siren.

The **Cause & Effect (C&E) matrix** is simply a big grid: causes down the side, effects across the top, and a mark where "this cause makes that effect go to its safe state". This project's C&E follows the **BS EN IEC 62881** standard.

### Fail-safe / "de-energise to trip"

Almost every effect here is **de-energise to trip** (the safe state is OFF — when power is removed, the device springs to safe by itself). That means:

> **OFF = SAFE.** Power contactor *open* (hazard isolated), door solenoid *de-energised* (door unlocked so people can get out), valve *closed*.

So if a wire breaks or the PLC loses power, everything falls to the safe state. When you watch an output in testing, an output shown as `1`/energised means *the hazard is enabled* or *the door is locked*; `0`/off means *safe*.

---

## 1.3 Voting — "how many sensors must agree before we act"

Safety sensors are duplicated so that **one faulty sensor cannot** (a) cause a dangerous failure, nor (b) cause a nuisance trip (an unnecessary shutdown). The notation is **NooM** ("N out of M"): trip when **N** of the **M** sensors in the group agree.

| Voting | Meaning | Used here for |
|---|---|---|
| **2oo3** | 2 of 3 must agree to trip — tolerates 1 failed sensor | doors (`GADC`/`SADC`, the door-closed switches), current and voltage transmitters |
| **1oo2** | any 1 of 2 trips | second service-door switch pair, radiation monitors (`RDMN`) |
| **1oo4** | any 1 of 4 trips (very sensitive) | oxygen monitors (`OXMON`) |
| **1oo7** | any 1 of the beam-off buttons trips | beam-off buttons (`BOB`) |
| **1oo1** | single channel | enable keys (`KEY`) |

Worked example: the radiation-present check uses the current transmitters `BL10E-PS-IT-01..03` (the sensors that show the electron source is electrically live) voted **2oo3**. If only one transmitter reads high, nothing happens. When a second one also reads high, that is 2 of 3, so the PLC declares "source live / radiation present". To see how to drive these signals yourself, follow document 04 (the SILworX offline test procedure).

---

## 1.4 The causes in this system (the inputs)

Grouped the way the C&E groups them (the letter is the C&E "Group" column). Each tag has a short plain-language meaning next to it.

| Group | Cause tags | What it senses | Voting | Drives |
|---|---|---|---|---|
| A | `GADC-01..03` — three closed-switches on the **main personnel door** | main personnel **door** is shut | 2oo3 | SIF-01 |
| B | `GADC-04..06` — three closed-switches on the **entrance gate** | entrance **gate** is shut | 2oo3 | SIF-13 |
| C | `SADC-01..03` — closed-switches on the **service / maintenance door** | service **door** is shut | 2oo3 | SIF-02/05 |
| D | `SADC-04..05` — a second set of closed-switches on the **service door** | service door is shut (2nd set) | 1oo2 | SIF-02/05 |
| E | `IT-01..03` — **current transmitters** on the electron source | electron-source **current** present (source live) | 2oo3 | SIF-03 |
| F | `VT-01..03` — **voltage transmitters** on the electron source | electron-source **voltage** present (source live) | 2oo3 | SIF-03 |
| H | `OXMON-01..04` — **oxygen monitors** in the hutch | **oxygen** has dropped (air unsafe) | 1oo4 | SIF-11 |
| J | `BOB-01..08` — the eight **beam-off buttons** (emergency stop, two wires each) | a beam-off button is **pressed** | 1oo7 | SIF-08 |
| K | `RDMN-01..02` — **radiation monitors** (dose and rate) | **radiation** is high | 1oo2 | SIF-09 |
| — | `KEY-01` — **electron-source enable key** at the control panel (ZCP) | the key is **turned on** | 1oo1 | SIF-05/10 |
| — | `KEY-02` — **hutch enable key** (needed to start a search) | the key is **turned on** | 1oo1 | SIF-05/06 |
| — | `KEY-03` — **electron-source enable key** at the equipment rack | the key is **turned on** | 1oo1 | SIF-10 |
| — | `SCR` (**search card reader**), `LCRx` (**light curtain** across the doorway), `ASB-01..04` (**area-search buttons** pressed in order), `ASBF-01` (the **final** area-search button by the exit) | the steps of walking through and searching the hutch | sequence | SIF-04/05/06 |

## 1.5 The effects in this system (the outputs)

| Effect tags | What it is | Safe state |
|---|---|---|
| `CON-01..05` — **power contactors** feeding the **electron source** | the big switches that power the electron source | open (source isolated) |
| `CON-06..08` — **power contactors** for the **3-phase RF** supply | the big switches that power the RF | open |
| `CON-09..10` — **power contactors** for the **1-phase RF drive** | the switches that power the RF drive | open |
| `GADL-01..04`, `SADL-01..02` (the solenoids `SOL-01..06`) — door/gate **lock solenoids** | the electric bolts that lock the doors and gate | unlocked |
| `ANNOPN` / `ANNRES` / `ANNSTB` / `ANNBON` — hutch status **sign** (Open / Restricted / Standby / Beam On) | the lit sign telling people the hutch state | off |
| `SP01` / `SP02` / `SP03` — **beacons and sounders** (caution / deterrent / alarm) | warning lights and sirens | off |
| `BLUEL-01..06` — **blue warning lights** (radiation deterrent) | blue lights that warn radiation is near | off |
| `BONI` (**"Beam On" indicator**) / `BOBI-01..04` (**"Press Beam Off" indicators**) | lamps showing beam status | off |
| `SDVLN2` (valve `SOVLN2-01`) — **liquid-nitrogen shut-off valve** | the valve that lets liquid nitrogen flow | closed |
| `IND-01..03` — **oxygen traffic-light indicators** (green/red) | the green/red lights showing if the air is safe | red (oxygen low) |

## 1.6 The 12 Safety Instrumented Functions (SIFs)

A **SIF** (Safety Instrumented Function — one self-contained protective job, made of its own sensors, logic and outputs) is one complete piece of protection. The PLC has **12** of them (SIF-01…11 and SIF-13). There is no SIF-12 in the PLC; the C&E sheet lists the oxygen job as "SIF 11 & 12". A few terms used below:

* **permissive** = a signal that means "it is OK to proceed". A permissive is `1` when healthy and drops to `0` to trip.
* **latch** = a memory bit that stays tripped after the cause clears, until someone presses a reset button.
* **SFC** = Sequential Function Chart — a step-by-step program (a state machine) that walks through one stage at a time. The search uses one.

One-line summary of each SIF:

| SIF | Protects against | Cause → Effect |
|---|---|---|
| 01 | someone opening the **main personnel door** while the beam is on | `GADC-01..03` (main-door closed-switches) 2oo3 → open `CON-01..03` (electron-source contactors) |
| 02 | someone opening the **service door** | `SADC` (service-door closed-switches) 2oo3 / 1oo2 → open `CON-01..03` (electron-source contactors) |
| 03 | unlocking the doors while **radiation is still present** | `IT`/`VT` (current/voltage transmitters) 2oo3 → keep the door locks ON until the source reads 0 for 20 s, then Open/Reset is pressed |
| 04 | a fault in **the search itself** (the SFC step machine) | search sequence → `STATUS-` flags (the bits that show which step the search is on) |
| 05 | starting a search without authority | `SCR` (search card) + `KEY` (enable keys) + doors shut → grant the start permit (transition T1) |
| 06 | declaring "searched" while a door is still open | `GADC` (main-door) + gate closed-switches 2oo3 → grant the search-complete permit (transition T7) |
| 07 | turning the beam on before the door locks are confirmed | lock feedback (`GADL`/`SADL` locked-switches) + a 180 s wait → grant the beam-on permit |
| 08 | **emergency stop** — any beam-off button pressed | `BOB-01..08` (beam-off buttons) 1oo7 → open `CON-01..03` and `CON-06..10` (electron-source and RF contactors) |
| 09 | **radiation** detected high | `RDMN-01..02` (radiation monitors) 1oo2 → open `CON-01..03` and `CON-09` |
| 10 | the RF being enabled without the **enable key** | `KEY-03` (electron-source enable key at the rack) → open `CON-06..10` (RF contactors) |
| 11 | **oxygen depletion** (air unsafe to breathe) | `OXMON-01..04` (oxygen monitors) 1oo4 → close the `SDVLN2` liquid-nitrogen valve and raise the alarm |
| 13 | someone opening the **entrance gate** | `GADC-04..06` (gate closed-switches) 2oo3 → open `CON-06..08` (3-phase RF contactors) within 200 ms |

The exact gate logic, latching and timers are in document 03 (the Program logic reference). To drive any of these functions yourself and watch the result, follow document 04 (the SILworX offline test procedure).
