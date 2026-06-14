# 2 · The hutch SEARCH sequence (T1 → T7 → Beam On)

*This is the heart of the system. It is SIF-04, implemented in the PLC as a
Sequential Function Chart (SFC). Read this, then drive it in the simulator.*

---

## 2.1 Why a "search"

Before the radiation/RF hazard can be switched on, a trained person must
physically walk through the whole hutch to confirm **nobody is left inside**, in
a **fixed order**, within **strict time windows**, and then lock the doors behind
them. The PLC only lets the beam on if that exact ritual is completed correctly.
If the searcher does anything wrong — wrong button, too fast, too slow, or a door
opens — the search **aborts** and they must start again.

This defends against the worst case: a person hiding/working in the hutch while a
colleague switches the beam on.

---

## 2.2 The states (what the hutch is doing)

These are the real PLC state names (`STATUS-*` flags), confirmed from
`program.pdf`:

```
 OPEN ──▶ OPEN_READY ──▶ START_SEARCH ──▶ HUTCH_ENTERED ──▶ ASB1 ──▶ ASB2
                            (T1)              (T2)           (T3)     (T4)
                                                                       │
        OPEN ◀── BEAM_ON ◀── STANDBY ◀── ASB4 ◀── ASB3 ◀──────────────┘
        (T9)      (T8)         (T7)       (T6)     (T5)
```

| State | Meaning | Annunciator sign |
|---|---|---|
| OPEN | doors unlocked, anyone may enter, no hazard | **OPEN** |
| OPEN_READY | all doors closed & keys in — ready to start | OPEN |
| START_SEARCH | search begun; service doors lock | **RESTRICTED** |
| HUTCH_ENTERED | searcher passed the light curtain | RESTRICTED |
| ASB1..ASB4 | area-search buttons pressed in order | RESTRICTED |
| STANDBY | search done, **all doors locked**, 180 s warning dwell | **STANDBY** |
| BEAM_ON | hazard enabled | **BEAM ON** |

---

## 2.3 The steps, one at a time

Each transition **Tn** is "the event that moves you to the next state".

| T | From → To | What the searcher does | PLC pre-condition | What happens on arrival |
|---|---|---|---|---|
| **T1** | OPEN_READY → START_SEARCH | Insert search **card** (SCR) and turn **KEY01** (electron-source) and **KEY02** (hutch) to ON | service doors closed (SADC), no beam-off latched (**SIF-05**) | **Service doors lock**; **RESTRICTED** sign; Speaker **SP01** "search in progress"; white lights on; **180 s search timer starts** |
| **T2** | START_SEARCH → HUTCH_ENTERED | Walk through the **light curtain** once (single pass) | — | Light-curtain **monitoring arms** after 2 s |
| **T3** | HUTCH_ENTERED → ASB1 | Press **ASB-01** (deep in the hutch) | light curtain monitored | ASB-01 LED on |
| **T4** | ASB1 → ASB2 | Press **ASB-02** | light curtain monitored | ASB-02 LED on |
| **T5** | ASB2 → ASB3 | Press **ASB-03** | light curtain monitored | ASB-03 LED on |
| **T6** | ASB3 → ASB4 | Press **ASB-04** | — | ASB-04 LED on; **light-curtain monitoring ends** |
| **T7** | ASB4 → STANDBY | Press the **final** button **ASBF** by the door | **all general doors & gate closed (2oo3, SIF-06)** | **General doors/gate lock**; **STANDBY** sign; **blue light on**; Speaker **SP02** "radiation imminent"; beam-off indicators on; **180 s beam-delay starts**; KEY01 released |
| **T8** | STANDBY → BEAM_ON | (operator enables beam) | 180 s elapsed **and** all locks confirmed (**SIF-07**) | **BEAM ON** sign; Beam-On indicator; **contactors energise**; latch `SEARCHED_AND_LOCKED` |
| **T9** | BEAM_ON → OPEN | press a beam-off button, or source confirmed zero (**SIF-03**) | — | returns toward OPEN (60 s reset delay) |

---

## 2.4 The two timers that police the search

The PLC uses **two independent timing systems** (both verified in `program.pdf`):

1. **Overall search timer — `MAX_SEARCH_TIME = 180 s`.** The whole walk
   (START_SEARCH → STANDBY) must finish inside 180 seconds, or it aborts.
2. **Per-step window — `5 s … 60 s` (six `Transition_Timer` blocks).** Each step
   must take **at least 5 s** (you cannot rush / tailgate) and **at most 60 s**
   (you cannot dawdle). Outside that → abort.

So a valid search is: do each step *deliberately* (wait ≥5 s), keep moving
(≤60 s/step), and finish the lot within 180 s.

---

## 2.5 What aborts a search

Any of these throws the SFC into an `*_ABORTED` state and back toward OPEN:

* a **wrong** button (out of order),
* a step done **too fast** (<5 s) or **too slow** (>60 s), or the whole search >180 s,
* the **light curtain** is interrupted again while it is being monitored (T2…T6),
* an **enable key** (KEY01/KEY02) is lost during the search,
* a **door opens** during the search,
* a **beam-off button** is pressed.

---

## 2.6 Drive it in the simulator

The per-step minimum is 5 s, so you must let time pass between presses. The CLI
`search` macro does this for you; or do it by hand to *feel* the timing:

```text
python3 pss_cli.py

pss> card            # T1: insert card (keys are already IN). -> START_SEARCH, RESTRICTED
pss> wait 10         # let 10 s pass (>=5, <=60)
pss> lcrx            # T2 -> HUTCH_ENTERED
pss> wait 10
pss> asb1            # T3 -> ASB1
pss> wait 10
pss> asb2            # T4
pss> wait 10
pss> asb3            # T5
pss> wait 10
pss> asb4            # T6
pss> wait 10
pss> asbf            # T7 -> STANDBY (doors lock, blue light, 'radiation imminent')
pss> enable          # operator beam-enable request
pss> wait 180        # the 180 s 'radiation imminent' dwell
pss> state           # -> BEAM_ON: contactors energised, BEAM ON sign
```

Now try breaking it:
```text
pss> card
pss> wait 2          # only 2 s ...
pss> lcrx            # ... too fast -> ABORT (read the 'last abort' line)

pss> card
pss> wait 10
pss> asb1            # wrong! light curtain (lcrx) expected first -> ABORT
```
