# Appendix C — Study Plan and Self-Assessment

This appendix turns the course into a plan you can follow and gives you a way to check your
progress. It covers how to study each module, three week-by-week plans for different amounts
of spare time, a milestone and a self-assessment checklist for each level, an index of every
lab, what to put in a portfolio, and how to reorder the later modules for process plant or
for machine work.

All the times come from the estimate at the top of each module. They include the reading,
the "Check your understanding" questions and the labs. Treat them as a guide: a module can
go faster because you already know the plant side, or slower because the programming idea is
new to you.

## C.1 How to study

### C.1.1 The loop for every module

The same five steps work for every module:

1. **Read the lesson.** At each worked example, predict what the logic will do before you
   read the explanation.
2. **Quiz yourself.** Answer each "Check your understanding" question in writing before you
   open the answer. Put every question you get wrong on a review list (C.1.3).
3. **Do the labs** using the [lab workflow](../00-start-here/README.md#the-lab-workflow) from
   Module 00. Read the whole specification and interface table, then sketch: rungs on paper
   for a ladder lab, a state diagram for a sequence. Open the hint only after a real attempt.
4. **Compare** with the reference solution once yours passes. Look for differences in
   design, not just in code, and note one thing you would adopt.
5. **Write your own tests.** Copy the lab's `.test` file into `my-work/` and add at least one
   scenario to the copy: a "must not" case, a boundary value, or the bug you made on the way
   (see
   [Writing your own tests](../00-start-here/README.md#writing-your-own-tests)). From Level 2
   on, also make a deliberately wrong copy of your solution and check that the tests catch
   it. [Lab 22-1](../22-software-engineering/README.md#lab-22-1-write-the-tests-dry-run-trip)
   turns this habit into mutation testing.

A lab is finished when it passes, you have checked every numbered requirement yourself, you
have compared it with the reference, and it is in your log.

### C.1.2 OpenPLC Editor or `plctest`?

You have two ways to run a lab, and they do different jobs. The OpenPLC Editor's built-in
simulator lets you *see* the logic: ladder wires light up where power flows, and you change
inputs in the debugger. `plctest` *tests* the logic: it runs every scenario in the
acceptance test, including the timing checks and the things that must not happen, the same
way every time.

| Job | Best tool | Why |
|---|---|---|
| Learning Ladder and FBD (Modules 04–08) | Editor simulator first, then `plctest` on the ST version | You watch power flow rung by rung, then run the full acceptance test |
| Deciding that a lab is finished | `plctest`, plus your own check of the numbered requirements | It runs every scenario, including timing checks just before and just after each preset |
| A ladder program you drew | Editor simulator, and `plctest` too if your Editor version lets you save the generated ST ([Module 00](../00-start-here/README.md#testing-ladder-you-drew-in-openplc-editor)) | The test uses variable names, so keep the lab's names |
| SFC (Lab 13-3) | Textual SFC with `plctest`, or CODESYS | [Module 13, section 3.11](../13-sequential-control/README.md#311-graphical-sfc-openplc-editor-and-codesys) explains the options |
| Capstones | `plctest` | Several hundred checks: far too many to do by hand |

On Windows, the Editor runs directly and `plctest` runs in WSL. WSL can see your Windows
drives (under `/mnt/c/…`), so keep one copy of the course where both tools can reach it. If
you clone it, do so from the WSL terminal: Git for Windows may convert the files to Windows
line endings, which stops `tools/setup-matiec.sh` from running.

A good rhythm: in Modules 04–08, draw every lab in the Editor *and* pass it with `plctest`.
Module 09's labs are Structured Text functions and calculations, and from Level 3 on most labs
are Structured Text function blocks, so from then on let `plctest` do most of the checking.

### C.1.3 Spaced repetition

Cramming works for a week. To still know this at an interview a year from now, come back to
material at growing intervals:

- **Open each session with ten minutes of review.** Answer three to five "Check your
  understanding" questions from earlier modules: one from last week, one from last month and
  one from further back.
- **Keep a review list.** A question you got wrong comes back after about a day, a week and a
  month. Drop it when you have answered it correctly at two separate reviews.
- **Redo labs cold.** About a month after finishing a level, redo two of its labs from a
  fresh starter, without notes or the solution. Good candidates: 02-1 and 03-1 (Level 1),
  04-2 and 07-3 (Level 2), 11-1 and 13-2 (Level 3), 16-1 and 18-1 (Level 4), 20-2 and 23-3
  (Level 5). Where you stall is what to review.
- **Use flashcards for vocabulary:** terms from [Appendix B](B-glossary.md) and vendor
  equivalents from [Appendix A](A-vendor-cross-reference.md) (`.DN`, 27648, `TONR`).

The plans in C.3 set aside two hours at the end of each level for this review and for the
milestone check in C.4.

### C.1.4 Keep a learning log in git

Module 00 suggests a `my-work/` folder for your lab files. Add a log file next to them,
`my-work/LOG.md`, and commit both at the end of every session. You can then see your
progress and go back to any earlier solution, and the log becomes the raw material for
write-ups, interview answers and, later, a professional competence log
([section D.6.7](D-resources-and-certifications.md#d67-professional-registration-uk)).

A log entry needs only a few lines:

```text
## 2026-10-14 · 2 h · Module 06
Did:      Lab 06-1 passes. Added a scenario: button held for 5 s toggles only once.
Stuck on: the lamp flickered while the button was held. I toggled on the level, not the edge.
Learned:  a toggle needs a one-shot; the "previous value" update goes last.
Review:   Module 04 Q3 (wrong again), Module 05 Q6
Next:     Lab 06-2
```

Then commit, and tag each milestone so that you can find it later:

```bash
git add my-work
git commit -m "Lab 06-1 passes; add held-button scenario"
git tag level-2-done            # once, at the Level 2 milestone
```

Push to a private remote repository as a backup. [Module 22](../22-software-engineering/)
covers version control properly. This is the same habit at a small scale.

## C.2 How long it takes

| Level | Modules | Labs | Time (module estimates) |
|---|---|---|---|
| Orientation | 00 | 1 | 2–3 h |
| 1 — Foundations | 01–03 | 8 | 22–28 h |
| 2 — Core programming | 04–09 | 21 (2 optional) | 50–52 h |
| 3 — Structured programming | 10–14 | 16 | 54–56 h |
| 4 — Advanced | 15–19 | 13 | 56–62 h |
| 5 — Professional practice | 20–23 | 9 | 50–52 h |
| **Modules 00–23** | | **68** | **234–253 h** |
| Capstones | 24-1, 24-2, 24-3 | 3 | 25–35 h, 25–35 h, 30–40 h |

The plans below take the middle of each module's range (about 244 hours in all), add a
two-hour review at the end of each level (10 hours) and one capstone at about 36 hours
including the write-up. That comes to about **290 hours**. A second capstone adds another
25–40 hours, depending on which you choose. You don't have to do all three
([Module 24](../24-capstone-projects/README.md#the-three-projects) helps you choose).

What that means in calendar time:

| Hours a week | Weeks to finish (about 290 h) | Notes |
|---|---|---|
| 24 | about 12 | Close to full-time study |
| 15 | about 20 | Plan A |
| 12 | about 24 | |
| 7 | about 42 | Plan B |
| 4 | about 73 | Plan C |

None of the plans includes holidays, illness or busy weeks at work. Add a spare week every
eight to ten weeks. If a module takes longer than planned, let the dates slip rather than
skipping labs.

## C.3 Three study plans

Each plan keeps the modules in order and includes one capstone. If you want the process or
machine order from C.8, rearrange the Level 4, Level 5 and capstone rows to match: the hours
per module stay the same, so the total doesn't change. Hours are shown in brackets.

### C.3.1 Plan A — Intensive: about 15 hours a week, 20 weeks

For a career break, a gap between jobs or an employer-supported study block. A workable week
is three two-hour evenings plus two weekend sessions of 4½ hours.

| Week | Study (hours) | Labs to finish | Checkpoint |
|---|---|---|---|
| 1 | 00 (3) · 01 (7) · start 02 (5) | 00-1, 01-1, 01-2 | Tools installed and checked (Module 00) |
| 2 | finish 02 (4) · 03 (9) · Level 1 review (2) | 02-1 to 02-3, 03-1 to 03-3 | **Level 1 milestone** |
| 3 | 04 (9) · start 05 (6) | 04-1 to 04-4 | Each 04 lab drawn in the Editor too |
| 4 | finish 05 (2) · 06 (7) · start 07 (6) | 05-1 to 05-3, 06-1 to 06-3 | |
| 5 | finish 07 (4) · 08 (7) · start 09 (4) | 07-1 to 07-5, 08-1 to 08-3 | |
| 6 | finish 09 (6) · Level 2 review (2) · start 10 (7) | 09-1 to 09-3 | **Level 2 milestone** |
| 7 | finish 10 (3) · 11 (12) | 10-1 to 10-4, 11-1 to 11-3 | |
| 8 | 12 (10) · start 13 (5) | 12-1 to 12-3 | |
| 9 | finish 13 (7) · start 14 (8) | 13-1 to 13-3 | |
| 10 | finish 14 (3) · Level 3 review (2) · start 15 (10) | 14-1 to 14-3 | **Level 3 milestone** |
| 11 | finish 15 (4) · 16 (11) | 15-1 to 15-3, 16-1 to 16-3 | |
| 12 | 17 (13) · start 18 (2) | 17-1 to 17-3 | |
| 13 | finish 18 (8) · start 19 (7) | 18-1, 18-2 | |
| 14 | finish 19 (4) · Level 4 review (2) · start 20 (9) | 19-1, 19-2 | **Level 4 milestone** |
| 15 | finish 20 (4) · start 21 (11) | 20-1, 20-2 | |
| 16 | finish 21 (3) · 22 (12) | 21-1, 21-2, 22-1, 22-2 | |
| 17 | 23 (12) · Level 5 review (2) · read the capstone brief (1) | 23-1 to 23-3 | **Level 5 milestone** |
| 18 | Capstone: design, then milestones M1–M3 (15) | | Commit after each milestone |
| 19 | Capstone: M4–M6 (15) | | |
| 20 | Capstone: remaining milestones, full FAT, compare, write-up (5) · spare (10) | 24-1, 24-2 or 24-3 | **Capstone milestone** |
| 21–22 | *Optional:* a second capstone (about 32), starting in the spare hours of week 20 | | |

At this pace the review time is the first thing to go. Protect it: it is what makes
15 hours a week stick.

### C.3.2 Plan B — Standard: about 7 hours a week, 42 weeks

For most people in full-time work. A workable week is two 1½-hour evenings plus one 4-hour
weekend session, which gives the labs an unbroken block. Where one row ends and the next
starts in the same week, finish the first module before you start the next.

| Weeks | Study (hours) | Labs to finish | Checkpoint |
|---|---|---|---|
| 1–2 | 00 (3) · 01 (7) | 00-1, 01-1, 01-2 | Tools installed |
| 2–4 | 02 (9) · 03 (9) | 02-1 to 02-3, 03-1 to 03-3 | |
| 5 | Level 1 review (2) | | **Level 1 milestone** |
| 5–6 | 04 (9) | 04-1 to 04-4 | |
| 6–8 | 05 (8) · 06 (7) | 05-1 to 05-3, 06-1 to 06-3 | |
| 8–10 | 07 (10) | 07-1 to 07-5 | |
| 10–12 | 08 (7) · 09 (10) · Level 2 review (2) | 08-1 to 08-3, 09-1 to 09-3 | **Level 2 milestone** |
| 12–15 | 10 (10) · 11 (12) | 10-1 to 10-4, 11-1 to 11-3 | |
| 16–17 | 12 (10) | 12-1 to 12-3 | |
| 17–19 | 13 (12) | 13-1 to 13-3 | |
| 19–20 | 14 (11) · Level 3 review (2) | 14-1 to 14-3 | **Level 3 milestone** |
| 21–22 | 15 (14) | 15-1 to 15-3 | |
| 23–24 | 16 (11) | 16-1 to 16-3 | |
| 24–26 | 17 (13) | 17-1 to 17-3 | |
| 26–27 | 18 (10) | 18-1, 18-2 | |
| 27–29 | 19 (11) · Level 4 review (2) | 19-1, 19-2 | **Level 4 milestone** |
| 29–31 | 20 (13) | 20-1, 20-2 | |
| 31–33 | 21 (14) | 21-1, 21-2 | |
| 33–35 | 22 (12) | 22-1, 22-2 | |
| 35–37 | 23 (12) · Level 5 review (2) | 23-1 to 23-3 | **Level 5 milestone** |
| 37–42 | One capstone (about 36, with the write-up) | 24-1, 24-2 or 24-3 | **Capstone milestone** |
| 42–46 | *Optional:* a second capstone (about 32) | | |

### C.3.3 Plan C — Part-time: about 4 hours a week, 73 weeks

For busy periods. Two 2-hour sessions a week work better than four 1-hour ones, because a
lab needs time to get into. That is about 17 months of study weeks, so with holidays plan on
a year and a half or a little more. The end of Level 3 (week 35) is a natural place to pause
if you need to: by then you have the programming core.

| Weeks | Study (hours) | Labs to finish | Checkpoint |
|---|---|---|---|
| 1–3 | 00 (3) · 01 (7) | 00-1, 01-1, 01-2 | Tools installed |
| 3–5 | 02 (9) | 02-1 to 02-3 | |
| 5–7 | 03 (9) | 03-1 to 03-3 | |
| 8 | Level 1 review (2) | | **Level 1 milestone** |
| 8–10 | 04 (9) | 04-1 to 04-4 | |
| 10–12 | 05 (8) | 05-1 to 05-3 | |
| 12–14 | 06 (7) | 06-1 to 06-3 | |
| 14–16 | 07 (10) | 07-1 to 07-5 | |
| 17–18 | 08 (7) | 08-1 to 08-3 | |
| 18–21 | 09 (10) · Level 2 review (2) | 09-1 to 09-3 | **Level 2 milestone** |
| 21–24 | 10 (10) | 10-1 to 10-4 | |
| 24–27 | 11 (12) | 11-1 to 11-3 | |
| 27–29 | 12 (10) | 12-1 to 12-3 | |
| 29–32 | 13 (12) | 13-1 to 13-3 | |
| 32–35 | 14 (11) · Level 3 review (2) | 14-1 to 14-3 | **Level 3 milestone** |
| 36–39 | 15 (14) | 15-1 to 15-3 | |
| 39–42 | 16 (11) | 16-1 to 16-3 | |
| 42–45 | 17 (13) | 17-1 to 17-3 | |
| 45–47 | 18 (10) | 18-1, 18-2 | |
| 48–51 | 19 (11) · Level 4 review (2) | 19-1, 19-2 | **Level 4 milestone** |
| 51–54 | 20 (13) | 20-1, 20-2 | |
| 54–57 | 21 (14) | 21-1, 21-2 | |
| 58–60 | 22 (12) | 22-1, 22-2 | |
| 61–64 | 23 (12) · Level 5 review (2) | 23-1 to 23-3 | **Level 5 milestone** |
| 64–73 | One capstone (about 36, with the write-up) | 24-1, 24-2 or 24-3 | **Capstone milestone** |

### C.3.4 When you fall behind

- **Let the plan slip, not the labs.** A module read without its labs teaches far less than
  one with them.
- **Cap the time on a stuck lab.** If a lab has taken twice its share of the module's time,
  open the hint, then the solution, and put "redo from the starter" on your review list for
  the following week.
- **Re-plan at each milestone**, not every week.
- **Changing plan is normal.** The hours per module are the same in every plan, so find the
  module you have reached in the slower (or faster) table and carry on from there.

## C.4 Milestones: ready to move on?

Use the review block at the end of each level to check yourself against its milestone.

| Milestone | You are ready to move on when… |
|---|---|
| **Set-up** (00) | `python3 tools/plctest.py --all .` gives the results Module 00 describes; your own Lab 00-1 passes; if you use the OpenPLC Editor, you have drawn 00-1 in Ladder and checked all six requirements in the simulator (optional in Module 00, but worth it); `my-work/` and your log exist and are committed. |
| **Level 1** (01–03) | All eight labs pass. You can answer about eight in ten of the "Check your understanding" questions in 01–03 without opening the answers. You can draw a scan-cycle timing diagram for an input that changes mid-scan, explain what a broken wire on an NC stop button does, and convert between decimal, hex, binary and BCD on paper. |
| **Level 2** (04–09) | All the core labs pass (04-4 and 07-5 are optional). From a blank file and without notes, you can write a stop-dominant seal-in, a `TON` feedback timeout with a latched fault, and an edge-triggered count. You can sketch `TON`, `TOF` and `TP` timing diagrams from memory. You have redone two Level 1 labs cold (C.1.3). |
| **Level 3** (10–14) | All labs pass. You can turn a paragraph of operating description into a state diagram and then a `CASE` state machine. You have written a device FB that someone else could use from its interface and comments alone. You can explain what your `FB_AnalogInput` does on a wire break, and why. |
| **Level 4** (15–19) | All labs pass. You can explain anti-windup and bumpless transfer in your own words. For each Level 4 lab you can say what goes wrong on a real plant without that logic: a chattering alarm, a stale value from a dead link, an HMI command acted on twice. |
| **Level 5** (20–23) | All labs pass. Your Lab 22-1 test kills all six mutants, and you have a fault record for every bug in 23-1 and 23-2. You can explain to a non-specialist why the course's trip labs are not safety systems, and walk through testing a cause-and-effect matrix mark by mark and blank by blank. |
| **Capstone** | The full FAT passes. You have scored yourself against the brief's marking rubric, compared your design with the reference, tried one extension and written the project up (C.7). |

## C.5 Self-assessment checklists

Tick a box only when you could do it now, without notes, with someone watching. Copy this
section into your log and revisit it at each milestone. The module in brackets is where to go
back to for any box you can't tick yet.

### Level 1 — Foundations

- [ ] I can describe the four steps of the scan cycle and show when an input change reaches an output. (01)
- [ ] I can find and fix an output written in two places ("last write wins"). (01)
- [ ] I can explain why stop buttons, e-stops and overloads are wired normally-closed, and what the PLC sees when a wire breaks. (02)
- [ ] I can read a loop diagram and an I/O drawing, and trace a 4–20 mA signal to the PLC input. (02)
- [ ] I can explain NAMUR line-fault detection and what the logic should do with a faulted signal. (02)
- [ ] I can convert between decimal, binary, hex and BCD by hand, and state the range of the common integer types. (03)
- [ ] I can pack and unpack bits in a `WORD` with shifts and masks. (03)
- [ ] I can decide which data should be retentive, and predict what a warm or cold restart does to it. (03)

### Level 2 — Core programming

- [ ] I can explain why an NC stop button is programmed with a normally-open contact, write a stop-dominant seal-in with several stations, and fix a double-coil bug. (04)
- [ ] I can design a reversing starter with interlocks and travel limits, and explain why a software interlock never replaces an electrical one. (04)
- [ ] I can reduce a truth table with a Karnaugh map, tell permissives, interlocks and trips apart, and implement 2oo3 voting. (05)
- [ ] I can write edge detection by hand and with `R_TRIG`/`F_TRIG`, and avoid the conditional-call trap. (06)
- [ ] I can draw `TON`, `TOF` and `TP` timing diagrams and apply the three timer rules. (07)
- [ ] I can supervise a motor with a feedback timeout, a latched fault and a reset that never restarts it. (07)
- [ ] I can use `CTU`, `CTD` and `CTUD`, and design shift and lifetime counts that never lose a count. (08)
- [ ] I can predict integer division, `MOD` and overflow results, and compare `REAL` values with a tolerance. (09)
- [ ] I can write a scaling function that clamps and survives a zero span, and a totaliser that keeps its precision. (09)

### Level 3 — Structured programming

- [ ] I can write ST with `IF`, `CASE`, `FOR`, `WHILE` and `REPEAT`, keep every loop bounded within one scan, and protect every array index. (10)
- [ ] I can choose between `PROGRAM`, `FUNCTION_BLOCK` and `FUNCTION`, and say what an FB instance remembers between scans. (11)
- [ ] I can design a reusable device FB with commands, feedback, parameters, status and latched faults, in a project with one writer for every output. (11)
- [ ] I can design a `Cmd`/`Sts`/`Cfg`/`Alm` data model and process several devices from an array of structures. (12)
- [ ] I can write a `CASE` state machine with a step timer, watchdogs, a fault state, Hold/Resume and Abort. (13)
- [ ] I can read and write SFC, and choose the right action qualifier. (13)
- [ ] I can scale a 4–20 mA input, detect NE43 faults, filter it, and choose between hold and substitute on a fault. (14)
- [ ] I can write HH/H/L/LL alarms with a deadband and an on-delay, and on/off control with hysteresis. (14)

### Level 4 — Advanced

- [ ] I can estimate a first-order-plus-dead-time model from a step test, and explain what P, I and D each do. (15)
- [ ] I can write a PID block with output limits, anti-windup and bumpless transfer, and tune it with lambda rules. (15)
- [ ] I can write an alarm block with acknowledge and reset on edges, build a first-out annunciator, and remedy a chattering alarm. (16)
- [ ] I can write heartbeat and frozen-signal diagnostics. (16)
- [ ] I can convert between Modbus documented register numbers and protocol addresses, and handle 32-bit values in either word order. (17)
- [ ] I can supervise a communication link and fall back to safe values when it is lost. (17)
- [ ] I can write an HMI command handshake with reject codes and validated setpoints, and Off/Manual/Auto mode logic. (18)
- [ ] I can explain VFD starting and ramps, decode a quadrature encoder, and write two-speed positioning with an in-position window. (19)

### Level 5 — Professional practice

- [ ] I can explain why a standard PLC is not relied on for a safety function, and say which standards use SIL and which use PL. (20)
- [ ] I can implement trip latching with a reset that never restarts anything, and controlled, time-limited bypasses. (20)
- [ ] I can implement a cause-and-effect matrix and test every mark and every blank. (20)
- [ ] I can describe the ISA-88 and PackML state models and write an equipment phase with Hold and Abort. (21)
- [ ] I can write tests that kill realistic mutants, refactor under a characterisation test, and trace a requirement from specification to its FAT test. (22)
- [ ] I can plan a point-to-point I/O checkout and a loop check, and say what FAT and SAT each prove. (23)
- [ ] I can find a bug from a failing test with a structured method, fix the root cause and record it. (23)

### Capstone

- [ ] I have read a brief twice, designed before coding and built it milestone by milestone. (24)
- [ ] The full FAT passes, and I have added at least one test of my own. (24)
- [ ] I have scored my work against the rubric and compared designs with the reference. (24)
- [ ] I have written the project up so that a stranger could follow my design decisions. (24, [D.7](D-resources-and-certifications.md#d7-building-a-portfolio))

## C.6 Lab index

Every lab in the course; each title links to the lab's section in its module, and each
capstone to its brief. Labs 04-4 and 07-5 are optional. Four labs work differently: in
Lab 22-1 the program is given and **you write the test** (its starter is
`labs/starter/22-1-dry-run-trip.test`), in Lab 22-2 the legacy starter passes its test on
purpose because the job is to refactor it, and in Labs 23-1 and 23-2 the starter is a
complete program with three bugs to find.

| Module | Lab | Title | Key skills |
|---|---|---|---|
| 00 | 00-1 | [Hello PLC](../00-start-here/README.md#lab-00-1-hello-plc) | Seal-in, NC stop, first `plctest` run |
| 01 | 01-1 | [Lamps and switches](../01-what-is-a-plc/README.md#lab-01-1-lamps-and-switches) | NOT/AND/OR, lamp test, the lab workflow |
| 01 | 01-2 | [Last write wins](../01-what-is-a-plc/README.md#lab-01-2-last-write-wins) | Scan cycle, an output written twice, HAND-OFF-AUTO |
| 02 | 02-1 | [Fail-safe motor circuit](../02-electrical-and-field-devices/README.md#lab-02-1-fail-safe-motor-circuit) | NC stop and overload, no automatic restart |
| 02 | 02-2 | [Single-solenoid versus double-solenoid valves](../02-electrical-and-field-devices/README.md#lab-02-2-single-solenoid-versus-double-solenoid-valves) | Fail-closed versus fail-last valves, high-high level interlock |
| 02 | 02-3 | [NAMUR level switch with line-fault detection](../02-electrical-and-field-devices/README.md#lab-02-3-namur-level-switch-with-line-fault-detection) | Line-fault status bits, safe substitution, latched fault |
| 03 | 03-1 | [Status word and command word](../03-data-types-and-addressing/README.md#lab-03-1-status-word-and-command-word) | Bits in a `WORD`, masks and shifts, rejecting invalid words |
| 03 | 03-2 | [BCD display and thumbwheel](../03-data-types-and-addressing/README.md#lab-03-2-bcd-display-and-thumbwheel) | Binary to BCD and back, clamping, invalid digits |
| 03 | 03-3 | [Temperature in tenths (integer versus REAL maths)](../03-data-types-and-addressing/README.md#lab-03-3-temperature-in-tenths-integer-versus-real-maths) | Fixed-point to `REAL`, rounding, overflow, sensor-fault value |
| 04 | 04-1 | [Start/stop from two stations](../04-ladder-logic/README.md#lab-04-1-startstop-from-two-stations) | Stop-dominant seal-in, parallel starts, series NC stops |
| 04 | 04-2 | [Forward/reverse motor with interlocks](../04-ladder-logic/README.md#lab-04-2-forwardreverse-motor-with-interlocks) | Software interlock, stop before reversing, travel limits |
| 04 | 04-3 | [Jog/run selector](../04-ladder-logic/README.md#lab-04-3-jogrun-selector) | A jog that can never seal in |
| 04 | 04-4 | [Tank fill valve with set/reset (optional)](../04-ladder-logic/README.md#lab-04-4-tank-fill-valve-with-setreset-optional) | Set/reset coils, latch dominance, power-up state, switch cross-check |
| 05 | 05-1 | [Transfer pump start permissive](../05-boolean-logic-and-fbd/README.md#lab-05-1-transfer-pump-start-permissive) | Specification to logic, mixed input polarities, a failed selector |
| 05 | 05-2 | [Two-out-of-three pressure trip vote](../05-boolean-logic-and-fbd/README.md#lab-05-2-two-out-of-three-pressure-trip-vote) | 2oo3 voting, de-energise to trip, discrepancy (training only) |
| 05 | 05-3 | [From truth table to minimal logic: wet-well alarm horn](../05-boolean-logic-and-fbd/README.md#lab-05-3-from-truth-table-to-minimal-logic-wet-well-alarm-horn) | Karnaugh map, minimal logic, what the logic means |
| 06 | 06-1 | [One-button floodlight toggle](../06-edges-and-one-shots/README.md#lab-06-1-one-button-floodlight-toggle) | Push-on/push-off, the conditional-call trap |
| 06 | 06-2 | [Carton and product-change counter](../06-edges-and-one-shots/README.md#lab-06-2-carton-and-product-change-counter) | Counting rising edges and changes of value |
| 06 | 06-3 | [Duty-standby pump alternation](../06-edges-and-one-shots/README.md#lab-06-3-duty-standby-pump-alternation) | Alternation on each new demand, fault fallback |
| 07 | 07-1 | [Star-delta starter](../07-timers/README.md#lab-07-1-star-delta-starter) | Contactor sequencing, dead time between star and delta |
| 07 | 07-2 | [Flasher beacon](../07-timers/README.md#lab-07-2-flasher-beacon) | Oscillator with separate on and off times |
| 07 | 07-3 | [Motor with run-feedback monitoring](../07-timers/README.md#lab-07-3-motor-with-run-feedback-monitoring) | Feedback timeouts, latched faults, safe reset |
| 07 | 07-4 | [Accumulating run-hours meter](../07-timers/README.md#lab-07-4-accumulating-run-hours-meter) | Retentive timing without drift or overflow |
| 07 | 07-5 | [Two-hand control timing (optional)](../07-timers/README.md#lab-07-5-two-hand-control-timing-optional) | Timing window, release both before re-cycling (not a safety design) |
| 08 | 08-1 | [Bottle packing](../08-counters/README.md#lab-08-1-bottle-packing) | Count to a preset, timed index, reset without lost counts |
| 08 | 08-2 | [Car park up/down counter](../08-counters/README.md#lab-08-2-car-park-updown-counter) | Up/down count, capacity, manual preset, counting past limits |
| 08 | 08-3 | [Production counts, yield and shift reset](../08-counters/README.md#lab-08-3-production-counts-yield-and-shift-reset) | Shift snapshot, yield as `REAL`, lifetime total |
| 09 | 09-1 | [A general scaling function (F_Scale)](../09-math-and-data-handling/README.md#lab-09-1-a-general-scaling-function-f_scale) | Linear scaling, clamping, reversed ranges, zero span |
| 09 | 09-2 | [Conveyor reject tracking with a shift register](../09-math-and-data-handling/README.md#lab-09-2-conveyor-reject-tracking-with-a-shift-register) | Bit shift register in a `WORD`, tracking by pitch pulses |
| 09 | 09-3 | [Flow totaliser](../09-math-and-data-handling/README.md#lab-09-3-flow-totaliser) | Integrating a rate, `REAL` precision over years |
| 10 | 10-1 | [Array statistics](../10-structured-text/README.md#lab-10-1-array-statistics) | `FOR` loops, minimum, maximum, average, index of the maximum |
| 10 | 10-2 | [Median filter](../10-structured-text/README.md#lab-10-2-median-filter) | History array, sorting a copy, sampling on an edge |
| 10 | 10-3 | [Tank strapping table](../10-structured-text/README.md#lab-10-3-tank-strapping-table) | Table search, linear interpolation, off-table values |
| 10 | 10-4 | [Alarm message text](../10-structured-text/README.md#lab-10-4-alarm-message-text) | String functions, formatting a number |
| 11 | 11-1 | [FB_Motor, used three times](../11-program-organization/README.md#lab-11-1-fb_motor-used-three-times) | Reusable device FB, instances, interlocks, proven running |
| 11 | 11-2 | [FB_Valve with limit switches and a fail position](../11-program-organization/README.md#lab-11-2-fb_valve-with-limit-switches-and-a-fail-position) | Limit-switch supervision, fail-closed and fail-open valves |
| 11 | 11-3 | [A function library and shared statistics with VAR_IN_OUT](../11-program-organization/README.md#lab-11-3-a-function-library-and-shared-statistics-with-var_in_out) | Library functions, `VAR_IN_OUT`, report-by-exception |
| 12 | 12-1 | [Recipe manager](../12-data-structures/README.md#lab-12-1-recipe-manager) | Array of structures, validation, loading in one piece |
| 12 | 12-2 | [Event log ring buffer](../12-data-structures/README.md#lab-12-2-event-log-ring-buffer) | Ring buffer of structures, newest index, overwriting the oldest |
| 12 | 12-3 | [Four pumps, one data model](../12-data-structures/README.md#lab-12-3-four-pumps-one-data-model) | Array of structures in a `FOR` loop, per-device timing |
| 13 | 13-1 | [Pedestrian crossing](../13-sequential-control/README.md#lab-13-1-pedestrian-crossing) | First `CASE` state machine, step timer, latched request |
| 13 | 13-2 | [Batch tank with watchdogs, Hold/Resume and Abort](../13-sequential-control/README.md#lab-13-2-batch-tank-with-watchdogs-holdresume-and-abort) | Watchdogs, fault codes, Hold/Resume, Abort, interlocks outside the sequence |
| 13 | 13-3 | [Drilling station in SFC](../13-sequential-control/README.md#lab-13-3-drilling-station-in-sfc) | Textual SFC, action qualifiers N, S, R, D, L and P |
| 14 | 14-1 | [Analog input block (FB_AnalogInput)](../14-analog-and-process-io/README.md#lab-14-1-analog-input-block-fb_analoginput) | Scaling, NE43 faults, filtering, quality, hold or substitute |
| 14 | 14-2 | [Analog alarm block (FB_AnalogAlarm)](../14-analog-and-process-io/README.md#lab-14-2-analog-alarm-block-fb_analogalarm) | HH/H/L/LL alarms, deadband, on-delay |
| 14 | 14-3 | [Sump pump level control](../14-analog-and-process-io/README.md#lab-14-3-sump-pump-level-control) | Hysteresis control, independent dry-run protection, transmitter failure |
| 15 | 15-1 | [FOPDT plant simulator](../15-pid-control/README.md#lab-15-1-fopdt-plant-simulator) | Process model with lag and dead time, sample time |
| 15 | 15-2 | [PID controller function block](../15-pid-control/README.md#lab-15-2-pid-controller-function-block) | Limits, anti-windup, direct/reverse action, bumpless transfer |
| 15 | 15-3 | [Cascade control of a steam heater](../15-pid-control/README.md#lab-15-3-cascade-control-of-a-steam-heater) | Cascade mode logic, setpoint, output and PV tracking |
| 16 | 16-1 | [Alarm block (FB_Alarm)](../16-alarms-and-diagnostics/README.md#lab-16-1-alarm-block-fb_alarm) | On-delay, latching, acknowledge and reset on edges, alarm states |
| 16 | 16-2 | [First-out annunciator](../16-alarms-and-diagnostics/README.md#lab-16-2-first-out-annunciator) | First-out, horn, acknowledge, reset, lamp test, run permissive |
| 16 | 16-3 | [Frozen-signal and heartbeat diagnostics](../16-alarms-and-diagnostics/README.md#lab-16-3-frozen-signal-and-heartbeat-diagnostics) | Frozen-value detection, heartbeat supervision |
| 17 | 17-1 | [Modbus register map](../17-industrial-communications/README.md#lab-17-1-modbus-register-map) | 32-bit values in two registers, word order, scaled integers |
| 17 | 17-2 | [Communication watchdog](../17-industrial-communications/README.md#lab-17-2-communication-watchdog) | Heartbeat, loss delay, fallback values, deliberate recovery |
| 17 | 17-3 | [Drive control word and status word](../17-industrial-communications/README.md#lab-17-3-drive-control-word-and-status-word) | Status decoding, fault-reset pulse, no restart on reset |
| 18 | 18-1 | [HMI command handshake](../18-hmi-and-scada/README.md#lab-18-1-hmi-command-handshake) | Act once and clear, reject codes, setpoint validation |
| 18 | 18-2 | [Mode manager](../18-hmi-and-scada/README.md#lab-18-2-mode-manager) | Off/Manual/Auto, Local/Remote, bumpless transfer, mode shedding |
| 19 | 19-1 | [Quadrature decoder (x4)](../19-motion-and-drives/README.md#lab-19-1-quadrature-decoder-x4) | x4 decoding, direction, illegal transitions, limits of a scanned input |
| 19 | 19-2 | [Simple two-speed positioning](../19-motion-and-drives/README.md#lab-19-2-simple-two-speed-positioning) | Fast and creep speeds, in-position window, stop and fault handling |
| 20 | 20-1 | [2oo3 pressure trip with degraded voting](../20-functional-safety/README.md#lab-20-1-2oo3-pressure-trip-with-degraded-voting) | NE43 bad quality, degraded voting, latch and reset (training only) |
| 20 | 20-2 | [Cause-and-effect matrix with first-out and bypasses](../20-functional-safety/README.md#lab-20-2-cause-and-effect-matrix-with-first-out-and-bypasses) | C&E logic, first-out, time-limited bypasses, the test as a test sheet |
| 21 | 21-1 | [PackML base state machine](../21-architecture-and-standards/README.md#lab-21-1-packml-base-state-machine) | 17 states, commands, legal and illegal transitions |
| 21 | 21-2 | [ISA-88 dosing phase](../21-architecture-and-standards/README.md#lab-21-2-isa-88-dosing-phase) | Equipment phase, Hold/Restart, Stop/Abort, command/state interface |
| 22 | 22-1 | [Write the tests (dry-run trip)](../22-software-engineering/README.md#lab-22-1-write-the-tests-dry-run-trip) | Writing acceptance tests, mutation testing |
| 22 | 22-2 | [Refactor safely (dosing skid)](../22-software-engineering/README.md#lab-22-2-refactor-safely-dosing-skid) | Refactoring into functions and FBs under a characterisation test |
| 23 | 23-1 | [Find the bugs](../23-commissioning-and-troubleshooting/README.md#lab-23-1-find-the-bugs) | Symptom, hypothesis, proof, fix; fault records |
| 23 | 23-2 | [Subtle faults](../23-commissioning-and-troubleshooting/README.md#lab-23-2-subtle-faults) | Faults that appear only under particular conditions |
| 23 | 23-3 | [I/O simulation layer](../23-commissioning-and-troubleshooting/README.md#lab-23-3-io-simulation-layer) | A simulation layer for FAT and I/O checkout, with safeguards |
| 24 | 24-1 | [Conveyor sorting cell](../24-capstone-projects/24-1-conveyor-sorting-cell.md) | Tracking, pushers, jams, alarms, stack light, HMI interface |
| 24 | 24-2 | [Batch mixing plant](../24-capstone-projects/24-2-batch-mixing-plant.md) | Recipes, dosing by flow totals, PID, ISA-88-style procedure |
| 24 | 24-3 | [Wastewater pump station](../24-capstone-projects/24-3-pump-station.md) | NE43 level, duty/assist/standby, starts per hour, SCADA register map |

## C.7 Portfolio and job readiness

### C.7.1 What to show

An interviewer wants evidence that you can turn a specification into working, tested,
maintainable logic. By the end of the course you can show:

1. **One capstone, finished properly:** the full FAT passing, a self-score against the rubric
   and one extension. Choose the one nearest the job you want
   ([Module 24](../24-capstone-projects/README.md#the-three-projects)).
2. **Tests you wrote yourself:** your Lab 22-1 test with its mutation score of 6/6, and the
   scenarios you added to lab tests along the way.
3. **Short write-ups:** a page or two per capstone covering the problem, your architecture,
   one design decision and one bug the tests caught
   ([section D.7](D-resources-and-certifications.md#d7-building-a-portfolio) gives a layout).
4. **Fault records** from Labs 23-1 and 23-2: symptom, root cause, fix, how verified.
5. **One lab in a vendor tool**, to show that you can move between dialects.
   [Appendix A](A-vendor-cross-reference.md#a13-translating-a-lab-between-tools-lab-07-1)
   walks through Lab 07-1 as an example.
6. **Your commit history and log**, which show how you work, not just what you finished.

Label everything honestly as training work, and say that any safety-related logic is an
exercise, not a design for a real safety function. Never publish an employer's or client's
code, drawings, specifications or tag lists, even "anonymised".

### C.7.2 What the course does and does not give you

The course gives you the programming foundations and evidence to show for them. It does not
replace experience on a particular vendor platform, time on site, or the safety training and
qualifications a role may require. Many job adverts name a platform: if you know which one
your target employer uses, redo a few labs in that vendor's software
([section D.1](D-resources-and-certifications.md#d1-free-software-and-simulators)).
Certifications and career paths are in
[section D.6](D-resources-and-certifications.md#d6-certifications-and-career-paths).

### C.7.3 Typical interview topics

Interviews vary with the employer and the role, but these themes come up often. Interviewers
tend to ask about decisions rather than syntax, so practise explaining *why*, out loud, with
your own lab and capstone work as examples.

| Topic | The kind of question you might meet | Modules |
|---|---|---|
| How a PLC runs | "What happens in one scan? What if an output is written in two places?" | 01, 04 |
| Fail-safe wiring | "Why is a stop button wired normally-closed? What does the PLC see if the wire breaks?" | 02, 04 |
| Basic circuits | "Draw a start/stop circuit. Which wins if both are pressed? How do you interlock a reversing starter?" | 04, 05 |
| Timers, counters and edges | "TON, TOF or TP for this job? Why does this toggle flicker?" | 06, 07, 08 |
| Numbers | "What is `16#FFFF` as a 16-bit signed integer? Why not compare two `REAL`s with `=`?" | 03, 09 |
| Analog signals | "Scale 4–20 mA to 0–10 bar. What does a reading of 3.6 mA tell you?" | 02, 09, 14 |
| Program structure | "When do you use a function block rather than a function? How would you build a reusable motor block?" | 11, 12 |
| Sequences | "How would you structure a batch sequence? What happens after a power cut halfway through?" | 13, 21 |
| Process control | "What does integral action do? What is windup?" | 15 |
| Alarms and faults | "How do you stop an alarm chattering? What should happen when a transmitter fails?" | 14, 16 |
| Communications | "Register 40001 or register 0? Why does my 32-bit value look like nonsense?" | 17 |
| HMI and SCADA | "How does a Start button on the HMI reach the motor, and what stops it acting twice?" | 18 |
| Drives | "What does a VFD ramp do? What is STO?" | 19 |
| Functional safety | "Why shouldn't a standard PLC be relied on for the emergency stop? What is the difference between SIL and PL?" | 20 |
| Working practice | "How do you know which version is running in the PLC? How would you test a change before it goes to site?" | 22 |
| Fault-finding | "A pump won't start. Walk me through how you would find out why." | 23 |
| Vendor platforms | "Have you used TIA Portal or Studio 5000? Where does a Siemens FB keep its data?" | 11, [Appendix A](A-vendor-cross-reference.md) |

## C.8 Adjusting the order for your kind of work

The course order works for everyone. If you already know where you are heading, you can
reorder Levels 4 and 5 without breaking the stated prerequisites of Modules 15–23. The one
rule bent is in the process route, where Module 19 comes after capstones 24-3 and 24-2
(C.8.1 explains why). Keep Levels 1–3 in order: they are the programming core, and each
module builds on earlier ones.

### C.8.1 Process plant, instrumentation and safety systems

If you already work with loop drawings, IS barrier schedules and cause-and-effect matrices,
this is your route.

| Order | Module | Why here |
|---|---|---|
| 1 | 15 PID | The loops you already see on P&IDs; needs only 09, 11 and 14 |
| 2 | 16 Alarms and diagnostics | Required by 20; ISA-18.2 alarm management |
| 3 | 20 Functional safety | Its prerequisites (05, 07, 14, 16) are now done, and it is closest to your day job |
| 4 | 17 Communications | Required by 18 and by the pump-station capstone |
| 5 | 18 HMI and SCADA | The control-room interface |
| 6 | 22 Software engineering | Testing, version control and change management; required by 23 |
| 7 | 23 Commissioning | Loop checks, C&E testing, fault-finding |
| 8 | Capstone 24-3 | The pump station: NE43 level, alarms, a SCADA register map |
| 9 | 21 Architecture | ISA-88 before the batch capstone |
| 10 | Capstone 24-2 (a second capstone) | The batch plant: recipes, PID and an ISA-88-style procedure |
| 11 | 19 Motion and drives | Last, or before 24-1 if you do it |

The capstone briefs list Levels 1–4 (Modules 01–19) as prerequisites. Neither 24-2 nor 24-3
names Module 19 among the modules it relies on most, so moving 19 after them is a reasonable
trade. Do 19 before 24-1, which does rely on it.

Along the way:

- **Module 02** sections [5](../02-electrical-and-field-devices/README.md#5-reading-electrical-and-instrument-drawings)
  to [7](../02-electrical-and-field-devices/README.md#7-hazardous-areas-for-plc-people)
  (drawings, analog signals, hazardous areas) will be familiar, so read them quickly. Still do
  all three labs: Lab 02-3 is the PLC side of the NAMUR signals you already know.
- **Preview Module 20** by reading
  [section 20.1](../20-functional-safety/README.md#201-why-a-standard-plc-is-not-a-safety-system)
  when you reach Lab 05-2. It frames every trip-like lab that follows.
- **Pick your cold redos from these labs:** 02-3, 05-2, 06-3, 09-1, 09-3, 10-3, 11-2, 14-1,
  14-3, 16-2, 17-2, 20-1, 20-2, 22-1 and 23-3.
- **Keep the boundary clear.** The trip, voting and C&E labs are training exercises, not
  designs for real safety functions. Keep real SRS extracts, C&E matrices and site documents
  out of your study repository.

### C.8.2 Machines and manufacturing automation

In Levels 1–3, give extra time to 04, 06 and 07 (including the optional Lab 07-5, which is a
timing exercise, not a safety design), to Lab 09-2 (shift-register tracking, which the
conveyor capstone builds on) and to Module 13, including the SFC of Lab 13-3.

| Order | Module | Why here |
|---|---|---|
| 1 | 16 Alarms and diagnostics | Required by 18 and 20 |
| 2 | 17 Communications | Required by 19; drives over fieldbus |
| 3 | 19 Motion and drives | VFDs, encoders and positioning are daily work on machines |
| 4 | 18 HMI and SCADA | Operator interfaces and modes |
| 5 | 15 PID | Needed for the batch capstone; Lab 15-3 (cascade) can wait if time is short |
| 6 | 20 Functional safety | Concentrate on the machinery side of [section 20.3](../20-functional-safety/README.md#203-the-standards-map) (ISO 13849-1, IEC 62061, stop categories) and the safety relays in [section 20.4](../20-functional-safety/README.md#204-safety-hardware) |
| 7 | 21 Architecture | [PackML](../21-architecture-and-standards/README.md#4-packml-isa-88-for-machines) and Lab 21-1 |
| 8 | 22 Software engineering | |
| 9 | 23 Commissioning | |
| 10 | Capstone 24-1, then 24-2 | Conveyor sorting cell first, then the batch plant as a second |

Read Module 19's [drive safety functions](../19-motion-and-drives/README.md#7-drive-safety-functions-iec-61800-5-2)
(STO, SS1, SLS and the others) together with Module 20: on machines with drives, the two
topics meet.

---

Back to the course home: **[PLC Programming Course](../README.md)** ·
Start of the course: **[00 — Start Here](../00-start-here/)**

Other appendices: [A — Vendor cross-reference](A-vendor-cross-reference.md) ·
[B — Glossary](B-glossary.md) ·
[D — Resources and certifications](D-resources-and-certifications.md) ·
[E — MATIEC and OpenPLC notes](E-matiec-openplc-notes.md)
