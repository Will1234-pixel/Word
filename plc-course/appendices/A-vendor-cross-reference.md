# Appendix A — Vendor Cross-Reference

This appendix is a lookup table. The course teaches IEC 61131-3, the international standard,
and tests everything with OpenPLC's compiler. On site you will meet Siemens TIA Portal and
Rockwell Studio 5000 far more often than OpenPLC, and sometimes Beckhoff, Schneider,
Mitsubishi or Omron. When you know what you want in IEC terms, these tables tell you what
each vendor calls it and where it behaves differently. It does not replace the vendor's
manual. Use it to find the right page of the manual.

**How to read the tables**

- **IEC / CODESYS / OpenPLC** is IEC 61131-3 as implemented by CODESYS (and therefore Beckhoff
  TwinCAT 3 and Schneider EcoStruxure Machine Expert, which are built on CODESYS) and by
  OpenPLC/MATIEC, the compiler behind this course's `plctest`. Where they differ, the cell
  says so. [Appendix E](E-matiec-openplc-notes.md) lists MATIEC's gaps.
- **Siemens** is TIA Portal (STEP 7) for S7-1200 and S7-1500 CPUs, in the languages LAD, FBD,
  SCL and GRAPH. Older S7-300/400 differences are noted where they matter, because you will
  meet migrated code. The newer S7-1200 G2 family does not always match the classic S7-1200
  rows here, so check its own documentation.
- **Rockwell** is Studio 5000 Logix Designer for ControlLogix and CompactLogix ("Logix"), in
  Ladder Diagram, Function Block Diagram, Structured Text and SFC. The Micro800 family,
  programmed with Connected Components Workbench (CCW), is a different, more IEC-like
  environment. It appears in [section A.1.4](#a14-other-platforms-at-a-glance).
- **"—"** means there is no direct equivalent. **"Check the manual"** means that something
  exists but the details depend on the CPU, firmware or software version.
- **Rockwell renamed some instructions.** From Logix Designer version 36, several instruction
  mnemonics took IEC-style names (`MOV` became `MOVE`, `EQU` became `EQ`, and so on:
  [section A.7](#a7-maths-comparison-move-conversion-and-scaling)). Most existing code,
  manuals, forum posts and the other modules of this course use the older names. Where the
  name changed, the tables show `old`/`new`.

Vendor tools change with every release: instructions are added, renamed and retired, and
what an S7-1200 supports is not always what an S7-1500 supports. Treat every row as a
starting point, and confirm it in the instruction help of the tool and version you are using.

> **Safety.** Translating logic between tools does not make it suitable for a safety
> function. Emergency stops, guard interlocks and process trips belong in safety-rated
> systems designed to IEC 62061, ISO 13849 or IEC 61511 ([Module 20](../20-functional-safety/)).
> The examples here are training material.

## A.1 Terminology

### A.1.1 Languages

| IEC 61131-3 | Siemens TIA Portal | Rockwell Studio 5000 (Logix) | Notes |
|---|---|---|---|
| Ladder Diagram (LD) | LAD | Ladder Diagram (often called RLL, relay ladder logic) | Rockwell rungs can also be shown and edited as rung text: `XIC(A)OTE(B);` |
| Function Block Diagram (FBD) | FBD | Function Block Diagram (sheets, free placement) | CODESYS also has CFC (Continuous Function Chart), a free-placement FBD |
| Structured Text (ST) | SCL (Structured Control Language) | Structured Text | Same core language. Declarations, calls and names differ ([Module 10](../10-structured-text/)) |
| Sequential Function Chart (SFC) | GRAPH (S7-1500 and S7-300/400, not S7-1200) | SFC | Step and action control differ between tools ([Module 13](../13-sequential-control/)) |
| Instruction List (IL), deprecated in edition 3 | STL (S7-1500 and S7-300/400, not S7-1200) | — | Meet it in old code, don't write new code in it |
| — | CEM (Cause Effect Matrix): recent TIA Portal versions and CPU firmware, S7-1200 and S7-1500, in FBs only | — | Of interest if you work with C&E charts. A standard PLC running a C&E matrix is still not a safety system |

### A.1.2 Project structure and program organisation

| IEC 61131-3 / CODESYS / OpenPLC | Siemens TIA Portal | Rockwell Studio 5000 (Logix) | Notes |
|---|---|---|---|
| Project; `CONFIGURATION` and `RESOURCE` (CODESYS: *Device* and *Application*) | Project holding one or more stations (PLCs, HMIs, drives) | Project file (`.ACD`) for **one** controller | Several Logix controllers means several projects |
| Program organisation unit (POU): `PROGRAM`, `FUNCTION_BLOCK`, `FUNCTION` | Blocks: OB, FB, FC, plus DBs for data | Programs, routines and Add-On Instructions | [Module 11](../11-program-organization/) |
| `TASK` (cyclic or event) | Organisation block (OB): OB1 program cycle, OB30–OB38 cyclic interrupts, OB40+ hardware interrupts, OB100 startup | Task: continuous (at most one), periodic, event. Priorities 1 (highest) to 15 | CODESYS: *Task Configuration*, priorities 0 (highest) to 31 |
| `PROGRAM` instance attached to a task | No direct equivalent: OB1 calls your FCs and FBs | **Program**: a container with its own tags and routines, scheduled by a task | A Logix "program" holds code. It is not itself code |
| Body of a POU | Block body, in **networks** (LAD/FBD) | **Routine** (LD, FBD, ST or SFC). The main routine calls the others with `JSR` | |
| `FUNCTION` | FC (function) | No user-defined functions. Use an AOI, or `JSR` with parameters | |
| `FUNCTION_BLOCK` type | FB | **Add-On Instruction (AOI)** | AOI definitions cannot be edited online |
| FB instance | Instance DB (single instance) or multi-instance in the caller's *Static* section | Backing tag of the AOI's data type | |
| Global variables (`VAR_GLOBAL`, CODESYS GVL) | PLC tags (tag table) and global DBs | Controller-scoped tags | |
| Local variables (`VAR`, `VAR_TEMP`) | *Static* and *Temp* sections of the block interface | Program-scoped tags; AOI local tags | |
| FB interface (`VAR_INPUT`, `VAR_OUTPUT`, `VAR_IN_OUT`) | *Input*, *Output*, *InOut* | AOI Input, Output and InOut parameters; program parameters in newer versions | |
| Retentive data (`VAR RETAIN`, CODESYS `PERSISTENT`) | *Retain* setting per M-memory range, per member of optimised DBs | All tags keep their values through a power cycle | See the power-up notes in A.4 |
| `STRUCT` type (CODESYS: DUT) | PLC data type (UDT); anonymous `Struct` | User-Defined data type (UDT) | [Module 12](../12-data-structures/) |
| Enumeration | Traditionally none: named constants (check your version) | None: `DINT` values with descriptions | |
| Library | Project library and global libraries, with versioned types | Export and import (`.L5X`) of AOIs, UDTs, rungs, routines and programs | CODESYS: *Library Manager*, versioned libraries |

### A.1.3 Working with the tool

| Action | CODESYS | Siemens TIA Portal | Rockwell Studio 5000 | Notes |
|---|---|---|---|---|
| Connect to the running PLC | Login / Logout | Go online / Go offline | Go Online / Go Offline | "Online" = connected and monitoring |
| PC → PLC | Login with download; **online change** for small edits | Download to device | Download | A full download usually stops the PLC. Plan it |
| PLC → PC | Source upload, only if the source was stored in the PLC | Upload from device | Upload | Always keep the offline project under version control ([Module 22](../22-software-engineering/)) |
| Edit while running | Online change | Download changed blocks in RUN; S7-1200 and S7-1500 can add tags to a block without reinitialising it, within the block's memory reserve | Online edits: start pending edits, accept, test, assemble | Check the consequences before accepting |
| Watch live values | Watch lists, online view in the editor | Monitoring (glasses icon), watch tables | Monitor Tags, Watch window, live ladder colouring | |
| Write a value once | Write values | *Modify* in a watch table | Type a new value in Monitor Tags | |
| Force a value | Force values | Force table. S7-1200/1500 force only I/O | I/O forces (install, then enable) | Forces override logic. Record and remove them |
| Record values over time | Trace | Trace | Trend | Useful for timing and PID ([Module 23](../23-commissioning-and-troubleshooting/)) |
| Find every use of a name | Cross Reference List | Cross-references; assignment list for I/O and M bits | Cross Reference | The first tool to reach for when debugging |
| Compare versions | Project compare | Compare editor (offline/offline, offline/online) | Logix Designer Compare Tool | |
| Read faults | Device log | Online & diagnostics, diagnostic buffer | Controller Properties: Major Faults and Minor Faults tabs | [Module 16](../16-alarms-and-diagnostics/) |

A download replaces values as well as code: see the last row of the false friends in A.14.

### A.1.4 Other platforms at a glance

| Topic | Rockwell CCW (Micro800) | Beckhoff TwinCAT 3 | Schneider EcoStruxure Machine Expert | Mitsubishi GX Works3 | Omron Sysmac Studio |
|---|---|---|---|---|---|
| Basis | IEC 61131-3 languages, named variables | Built on CODESYS; IEC edition 3 including OOP | Built on CODESYS V3 | MELSEC devices and instructions, plus IEC-style labels and FBs | IEC-style variables and FBs |
| Languages | LD, FBD, ST | LD, FBD, ST, SFC, CFC (IL) | LD, FBD, ST, SFC, CFC (IL) | Ladder, ST, FBD/LD, SFC | Ladder, ST |
| Reusable blocks | User-defined function blocks (UDFBs) | `FUNCTION_BLOCK` with methods, properties, interfaces | `FUNCTION_BLOCK` | FBs | FBs and functions |
| Physical I/O in code | Embedded I/O variables such as `_IO_EM_DI_00` | `AT %I*` / `AT %Q*` variables linked to terminals in the I/O tree | I/O mapping to variables | Devices `X` and `Y` (FX5: octal numbering) | Device variables assigned in the I/O Map |
| Transfer to controller | Download | Activate configuration, then Login | Login | Write to PLC / Read from PLC | Synchronize |
| First-scan flag | System variable `_SYSVA_FIRST_SCAN` (firmware 2 and later; some sources write it with two leading underscores, so copy it from CCW's system-variable list) | `_TaskInfo[GETCURTASKINDEXEX()].FirstCycle` | Check the manual | Special relay `SM402` (on for one scan after RUN) | `P_First_RunMode` (first task period after the change to RUN); `P_First_Run` (first period after a program starts) |
| Timers | IEC `TON`, `TOF`, `TP` with `IN`, `PT`, `Q`, `ET` | `TON`, `TOF`, `TP` (Tc2_Standard library) | `TON`, `TOF`, `TP` (Standard library) | Timer devices `T` (retentive `ST`) plus IEC-style timer FBs. Check the time base | `TON`, `TOF`, `TP` and vendor timer instructions. Check the manual |

The other sections concentrate on IEC, Siemens and Rockwell. For TwinCAT and Machine Expert,
read the CODESYS column. Mitsubishi bit logic uses `LD`/`LDI` (NO/NC contact), `OUT`,
`SET`/`RST`, pulse contacts `LDP`/`LDF` and pulse outputs `PLS`/`PLF`. Schneider's separate
*Machine Expert – Basic* (for the smallest Modicon controllers) is not CODESYS-based and uses
its own `%I0.0`-style addressing.

## A.2 Data types

### A.2.1 Elementary types

| IEC 61131-3 / CODESYS / OpenPLC | Siemens S7-1200/1500 | Rockwell Logix | Notes |
|---|---|---|---|
| `BOOL` | `Bool` | `BOOL` | Logix `BOOL` arrays come in multiples of 32 |
| `BYTE`, `WORD`, `DWORD`, `LWORD` | `Byte`, `Word`, `DWord`, `LWord` (S7-1500) | — | Logix has no bit-string types. Use `SINT`/`INT`/`DINT` with bit access (`MyDint.3`) |
| `SINT`, `USINT` | `SInt`, `USInt` | `SINT`; `USINT`, `UINT`, `UDINT`, `ULINT` only on 5380/5480/5580-family controllers | |
| `INT`, `UINT` | `Int`, `UInt` | `INT` (`UINT`: see above) | Siemens analog values arrive as `Int`, nominal 0–27 648 |
| `DINT`, `UDINT` | `DInt`, `UDInt` | **`DINT`**, the natural size | See A.2.3 |
| `LINT`, `ULINT` | `LInt`, `ULInt` (S7-1500) | `LINT` (time stamps; wider instruction support on newer firmware: check) | |
| `REAL` | `Real` | `REAL` | IEEE 754 single precision everywhere: about 7 significant digits |
| `LREAL` | `LReal` | 5380/5480/5580-family controllers only | |
| `TIME` | `Time` (32-bit milliseconds), `LTime` (S7-1500), `S5Time` (legacy) | Timers use `DINT` milliseconds. Newer versions add `TIME`, but in **microseconds** | See A.2.2 |
| `DATE`, `TIME_OF_DAY`, `DATE_AND_TIME` | `Date`, `Time_Of_Day`, `Date_And_Time` (not S7-1200), `DTL` | Wall clock read with `GSV` from the `WallClockTime` object. Newer versions add date-and-time types (check) | See A.2.2 |
| `STRING`, `WSTRING` | `String` (up to 254 characters), `WString`, `Char`, `WChar` | `STRING`: `.LEN` plus `.DATA`, 82 characters; you can define other string lengths | CODESYS `STRING` defaults to 80 characters; MATIEC allows 126 |
| `ARRAY[1..10] OF INT` | `Array[1..10] of Int`, any bounds | `INT[10]`: always zero-based, up to three dimensions | |
| `STRUCT` | PLC data type or `Struct` | UDT | |

### A.2.2 Time and date

**IEC and CODESYS.** `TIME` is a duration, written `T#5s` or `T#1m30s`. In CODESYS it is a 32-bit
millisecond count, and edition-3 tools add a 64-bit `LTIME`. `DATE`, `TIME_OF_DAY` (`TOD`)
and `DATE_AND_TIME` (`DT`) hold calendar values. MATIEC has no `LTIME`, and its
`TIME_TO_DINT` returns seconds where CODESYS returns milliseconds
([Appendix E](E-matiec-openplc-notes.md)).

**Siemens.**

| Type | Size | Content | Literal |
|---|---|---|---|
| `Time` | 32 bits, signed | Milliseconds, up to about ±24.8 days | `T#5S`, `T#1M30S` |
| `LTime` (S7-1500) | 64 bits | Nanoseconds | `LT#5S` |
| `S5Time` (legacy) | 16 bits | Three BCD digits (0–999) times a time base of 10 ms, 100 ms, 1 s or 10 s. Maximum 2 h 46 min 30 s | `S5T#5S` |
| `Date` | 16 bits | Days since 1 January 1990 | `D#2026-09-26` |
| `Time_Of_Day` | 32 bits | Milliseconds since midnight | `TOD#08:30:00` |
| `Date_And_Time` (S7-1500, S7-300/400) | 8 bytes | BCD-coded date and time | `DT#2026-09-26-08:30:00` |
| `DTL` (S7-1200 and S7-1500) | 12 bytes | Structure: `YEAR` (UInt), `MONTH`, `DAY`, `WEEKDAY` (1 = Sunday), `HOUR`, `MINUTE`, `SECOND` (USInt), `NANOSECOND` (UDInt) | `DTL#2026-09-26-08:30:00` |

`RD_SYS_T` (system time, UTC) and `RD_LOC_T` (local time) read the CPU clock into a `DTL`.
`S5Time` belongs to the legacy S5 timers of A.5. When you convert old code, watch for
`S5T#` presets: the value is BCD, and precision depends on the time base the CPU chose.

**Rockwell.** Logix timers keep their preset and accumulated value as `DINT` milliseconds, so
5 s is `5000`. The controller's wall clock is read with `GSV` from the `WallClockTime` object,
for example as seven `DINT`s (year, month, day, hour, minute, second, microsecond). Recent
versions of Logix Designer add IEC-style time and date types: `TIME32` (32 bits,
microseconds), `TIME` (64 bits, microseconds), `LTIME` (64 bits, nanoseconds), `DT`
(64 bits, microseconds) and `LDT` (64 bits, nanoseconds). Only a limited set of
instructions accepts them (moves, clears, adds, subtracts, compares, `GSV`/`SSV`), FBD does
not support them, and the timer instructions still use `DINT` milliseconds. So a Logix
`TIME` is neither the size nor the unit of a CODESYS or Siemens `TIME`. Check the help of
your version before using them.

### A.2.3 Rockwell's DINT-centric practice

Logix CPUs work natively in 32 bits. `SINT` and `INT` operands are converted to `DINT` for
arithmetic and converted back when stored, which costs time and can overflow when the
result is stored. Experienced Logix programmers therefore use `DINT` for every integer
(counts, states, indexes, setpoints), `REAL` for analog values, and `INT` only where a
device or message demands a 16-bit layout. Siemens and IEC programmers are used to choosing
the smallest type that fits. Both habits are sensible on their own platform, so don't
"optimise" a Logix program by shrinking its `DINT`s.

### A.2.4 Instruction data structures

Where IEC uses a function block instance, Logix uses a predefined structure (a tag of a
built-in type) and Siemens an instance DB or multi-instance.

| Purpose | IEC instance | Siemens | Rockwell ladder | Rockwell ST / FBD |
|---|---|---|---|---|
| Timer | `TON`, `TOF`, `TP` instance | `TON_TIME` etc. (`IEC_TIMER` in some versions and CPUs) | `TIMER`: `.PRE`, `.ACC`, `.EN`, `.TT`, `.DN` | `FBD_TIMER` (for `TONR`, `TOFR`, `RTOR`) |
| Counter | `CTU`, `CTD`, `CTUD` instance | `IEC_COUNTER` (Int) and typed variants for the other count types | `COUNTER`: `.PRE`, `.ACC`, `.CU`, `.CD`, `.DN`, `.OV`, `.UN` | `FBD_COUNTER` (for `CTUD`) |
| Edge detection | `R_TRIG`, `F_TRIG` instance | `R_TRIG`/`F_TRIG` instance, or an edge memory bit | A storage `BOOL` for `ONS`, `OSR`, `OSF` | `FBD_ONESHOT` (for `OSRI`, `OSFI`) |
| Shift registers, FIFOs, sequencers | — | — | `CONTROL`: `.LEN`, `.POS`, `.EN`, `.DN`, `.EM`, `.UL` and others | — |
| PID | Vendor or library FB instance | `PID_Compact` instance DB | `PID` | `PIDE` (the `PID` instruction is also available in ST) |
| Messaging | — | Instance of the communication instruction | `MESSAGE` (for `MSG`) | `MESSAGE` |

## A.3 Addressing styles

### A.3.1 I/O and memory

| Item | IEC / CODESYS / OpenPLC | Siemens S7-1200/1500 | Rockwell Logix | Legacy Allen-Bradley (SLC 500, MicroLogix, PLC-5) |
|---|---|---|---|---|
| Digital input bit | `%IX0.0` | `%I0.0` (German mnemonics: `%E0.0`) | Module tag, for example `Local:1:I.Data.0` (1756 digital) or `Local:1:I.Pt00.Data` (5069 Compact 5000 I/O), usually aliased | SLC `I:1/0` (slot 1, bit 0); PLC-5 `I:012/07` (rack 01, group 2, bit 07, octal) |
| Digital output bit | `%QX0.0` | `%Q0.0` (German: `%A0.0`) | For example `Local:2:O.Data.0` | SLC `O:2/0` |
| Analog input word | `%IW0` | `%IW64` (for example the S7-1200's on-board analog inputs); `%IW64:P` reads the module directly | Channel members, for example `Local:3:I.Ch0Data` (names vary by module family; often a scaled `REAL`) | SLC `I:3.0` (slot 3, word 0) |
| Internal bit | `%MX0.0` | `%M0.0` (bit memory, "Merker") | A `BOOL` tag: there are no memory areas | `B3:0/0` (also written `B3/0`) |
| Internal word, double word | `%MW0`, `%MD0` | `%MW10`, `%MD20` | `INT`, `DINT` or `REAL` tags | `N7:0` (integer file), `F8:0` (float file) |
| Structured data | A variable of a `STRUCT` type | `"Tank_DB".Level` (symbolic); `%DB1.DBX0.0`, `%DB1.DBW2`, `%DB1.DBD4` (absolute, standard-access blocks only) | `Tank.Level` (UDT tag) | Data files only |
| Timer status | `T1.Q`, `T1.ET` | `#T1.Q` or `"T1_DB".Q`; legacy S5 timer `T1` | `T1.DN`, `T1.ACC` | `T4:0/DN`, `T4:0.ACC` |
| Counter status | `C1.Q`, `C1.CV` | `#C1.QU`, `#C1.CV`; legacy S5 counter `C1` (German: `Z1`) | `C1.DN`, `C1.ACC` | `C5:0/DN`, `C5:0.ACC` |
| Bit of a word | `MyWord.3` (CODESYS; not MATIEC) | `#MyWord.%X3` | `MyDint.3` | `N7:0/3` |
| System status | — | System memory bits such as `FirstScan` | `S:FS`, `S:N`, `S:Z`, `S:V`, `S:C`, `S:MINOR` | Status file, for example `S:1/15` first pass (SLC) |

**IEC direct addresses** are `%`, an area (`I` input, `Q` output, `M` memory), a size (`X` bit,
`B` byte, `W` word, `D` double word, `L` long word) and numbers whose meaning is up to the
implementation. In OpenPLC they map to the Runtime's I/O and to its Modbus tables
([Module 17](../17-industrial-communications/)). CODESYS and TwinCAT projects usually map I/O
to named variables in the device configuration instead.

**Siemens** addresses are byte-based, and larger sizes overlap: `%MW10` is `%MB10` plus
`%MB11`, and `%MW11` is `%MB11` plus `%MB12`. Using `%MW10` and `%MW11` for different values
corrupts both. The byte order is **big-endian**: the lower-numbered byte is the high byte, so
`%M11.0` is bit 0 of `%MW10` and `%M10.0` is bit 8. Blocks with **optimised access** (the
default for new blocks) can only be addressed symbolically: `"Tank_DB".Level`, never
`DB1.DBD4`. Use standard access only when something outside the program needs fixed offsets,
for example some older HMIs or remote `PUT`/`GET` partners. A `:P` suffix (`%IW64:P`) reads
or writes the module directly instead of the process image.

**Rockwell** has no absolute memory. Everything is a tag. Adding a module to the I/O
configuration creates its module-defined tags, whose names depend on the module family.
Create an **alias tag** with a meaningful name (`StartPB` → `Local:1:I.Data.0`), or copy the
I/O into your own tags in a mapping routine. Logix updates I/O tags asynchronously to the
program scan, so an input can change between two rungs. Copying inputs once at the start
of the scan also removes that problem ([Module 11](../11-program-organization/)).

**Legacy Allen-Bradley** controllers use data files: `O0` outputs, `I1` inputs, `S2` status,
`B3` bits, `T4` timers, `C5` counters, `R6` control, `N7` integers and `F8` floats are the
defaults. Migrated Logix projects often contain tags or arrays named after these files.

### A.3.2 Modbus register notation

| Modbus table | Classic reference | Access | Read function | Write function |
|---|---|---|---|---|
| Coils | 00001–09999 ("0x") | Bit, read/write | 01 | 05 (single), 15 (multiple) |
| Discrete inputs | 10001–19999 ("1x") | Bit, read-only | 02 | — |
| Input registers | 30001–39999 ("3x") | 16-bit, read-only | 04 | — |
| Holding registers | 40001–49999 ("4x") | 16-bit, read/write | 03 | 06 (single), 16 (multiple) |

The classic reference is a documentation convention. The protocol carries a zero-based
address and the function code, so **reference 40001 is holding register 0**. Six-digit
references (400001) are used when a table has more than 9,999 entries. Device manuals mix
0-based and 1-based numbering, so always prove the mapping by reading one known register
before trusting the rest. A 32-bit value occupies two registers, and the word order varies
between devices ([Module 17](../17-industrial-communications/)).

In the OpenPLC Runtime, `%IX` maps to discrete inputs, `%QX` to coils, `%IW` to input
registers and `%QW` to holding registers from 0. Siemens `MB_CLIENT` takes a classic-style
reference (for example 40001) together with a mode parameter, and `MB_SERVER` maps holding
registers onto a data area you choose. Check the instruction help for the exact parameters.

## A.4 Bit logic

| Function | IEC LD (course notation) / ST | Siemens LAD / SCL | Rockwell LD / ST | Notes |
|---|---|---|---|---|
| NO contact | `--] [--` / `A` | `-\| \|-` / `#A` | `XIC(A)` / `A` | Rockwell: "examine if closed" |
| NC contact | `--]/[--` / `NOT A` | `-\|/\|-` / `NOT #A` | `XIO(A)` / `NOT A` | "Examine if open" |
| Invert power flow | — | `-\|NOT\|-` | — | |
| Output coil | `--( )--` / `Q := ...;` | `-( )-` | `OTE(Q)` | One coil per bit ([Module 04](../04-ladder-logic/)) |
| Negated coil | `--(/)--` | `-(/)-` | — | |
| Set (latch) | `--(S)--` | `-(S)-`; `SET_BF` for a range of bits | `OTL(Q)` | |
| Reset (unlatch) | `--(R)--` | `-(R)-`; `RESET_BF` for a range | `OTU(Q)` | |
| Bistable FB | `SR` (set-dominant), `RS` (reset-dominant) | `SR` (**reset**-dominant), `RS` (**set**-dominant) | Ladder: none, use `OTL`/`OTU`. FBD/ST: `SETD`, `RESD` | The input whose name ends in 1 wins |
| Rising-edge contact | `--]P[--` | `-\|P\|-` with an edge memory bit | `XIC(A)ONS(A_ONS)`: the `ONS` follows the condition | [Module 06](../06-edges-and-one-shots/) |
| Falling-edge contact | `--]N[--` | `-\|N\|-` with an edge memory bit | — (use `OSF` on the rung) | |
| Pulse on the rising rung condition | `--(P)--` coil | `-(P)-` coil; `P_TRIG` box | `OSR(Storage,Output)` | |
| Pulse on the falling rung condition | `--(N)--` coil | `-(N)-` coil; `N_TRIG` box | `OSF(Storage,Output)` | |
| Edge FB (ST, FBD) | `R_TRIG`, `F_TRIG` | `R_TRIG`, `F_TRIG` (instance required) | `OSRI`, `OSFI` (`FBD_ONESHOT` tag) | |
| First scan | — | `FirstScan` system memory bit; startup OB100 | `S:FS` | See A.11 |

Notes:

- **Edge memory must be unique and static.** Each Siemens `-|P|-`, `P_TRIG` or `-(P)-` needs
  its own memory bit that nothing else writes, in M memory or in the *Static* area of an FB.
  A *Temp* variable does not survive between cycles and silently breaks the detector. Each
  Rockwell `ONS`/`OSR`/`OSF` needs its own storage bit. Name it after the signal
  (`StartPB_ONS`) so that copy-and-paste mistakes stand out.
- **Power-up.** Logix tags are retentive. On the change to Run the *prescan* clears bits written
  by `OTE`, but bits written by `OTL`/`OTU` keep their state, so a latched run command can
  survive a power cycle. On Siemens CPUs, whether an `-(S)-` bit survives depends on the
  retentive setting of its memory area or DB. In both cases, decide explicitly what must
  happen at power-up ([Module 04](../04-ladder-logic/)).

## A.5 Timers

| Function | IEC / CODESYS / OpenPLC | Siemens S7-1200/1500 | Rockwell ladder | Rockwell ST / FBD |
|---|---|---|---|---|
| On-delay | `TON` (`IN`, `PT` → `Q`, `ET`) | `TON` box or `-(TON)-` coil; SCL `#T(IN := x, PT := T#5S);` | `TON` on a `TIMER` tag | `TONR` on an `FBD_TIMER` tag |
| Off-delay | `TOF` | `TOF` | `TOF` | `TOFR` |
| Pulse | `TP` | `TP` | — (build one from a `TON`) | — |
| Retentive on-delay | None in the CODESYS Standard library or MATIEC: build one ([Module 07](../07-timers/)) | `TONR` (`IN`, `R`, `PT` → `Q`, `ET`) | `RTO`, cleared by `RES` | `RTOR` |
| Reset | Call with `IN := FALSE` | `-(RT)-` (reset timer); the `R` input of `TONR` | `RES` | `.Reset` member |
| Change the preset | Write `PT` | Write `PT`; `-(PT)-` (load time duration) | Write `.PRE` (for example with `MOV`) | Write `.PRE` |
| Done | `Q` | `Q` | `.DN` | `.DN` |
| Elapsed time | `ET` (`TIME`) | `ET` (`Time`) | `.ACC` (`DINT`, ms) | `.ACC` |
| Timing / enabled | — | — | `.TT` / `.EN` | `.TT` / `.EN` |
| Time unit | `TIME` | `Time` (ms); `LTime` (ns) timers on S7-1500 | `DINT` milliseconds | `DINT` milliseconds |
| Legacy | — | S5 timers `S_PULSE`, `S_PEXT`, `S_ODT`, `S_ODTS`, `S_OFFDT` with `S5TIME` presets (S7-300/400, and S7-1500 for migrated code) | SLC 500 / PLC-5 timers `T4:n` with a selectable time base | — |

Notes:

- **Same behaviour, different packaging.** A Rockwell `TON.DN` is the IEC `TON.Q`, and a
  `TOF.DN` is the IEC `TOF.Q`. `.ACC` stops at `.PRE` as `ET` stops at `PT`. The extra
  status bits are handy: `.TT` ("timing") is `IN AND NOT Q` without writing it yourself.
- **Instances.** Every IEC timer needs its own instance. In TIA Portal that means a
  single-instance DB (TIA offers to create one, named like `IEC_Timer_0_DB`) or a
  multi-instance in an FB's *Static* section, which keeps a device's data together
  ([Module 11](../11-program-organization/)). In Logix, every timer needs its own `TIMER` or
  `FBD_TIMER` tag. Sharing one between two jobs is the timer equivalent of a double coil.
- **Call every scan.** A timer inside a skipped `IF`, a jumped-over rung or a routine that is
  not called is frozen, not reset. That is true everywhere ([Module 07](../07-timers/)).
- **Logix ST call style.** In Logix ST you set the members, then call the instruction with the
  tag as its only operand: `T1.TimerEnable := x; T1.PRE := 5000; TONR(T1);`. There are no
  named parameters.

## A.6 Counters

| Function | IEC / CODESYS / OpenPLC | Siemens S7-1200/1500 | Rockwell ladder | Rockwell ST / FBD |
|---|---|---|---|---|
| Count up | `CTU` (`CU`, `R`, `PV` → `Q`, `CV`) | `CTU`, same pins | `CTU` on a `COUNTER` tag | `CTUD` with `.CUEnable` |
| Count down | `CTD` (`CD`, `LD`, `PV` → `Q`, `CV`) | `CTD` | `CTD` on a `COUNTER` tag | `CTUD` with `.CDEnable` |
| Up/down | `CTUD` (→ `QU`, `QD`, `CV`) | `CTUD` | `CTU` and `CTD` on the same tag | `CTUD` (`FBD_COUNTER`) |
| Reset | `R` input (CODESYS: `RESET`) | `R` input | `RES` instruction | `.Reset` member |
| Preset / count | `PV`, `CV` | `PV`, `CV` | `.PRE`, `.ACC` (`DINT`) | `.PRE`, `.ACC` |
| Done | `Q` (`CTU`: `CV >= PV`; `CTD`: `CV <= 0`) | Same as IEC | `.DN` = `.ACC >= .PRE`, **for `CTD` too** | `.DN` |
| Over/underflow | Implementation-dependent | Stops at the limits of the chosen type | `.OV`, `.UN`: the count wraps at the `DINT` limits | `.OV`, `.UN` |
| Count type | `INT`; typed variants such as `CTU_DINT` | Chosen on the box, `SInt` to `DInt` and unsigned types (`LInt` on S7-1500) | `DINT` | `DINT` |
| Legacy | — | S5 counters `S_CU`, `S_CD`, `S_CUD`, 0–999, BCD output (not S7-1200) | SLC `C5:n`, 16-bit | — |

The main traps, detailed in [Module 08](../08-counters/), are the Rockwell `CTD` done bit in
the table above and these two:

- Rockwell `RES` also clears the `.CU`/`.CD` edge memory. If the count rung is still true when
  the reset rung goes false, the counter sees a new edge and counts once, so the count
  restarts at 1.
- CODESYS Standard library counters use `RESET` and `LOAD` as input names and `WORD` for `PV`
  and `CV`. MATIEC counters stop at `PV` and at 0.

## A.7 Maths, comparison, move, conversion and scaling

### A.7.1 Rockwell mnemonics renamed in Logix Designer v36

| Legacy mnemonic | From v36 | What it does |
|---|---|---|
| `EQU`, `NEQ` | `EQ`, `NE` | Equal, not equal |
| `LES`, `LEQ` | `LT`, `LE` | Less than, less than or equal |
| `GRT`, `GEQ` | `GT`, `GE` | Greater than, greater than or equal |
| `LIM` | `LIMIT` | Range **test** (not a clamp) |
| `MOV` | `MOVE` | Move |
| `SQR` | `SQRT` | Square root |
| `XPY` | `EXPT` | X to the power of Y |
| `TRN` | `TRUNC` | Truncate |
| `TOD` | `TO_BCD` | Convert to BCD |
| `FRD` | `BCD_TO` | Convert from BCD to integer |
| `ACS`, `ASN`, `ATN` | `ACOS`, `ASIN`, `ATAN` | Arc cosine, arc sine, arc tangent |

That is the list in the Logix Designer help page *Updated instruction mnemonics* at the time
of writing; check that page for your version. Rockwell's documentation also says that code
using the new mnemonics cannot simply be converted or imported into older versions, so agree
on a version before sharing exported code.

### A.7.2 Arithmetic

| Operation | IEC / CODESYS / OpenPLC | Siemens | Rockwell | Notes |
|---|---|---|---|---|
| Add, subtract, multiply, divide | `ADD`, `SUB`, `MUL`, `DIV`; ST `+ - * /` | `ADD`, `SUB`, `MUL`, `DIV` boxes; SCL operators | `ADD`, `SUB`, `MUL`, `DIV`; ST operators | Siemens boxes can take extra inputs |
| Remainder | `MOD` | `MOD` | `MOD` | Check the sign rule for negative values |
| Whole expression | ST | `CALCULATE` (LAD/FBD) | `CPT` (ladder) | |
| Square root | `SQRT` | `SQRT` (`SQR` **squares**) | `SQR`/`SQRT` (square root) | A classic false friend |
| Power | `EXPT`, `**` | `EXPT`; `**` in SCL | `XPY`/`EXPT`; `**` in ST | |
| Negate, absolute value | Unary `-`, `ABS` | `NEG`, `ABS` | `NEG`, `ABS` | |
| Increment, decrement | `x := x + 1` | `INC`, `DEC` | `ADD` | |
| Minimum, maximum, clamp | `MIN`, `MAX`, `LIMIT` | `MIN`, `MAX`, `LIMIT` | Clamp with `HLL` (FBD/ST) or two comparisons | Rockwell `LIM`/`LIMIT` is a test |

### A.7.3 Comparison

| Operation | IEC / CODESYS / OpenPLC | Siemens | Rockwell | Notes |
|---|---|---|---|---|
| =, <>, <, <=, >, >= | ST operators; functions `EQ`, `NE`, `LT`, `LE`, `GT`, `GE` | `CMP ==`, `CMP <>` … contacts; SCL operators | `EQU`/`EQ`, `NEQ`/`NE`, `LES`/`LT`, `LEQ`/`LE`, `GRT`/`GT`, `GEQ`/`GE` | Rockwell compares are input instructions on the rung |
| Inside a band | `(x >= lo) AND (x <= hi)` | `IN_RANGE`, `OUT_RANGE` | `LIM`/`LIMIT` | With Low > High, Rockwell tests the *outside* of the band |
| Expression | ST | — | `CMP` | |
| Masked equal | `(a AND m) = (b AND m)` | Same, with `AND` boxes | `MEQ` | |
| Valid floating-point number | — | `OK`, `NOT_OK` | — | Catches NaN and infinity |

### A.7.4 Move and copy

| Operation | IEC / CODESYS / OpenPLC | Siemens | Rockwell | Notes |
|---|---|---|---|---|
| Copy one value | `:=`, `MOVE` | `MOVE` (one input, several outputs) | `MOV`/`MOVE` | |
| Copy part of an array | `FOR` loop; whole-array assignment between arrays of the same type | `MOVE_BLK`, `UMOVE_BLK` (not interrupted); SCL array assignment | `COP` (length counted in destination elements); `CPS` (not interrupted by I/O or comms updates) | `COP` copies bytes, so it can reinterpret one type as another |
| Fill | `FOR` loop | `FILL_BLK`, `UFILL_BLK` | `FLL` | |
| Clear | `:= 0` | `MOVE` 0 | `CLR` | |
| Masked move | `(a AND NOT m) OR (b AND m)` | Same, with word logic | `MVM` | |
| Swap bytes | — | `SWAP` | `SWPB` | Needed for some Modbus devices |

### A.7.5 Conversion and scaling

| Operation | IEC / CODESYS / OpenPLC | Siemens | Rockwell | Notes |
|---|---|---|---|---|
| Numeric conversion | Typed: `INT_TO_REAL`, `REAL_TO_INT` (rounds), `TRUNC` | `CONV` (LAD/FBD), `ROUND`, `TRUNC`, `CEIL`, `FLOOR`; SCL typed conversions and many implicit ones | Implicit in `MOV` and assignments: REAL to integer **rounds**; `TRN`/`TRUNC` truncates | See the false friends in A.14 |
| BCD | Library functions (MATIEC: `UINT_TO_BCD_WORD`, `WORD_BCD_TO_UINT`) | `CONV` with the BCD16/BCD32 types | `TOD`/`TO_BCD` and `FRD`/`BCD_TO` | Thumbwheels, 7-segment displays |
| Degrees, radians | Multiply by π/180 | Multiply | `DEG`, `RAD` | |
| Scale raw counts to engineering units | Your own function ([Module 14](../14-analog-and-process-io/)); CODESYS Util `LIN_TRAFO` | `NORM_X` then `SCALE_X`; S7-300/400 `SCALE` (FC105) and `UNSCALE` (FC106) | `SCP` (ladder), `SCL` (FBD/ST), or scaling in the module properties | |

**Scaling formulas.** Rockwell `SCP` does the whole job in one box:
Out = (In − InMin) × (ScaledMax − ScaledMin) / (InMax − InMin) + ScaledMin.
Siemens splits it in two: `NORM_X` gives (Value − Min) / (Max − Min), a `Real` between 0.0 and
1.0, and `SCALE_X` gives Value × (Max − Min) + Min. For a 0–10 bar transmitter on a Siemens
input with the nominal range 0–27 648, a raw value of 13 824 gives `NORM_X` = 0.5 and then
`SCALE_X` = 5.0 bar. For an analog **output**, reverse the order: `NORM_X` on the engineering
value, then `SCALE_X` to 0–27 648. Check what each instruction does when the input lies
outside its range, and add your own range and wire-break checks
([Module 14](../14-analog-and-process-io/)).

## A.8 Program flow

| Function | IEC / CODESYS / OpenPLC | Siemens | Rockwell | Notes |
|---|---|---|---|---|
| Jump within a POU | Jumps and labels in LD and FBD; none in IEC ST | LAD/FBD `JMP`, `JMPN`, `LABEL`, `JMP_LIST`, `SWITCH`; SCL `GOTO` | `JMP`/`LBL` (ladder) | Timers and edges on skipped rungs freeze |
| Call a reusable unit | Call a `FUNCTION` or an FB instance | Call an FC, or an FB with its instance DB or multi-instance | `JSR` → `SBR` … `RET` (optional parameters); call an AOI | |
| Leave early | `RETURN` | `RET` (LAD/FBD), `RETURN` (SCL) | `RET` from a subroutine; `TND` (temporary end, for testing) | |
| Run a block conditionally | `IF`; `EN` input in LD/FBD | `EN` input of the box; `IF` in SCL | Rung condition; `IF` in ST | Siemens outputs are not written when `EN` is FALSE (A.14) |
| Master control zone | — | MCR instructions documented for S7-300/400; on S7-1200/1500 check the help | `MCR` pairs | Not an emergency stop. Most coding standards avoid MCR zones |
| Loops | `FOR`, `WHILE`, `REPEAT`, `EXIT` | SCL `FOR … TO … BY … DO`, `WHILE`, `REPEAT`, `EXIT`, `CONTINUE` | ST `FOR`, `WHILE`, `REPEAT`, `EXIT`; ladder `FOR`/`BRK` runs a routine repeatedly | Every iteration adds scan time. Watch the watchdog |
| Multi-way branch | `CASE` | SCL `CASE`; LAD `SWITCH`, `JMP_LIST` | ST `CASE` | States are integers in Siemens and Logix: no enumerations |
| Disable a rung while testing | Comment it out | Comment it out, or skip it with a jump | `AFI` (always false) at the start of the rung | Remove before handover |
| Hold off interrupts | — | `DIS_AIRT` / `EN_AIRT` | `UID` / `UIE` | For short sections that must not be interrupted |

**Subroutine parameters.** A Logix `JSR` can pass input parameters that the called routine's
`SBR` receives, and the routine's `RET` can pass values back. It works, but the parameters are
positional and unnamed, so an AOI or a program with program parameters is easier to read and
test. In Siemens terms, a parameterised `JSR` is closest to calling an FC, and an AOI to
calling an FB.

## A.9 Bit and word operations, shift registers and FIFOs

| Function | IEC / CODESYS / OpenPLC | Siemens | Rockwell | Notes |
|---|---|---|---|---|
| Bitwise AND, OR, XOR, NOT | On bit strings (`WORD` etc.); CODESYS also on integers | `AND`, `OR`, `XOR`, `INV`; SCL operators | `AND`, `OR`, `XOR`, `NOT` on integers | MATIEC: bit strings only, no arithmetic on `WORD` |
| Shift a word | `SHL`, `SHR` | `SHL`, `SHR` | No word-shift instruction (check your version); `MUL`/`DIV` by powers of two for unsigned-style values | Division of negative numbers does not behave like a shift |
| Rotate a word | `ROL`, `ROR` | `ROL`, `ROR` | No rotate instruction (check your version): build it from shifts and masks | |
| Bit shift register (one bit per part, for tracking) | Build it with `SHL` or a `BOOL` array | Build it with `SHL` on a word or an array loop; the LGF library has `LGF_ShiftRegister` | `BSL`, `BSR` on a `DINT` array with a `CONTROL` tag (`.LEN` in bits; `.UL` holds the bit shifted out) | [Module 12](../12-data-structures/) |
| FIFO queue | Build it: array plus indexes | No FIFO in the basic instruction set; the Siemens LGF library has one (`LGF_FIFO`) | `FFL` (load), `FFU` (unload) with a `CONTROL` tag (`.DN` full, `.EM` empty) | |
| LIFO stack | Build it | Build it, or `LGF_LIFO` from the LGF library | `LFL`, `LFU` | |
| Sequencer tables | Build it (`CASE`, arrays) | Build it | `SQO`, `SQI`, `SQL` | |
| Bit-field distribute | Shifts and masks | Slice access and shifts | `BTD` | |
| Array search and arithmetic | `FOR` loops | `FOR` loops | `FSC` (search and compare), `FAL` (arithmetic and logic) | |
| Single bit of a word | `MyWord.3` (CODESYS; not MATIEC) | `#MyWord.%X3`; also `%B` and `%W` slices | `MyDint.3` | |

The Logix bit-shift (`BSL`, `BSR`), FIFO, LIFO and sequencer instructions are ladder-only.
From ST, write the loop yourself or call a ladder routine. In TIA Portal you normally build
these from arrays and loops in SCL, or use the Library of General Functions (LGF), which
Siemens provides for S7-1200/1500 through its online support site. It includes a FIFO, a
LIFO and a shift register.

## A.10 PID control

| Item | IEC / CODESYS / OpenPLC | Siemens S7-1200/1500 | Rockwell `PID` | Rockwell `PIDE` |
|---|---|---|---|---|
| Block | No standard PID. CODESYS Util: `PID`, `PID_FIXCYCLE`. OpenPLC/MATIEC: `PID` | `PID_Compact` (continuous output), `PID_3Step` (motorised valve), `PID_Temp` (heat/cool); S7-300/400 `CONT_C`, `CONT_S` | `PID` instruction (ladder, ST) on a `PID` tag | `PIDE` (FBD, ST) |
| Where to run it | A task with a fixed interval | A cyclic interrupt OB (for example OB30) | A periodic task; the loop update time must match the real interval | A periodic task |
| Gain | CODESYS `KP`; OpenPLC `KP` | `Gain` | Kp (independent) or Kc (dependent) | Proportional gain or Kc |
| Integral setting | CODESYS `TN` (s); OpenPLC `TR` | `Ti` (s) | Ki in **1/s** (independent) or Ti in **minutes per repeat** (dependent) | Integral gain in **1/min** (independent) or Ti in minutes per repeat |
| Derivative setting | CODESYS `TV` (s); OpenPLC `TD` | `Td` (s) | Kd in s or Td in minutes | Derivative gain in minutes or Td in minutes |
| Algorithm form | Read the source or help | See the help | Positional | Velocity |
| Direction of action | CODESYS: error = SP − PV. OpenPLC: error = PV − SP | Positive gain only; set `Config.InvertControl` to reverse | Control-action setting in the instruction configuration | Control-action setting |
| Output limits, anti-windup | CODESYS: `Y_MIN`, `Y_MAX`. OpenPLC: none | Built in | Built in (check the options) | Built in, plus cascade, ratio and mode handling |
| Tuning aids | — | Pretuning and fine tuning in the commissioning editor | Check the manual | Autotune (check your version and licence) |

> **Caution: parameters do not transfer.** Every PID block has its own equation form
> (independent/parallel or dependent/ISA), its own time units (seconds, minutes, repeats per
> minute or minutes per repeat), its own sign convention, its own scaling of PV and output,
> and its own behaviour when switching between manual and auto. Even Rockwell's two blocks
> differ: `PID` takes Ki per second, `PIDE` per minute. Copying "Kp 2, Ti 30" from a loop
> sheet or from another controller without converting can give integral action 60 times
> too strong or too weak, and a wrong action setting drives the process away from setpoint
> instead of towards it. Convert deliberately, write the units next to every tuning value,
> and retest with the plant in a safe state. [Module 15](../15-pid-control/)
> has the details for each platform.

## A.11 System and diagnostics

| Need | IEC / CODESYS / OpenPLC | Siemens S7-1200/1500 | Rockwell Logix | Notes |
|---|---|---|---|---|
| First scan | Not in the standard. Roll your own (a `BOOL` initialised TRUE and cleared at the end of the scan). TwinCAT: `_TaskInfo[GETCURTASKINDEXEX()].FirstCycle` | `FirstScan` bit of the system memory byte (`%M1.0` when the byte is at MB1), TRUE in the first cycle after the startup OBs; startup OB100 | `S:FS`; optional power-up handler | Micro800: `_SYSVA_FIRST_SCAN` (check the spelling: A.1.4) |
| Always TRUE / FALSE bits | Literals | `AlwaysTRUE`, `AlwaysFALSE` system memory bits | — | |
| Clock pulses | Build with timers | Clock memory byte: bits from 10 Hz down to 0.5 Hz | Build with timers | Clock bits are not synchronised to your logic |
| Date and time | CODESYS system libraries (check your runtime) | `RD_SYS_T` (UTC), `RD_LOC_T` (local) into `DTL` | `GSV` from `WallClockTime` | |
| Read or write controller data | Runtime-specific | Dedicated instructions: `RUNTIME`, `GET_DIAG`, `DeviceStates`, `ModuleStates`, `LED` and others | `GSV` and `SSV` with an object class and attribute | Logix: one pair of instructions for many objects |
| Scan-time measurement | CODESYS task monitor | Online & diagnostics shows the cycle time; `RUNTIME` measures code sections | `GSV` from the `Task` object: `LastScanTime`, `MaxScanTime` | [Module 23](../23-commissioning-and-troubleshooting/) |
| Scan-time limit | Task watchdog | Maximum cycle time in the CPU properties; OB80 time-error OB; `RE_TRIGR` restarts the monitoring | Watchdog time per task; expiry is a major fault | |
| Programming error at run time | Exceptions; implicit checks in CODESYS | S7-1500: OB121. S7-1200: no error OB; the CPU logs the error in the diagnostic buffer and stays in RUN (check your firmware). Both: local handling with `GET_ERROR` / `GET_ERR_ID` | Major fault: the program's fault routine, then the controller fault handler | For example an array index out of range |
| I/O and module faults | Device diagnosis in the device tree | OB82 (diagnostic interrupt), OB83 (pull/plug), OB86 (rack or station failure); `DeviceStates`, `ModuleStates` | Module status; `GSV` from the `Module` object; a lost connection can be set to cause a major fault | Treat missing I/O as a fault, not as FALSE |
| Arithmetic status | — | `ENO` of the box | `S:V` (overflow, also a minor fault), `S:Z`, `S:N`, `S:C` | |
| Fault history | Log | Diagnostic buffer | Major and minor fault logs; `S:MINOR` | |

What happens when an error OB is missing, or a fault routine does not clear the fault,
depends on the CPU family, the error and the version: the CPU may stop, or it may log the
error and carry on. Find out for your controller before commissioning, not during a trip.

## A.12 Communications

| Need | IEC / CODESYS / OpenPLC | Siemens S7-1200/1500 | Rockwell Logix | Notes |
|---|---|---|---|---|
| Native I/O network | CODESYS: whatever is configured in the device tree. TwinCAT: EtherCAT | PROFINET | EtherNet/IP | Other networks through gateways or modules |
| Read or write another controller on demand | Library blocks (check your platform) | `GET`, `PUT` (S7 communication; must be permitted in the partner CPU's protection settings) | `MSG` (CIP Data Table Read/Write; CIP Generic for other objects) | Triggered by your logic: handle done, error and timeout |
| Cyclic data between controllers | Network variables or fieldbus configuration (check) | **PROFINET I-device**: a CPU acts as an IO device of another controller, with configured transfer areas | **Produced and consumed tags**, at a requested packet interval (RPI) | Configured, not programmed; monitor the connection status |
| Open TCP or UDP | Socket libraries (check) | `TSEND_C` / `TRCV_C` (connection built in); `TCON`, `TSEND`, `TRCV`, `TDISCON` | Socket interface, driven by `MSG` instructions (check your controller or module) | For devices with their own protocol |
| Modbus TCP client | CODESYS Modbus TCP device; OpenPLC slave devices | `MB_CLIENT` | Not built in: gateway, module, or Rockwell's Modbus TCP sample AOIs (which use the socket interface). Micro800: `MSG_MODBUS` family | |
| Modbus TCP server | CODESYS Modbus TCP server device; the OpenPLC Runtime is a server | `MB_SERVER` | As above | |
| Modbus RTU | CODESYS serial Modbus devices | `Modbus_Comm_Load` with `Modbus_Master` or `Modbus_Slave` on a serial module (names vary by module and version) | Gateway or module; Micro800 serial ports | |
| OPC UA | CODESYS: symbol configuration and OPC UA server | OPC UA server on S7-1500, and on S7-1200 with recent firmware; enabled and scoped in the project (check licensing) | Recent controllers and versions (check) | Protect it: [Module 17](../17-industrial-communications/), IEC 62443 |

Notes:

- **Both ends matter.** A `GET`/`PUT` or `MSG` that "does nothing" is usually refused by the
  partner: access not permitted, a wrong slot or path, an optimised DB where standard access
  is needed, or a tag that is not visible externally.
- **Byte order.** Siemens is big-endian and Logix is little-endian. Moving 32-bit values
  between them, or through 16-bit Modbus registers, needs an agreed word and byte order
  (`SWAP`, `SWPB`, or `COP` into the right type). Test with a value such as 123 456.789 whose
  bytes are all different.
- **Asynchronous data.** Produced/consumed tags and I/O arrive in Logix asynchronously to the
  scan. Use `CPS` to copy a structure that must stay consistent. On Siemens, data shared
  between organisation blocks of different priority can be copied with `UMOVE_BLK`, which a
  higher-priority OB cannot interrupt.

## A.13 Translating a lab between tools: Lab 07-1

> **Spoiler.** This section contains the logic of the
> [Lab 07-1](../07-timers/README.md#lab-07-1-star-delta-starter) reference solution. Do the
> lab first.

Lab 07-1 is a star-delta starter. Start runs the main and star contactors; after the star time
the star contactor opens; 100 ms later the delta contactor closes. Stop or the overload relay
stops everything. The lab's I/O:

| Tag | OpenPLC / IEC | Siemens tag table | Rockwell alias for (example: 1756 digital modules in slots 1 and 2) |
|---|---|---|---|
| `StartPB` | `%IX0.0` | `%I0.0` | `Local:1:I.Data.0` |
| `StopPB_NC` | `%IX0.1` | `%I0.1` | `Local:1:I.Data.1` |
| `OverloadOK_NC` | `%IX0.2` | `%I0.2` | `Local:1:I.Data.2` |
| `MainK` | `%QX0.0` | `%Q0.0` | `Local:2:O.Data.0` |
| `StarK` | `%QX0.1` | `%Q0.1` | `Local:2:O.Data.1` |
| `DeltaK` | `%QX0.2` | `%Q0.2` | `Local:2:O.Data.2` |

### IEC ST (OpenPLC, CODESYS, TwinCAT)

The body of `PROGRAM StarDelta`. The declarations (`StarTimer`, `GapTimer : TON`,
`StarTime : TIME := T#5s`) and the configuration are in the reference solution,
[`07-1-star-delta.st`](../07-timers/labs/solutions/07-1-star-delta.st), which passes the
lab's tests:

```iecst
MainK := (StartPB OR MainK) AND StopPB_NC AND OverloadOK_NC;

StarTimer(IN := MainK, PT := StarTime);
StarK := MainK AND NOT StarTimer.Q;

GapTimer(IN := StarTimer.Q, PT := T#100ms);

DeltaK := MainK AND GapTimer.Q AND NOT StarK;
```

In CODESYS or TwinCAT the same text goes into a *Program* POU unchanged. Only the task and the
I/O mapping move into the tool's configuration: the *Task Configuration* replaces the
`CONFIGURATION` section, and in TwinCAT you would declare the I/O as `AT %I*` / `AT %Q*` and
link it to the terminals.

### Siemens TIA Portal: SCL function block

Create an FB, `FB_StarDelta`, with this interface (edited in the table above the code):

| Section | Name | Data type | Start value | Comment |
|---|---|---|---|---|
| Input | `StartPB` | `Bool` | | Start push-button, NO |
| Input | `StopPB_NC` | `Bool` | | Stop push-button, NC |
| Input | `OverloadOK_NC` | `Bool` | | Overload relay contact, NC |
| Input | `StarTime` | `Time` | `T#5S` | Star period |
| Output | `MainK` | `Bool` | | Main contactor |
| Output | `StarK` | `Bool` | | Star contactor |
| Output | `DeltaK` | `Bool` | | Delta contactor |
| Static | `StarTimer` | `TON_TIME` | | Multi-instance: star period |
| Static | `GapTimer` | `TON_TIME` | | Multi-instance: changeover gap |

Depending on the CPU and TIA Portal version, the editor may offer `IEC_TIMER` for a
multi-instance timer instead of `TON_TIME` (the S7-1200 manual shows `IEC_TIMER`). Use the
type it offers when you drop a `TON` into the FB and choose *Multi instance*.

The FB body:

```iecst
// Siemens SCL (TIA Portal) - not MATIEC syntax
// 1. Run latch. An FB output lives in the instance DB, so it can be read back.
#MainK := (#StartPB OR #MainK) AND #StopPB_NC AND #OverloadOK_NC;

// 2. Star period: multi-instance timer, called on every cycle
#StarTimer(IN := #MainK,
           PT := #StarTime);
#StarK := #MainK AND NOT #StarTimer.Q;

// 3. Changeover gap
#GapTimer(IN := #StarTimer.Q,
          PT := T#100MS);

// 4. Delta, with a software interlock against star
#DeltaK := #MainK AND #GapTimer.Q AND NOT #StarK;
```

Call it from OB1 (here in SCL; in LAD you drag the FB into a network). TIA Portal offers to
create the instance DB, here `StarDelta_DB`:

```iecst
// Siemens SCL, in OB1 (Main) - not MATIEC syntax
"StarDelta_DB"(StartPB       := "StartPB",
               StopPB_NC     := "StopPB_NC",
               OverloadOK_NC := "OverloadOK_NC",
               StarTime      := T#5S,
               MainK         => "MainK",
               StarK         => "StarK",
               DeltaK        => "DeltaK");
```

### Rockwell Studio 5000: Structured Text routine

Tags: the six I/O aliases above (controller scope), plus program-scoped `StarTimer` and
`GapTimer` of type `FBD_TIMER` and `StarTime_ms` of type `DINT` with the value 5000. A Logix
routine has no declaration section.

```iecst
// Rockwell Logix ST (Studio 5000) - not MATIEC syntax
// 1. Run latch. [:=] is the non-retentive assignment: MainK is also cleared
//    when the controller enters Run, as an OTE is in ladder (see point 4 below).
MainK [:=] (StartPB OR MainK) AND StopPB_NC AND OverloadOK_NC;

// 2. Star period: set the members, then call the instruction
StarTimer.PRE := StarTime_ms;            // DINT, milliseconds
StarTimer.TimerEnable := MainK;
TONR(StarTimer);
StarK := MainK AND NOT StarTimer.DN;

// 3. Changeover gap
GapTimer.PRE := 100;                     // 100 ms
GapTimer.TimerEnable := StarTimer.DN;
TONR(GapTimer);

// 4. Delta, with a software interlock against star
DeltaK := MainK AND GapTimer.DN AND NOT StarK;
```

### Rockwell Studio 5000: ladder, as rung text

Here `StarTimer` and `GapTimer` are `TIMER` tags. In a `TON` the three operands are the timer
tag, the preset and the accumulated value.

```text
MOV(StarTime_ms,StarTimer.PRE);
[XIC(StartPB) ,XIC(MainK) ]XIC(StopPB_NC)XIC(OverloadOK_NC)OTE(MainK);
XIC(MainK)TON(StarTimer,5000,0);
XIC(MainK)XIO(StarTimer.DN)OTE(StarK);
XIC(StarTimer.DN)TON(GapTimer,100,0);
XIC(MainK)XIC(GapTimer.DN)XIO(StarK)OTE(DeltaK);
```

The first rung copies an HMI-adjustable star time into the preset on every scan. Leave it out
for a fixed 5 s. (From v36 the instruction is called `MOVE`.) The second rung is the seal-in
from [Module 00](../00-start-here/) with the overload contact added: the branch
`[ … , … ]` is the OR, and contacts in series are the AND.

### What changed, and what did not

| Aspect | IEC ST | Siemens SCL | Rockwell ST | Rockwell ladder |
|---|---|---|---|---|
| Where the code lives | `PROGRAM` POU | FB called from OB1 | Routine in a program, in a task | Routine in a program, in a task |
| I/O | `AT %IX0.0` declarations | Tag table (`%I0.0`), symbolic names | Alias tags for module tags | Alias tags for module tags |
| Timer data | `TON` instance | `TON_TIME` multi-instance | `FBD_TIMER` tag | `TIMER` tag |
| Timer call | `StarTimer(IN := …, PT := …)` | `#StarTimer(IN := …, PT := …)` | Set members, then `TONR(StarTimer)` | `TON` instruction on the rung |
| Preset | `T#5s` (`TIME`) | `T#5S` (`Time`) | `5000` (`DINT`, ms) | `5000` |
| Done bit | `.Q` | `.Q` | `.DN` | `.DN` |
| Names | Plain | `#Local`, `"Global"` | Plain | Plain |
| Scheduling | `TASK MainTask (INTERVAL := T#10ms)` | OB1 (program cycle), or a cyclic OB | Continuous or periodic task | Continuous or periodic task |

The logic itself (a seal-in, two on-delays and an interlock) did not change at all. That is
the point of learning it in IEC terms. What you must check every time you port something:

1. **Time units.** Every `TIME` preset becomes milliseconds in Logix. Every `S5TIME` in old
   Siemens code needs converting.
2. **One instance per timer, called every scan.** The same in all four versions.
3. **Asynchronous I/O in Logix.** Here it does no harm, but a routine that reads the same
   input several times, or edge-detects it, should copy inputs to internal tags first.
4. **Power-up.** In IEC tools and on Siemens CPUs, a variable that is not marked retentive
   starts FALSE after a power cycle, so the seal-in drops out. Logix tags keep their values.
   In ladder the prescan clears bits written by `OTE`, which drops the seal-in, but in
   Logix ST an ordinary `:=` assignment keeps its last value. That is why the ST version
   uses the non-retentive assignment `[:=]` for `MainK`. Written with `:=`, a motor that was
   running when the power failed could restart by itself when the power returns. Check
   this whenever you port a seal-in, an `OTL` or a `S=`.
5. **Testing.** `plctest` proves the IEC version. For the others use S7-PLCSIM or Logix
   emulation (FactoryTalk Logix Echo), and run the same scenarios as the `.test` file,
   including "Start and Stop together" and "overload during star".

> **Safety.** A real star-delta starter also has hard-wired electrical and mechanical
> interlocks between the star and delta contactors. The PLC interlock is the second line of
> defence, never the only one ([Module 07](../07-timers/)).

## A.14 False friends

Words and habits that look the same across tools but are not.

| False friend | In one tool | In another | What goes wrong |
|---|---|---|---|
| Timer preset | IEC: `PT := T#5s`, a `TIME` | Rockwell: `.PRE := 5000`, a `DINT` in ms. Siemens S5: `S5T#5S`, BCD | Copy the number 5 and the delay becomes 5 ms |
| `TIME` data type | CODESYS and Siemens: 32 bits, milliseconds | Logix (newer versions): 64 bits, **microseconds**; `TIME32` is 32 bits, also microseconds | A raw count copied between them is out by a factor of 1000 |
| `TONR` | Siemens: **retentive** on-delay (accumulating, with an `R` input) | Rockwell ST/FBD: ordinary on-delay "with reset". The retentive one is `RTOR` (ladder `RTO`) | An accumulating run-hours timer silently resets, or the other way round |
| `SR`, `RS` | IEC and CODESYS: `SR` is set-dominant | Siemens: `SR` is **reset**-dominant (`S`, `R1`) | A trip latch that loses to its reset, or a motor latch that ignores Stop. The input marked 1 wins |
| `LIMIT` | IEC, Siemens, CODESYS: a **clamp** that returns a number | Rockwell `LIM` (v36: `LIMIT`): a **test** that is true inside the band, or outside it when Low > High | Ported code compiles and does something completely different |
| `SQR` | Siemens: square (x²) | Rockwell: square root (v36: `SQRT`) | Flow from a differential-pressure transmitter comes out squared instead of rooted |
| `SCL` | Siemens: the Structured Text language | Rockwell: the *Scale* instruction (FBD/ST) | Confusing searches and conversations |
| `TOD` | IEC: the *time of day* data type | Rockwell (legacy): *convert to BCD* instruction (v36: `TO_BCD`) | As above |
| Program | IEC: a `PROGRAM` POU containing code | Rockwell: a container of routines and tags. Siemens: the whole user program | "Add it to the program" means different things |
| `ENO` | Siemens LAD/FBD: FALSE after an error such as overflow; when `EN` is FALSE the box does not run and **its outputs are not written** (the destination keeps its old value) | IEC: `EN`/`ENO` are optional. Rockwell ladder: the rung condition, with `S:V` for overflow | A value "freezes" when its box is disabled. In SCL, how `ENO` is set depends on a block property: check it |
| REAL to integer | Rockwell: `MOV` or assignment **rounds**; `TRN`/`TRUNC` truncates. `DIV` with only integer operands truncates, but with a `REAL` operand and an integer destination it rounds | IEC `REAL_TO_INT` rounds; `TRUNC` truncates. C-style habits expect truncation | Off-by-one indexes and counts. Logix and MATIEC round exact halves to the even neighbour (2.5 → 2, 3.5 → 4); other platforms may round halves away from zero, so don't rely on them |
| `CTD` done | IEC `CTD.Q`: `CV <= 0` | Rockwell `CTD .DN`: `.ACC >= .PRE` | A "batch finished" signal that is never, or always, true |
| Counter limits | IEC/MATIEC and Siemens: stop at a limit | Rockwell: wraps at the `DINT` limits and sets `.OV`/`.UN` | A totaliser that suddenly goes negative |
| Array bounds | IEC, Siemens, CODESYS: any bounds, often `[1..10]` | Rockwell: always zero-based, `[0]` to `[9]` | Off-by-one, or a major fault on an index out of range |
| Byte order | Siemens: big-endian; `%M10.0` is bit 8 of `%MW10` | Logix and most CODESYS targets: little-endian | Wrong bits in status words, scrambled `REAL`s over comms |
| Modbus 40001 | A documentation reference | Holding register **0** on the wire | Every value is read from the register next door |
| `TIME_TO_DINT` | CODESYS: milliseconds | MATIEC/OpenPLC: seconds | A 1.5 s timeout becomes 25 minutes ([Appendix E](E-matiec-openplc-notes.md)) |
| Retentive by default | Logix: every tag. The prescan clears `OTE` bits and ST `[:=]` targets, but `OTL` bits and ST `:=` targets survive a power cycle | Siemens: only what you mark retentive. IEC: only `RETAIN` | Equipment restarts after a power cut, or setpoints are lost |
| Download | Logix: replaces tag values with the project's | Siemens: reinitialising a DB replaces actual values with start values | Tuned setpoints and counts are overwritten |

---

Back to the [course home](../README.md) · [Module 00 — Start Here](../00-start-here/) ·
Related: [Appendix B — Glossary](B-glossary.md) · [Appendix E — MATIEC and OpenPLC notes](E-matiec-openplc-notes.md)
