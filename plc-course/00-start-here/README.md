# 00 — Start Here: How This Course Works and Setting Up Your Lab

> **Level:** Orientation · **Time:** 2–3 hours (most of it installing tools) · **Prerequisites:** none

Welcome. This course takes you from "what is a PLC?" to designing, testing and commissioning
real industrial control software. It is **vendor-neutral**: everything is taught in the
international standard IEC 61131-3, which is what Siemens, Rockwell (Allen-Bradley), Schneider,
Beckhoff, CODESYS-based controllers, OpenPLC and most others implement or closely follow.
Throughout the course there are notes showing how each idea looks in the big vendor tools.

## What you will be able to do by the end

- Explain how a PLC works (hardware, scan cycle, I/O, memory) and read the electrical drawings around it.
- Write correct programs in Ladder Diagram (LD), Function Block Diagram (FBD), Structured Text (ST)
  and Sequential Function Charts (SFC).
- Use timers, counters, edge detection, maths, arrays, structures and function blocks the way
  professionals do.
- Handle analog signals, alarms, PID loops, sequences, communications and HMI interfaces.
- Understand functional safety, cause-and-effect matrices, industry standards (ISA-88, PackML,
  ISA-18.2, IEC 62443) and where a standard PLC must *not* be used.
- Test, version-control, commission and troubleshoot PLC software.
- Finish three capstone projects that you can show in a job interview.

## How the course is organised

| Level | Modules | You will learn |
|---|---|---|
| **1 — Foundations** | [01](../01-what-is-a-plc/) · [02](../02-electrical-and-field-devices/) · [03](../03-data-types-and-addressing/) | What a PLC is, the scan cycle, wiring and field devices, numbers, data types and addresses |
| **2 — Core programming** | [04](../04-ladder-logic/) · [05](../05-boolean-logic-and-fbd/) · [06](../06-edges-and-one-shots/) · [07](../07-timers/) · [08](../08-counters/) · [09](../09-math-and-data-handling/) | Ladder logic, Boolean logic and FBD, edges, timers, counters, maths and data handling |
| **3 — Structured programming** | [10](../10-structured-text/) · [11](../11-program-organization/) · [12](../12-data-structures/) · [13](../13-sequential-control/) · [14](../14-analog-and-process-io/) | Structured Text, function blocks and program structure, data structures, sequences and SFC, analog signals |
| **4 — Advanced** | [15](../15-pid-control/) · [16](../16-alarms-and-diagnostics/) · [17](../17-industrial-communications/) · [18](../18-hmi-and-scada/) · [19](../19-motion-and-drives/) | PID control, alarms and diagnostics, networks, HMI/SCADA, drives and motion |
| **5 — Professional practice** | [20](../20-functional-safety/) · [21](../21-architecture-and-standards/) · [22](../22-software-engineering/) · [23](../23-commissioning-and-troubleshooting/) | Functional safety, architecture standards, software engineering, commissioning and troubleshooting |
| **Capstone** | [24](../24-capstone-projects/) | Three complete projects with acceptance tests |

Appendices: [vendor cross-reference](../appendices/A-vendor-cross-reference.md) ·
[glossary](../appendices/B-glossary.md) ·
[study plan and self-assessment](../appendices/C-study-plan-and-self-assessment.md) ·
[resources and certifications](../appendices/D-resources-and-certifications.md) ·
[MATIEC/OpenPLC notes](../appendices/E-matiec-openplc-notes.md).

### Anatomy of a module

Every module folder has the same layout:

```
07-timers/
├── README.md                 the lesson: concepts, worked examples, pitfalls, vendor notes, quiz
└── labs/
    ├── 07-1-star-delta.test  acceptance tests for the lab (you run these against YOUR code)
    ├── starter/              declarations already written; you fill in the logic
    │   └── 07-1-star-delta.st
    └── solutions/            reference solutions (try the lab first!)
        └── 07-1-star-delta.st
```

Each lesson ends with **"Check your understanding"** questions. The answers are hidden in
collapsible sections, so try the question before you open the answer.

### How long will it take?

The whole course is about 290 hours of study, including one capstone project. At about 7
hours a week that is roughly 40 weeks:

| Part | Study time | At ~7 h a week |
|---|---|---|
| Orientation and Levels 1–2 (Modules 00–09) | about 75–85 h | 11–12 weeks |
| Level 3 (Modules 10–14) | about 55 h | about 8 weeks |
| Levels 4–5 (Modules 15–23) | about 105–115 h | 15–16 weeks |
| One capstone project | about 25–40 h | 4–6 weeks |

At 15 hours a week it takes about 20 weeks. See
[Appendix C](../appendices/C-study-plan-and-self-assessment.md) for week-by-week plans at
different paces. You can stop after any level and still have useful, complete skills: Levels
1–2 already cover much of the day-to-day ladder work on a plant.
Doing the labs matters more than reading: you learn PLC programming by writing and testing
logic.

## A word on safety

PLCs switch motors, heaters, valves and presses. The labs in this course are simulations, so
nothing can hurt you. The moment you connect a PLC to real equipment:

- Never work on live circuits unless you are trained, authorised and following your site's
  rules (lock-out/tag-out, permits, the relevant electrical safety standard).
- Never test new logic on running plant without an approved test plan and the operators' knowledge.
- A standard PLC is **not** a safety system. Emergency stops, guards and process trips need
  safety-rated devices designed under the functional-safety standards (Module 20).

## Setting up your practice lab

You need somewhere to write and run PLC code. You do **not** need any hardware to begin.
Pick at least one option from each row:

| Purpose | Recommended | Alternatives |
|---|---|---|
| Automatic checking of every lab (Structured Text) | **`plctest`**, the test runner in this repo | — |
| Drawing Ladder / FBD graphically and simulating it on your PC | **OpenPLC Editor** (free, open source; the "Download OpenPLC IDE" button on autonomylogic.com) | CODESYS; vendor tools |
| A "real" IDE with simulation, used in industry | **CODESYS Development System** (free, Windows) | Siemens TIA Portal + PLCSIM (trial), Rockwell Connected Components Workbench (free, Micro800) |

### Option 1 — `plctest`: the course test runner (do this first)

`plctest` compiles your Structured Text with **MATIEC**, the open-source IEC 61131-3 compiler
used by OpenPLC, then runs your program in a small simulated PLC. It sets inputs, lets PLC time
pass, and checks the outputs against each lab's acceptance tests.

It runs on Linux, macOS, or Windows through WSL (Windows Subsystem for Linux).

1. **Install the build tools** (one time):
   - Ubuntu/Debian or WSL: `sudo apt-get install git python3 build-essential autoconf automake libtool flex bison`
   - macOS (with [Homebrew](https://brew.sh)): `xcode-select --install`, then `brew install autoconf automake libtool flex bison`
   - Windows: install WSL first (`wsl --install` in an administrator PowerShell, then reboot), open
     the Ubuntu terminal, and use the Ubuntu command above.
2. **Build MATIEC** (one time, about a minute). From the `plc-course` folder:
   ```bash
   tools/setup-matiec.sh
   ```
3. **Check everything works** by running every lab solution in the course:
   ```bash
   python3 tools/plctest.py --all .
   ```
   Every line should say `PASS`. Solutions must pass their tests. Starter files must *fail*
   them, which proves the tests really check something.

### Option 2 — OpenPLC Editor (graphical Ladder and FBD, free, with a simulator)

[OpenPLC](https://autonomylogic.com) is a free, open-source PLC that follows IEC 61131-3.
On the website, click **Download OpenPLC IDE**. You don't need *Autonomy Edge*, which is a
separate cloud service from the same company.

- The **Editor** (Windows, macOS, Linux) lets you draw **Ladder (LD)** and **Function Block
  Diagram (FBD)** and write **Structured Text (ST)** and **Instruction List (IL)**.
- It has a **built-in simulator**. Write a program, start the simulator, and it runs on your
  PC with no hardware. Ladder wires light up where "power" flows, and a debugger panel shows
  live variable values that you can change to simulate pressing buttons.
- The separate **Runtime** turns a PC, Raspberry Pi or some Arduino-class boards into a real
  PLC when you want to drive actual I/O later. In the current version (v4) it is managed from
  the Editor. The older v3 Runtime had its own web page for uploading `.st` files, which is
  why you will see both described online.

Why it pairs well with this course: OpenPLC uses the same compiler family (MATIEC) as
`plctest`, so code that passes `plctest` uses only what OpenPLC understands. Every lab solution
is also compile-checked with the OpenPLC Runtime's own compiler. The simplest way to use it:
**draw each lab in the Editor, run it in the simulator, and tick off the lab's numbered
requirements one by one**, toggling the inputs in the debugger.

Sequential Function Chart (SFC) is not listed among the current Editor's languages. For the
SFC part of Module 13, use CODESYS (Option 3), or write the textual SFC form that `plctest`
accepts.

### Option 3 — CODESYS (industry-grade, free)

**CODESYS Development System V3** is free from the CODESYS Store (Windows; registration
required). Hundreds of hardware brands use it, including WAGO, Schneider Machine Expert,
Beckhoff TwinCAT (a close relative), Festo, ifm and Eaton. It has a built-in simulation mode
and a free soft PLC (*CODESYS Control Win*, which runs for a limited time before you restart it).
It supports everything in IEC 61131-3 edition 3, including the object-oriented features in
Module 21 that MATIEC does not.

To use a lab in CODESYS, create a POU of type *Program*. Paste the variable declarations into
the declaration part and the logic into the implementation part. Ignore the `CONFIGURATION`
section, because CODESYS configures tasks in its *Task Configuration* tree.

### Option 4 — vendor tools

If your job uses a particular brand, install its tools as well:

- **Siemens:** TIA Portal (STEP 7 Basic/Professional) has trial licences, and **S7-PLCSIM**
  simulates S7-1200/1500 CPUs. The ST dialect is called **SCL**.
- **Rockwell:** **Connected Components Workbench (CCW)** is free for Micro800 controllers and
  includes a simulator for some models. **Studio 5000 Logix Designer**
  (ControlLogix/CompactLogix) is paid, and emulation needs FactoryTalk Logix Echo or the older
  Studio 5000 Logix Emulate.
- **Simulated machines:** **Factory I/O** (paid, with a free trial) provides 3D conveyor, sorting
  and tank scenes that connect to real or simulated PLCs.

Vendor names, licences and product line-ups change often, so check the vendor's website for
the current offer. [Appendix A](../appendices/A-vendor-cross-reference.md) maps IEC terms and
instructions to Siemens and Rockwell equivalents.

### Optional — real hardware

You can learn everything here without hardware. If you want to hear a relay click, a cheap
route is the OpenPLC Runtime on a Raspberry Pi or a supported Arduino-class board with a few
buttons and LEDs. A second-hand small PLC (Siemens S7-1200, Allen-Bradley Micro820/850, an
AutomationDirect CLICK) with a 24 V DC power supply, some push-buttons and pilot lights is the
classic bench kit. Use 24 V DC for all your practice wiring. Mains wiring is for qualified
people only.

## The lab workflow

1. **Read the lesson.** Each lab lists its **interface**: the exact variable names, types and
   I/O addresses the acceptance test uses. Keep those names exactly as given. Anything else
   inside your program is up to you.
2. **Copy the starter** into a working folder so that the original stays clean:
   ```bash
   mkdir -p my-work
   cp 00-start-here/labs/starter/00-1-hello-plc.st my-work/
   ```
3. **Write your logic** in any text editor. VS Code has "Structured Text" syntax-highlighting
   extensions.
4. **Run the acceptance test** against your file:
   ```bash
   python3 tools/plctest.py my-work/00-1-hello-plc.st 00-start-here/labs/00-1-hello-plc.test
   ```
   (For a file still inside `labs/starter/` you can leave the test argument off. `plctest`
   finds `labs/<name>.test` by itself.)
5. **Read the output**, fix, and repeat until every check says `ok`.
6. **Compare** with `labs/solutions/`. Several correct answers are usually possible. When yours
   differs from the reference, work out which one is easier to read and maintain.

### Reading `plctest` output

```
scenario: stop button stops the motor, and it stays stopped
  ok      line 37   expect Motor FALSE
  ok      line 38   expect RunLamp FALSE
  FAIL    line 41   expect Motor FALSE   (actual: TRUE, at t=1040 ms)
14 check(s), 1 failure(s)
```

- Each `scenario` starts a freshly powered-up PLC: all variables at their initial values,
  PLC clock at 0.
- `line 41` is the line in the `.test` file. Open it to see exactly what was expected and
  what happened just before.
- `t=` is the PLC time of the most recent scan. The labs use a 10 ms task, so `wait 1s` runs
  100 scans.
- Compile errors are printed with the line and column in your `.st` file.

### Writing your own tests

The `.test` files are plain text, and you are encouraged to write your own. Adding a test for
a bug you just fixed is a professional habit (Module 22). The full language is in
`python3 tools/plctest.py --help`. The essentials:

```
scenario my first test        # fresh PLC
set StopPB_NC TRUE            # write an input (or any variable)
set StartPB TRUE
scan                          # run one PLC scan
expect Motor TRUE             # check a value (= <> < <= > >= also work)
wait 2s                       # let 2 s of PLC time pass
expect Timer1.ET ~ T#2s T#20ms  # approximately equal, within a tolerance
until Level >= 80.0 within 30s  # run until a condition is true, or fail after 30 s
print Level                   # show a value while you debug
```

### Testing Ladder you drew in OpenPLC Editor

The quickest check is the Editor's own simulator: go through the lab's numbered requirements
and set the inputs in the debugger to prove each one, including the "must not" cases (stop
wins, no restart after a trip, and so on). Reading the lab's `.test` file shows you exactly
which situations the automatic test checks, because it is plain text.

Graphical programs are translated into Structured Text before compiling. If your version of
the Editor lets you export or save that generated `.st` file (older versions did this when
building a program for the Runtime), you can also run it against the acceptance test:

```bash
python3 tools/plctest.py path/to/generated.st 04-ladder-logic/labs/04-1-start-stop-station.test
```

This works as long as your Ladder variables use the lab's names and your project has **one**
program instance. The test uses variable names, not addresses, and your task interval can
differ from 10 ms because the tests use time-based waits.

## Conventions used in this course

### Ladder diagrams in the text

Ladder is graphical, so the lessons draw it with characters:

```
 Symbol        Meaning                        Rockwell      Siemens
 --] [--       normally-open (NO) contact     XIC           -| |-
 --]/[--       normally-closed (NC) contact   XIO           -|/|-
 --( )--       output coil                    OTE           -( )-
 --(S)--       set (latch) coil               OTL           -(S)-
 --(R)--       reset (unlatch) coil           OTU           -(R)-
 --]P[--       rising-edge contact            ONS / OSR     -|P|-
 --]N[--       falling-edge contact           OSF           -|N|-
```

Rungs read left to right and are solved top to bottom. For example, the seal-in circuit
from Lab 00-1:

```
      StartPB         StopPB_NC                          Motor
 |-----] [-----+-------] [---------------------------------( )-----|
 |             |
 |     Motor   |
 |-----] [-----+
 |
 |      Motor                                            RunLamp
 |-----] [-----------------------------------------------( )-----|
```

and the same logic in Structured Text:

```iecst
Motor := (StartPB OR Motor) AND StopPB_NC;
RunLamp := Motor;
```

### Naming

| Pattern | Meaning | Example |
|---|---|---|
| `...PB` | push-button | `StartPB` |
| `..._NC` | input from a **normally-closed** device: TRUE when healthy / not operated | `StopPB_NC`, `EStop_NC`, `OverloadOK_NC` |
| `...LS`, `...PE`, `...PX` | limit switch, photo-eye, proximity sensor | `ClosedLS` |
| `FB_...` | function block type | `FB_Motor` |
| `ST_...` | structure (UDT) type | `ST_Recipe` |
| `E_...` | enumeration type | `E_State` |
| `F_...` | function | `F_Scale` |

The `_NC` suffix matters. Stop buttons, emergency stops and overload contacts are wired
normally-closed so that a broken wire looks the same as "stop". Module 02 explains why, and
Module 04 shows why it confuses almost every beginner.

### I/O addresses

The labs use IEC direct addresses as OpenPLC does: `%IX0.0` is digital input 0.0, `%QX0.0`
is digital output 0.0, `%IW0` is analog (16-bit word) input 0, and `%QW0` is analog output 0.
Module 03 covers addressing in detail, including Siemens and Rockwell styles.

### About the compiler

MATIEC follows the IEC standard strictly and has some gaps. For example, it rejects `//`
comments (write `(* ... *)`), arrays of function block instances, and the object-oriented
features of IEC 61131-3 edition 3. The lab files avoid all of these. Every limitation, and
what to do in CODESYS, TIA Portal or Studio 5000 instead, is listed in
[Appendix E](../appendices/E-matiec-openplc-notes.md).

## Lab 00-1: Hello PLC

**Goal:** get your tools working and run your first acceptance test.

A conveyor motor has a green **Start** button and a red **Stop** button. Press Start and the
motor runs, and it keeps running when you let go of Start. Press Stop and it stops. A green
lamp shows when the motor is running.

**Interface** (use these names exactly):

| Tag | Address | Type | Description |
|---|---|---|---|
| `StartPB` | `%IX0.0` | BOOL | Start push-button, **NO**: TRUE while pressed |
| `StopPB_NC` | `%IX0.1` | BOOL | Stop push-button, **NC**: TRUE while **not** pressed (and FALSE if its wire breaks) |
| `Motor` | `%QX0.0` | BOOL | Motor contactor coil |
| `RunLamp` | `%QX0.1` | BOOL | Green "running" lamp |

**Requirements:**

1. At power-up the motor is off.
2. Pressing Start runs the motor. It keeps running after Start is released.
3. Pressing Stop stops the motor. It does not restart when Stop is released.
4. If Start and Stop are pressed together, Stop wins and the motor stays off.
5. A broken wire on the stop button must stop the motor.
6. The lamp is on exactly when the motor is on.

**Steps:**

1. Run the test against the untouched starter and watch it fail:
   `python3 tools/plctest.py 00-start-here/labs/starter/00-1-hello-plc.st`
2. Copy the starter to `my-work/`, write the logic, and run the test again:
   `python3 tools/plctest.py my-work/00-1-hello-plc.st 00-start-here/labs/00-1-hello-plc.test`
3. When it passes, open `labs/solutions/00-1-hello-plc.st` and compare.
4. *(Optional, and recommended if you installed OpenPLC Editor)* Draw the same logic in
   Ladder using the rung above, start the simulator, and check each requirement by changing
   `StartPB` and `StopPB_NC` in the debugger.

<details>
<summary>Hint (open only if stuck)</summary>

The motor output must appear on the right-hand side of its own equation. That is the seal-in:
`Motor := (StartPB OR Motor) AND ...`. Which input breaks the circuit?
</details>

## Check your understanding

1. Why does every lab keep the exact variable names given in its interface table?
2. A starter file fails its acceptance test before you have changed anything. Is that a problem?
3. Why is the Stop button wired normally-closed, and what does the PLC see when its wire breaks?
4. `plctest` reports `FAIL line 41 ... at t=1040 ms`. Where do you look first?

<details>
<summary>Answers</summary>

1. The acceptance tests refer to the interface variables by name. Everything else inside
   your program can be named and structured however you like.
2. No, that is the expected behaviour. A starter only declares the variables, so failing
   proves that the tests actually check the logic. `plctest --all` reports an error if a
   starter unexpectedly *passes*.
3. So that a fault in the stop circuit (broken wire, loose terminal, blown fuse) has the same
   effect as pressing Stop: the input goes FALSE and the machine stops. It fails *safe*. The
   PLC cannot tell a pressed stop button from a broken wire, and both stop the motor.
4. Line 41 of the `.test` file, plus the `set`/`wait` lines just above it. They tell you what
   the inputs were and how much time had passed. Then use `print` lines or re-read your logic
   for that situation.
</details>

---

Next: **[01 — What Is a PLC?](../01-what-is-a-plc/)**
