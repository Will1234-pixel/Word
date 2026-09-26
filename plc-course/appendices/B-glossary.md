# Appendix B — Glossary

This appendix explains the terms, abbreviations and standard names used in the course, in
alphabetical order. Each entry gives the meaning the course uses, in one to three sentences,
and links to the module that teaches it. Where another module adds something important, a
second link follows. The entries are reminders, not lessons: when a definition is not enough,
follow the link, because the module has the worked examples and the traps.

**How to use it**

- Entries are sorted alphabetically, ignoring capitals and punctuation. Terms that start with a
  digit or a symbol (`%IX0.0`, `4–20 mA`, `1oo2`, `_NC`) are at the start, under
  [Numbers and symbols](#numbers-and-symbols).
- Abbreviations are expanded in brackets. Where the full name is the usual form, the entry is
  under the full name (look for **Safety integrity level (SIL)**, not SIL); a "See" entry is
  given only where the two forms would fall under different letters.
- Vendor-specific terms are marked with the vendor in italics: *Siemens* (TIA Portal,
  S7-1200/1500), *Rockwell* (Studio 5000 Logix Designer, ControlLogix/CompactLogix),
  and *CODESYS* (also TwinCAT and the other CODESYS-based tools).
  [Appendix A](A-vendor-cross-reference.md) maps them to their IEC 61131-3 equivalents.
- Standards are listed under their usual names: IEC 61511 and ISA-18.2 under I, NFPA 70E under
  N. Where an ISA standard has an IEC twin, the entry gives both.
- The last column links to the module that teaches the term: `07` is
  [Module 07](../07-timers/), `24-3` is the pump-station capstone, and `App. A` and `App. E`
  are [Appendix A](A-vendor-cross-reference.md) and
  [Appendix E](E-matiec-openplc-notes.md).
- A few abbreviations carry two meanings in the course, and each meaning has its own entry:
  **CV** is a counter's current value (Module 08) and a controller's output (Module 15), and
  **PV** is a counter's preset value and a process variable. Words that mean different things
  in different vendors' tools are collected in
  [Appendix A, section A.14 (false friends)](A-vendor-cross-reference.md#a14-false-friends).

> **Safety.** A glossary entry is a reminder, not design guidance. Safety functions are
> specified, designed and verified under the standards in
> [Module 20](../20-functional-safety/), in safety-rated hardware, and every lab in this course
> is a training exercise only.

**Jump to:** [Numbers and symbols](#numbers-and-symbols) · [A](#a) · [B](#b) · [C](#c) · [D](#d) · [E](#e) · [F](#f) · [G](#g) · [H](#h) · [I](#i) · [J](#j) · [K](#k) · [L](#l) · [M](#m) · [N](#n) · [O](#o) · [P](#p) · [Q](#q) · [R](#r) · [S](#s) · [T](#t) · [U](#u) · [V](#v) · [W](#w) · [X](#x) · [Z](#z)

## Numbers and symbols

| Term | Meaning | Module |
|---|---|---|
| **`%IX`, `%QX`, `%IW`, `%QW`, `%MW` …** (IEC direct addresses) | `%`, then the location (`I` input, `Q` output, `M` memory), the size (`X` bit, `B` byte, `W` word, `D` double word, `L` long word) and a position such as `0.3`. The labs use `%IX`/`%QX` for digital I/O and `%IW`/`%QW` for analog channels, tied to names with `AT`. Whether bit, byte and word addresses overlap depends on the platform. | [03](../03-data-types-and-addressing/) |
| **`_NC`** (course naming suffix) | Marks an input from a normally-closed device: TRUE while healthy or not operated, FALSE when operated *or* when its wire breaks. Use it directly in run conditions, with no `NOT`; in ladder that is an NO contact, `--] [--`. | [00](../00-start-here/) · [02](../02-electrical-and-field-devices/) |
| **`(* … *)`** (comment) | The IEC 61131-3 comment. MATIEC, and therefore every lab file, rejects `//` line comments and nested comments. | [10](../10-structured-text/) · [App. E](E-matiec-openplc-notes.md) |
| **`#Name`, `"Name"`** · *Siemens* | SCL notation: a leading `#` marks a local variable of the block, and double quotes mark a global PLC tag or data block. | [10](../10-structured-text/) |
| **`[:=]`** (non-retentive assignment) · *Rockwell* | A Logix Structured Text assignment whose target is also reset to zero when the controller goes into Run mode. An ordinary `:=` target keeps its value through a power cycle, so a run command written with `:=` could restart equipment by itself. | [10](../10-structured-text/) · [App. A](A-vendor-cross-reference.md) |
| **`.EN`, `.TT`, `.DN`, `.ACC`, `.PRE`** · *Rockwell* | Members of a Logix `TIMER` tag: enable, timer timing, done, accumulated time and preset (`DINT` milliseconds). `TON.DN` is the IEC `Q`. `COUNTER` tags have `.CU`, `.CD`, `.OV` and `.UN` in place of `.EN` and `.TT`, and their `.DN` means `.ACC >= .PRE`, even for `CTD`. | [07](../07-timers/) · [08](../08-counters/) |
| **0–10 V** | A voltage analog signal, common for drive speed references. It has no live zero, so 0 V may be a genuine zero or a broken wire; prefer 4–20 mA for field signals. | [02](../02-electrical-and-field-devices/) |
| **1oo1, 1oo2, 2oo2, 2oo3** (MooN voting) | "M out of N": N channels are installed and M of them must demand a trip. 1oo2 (OR) favours safety, 2oo2 (AND) favours availability, and 2oo3 (majority) tolerates one failure of either kind. 1oo2D is a 1oo2 whose diagnostics can switch out a channel detected as faulty. | [05](../05-boolean-logic-and-fbd/) · [20](../20-functional-safety/) |
| **2-wire and 3-wire control** | Old names for start/stop circuits, not for sensor wiring. 2-wire control runs a motor from a maintained contact, so it restarts by itself after a power cut; 3-wire control uses momentary Start and Stop buttons and a seal-in, so it stays off until Start is pressed again. | [02](../02-electrical-and-field-devices/) · [04](../04-ladder-logic/) |
| **2-wire, 3-wire and 4-wire devices** | A 2-wire (loop-powered) transmitter takes its power through its two signal wires; a 4-wire transmitter has its own supply and drives the loop current itself; a 3-wire DC sensor has +24 V, 0 V and a separate output wire. RTDs are also connected 2-, 3- or 4-wire. | [02](../02-electrical-and-field-devices/) · [14](../14-analog-and-process-io/) |
| **4–20 mA current loop** | The standard analog signal: 4 mA is 0 % of range and 20 mA is 100 %. The current is the same everywhere in a series loop, so cable resistance does not change the reading, and the live zero makes a broken wire detectable. | [02](../02-electrical-and-field-devices/) · [14](../14-analog-and-process-io/) |
| **27648** · *Siemens* | The nominal raw count for 100 % on Siemens analog channels (4 mA = 0, 20 mA = 27648 = `16#6C00`), with over-range up to 32511 and under-range down to −4864. The course's analog labs use the same convention, so 1 mA = 1728 counts. | [14](../14-analog-and-process-io/) |
| **40001, 30001, 10001, 00001** (Modbus reference numbers) | The old Modicon numbering of the four Modbus tables, counting from 1. The leading digit is not sent and the address on the wire counts from 0, so "40001" is holding register address 0: the classic Modbus off-by-one. | [03](../03-data-types-and-addressing/) · [17](../17-industrial-communications/) |

[Back to top](#appendix-b--glossary)

## A

| Term | Meaning | Module |
|---|---|---|
| **Abort** | An operator command that ends a sequence or phase from any active state, as quickly as is safe. It is not an emergency stop: e-stops and trips belong to the safety system, and the sequence only follows them. | [13](../13-sequential-control/) · [21](../21-architecture-and-standards/) |
| **Absolute encoder, resolver** | An absolute encoder outputs a unique code for every position, so the position is known at power-up without homing; single-turn types code one revolution and multi-turn types also count revolutions. A resolver is a rotary transformer, rugged and absolute within one revolution, used on many harsh-duty servo motors. | [19](../19-motion-and-drives/) |
| **Acceptance test** (lab) | The `.test` file that comes with each lab; `plctest` runs its scenarios against your program. Starter files must fail it and solutions must pass it. On real projects the FAT and SAT are the acceptance tests. | [00](../00-start-here/) |
| **Acknowledge** (alarm) | The operator's confirmation that an alarm has been seen: flashing goes steady and the horn stops (silence only stops the horn). It does not clear the alarm or touch the cause, and it should act on the edge of the button so that a jammed button acknowledges only once. | [16](../16-alarms-and-diagnostics/) |
| **Action, action qualifier** (SFC) | An action is what a step does: a Boolean variable, or a named action with a body. The qualifier says when it is active: N (while the step is active), S and R (set and overriding reset), P (pulse), L (time limited), D (time delayed), SD, DS, SL, and P1/P0 (pulse on activation/deactivation). | [13](../13-sequential-control/) |
| **Add-On Instruction (AOI)** · *Rockwell* | Rockwell's user-defined instruction, the Logix equivalent of an IEC function block type. Each use has a backing tag of the AOI's data type, and AOI definitions cannot be edited online. | [11](../11-program-organization/) |
| **Alarm** | A notification that needs a timely operator response to avoid a defined consequence. Something that only needs the operator's awareness is an alert, a record of what happened is an event, and a maintenance matter is a diagnostic; none of them belongs in the alarm list. | [16](../16-alarms-and-diagnostics/) |
| **Alarm states** | The combination of two separate memories, *active* and *acknowledged*: normal, unacknowledged, acknowledged, and returned to normal unacknowledged (RTN unack). A latching alarm stays in alarm after its condition has gone, until someone resets it. | [16](../16-alarms-and-diagnostics/) |
| **Alias tag** · *Rockwell* | A Logix tag that is another name for an existing tag, for example `StartPB` for `Local:1:I.Data.0`, so the logic reads well and the I/O mapping sits in one place. | [03](../03-data-types-and-addressing/) |
| **Alternation** | Changing which of two or more identical machines runs next, usually on each new demand, so that they share the wear and a hidden failure of the standby is found early. | [06](../06-edges-and-one-shots/) · [24-3](../24-capstone-projects/24-3-pump-station.md) |
| **Alternative and simultaneous branches** (SFC) | An alternative branch is a step with several outgoing transitions of which only one should fire; MATIEC activates both targets if two conditions are TRUE in the same scan, so make them mutually exclusive. A simultaneous branch, drawn with double lines, starts several parallel sequences at once and rejoins them at a transition that waits for all of them. | [13](../13-sequential-control/) · [App. E](E-matiec-openplc-notes.md) |
| **Analog input, analog output** (AI, AO) | I/O channels for continuous signals such as 4–20 mA, 0–10 V, RTDs and thermocouples. The card's ADC turns the signal into a raw integer whose range depends on the card, and the program scales it to engineering units; an analog output typically drives a valve positioner or a drive's speed reference. | [01](../01-what-is-a-plc/) · [14](../14-analog-and-process-io/) |
| **Annunciator** | A panel of back-lit alarm windows with a horn and acknowledge, reset and lamp-test buttons. Its lamps and horn follow an ISA-18.1 sequence, and the lamp test proves that a dark window really means "no alarm". | [16](../16-alarms-and-diagnostics/) |
| **Anti-windup, integral windup** | Windup is the integral part of a PID growing while the output is stuck on a limit, so the loop stays saturated and overshoots when the limit clears. Anti-windup prevents it: conditional integration (clamping), back-calculation, limiting the integral, the velocity form, or external reset feedback. | [15](../15-pid-control/) |
| **Array** | A numbered set of variables of one type, such as `ARRAY[1..10] OF REAL`; IEC bounds are whatever you declare, while Rockwell arrays are always zero-based. A variable index out of range is a major fault on Logix and not checked at all by MATIEC, so validate every index that does not come from a `FOR` loop over the bounds. | [10](../10-structured-text/) · [12](../12-data-structures/) |
| **As-built, as-found, red-lines** | Red-lines are changes marked on the drawings during commissioning; the design office turns them into as-built drawings that record the plant as actually built. As-found readings are recorded before anything is adjusted, for example in a loop check or a proof test. | [23](../23-commissioning-and-troubleshooting/) |
| **Asynchronous I/O** · *Rockwell* | Logix controllers update I/O tags at each module's requested packet interval, independently of the program scan, so an input can change between two rungs. The defence is to copy inputs to internal tags once per scan. | [01](../01-what-is-a-plc/) · [11](../11-program-organization/) |
| **Audit trail** | A record of who changed what, when and why: setpoints, modes, bypasses, program versions. | [18](../18-hmi-and-scada/) · [22](../22-software-engineering/) |
| **Auto, Manual, Off** (modes) | Who commands a device: the program (Auto), the operator one command at a time (Manual), or nobody (Off, or out of service). Interlocks and permissives apply in every mode, and a stop is obeyed in every mode. | [11](../11-program-organization/) · [18](../18-hmi-and-scada/) |
| **Axis state machine** (PLCopen) | The states a PLCopen motion axis can be in: Disabled, Standstill, Homing, Discrete Motion, Continuous Motion, Synchronized Motion, Stopping and ErrorStop. Each motion block is accepted only in certain states. | [19](../19-motion-and-drives/) |

[Back to top](#appendix-b--glossary)

## B

| Term | Meaning | Module |
|---|---|---|
| **Barrier** | See **IS barrier**. | [02](../02-electrical-and-field-devices/) |
| **Basic process control system (BPCS)** | The normal control system (PLC or DCS) that runs the plant, as distinct from the safety instrumented system. A BPCS protection layer not designed and managed to IEC 61511 may claim a risk reduction factor of no more than 10. | [20](../20-functional-safety/) |
| **BCD** (binary-coded decimal) | Each decimal digit stored in its own four bits, as used by thumbwheel switches, seven-segment displays and legacy S5 timers. Reading BCD as if it were binary gives wrong numbers. | [03](../03-data-types-and-addressing/) |
| **Bit, byte, word, double word** | 1, 8, 16 and 32 bits. The IEC bit-string types `BYTE`, `WORD`, `DWORD` and `LWORD` (64 bits) hold bit patterns, not numbers, and the standard defines no arithmetic on them. | [03](../03-data-types-and-addressing/) |
| **Bitwise operators, masks** | `AND`, `OR`, `XOR` and `NOT` applied bit by bit to a word; a mask selects which bits to test, set, clear or toggle. MATIEC has no `MyWord.3` bit access, so the labs use shifts and masks. | [09](../09-math-and-data-handling/) |
| **Black channel** | The way safety protocols treat an ordinary network: as untrusted. The safety layer at each end adds its own CRC, message numbering, identifiers and watchdog. The main protocols are PROFIsafe (PROFINET, PROFIBUS), CIP Safety (EtherNet/IP), FSoE (EtherCAT) and openSAFETY. | [20](../20-functional-safety/) |
| **Boolean operators** | NOT, AND, OR and XOR, plus NAND, NOR and XNOR (equivalence). In ST, `NOT` binds tightest and applies to the next operand only, then comparisons, then `AND`, `XOR` and `OR`. | [05](../05-boolean-logic-and-fbd/) |
| **BS 7671** | The UK wiring regulations, in the IEC 60364 family. The electrical equipment of machines follows IEC 60204-1. | [02](../02-electrical-and-field-devices/) |
| **Bumpless transfer** | A mode change (Manual to Auto, local to remote) that does not make the output jump. It is achieved by tracking: while one owner is in charge, the other owner's value follows the actual output. A PID uses output tracking (the integral is set so that the first automatic output equals the manual one) or PV tracking (the setpoint follows the PV while in manual). | [15](../15-pid-control/) · [18](../18-hmi-and-scada/) |
| **Burden resistor** | A precision resistor in a current loop across which the input measures a voltage. With 250 Ω, 4–20 mA becomes 1–5 V, and the resistance also meets HART's minimum loop resistance. Removing it breaks the loop. | [02](../02-electrical-and-field-devices/) |
| **Burnout** | The direction a transmitter or input drives its reading when the sensor fails: upscale or downscale. Choose the direction that pushes the logic towards safety, such as upscale for a high trip, and still detect it as a fault. | [02](../02-electrical-and-field-devices/) · [14](../14-analog-and-process-io/) |
| **Bypass, override** | A deliberate override of an interlock or trip input; logically just an OR with the healthy signal. In safety systems a maintenance bypass is authorised, time-limited, alarmed, logged, applied per cause and never done by forcing I/O; a start-up override suppresses a trip whose cause is expected during start-up and removes itself automatically. | [05](../05-boolean-logic-and-fbd/) · [20](../20-functional-safety/) |
| **Byte order, word order** | The order in which the bytes of a multi-byte value are stored or sent: Siemens CPUs and the contents of a Modbus register are big-endian (high byte first), PCs and many CODESYS targets little-endian. Modbus does not define the order of the two registers of a 32-bit value either, so a wrong byte or word order gives absurd values. | [03](../03-data-types-and-addressing/) · [17](../17-industrial-communications/) |

[Back to top](#appendix-b--glossary)

## C

| Term | Meaning | Module |
|---|---|---|
| **CAN, CANopen** | CAN is a two-wire differential bus from the car industry, in which each message's identifier also sets its priority. CANopen adds an object dictionary, PDOs for cyclic process data, SDOs for acyclic access and NMT for network management. | [17](../17-industrial-communications/) |
| **Cascade control** | One controller's output becomes another's setpoint. The outer (primary, master) loop controls the variable you care about; the faster inner (secondary, slave) loop corrects disturbances in its own variable before they reach the outer one. Tune the inner loop first. | [15](../15-pid-control/) |
| **CASE** | The ST statement that selects one branch by value; the usual way to write a state machine. MATIEC does not accept a `VAR CONSTANT` as a case label. | [10](../10-structured-text/) · [13](../13-sequential-control/) |
| **Cause-and-effect (C&E) matrix** | Shutdown logic as a table: causes (trip initiators) are the rows, effects (actions) the columns, and a mark means "this cause produces this effect". It is the reference for the logic, the FAT and SAT, and proof testing. | [20](../20-functional-safety/) · [12](../12-data-structures/) |
| **Characterisation test, refactoring** | Refactoring changes the structure of code without changing its behaviour. A characterisation test records what the existing program actually does, so the refactor can prove that nothing changed. | [22](../22-software-engineering/) |
| **Chattering** | An alarm or signal that repeatedly goes in and out, commonly defined as three or more times in one minute. Cured with deadband, on- and off-delays, or by fixing the instrument. | [14](../14-analog-and-process-io/) · [16](../16-alarms-and-diagnostics/) |
| **Clamping** | Forcing a value into a range, `LIMIT(Min, X, Max)`. Always clamp outputs to the field and operator entries, but check a value for faults before you clamp it. | [09](../09-math-and-data-handling/) · [14](../14-analog-and-process-io/) |
| **Client/server** | Request/response communication in which clients ask and servers answer, as in Modbus TCP and OPC UA. Modern Modbus documents use it in place of master/slave. | [17](../17-industrial-communications/) |
| **Closed loop, open loop** | In closed loop (automatic) the controller compares PV with SP on every execution and moves the output; in open loop (manual) the operator sets the output. | [15](../15-pid-control/) |
| **Cmd, Sts, Cfg, Alm** | The course's split of a device's data by who writes it: commands (the HMI sets, the PLC clears), status (the PLC writes every scan), configuration (engineer level, retentive, validated) and alarms (latched by the PLC). | [12](../12-data-structures/) · [18](../18-hmi-and-scada/) |
| **CODESYS** | A widely used IEC 61131-3 development system and runtime, free for Windows. Beckhoff TwinCAT (a close relative), Schneider Machine Expert, WAGO and many other brands build on it, and it supports edition 3 including object orientation. | [00](../00-start-here/) |
| **Coding standard** | A team's written rules for names, comments, structure and complexity limits (a cyclomatic complexity of about 10 per POU is a common one), checked in code review. The PLCopen coding guidelines are a free, vendor-neutral starting point. | [22](../22-software-engineering/) |
| **Coil** | In ladder, an instruction that writes the rung result to one bit every time it executes: TRUE with power, FALSE without. In a relay or contactor, the winding (terminals A1/A2) that moves the contacts. | [04](../04-ladder-logic/) · [02](../02-electrical-and-field-devices/) |
| **Cold restart, warm restart** | After a cold restart every variable takes its initial value; after a warm restart (typically when power returns) `RETAIN` variables keep their last values. In `plctest` every scenario is a cold start. | [03](../03-data-types-and-addressing/) · [11](../11-program-organization/) |
| **Combinational logic, sequential logic** | Combinational logic has no memory: outputs depend only on the present inputs. Sequential logic has memory (a seal-in, a latch, a state), so its outputs also depend on what happened before. | [05](../05-boolean-logic-and-fbd/) |
| **Command and feedback** | The command is what the PLC asks for (run, open); the feedback is an independent signal that it happened (a contactor auxiliary contact, a limit switch). Disagreement for longer than a set time, a feedback timeout, raises a latched fault. | [02](../02-electrical-and-field-devices/) · [07](../07-timers/) |
| **Commissioning** | Taking an installed system from "built" to "proven and handed over": mechanical completion, pre-commissioning (I/O checkout and loop checks without process materials), cold (dry) commissioning, hot (wet) commissioning with process materials, a performance test, and handover with the as-built documents. | [23](../23-commissioning-and-troubleshooting/) |
| **Common cause failure (CCF)** | One cause that defeats several redundant channels at once, such as a shared impulse line or the same wrong calibration on every transmitter. The β factor is the fraction of failures that hit all channels together. | [20](../20-functional-safety/) |
| **Communication loss** | Loss of a link to a device or partner. The design decides what the data does (hold, substitute a safe value, force a defined state, switch to a backup source), and equipment is never restarted just because the link came back. | [17](../17-industrial-communications/) |
| **Compact, modular and rack-based PLCs** | Form factors: a compact PLC has CPU, power supply and a fixed set of I/O in one housing (S7-1200, Micro800); a modular PLC adds I/O modules as needed, usually on a DIN rail; a rack-based PLC plugs modules into a chassis whose backplane carries data and power. Smart relays such as LOGO! sit below them. | [01](../01-what-is-a-plc/) |
| **CONFIGURATION, RESOURCE, TASK** | The IEC software model: a configuration (the whole PLC) holds resources (usually one per CPU), each with tasks, and program instances are attached to tasks. Every lab ends with `Config0`, `Res0`, a 10 ms `MainTask` and `Inst0`. | [11](../11-program-organization/) |
| **Contact** | In ladder, a question about one bit: an NO contact `--] [--` passes power when the bit is TRUE, an NC contact `--]/[--` when it is FALSE. In hardware, the switching part of a relay, push-button or switch. | [04](../04-ladder-logic/) · [02](../02-electrical-and-field-devices/) |
| **Contactor** | A heavy-duty relay for power circuits such as motors and heaters, with main contacts (poles) for the power and auxiliary contacts for control and feedback. | [02](../02-electrical-and-field-devices/) |
| **Control location** | *From where* a device is commanded: the local station, the motor control centre, a local HMI or the central SCADA; the mode says *who* commands. Two stations commanding one unit are kept apart by area responsibility or a control token granted to one station at a time. | [18](../18-hmi-and-scada/) |
| **Control module (CM)** | In ISA-88, the lowest level of equipment: a device or small group of devices with basic control, such as a valve, a motor or a PID loop. It knows nothing about batches. | [21](../21-architecture-and-standards/) |
| **Control word, status word** | Packed bits exchanged with a device such as a drive: the control word carries commands (run, direction, fault reset) and the status word reports state (ready, running, fault). In drive profiles the control word requests transitions of the drive's own state machine. | [03](../03-data-types-and-addressing/) · [17](../17-industrial-communications/) |
| **Counter** (`CTU`, `CTD`, `CTUD`) | A function block built from an edge detector, a stored count `CV` and a comparison with a preset `PV`. `CTU` counts rising edges of `CU` and sets `Q` while `CV >= PV`; `CTD` loads `PV` with `LD`, counts down and sets `Q` while `CV <= 0`; `CTUD` does both. In MATIEC they stop at `PV` and at 0, while other platforms count on or wrap. | [08](../08-counters/) |
| **CPU** | The PLC module that holds the processor, program and data memory, retentive memory and firmware. Rockwell calls it the controller. | [01](../01-what-is-a-plc/) |
| **Cross-reference** | On drawings, the link from a coil to its contacts, or from a wire to where it continues. In a programming tool, the list of every place a tag is read and written: the first tool to reach for when fault-finding. | [02](../02-electrical-and-field-devices/) · [04](../04-ladder-logic/) |
| **CV** (controller output) | The output a PID controller sends to the final control element, normally 0–100 %; also called OP, MV or Y. | [15](../15-pid-control/) |
| **CV** (current value) | A counter's count. Rockwell calls it the accumulated value, `.ACC`. | [08](../08-counters/) |
| **Cyclic (I/O) data, acyclic messages** | Cyclic data (process values, commands, control and status words) is exchanged every network cycle at a fixed rate and usually mapped straight into the process image. Acyclic messages (parameters, diagnostics, recipes) are sent on demand through instructions with *Execute / Busy / Done / Error* outputs. | [17](../17-industrial-communications/) |
| **Cyclic task** | A task that runs at a fixed interval, giving the constant sample time that PID loops, filters and rate calculations need; all the labs use one 10 ms cyclic task. A task that has not finished when its next start is due has overrun. | [01](../01-what-is-a-plc/) · [11](../11-program-organization/) |

[Back to top](#appendix-b--glossary)

## D

| Term | Meaning | Module |
|---|---|---|
| **Data block (DB)** · *Siemens* | A block that holds data: a global DB for shared values, or an instance DB holding one FB instance's memory. Optimised DBs are reached only by name; standard-access DBs have fixed offsets. | [03](../03-data-types-and-addressing/) · [11](../11-program-organization/) |
| **Data consistency** | Making sure a value is not read half-updated or changed mid-scan by another task or the network. The defences are one writer per variable, a snapshot at the start of the task, handshakes with sequence numbers, and atomic copies such as Rockwell `CPS`. | [11](../11-program-organization/) · [17](../17-industrial-communications/) |
| **DCS** (distributed control system) | A plant-wide control system whose controllers, I/O, operator stations, alarm management and historian are engineered from one database; the usual choice for large continuous and batch process plants. | [01](../01-what-is-a-plc/) · [18](../18-hmi-and-scada/) |
| **De Morgan's theorems** | NOT (A AND B) = NOT A OR NOT B, and NOT (A OR B) = NOT A AND NOT B. They explain why NC stop buttons wired in series mean "stop if any one is pressed". | [05](../05-boolean-logic-and-fbd/) |
| **Deadband** (hysteresis) | A band a value must cross back through before a state changes: a high alarm at 80 % with a 2 % deadband clears below 78 %, and on/off control with hysteresis runs a pump between a start level and a stop level. Over a network, the smallest change worth writing or reporting. | [14](../14-analog-and-process-io/) · [17](../17-industrial-communications/) |
| **Debounce** | Accepting a change of a digital input only after it has stayed in the new state for a set time, which filters contact bounce and chattering switches. Every such delay adds to the response time. | [07](../07-timers/) |
| **De-energise to trip (DTT), energise to trip (ETT)** | De-energise to trip removes energy to make the safe action, so a power loss or broken wire also trips; it is the default. Energise to trip applies energy to act and needs line and supply monitoring, because a failure would otherwise go unnoticed. | [02](../02-electrical-and-field-devices/) · [20](../20-functional-safety/) |
| **Degraded mode, degraded voting** | Carrying on with reduced capability after a detected failure, for example voting 1oo2 on the two good transmitters of a 2oo3 group. What each failure does must be specified in advance. | [16](../16-alarms-and-diagnostics/) · [20](../20-functional-safety/) |
| **Demand, demand mode** | A demand is an event that requires a safety function to act. In low-demand mode (demanded no more than once a year) the target is PFDavg; in high-demand or continuous mode it is PFH. | [20](../20-functional-safety/) |
| **Derivative action** (Td) | The part of PID that responds to how fast the error is changing, so it acts early. Taking the derivative of the PV rather than the error avoids a "derivative kick" on setpoint steps; noise makes derivative hard to use. | [15](../15-pid-control/) |
| **Derived type** | Any data type you build yourself: array, structure, enumeration, subrange or directly derived type. CODESYS calls it a DUT, TIA Portal a PLC data type, Studio 5000 a UDT. | [12](../12-data-structures/) |
| **Determinism** | Whether the worst-case timing of a controller or a network is known and bounded. For networks it goes with latency (how long a value takes to arrive) and jitter (how much that time varies). | [01](../01-what-is-a-plc/) · [17](../17-industrial-communications/) |
| **Device FB** | A reusable function block for one kind of device, such as `FB_Motor` or `FB_Valve`, that owns its commands, interlocks, feedback supervision, modes and faults. One instance per device, no addresses or globals inside. | [11](../11-program-organization/) |
| **Diagnostic buffer** · *Siemens* | The CPU's ring buffer of recent diagnostic events, newest first, with time stamps. After a CPU STOP it is the first place to look. | [16](../16-alarms-and-diagnostics/) |
| **Direct acting, reverse acting** | A reverse-acting controller raises its output when the PV falls (a heater, an inlet valve on a level); a direct-acting one raises its output when the PV rises (a cooling valve, an outlet valve). Controller action, output scaling and valve action together must give negative feedback, or the loop drives the PV away from the setpoint. | [15](../15-pid-control/) |
| **Direct address** | See **`%IX`, `%QX`, `%IW`, `%QW`, `%MW` …** under Numbers and symbols. | [03](../03-data-types-and-addressing/) |
| **Direct on-line (DOL)** | The simplest motor starter: short-circuit protection, a contactor and an overload relay, switching the motor straight onto the supply. | [02](../02-electrical-and-field-devices/) |
| **Direct (positive) opening action** | A contact design in which operating the device forces the NC contacts apart mechanically, even if they have welded. Used on e-stops and safety limit switches. | [02](../02-electrical-and-field-devices/) · [20](../20-functional-safety/) |
| **Discrepancy** | A disagreement that should not last: between voting channels, between a command and its feedback, or between the two contacts of a two-channel safety input (equivalent NC/NC contacts should agree, antivalent NC/NO contacts should differ). A short discrepancy time is allowed, then a fault is latched. | [05](../05-boolean-logic-and-fbd/) · [16](../16-alarms-and-diagnostics/) · [20](../20-functional-safety/) |
| **DMZ** (demilitarised zone) | A firewall-protected network zone between the plant networks and the business network (between ISA-95 Levels 3 and 4). Data such as a historian replica is passed outwards through it, and remote access goes through it rather than straight to the control network. | [18](../18-hmi-and-scada/) · [22](../22-software-engineering/) |
| **Don't-care** | A truth-table row whose output may be taken as 0 or 1 to simplify the logic. On a plant it is really a decision about what happens when something fails, so use the safe value where it matters. | [05](../05-boolean-logic-and-fbd/) |
| **Double-coil bug** | The same bit written by more than one coil or assignment: only the last write in the scan counts. The rule is one bit, one writer. | [04](../04-ladder-logic/) |
| **Download, upload** | Download sends the project from the PC to the PLC; upload reads it back. A full download usually stops the CPU and can overwrite values tuned on site, so keep the offline project under version control. | [23](../23-commissioning-and-troubleshooting/) · [22](../22-software-engineering/) |
| **DP flow, square-root extraction** | Flow through an orifice plate or venturi is proportional to the square root of the differential pressure. Take the root in the transmitter or in the PLC, never both and never neither, and add a low-flow cut-off, because near zero the root turns noise into apparent flow. | [14](../14-analog-and-process-io/) |
| **Duty, assist, standby** | Pump roles: the duty (lead) pump handles normal flow, the assist (lag) pump joins when one pump cannot keep up, and the standby is a spare that runs only when another is unavailable. North American usage: lead/lag/standby. | [24-3](../24-capstone-projects/24-3-pump-station.md) |

[Back to top](#appendix-b--glossary)

## E

| Term | Meaning | Module |
|---|---|---|
| **Earthing** (PE, functional earth, IS earth) | Protective earth (PE) keeps exposed metalwork safe by making an insulation fault trip the protection; a functional ("clean") earth is the reference for signals and cable screens; an IS earth is the dedicated connection that shunt-diode barriers need. Analog cable screens are commonly earthed at one end only. | [02](../02-electrical-and-field-devices/) |
| **Edge, level** | An edge is the moment a Boolean changes (FALSE → TRUE is rising, TRUE → FALSE falling); a level is a condition that lasts. Use an edge when something must happen once per event, and the level for interlocks and trips, which must act for as long as the condition lasts. | [06](../06-edges-and-one-shots/) |
| **Edge memory bit** · *Siemens* | The bit that a Siemens P or N contact, P or N coil, or `P_TRIG`/`N_TRIG` box uses to remember the previous state. Each edge instruction needs its own, in M memory or a static variable, never a Temp variable. | [06](../06-edges-and-one-shots/) |
| **Electrical, mechanical and software interlocks** | Hard-wired protection against two contactors (forward and reverse, star and delta) closing together: an NC auxiliary contact of each in the other's coil circuit, and a mechanical linkage between them. The software interlock in the PLC is the second line of defence, never the only one. | [04](../04-ladder-logic/) · [07](../07-timers/) |
| **Electronic gearing, camming** | Gearing (`MC_GearIn`) makes a slave axis follow a master at a fixed ratio; camming (`MC_CamIn`) makes the slave position a function of the master position through a cam table, as for a rotary knife or flying shear. The master can be a real axis, an external encoder or a virtual axis. | [19](../19-motion-and-drives/) |
| **Emergency stop** (e-stop), ISO 13850 | A red mushroom-head button on a yellow background that latches when pressed and has NC contacts with direct opening action; ISO 13850 specifies the function, which must be stop category 0 or 1. It acts through a safety relay or safety PLC, and the standard PLC only monitors it. | [02](../02-electrical-and-field-devices/) · [20](../20-functional-safety/) |
| **Emulation** | Running the real control program on a PC in a process that behaves like the CPU: S7-PLCSIM, FactoryTalk Logix Echo, CODESYS simulation mode, the OpenPLC Editor's built-in simulator, the OpenPLC Runtime or `plctest`. Used for unit and integration tests. | [22](../22-software-engineering/) |
| **EN, ENO** | Optional enable input and enable output on a function or FB box. When `EN` is FALSE the block does not run and `ENO` is FALSE. In Siemens LAD and FBD its outputs are then not written, so the destination keeps its old value, and `ENO` also goes FALSE after an error such as overflow. | [05](../05-boolean-logic-and-fbd/) · [09](../09-math-and-data-handling/) |
| **Encoder** (incremental) | A sensor that gives pulses as a shaft turns, on two channels A and B in quadrature and often a once-per-revolution Z pulse. It measures change of position only, so the axis must be homed after power-up. | [19](../19-motion-and-drives/) |
| **Entry action** | Something done once when a state is entered, such as counting a batch or clearing a totaliser. In the course's ST state machines a `StepEntry` flag is TRUE for exactly the first scan in each new state, and entry actions go before the transitions. | [13](../13-sequential-control/) |
| **Enumeration** | A type whose values are names, such as `(Idle, Filling, Draining)`; ideal for states and modes. MATIEC accepts only plain enumerations, without explicit values, and cannot convert or order them. | [12](../12-data-structures/) |
| **Equipment module (EM)** | In ISA-88, a functional group of equipment that carries out a finite number of minor processing activities, such as dosing or heating; usually where a phase is carried out. | [21](../21-architecture-and-standards/) |
| **EtherCAT** | Industrial Ethernet, developed by Beckhoff, in which one frame passes through every slave in turn and each slave reads and inserts its data on the fly in hardware. Very fast, with distributed clocks for motion. | [17](../17-industrial-communications/) |
| **EtherNet/IP, CIP** | ODVA's industrial Ethernet (the IP stands for Industrial Protocol) carrying CIP, the object-based Common Industrial Protocol; the native network of Rockwell Logix. Cyclic I/O uses implicit messaging over UDP at a requested packet interval, and request/response traffic such as the Logix `MSG` instruction uses explicit messaging over TCP. | [17](../17-industrial-communications/) |
| **Execute / Done / Busy / Error** | The PLCopen pattern for blocks whose job takes time: a rising edge on `Execute` starts it, `Busy` shows it is running, and `Done`, `Error` or `CommandAborted` report how it ended. Communication instructions use the same idea. | [19](../19-motion-and-drives/) · [17](../17-industrial-communications/) |

[Back to top](#appendix-b--glossary)

## F

| Term | Meaning | Module |
|---|---|---|
| **Faceplate** | An HMI pop-up or symbol built once for a type of device and connected to each instance's data structure, such as `Pumps[3]`. | [12](../12-data-structures/) · [18](../18-hmi-and-scada/) |
| **Fail position** (FC, FO, FL) | Where a valve goes on loss of signal, power or air: fail closed, fail open, or fail last (locked). The spring of a spring-return actuator provides it, and which position is safe is a process decision, marked on the P&ID and valve data sheet. | [02](../02-electrical-and-field-devices/) |
| **Fail-safe** | Designed so that the likely failures (broken wire, lost power, blown fuse, stopped PLC) produce the safe state. Stops and trips are wired so that the healthy condition is the one that passes current. | [02](../02-electrical-and-field-devices/) |
| **FAT** (factory acceptance test) | The test of the control system against its specification at the supplier's workshop, with simulated I/O and the client witnessing. It cannot prove field wiring or real process behaviour, but it is the cheapest place to find software faults. | [01](../01-what-is-a-plc/) · [23](../23-commissioning-and-troubleshooting/) |
| **Fault latching and reset** | Faults stay latched until someone resets them. A reset works only when the cause has gone, and it never starts anything by itself. | [11](../11-program-organization/) · [16](../16-alarms-and-diagnostics/) |
| **FBD** (Function Block Diagram) | The graphical IEC language of blocks joined by lines, suited to signal-flow, analog and interlock logic. Networks run top to bottom, each block runs once its inputs are available, and a loop is broken at a feedback variable. CODESYS also offers CFC, a free-placement variant. | [05](../05-boolean-logic-and-fbd/) |
| **FDS, URS, SDS** (document chain) | The user requirements specification (URS) says what the owner needs and is verified at the SAT; the functional design specification (FDS, also called the control philosophy) says how the system will behave and is verified at the FAT; the software design specification (SDS) says how the software is built. Traceability links every requirement through them to code and tests. | [01](../01-what-is-a-plc/) · [22](../22-software-engineering/) |
| **Feedforward** | Adding a correction for a measured disturbance to the controller output, so the loop reacts before the disturbance moves the PV. | [15](../15-pid-control/) |
| **FIFO, LIFO** | First in, first out (a queue: the oldest entry comes out first) and last in, first out (a stack: the newest comes out first). A FIFO queue refuses new entries when full, where a ring buffer overwrites the oldest. | [09](../09-math-and-data-handling/) · [12](../12-data-structures/) |
| **Filter** (first-order lag, moving average) | A first-order lag moves its output a fixed fraction of the way towards the input each scan, `alpha = Ts / (tau + Ts)`, and covers 63.2 % of a step in one time constant τ; a moving average averages the last N samples. Every filter adds lag. | [14](../14-analog-and-process-io/) |
| **First-out** | An indication of which input of a group tripped first, so the initiating cause can be told apart from the alarms that follow as consequences. | [16](../16-alarms-and-diagnostics/) · [20](../20-functional-safety/) |
| **First-scan flag** | A bit that is TRUE only during the first scan after the PLC starts running. IEC has none, so you build one from a non-retentive bit; Siemens offers a system-memory `FirstScan` bit or OB100, Rockwell the `S:FS` flag. | [06](../06-edges-and-one-shots/) |
| **Following error** | The difference between where a servo axis should be and where it is. Every motion system has a following error limit, and exceeding it (a jam, a crash, a wrong direction) faults the axis. | [19](../19-motion-and-drives/) |
| **FOPDT** (first-order plus dead time) | The three-number process model used for tuning, read from a bump (step) test: process gain K, time constant τ (how fast the PV moves once it starts; it covers 63.2 % of the change in one τ) and dead time θ (how long before it starts to move at all). | [15](../15-pid-control/) |
| **Force, force register** | A force makes the PLC use a fixed value instead of a real input, or drive an output regardless of the logic and its interlocks. Every force needs a permit, an entry in the force register, and removal as soon as the reason has gone. | [23](../23-commissioning-and-troubleshooting/) |
| **Free-running (continuous) execution** | The next scan starts as soon as the previous one has finished, so the scan time varies. Siemens OB1, the Rockwell continuous task and the CODESYS freewheeling task work this way. | [01](../01-what-is-a-plc/) · [11](../11-program-organization/) |
| **F_TRIG** | See **R_TRIG, F_TRIG**. | [06](../06-edges-and-one-shots/) |
| **Function** (`FUNCTION`) | A POU with no memory between calls: the same inputs always give the same result. Examples are `ABS`, `LIMIT`, `REAL_TO_INT` and your own `F_Scale`; Siemens calls a function an FC. | [11](../11-program-organization/) |
| **Function block (FB)** | A POU with its own memory, used through instances, each of which keeps its own data from scan to scan. Timers, counters, edge detectors and device blocks are FBs. Call every instance once per scan, unconditionally. | [11](../11-program-organization/) · [05](../05-boolean-logic-and-fbd/) |
| **Functional safety** | The part of overall safety that depends on a system or equipment operating correctly in response to its inputs. | [20](../20-functional-safety/) |

[Back to top](#appendix-b--glossary)

## G

| Term | Meaning | Module |
|---|---|---|
| **GRAFCET** (IEC 60848) | A specification language for sequential behaviour, developed in France, from which SFC was derived. Its word for a transition condition is a receptivity. | [13](../13-sequential-control/) |
| **GRAPH** · *Siemens* | Siemens' SFC language, available for S7-300/400 and S7-1500; the S7-1200 has not supported it, so check your CPU. A GRAPH sequence is an FB with an instance DB. | [13](../13-sequential-control/) |
| **Gray code** | A binary code in which only one bit changes between neighbouring values. It labels the rows and columns of a Karnaugh map, and many absolute encoders output it. | [05](../05-boolean-logic-and-fbd/) · [19](../19-motion-and-drives/) |
| **Ground loop** | An unwanted current through a screen or signal circuit that is earthed at two points of different potential; shows up as offsets and noise. | [23](../23-commissioning-and-troubleshooting/) · [02](../02-electrical-and-field-devices/) |

[Back to top](#appendix-b--glossary)

## H

| Term | Meaning | Module |
|---|---|---|
| **Half-splitting** | Testing at the middle of a signal path so that each measurement halves the part of the chain where the fault can be. | [23](../23-commissioning-and-troubleshooting/) |
| **Hand-Off-Auto (HOA)** | A three-position selector: Hand runs the device locally, Off stops it, Auto hands it to the control system. At a motor starter it is usually hard-wired. | [02](../02-electrical-and-field-devices/) · [18](../18-hmi-and-scada/) |
| **Handshake** (command) | A protocol that makes an HMI or remote command act exactly once. In the PLC-clears-the-command pattern, the HMI sets a bit, the PLC takes a snapshot and clears it, then accepts the command or rejects it with a reject code. | [18](../18-hmi-and-scada/) · [17](../17-industrial-communications/) |
| **HART** | A digital signal superimposed on a 4–20 mA loop (1200 Hz for a 1, 2200 Hz for a 0) for configuring and diagnosing smart instruments without disturbing the analog value. It needs a minimum loop resistance, usually quoted as about 230 Ω. | [02](../02-electrical-and-field-devices/) · [17](../17-industrial-communications/) |
| **Hazard, harm, risk** | A hazard is a potential source of harm; harm is injury or damage to health; risk combines how often harm could occur with how severe it would be. Tolerable risk is what the owner accepts in context, and in the UK risk must also be reduced as low as reasonably practicable (ALARP). | [20](../20-functional-safety/) |
| **HAZOP** (hazard and operability study) | A structured team review of the P&IDs that applies guide words (no, more, less, reverse …) to process parameters, node by node, to find deviations, their causes and consequences. It finds hazards; it does not decide how much protection is enough. | [20](../20-functional-safety/) |
| **Heartbeat** | A value that a partner changes regularly, so the receiver can prove that the link and the partner's program are alive. Use a counter rather than a toggling bit, choose the timeout from the update period, and supervise both directions. | [07](../07-timers/) · [16](../16-alarms-and-diagnostics/) · [17](../17-industrial-communications/) |
| **High-speed counter (HSC)** | Counting hardware in the CPU or an I/O module that counts pulses far faster than the scan could see them, from encoders and flow meters. | [08](../08-counters/) · [19](../19-motion-and-drives/) |
| **Historian** | A time-series database of process values, states and events, used for long-term trends, reports and analysis. It records; control and protection never depend on it, and stay in the controller. | [18](../18-hmi-and-scada/) |
| **HMI** (human-machine interface) | The screen and software for seeing and operating a machine or unit. It writes requests, never outputs; control and protection stay in the PLC. | [18](../18-hmi-and-scada/) |
| **Hold, Held, Restart** | Hold parks a running sequence or phase in a safe, resumable condition; Held is the waiting state; Restart (ISA-88) or Resume continues it. In PackML, Held means a cause at the machine itself and Suspended an upstream or downstream cause. | [13](../13-sequential-control/) · [21](../21-architecture-and-standards/) |
| **Homing** (referencing) | Moving to a known physical point and setting the axis position there, for example the first encoder Z pulse after a home switch. Needed with incremental encoders; start it only from Standstill. | [19](../19-motion-and-drives/) |

[Back to top](#appendix-b--glossary)

## I

| Term | Meaning | Module |
|---|---|---|
| **Identifier** | A name in IEC code. Identifiers are not case-sensitive, so `Motor` and `MOTOR` are the same variable and `Sin` clashes with the `SIN` function; MATIEC also rejects names that clash with POU, type or library names. | [10](../10-structured-text/) · [App. E](E-matiec-openplc-notes.md) |
| **IEC 60204-1** | The standard for the electrical equipment of machines: pilot-light colours, stop categories 0, 1 and 2, and no hazardous automatic restart after a power failure. NFPA 79 is the North American counterpart. | [02](../02-electrical-and-field-devices/) · [20](../20-functional-safety/) |
| **IEC 61131-3** | The international standard for PLC programming languages, data types, POUs and standard function blocks. Edition 2 (2003) is what MATIEC implements; edition 3 (2013) added object orientation and deprecated IL. Other parts of IEC 61131 cover the hardware (part 2) and IO-Link (part 9). | [01](../01-what-is-a-plc/) |
| **IEC 61508** | The umbrella functional-safety standard for electrical, electronic and programmable systems. Device makers certify to it, and IEC 61511 and IEC 62061 apply it to process plant and machinery. | [20](../20-functional-safety/) |
| **IEC 61511** | Functional safety of safety instrumented systems in the process industry, written for plant owners and integrators; it organises the work into a safety lifecycle. | [20](../20-functional-safety/) |
| **IEC 62061** | Functional safety of machinery by the IEC 61508 approach, with results expressed as SIL 1 to 3. | [20](../20-functional-safety/) |
| **IEC 62381, IEC 62382** | Process-automation standards for the FAT, SAT and SIT (62381) and for electrical and instrumentation loop checks (62382). | [23](../23-commissioning-and-troubleshooting/) |
| **IEC 62443** | The main family of standards for industrial automation and control system security. It assigns roles (asset owner, service providers, product suppliers), groups assets into zones joined by controlled conduits, and sets a target security level from SL 1 to SL 4 by the attacker a zone must resist. | [22](../22-software-engineering/) |
| **IL** (Instruction List) | An assembler-like IEC language, deprecated in edition 3. Meet it in old code but don't write new code in it; Siemens STL is similar but not identical. | [01](../01-what-is-a-plc/) |
| **Initial value** | The value a variable takes at a cold start: the one in its declaration, or the type's default (0, 0.0, FALSE, an empty string, `T#0s`). | [03](../03-data-types-and-addressing/) · [11](../11-program-organization/) |
| **Instance** | One copy of a function block with its own memory, declared like a variable (`Pump1 : FB_Motor;`). Every timer, counter and edge detector needs its own instance, and one instance must never serve two jobs. | [07](../07-timers/) · [11](../11-program-organization/) |
| **Instance DB, multi-instance** · *Siemens* | An FB call's memory lives in its own instance data block (a single instance), or, when declared in another FB's *Static* section, inside that FB's instance DB (a multi-instance). | [07](../07-timers/) · [11](../11-program-organization/) |
| **Integer types** | `SINT`, `INT`, `DINT`, `LINT` (8, 16, 32, 64 bits, signed) and their unsigned `U…` forms. `INT` runs from −32,768 to 32,767. In MATIEC a result that does not fit wraps silently; some PLCs set a flag or fault instead. | [03](../03-data-types-and-addressing/) |
| **Integral action** (Ti) | The part of PID that keeps moving the output while any error remains, so it removes the offset a proportional-only controller leaves; historically called reset. Ti, the integral or reset time, is how long the integral part takes to repeat the proportional action once; some tools use repeats per minute or Ki instead. | [15](../15-pid-control/) |
| **Interlock** | A condition that prevents or stops an action for as long as it is present, in every mode. On a seal-in rung it sits in the main path, so it also stops running equipment. | [04](../04-ladder-logic/) · [05](../05-boolean-logic-and-fbd/) |
| **Interposing relay** | A relay between a PLC output and the real load, used for more current, a different voltage, isolation, extra contacts, or to take the wear of frequent switching. | [02](../02-electrical-and-field-devices/) |
| **Intrinsic safety (IS)** | Limiting the energy in a hazardous-area circuit so that neither a spark nor a hot surface can ignite the atmosphere, even with specified faults (Ex i); the usual method for instrument signals. An IS loop is a system of field device, barrier or isolator and cable, verified by comparing their entity parameters. | [02](../02-electrical-and-field-devices/) |
| **I/O checkout** (point-to-point) | Checking every I/O point from the field device through the wiring to the PLC and the HMI, row by row from the I/O list, with jumpers at the device end, not at the marshalling. | [23](../23-commissioning-and-troubleshooting/) |
| **IO-Link** | A point-to-point digital link between one port of an IO-Link master and one sensor or actuator over an ordinary 3-wire sensor cable; standardised as SDCI in IEC 61131-9. | [17](../17-industrial-communications/) |
| **I/O list** | The controls engineer's master table: one row per signal with tag, description, signal and electrical type, range, fail-safe state, PLC address and drawing references. The instrument index is the instrument engineer's equivalent, one row per instrument. | [02](../02-electrical-and-field-devices/) · [03](../03-data-types-and-addressing/) |
| **I/O mapping layer** | The part of the program that copies raw I/O to named internal variables at the start and internal decisions to the outputs at the end. Polarity, re-wiring, simulation and Rockwell's asynchronous I/O are all handled there, once. | [11](../11-program-organization/) |
| **I/O module** | The module that connects field wiring to the CPU. Each channel (point) handles one signal: digital or analog, input or output. | [01](../01-what-is-a-plc/) |
| **I/O simulation layer** | Code, switched on for testing, that feeds simulated inputs to the logic instead of the real ones and holds the real outputs off, so sequences, alarms and interlocks can be tested before any cable exists. | [23](../23-commissioning-and-troubleshooting/) · [11](../11-program-organization/) |
| **IP address, subnet mask, default gateway** | An IPv4 device's address, the mask that says which addresses are on the same network, and the router used to reach any others. Duplicate IP addresses are a classic commissioning fault. | [17](../17-industrial-communications/) |
| **IS barrier** | Associated apparatus in the safe area that limits the energy reaching an intrinsically safe field circuit. A shunt-diode (Zener) barrier diverts fault energy to a dedicated IS earth and adds series resistance to the loop; a galvanic isolator separates the circuits, needs no IS earth, and can power the loop, pass HART and act as a NAMUR switch amplifier. | [02](../02-electrical-and-field-devices/) |
| **ISA-5.1** | The instrument symbols and tag letters on P&IDs: the first letter is the measured variable, then optional modifiers and function letters, then the loop number, as in `LT-301`, `FIC-101`, `XV-201` or `ZSC-201` (closed-position switch). | [02](../02-electrical-and-field-devices/) |
| **ISA-18.2, IEC 62682** | The alarm-management standards for the process industries: a lifecycle from the alarm philosophy through rationalisation to monitoring, plus priorities, shelving and performance targets; IEC 62682 is the international version. EEMUA 191 is the widely used UK guide, and ISA-18.1 covers annunciator sequences (A, M, R and first-out). | [16](../16-alarms-and-diagnostics/) |
| **ISA-88, IEC 61512** | The batch-control standard: a physical model, a procedural model, recipes and a procedural state model, for batch manufacturing (a finite quantity made by a set of activities over a finite time, as opposed to continuous or discrete production). Its ideas are used well beyond batch plants, and PackML applies them to machines. | [21](../21-architecture-and-standards/) |
| **ISA-95, IEC 62264** | The standard for integrating business and manufacturing systems, grown from the Purdue reference model. Its functional levels run from 0 (the physical process) through 1 (sensing and actuating) and 2 (control, HMI, SCADA) to 3 (manufacturing operations, MES) and 4 (business planning and logistics, ERP). | [21](../21-architecture-and-standards/) |
| **ISA-101, IEC 63303** | The standards for designing and maintaining HMIs in process automation (high-performance HMI). They require an HMI philosophy and style guide rather than prescribing a look. | [18](../18-hmi-and-scada/) |
| **ISO 13849-1** | Safety of machinery: the safety-related parts of control systems, rated by performance level PL a (lowest) to PL e (highest). The PL achieved depends on the category (B, 1 to 4: the structure and how it behaves with faults), MTTFd, diagnostic coverage DCavg and common-cause measures; the required level PLr comes from a risk graph. | [20](../20-functional-safety/) |

[Back to top](#appendix-b--glossary)

## J

| Term | Meaning | Module |
|---|---|---|
| **Jog** (inching) | Running a motor only while a button is held, for setting up or positioning. A jog must never seal in. | [04](../04-ladder-logic/) |

[Back to top](#appendix-b--glossary)

## K

| Term | Meaning | Module |
|---|---|---|
| **Karnaugh map** | A truth table drawn as a grid in Gray-code order, in which adjacent 1s are grouped to find the simplest logic; practical up to four variables. | [05](../05-boolean-logic-and-fbd/) |
| **Kc, proportional band** | Kc is the controller gain. Many older instruments and DCSs set proportional band instead: PB (%) = 100 / Kc, so a wide band means a low gain. | [15](../15-pid-control/) |
| **K-factor** | The number of pulses a flow meter gives per unit of volume. | [08](../08-counters/) |

[Back to top](#appendix-b--glossary)

## L

| Term | Meaning | Module |
|---|---|---|
| **Ladder Diagram (LD)** | The graphical IEC language of contacts and coils between two power rails, read like a relay schematic: series contacts are AND, parallel branches are OR. Siemens calls it LAD; Rockwell also calls it RLL (relay ladder logic). | [04](../04-ladder-logic/) · [01](../01-what-is-a-plc/) |
| **Lambda tuning** | A tuning method in which you choose the closed-loop time constant λ and the rules give a PI setting that follows setpoint changes like a first-order lag, without overshoot. | [15](../15-pid-control/) |
| **Layer of protection analysis (LOPA)** | A semi-quantitative method, working in orders of magnitude, that decides how much risk reduction a safety instrumented function must still provide. It credits only independent protection layers (IPLs): specific, independent, dependable and auditable. | [20](../20-functional-safety/) |
| **Layers** (program structure) | Arranging code so that commands go down and status comes up: I/O mapping, device FBs, equipment and sequence logic, coordination, and the HMI interface. Only the bottom layer touches physical I/O, and a sequence never writes an output directly. | [11](../11-program-organization/) · [21](../21-architecture-and-standards/) |
| **Library** | A versioned collection of tested, reusable POUs and data types. A released library block is changed only by releasing a new version. | [11](../11-program-organization/) |
| **`LIMIT`, `LIM`** | IEC `LIMIT(MN, IN, MX)` is a clamp that returns a number; Rockwell's `LIM` (`LIMIT` from Logix Designer v36) is a test that is TRUE inside a band. A classic false friend when porting code. | [09](../09-math-and-data-handling/) · [App. A](A-vendor-cross-reference.md) |
| **Limit switch** | A mechanical switch operated by a moving part: end of travel, valve open and closed positions (ZSO, ZSC), guard positions. Versions with positive-opening NC contacts are used for safety. | [02](../02-electrical-and-field-devices/) |
| **Literal** | A value written in code, such as `123`, `16#FF`, `2#1010`, `T#5s` or `REAL#1.5`. | [03](../03-data-types-and-addressing/) · [10](../10-structured-text/) |
| **Live zero** | Using 4 mA rather than 0 mA for 0 % of range, so a current near zero means a broken wire or failed transmitter rather than a valid reading. | [02](../02-electrical-and-field-devices/) · [14](../14-analog-and-process-io/) |
| **Local, Remote** | The control location: Local means the device is worked from its field station, either hard-wired past the PLC (Hand at the starter, when the PLC can only monitor it) or through PLC inputs with every interlock still applying; Remote means it is commanded from the PLC, HMI or SCADA. One location has control at a time, and a stop from any location is obeyed. | [11](../11-program-organization/) · [18](../18-hmi-and-scada/) |
| **Located variable** (`AT`) | A variable tied to a physical address with `AT`, as in `StartPB AT %IX0.0 : BOOL;`. In MATIEC located variables need their own `VAR` block, and fully specified addresses belong in programs, not in reusable FBs. | [03](../03-data-types-and-addressing/) · [11](../11-program-organization/) |
| **Lock-out/tag-out (LOTO)** | Switching off at a proper isolating device, locking it off with a personal lock and tagging it before work, then proving dead. A PLC output that is off is never an isolation. | [02](../02-electrical-and-field-devices/) |
| **Loop check, loop calibrator** | Proving that every part of an analog loop, from the transmitter to the HMI including scaling, alarms and trips, reports the signal correctly; usually a five-point check at 0, 25, 50, 75 and 100 %, up and down. The loop calibrator can simulate a 2-wire transmitter (using the loop's own power), source a current, or measure one. | [23](../23-commissioning-and-troubleshooting/) |
| **Loop diagram** | A drawing of one instrument loop from end to end (format per ISA-5.4): field device, junction boxes, cables, marshalling, barrier or isolator and card channel, with polarities and the loop power source. It shows every point where you can measure. | [02](../02-electrical-and-field-devices/) |
| **Loop-resistance budget** | The check that the supply voltage, less the transmitter's minimum terminal voltage, can drive the highest loop current (about 22 mA, to cover NE43 fault signals) through the burden, cable and barrier. | [02](../02-electrical-and-field-devices/) · [23](../23-commissioning-and-troubleshooting/) |
| **LREAL, REAL** | 64-bit and 32-bit floating-point numbers, with about 15–16 and about 7 significant digits. Never compare them with `=` or `<>`, and don't totalise in `REAL`: small increments are lost as the total grows. | [03](../03-data-types-and-addressing/) · [09](../09-math-and-data-handling/) |

[Back to top](#appendix-b--glossary)

## M

| Term | Meaning | Module |
|---|---|---|
| **Major fault, minor fault** · *Rockwell* | A major fault stops the logic and sends the outputs to their configured fault state, for example an array index out of range or a task watchdog; a minor fault, such as an arithmetic overflow, is logged while the logic keeps running. The `GSV` and `SSV` instructions read and write controller status such as fault records. | [16](../16-alarms-and-diagnostics/) · [10](../10-structured-text/) |
| **Management of change (MOC)** | The formal process every change to plant, process, procedures or control software goes through: request, impact and hazard review, approval, implementation, test and updated documents. | [01](../01-what-is-a-plc/) · [22](../22-software-engineering/) |
| **Marshalling** (cabinet) | The cabinet or terminal area, usually in the equipment or control room, where the field multicores are terminated and cross-wired to the cables of the I/O cards; IS barriers and isolators often sit there too. A jumper placed there during I/O checkout proves only half the loop. | [02](../02-electrical-and-field-devices/) · [23](../23-commissioning-and-troubleshooting/) |
| **Master/slave** | Communication in which one master asks each slave in turn and a slave only ever answers, as in Modbus RTU, PROFIBUS DP and HART. | [17](../17-industrial-communications/) |
| **MATIEC** | The open-source IEC 61131-3 compiler from the Beremiz project, used by OpenPLC and by `plctest`. It implements edition 2 and has known gaps, listed in Appendix E. | [00](../00-start-here/) · [App. E](E-matiec-openplc-notes.md) |
| **MCR** (master control relay) · *Rockwell* | Paired instructions that fence off a zone of rungs; when the zone condition is false, `OTE` outputs in it go off. Not a substitute for a hard-wired master control relay, and discouraged by many coding standards. | [04](../04-ladder-logic/) |
| **Mealy machine, Moore machine** | In a Moore machine outputs depend only on the current state, which is what you want for field devices; in a Mealy machine something happens on a transition, which suits one-off actions such as counting. | [13](../13-sequential-control/) |
| **Median selection** | Taking the middle of three values, `MAX(MIN(A, B), MIN(MAX(A, B), C))`, which survives any one transmitter failing high or low. | [09](../09-math-and-data-handling/) · [20](../20-functional-safety/) |
| **MES** (manufacturing execution system) | ISA-95 Level 3 software that manages production: orders, materials, genealogy, quality, performance and OEE. | [18](../18-hmi-and-scada/) · [21](../21-architecture-and-standards/) |
| **`MOD`** | The remainder of an integer division. It takes the sign of the dividend (`-7 MOD 2 = -1`), which matters when wrapping ring-buffer indexes. | [09](../09-math-and-data-handling/) |
| **Modbus** | A simple, very widely used protocol: Modbus RTU (binary over serial, usually RS-485, with a CRC-16), Modbus ASCII (rare) and Modbus TCP (Ethernet, port 502, with a 7-byte MBAP header). A function code says what to do, such as FC 03 read holding registers or FC 16 write several, and a failed request gets an exception response, which is not a timeout. | [17](../17-industrial-communications/) |
| **Modbus data model** | Four tables: coils (read/write bits), discrete inputs (read-only bits), input registers (read-only 16-bit words) and holding registers (read/write words). A register has no data type; the device decides what it means. | [03](../03-data-types-and-addressing/) · [17](../17-industrial-communications/) |
| **Mode shedding** | When Auto can no longer work (for example the level transmitter it depends on has failed), the device drops to Manual, keeps its present state and tells the operator. It does not return to Auto by itself. | [18](../18-hmi-and-scada/) |
| **MooN** | See **1oo1, 1oo2, 2oo2, 2oo3** under Numbers and symbols. | [05](../05-boolean-logic-and-fbd/) |
| **MQTT** | A lightweight publish/subscribe protocol over TCP: clients publish to hierarchical topics through a broker. QoS 0, 1 and 2 set the delivery guarantee, retained messages give new subscribers the last value, and a Last Will reports a client that vanishes. | [17](../17-industrial-communications/) |
| **Multi-instance** | See **Instance DB, multi-instance**. | [11](../11-program-organization/) |
| **Mutation testing** | Measuring how strong a test suite is by running it against slightly wrong copies of the program (mutants). A mutant is killed if a check fails and survives if all pass; the mutation score is killed ÷ (total − equivalent). | [22](../22-software-engineering/) |
| **`MUX`, `SEL`** | Selection functions: `SEL(G, IN0, IN1)` picks one of two, `MUX(K, IN0, IN1, …)` one of many by an index that counts from 0. | [09](../09-math-and-data-handling/) |

[Back to top](#appendix-b--glossary)

## N

| Term | Meaning | Module |
|---|---|---|
| **NAMUR sensor, line-fault detection** | NAMUR is the process-industry user association; a NAMUR sensor (IEC 60947-5-6) is a 2-wire sensor that a switch amplifier powers at about 8.2 V, reading below about 1.2 mA as OFF and above about 2.1 mA as ON. Open and short circuits give currents outside those bands, so the amplifier can detect line faults; the switching state then cannot be trusted, so substitute the safe value and alarm. | [02](../02-electrical-and-field-devices/) |
| **NaN** (not a number) | The `REAL` result of an undefined operation such as 0.0 / 0.0. Every comparison with NaN is FALSE except `<>`, so a NaN can silently stop a trip from ever tripping. | [03](../03-data-types-and-addressing/) |
| **Narrowing, widening** | A widening conversion goes to a type that holds every value of the old one (`INT_TO_DINT`) and is always safe; a narrowing one can lose range or precision (`DINT_TO_INT`, `REAL_TO_INT`), so check the range first. | [09](../09-math-and-data-handling/) · [03](../03-data-types-and-addressing/) |
| **NE43** | NAMUR's recommendation for transmitter current levels: 3.8 to 20.5 mA carries measurement information, while a current at or below 3.6 mA or at or above 21.0 mA is a failure signal. | [14](../14-analog-and-process-io/) |
| **NFPA 70E, NFPA 79, NEC** | North American standards: NFPA 70E for electrical safety in the workplace, including arc flash (burns from a fault in a high-energy panel); NFPA 79 for the electrical equipment of industrial machinery; and the National Electrical Code (NFPA 70). | [02](../02-electrical-and-field-devices/) |
| **NO, NC** (normally open, normally closed) | Contact types described in the device's shelf state (de-energised, with no process applied), not "during normal operation": a pressure switch's NO contact may be closed for its whole working life. A PLC input simply reads TRUE when current flows, so what matters is the combination of device, contact and wiring. | [02](../02-electrical-and-field-devices/) · [04](../04-ladder-logic/) |
| **Non-retentive assignment** · *Rockwell* | See **`[:=]`** under Numbers and symbols. | [10](../10-structured-text/) |
| **NPN** | See **PNP and NPN**. | [02](../02-electrical-and-field-devices/) |
| **NTP, PTP** | Network Time Protocol sets clocks from a time server over an ordinary network, typically to within milliseconds on a local network; Precision Time Protocol (IEEE 1588) uses hardware time stamps for sub-microsecond agreement. | [16](../16-alarms-and-diagnostics/) · [17](../17-industrial-communications/) |
| **Nuisance alarms** | Alarms that erode the operator's trust: chattering, fleeting (in and out within seconds), stale (active for more than a day), duplicates, and floods (ISA-18.2's example is more than 10 in 10 minutes per operator). Monitoring finds the "bad actors" that cause a large share of the load. | [16](../16-alarms-and-diagnostics/) |

[Back to top](#appendix-b--glossary)

## O

| Term | Meaning | Module |
|---|---|---|
| **OB** (organisation block) · *Siemens* | The operating system's entry points, equivalent to tasks: OB1 main program cycle (free-running, lowest priority), OB30–OB38 cyclic interrupts, OB40–OB47 hardware interrupts, OB100 startup, and error OBs such as OB80 (time error), OB82 (diagnostic interrupt) and OB86 (station failure). Depending on the CPU, a missing error OB can mean the CPU goes to STOP. | [01](../01-what-is-a-plc/) · [11](../11-program-organization/) · [16](../16-alarms-and-diagnostics/) |
| **OEE** (overall equipment effectiveness) | Availability × performance × quality: how much of the planned production time turned into good product at the ideal speed. | [18](../18-hmi-and-scada/) |
| **On-delay, off-delay** (alarms) | An on-delay raises an alarm only after the condition has lasted a set time (curing fleeting alarms); an off-delay clears it only after the condition has been gone a set time (curing chattering). Both add to the response time. | [14](../14-analog-and-process-io/) · [16](../16-alarms-and-diagnostics/) |
| **One-shot** | A signal that is TRUE for exactly one scan (one execution) when an edge occurs. Built from a previous-value bit, from `R_TRIG`/`F_TRIG`, or from vendor instructions. | [06](../06-edges-and-one-shots/) |
| **One writer rule** | Every output, and every variable that stands for a decision, has exactly one place in the program that writes it. Also called the single-writer rule; it is the cure for the double-coil bug. | [04](../04-ladder-logic/) · [11](../11-program-organization/) · [18](../18-hmi-and-scada/) |
| **Online edit** | Changing the logic of a running PLC. Plan it, get it approved, check what it will do on the running plant, then test it and put it under version control like any other change. | [23](../23-commissioning-and-troubleshooting/) · [22](../22-software-engineering/) |
| **`ONS`, `OSR`, `OSF`** · *Rockwell* | Logix ladder one-shots: `ONS` makes the rest of the rung true for one scan, and `OSR`/`OSF` set an output bit for one scan when the rung goes true or false. Each needs its own storage bit; ST and FBD use `OSRI` and `OSFI`. | [06](../06-edges-and-one-shots/) |
| **OOP** (object-oriented programming) | Edition-3 IEC features on top of function blocks: `METHOD` (runs only when called), `INTERFACE` (a contract), `IMPLEMENTS`, `EXTENDS` (inheritance), `THIS`, `SUPER`, `CLASS` and access specifiers. CODESYS and TwinCAT support them; MATIEC does not. | [21](../21-architecture-and-standards/) |
| **OPC UA** | A platform-independent, secure standard (IEC 62541) for exchanging data through typed information models, in which every value carries a StatusCode and a time stamp. It is the successor to the Windows-only OPC Classic, which it has largely replaced. | [17](../17-industrial-communications/) |
| **OpenPLC** | A free, open-source PLC that follows IEC 61131-3. The Editor draws LD and FBD, writes ST and IL, and has a built-in simulator; the Runtime runs programs on a PC, a Raspberry Pi or some Arduino-class boards. It compiles with MATIEC. | [00](../00-start-here/) |
| **Operating modes** (RUN, STOP) | In RUN the CPU executes the scan cycle; in STOP (Rockwell: PROGRAM) it does not, and the outputs go to their configured state, usually off. | [01](../01-what-is-a-plc/) |
| **`OTE`, `OTL`, `OTU`** · *Rockwell* | Output Energize (an ordinary coil), Output Latch (a set coil) and Output Unlatch (a reset coil). On entering Run the prescan clears `OTE` bits but leaves `OTL`/`OTU` bits unchanged. | [04](../04-ladder-logic/) |
| **Overflow, wrap-around** | An integer result too big for its type wraps round: in MATIEC `INT` 32767 + 1 = −32768, silently. Size variables so it cannot happen, or deliberately use only the difference of a free-running count. | [03](../03-data-types-and-addressing/) · [08](../08-counters/) · [09](../09-math-and-data-handling/) |
| **Overload relay, MPCB** | An overload relay protects a motor from overheating by measuring its current; when it trips it opens its auxiliary NC contact 95–96 and closes NO 97–98, without switching the power circuit itself. A motor-protective circuit breaker (MPCB) combines short-circuit and overload protection in one device. | [02](../02-electrical-and-field-devices/) |
| **Override (selector) control** | Two or more controllers share one final element through a low-select or high-select, so that a constraint controller takes over as its limit is approached. | [15](../15-pid-control/) |

[Back to top](#appendix-b--glossary)

## P

| Term | Meaning | Module |
|---|---|---|
| **PAC** (programmable automation controller) | A marketing term for controllers that combine PLC logic with motion, process control and PC-like data handling. Today the line between PLC and PAC is blurred. | [01](../01-what-is-a-plc/) |
| **PackML** | The Packaging Machine Language state model developed by OMAC and published as ISA-TR88.00.02: 17 states, nine commands and unit modes, so that every machine on a line behaves and reports in the same way. | [21](../21-architecture-and-standards/) |
| **PackTags** | PackML's standard names and data types for a machine's Command, Status and Admin data, such as `CntrlCmd` and `StateCurrent`. | [21](../21-architecture-and-standards/) |
| **Permissive** | A condition that must be true before an action may start, but is not necessarily checked again once it is running. On a seal-in rung it sits in the start branch. | [04](../04-ladder-logic/) · [05](../05-boolean-logic-and-fbd/) |
| **PERSISTENT** · *CODESYS* | A CODESYS/TwinCAT extension for variables that survive more kinds of reset than `RETAIN`, generally including a new download. | [11](../11-program-organization/) |
| **PFD, PFDavg, PFH** | Probability of failure on demand and its average over the proof-test interval (the target for low-demand functions); PFH is the average frequency of dangerous failure per hour (the target for high-demand functions). For one channel, PFDavg ≈ λDU × TI / 2. | [20](../20-functional-safety/) |
| **Phantom edge** | An edge a program "sees" without a fresh event in the plant, typically from an edge detector that is called conditionally and compares against stale memory, or at power-up. Call edge detectors every scan and handle the first scan deliberately. | [06](../06-edges-and-one-shots/) |
| **Phase** (ISA-88) | The smallest element of procedural control that can accomplish a process-oriented task, such as dose, heat or agitate. The equipment phase in the PLC does the work behind a phase interface of commands, state, parameters and report parameters. | [21](../21-architecture-and-standards/) |
| **Photoelectric sensor** | A light-based sensor: through-beam (separate emitter and receiver, longest range), retro-reflective (light returned by a reflector) or diffuse (light returned by the object itself). | [02](../02-electrical-and-field-devices/) |
| **Physical model** (ISA-88) | The equipment hierarchy: enterprise, site and area, then the four levels that engineers design and code should mirror: process cell (the equipment that makes a batch; a packaging line in PackML), unit, equipment module and control module. | [21](../21-architecture-and-standards/) |
| **P&ID** (piping and instrumentation diagram) | The process drawing: vessels, pipes, pumps and valves, with every instrument drawn as a tagged bubble. | [02](../02-electrical-and-field-devices/) |
| **PID** (proportional-integral-derivative) | The standard feedback controller. It is written in ideal (ISA standard), parallel or series form with different units, so settings are never copied between blocks without converting them. MATIEC and OpenPLC provide a `PID` block. | [15](../15-pid-control/) |
| **Pilot light** | An indicator lamp. IEC 60204-1 colours: red for emergency or danger, yellow abnormal, green normal, blue action required, white other information; some industries use their own conventions. | [02](../02-electrical-and-field-devices/) |
| **Plant simulation** (lab) | A given function block, such as `FB_PlantSim` in capstone 24-2 or `FB_WetWellSim` in 24-3, that models the process so the acceptance test can inject faults and its observer outputs can act as an independent referee. | [24-2](../24-capstone-projects/24-2-batch-mixing-plant.md) · [24-3](../24-capstone-projects/24-3-pump-station.md) |
| **PLC** (programmable logic controller) | An industrial computer with plant-rated I/O that runs its program in a repeating, predictable scan cycle. The Modicon 084 is widely credited as the first. | [01](../01-what-is-a-plc/) |
| **PLCopen** | The vendor-neutral organisation that promotes IEC 61131-3. It publishes the motion-control function blocks (`MC_Power`, `MC_Home`, `MC_MoveAbsolute` …), safety function blocks and coding guidelines. | [19](../19-motion-and-drives/) · [22](../22-software-engineering/) |
| **`plctest`** | The course's test runner. It compiles your ST with MATIEC, runs it in a simulated PLC with a 10 ms task and checks the lab's `.test` scenarios. `--all` checks a whole folder; `--keep` keeps the generated C code. | [00](../00-start-here/) · [App. E](E-matiec-openplc-notes.md) |
| **`plctest` commands** | `scenario` starts a fresh (cold-started) PLC, `set` writes a variable, `scan` runs one scan (or `scan N`, N scans), `wait` lets PLC time pass, `until … within` runs until a condition is true or fails, `expect` checks a value (`~` for a tolerance) and `print` shows one. | [00](../00-start-here/) |
| **PNP and NPN** (sourcing and sinking) | A PNP (sourcing) sensor switches +24 V onto its output and pairs with a sinking input, whose common is at 0 V; an NPN (sinking) sensor switches its output to 0 V and pairs with a sourcing input. Check where the module's common goes. | [02](../02-electrical-and-field-devices/) |
| **Positional form, velocity form** (PID) | The positional form calculates the whole output every sample; the velocity (incremental) form calculates the change and adds it to the last output, so it cannot wind up and moves off from manual without a bump. | [15](../15-pid-control/) |
| **POU** (program organisation unit) | IEC's name for a piece of code: a `FUNCTION`, a `FUNCTION_BLOCK` or a `PROGRAM`. | [11](../11-program-organization/) · [10](../10-structured-text/) |
| **Preact** (in-flight compensation) | Closing a dosing valve slightly early to allow for the liquid still in flight between the valve and the tank. | [08](../08-counters/) · [24-2](../24-capstone-projects/24-2-batch-mixing-plant.md) |
| **Prescan** · *Rockwell* | The pass a Logix controller makes when it enters Run mode: it clears `OTE` bits and resets non-retentive instructions such as `TON`, leaves `OTL`/`OTU` bits unchanged, and primes one-shots so that no false edge fires on the first scan. | [04](../04-ladder-logic/) · [06](../06-edges-and-one-shots/) |
| **Previous-value bit** | A variable holding a signal's value from the last scan; `Signal AND NOT Prev` is then a rising edge. It must live in memory that survives between scans (`VAR`, never `VAR_TEMP`). | [06](../06-edges-and-one-shots/) |
| **Priority** (alarm) | How urgently the operator must act, set from how bad the consequence is and how soon action is needed. Use three or four levels; ISA-18.2's example is roughly 80 % low, 15 % medium and 5 % high. | [16](../16-alarms-and-diagnostics/) |
| **Priority** (task) | Which task runs first and which may interrupt which. In IEC and CODESYS the smallest number (0) is highest, in Rockwell 1 is highest, and in Siemens the largest number is highest. A higher-priority task usually pre-empts a lower one mid-scan, but MATIEC runs tasks one after another, so they never interrupt each other there. | [11](../11-program-organization/) |
| **Procedural model** (ISA-88) | The hierarchy of recipe instructions: procedure (a whole batch), unit procedure (the part in one unit), operation (a major processing activity) and phase. | [21](../21-architecture-and-standards/) |
| **Procedural state model** (ISA-88) | The example state model for phases and procedures: Idle, Running, Complete, Pausing/Paused, Holding/Held, Restarting, Stopping/Stopped and Aborting/Aborted, driven by Start, Stop, Hold, Restart, Abort, Reset, Pause and Resume. | [21](../21-architecture-and-standards/) |
| **Process image** | The input image, copied from the input modules at the start of each scan, and the output image, copied to the output modules at the end. Every rung in a scan sees the same snapshot. Siemens: PII and PIQ. | [01](../01-what-is-a-plc/) |
| **Process safety time (PST)** | The time between the process starting to go wrong and the hazardous event if the safety function does not act. The function's whole response time, including any delay added in the logic, must fit well inside it. | [20](../20-functional-safety/) |
| **Process switch** | A switch that turns a process variable into an on/off signal (pressure, level, flow, temperature), with a set point and a differential. Its contacts are described in the shelf state. | [02](../02-electrical-and-field-devices/) |
| **Producer/consumer** | A device produces its data at a set rate without being asked, and any number of consumers take it, as in EtherNet/IP implicit I/O, CANopen PDOs and Logix produced/consumed tags. | [17](../17-industrial-communications/) |
| **PROFIBUS DP, PROFIBUS PA** | PI's fieldbus: DP (Decentralised Periphery) runs on RS-485 for remote I/O and drives; PA (Process Automation) carries power and data to field instruments, optionally intrinsically safe, joined to DP through a coupler. | [17](../17-industrial-communications/) |
| **PROFIdrive** | PI's drive profile for PROFIBUS and PROFINET: control and status words (STW1, ZSW1), normalised speed (`16#4000` = 100 %) and standard telegrams. | [17](../17-industrial-communications/) |
| **PROFINET** | PI's industrial Ethernet, with an IO controller (the PLC), IO devices and IO supervisors. Devices are identified by name, described by GSDML files, and exchange RT or scheduled IRT cyclic data. | [17](../17-industrial-communications/) |
| **`PROGRAM`** | The top-level POU, created by the configuration and attached to a task; physical I/O is normally declared here. A Rockwell "program" is something else: a container of routines and tags. | [11](../11-program-organization/) · [App. A](A-vendor-cross-reference.md) |
| **Proof test** | A test that makes a safety function act, or checks each part of it, to find dangerous undetected (DU) failures such as a stuck valve. PFDavg grows with the proof-test interval TI; partial-stroke testing moves a shutdown valve a few percent while the plant runs, to find a stuck valve between full tests. | [20](../20-functional-safety/) |
| **PROPERTY** · *CODESYS* | A CODESYS/TwinCAT extension, not part of IEC 61131-3: it looks like a variable from outside but is implemented by Get and Set methods. | [21](../21-architecture-and-standards/) |
| **Proximity sensor** | A non-contact sensor: inductive (metal, short range), capacitive (almost any material, even through a non-metallic tank wall) or magnetic (a magnet in a cylinder's piston). | [02](../02-electrical-and-field-devices/) |
| **Publish/subscribe** | Publishers send data on a named topic, usually through a broker, and subscribers receive the topics they asked for; neither needs to know the other. MQTT and OPC UA PubSub work this way. | [17](../17-industrial-communications/) |
| **Punch list** | The list of everything found not to meet the specification, from a missing label to a wrong interlock. Each item has an ID, an owner and a category that says what must be closed before the next stage. | [23](../23-commissioning-and-troubleshooting/) |
| **PV** (preset value) | A counter's preset: `Q` switches when the count reaches it. Rockwell: `.PRE`. | [08](../08-counters/) |
| **PV** (process variable) | The measured value that a control loop controls, such as 62.3 °C from TT-101. | [15](../15-pid-control/) |

[Back to top](#appendix-b--glossary)

## Q

| Term | Meaning | Module |
|---|---|---|
| **Quadrature** | Two encoder channels, A and B, a quarter-cycle (90°) apart, whose order gives the direction of travel. Counting every edge of both channels (x4 decoding) gives four counts per pulse. | [08](../08-counters/) · [19](../19-motion-and-drives/) |
| **Quality** (signal) | Status that travels with a value, commonly simplified to Good, Uncertain or Bad, from range checks, card diagnostics, communication status and plausibility checks. The logic uses it to hold, substitute or trip. | [14](../14-analog-and-process-io/) · [17](../17-industrial-communications/) |

[Back to top](#appendix-b--glossary)

## R

| Term | Meaning | Module |
|---|---|---|
| **Random and systematic failures** | Random hardware failures happen at statistically predictable rates and are reduced by redundancy, diagnostics and testing. Systematic failures (wrong requirements, design errors, software bugs) are built in, so redundancy does not help; they are controlled by process. | [20](../20-functional-safety/) |
| **Rate of change** | How fast a value is changing, per second or per minute; used to catch implausible jumps and for alarms. It needs a constant sample time. | [14](../14-analog-and-process-io/) |
| **Ratio control** | Keeping one flow in proportion to a measured "wild" flow by making the controlled flow's setpoint the wild flow times the ratio. | [15](../15-pid-control/) |
| **Rationalisation** (alarms) | Checking each candidate alarm for a real cause, consequence and operator action, then setting its priority and limit and recording it in the master alarm database. | [16](../16-alarms-and-diagnostics/) |
| **Recipe** | The set of values that makes one product. ISA-88 defines general, site, master and control recipes, each with a header, formula, equipment requirements and procedure; the phase logic takes every product-specific number as a parameter. | [12](../12-data-structures/) · [21](../21-architecture-and-standards/) |
| **Redundant (hot-standby) PLC** | Two CPUs: one runs the plant while the other tracks it and takes over without stopping the process. Redundancy is about availability, not safety. | [01](../01-what-is-a-plc/) |
| **Reference designation** | The identifier printed on a drawing and on the device's label, such as `-K1`. The newer IEC 81346 style uses codes such as `-QA1`, with `=` for function and `+` for location (`=PU01+CP1-Q1`). | [02](../02-electrical-and-field-devices/) |
| **Registration** | Recording exactly where a product is when a sensor sees it, so that later actions happen at the right place. In motion control, capturing the axis position in hardware with a touch probe. | [19](../19-motion-and-drives/) · [24-1](../24-capstone-projects/24-1-conveyor-sorting-cell.md) |
| **Regression, regression test** | A regression is a working feature broken by a change somewhere else; regression tests rerun the whole test suite after every change to catch it. Continuous integration (CI) runs them automatically on every commit. | [22](../22-software-engineering/) |
| **Relay** | An electrically operated switch: current through its coil moves its normally-open, normally-closed or changeover (CO) contacts. | [02](../02-electrical-and-field-devices/) |
| **Remote I/O** (distributed I/O) | I/O stations placed near the plant and connected to the CPU over a network such as PROFINET or EtherNet/IP. It saves cabling at the cost of network delay. | [01](../01-what-is-a-plc/) |
| **Reset** | Clearing a latched alarm, fault or trip whose cause has gone. It never starts equipment, does nothing while the cause is still present and acts on the edge of the button; manual reset is the normal choice wherever an automatic reset could restart something and hurt someone. | [16](../16-alarms-and-diagnostics/) · [20](../20-functional-safety/) |
| **Response time** | The time from a change in the plant to the reaction at the outputs: input filter, scan, network delays and output switching. For a safety function it must fit well inside the process safety time. | [01](../01-what-is-a-plc/) · [20](../20-functional-safety/) |
| **`RETAIN`, retentive memory** | Retentive variables keep their values through a warm restart such as a power cut; IEC marks them `RETAIN` (and `NON_RETAIN`). Every Logix tag is retentive, while IEC tools and Siemens keep only what you mark; retain totals, run hours and settings, never run commands or seal-ins without careful thought. | [03](../03-data-types-and-addressing/) · [11](../11-program-organization/) |
| **Retentive timer** | An accumulating timer that keeps its elapsed time when `IN` goes FALSE, until an explicit reset: Rockwell `RTO` (in ST and FBD, `RTOR`), Siemens `TONR`. IEC and MATIEC have none, so the course builds one. | [07](../07-timers/) |
| **Ring buffer** | An array with an index that wraps from the last element back to the first, overwriting the oldest entry; used for event logs and trends. Nothing is moved, so every operation costs the same. | [12](../12-data-structures/) · [09](../09-math-and-data-handling/) |
| **Risk reduction factor (RRF)** | How many times a protection layer cuts the frequency of the hazardous event: RRF = 1 / PFD. | [20](../20-functional-safety/) |
| **Routine** · *Rockwell* | A block of Logix code (LD, FBD, ST or SFC) inside a program; the main routine calls the others with `JSR`. | [11](../11-program-organization/) |
| **RPI** (requested packet interval) | The rate at which EtherNet/IP I/O data is produced. Logix I/O tags update at their module's RPI, asynchronously to the program scan. | [17](../17-industrial-communications/) · [01](../01-what-is-a-plc/) |
| **RS-232, RS-485** | Serial standards. RS-232 is point to point over short distances; RS-485 is a differential, multi-drop, half-duplex bus of up to about 1200 m, terminated with about 120 Ω at both ends and biased at one point. | [17](../17-industrial-communications/) |
| **RTD** (resistance temperature detector) | A resistor whose value rises with temperature; a Pt100 is 100 Ω at 0 °C. Lead resistance adds to the reading, so 3-wire and 4-wire connections compensate for it. | [02](../02-electrical-and-field-devices/) |
| **`R_TRIG`, `F_TRIG`** | The IEC edge-detector FBs: `Q` is TRUE for one execution when `CLK` rises (`R_TRIG`) or falls (`F_TRIG`). In MATIEC and OpenPLC an `F_TRIG` fires on its first call if `CLK` is FALSE, so treat the first scan deliberately. | [06](../06-edges-and-one-shots/) · [App. E](E-matiec-openplc-notes.md) |
| **RTU** (remote terminal unit) | A controller at a remote site, such as a telemetry outstation at a pumping station, that gathers data and carries out commands for a SCADA system, often over slow or unreliable links. Not to be confused with Modbus RTU, the binary serial form of Modbus. | [18](../18-hmi-and-scada/) |
| **Rung** | One horizontal line of a ladder diagram, with contacts forming a condition on the left and coils or boxes acting on the result on the right; Siemens and CODESYS call it a network. Each rung is solved as one Boolean expression, and rungs run top to bottom. | [04](../04-ladder-logic/) |

[Back to top](#appendix-b--glossary)

## S

| Term | Meaning | Module |
|---|---|---|
| **S5TIME, S5 timers** · *Siemens* | Legacy S7-300/400 timers (`S_ODT`, `S_ODTS` and others) using a BCD time format whose longest preset is `S5T#2H46M30S`. New projects use the IEC timers. | [07](../07-timers/) |
| **Safe state** | The condition that is safe for a particular hazard, written down: valve closed, motor stopped, blowdown valve open. It is not always "everything off". | [20](../20-functional-safety/) |
| **Safe Torque Off (STO)** | The basic drive safety function: the drive stops supplying energy that can produce torque and the motor coasts to a stop (stop category 0). It is not electrical isolation and does not hold a vertical axis. | [19](../19-motion-and-drives/) · [20](../20-functional-safety/) |
| **Safety function** | A function that achieves or maintains a safe state in response to a specific hazardous event. It is designed and verified under the functional-safety standards, normally in safety-rated hardware, never by the standard PLC program. | [20](../20-functional-safety/) · [04](../04-ladder-logic/) |
| **Safety instrumented function (SIF)** | One specific safety function with its own SIL, from sensor through logic solver to final element; for example "on high pressure in V-201, close XV-201 within 3 s". | [20](../20-functional-safety/) |
| **Safety instrumented system (SIS)** | The sensors, logic solver(s) and final elements that carry out safety instrumented functions (IEC 61511). | [20](../20-functional-safety/) |
| **Safety integrity level (SIL)** | One of four discrete levels (SIL 1 to 4) of integrity required of a safety function, each a band of PFDavg or PFH; the SIL belongs to the function, not to a device. A good SRS also records the RRF target, and IEC 61511 sets a minimum hardware fault tolerance (HFT) that rises with the SIL. | [20](../20-functional-safety/) |
| **Safety lifecycle** | The IEC 61511 sequence from hazard and risk assessment, through allocation, the SRS, design, installation and validation, to operation, modification and decommissioning. Management of functional safety, verification and independent functional safety assessments (FSA) run alongside every phase. | [20](../20-functional-safety/) |
| **Safety PLC** | A controller certified to IEC 61508 for safety functions (for example GuardLogix or Siemens F-CPUs), with redundant processing, self-diagnostics, safe I/O with test pulses and a protected safety program; some process systems use triple modular redundancy (TMR). A failed safety channel is passivated to a safe value until deliberately reintegrated. A standard PLC is not a safety system. | [01](../01-what-is-a-plc/) · [20](../20-functional-safety/) |
| **Safety relay** | A certified, pre-engineered module for one type of safety function, built from relays with forcibly guided contacts. It adds cross-monitoring of two channels, monitored reset, and external device monitoring (EDM), in which the mirror contacts of its output contactors must be closed before a start. | [20](../20-functional-safety/) |
| **Safety requirements specification (SRS)** | The contract for a safety system. For each SIF it states the safe state, sensors and trip points, voting, response time against the process safety time, SIL and RRF, proof-test interval, reset, bypass and fault behaviour. | [20](../20-functional-safety/) |
| **Safety signature** | A CRC over a safety program and its settings that changes whenever the program changes, proving which version is running. | [20](../20-functional-safety/) |
| **SAT, SIT** (site acceptance and site integration tests) | The SAT tests the installed system on site against its specification (in machine building it often means the final acceptance of the whole machine, so agree what it covers). The SIT proves that it works with the other systems it has interfaces with. | [01](../01-what-is-a-plc/) · [23](../23-commissioning-and-troubleshooting/) |
| **SCADA** (supervisory control and data acquisition) | PC or server software that collects data from many PLCs and RTUs, often over wide areas, for overview displays, alarms, trends, history and remote commands. | [18](../18-hmi-and-scada/) |
| **Scaling** | Converting raw counts to engineering units (bar, m, °C) with a straight line through two known points, the two-point form. Integer versions must avoid overflow and divide last. | [09](../09-math-and-data-handling/) · [14](../14-analog-and-process-io/) |
| **Scan, scan cycle** | The PLC's repeating loop: read the inputs into the input image, execute the program top to bottom, write the output image to the outputs, then housekeeping. Each pass is one scan. | [01](../01-what-is-a-plc/) |
| **Scan time** | The time for one complete scan (cycle time). It varies with the program, the work it does, the CPU and the communication load, and a pulse shorter than one scan can be missed. | [01](../01-what-is-a-plc/) |
| **SCL** (Structured Control Language) · *Siemens* | Siemens' name for Structured Text. Rockwell uses the same letters for an unrelated scaling instruction. | [10](../10-structured-text/) · [App. A](A-vendor-cross-reference.md) |
| **Seal-in** | A rung in which the output's own contact holds it on after the Start button is released, until a stop breaks it: `Motor := (StartPB OR Motor) AND StopPB_NC;`. The software version of 3-wire control. | [04](../04-ladder-logic/) |
| **Self-regulating, integrating and runaway processes** | A self-regulating process settles at a new steady value after a step (a heated stream's temperature); an integrating one changes at a new rate instead (a tank level with a pumped outlet) and responds badly to too much integral action; a runaway process accelerates away and needs expert design. | [15](../15-pid-control/) |
| **Sequence of events (SOE)** | Recording changes of selected digital signals with time stamps of about a millisecond, taken at the input rather than in a program scan, so the true order of a fast trip can be established. | [16](../16-alarms-and-diagnostics/) |
| **Servo** | A motor with built-in feedback (encoder or resolver) driven by a servo drive that runs nested current, velocity and position loops, for fast and precise positioning. | [19](../19-motion-and-drives/) |
| **Set and reset coils** | Ladder coils `--(S)--` and `--(R)--` that write TRUE or FALSE only when powered and otherwise leave the bit alone. If both act on the same bit in one scan, the later rung wins. | [04](../04-ladder-logic/) |
| **Set-dominant, reset-dominant** | Which input wins when set and reset are both TRUE. Run commands must be reset (stop) dominant; trip and fault memories are set-dominant so a held reset cannot hide a live fault. | [04](../04-ladder-logic/) |
| **Setpoint** (SP) | The value you want the PV to have. | [15](../15-pid-control/) |
| **Setpoint validation** | The PLC checks every value that arrives from outside (range, NaN, rate of change, authority) and rejects or clamps it before use; the PLC is the last line of defence. | [18](../18-hmi-and-scada/) · [22](../22-software-engineering/) |
| **SFC** (Sequential Function Chart) | The IEC language for sequences: steps with actions, joined by transitions with conditions, with alternative and simultaneous branches. Siemens calls it GRAPH; MATIEC compiles a textual form. | [13](../13-sequential-control/) |
| **Shelving, suppression by design, out of service** | The three legitimate ways to keep an alarm from the operator: shelving by the operator for a limited time, with a reason and a log; suppression by design (state-based alarming) when the alarm is meaningless in the current plant state; and out of service for maintenance under a permit. Disabling or forcing alarms because they are annoying is not legitimate. | [16](../16-alarms-and-diagnostics/) |
| **Shift register** | An array or word whose contents move one place on each pulse, used to track products along a fixed-pitch conveyor; shift on the edge of the pulse, never on its level. Rockwell's `BSL` and `BSR` shift a `DINT` array by one bit per rung transition. | [09](../09-math-and-data-handling/) |
| **Short-circuit evaluation** | Stopping the evaluation of a Boolean expression as soon as the result is known. IEC allows but does not require it (MATIEC does it, CODESYS offers `AND_THEN`/`OR_ELSE`), so portable code never relies on it. | [10](../10-structured-text/) |
| **Soft PLC** | PLC runtime software on an industrial PC with a real-time kernel and I/O over a fieldbus, such as TwinCAT or CODESYS Control. | [01](../01-what-is-a-plc/) |
| **Solenoid valve** (single, double) | A valve moved by a coil, often switching instrument air to a process valve's actuator. A single-solenoid, spring-return valve is actuated only while energised, so losing the signal, the 24 V or the air sends it to its fail position (the choice for trips); a double-solenoid valve stays where it was last pulsed (fail last) until the PLC energises the other coil. | [02](../02-electrical-and-field-devices/) |
| **SOP, POS** (sum of products, product of sums) | Canonical forms of Boolean logic read off a truth table: SOP ORs together the AND terms of the 1-rows (the natural shape of ladder), POS ANDs the OR terms of the 0-rows. | [05](../05-boolean-logic-and-fbd/) |
| **Sparkplug B** | An Eclipse specification on top of MQTT with a fixed topic namespace, birth and death certificates for state awareness, and report by exception. | [17](../17-industrial-communications/) |
| **Split-range control** | One controller output driving two or more final elements over different parts of its range, such as heating and cooling on one vessel. | [15](../15-pid-control/) |
| **Spurious trip** | A trip without a real demand, caused by a safe failure. It is not harmless: shutdowns and restarts are hazardous phases, and a trip that keeps "crying wolf" invites bypassing. | [20](../20-functional-safety/) |
| **`SR`, `RS`** | The IEC bistable FBs: `SR` is set-dominant (inputs `S1`, `R`), `RS` is reset-dominant (`S`, `R1`); the input whose name ends in 1 wins. Siemens names its boxes the other way round, so check the pin names. | [04](../04-ladder-logic/) · [App. A](A-vendor-cross-reference.md) |
| **SS1, SS2, SOS, SLS** (drive safety functions) | Drive safety functions from IEC 61800-5-2: Safe Stop 1 ramps down then applies STO; Safe Stop 2 ramps down and holds under power; Safe Operating Stop monitors standstill; Safely-Limited Speed monitors a speed limit. | [19](../19-motion-and-drives/) |
| **ST** (Structured Text) | The IEC high-level textual language, suited to calculations, data handling, loops, state machines and reusable FBs. Siemens calls it SCL. All the course's lab files are ST. | [10](../10-structured-text/) |
| **Star-delta starting** | Starting a motor with its windings in star (about one third of the direct-on-line current and torque), then switching to delta after a set time. The star and delta contactors must never close together; soft starters and VFDs are the modern alternatives. | [02](../02-electrical-and-field-devices/) · [07](../07-timers/) |
| **Starter file, solution, interface table** (lab) | Each lab's `labs/starter/` file holds the declarations and configuration with placeholder logic and must fail the test; `labs/solutions/` holds a reference solution that passes. The lab's interface table lists the exact names the test uses: keep those, and everything else is your choice. | [00](../00-start-here/) |
| **Starts per hour** | The maximum number of starts a motor maker allows per hour, because every start heats the motor. Logic enforces it with minimum off times or a rolling-window count. | [07](../07-timers/) · [24-3](../24-capstone-projects/24-3-pump-station.md) |
| **State complete (SC)** | In PackML, the signal from the machine's own logic that the current acting state (or Execute) has finished its work, so the state machine can move on. It must belong to the current state only. | [21](../21-architecture-and-standards/) |
| **State machine** | Logic that is always in exactly one state, held in one variable, and moves between states on defined transitions. In ST it is usually a `CASE` on an enumeration. | [13](../13-sequential-control/) |
| **State/output table** | A table of what every output does in every state, written before the code and reviewed with the process engineer. An empty cell is a question nobody has answered yet. | [13](../13-sequential-control/) |
| **Step, step flag, step time** (SFC) | A step is active or inactive, and each chart has exactly one initial step, active at start-up. `Step.X` is TRUE while the step is active and `Step.T` is how long it has been active. | [13](../13-sequential-control/) |
| **Step watchdog** | A maximum time for a state that waits for the plant; when it expires, the sequence goes to a fault state instead of waiting for ever. | [13](../13-sequential-control/) |
| **Stepper motor** | A motor that moves one step per pulse (typically 1.8°), driven by pulse and direction signals. A standard stepper is open loop and loses steps silently if overloaded. | [19](../19-motion-and-drives/) |
| **Stiction** | Static friction in a control valve that makes it stick and then jump. It causes a cycling loop that retuning will not cure. | [15](../15-pid-control/) |
| **Stop categories** | From IEC 60204-1: category 0 stops by immediate removal of power; 1 is a controlled stop and then removal of power; 2 is a controlled stop with power left available. | [19](../19-motion-and-drives/) · [20](../20-functional-safety/) |
| **Stop-dominant, start-dominant** | Where the stop sits in a seal-in: in series with the whole OR (stop wins) or only in the seal-in branch (start wins, even over a broken stop wire). Motors, pumps, heaters and valves are always stop-dominant. | [04](../04-ladder-logic/) |
| **`STRING`** | A text type. The maximum length differs between platforms; MATIEC's plain `STRING` holds up to 126 characters and rejects length declarations such as `STRING[20]`. | [12](../12-data-structures/) · [03](../03-data-types-and-addressing/) |
| **Structure** (`STRUCT`) | A derived type that groups named members of different types, such as a pump's command, status and configuration data; copied whole with one assignment. Called a UDT in Rockwell and many site standards. | [12](../12-data-structures/) |
| **Stuck (frozen) signal** | A value that has stopped following the process but still looks normal, for example a transmitter left in loop-test mode or a plugged impulse line. Range checks cannot see it. | [16](../16-alarms-and-diagnostics/) |
| **Studio 5000 Logix Designer** · *Rockwell* | Rockwell's programming software for ControlLogix and CompactLogix (Logix) controllers. Micro800 controllers use the free Connected Components Workbench (CCW) instead. | [01](../01-what-is-a-plc/) |
| **Subrange** | An integer type restricted to a range, such as `INT(0..100)`. MATIEC does not enforce it at all, so treat it as documentation and still validate outside values. | [12](../12-data-structures/) |
| **Substitute value** | A defined value used in place of a bad or lost signal, chosen to drive the logic to its safe state. The alternatives are holding the last good value (for a limited time) or switching to another source. | [14](../14-analog-and-process-io/) · [17](../17-industrial-communications/) |
| **Suppressor** | A component across a coil that absorbs the voltage spike at switch-off: a freewheeling diode, a diode plus Zener or TVS diode, an RC snubber or a varistor. | [02](../02-electrical-and-field-devices/) |
| **Synchronous speed, slip** | The speed of a motor's rotating field, n = 120 × f / p: 1500 rpm for a 4-pole motor at 50 Hz. An induction motor turns slightly slower; that difference, the slip, produces the torque and rises with load. | [19](../19-motion-and-drives/) |
| **Systematic capability** | Evidence that a device was developed with enough rigour against systematic faults for a given SIL, shown by an IEC 61508 certificate or, under IEC 61511, a prior-use justification. | [20](../20-functional-safety/) |

[Back to top](#appendix-b--glossary)

## T

| Term | Meaning | Module |
|---|---|---|
| **Tag** | A named variable (a symbol), as opposed to an absolute address such as `%IX0.3`, `I0.3` or `N7:0`. Rockwell Logix is entirely tag-based, with controller-scoped and program-scoped tags; on a P&ID, the tag is the instrument's ISA-5.1 identifier. | [03](../03-data-types-and-addressing/) · [02](../02-electrical-and-field-devices/) |
| **Task** | What runs programs: cyclic (at a fixed interval), event (once on each rising edge of a trigger, `TASK T(SINGLE := Trigger, …)`) or freewheeling (as fast as possible), each with a priority and a watchdog. | [01](../01-what-is-a-plc/) · [11](../11-program-organization/) |
| **TCP, UDP, port** | TCP gives a reliable connection with acknowledgement and retransmission; UDP sends datagrams without them. The port number selects the service, such as 502 for Modbus TCP. | [17](../17-industrial-communications/) |
| **Test-driven development (TDD)** | Writing a failing test for the next small requirement first (red), then the least code that makes it pass (green), then tidying up with all tests still passing (refactor). | [22](../22-software-engineering/) |
| **Test pulses** | Brief OFF pulses that safety inputs put on the sensor supply, and safety outputs on their own switches, to detect shorts and prove that the switches can open. Light curtains and scanners provide two tested outputs of this kind, called OSSDs. | [20](../20-functional-safety/) |
| **Test specification** | The document that says what will be tested, how, and what counts as a pass, including what must not happen; written from the FDS and the C&E matrices. | [23](../23-commissioning-and-troubleshooting/) · [22](../22-software-engineering/) |
| **Thermocouple** | Two different metals joined at the measuring junction, giving a small voltage that depends on the temperature difference to the cold junction. It needs the right extension cable and cold-junction compensation. | [02](../02-electrical-and-field-devices/) |
| **TIA Portal** · *Siemens* | Siemens' engineering software for S7-1200 and S7-1500 CPUs (STEP 7), HMIs and drives. | [00](../00-start-here/) · [01](../01-what-is-a-plc/) |
| **`TIME`, `DATE`, `TOD`, `DT`** | `TIME` is a duration, written `T#1m30s`; `DATE`, `TIME_OF_DAY` (`TOD`) and `DATE_AND_TIME` (`DT`) hold calendar values, which is why no variable may be called `dt`. Sizes differ between platforms, and MATIEC's `TIME_TO_DINT` returns seconds where CODESYS returns milliseconds, so compare TIME values directly. | [07](../07-timers/) · [03](../03-data-types-and-addressing/) · [App. E](E-matiec-openplc-notes.md) |
| **Timer** | A function block instance that measures time from the PLC clock, with pins `IN`, `PT` (preset time), `Q` and `ET` (elapsed time, never above `PT`). Call each instance once per scan, unconditionally. | [07](../07-timers/) |
| **Time-stamping** | Recording when an event happened, ideally in UTC (converted to local time only for display) and as close to the source as possible. The resolution decides whether the order of fast events can be trusted. | [16](../16-alarms-and-diagnostics/) |
| **Toggle** (push-on/push-off) | One button that switches an output on with one press and off with the next; built on an edge, never on the level. | [06](../06-edges-and-one-shots/) |
| **`TON`, `TOF`, `TP`** | The three IEC timers. `TON` (on-delay): `Q` goes TRUE when `IN` has been TRUE for `PT` and FALSE at once when `IN` falls. `TOF` (off-delay): `Q` goes TRUE at once and FALSE `PT` after `IN` falls; `TP` (pulse): one pulse of length `PT` on a rising edge, whatever `IN` does afterwards. | [07](../07-timers/) |
| **`TONR`** · *Siemens*, *Rockwell* | A false friend: Siemens `TONR` is the retentive (accumulating) on-delay; Rockwell's ST/FBD `TONR` is an ordinary on-delay with a reset input, and its retentive timer is `RTOR`. | [07](../07-timers/) · [App. A](A-vendor-cross-reference.md) |
| **Top 20 Secure PLC Coding Practices** | A community list, first published in 2021, of things the PLC program itself can do to resist misuse and reveal attacks, such as validating every value that comes from outside. | [22](../22-software-engineering/) |
| **Totaliser** | Logic that integrates a rate (m³/h) into a quantity (m³). A `REAL` total loses small increments as it grows, so totalise in `LREAL` or in whole units plus a fraction. For custody transfer (flow that is bought and sold) the legal total comes from an approved flow computer or the meter. | [09](../09-math-and-data-handling/) |
| **Tracking** (product) | Following each product's position along a conveyor, with a shift register or a table of parts, so that actions happen at the right place. | [09](../09-math-and-data-handling/) · [24-1](../24-capstone-projects/24-1-conveyor-sorting-cell.md) |
| **Transition, transition condition** | A move from one state or step to the next, and the Boolean condition (guard) that allows it. In SFC a transition fires when all the steps above it are active and its condition is TRUE. | [13](../13-sequential-control/) |
| **Transmitter** | A field instrument that measures a process variable and sends it as a standard signal, usually 4–20 mA, often with HART. | [14](../14-analog-and-process-io/) · [02](../02-electrical-and-field-devices/) |
| **Trip** | A protective action that brings the process or equipment to a safe state and latches: it stays tripped until the cause has cleared and someone resets it. | [05](../05-boolean-logic-and-fbd/) · [16](../16-alarms-and-diagnostics/) |
| **`TRUNC`, `REAL_TO_INT`** | `TRUNC` cuts the fraction off towards zero; `REAL_TO_INT` rounds to the nearest integer, with MATIEC sending exact halves to the even neighbour. | [09](../09-math-and-data-handling/) · [App. E](E-matiec-openplc-notes.md) |
| **Truth table** | A table of every input combination and its output: the complete specification of a piece of combinational logic. | [05](../05-boolean-logic-and-fbd/) |
| **Two-hand control** | A device that keeps both of an operator's hands on the controls during hazardous motion (ISO 13851): the output only while both are held, both released before a new cycle and, for type III, pressed within 0.5 s of each other. A safety function, not ordinary PLC logic. | [07](../07-timers/) |
| **Two's complement** | The way signed integers are stored: the top bit has a negative weight. Negate a number by inverting every bit and adding one. | [03](../03-data-types-and-addressing/) |
| **Typed conversion** | IEC languages are strongly typed, so types are converted explicitly with named functions such as `INT_TO_REAL`, `REAL_TO_INT` or `WORD_TO_INT`. MATIEC requires the typed names and rejects the generic `TO_INT`; vendors relax the rules to different degrees. | [09](../09-math-and-data-handling/) · [App. E](E-matiec-openplc-notes.md) |

[Back to top](#appendix-b--glossary)

## U

| Term | Meaning | Module |
|---|---|---|
| **Unit** (ISA-88) | Equipment in which one or more major processing activities happen, usually on one batch at a time, such as a reactor. In PackML a machine is a unit. | [21](../21-architecture-and-standards/) |
| **Unit mode** (PackML) | What kind of work the machine is doing: 1 Production, 2 Maintenance, 3 Manual, plus user-defined modes. The mode and the state are independent. | [21](../21-architecture-and-standards/) |
| **Unit test** | A test of one function or FB in isolation, through its interface, driven by a small test harness. Each test follows arrange, act, assert: set up a known state, do one thing, then check the result, including what must not have happened. | [22](../22-software-engineering/) |

[Back to top](#appendix-b--glossary)

## V

| Term | Meaning | Module |
|---|---|---|
| **Valve positioner** | The device on a control valve that moves it until its position matches the 4–20 mA signal from an analog output. Which end of the range means "closed" is configured in the positioner, while the fail position on loss of air comes from the actuator's spring; smart positioners support HART. | [02](../02-electrical-and-field-devices/) |
| **`VAR`, `VAR_TEMP`** | `VAR` holds private variables that FBs and programs keep between calls; `VAR_TEMP` variables start afresh on every call, so never keep a previous-value bit there. | [11](../11-program-organization/) |
| **`VAR CONSTANT`** | A named value that cannot be written. Use constants for numbers with a meaning, enumerations for closed sets of names; MATIEC does not accept a constant as a `CASE` label. | [11](../11-program-organization/) · [12](../12-data-structures/) |
| **`VAR_GLOBAL`, `VAR_EXTERNAL`** | A global is declared with `VAR_GLOBAL` (in the configuration, for MATIEC) and used in a POU through `VAR_EXTERNAL`; CODESYS uses global variable lists (GVLs) instead. Keep globals few, and give each one writer. | [11](../11-program-organization/) |
| **`VAR_INPUT`, `VAR_OUTPUT`, `VAR_IN_OUT`** | The interface of a POU: inputs the caller writes (an FB keeps the last value), outputs the POU writes, and in-out parameters that are the caller's own variable, passed by reference. | [11](../11-program-organization/) |
| **Version control** | Keeping every version of the project, with who changed what and why, in a system such as Git. PLC projects need their code exported as text to be diffed usefully. | [22](../22-software-engineering/) |
| **V/f control, vector control** | V/f (scalar) control keeps voltage over frequency constant, simple and the usual choice for pumps and fans; vector control models the motor to control flux and torque separately, giving high torque at low speed. Above base speed the drive cannot raise the voltage further, so the available torque falls (field weakening). | [19](../19-motion-and-drives/) |
| **VFD** (variable-frequency drive) | A drive that controls an AC motor's speed through its supply frequency. The PLC sends run, direction and a speed reference and reads status and faults; stop it with the run command, not by switching its supply. | [02](../02-electrical-and-field-devices/) · [19](../19-motion-and-drives/) |
| **Virtual commissioning, digital twin** | Virtual commissioning runs the real control software, on an emulated or real controller, against a simulated plant to test it before site; it never replaces I/O checkout and loop checks. A digital twin is a plant model kept in step with the real plant over its life. | [22](../22-software-engineering/) |
| **Voltage, current, resistance, Ohm's law** | Voltage is electrical "pressure" (V), current the flow of charge (A) and resistance the opposition to it (Ω), related by V = I × R. Current flows only round a complete loop, so a break anywhere stops it everywhere; 4–20 mA through a 250 Ω burden gives 1–5 V. | [02](../02-electrical-and-field-devices/) |

[Back to top](#appendix-b--glossary)

## W

| Term | Meaning | Module |
|---|---|---|
| **Warm restart** | See **Cold restart, warm restart**. | [03](../03-data-types-and-addressing/) |
| **Watchdog** | A timer that detects something that has stopped: the CPU's scan-time watchdog catches a program that never finishes its scan; an application watchdog (a heartbeat) proves a partner is alive; a step watchdog catches a sequence waiting too long. | [01](../01-what-is-a-plc/) · [13](../13-sequential-control/) · [16](../16-alarms-and-diagnostics/) |
| **Wet well, rising main** | At a wastewater pumping station the wet well is the chamber where sewage collects, and the pumps lift it into the rising main (North America: force main), a pressure pipe to a higher sewer. In capstone 24-3, float switches back up the level transmitter and a dry-run cut-out stops all pumps at low level in every mode. | [24-3](../24-capstone-projects/24-3-pump-station.md) |

[Back to top](#appendix-b--glossary)

## X

| Term | Meaning | Module |
|---|---|---|
| **`XIC`, `XIO`** · *Rockwell* | Examine If Closed (TRUE when the bit is 1, drawn `--] [--`) and Examine If Open (TRUE when the bit is 0, drawn `--]/[--`). They examine bits, not devices, so a healthy NC stop button uses `XIC`. | [04](../04-ladder-logic/) |
| **`XOR`, `XNOR`** | Exclusive OR is TRUE when its two inputs differ; XNOR (equivalence) when they are equal. Useful for discrepancy checks and change detection. | [05](../05-boolean-logic-and-fbd/) |
| **XV** | The usual tag for an on/off (block) valve, from ISA-5.1's "X" for unclassified; companies also use SDV or ESDV for shutdown valves. | [02](../02-electrical-and-field-devices/) |

[Back to top](#appendix-b--glossary)

## Z

| Term | Meaning | Module |
|---|---|---|
| **Ziegler–Nichols** | Classic 1942 tuning rules (the closed-loop ultimate-gain method and the open-loop reaction-curve method) aiming at quarter-amplitude decay. The settings are aggressive: use them as a starting point and detune. | [15](../15-pid-control/) |
| **Zone** (hazardous area) | IEC 60079 classifies hazardous areas by how likely an explosive atmosphere is: Zone 0 continuously or for long periods, Zone 1 occasionally in normal operation, Zone 2 not normally and only briefly (dusts: Zones 20 to 22). North America traditionally uses classes and divisions, and equipment is also marked with a gas group (IIA to IIC) and a temperature class (T1 to T6). | [02](../02-electrical-and-field-devices/) |

[Back to top](#appendix-b--glossary)

---

Back to the [course home](../README.md) · [Module 00 — Start Here](../00-start-here/) ·
Related: [Appendix A — Vendor cross-reference](A-vendor-cross-reference.md) · [Appendix E — MATIEC and OpenPLC notes](E-matiec-openplc-notes.md)
