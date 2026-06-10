# B10E "HeXI" Personnel Safety System — Logic Simulator & Study Pack

A self-contained kit to **understand** and **simulate** the safety logic in this
repository, written for a **junior technical-support engineer**. No PLC, no
licences and no internet are needed — just Python 3.

> **What is this system?**
> The three files in the repo describe the **Personnel Safety System (PSS)** for
> the Diamond Light Source **B10E "HeXI"** synchrotron beamline. It is a **SIL-2**
> radiation/personnel-protection interlock running on a **HIMax** redundant
> safety PLC (programmed in HIMA *SILworX*). Its job: **make it impossible for
> the X-ray/electron-source/RF hazard to be energised while a person could be
> inside the shielded "hutch"** — and to force the hazard off if anything unsafe
> happens.

---

## The three source files (and what each one is for)

| File in repo | What it is | Why it matters |
|---|---|---|
| `TDI-PSS-B10E-C&E Cause & Effect Matrix (14-04-26) v4.0.pdf` | **Cause & Effect (C&E) matrix** (per BS EN IEC 62881) | The contract: which **causes** (sensors) drive which **effects** (outputs), with voting, timing and the SIF they belong to. |
| `C15862H-HeXI-IOS.xlsx` | **I/O Schedule (IOS)** | Which physical PLC channel each signal is wired to (AI module 005, DI 007/008/009, DO 013–016). |
| `program.pdf` | **SILworX program printout** (713 pages) | The actual PLC code: the 12 SIFs, the search **SFC**, all timers, latches and voting blocks. |

This kit turns those documents into something you can *run*.

---

## What's in this folder

```
B10E-PSS-Simulator/
├── README.md                     <- you are here
├── pss_sim.py                    <- the SIMULATOR ENGINE (logic model, heavily commented)
├── pss_cli.py                    <- INTERACTIVE keyboard driver  (python3 pss_cli.py)
├── scenarios.py                  <- 7 worked examples + self-test (python3 scenarios.py)
├── data/
│   ├── cause_effect.json         <- machine-readable C&E (causes, effects, SIFs, voting, timers)
│   ├── io_map.json               <- the full I/O list extracted from the IOS spreadsheet
│   ├── ios_csv/                  <- the IOS spreadsheet exported sheet-by-sheet (readable)
│   └── program_extracted.txt     <- searchable text of all 713 program pages
└── docs/
    ├── 01_SYSTEM_AND_CAUSE_EFFECT.md   <- the big picture + how to read the C&E
    ├── 02_SEARCH_SEQUENCE.md           <- the T1..T7 hutch search, step by step
    ├── 03_TEST_PROCEDURE.md            <- step-by-step functional test for every SIF
    ├── 04_PROGRAM_LOGIC_REFERENCE.md   <- exact PLC logic (SIFs, FBs, timers, latches)
    └── 05_HOW_TO_USE_THE_SIMULATOR.md  <- every command, with examples
```

---

## Quick start (60 seconds)

```bash
cd B10E-PSS-Simulator

# 1) Prove the model matches the Cause & Effect matrix (7 scenarios):
python3 scenarios.py

# 2) Drive it yourself:
python3 pss_cli.py
#   then type:   search        (runs a full valid search and turns BEAM ON)
#                bob 3         (press a beam-off button -> watch everything trip)
#                reset BOB     (clear the latch)
#                door GADC01 open   then   door GADC02 open   (2oo3 door trip)
#                help          (all commands)
```

Nothing here is connected to real plant. It is a **learning model** of the
logic. Where the simulator simplifies the real PLC, it says so in the comments
and in `docs/04_PROGRAM_LOGIC_REFERENCE.md`.

---

## Where to go next

* **New to the system?** Read `docs/01_SYSTEM_AND_CAUSE_EFFECT.md`.
* **Need the test steps?** Read `docs/03_TEST_PROCEDURE.md` and run each one in
  the CLI as you go.
* **Want the exact PLC logic?** `docs/04_PROGRAM_LOGIC_REFERENCE.md`.
