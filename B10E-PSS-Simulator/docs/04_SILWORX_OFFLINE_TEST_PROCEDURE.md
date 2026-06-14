# 4 · SILworX offline‑simulation test procedure

*This is the main "do this" document. You run it in **HIMA SILworX offline
simulation** (the PLC program running on your PC, with no real hardware). For
each safety function it tells you, in plain steps: which signal to **force** (set
by hand), which signal to **watch**, and what should **happen**. Every tag (signal
name) has a short description; the full list is in document 00 (the tag glossary).*

Everything here comes from the real program file `program.pdf` (project
`C15862H-BL10E`, configuration `BL10E_HeXI [400]`, SILworX v16.0.0 R3326). The
searchable text of all 713 pages is in `data/program_extracted.txt`.

---

## 0 · Set‑up and the rules you must know first

### 0.1 Start the offline simulation
1. Open the project and select the **Resource `BL10E_HeXI [400]`** (the controller).
2. Generate the code, then start **Offline Simulation** on that resource.
3. Open a **logic page** (for example `Library/SIF/B10E-SIF-01`). In simulation the
   wires on the page show live `TRUE`/`FALSE` values, so you can watch the logic work.
4. Open the **Force editor** (or a Watch page). "Forcing" means setting a signal to a
   value by hand. Add the tags listed in each test.

### 0.2 The two big rules
**Rule 1 — you are the field.** In offline simulation there is no real wiring, so a
sensor input just sits at its starting value until *you* force it. Forcing an input
is like operating the real plant.

**A trap that follows from Rule 1 — feedback does not follow outputs.** When the PLC
energises a lock output `BL10E-PS-SOL-01` (the bolt solenoid that locks a door), the
matching feedback input `BL10E-PS-GADL-01` (the switch that senses the bolt is in) does
**not** move by itself. On the real door the bolt moves the switch; in simulation **you
must force the feedback** to copy that. This matters in the search (§4): if you do not
force `BL10E-PS-GADL-…` and `BL10E-PS-SADL-…` (the door‑locked sensing switches) to `1`
after the locks energise, the beam‑on permit `BL10E-SIF-07_OUTPUT` (the master "beam may
come on" signal) never turns on, and the beam never comes on.

**Rule 2 — OFF is the safe state ("de‑energise‑to‑trip").** Almost every output's safe
state is OFF. So for most inputs the **unsafe / "do something" value is `0`**, and many
internal signals are **permissives** — a permissive is `1` when everything is healthy
and drops to `0` to trip. The one exception: the analogue trip flags
`BL10E-PS-IT/VT/OXMON‑0x_TRIP` (the "limit reached" flags from the current, voltage and
oxygen sensors) are the other way round — `1` means a limit was crossed.

### 0.3 Which way to force each signal (polarity)

| Signal (tag) | What it is (the exact device) | Healthy / normal | Unsafe value / action |
|---|---|---|---|
| `BL10E-PS-GADC-01`, `-02`, `-03` | The three "closed" switches on the **main personnel door** | **1 = door shut** | 0 = door open |
| `BL10E-PS-GADC-04`, `-05`, `-06` | The three "closed" switches on the **entrance gate** | **1 = gate shut** | 0 = gate open |
| `BL10E-PS-SADC-01`, `-02`, `-03` | The three "closed" switches on the **service door** (first set, voted 2oo3) | **1 = shut** | 0 = open |
| `BL10E-PS-SADC-04`, `-05` | A second pair of "closed" switches on the **service door** (voted 1oo2) | **1 = shut** | 0 = open |
| `BL10E-PS-GADL-01`, `-02` | The two "locked" switches that sense the **main‑door** bolt | 1 = locked | 0 = not locked |
| `BL10E-PS-GADL-04`, `-05` | The two "locked" switches that sense the **gate** bolt | 1 = locked | 0 = not locked |
| `BL10E-PS-SADL-01`, `-02` | The two "locked" switches that sense the **service‑door** bolt | 1 = locked | 0 = not locked |
| `BL10E-PS-KEY-01` | **Electron‑source enable key** at the control panel (ZCP) | **1 = on** | 0 = off |
| `BL10E-PS-KEY-02` | **Hutch enable key** (the one needed to start a search) | **1 = on** | 0 = off |
| `BL10E-PS-KEY-03` | **Electron‑source enable key** at the equipment rack | **1 = on** | 0 = off |
| `BL10E-PS-SCR-01` | Search‑card reader at the door | 1 = card in | 0 = no card |
| `BL10E-PS-BOB-01:A`/`:B` … `BOB-08:A`/`:B` | The 8 emergency Beam‑Off Buttons; each has two channels `:A` and `:B` | **1 = not pressed** | 0 = pressed |
| `BL10E-PS-ASB-01`, `-02`, `-03`, `-04` | The four area‑search buttons, pressed in order during the walk | 0 = idle | a press = 0→1 |
| `BL10E-PS-ASBF-01` | The **final** area‑search button, by the exit door | 0 = idle | a press = 0→1 |
| `BL10E-PS-LCRx-01` | Light curtain across the doorway | 1 = clear | 0 = beam broken |
| `BL10E-PS-OR-01` | The Open/Reset button | 0 = idle | a press = 0→1 |
| `BL10E-PS-IT-01`, `-02`, `-03_TRIP` (see §0.4) | Trip flags from the source **current** sensors | **force 0** = no current | force 1 = current present |
| `BL10E-PS-VT-01`, `-02`, `-03_TRIP` (see §0.4) | Trip flags from the source **voltage** sensors | **force 0** = no voltage | force 1 = voltage present |
| `BL10E-PS-OXMON-01`…`-04_TRIP` (see §0.4) | Trip flags from the four **oxygen** sensors | **force 0** = air OK | force 1 = oxygen low |
| `BL10E-PS-RDMND-01`, `-02` | Radiation **dose** sensors | healthy | trip value |
| `BL10E-PS-RDMNR-01`, `-02` | Radiation **dose‑rate** sensors | healthy | trip value |
| `BL10E-PS-IOC-01-BOB:RESET` | Control‑room reset for the **beam‑off‑button** latch | 0 = idle | a press = 0→1 |
| `BL10E-PS-IOC-01-RDMN:RESET` | Control‑room reset for the **radiation** latch | 0 = idle | a press = 0→1 |
| `BL10E-PS-IOC-01-GAS:RESET` | Control‑room reset for the **oxygen** latch | 0 = idle | a press = 0→1 |
| `BL10E-PS-IOC-01-SYS:RESET` | Control‑room reset for general **system** latches | 0 = idle | a press = 0→1 |
| OUTPUT `BL10E-PS-CON-01:EN` … `CON-05:EN` | Commands to the contactors feeding the **electron source** | — | **1 = on (hazard live)**, 0 = safe |
| OUTPUT `BL10E-PS-CON-06:EN` … `CON-08:EN` | Commands to the **3‑phase RF** contactors | — | **1 = on**, 0 = safe |
| OUTPUT `BL10E-PS-CON-09:EN`, `CON-10:EN` | Commands to the **1‑phase RF drive** contactors | — | **1 = on**, 0 = safe |
| OUTPUT `BL10E-PS-SOL-01`, `-02` | The bolt solenoids that lock the **main door** | — | **1 = locked**, 0 = unlocked |
| OUTPUT `BL10E-PS-SOL-03`, `-04` | The bolt solenoids that lock the **gate** | — | **1 = locked**, 0 = unlocked |
| OUTPUT `BL10E-PS-SOL-05`, `-06` | The bolt solenoids that lock the **service door** | — | **1 = locked**, 0 = unlocked |

### 0.4 Important: the analogue set‑points are fixed "fail‑safe" numbers
The PLC turns each 4–20 mA sensor into a trip flag using a limit block. The level
at which it trips is a set‑point tag `…_SP`. In this program the as‑built set‑points are:

| Set‑point tag | Value | Block | What it does as shipped |
|---|---|---|---|
| `BL10E-PS-OXMON-01..04_SP` (oxygen trip level) | **25.0** | `X_LimL` (trips when the reading goes **below** the set‑point) | 25 is the top of range, so the oxygen trip is **always active** |
| `BL10E-PS-IT-01..03_SP`, `VT-01..03_SP` (source current/voltage trip level) | **0.0** | `X_LimH` (trips when the reading goes **above** the set‑point) | 0 means "source present" is **always active** |
| all `…_HYST` (the small dead‑band) | 0.2 | — | — |

Two things follow:
1. These are **deliberate fail‑safe placeholders** — until the system is commissioned with
   real numbers, the analogue functions sit in their tripped (safe) state.
2. They are marked **`Constant`**, so in offline simulation **you cannot force `…_SP` or
   `…_HYST`**, and forcing the raw reading (e.g. `BL10E-PS-IT-01 = 3.9`) can never clear the
   trip (3.9 is still above 0.0).

So you have two ways to test the analogue functions:
* **Way A (easy, no code change):** force the **trip flag** directly — set
  `BL10E-PS-OXMON-01..04_TRIP`, `IT-01..03_TRIP`, `VT-01..03_TRIP` (the "limit reached"
  flags) to `0` for healthy, or to `1` to fake a trip. Forcing overrides what the program
  writes, so everything downstream behaves exactly as designed.
* **Way B (to test the limit blocks themselves):** edit the `…_SP` starting values in the
  global‑variable editor (for example `OXMON-01_SP = 19.5`, `IT-01_SP = 6.0`), regenerate
  the code, restart the simulation — now forcing the raw reading works. Put the values back
  afterwards.

### 0.5 The timers run on the simulation clock
The program uses several timers. In offline simulation they count down in real
(simulated) time, so you sometimes have to **wait**.

| Timer (tag) | Value | What it is, in plain words |
|---|---|---|
| `MAX_SEARCH_TIME` | 180 s (3 min) | The whole search must finish within 3 minutes, or it cancels. |
| per‑step window (`T1-T2_TIMER…T6-T7_TIMER`) | 5–60 s | Between each search button: wait **at least 5 s** (so nobody can rush the search) but **no more than 60 s**. |
| `BEAM_DELAY_TIMER_TIME` | 180 s (3 min) | After the search, the system waits 3 minutes (with warning lights/sirens) before the beam may come on. |
| `DOOR_UNLOCK_DELAY` | 20 s | After the source reads zero, wait 20 s to be sure before doors may unlock. |
| `LIGHT_CURTAIN_DELAY` | 2 s | A 2‑second pause after someone enters before the light curtain starts watching for extra people. |
| `RESET_DELAY_TIMER` | 60 s | A 1‑minute wait before the system returns to fully "Open". |
| `E_SOURCE_TIME` | 120 s (2 min) | How long the source must read off before the alarm screen treats it as truly dead. |

### 0.6 Keep a test record
For every test, write down: the starting state, what you forced, what you watched,
what happened, whether it latched (stuck on until reset), and PASS/FAIL. A blank
form is at the end (§9).

---

## 1 · Set the healthy starting point (do this before every test)

**Why:** every test must start from a known, safe plant — all doors shut, keys in,
nothing pressed, sensors healthy. The program shows this as
`STATUS-OPEN_READY = 1` (the "ready to start a search" state).

**Step 1 — force every input to the value in the last column.** Each tag is listed
on its own so you can see exactly what it is.

| Tag | What it is (the exact device) | Force to |
|---|---|---|
| `BL10E-PS-GADC-01`, `-02`, `-03` | The three closed‑switches on the **main personnel door** | **1** (door shut) |
| `BL10E-PS-GADC-04`, `-05`, `-06` | The three closed‑switches on the **entrance gate** | **1** (gate shut) |
| `BL10E-PS-SADC-01`, `-02`, `-03` | The **service door** closed‑switches (first set) | **1** (shut) |
| `BL10E-PS-SADC-04`, `-05` | The **service door** closed‑switches (second set) | **1** (shut) |
| `BL10E-PS-KEY-01` | **Electron‑source enable key** at the control panel (ZCP) | **1** (on) |
| `BL10E-PS-KEY-02` | **Hutch enable key** (needed to start a search) | **1** (on) |
| `BL10E-PS-KEY-03` | **Electron‑source enable key** at the equipment rack | **1** (on) |
| `BL10E-PS-BOB-01:A`/`:B` … `BOB-08:A`/`:B` | All 16 channels of the 8 **beam‑off buttons** | **1** (not pressed) |
| `BL10E-PS-LCRx-01` | The **light curtain** across the doorway | **1** (clear) |
| `BL10E-PS-ASB-01`, `-02`, `-03`, `-04` | The four **area‑search buttons** | **0** (idle) |
| `BL10E-PS-ASBF-01` | The **final** area‑search button | **0** (idle) |
| `BL10E-PS-SCR-01` | The **search‑card reader** | **0** (no card) |
| `BL10E-PS-OR-01` | The **Open/Reset** button | **0** (idle) |
| `BL10E-PS-GADL-01`, `-02` | The **main‑door** "locked" switches (locks not on yet) | **0** (not locked) |
| `BL10E-PS-GADL-04`, `-05` | The **gate** "locked" switches (locks not on yet) | **0** (not locked) |
| `BL10E-PS-SADL-01`, `-02` | The **service‑door** "locked" switches (locks not on yet) | **0** (not locked) |
| `BL10E-PS-RDMND-01`, `-02` | The radiation **dose** sensors | **0** (healthy) |
| `BL10E-PS-RDMNR-01`, `-02` | The radiation **dose‑rate** sensors | **0** (healthy) |
| `BL10E-PS-OXMON-01`…`-04_TRIP` | The four **oxygen** trip flags (Way A, §0.4) | **0** (air OK) |
| `BL10E-PS-IT-01`, `-02`, `-03_TRIP` | The source **current** trip flags (Way A, §0.4) | **0** (no current) |
| `BL10E-PS-VT-01`, `-02`, `-03_TRIP` | The source **voltage** trip flags (Way A, §0.4) | **0** (no voltage) |

*(If you use Way B from §0.4 instead, force the raw readings: `IT-0x = 3.9`,
`VT-0x = 3.9`, `OXMON-0x = 20.9`.)*

**Step 2 — press each control‑room reset once** (force `0`→`1`→`0`) to clear any
latch left from power‑up:

| Tag | What it resets |
|---|---|
| `BL10E-PS-IOC-01-BOB:RESET` | the beam‑off‑button latch |
| `BL10E-PS-IOC-01-RDMN:RESET` | the radiation latch |
| `BL10E-PS-IOC-01-GAS:RESET` | the oxygen latch |

**Step 3 — check you are at the healthy start.** You should see:

| Watch this | Expect | Meaning |
|---|---|---|
| `STATUS-OPEN_READY` | `1` | the hutch is ready to start a search |
| `BL10E-PS-ANNOPN-01:A`/`:B` | `1` | the "OPEN" sign is on |
| `BL10E-PS-CON-01:EN` … `CON-10:EN` | all `0` | every hazard is off |
| `BL10E-PS-SOL-01` … `SOL-06` | all `0` | every door is unlocked |
| `BL10E-SIF-01_TRIP` … `SIF-13_TRIP` | at healthy value (mostly `1`) | every safety function is healthy |

---

## 2 · Input‑layer tests (how a sensor becomes a trip)

### 2.1 An analogue sensor → its trip flag *(needs Way B from §0.4)*
**Idea:** each 4–20 mA sensor reading is compared with its set‑point by a limit
block — `X_LimH` (HIMA's "trip when above" block) for current/voltage,
`X_LimL` ("trip when below") for oxygen — which produces the trip flag `…_TRIP`.

> This test only works if you use **Way B** (edit the set‑points), because the
> set‑points are `Constant`. Set `OXMON-01_SP = 19.5` and `IT-01_SP = 6.0`,
> regenerate, restart. If you stay on Way A, skip this test — the safety‑function
> behaviour is fully covered by forcing `…_TRIP` in §3.

1. Open the `Analogue Inputs` logic (pages 184–187).
2. Force `BL10E-PS-OXMON-01 = 20.9` (a healthy oxygen reading). **Watch**
   `OXMON-01_TRIP = 0`.
3. Force `BL10E-PS-OXMON-01 = 18.0` (below the 19.5 set‑point). **Watch**
   `OXMON-01_TRIP` turn `1` (a low‑oxygen trip).
4. Force `BL10E-PS-OXMON-01 = 19.6` (just above the set‑point). **Watch** that it
   **stays** tripped until the reading clears the set‑point *plus* the dead‑band —
   that is the **hysteresis** at work.
5. Force `BL10E-PS-IT-01 = 12.0` (a high source‑current reading). **Watch**
   `IT-01_TRIP` turn `1` (a high trip).

**Proves:** you can follow any analogue sensor from its raw reading to its trip flag.

### 2.2 Two‑channel inputs and the "discrepancy" alarm
**Idea:** the beam‑off buttons (and some lamps) use **two** wires, `:A` and `:B`,
that are checked against each other so a single broken wire cannot fake a healthy
button. If `:A` and `:B` disagree for too long, a `2In_Discrepency_Alarm` block
raises a **fault** alarm — that is different from a safety **trip**.

1. Force `BL10E-PS-BOB-05:A = 0` (channel A of beam‑off button 5 "pressed") while
   leaving `BL10E-PS-BOB-05:B = 1` (channel B "not pressed").
2. **Watch** the beam‑off function `BL10E-SIF-08_TRIP` (the "no button pressed"
   permissive) behave per design, **and** the BOB‑05 discrepancy alarm appear in
   the `Alarms` logic (page 171).
3. Set both channels back to `1` and reset.

**Proves:** a wiring fault is detected and is handled separately from a real trip.

---

## 3 · Safety‑function (SIF) tests — one at a time

A **SIF** is one independent safety function. Re‑do the §1 starting point between
tests. Each test names the **page** to open, the **tag to force**, the **signal to
watch**, and the **result to expect**.

### SIF‑01 — Main personnel door open → cut the source (page 291)
**What it protects:** if the main door opens, the electron source must switch off —
radiation must never be on with the door open.
**How it is built:** the three door‑closed switches `BL10E-PS-GADC-01/02/03` go into
a **2oo3 voter** (HIMA block `X_2oo3_B`; "2oo3" means at least 2 of the 3 must say
"open" before it counts). The voter output is combined (AND) with the beam‑on permit
`BL10E-SIF-07_OUTPUT` to make `BL10E-SIF-01_TRIP` (a permissive: `1` = door OK).

1. Get to `STATUS-BEAM_ON` (do the §4 search first) or just use the §1 start point.
2. Force `BL10E-PS-GADC-01 = 0` (one door switch says "open"). **Expect:** the voter
   stays healthy and `BL10E-SIF-01_TRIP` stays `1` — **no trip** (2oo3 tolerates one
   switch). After a short delay the voter's `Dev` output flags the disagreement.
3. Also force `BL10E-PS-GADC-02 = 0` (now 2 of 3 say "open"). **Expect:**
   `BL10E-SIF-01_TRIP` turns `0`, and the source contactors `BL10E-PS-CON-01:EN`,
   `CON-02:EN`, `CON-03:EN` (and `CON-10:EN`, same memory group, page 267) turn `0`
   — the source is isolated.
4. Set both switches back to `1`. **Expect:** the contactors **stay** `0` — see the
   memory‑latch test in §5; you must run a fresh search to get the hazard back.

### SIF‑13 — Gate open → cut the RF (page 382)
**What it protects:** the entrance gate is separate from the door; opening it cuts
the RF supply, with a small **200 ms** delay (to ride through switch bounce on a
moving gate).
**How it is built:** the three gate switches `BL10E-PS-GADC-04/05/06` go into a 2oo3
voter, combined with `BL10E-SIF-07_OUTPUT` (beam‑on permit) → `BL10E-SIF-13_TRIP`.

1. Force `BL10E-PS-GADC-04 = 0` (one gate switch open). **Expect:** no trip.
2. Also force `BL10E-PS-GADC-05 = 0` (2 of 3). **Expect:** `BL10E-SIF-13_TRIP` turns
   `0`; after ~200 ms the RF contactors `BL10E-PS-CON-06:EN`, `CON-07:EN`, `CON-08:EN`
   (and `CON-09:EN`, same group) turn `0`.

### SIF‑02 — Service door open → cut the source (page 297)
**What it protects:** the service/maintenance door is a second way in.
**How it is built:** the three service‑door switches `BL10E-PS-SADC-01/02/03` go into
a 2oo3 voter; this is OR‑ed with a 1oo2 pair `BL10E-PS-SADC-04` and `SADC-05` ("1oo2"
means either one is enough). The result, combined with `BL10E-SIF-07_OUTPUT`, makes
`BL10E-SIF-02_TRIP`.

1. **Test the 2oo3 side:** force `BL10E-PS-SADC-01 = 0`, then `SADC-02 = 0`.
   **Expect:** `BL10E-SIF-02_TRIP` turns `0`; source contactors `CON-01/02/03:EN` → `0`.
2. **Test the 1oo2 side:** from the §1 start point, force **only** `BL10E-PS-SADC-04 = 0`.
   **Expect:** it trips on its own (1oo2 needs just one).

### SIF‑03 — "Is the source really off?" / permission to unlock (page 303)
**What it protects:** doors may only unlock once the source is **proven dead** —
measured two ways, current and voltage — and held off for **20 s**, then a person
must press a button. This stops doors unlocking on a brief dip or one faulty sensor.
**How it is built:** a 2oo3 voter on the current trips `BL10E-PS-IT-01/02/03_TRIP`
and another on the voltage trips `BL10E-PS-VT-01/02/03_TRIP`; a memory (RS latch); an
on‑delay timer `DOOR_UNLOCK_DELAY = 20 s`; the Open/Reset button `BL10E-PS-OR-01`;
and a lamp `BL10E-PS-OR-01:LED` ("you may press now") → `BL10E-SIF-03_OUTPUT`.

Using **Way A** (force the trip flags):
1. Force `BL10E-PS-IT-01_TRIP = 1` and `IT-02_TRIP = 1` (2 of 3 current sensors say
   "source live"). **Expect:** "source present" wins, the door locks `SOL-0x` are
   **held on** (`1`), and the lamp `BL10E-PS-OR-01:LED = 0`.
2. Force `IT-01_TRIP = 0` and `IT-02_TRIP = 0` (source now reads zero). Wait **less
   than** 20 s. **Expect:** `OR-01:LED` is still `0` (the 20 s check is running).
3. Wait until **20 s** have passed. **Expect:** `OR-01:LED` turns `1`.
4. Press `BL10E-PS-OR-01` (force `0`→`1`). **Expect:** `BL10E-SIF-03_OUTPUT` allows
   unlocking; the system heads back toward "Open" (after the 60 s `RESET_DELAY_TIMER`).
5. Repeat steps 1–4 using `VT-01_TRIP`/`VT-02_TRIP` (the voltage sensors) — same result.

### SIF‑05 — Permission to start a search (page 344)
**What it protects:** a search may only begin with the right authority, the service
doors shut, and no stop button latched. Each item is a hard condition — remove any
one and the search must refuse to start (these are the **negative tests**).
**How it is built:** an AND of `BL10E-PS-SCR-01` (search card in), `KEY-01` and
`KEY-02` (both enable keys on), the 1oo2 pair `SADC-04` and `SADC-05`, the 2oo3 voter
on `SADC-01/02/03`, and `BL10E-SIF-08_TRIP` (no beam‑off button) → `BL10E-SIF-05_START`.

From the §1 start point, for each row force the listed item, then present the card
`BL10E-PS-SCR-01 = 1`:

| Block this | Force | Expect |
|---|---|---|
| nothing (control) | just `SCR-01 = 1` | `BL10E-SIF-05_START = 1`, then `STATUS-START_SEARCH = 1` — a search starts ✔ |
| key 1 missing | `BL10E-PS-KEY-01 = 0` | `SIF-05_START` stays `0` — no search |
| key 2 missing | `BL10E-PS-KEY-02 = 0` | stays `0` |
| service door open | `BL10E-PS-SADC-04 = 0` | stays `0` |
| beam‑off latched | press+release a beam‑off button without resetting | stays `0` until you press `IOC-01-BOB:RESET` |

### SIF‑06 — Proof the search may finish (page 350)
**What it protects:** the final search button only counts if **every** door and gate
is shut at that moment.
**How it is built:** a 2oo3 voter on `BL10E-PS-GADC-01/02/03` (door) AND a 2oo3 voter
on `GADC-04/05/06` (gate) → `BL10E-SIF-06_TRIP`.

1. During the search (§4), at the `STATUS-ASB4` step, force `BL10E-PS-GADC-01 = 0` and
   `GADC-02 = 0` (open the door). Press `BL10E-PS-ASBF-01` (the final button).
   **Expect:** the final step is **refused** (`BL10E-SIF-06_TRIP = 0`, no `STATUS-STANDBY`).
2. Set the door switches back to `1`, press `ASBF-01` again. **Expect:** now it moves to
   `STATUS-STANDBY`.

### SIF‑07 — Beam‑on permit / proof the locks really engaged (page 356)
**What it protects:** locked doors must be **proven** (by the lock switches, not just
the command), and then a **180 s** "radiation imminent" warning gives anyone inside a
last chance to hit a stop button.
**How it is built:** an AND of the door‑locked switches `BL10E-PS-GADL-01`, `GADL-02`,
`GADL-04`, `GADL-05`, `SADL-01`, `SADL-02`, plus `BL10E-SIF-06_TRIP` (search complete),
feeding a 180 s timer `BEAM_DELAY_TIMER` and a memory → `BEAM_DELAY_TIMER_END` and the
master permit `BL10E-SIF-07_OUTPUT`.

1. **Positive test:** during §4 after the final button, force the six lock switches
   `GADL-01/02/04/05` and `SADL-01/02` to `1` (copying the bolts going in). Wait 180 s.
   **Expect:** `BEAM_DELAY_TIMER_END = 1` and `BL10E-SIF-07_OUTPUT = 1` (beam may come on).
2. **Negative test:** repeat, but leave **`SADL-02 = 0`** (one lock fails to engage).
   **Expect:** `BL10E-SIF-07_OUTPUT` stays `0` and **the beam never comes on**.

### SIF‑08 — Beam‑Off Buttons (emergency stop) (page 363)
**What it protects:** the emergency stop. Pressing **any one** of the 8 buttons (this is
"1oo7" — one out of many) cuts **both** the source and the RF, and unlocks the doors so
people can get out. It **latches** (stays tripped): releasing the button must never
restart the hazard — only a separate reset clears it.
**How it is built:** each button's two channels `BOB-0x:A` and `BOB-0x:B` are AND‑ed;
all buttons feed a memory (RS latch); the reset is `BL10E-PS-IOC-01-BOB:RESET`; the
output is the permissive `BL10E-SIF-08_TRIP`.

1. Force `BL10E-PS-BOB-03:A = 0` **and** `BOB-03:B = 0` (press button 3, both channels).
   **Expect:** `BL10E-SIF-08_TRIP` turns `0`; contactors `CON-01:EN, 02, 03, 06, 07, 08,
   09, 10` all turn `0`; locks `SOL-0x` turn `0` (instant unlock to escape).
2. Set both channels back to `1`. **Expect:** `BL10E-SIF-08_TRIP` **stays** `0` (latched).
3. Press `BL10E-PS-IOC-01-BOB:RESET` (force `0`→`1`→`0`). **Expect:** `SIF-08_TRIP`
   returns to `1` (but the hazard stays off until a new search).
4. Repeat for buttons 1, 2, 4, 5, 6, 7, 8 — each one alone must trip (1oo7).

### SIF‑09 — Radiation sensors (page 368)
**What it protects:** if the radiation sensors read high, cut the hazard. Voting is
**1oo2** (either sensor is enough — a real alarm must never be out‑voted). It latches.
**How it is built:** the dose sensors `BL10E-PS-RDMND-01/02` and dose‑rate sensors
`RDMNR-01/02` feed a memory (RS latch); the reset is `BL10E-PS-IOC-01-RDMN:RESET`; the
output is `BL10E-SIF-09_TRIP`.

1. Force `BL10E-PS-RDMND-01` to its trip value. **Expect:** `BL10E-SIF-09_TRIP = 0`;
   source contactors `CON-01/02/03:EN` → `0` (and `CON-10:EN`).
2. Set it back to healthy. **Expect:** it **stays** tripped (latched).
3. Press `BL10E-PS-IOC-01-RDMN:RESET`. **Expect:** it clears.
4. Repeat with `RDMNR-01`, `RDMND-02`, `RDMNR-02` (1oo2 — any one trips).

### SIF‑10 — Electron‑source enable key (page 372)
**What it protects:** a physical key is the permission to have the source/RF energisable
at all. Voting is **1oo1** (one channel — the key is the law). Putting the key back is
**not** a reset.
**How it is built:** `BL10E-PS-KEY-03` (the rack enable key) → `BL10E-SIF-10_TRIP`,
which gates the contactors `CON-04/05:EN` (with `SIF-08`) and the RF group (page 267).

1. From `STATUS-BEAM_ON`, force `BL10E-PS-KEY-03 = 0` (turn the key off). **Expect:**
   `BL10E-SIF-10_TRIP = 0`; contactors `CON-04:EN`, `CON-05:EN` turn `0` (and watch which
   RF contactors follow, page 267).
2. Force `KEY-03 = 1` again. **Expect:** the hazard stays off — you recover only with a
   new search.

### SIF‑11 — Oxygen monitors (page 377)
**What it protects:** cryogenic nitrogen can push out the air. **Any one** of four
oxygen sensors reading low (this is "1oo4" — very sensitive) shuts the nitrogen valve
and raises the oxygen alarm. It latches.
**How it is built:** the four trip flags `BL10E-PS-OXMON-01..04_TRIP` feed a memory
(RS latch); the reset is `BL10E-PS-IOC-01-GAS:RESET`; the output `BL10E-SIF-11_TRIP`
closes the nitrogen valve `BL10E-PS-SDVLN2`, switches the oxygen beacons and the
`BL10E-PS-IND-01/02/03` traffic‑light indicators to red.

1. Force `BL10E-PS-OXMON-02_TRIP = 1` (one oxygen sensor low). **Expect:** the valve
   `BL10E-PS-SDVLN2 = 0` (closed); the oxygen indicators go to alarm/red.
2. Force `OXMON-02_TRIP = 0` again. **Expect:** it **stays** tripped (latched).
3. Press `BL10E-PS-IOC-01-GAS:RESET`. **Expect:** it clears.
4. Repeat for each of `OXMON-01..04_TRIP` (1oo4 — any one trips).

---

## 4 · The hutch search, step by step (the SFC, pages 326–338)

**What it is:** the search is a fixed walk‑through that proves nobody is left in the
hutch. The program runs it as an **SFC** (a step‑by‑step state machine). One person
sweeps the hutch pressing buttons in order. Two clocks watch them: the overall
**180 s** clock `MAX_SEARCH_TIME`, and a **5 s–60 s** window between each step. Too
fast means they did not really look; too slow means they lost control of the area.

**Open these tags in a Watch page so you can see the search move:**
`STATUS-OPEN_READY`, `STATUS-START_SEARCH`, `STATUS-HUTCH_ENTERED`,
`STATUS-ASB1..ASB4`, `STATUS-STANDBY`, `STATUS-BEAM_ON` (the search state),
`SEARCHED_AND_LOCKED` (memory: "search done & locked"), `SEARCH_TIMER_RUNNING` and
`SEARCH_TIME_EXCEEDED` (the 180 s clock), `LIGHT_CURTAIN_MONITORING` (curtain being
watched), `BEAM_DELAY_TIMER_END` (the 180 s warning done), `ABORT_SEARCH` (search
cancelled), the per‑step flags `Tx-Ty_TIMER_TRIP_LOW/HIGH` (too fast / too slow),
and `BL10E-SIF-05_START`, `SIF-06_TRIP`, `SIF-07_OUTPUT`.

### 4.1 Walk it all the way to beam on

| Step | What you force | The state moves to | Also do / watch |
|---|---|---|---|
| 0 | the §1 start point | `STATUS-OPEN_READY = 1` | — |
| **T1** | `BL10E-PS-SCR-01 = 1` (present the search card) | `STATUS-START_SEARCH` | `BL10E-SIF-05_START = 1`; service locks `SOL-05/06 = 1`; **now force `SADL-01/02 = 1`** (copy the bolts going in); the "RESTRICTED" sign `ANNRES = 1`; the 180 s clock starts |
| — | wait ≥ 5 s | — | the `T1-T2_TIMER` is running |
| **T2** | pulse `BL10E-PS-LCRx-01: 1→0→1` (one person steps through the light curtain) | `STATUS-HUTCH_ENTERED` | after 2 s `LIGHT_CURTAIN_MONITORING = 1` (curtain now watched) |
| — | wait ≥ 5 s | — | — |
| **T3** | pulse `BL10E-PS-ASB-01: 0→1→0` (press search button 1) | `STATUS-ASB1` | the button lamp `ASB-01:LED = 1` |
| — | wait ≥ 5 s | — | — |
| **T4** | pulse `BL10E-PS-ASB-02` | `STATUS-ASB2` | `ASB-02:LED = 1` |
| — | wait ≥ 5 s | — | — |
| **T5** | pulse `BL10E-PS-ASB-03` | `STATUS-ASB3` | `ASB-03:LED = 1` |
| — | wait ≥ 5 s | — | — |
| **T6** | pulse `BL10E-PS-ASB-04` | `STATUS-ASB4` | `ASB-04:LED = 1`; curtain watching ends |
| — | wait ≥ 5 s | — | — |
| **T7** | pulse `BL10E-PS-ASBF-01` (the final button; needs `BL10E-SIF-06_TRIP = 1`, i.e. all doors shut) | `STATUS-STANDBY` | general locks `SOL-01..04 = 1`; **now force `GADL-01/02/04/05 = 1`** ← *without this the search sticks here*; the "STANDBY" sign `ANNSTB = 1`; blue lights `BLUEL-0x = 1`; `SEARCHED_AND_LOCKED = 1`; the 180 s warning starts |
| — | wait 180 s | — | `BEAM_DELAY_TIMER_END = 1`, then `BL10E-SIF-07_OUTPUT = 1` |
| **T8** | (happens by itself) | `STATUS-BEAM_ON` | the "BEAM ON" sign `ANNBON = 1`; the beam‑on lamp `BONI-01:A/:B = 1`; the contactors `CON-0x:EN = 1` (hazard live); the key `KEY-01:SOL` releases |

### 4.2 Prove the search cancels when it should (abort tests)
Each of these must send the search to a cancelled state (`ABORT_SEARCH = 1`) and back
toward "Open":

| Cancel because | How to cause it | Watch |
|---|---|---|
| wrong order | at `STATUS-START_SEARCH`, press `ASB-01` **before** the light curtain | `ABORT_SEARCH = 1` |
| too fast | press the next button **less than 5 s** after the last | the matching `Tx-Ty_TIMER_TRIP_LOW = 1` → cancel |
| too slow | sit in a step **more than 60 s** | the matching `Tx-Ty_TIMER_TRIP_HIGH = 1` → cancel |
| over the 180 s limit | drag the whole search past 180 s | `SEARCH_TIME_EXCEEDED = 1` → cancel |
| curtain re‑broken | during T3–T6, pulse `BL10E-PS-LCRx-01 = 0` | cancel while `LIGHT_CURTAIN_MONITORING = 1` |
| key removed mid‑search | force `BL10E-PS-KEY-01 = 0` (or `KEY-02`) before the final button | cancel |
| door opened mid‑search | force `BL10E-PS-GADC-01 = 0` + `GADC-02 = 0` | cancel |
| door open at the final button | open a door at `STATUS-ASB4`, then press `ASBF-01` | final step refused (`SIF-06_TRIP = 0`) |

### 4.3 The enable‑key trap (page 337)
**Idea:** the key `BL10E-PS-KEY-01` is held in place by a solenoid `KEY-01:SOL` during
the search. At `STATUS-BEAM_ON` the program releases it so it can be moved to the rack.
Removing it **before** the search finishes must cancel; removing it **after** release
must not.
1. Mid‑search, force `KEY-01 = 0` → the search cancels (already covered in §4.2).
2. Reach `STATUS-BEAM_ON` and watch `KEY-01:SOL = 0` (the key is released).

---

## 5 · The "no silent restart" memory test (page 267) — the most important one
**Idea:** after any trip, simply clearing the cause must **not** bring the hazard back.
The contactor logic combines the safety‑function permissives with `SEARCHED_AND_LOCKED`
(the "search done & locked" memory) and `STATUS-BEAM_ON` through memory latches. The
program page even says so:

> *"If Search and Locked is broken, contactors 01, 02, 03, 06, 07, 08, 09 & 10 can not
> start again when tripped without going through a new search sequence."*

The contactor groups on page 267 are:

| Group | Contactors (the `:EN` command tags) | Held on by |
|---|---|---|
| Source | `CON-01, 02, 03, 10` | `SIF-08` (no stop button) & `SIF-01` (door) & `SIF-02` (service door) & `SIF-09` (radiation), plus `SEARCHED_AND_LOCKED` & `STATUS-BEAM_ON` |
| Gate / RF | `CON-06, 07, 08, 09` | `SIF-13` (gate) |
| Key | `CON-04, 05` | `SIF-10` (key) & `SIF-08` |
| Door locks | `SOL-01..06` | set when the search reaches each lock step, cleared at "Open" or by a stop button |

1. Reach `STATUS-BEAM_ON` (§4). Confirm the contactors `CON-0x:EN = 1`.
2. Cause any trip (for example press one beam‑off button). **Expect:** `CON-0x:EN = 0`,
   `SEARCHED_AND_LOCKED = 0`, and the state leaves `STATUS-BEAM_ON`.
3. Clear the cause and press the matching reset. **Expect:** the contactors **stay** `0`.
4. Confirm only a complete new §4 search brings them back. Do this once for a door
   trip and once for a beam‑off‑button trip.

---

## 6 · The alarm / diagnostic layer (pages 162–174) — it watches, it does not trip
**Idea:** around the safety functions sits a layer that just tells the operator **why**
something happened. It does not trip anything. Examples: per‑sensor alarm flags such as
`BL10E-PS-IT-01_ALARM` (made from `IT-01_TRIP` through an off‑delay timer
`E_SOURCE_TIME = 120 s`, page 172); the two‑channel discrepancy alarms (pages 171,
173–174); and system diagnostics (power‑supply, fan and network‑switch faults, force
flags, module errors — `Diagnostics`, pages 241–250).

**Sample check:**
1. Force `BL10E-PS-IT-01_TRIP = 1` and hold it for more than 120 s. **Expect:** the
   alarm `IT-01_ALARM` comes on; clear the trip and it goes off after the 120 s timer.
2. Force `BL10E-PS-GADC-01 = 0` on its own for longer than the voter's delay.
   **Expect:** the voter's `Dev` (disagreement) flag comes on — a maintenance alarm,
   not a trip.

---

## 7 · Coverage checklist (tick each when done)

| Tick | What you tested | Page | The idea it proves |
|---|---|---|---|
| ☐ | analogue sensor → trip flag (Way B) | 184–187 | set‑point + hysteresis |
| ☐ | two‑channel + discrepancy | 152–161, 171–174 | a wiring fault is not a trip |
| ☐ | SIF‑01 main door | 291 | 2oo3 voting |
| ☐ | SIF‑13 gate | 382 | 2oo3 + 200 ms |
| ☐ | SIF‑02 service door | 297 | 2oo3 or 1oo2 |
| ☐ | SIF‑03 current + voltage / unlock permit | 303 | two 2oo3 checks, 20 s, manual button |
| ☐ | SIF‑05 start permit (5 negative tests) | 344 | every start condition is required |
| ☐ | SIF‑06 search‑complete proof | 350 | doors shut at the final button |
| ☐ | SIF‑07 lock proof + 180 s (positive and negative) | 356 | command is not the same as confirmation |
| ☐ | SIF‑08 beam‑off buttons × 8 | 363 | 1oo7, latch, escape unlock |
| ☐ | SIF‑09 radiation × 4 signals | 368 | 1oo2, latch |
| ☐ | SIF‑10 enable key | 372 | 1oo1, key is not a reset |
| ☐ | SIF‑11 oxygen × 4 | 377 | 1oo4, latch |
| ☐ | full search T1→T8 | 326–338 | the search walk‑through |
| ☐ | 8 abort tests | 328–331 | both clocks + the monitors |
| ☐ | key‑trap release | 337 | search integrity |
| ☐ | "no silent restart" memory | 267 | the master safety rule |
| ☐ | alarm layer | 162–174 | watching vs protecting |

## 8 · Honest limits (read before you rely on a result)
* The analogue set‑points are **fixed fail‑safe numbers** (`OXMON_SP = 25.0`,
  `IT/VT_SP = 0.0`) — they cannot be forced; use §0.4. The example values used in the
  other documents (19.5 % oxygen, "above 4 mA") come from the Cause & Effect matrix,
  not from the program.
* A few exact wire polarities are hard to read from the flattened program printout —
  **trust the live value you see in simulation**; that is what offline simulation is for.
* The full requirements document (`TDI-PSS-SRS-0002`) and the logic drawing
  (`Dwg 1224211`) are **not** in this repo. For real plant work, check against them
  (for example the C&E mentions 12 s where the program uses `DOOR_UNLOCK_DELAY = 20 s`).

## 9 · Test record (copy one per test)
```
Test (checklist row): ____   Page: ____   Date: ____   Engineer: ____
Started from §1 (STATUS-OPEN_READY = 1)?   Yes / No
Way A or Way B for analogue (§0.4):  ____
Forced (tag = value): ______________________________________
Watched (tag : value seen): ________________________________
Output (tag : value seen): _________________________________
Did it latch?  Reset used: ___________   New search needed?  Yes / No
PASS / FAIL: ____   Notes: __________________________________
```
