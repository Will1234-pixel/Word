# B10E "HeXI" Personnel Safety System — study & test pack

A set of clear, plain‑English documents to help you **understand** the safety
logic in this repository and **test it step by step in HIMA SILworX offline
simulation**. Written for a junior technical‑support engineer.

> ### 👉 New here? Read **`docs/00_START_HERE.md`** first.
> It is a single guided document — system, code, and how to simulate it — and it
> is all you need to understand the whole thing. The other documents are deep
> reference you can dip into later.

> **What is this system?**
> The three source files in this repo describe the **Personnel Safety System
> (PSS)** for the Diamond Light Source **B10E "HeXI"** beamline. A beamline has a
> shielded room called a **hutch**. Inside the hutch there are things that can
> hurt a person: **radiation**, **RF (radio‑frequency) power**, and **low oxygen**
> from cryogenic gas. The PSS is an independent safety PLC (a **HIMax**, from
> HIMA) whose one job is simple:
>
> **a person and the hazard must never be in the hutch at the same time.**
>
> Before the hazard can be switched on, a trained person must walk through and
> "search" the hutch to prove nobody is inside, then lock the doors. While the
> hazard is on, if anything unsafe happens (a door opens, a stop button is
> pressed, radiation is detected, oxygen drops) the PLC removes the hazard in a
> fraction of a second. The system is rated **SIL 2** (a measure of how
> trustworthy the protection must be).

---

## The three source files (already in this repo)

| File | What it is | Plain meaning |
|---|---|---|
| `TDI-PSS-B10E-C&E Cause & Effect Matrix (14-04-26) v4.0.pdf` | **Cause & Effect (C&E) matrix** | A big grid that says which **sensor** (cause) switches off which **output** (effect). |
| `C15862H-HeXI-IOS.xlsx` | **I/O schedule (IOS)** | A list of every signal and which physical PLC terminal it is wired to. |
| `program.pdf` | **SILworX program printout** | The actual PLC program: the safety functions, the search, all the timers. |

These documents turn those three files into something you can read and test.

---

## What's in this folder

```
B10E-PSS-Simulator/
├── README.md                 <- you are here
├── docs/
│   ├── 00_TAG_GLOSSARY.md             <- what every signal name (tag) means
│   ├── 01_SYSTEM_AND_CAUSE_EFFECT.md  <- the big picture + how to read the C&E
│   ├── 02_SEARCH_SEQUENCE.md          <- the hutch search, step by step
│   ├── 03_PROGRAM_LOGIC_REFERENCE.md  <- the exact PLC logic (pages, blocks, timers)
│   └── 04_SILWORX_OFFLINE_TEST_PROCEDURE.md  <- step-by-step test in SILworX
├── docs-word/                <- the same documents as Microsoft Word (.docx) files
└── data/                     <- reference data pulled out of the three source files
    ├── io_map.json           <- the I/O list as data
    ├── ios_csv/              <- the I/O schedule, one sheet per file
    └── program_extracted.txt <- searchable text of all 713 program pages
```

> Note: this pack is **documentation only**. There is no software to install and
> nothing here connects to real plant. You do the actual testing in your own
> **HIMA SILworX** offline simulation, following document 04.

---

## What each document tells you

| Document | What it tells you |
|---|---|
| **00 · Tag glossary** | The full list of signal names (tags) and what each one means in plain words. Keep this open while you read the others. |
| **01 · System and Cause & Effect** | The big picture: what the hutch hazards are, what a "cause" and an "effect" are, what **de‑energise‑to‑trip** means (OFF = safe), what **voting** means (e.g. "2 out of 3 sensors must agree"), and a one‑line summary of every safety function. Start here. |
| **02 · The hutch search** | How the walk‑through search works, step by step (the stages the system moves through), the time limits, and what cancels a search. |
| **03 · Program logic reference** | The exact PLC program: which page does what, how each safety function is built (which sensors, which voting, which timers), and the real set‑point and timer values. Use it as a look‑up. |
| **04 · SILworX offline test procedure** | The main "do this" document: a step‑by‑step test you run in HIMA SILworX offline simulation. For each safety function it gives the tag to force, the signal to watch, and the result to expect. |

---

## How to use this pack

1. **Read document 01** to understand what the system does and the key idea
   (`OFF = safe`).
2. **Keep document 00 (the glossary) open** so every tag makes sense.
3. **Read document 02** to understand the hutch search.
4. **Open document 04 and your SILworX project side by side**, and work through
   the tests one safety function at a time. Use **document 03** whenever you want
   the exact page or block behind a test.

Everything you need to test the logic is in document 04, written so each step is
clear: which signal to set, what to watch, and what should happen.
