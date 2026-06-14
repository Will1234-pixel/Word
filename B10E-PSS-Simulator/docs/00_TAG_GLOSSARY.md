# 0 · Tag glossary — what every signal name means

*Read this first, then keep it open. In the safety PLC every wire and signal has
a short code called a **tag**. This page explains, in plain English, what each
tag is and what its 1/0 value means. The other documents use these same tags and
repeat a short description each time — this page is the full list.*

**Two words you need:**
* **Input** = a signal coming *into* the PLC from a switch, button or sensor.
* **Output** = a signal the PLC *sends out* to switch something on or off.
* **`1` (TRUE)** = the signal is on / present. **`0` (FALSE)** = off / absent.
* **De-energise to trip** = the *safe* state is OFF. If power is lost, the device
  springs to its safe position by itself.

---

## A. Inputs — the doors and gates (position switches)

| Tag | What it is | `1` means | `0` means |
|---|---|---|---|
| `BL10E-PS-GADC-01`, `-02`, `-03` | Three "closed" switches on the **main personnel door** ("General Access Door Closed") | door is shut | door is open |
| `BL10E-PS-GADC-04`, `-05`, `-06` | Three "closed" switches on the **entrance gate** ("General Access Gate Closed") | gate is shut | gate is open |
| `BL10E-PS-SADC-01`…`-05` | "Closed" switches on the **service / maintenance door** ("Service Access Door Closed") | door is shut | door is open |
| `BL10E-PS-GADL-01`, `-02`, `-04`, `-05` | "Locked" switches that feel the **bolt** of the main door / gate ("General Access Door Locked") | door/gate is locked | not locked |
| `BL10E-PS-SADL-01`, `-02` | "Locked" switches that feel the bolt of the **service door** ("Service Access Door Locked") | door is locked | not locked |

## B. Inputs — keys, card and buttons

| Tag | What it is | `1` / action |
|---|---|---|
| `BL10E-PS-KEY-01` | **Electron-source enable key** at the control panel (ZCP) | `1` = key turned ON |
| `BL10E-PS-KEY-02` | **Hutch enable key** (needed to start a search) | `1` = key turned ON |
| `BL10E-PS-KEY-03` | **Electron-source enable key** at the equipment rack | `1` = key turned ON |
| `BL10E-PS-SCR-01` | **Search card reader** at the door | `1` = valid search card presented |
| `BL10E-PS-BOB-01:A`/`:B` … `BOB-08:A`/`:B` | The eight **Beam-Off Buttons** (emergency stop). Each button has **two** wires, channel `:A` and channel `:B`, for safety | `1` = button NOT pressed; `0` = pressed |
| `BL10E-PS-ASB-01`, `-02`, `-03`, `-04` | **Area-search buttons** pressed in order while walking through the hutch | a press = value goes `0`→`1` |
| `BL10E-PS-ASBF-01` | The **final** area-search button, next to the exit door | a press = `0`→`1` |
| `BL10E-PS-LCRx-01` | **Light curtain** beam across the doorway (detects a person passing) | `1` = clear; `0` = beam broken |
| `BL10E-PS-OR-01` | The **Open / Reset** button the operator presses to unlock and reset | a press = `0`→`1` |
| `BL10E-PS-IOC-01-BOB:RESET` | Control-room **reset button** for the beam-off-button latch | a press = `0`→`1` |
| `BL10E-PS-IOC-01-RDMN:RESET` | Control-room reset button for the **radiation** latch | a press = `0`→`1` |
| `BL10E-PS-IOC-01-GAS:RESET` | Control-room reset button for the **oxygen/gas** latch | a press = `0`→`1` |
| `BL10E-PS-IOC-01-SYS:RESET` | Control-room reset button for **general system** latches | a press = `0`→`1` |

## C. Inputs — the analogue sensors (they send a 4–20 mA signal)

| Tag | What it is |
|---|---|
| `BL10E-PS-IT-01`, `-02`, `-03` | **Current transmitters** on the electron source (lines L1/L2/L3). A high reading means the source is electrically live |
| `BL10E-PS-VT-01`, `-02`, `-03` | **Voltage transmitters** on the electron source (L1/L2/L3). High = source live |
| `BL10E-PS-OXMON-01`…`-04` | **Oxygen monitors** in the hutch. A low reading means the air is unsafe to breathe |
| `BL10E-PS-RDMND-01`, `-02` | **Radiation monitors** — accumulated **dose** |
| `BL10E-PS-RDMNR-01`, `-02` | **Radiation monitors** — dose **rate** |

Each analogue sensor has three helper tags:
* `…_SP` = the **set-point** (the level at which it trips).
* `…_HYST` = the **hysteresis** (a small dead-band so it doesn't flicker on/off).
* `…_TRIP` = the **trip flag** the PLC makes from the sensor: `1` = the limit has
  been crossed (oxygen too low, or source live), `0` = normal.
* `…_OC` / `…_SC` / `…_CH_OK` = wiring health (open-circuit / short-circuit / channel OK).

## D. Internal signals — the Safety Functions (SIFs)

Each safety function makes one main signal. **Important:** most of these are
"permissives" — **`1` = healthy / allowed**, and they drop to **`0` to trip**.

| Tag | What it is | `1` means |
|---|---|---|
| `BL10E-SIF-01_TRIP` | Main personnel **door** function | door is shut, OK to run |
| `BL10E-SIF-02_TRIP` | **Service door** function | service door shut, OK |
| `BL10E-SIF-03_OUTPUT` | "Source is **really off**, doors may unlock" permit | safe to unlock |
| `BL10E-SIF-05_START` | **Search-start** permit (card + keys + doors) | a search may begin |
| `BL10E-SIF-06_TRIP` / `_OUTPUT` | **Search-complete** proof (all doors shut) | search may finish |
| `BL10E-SIF-07_OUTPUT` | **Beam-on** master permit (locks confirmed + 180 s wait) | beam may come on |
| `BL10E-SIF-08_TRIP` | **Beam-off-button** function | no button pressed, OK |
| `BL10E-SIF-09_TRIP` | **Radiation** function | radiation normal, OK |
| `BL10E-SIF-10_TRIP` | **Enable-key** function | key on, OK |
| `BL10E-SIF-11_TRIP` | **Oxygen** function | oxygen OK |
| `BL10E-SIF-13_TRIP` | **Gate** function | gate shut, OK |

## E. Internal signals — the search "state" and its timers

| Tag | What it is |
|---|---|
| `STATUS-OPEN` / `STATUS-OPEN_READY` | The hutch is **open** (safe to enter) / **ready** to start a search |
| `STATUS-START_SEARCH` | A search has **begun** |
| `STATUS-HUTCH_ENTERED` | The searcher has **stepped through** the light curtain |
| `STATUS-ASB1` … `STATUS-ASB4` | Area-search buttons 1–4 have been **pressed in order** |
| `STATUS-STANDBY` | Search **done**, doors locked, waiting before beam |
| `STATUS-BEAM_ON` | The hazard (beam) is **on** |
| `SEARCHED_AND_LOCKED` | A memory bit: "search finished and doors locked." If broken, you must search again |
| `SEARCH_TIMER_RUNNING` / `SEARCH_TIME_EXCEEDED` | The overall **180-second** search clock is running / has run out |
| `LIGHT_CURTAIN_MONITORING` | The light curtain is being **watched** for extra people |
| `BEAM_DELAY_TIMER_END` / `_ELAPSED` | The **180-second** "radiation imminent" warning wait has finished |
| `ABORT_SEARCH` / `ABORT_START` | The search has been **cancelled** |
| `T1-T2_TIMER_TRIP_LOW` / `_HIGH` (and T2-T3 … T6-T7) | A step was done **too fast** (`LOW`, under 5 s) or **too slow** (`HIGH`, over 60 s) |

## F. Outputs — the things the PLC switches (all "de-energise to trip")

| Tag | What it is | `1` (energised) | `0` (safe) |
|---|---|---|---|
| `BL10E-PS-CON-01:EN` … `CON-05:EN` | **Power contactors** feeding the **electron source** | source powered (hazard live) | source isolated |
| `BL10E-PS-CON-06:EN`, `-07`, `-08` | **Power contactors** for the **3-phase RF** supply | RF powered | RF isolated |
| `BL10E-PS-CON-09:EN`, `-10` | **Power contactors** for the **1-phase RF drive** | RF drive powered | isolated |
| `BL10E-PS-CON-0x:FB` | **Feedback** wire from each contactor (an aux contact telling the PLC its real state) | (mirrors the contactor) | — |
| `BL10E-PS-SOL-01` … `SOL-06` | **Lock solenoids** — the bolts that lock the doors/gate | door locked | door unlocked |
| `BL10E-PS-ANNOPN-01:A`/`:B` | Hutch sign: **"OPEN"** (dual channel A/B) | sign lit | off |
| `BL10E-PS-ANNRES-01:A`/`:B` | Hutch sign: **"RESTRICTED"** | sign lit | off |
| `BL10E-PS-ANNSTB-01:A`/`:B` | Hutch sign: **"STANDBY"** | sign lit | off |
| `BL10E-PS-ANNBON-01:A`/`:B` | Hutch sign: **"BEAM ON"** | sign lit | off |
| `BL10E-PS-SP01-0x` / `SP02-0x` / `SP03-0x` | **Beacons / sounders** (warning lights and sirens) | sounding | off |
| `BL10E-PS-BLUEL-01:A`/`:B` … `BLUEL-06` | **Blue warning lights** (radiation deterrent) | on | off |
| `BL10E-PS-BONI-01:A`/`:B` | **"Beam On" indicator** lamp | on | off |
| `BL10E-PS-BOBI-01:A`/`:B` … `BOBI-05` | **"Press Beam Off" indicators** | on | off |
| `BL10E-PS-SDVLN2` (valve `SOVLN2-01`) | **Liquid-nitrogen shut-off valve** | valve open (gas can flow) | valve closed (safe) |
| `BL10E-PS-SOVLN2-01:OP` / `:CL` | Valve **position feedback**: open switch / closed switch | that position reached | — |
| `BL10E-PS-IND-01`, `-02`, `-03` | **Oxygen traffic-light indicators** (green/red) | green (air OK) | red (oxygen low) |
| `BL10E-PS-WLT-01` | **White lights** inside the hutch | on | off |
| `BL10E-PS-KEY-01:SOL` / `KEY-02:SOL` | **Key-trap solenoids** that hold a key in place | key trapped | key released |

---

*Tip: when you see a tag in any document, the first part `BL10E-PS-` just means
"Beamline 10E – Personnel Safety". The middle part is the device (e.g. `GADC` =
General Access Door Closed), and the number is which one.*
