# PLC Programming: From Basics to Advanced

A complete, hands-on course in industrial PLC programming. It starts at "what is a PLC?" and
ends with you designing, testing and commissioning real control systems. It is vendor-neutral:
everything is taught in the international standard **IEC 61131-3**, with notes on how each idea
looks in Siemens TIA Portal, Rockwell Studio 5000, CODESYS and OpenPLC.

**New here? Start with [Module 00 — Start Here](00-start-here/).** It explains how the course
works and helps you install free practice software. No PLC hardware is needed.

## Quick start (about 30 minutes)

1. Read [Module 00](00-start-here/).
2. Download the free **OpenPLC IDE** from [autonomylogic.com](https://autonomylogic.com)
   ("Download OpenPLC IDE"). It has a built-in simulator, so your programs run on your PC.
3. Do [Lab 00-1](00-start-here/README.md#lab-00-1-hello-plc): a motor start/stop circuit, the
   "hello world" of PLCs.
4. Continue with [Module 01](01-what-is-a-plc/). Work through the modules **in order**.

## Course map

| # | Module | Level | Time | Labs |
|---|---|---|---|---|
| 00 | [Start Here: How This Course Works and Setting Up Your Lab](00-start-here/) | Orientation | 2–3 h | 1 |
| 01 | [What Is a PLC?](01-what-is-a-plc/) | 1 Foundations | 6–8 h | 2 |
| 02 | [Electrical Fundamentals and Field Devices](02-electrical-and-field-devices/) | 1 Foundations | 8–10 h | 3 |
| 03 | [Numbers, Data Types and Addressing](03-data-types-and-addressing/) | 1 Foundations | 8–10 h | 3 |
| 04 | [Ladder Logic Fundamentals](04-ladder-logic/) | 2 Core programming | 8–10 h | 4 |
| 05 | [Boolean Logic, Truth Tables and Function Block Diagram](05-boolean-logic-and-fbd/) | 2 Core programming | ~8 h | 3 |
| 06 | [Edge Detection, One-Shots and Latching Patterns](06-edges-and-one-shots/) | 2 Core programming | ~7 h | 3 |
| 07 | [Timers](07-timers/) | 2 Core programming | ~10 h | 5 |
| 08 | [Counters](08-counters/) | 2 Core programming | ~7 h | 3 |
| 09 | [Maths, Comparison, Data Movement and Bit Manipulation](09-math-and-data-handling/) | 2 Core programming | ~10 h | 3 |
| 10 | [Structured Text in Depth](10-structured-text/) | 3 Structured programming | ~10 h | 4 |
| 11 | [Program Organisation and Reusable Function Blocks](11-program-organization/) | 3 Structured programming | ~12 h | 3 |
| 12 | [Data Structures: Arrays, Structures and Enumerations](12-data-structures/) | 3 Structured programming | ~10 h | 3 |
| 13 | [Sequential Control: State Machines and SFC](13-sequential-control/) | 3 Structured programming | ~12 h | 3 |
| 14 | [Analog Signals and Process I/O](14-analog-and-process-io/) | 3 Structured programming | 10–12 h | 3 |
| 15 | [PID and Closed-Loop Control](15-pid-control/) | 4 Advanced | ~14 h | 3 |
| 16 | [Alarms, Diagnostics and Fault Handling](16-alarms-and-diagnostics/) | 4 Advanced | 10–12 h | 3 |
| 17 | [Industrial Communications and Networks](17-industrial-communications/) | 4 Advanced | 12–14 h | 3 |
| 18 | [HMI and SCADA Integration](18-hmi-and-scada/) | 4 Advanced | ~10 h | 2 |
| 19 | [Motion Control, Drives and Positioning](19-motion-and-drives/) | 4 Advanced | 10–12 h | 2 |
| 20 | [Functional Safety, Safety PLCs and Cause-and-Effect](20-functional-safety/) | 5 Professional practice | 12–14 h | 2 |
| 21 | [Architecture, Industry Standards and Design Patterns](21-architecture-and-standards/) | 5 Professional practice | ~14 h | 2 |
| 22 | [Software Engineering for PLCs](22-software-engineering/) | 5 Professional practice | ~12 h | 2 |
| 23 | [Commissioning, Troubleshooting and Maintenance](23-commissioning-and-troubleshooting/) | 5 Professional practice | ~12 h | 3 |
| 24 | [Capstone Projects](24-capstone-projects/): conveyor sorting cell, batch mixing plant, wastewater pump station | Capstone | 25–40 h each | 3 |

**Appendices:**
[A — Vendor cross-reference](appendices/A-vendor-cross-reference.md) (IEC ↔ Siemens ↔ Rockwell and others) ·
[B — Glossary](appendices/B-glossary.md) ·
[C — Study plan and self-assessment](appendices/C-study-plan-and-self-assessment.md) ·
[D — Resources, standards and certifications](appendices/D-resources-and-certifications.md) ·
[E — MATIEC, OpenPLC and the test runner](appendices/E-matiec-openplc-notes.md)

The whole course is about 290 hours including one capstone: roughly 40 weeks at 7 hours a
week, or 20 weeks at 15 hours a week. See
[Appendix C](appendices/C-study-plan-and-self-assessment.md) for week-by-week plans.

## How each module works

- **The lesson** (`README.md`): concepts, diagrams, worked examples, common mistakes, vendor
  notes, and "Check your understanding" questions with hidden answers.
- **The labs** (`labs/`): small, realistic control problems. For each lab:
  - `starter/…st` has the variables declared; you write the logic.
  - `…test` is an acceptance test that checks your program automatically.
  - `solutions/…st` is a reference answer. Look only after you've tried.

You can do the labs two ways:

- **In OpenPLC Editor (or CODESYS):** draw or type the logic, run the simulator, and check each
  numbered requirement from the lab sheet by changing the inputs yourself.
- **With the automatic tester `plctest`** (Linux, macOS, or Windows via WSL): it runs your
  program in a simulated PLC and reports every requirement that passes or fails. Setup is in
  [Module 00](00-start-here/).

## What's in the box

- A start-here module, 23 teaching modules, 3 capstone projects and 5 appendices.
- 68 labs and 3 capstone acceptance tests. Every reference solution passes its tests, and every
  starter fails them (except the refactoring lab in Module 22, whose legacy starter is meant
  to pass), which proves the tests really check the logic. Every lab file also compiles with
  the OpenPLC Runtime's own compiler.
- Each module was written, then independently reviewed. Reviewers checked facts against vendor
  documentation and standards, and tried hundreds of deliberately wrong solutions against the
  tests. The tests were tightened until they caught them.

To re-run all the checks yourself (after the setup in Module 00):

```bash
cd plc-course
python3 tools/plctest.py --all .
```

## A word on safety

The labs are simulations. When you work on real equipment, follow your site's rules
(isolation, lock-out/tag-out, permits) and never test new logic on running plant without an
approved plan. A standard PLC is not a safety system: [Module 20](20-functional-safety/)
explains why, and what is used instead. The safety-related labs are training exercises, not
designs for real safety functions.

## For contributors

[tools/AUTHORING.md](tools/AUTHORING.md) describes the house style, the lab and test
conventions, and the MATIEC restrictions every lab file must respect.
