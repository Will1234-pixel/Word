# 24 — Capstone Projects

> **Level:** Capstone · **Time:** ~25–40 hours per project · **Prerequisites:** Levels 1–4
> (Modules [01](../01-what-is-a-plc/)–[19](../19-motion-and-drives/)). Level 5 helps a lot,
> especially [21](../21-architecture-and-standards/), [22](../22-software-engineering/) and
> [23](../23-commissioning-and-troubleshooting/).

The capstones are where everything comes together. Each one is a complete, realistic control
system described the way a real project is described to a controls engineer: a story,
a functional specification with numbered requirements, an I/O list, an HMI/SCADA interface,
alarms, and a factory acceptance test (FAT).

Unlike the module labs, nobody tells you how to structure the code. You design it: which
function blocks, which state machines, how the data is organised. Then you prove it works
against an acceptance test of several hundred checks, just as you would prove a real system
to a client before it leaves the workshop.

## The three projects

| Project | The plant | What it exercises most | Time | Brief |
|---|---|---|---|---|
| **24-1 Conveyor sorting cell** | A belt conveyor that sorts steel and plastic drum bungs into two lanes, with pneumatic pushers, jam detection and lane-full handling | Discrete logic, edges, timers, shift-register tracking, state machines, pneumatic actuator faults, alarms, HMI interface | ~25–35 h | [24-1-conveyor-sorting-cell.md](24-1-conveyor-sorting-cell.md) |
| **24-2 Batch mixing plant** | A jacketed mixing vessel: two ingredients dosed by flow-meter totals, PID heating, agitation, hold at temperature, pump-out | Recipes and structures, ISA-88-style batch state machine (hold/restart/abort), analog I/O, PID, alarms, batch reports | ~25–35 h | [24-2-batch-mixing-plant.md](24-2-batch-mixing-plant.md) |
| **24-3 Wastewater pump station** | An unmanned lift station with three pumps (duty/assist/standby), a level transmitter and backup floats, reporting to SCADA | Analog validation (NAMUR NE43), level control, alternation and run-hour balancing, fault substitution, float backup, starts-per-hour limits, SCADA register map | ~30–40 h | [24-3-pump-station.md](24-3-pump-station.md) |

You don't have to do all three. Choose by interest, or by the kind of work you want to do:

- **Process plant, instrumentation or safety systems:** start with **24-3**, then **24-2**.
  They are closest to loop drawings, 4–20 mA signals, trips and control-room interfaces.
- **Manufacturing and machines:** start with **24-1**, then **24-2**.
- **To show an employer one project:** pick the one nearest the job, finish it properly,
  and write it up (see *Showing your work* below).

## How each capstone works

Each project has four files:

```
24-capstone-projects/
├── 24-1-conveyor-sorting-cell.md            the project brief (read this first, all of it)
└── labs/
    ├── 24-1-conveyor-sorting-cell.test      the factory acceptance test (FAT)
    ├── starter/24-1-conveyor-sorting-cell.st   I/O, interface structures, configuration
    │                                           (and, for 24-2 and 24-3, a plant simulation)
    └── solutions/24-1-conveyor-sorting-cell.st  a reference solution
```

**The plant simulation.** In 24-2 and 24-3 you can't test a tank or a wet well by setting
inputs by hand, because levels, flows and temperatures must respond to what your program
does. So the starter includes a **given** simulation function block. It reads your outputs
(valves, pumps, heaters) and writes the "field" inputs (levels, flow pulses, temperatures,
motor feedbacks) as the real plant would. The test drives the operator (recipes, start,
hold, acknowledge) and injects faults through the simulation. Treat the simulation as the
plant: don't change it, and don't read its internals from your logic. Read the plant only
through the I/O variables, as you would on a real site.

**The FAT is criteria-based.** It checks behaviour against the numbered requirements in the
brief: this pump starts, that alarm raises within this time, the batch report shows these
quantities within that tolerance. It does not check how you wrote the code, so any sound
design passes. Each brief states the timing assumptions and tolerances the FAT relies on.

## Suggested way to work

1. **Read the whole brief**, twice. Mark anything unclear and decide how you would
   interpret it. Real specifications are never perfect, and interpreting them is part of
   the job.
2. **Design before coding.** Sketch the state diagram(s), list your function blocks and
   their interfaces, and decide where each output is written (once!). The briefs include a
   suggested architecture if you want a starting point.
3. **Build it in milestones.** Each brief has milestones (I/O mapping and single devices
   first, then sequences, then alarms and the HMI) mapped to groups of FAT scenarios.
   Get one milestone's scenarios passing before starting the next.
4. **Run the FAT often:**
   ```bash
   python3 tools/plctest.py my-work/24-3-pump-station.st 24-capstone-projects/labs/24-3-pump-station.test
   ```
   A failing check names the line of the `.test` file. Read the scenario around it to see
   exactly what situation it sets up.
5. **When everything passes, compare** with the reference solution. Look for design
   differences, not just code differences. Then score yourself against the rubric at the end
   of the brief.
6. **Try the extensions** listed in each brief. They are closer to real-world follow-up
   requests from a client.

> **OpenPLC Editor users:** you can build a capstone in the Editor and exercise it in the
> simulator. With hundreds of checks, though, the automatic FAT (`plctest`, see
> [Module 00](../00-start-here/)) is the practical way to prove it complete. If you can't
> run `plctest`, work through the brief's numbered requirements and the FAT's scenario names
> as a manual test sheet.

## Showing your work

A finished capstone is good evidence in a job application or interview, especially with:

- your code in a git repository, with a sensible commit history ([Module 22](../22-software-engineering/));
- a short write-up: the problem, your architecture (state diagram, FB list), one design
  decision you made and why, and one bug the FAT caught;
- any tests you added yourself;
- one extension beyond the brief.

Interviewers tend to ask about the decisions, not the syntax: why a trip latch is
set-dominant, how you handled a failed transmitter, what happens at power-up. The briefs'
"questions" sections are good practice for exactly that.

---

Previous: [23 — Commissioning, Troubleshooting and Maintenance](../23-commissioning-and-troubleshooting/) ·
Start with: [24-1](24-1-conveyor-sorting-cell.md) · [24-2](24-2-batch-mixing-plant.md) · [24-3](24-3-pump-station.md) ·
Course home: [README](../README.md)
