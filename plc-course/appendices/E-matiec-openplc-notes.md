# Appendix E — MATIEC, OpenPLC and the `plctest` Runner

This appendix explains what happens when you run `plctest`, which parts of IEC 61131-3 the
MATIEC compiler does and does not accept, where it behaves differently from other platforms,
and how to move lab code into CODESYS, TIA Portal or Studio 5000. Everything here was checked
by compiling and running test programs, not copied from documentation.

## E.1 What MATIEC and `plctest` are

**MATIEC** is an open-source IEC 61131-3 compiler from the Beremiz project. Its `iec2c`
program translates Structured Text, Instruction List and textual SFC into C. The OpenPLC
Runtime ships its own copy (a fork) of MATIEC. When the Runtime builds a program (the v3
Runtime from an uploaded `.st` file; v4 is driven from the Editor), the v3 build script runs
that compiler with these options:

```text
iec2c -f -l -p -r -R -a program.st
```

| Flag | Meaning |
|---|---|
| `-f` | show full source locations (`line-column..line-column`) in error messages |
| `-l` | relaxed datatype equivalence (a non-standard extension) |
| `-p` | allow forward references, so a POU can be used before it is declared (see E.4) |
| `-r` | allow references: `REF_TO`, `REF()`, `^`, `NULL` (an edition 3 feature) |
| `-R` | allow `REF_TO ANY` and references inside arrays and structs (non-standard) |
| `-a` | allow non-literal array bounds (non-standard) |

`plctest` uses the **same flags** with the upstream Beremiz MATIEC. `tools/setup-matiec.sh`
clones it and builds it into `tools/.matiec`. For every language feature used in this course
the two compilers accepted and rejected exactly the same programs (see E.3 for one
library difference, and E.2 for one crash seen only in OpenPLC's fork).

### How a test runs

1. `iec2c` compiles your `.st` file into C files: `POUS.c/h` (your POUs), `Config0.c`,
   `Res0.c` (configuration and resource), `LOCATED_VARIABLES.h` (your `%I/%Q/%M` addresses).
2. `plctest` reads the generated headers to learn the name, type and C location of every
   variable. That is how `set Motor TRUE` or `expect Pump1.Running TRUE` find the right memory.
3. It turns the `.test` scenario into a small C program. The program provides storage for each
   located address, a PLC clock (`__CURRENT_TIME`) and a scan loop, then compiles everything
   with `gcc` and runs it.
4. Each `scan` advances the clock by the task interval and then calls the configuration's run
   function once. That runs every task that is due, just as a real runtime would. `wait` and
   `until` simply repeat scans.

Use `python3 tools/plctest.py --keep file.st` to keep the generated C and read it. It is a good
way to see what a compiler really does with your code, for example how a `TON` call becomes a
call to `TON_body__()` with its inputs copied in first.

### What the simulation does and does not model

| Modelled | Not modelled |
|---|---|
| The scan cycle: inputs you `set` are seen at the next scan, and outputs are checked after it | Input filters, I/O module update times, jitter. Inputs can only change *between* scans |
| PLC time for timers (`TON`, `TOF`, `TP`, your own timing logic) | Real-time pressure: scan-time overruns, watchdogs (an endless loop is reported after 60 s of real time instead) |
| Several tasks with different intervals (run at multiples of the common tick) | Task pre-emption within a scan |
| Located I/O (`%IX`, `%QX`, `%IW`, `%QW`, `%M…`) and globals | Communication, real hardware, retentive memory across power cycles (every `scenario` is a cold start) |
| Initial values, `RETAIN` declarations (they compile) | A warm restart that keeps `RETAIN` values |

## E.2 Language restrictions

These are the constructs MATIEC rejects, or crashes on, that you will meet in other tools.
The lab files avoid all of them.

| Not accepted by MATIEC | What to write instead | In CODESYS / TIA Portal / Studio 5000 |
|---|---|---|
| `//` line comments | `(* … *)` | All three accept `//` |
| Nested comments `(* (* *) *)` | Don't nest | CODESYS allows nesting |
| Located and unlocated variables mixed in one `VAR` block | Separate `VAR` blocks | Allowed in CODESYS. TIA and Logix use tag tables and tags instead of `AT` |
| Arrays of function block instances (`ARRAY[1..3] OF TON`) | Separate instances, an array of structs processed by a function, or one FB that loops over an array | CODESYS and TIA (multi-instance arrays) allow them |
| Function block instances inside a `STRUCT` | Declare the FB instance next to the struct | Varies by tool and version. Check your tool's help |
| `STRING[n]` or `STRING(n)` length declarations | Plain `STRING` (up to 126 characters here) | CODESYS `STRING(n)`, TIA `String[n]` |
| Generic conversions `TO_INT(x)`, `TO_REAL(x)` | Typed conversions: `REAL_TO_INT`, `INT_TO_REAL`, `DINT_TO_REAL`, `WORD_TO_INT`, `TIME_TO_DINT`, `TRUNC` … | CODESYS accepts both forms. TIA uses typed conversions such as `REAL_TO_INT`, plus implicit conversion between many types |
| Bit access `MyWord.3` | Masks and shifts: `(SHR(MyWord, 3) AND 16#1) <> 0`, or a BOOL array | CODESYS `MyWord.3`, TIA `MyWord.%X3`, Logix `MyDint.3` |
| Enumerations with explicit values `(Idle := 0, Run := 10)` | Plain enumerations, or integer constants | Allowed in CODESYS. In TIA Portal, recent versions offer comparable named-value data types for S7-1500; check your version |
| `LTIME`, `LDATE`, `LTOD`, `LDT` | `TIME`, `DATE`, `TOD`, `DT` | Available in edition-3 tools |
| Object orientation from edition 3: `METHOD`, `INTERFACE`, `EXTENDS`, `IMPLEMENTS`, `THIS`, `SUPER`, and the CODESYS/TwinCAT extension `PROPERTY` | Plain function blocks | CODESYS and TwinCAT (see Module 21) |
| `VAR_GLOBAL` inside a `PROGRAM` | `VAR_GLOBAL` in the `CONFIGURATION`, `VAR_EXTERNAL` in the POU | Global variable lists (CODESYS), global DBs (TIA), controller tags (Logix) |
| An empty program body, or a bare `;` statement | At least one real statement. That is why starters contain placeholder assignments | Empty bodies are allowed elsewhere |
| An array as a FUNCTION `VAR_INPUT` (it compiles, then the C build fails) | Pass the array to a FUNCTION_BLOCK input (use a named array type), or as `VAR_IN_OUT` | Allowed |
| A `DT` (DATE_AND_TIME) member inside a structure or array (it compiles, then the C build fails: "initializer element is not constant") | Keep a `DT` as a plain variable, or store `TOD`/`DATE` or a DINT timestamp in the structure | Allowed |
| A local `VAR CONSTANT` used as an array bound, `ARRAY[1..N_MAX]` ("Subrange upper limit is not a constant value"), even with `-a` | Literal bounds; or a `VAR_GLOBAL CONSTANT` in the CONFIGURATION, read through `VAR_EXTERNAL CONSTANT` | Allowed |
| An array **element** passed to a FUNCTION's `VAR_IN_OUT`, `F(Arr[2])` (it compiles, then the C build fails) | Copy the element to a variable, call, copy back; or pass the whole array | Allowed |
| Located arrays, `Inputs AT %IX0.0 : ARRAY[0..7] OF BOOL` | Separate located BOOLs, copied into an array in the I/O-mapping code | Allowed in CODESYS; TIA and Logix map I/O differently |
| Ordering or converting enumeration values: `State > Idle`, `E_State_TO_INT(State)` | Compare with `=` / `<>`, or use `CASE`; keep a separate INT if you need a number | CODESYS allows conversion and, with care, ordering |
| `MUL_TIME` / `DIV_TIME` function names | `T * n`, `T / n`, or the older names `MULTIME` / `DIVTIME` | Named functions available in some tools |
| (OpenPLC's fork only) Some structure initialisers that upstream MATIEC accepts: initialisers for **arrays of structures**, struct initialisers with **array members** (`(Dose := [1.0, 2.0])`), and in some programs even TIME or REAL members of a constant structure ("Initialization element identifier … is not declared"). Which ones fail depends on the rest of the file | Leave the initialiser out and set the values in a first-scan block (`IF NOT Loaded THEN … Loaded := TRUE; END_IF`). If the data is `RETAIN`, make the flag `RETAIN` too (see capstone 24-2) | Allowed |
| (OpenPLC's fork only) Several instances of your own FB declared in one list, `Cause1, Cause2, Cause3 : FB_TripCause;`, crashed the Runtime's compiler in two labs, while upstream MATIEC compiled them. The crash is in the code that writes `VARIABLES.csv` and depends on the rest of the program, so it is hard to predict | Declare FB instances one per line. All lab files follow this rule | Not affected |
| A named constant (`VAR CONSTANT`) used as a `CASE` label ("invalid case element(s)") | Literal labels, or better, an enumeration | Allowed |
| Edge-qualified FB inputs `X : BOOL R_EDGE;` / `F_EDGE` (compiler error or crash) | An `R_TRIG`/`F_TRIG` instance inside the FB | Supported in CODESYS |
| `WSTRING` (internal compiler error) | `STRING` | `WSTRING` / `WString` available |
| A based literal outside the signed range, assigned to a signed type: `MyInt := 16#FFFF;` or `MySint := 16#80;` (rejected as "Incompatible data types") | Use the matching bit-string type (`WORD`, `BYTE`), a decimal value (`-1`), or a conversion (`WORD_TO_INT(16#FFFF)`) | Usually accepted, sometimes with a warning |

Accepted, and verified in this course: `IF/ELSIF/CASE` (with lists and ranges), `FOR … BY`,
`WHILE`, `REPEAT`, `EXIT`, `CONTINUE`, `RETURN`, `VAR_TEMP`, `VAR RETAIN`, `VAR CONSTANT`,
`VAR_IN_OUT`, functions, FB calls with `=>` output binding, structs (with arrays inside),
arrays of structs, multi-dimensional arrays, initialisers (`[1, 2, 3(0)]`,
`(A := 5, B := TRUE)`), plain enumerations with `E_State#Idle`, subranges `INT(0..100)`, shifts
and rotates, bitwise operators on `WORD`, `LIMIT/SEL/MUX/MAX/MIN`, `MOD`, `**`, `EXPT`, `SQRT`,
trigonometry, TIME arithmetic and comparison, `DT/TOD/DATE` literals, `REF_TO`, string
functions (`CONCAT`, `LEN`, `LEFT`, `FIND`, `INT_TO_STRING` …), textual SFC and Instruction List.

Standard function blocks available: `R_TRIG`, `F_TRIG`, `SR`, `RS`, `CTU`, `CTD`, `CTUD` (and
their `_DINT`, `_LINT`, `_UDINT`, `_ULINT` variants), `TP`, `TON`, `TOF`, plus the OpenPLC/MATIEC
extras `PID`, `RAMP`, `HYSTERESIS`, `INTEGRAL`, `DERIVATIVE`, `RTC` and `SEMA`. There is no
retentive timer (`RTO`/`TONR`). Module 07 shows how to build one.

## E.3 Behaviour you should not rely on

These are small differences between platforms. Good PLC code never depends on them.

**Integer division and `MOD`.** Division truncates toward zero, so `7 / 2 = 3` and
`-7 / 2 = -3`. `MOD` takes the sign of the dividend: `-7 MOD 2 = -1` and `7 MOD -2 = 1`.
Most platforms agree, but check before relying on negative operands.

**`REAL` to integer conversion.** `REAL_TO_INT` rounds to the nearest integer. In MATIEC an
exact half goes to the *even* neighbour:

| Expression | MATIEC result |
|---|---|
| `REAL_TO_INT(2.4)` | 2 |
| `REAL_TO_INT(2.5)` | 2 |
| `REAL_TO_INT(2.6)` | 3 |
| `REAL_TO_INT(3.5)` | 4 |
| `REAL_TO_INT(-2.5)` | -2 |
| `TRUNC(-2.7)` | -2 |

Other platforms may round halves away from zero. If exact halves matter, handle them
yourself, or convert with `TRUNC` after adding your own offset.

**`F_TRIG` on its very first call.** The reference implementation in the standard is:

```iecst
Q := NOT CLK AND NOT M;
M := NOT CLK;
```

With `M` initially FALSE and `CLK` FALSE on the first call, `Q` is TRUE for that first
execution: a "falling edge" appears out of nothing. Upstream MATIEC (and therefore `plctest`)
and the OpenPLC Runtime library both use this form, and a quick test confirms `Q` is TRUE on
the first scan and FALSE afterwards. The library copy inside OpenPLC's MATIEC source tree
contains a different version (`Q := NOT CLK AND M; M := CLK;`) that never pulses on the first
call, and other tools document their own behaviour. Treat the first scan after a restart as
special. Module 06 shows how to mask the first-call pulse with a first-scan flag. Never let a
falling-edge detector trigger anything important without checking what it does on your
platform.

**TIME conversions are in seconds.** In MATIEC and the OpenPLC Runtime:

| Expression | MATIEC / OpenPLC | CODESYS (and most other tools) |
|---|---|---|
| `TIME_TO_DINT(T#2500ms)` | 2 (whole seconds) | 2500 (milliseconds) |
| `TIME_TO_REAL(T#2500ms)` | 2.5 | 2500.0 |
| `DINT_TO_TIME(1500)` | T#1500s (25 minutes) | T#1.5s |

This is a classic source of bugs when code is moved between platforms: a timeout that was
1.5 seconds becomes 25 minutes. Compare TIME values directly (`Elapsed >= T#5s`), keep
elapsed times as TIME, and only convert where you must, with a comment that says which unit
you expect.

**TIME arithmetic in upstream MATIEC.** The current upstream code generator emits the wrong
C function name for `T1 + T2` and `T1 - T2`, so the C build fails. OpenPLC's fork generates
the right name, and `plctest` maps the wrong one for you, so you can write TIME arithmetic
normally.

**Subranges are not checked at all.** A variable of type `INT(0..100)` happily holds 150:
MATIEC accepts `Pct := 150;`, an out-of-range initial value, and assignments from other
variables, and nothing stops it at runtime. A subrange documents intent but gives no
protection here. Clamp with `LIMIT` yourself.

**`VAR_TEMP` does not remember anything.** Temporary variables are re-initialised every time
the POU runs (in a `PROGRAM`, that is every scan). A "previous value" bit kept in `VAR_TEMP`
therefore looks like a new edge on every scan. This is standard IEC behaviour, not a MATIEC
quirk. Keep anything that must survive between scans in `VAR`.

**A TIME sum can compare as smaller than it is.** When the millisecond parts of a TIME
addition add up to exactly one second, MATIEC's library leaves the result un-normalised
(4 s + 1 000 000 000 ns instead of 5 s). It prints as 5000 ms, but compares as neither
equal to nor greater than `T#5s`:

| Expression | MATIEC result |
|---|---|
| `T#4500ms + T#500ms` | prints as T#5000ms |
| `(T#4500ms + T#500ms) >= T#5s` | FALSE |
| `(T#4500ms + T#500ms) = T#5s` | FALSE |

The cause is an off-by-one test (`> 1000000000` instead of `>=`) in the normalising
function; OpenPLC's runtime library has the same code. The effect is that a `>=` test on an
accumulated time can fire one scan late. For timing, prefer a timer's `ET`, which is not
affected. [Module 07](../07-timers/) shows how to design accumulated-time logic around it.
`ADD_TIME`, `SUB_TIME`, `MULTIME` and `DIVTIME` all work; the edition-3 names `MUL_TIME` and
`DIV_TIME` do not.

**Integer overflow.** Arithmetic wraps around silently (`INT` 32767 + 1 = −32768) because the
generated C uses fixed-size integers. Some PLCs set a status flag or fault instead. Size your
variables so overflow cannot happen (Modules 03 and 09).

### SFC in MATIEC

MATIEC compiles textual SFC. Earlier OpenPLC Editor versions drew graphical SFC and compiled
it the same way; the current v4 Editor lists LD, FBD, ST and IL, and CODESYS is the easiest
free tool for graphical SFC. MATIEC differs from the standard in some SFC details, so write
charts that don't depend on them:

- **Alternative (selection) branches:** if two alternative transitions from the same step are
  TRUE in the same scan, MATIEC activates **both** following steps. That was verified here.
  Always make alternative transition conditions mutually exclusive, for example
  `Go AND RouteA` / `Go AND NOT RouteA`.
- The Module 13 authors also found, and checked in MATIEC, that:
  - the final execution of an action with its `Q` flag FALSE after its step deactivates is not
    performed;
  - a `P` action on the `INITIAL_STEP` does not run at power-up;
  - a Boolean action variable driven with `P0` stays TRUE;
  - an `N` action can drop out for a scan when the chart moves from a step written later in
    the source to one written earlier.

  Module 13 shows how to structure charts so that none of this matters: outputs are driven
  from step flags or `N` actions on the steps where they must be on, and there are no
  overlapping alternative conditions.
- Step flags (`MyStep.X`) and step times (`MyStep.T`) can be used inside the program, but
  `plctest` scenarios cannot address them, so SFC lab tests check outputs only.

## E.4 Name clashes caused by the `-p` flag

With forward references enabled, the compiler first collects the names of every POU, data type,
configuration, resource and task, **including those in the standard library**. If you then
use one of those names as a variable, even inside another POU, parsing fails with a confusing
message that often points into a library file:

```text
edge_detection.txt:23-17..23-23: error: invalid located variable declaration.
```

That error came from a test program named `M`: the standard `R_TRIG` block has an internal
variable called `M`, which then collided with the program name. The fix is to give every POU,
type, configuration, resource and task a name that is not used for any variable. The course
naming conventions (`FB_…`, `ST_…`, `E_…`, descriptive program names, `Config0`, `Res0`,
`MainTask`, `Inst0`) keep you clear of this.

The same happens with names of standard functions and FBs (`Limit`, `Max`, `Sel`, `Sin`,
`Ton`), type keywords (`Dt`, `Date`, `Word`) and language keywords (`Step`, `By`, `Program`,
`Transition`, `Action`) used as variable or enumeration-value names.
Remember that IEC identifiers are **not case-sensitive**: `Motor`, `MOTOR` and `motor` are
the same variable, and `Sin` is the same name as the `SIN` function.

## E.5 Reading MATIEC error messages

`-f` gives locations as `file:line-column..line-column`. Three rules help:

1. **Fix the first error first.** Later errors are often knock-on effects.
2. **Look one line up.** A missing `;`, `END_IF` or `THEN` is usually reported on the line
   after it.
3. **"invalid variable before ':='"** at a line that looks fine often means the previous
   statement was not closed, or that something MATIEC does not support (a `//` comment, bit
   access `x.3`, `TO_INT`) came just before it.

| Message (shortened) | Usual cause |
|---|---|
| `';' missing at the end of statement` | Missing semicolon, or an unsupported construct on that line |
| `invalid located variable declaration` | Located and unlocated variables mixed in one `VAR` block, or a name clash (E.4) |
| `no body defined in program declaration` | Empty program body. Add at least one statement |
| `invalid item data type in array specification` | Array of FB instances (not supported) |
| `invalid specification in structure element declaration` | FB instance inside a `STRUCT` |
| `')' missing at the end of enumerated specification` | Enumeration with explicit values |
| `unknown error in function block declaration` | `METHOD` or other edition-3 OOP syntax |
| iec2c *crashes* (segmentation fault) | `STRING[n]` / `STRING(n)` with an initial value. Use `STRING` |

## E.6 Moving lab code to other tools

| Lab file element | CODESYS / TwinCAT | Siemens TIA Portal (SCL) | Rockwell Studio 5000 (ST) |
|---|---|---|---|
| `PROGRAM X … END_PROGRAM` | POU of type *Program* (declaration + implementation parts) | An FC or FB called from OB1 (a cyclic organisation block) | A routine in a program, scheduled by a task |
| `CONFIGURATION / RESOURCE / TASK` | Task configuration tree | OB1 (program cycle) or cyclic-interrupt OBs (OB30–OB38) | Continuous or periodic task |
| `VAR … AT %IX0.0 : BOOL` | Same syntax, or map in the I/O configuration | PLC tag table (`%I0.0`), then use the symbolic name | Module-defined tags (`Local:1:I.Data.0`), usually aliased to a descriptive tag |
| `(* comment *)` | Same, or `//` | Same, or `//` | Same, or `//` |
| `Timer1(IN := x, PT := T#5s);` | Same | `#Timer1(IN := x, PT := T#5s);` with `Timer1` a multi-instance `TON_TIME` in the FB's static area, or a single-instance DB | ST uses `TONR`/`TOFR`/`RTOR` with an `FBD_TIMER` tag and `.PRE` in milliseconds. The ladder `TON` has `.EN/.TT/.DN/.ACC` |
| `REAL_TO_INT(x)` | Same, or `TO_INT(x)` | Same, or `ROUND(x)` / `TRUNC(x)` | Assign across types (`MyDint := MyReal;` rounds) or use `TRN` |
| Local variable use | Plain name | `#Name` (quotes for globals: `"Name"`) | Plain tag name |

Vendor details change between versions. Treat the table as a starting point and check your
tool's help for the exact instruction names.

## E.7 OpenPLC Editor v4 and the STruC++ compiler

The current **OpenPLC Editor (v4)** no longer uses MATIEC. It compiles Structured Text, and the
Ladder and FBD it translates into Structured Text, with **STruC++**, a newer IEC 61131-3 to
C++ compiler. MATIEC remains what `plctest` uses and what the older OpenPLC Runtime v3 used.

Every lab file was also compiled with STruC++ 0.6.9, the version bundled with OpenPLC Editor
4.3.1. All of them compile except the textual-SFC lab (13-3), because STruC++ and the v4
Editor have no SFC. These are the differences that were found, and how the labs avoid them:

| Construct | MATIEC (`plctest`, OpenPLC v3) | STruC++ (OpenPLC v4) | What the labs do |
|---|---|---|---|
| Qualified enum value `E_State#Idle` (the IEC form) | Accepted | Rejected ("unexpected character #") | Plain `Idle` |
| Qualified enum value `E_State.Idle` (CODESYS style) | Rejected | Accepted | Plain `Idle` |
| `VAR CONSTANT` with no initial value | Accepted | Rejected ("must have an initializer") | A plain `VAR` that nothing writes to |
| A variable named like a function or block in STruC++'s bundled libraries (for example `Window`: OSCAT Basic has a `WINDOW` function) | Accepted | Rejected: the name clashes with the library function | Distinct names (`PressWindow`) |
| Textual SFC (`INITIAL_STEP`, `STEP`, `TRANSITION`) | Supported | Not supported | Only Lab 13-3 uses it |

Plain enum values (`Idle`) are the form every compiler here accepts, as long as two enum types
don't share a value name.

**Using a lab in OpenPLC Editor v4.** Create a project, add a program in Structured Text,
then copy the lab's variable declarations and its logic into the program. Data types
(`TYPE … END_TYPE`) and function blocks become separate items in the project tree. The
CONFIGURATION section at the end of each lab file isn't needed: the Editor sets up tasks in its
own configuration. For a ready-to-open example of the v4 project format, see the
[PLC Playground](../playground/).

## E.8 Troubleshooting the setup

- **`MATIEC (iec2c) not found`**: run `tools/setup-matiec.sh` from the `plc-course` folder,
  or set `MATIEC_HOME` to an existing MATIEC build (a folder that contains `iec2c` and `lib/`).
- **`autoreconf: command not found`**, or errors about `flex`/`bison`/`libtool`: install the
  build tools listed in Module 00, delete `tools/.matiec` and run the script again.
- **macOS: the build complains about `bison` or `flex`**: macOS ships old versions, and
  Homebrew does not put its newer ones on the PATH. Try
  `export PATH="$(brew --prefix bison)/bin:$(brew --prefix flex)/bin:$PATH"`, then rebuild.
- **`C build of the test harness failed`**: `gcc` must be installed (`build-essential` on
  Ubuntu, Xcode command-line tools on macOS). Choose another compiler with `CC=clang`.
- **A test hangs and is then reported after 60 s**: your program has a loop that never ends
  within one scan. A real PLC would stop with a watchdog fault. See Module 10.
