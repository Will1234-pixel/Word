# Authoring guide for the PLC course

This file is for anyone who extends or corrects the course: new lessons, labs or tests. Learners
don't need it.

## 1. Audience and voice

- The reader is an adult who is new to PLC programming but already works around industrial
  plant. The original learner works with process-safety and instrumentation documents:
  loop drawings with 4–20 mA signals and 250 Ω burden resistors, intrinsically-safe barriers,
  and cause-and-effect matrices. Use examples from process plant *and* machines, and make the
  links to instrumentation and safety explicit where they fit naturally.
- Tone: a clear, practical, experienced engineer teaching a colleague. Explain every term the
  first time it appears. Prefer concrete plant examples to abstractions. No filler, no hype.
- Spelling: British spelling for everyday words (behaviour, colour, organise, centre, metre).
  Keep established industry terms as the industry writes them ("analog input", "program").
- Standards: lead with IEC/EN names (IEC 61131-3, IEC 60204-1, IEC 61511, IEC 81346) and add
  North-American equivalents (NFPA 70E, NEC, ANSI/ISA) where they help.

## 2. Accuracy rules (the most important section)

1. **Never invent** facts, standard clause or table numbers, product features, part numbers,
   prices, dates or quotations. If you are not sure something is exactly right, say it in a
   more general way that *is* right, or leave it out. A vague correct sentence beats a precise
   wrong one.
2. Vendor statements must be well established, for example Rockwell timer bits `.EN .TT .DN`,
   Siemens analog nominal range 0–27648, Siemens `TON` needing an instance DB. Product names and
   licensing change, so avoid version numbers unless they are essential.
3. Timing diagrams, truth tables and worked numbers must be correct. Check the arithmetic.
4. Safety content must be conservative. Labs are training exercises, never designs for real
   safety functions. Say so wherever safety logic appears.
5. IEC 61131-3 editions: edition 2 (2003) is what MATIEC implements; edition 3 (2013) added
   object orientation (CLASS, METHOD, INTERFACE, EXTENDS, IMPLEMENTS, THIS/SUPER, access
   specifiers), references and more, and marked
   Instruction List (IL) as deprecated. `PROPERTY` is **not** part of the standard: it is a
   CODESYS/TwinCAT extension. Don't make claims about later editions unless you are certain
   of them.
6. Every code example that looks complete must compile. Put anything longer than a few lines,
   or anything whose correctness matters, into a lab file and run it through `plctest`.

## 3. Folder layout and file names

```
plc-course/NN-slug/
├── README.md
└── labs/
    ├── NN-k-lab-name.test          acceptance tests
    ├── starter/NN-k-lab-name.st    interface and config only; must compile; must FAIL the tests
    └── solutions/NN-k-lab-name.st  reference solution; must PASS the tests
```

- `NN` is the two-digit module number and `k` the lab number within the module
  (`07-1-star-delta`). Use lower-case words and hyphens.
- Write only inside your own module folders. Don't edit other modules, `tools/`, or
  top-level files.
- Don't run `git` commands. Committing is done separately.

## 4. The lesson README

Use this skeleton and adapt the headings to the topic. All sections are expected.

```markdown
# NN — Title

> **Level:** N — Name · **Time:** ~X hours · **Prerequisites:** [Module MM](../MM-slug/), ...

One or two paragraphs: what this module covers and why it matters on a real plant.

## Learning objectives
- (5–8 measurable objectives: "Explain…", "Write…", "Choose…")

## <Concept sections>
Teach the ideas in a logical order. Use tables, ASCII timing/ladder diagrams and Mermaid
diagrams (GitHub renders Mermaid code blocks). Every major idea gets a worked example.

## Worked examples
Complete, realistic examples: ladder (ASCII) and/or ST, with an explanation of how the logic
behaves scan by scan where that helps.

## Common mistakes and how to avoid them

## Vendor notes
How the topic looks in Siemens TIA Portal, Rockwell Studio 5000 / CCW, CODESYS, and OpenPLC.

## Labs
One subsection per lab: goal, story/specification, **interface table**, numbered
requirements, how to run the test, and a collapsible hint.

## Check your understanding
6–10 questions, from recall to design and debugging, with answers in <details>.

## Further reading (optional)

---
Previous: [MM — Title](../MM-slug/) · Next: [PP — Title](../PP-slug/)
```

- Length: depth is expected. Most modules land between 3,500 and 8,000 words of lesson text,
  plus labs. Theory-heavy modules can be longer. Don't pad.
- Code fences: ```` ```iecst ```` for Structured Text, ```` ```text ```` for ASCII ladder and
  timing diagrams, ```` ```mermaid ```` for state and flow diagrams.
- Ladder notation (defined in Module 00, use it exactly):
  `--] [--` NO contact, `--]/[--` NC contact, `--( )--` coil, `--(S)--` set coil,
  `--(R)--` reset coil, `--]P[--` rising-edge contact, `--]N[--` falling-edge contact.
  Function blocks are drawn as boxes of `+`, `-` and `|` with pin names.
- Links to other modules are relative (`../07-timers/`). Link a specific lab as
  `../07-timers/README.md#lab-07-1-star-delta-starter`, or just link the module.

### Module slugs (for links)

```
00-start-here                       13-sequential-control
01-what-is-a-plc                    14-analog-and-process-io
02-electrical-and-field-devices     15-pid-control
03-data-types-and-addressing        16-alarms-and-diagnostics
04-ladder-logic                     17-industrial-communications
05-boolean-logic-and-fbd            18-hmi-and-scada
06-edges-and-one-shots              19-motion-and-drives
07-timers                           20-functional-safety
08-counters                         21-architecture-and-standards
09-math-and-data-handling           22-software-engineering
10-structured-text                  23-commissioning-and-troubleshooting
11-program-organization             24-capstone-projects
12-data-structures                  appendices/A-vendor-cross-reference.md
                                    appendices/B-glossary.md
                                    appendices/C-study-plan-and-self-assessment.md
                                    appendices/D-resources-and-certifications.md
                                    appendices/E-matiec-openplc-notes.md
```

## 5. Lab files

### 5.1 `.st` files (starter and solution)

Model every lab on `00-start-here/labs/` (read those three files first):

```iecst
(* Lab 07-1: Star-delta starter.
   Module 07 (Timers). REFERENCE SOLUTION - try the lab yourself first. *)

PROGRAM StarDelta
  VAR (* I/O *)
    StartPB   AT %IX0.0 : BOOL;  (* Start push-button, NO *)
    StopPB_NC AT %IX0.1 : BOOL;  (* Stop push-button, NC: TRUE while not pressed *)
    ...
    MainK     AT %QX0.0 : BOOL;  (* Main contactor *)
  END_VAR
  VAR (* internal *)
    StarTimer : TON;
  END_VAR

  (* logic ... *)
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : StarDelta;
  END_RESOURCE
END_CONFIGURATION
```

- Keep the configuration exactly as shown: `Config0`, `Res0`, `MainTask`, 10 ms, and one
  program instance `Inst0`. The OpenPLC Runtime expects `Config0`/`Res0`.
- Physical I/O uses located variables (`AT %IX0.0`, `%QX0.0`, `%IW0` for INT analog inputs,
  `%QW0` for analog outputs) in their **own** `VAR` block. MATIEC rejects a block that mixes
  located and unlocated variables.
- Starter = the same header (saying STARTER), the same declarations and configuration, any
  helper types or FBs the learner is *given*, and a body of placeholder assignments marked
  `(* TODO *)`. MATIEC rejects an empty body. The starter must compile and must fail the tests.
- Solutions must be clean, well commented and idiomatic. They are teaching material, so they
  show best practice for that stage of the course.
- Test directives (rarely needed): a comment `(* @plctest test=../x.test expect=fail *)` or
  `(* @plctest mode=compile *)` changes how `plctest --all` treats a file. Files under
  `starter/` and `mutants/` are expected to fail their tests by default.

### 5.2 `.test` files

- Start with a `#` comment block: which lab, and what is tested.
- Use one `scenario` per behaviour, with a descriptive name. Every scenario starts from a fresh
  PLC, so set healthy states first: NC inputs TRUE, e-stops healthy, permissives OK.
- **Only reference variables that appear in the lab's interface table.** Learners' own
  solutions must be able to pass. If the lab tells the learner to create a specific instance or
  variable (for example "an instance `Pump1` of `FB_Motor` with output `Running`"), that name is
  part of the interface and must be in the table.
- Make the tests independent of scan time: use `wait` and `until ... within` for timing, never
  a count of scans, and allow at least ±30 ms on timing checks. Where a timer matters, check
  just before it expires (for example at 90 % of the preset: still off) and just after (110 %:
  on).
- Test the negative cases too: things that must *not* happen, stop priority, faults, wire
  breaks, resets that must not restart equipment, boundary values.
- Before you finish, write 2–4 plausible **wrong** solutions (mutants) in a temporary folder
  and confirm the tests catch each one. A wrong solution that passes means the tests need
  strengthening. Don't commit throwaway mutants. Only labs that are *about* mutants keep them,
  under `labs/mutants/`.

### 5.3 Running the checks

From `plc-course/`:

```bash
python3 tools/plctest.py labs/path/solutions/NN-k-x.st          # one file (finds ../NN-k-x.test)
python3 tools/plctest.py some/file.st some.test                 # explicit test
python3 tools/plctest.py --all NN-slug                          # whole module: must end "0 problem(s)"
python3 tools/plctest.py --keep file.st                         # keep generated C to inspect
python3 tools/plctest.py --help                                 # full .test language
```

## 6. MATIEC restrictions (all verified)

Lab `.st` files must avoid everything below. The lesson text should still teach the full
language, with notes such as "CODESYS/TIA also allow…".

| Not supported by MATIEC | Use instead |
|---|---|
| `//` line comments | `(* ... *)` |
| Nested comments `(* (* *) *)` | Don't nest |
| Mixing located (`AT %IX…`) and unlocated variables in one `VAR` block | Separate `VAR` blocks |
| Arrays of function block instances (`ARRAY[1..3] OF TON`) | Separate instances, or arrays of structs processed by a FUNCTION, or one FB that loops over an array |
| Function block instances inside a `STRUCT` | Keep FB instances as variables of the program/FB |
| `STRING[n]` / `STRING(n)` length declarations (errors or crashes the compiler) | Plain `STRING` (max 126 characters) |
| Generic conversion `TO_INT(x)` etc. | Typed conversions: `REAL_TO_INT`, `INT_TO_REAL`, `DINT_TO_REAL`, `WORD_TO_INT`, `TIME_TO_DINT`, `TRUNC` … |
| Bit access `MyWord.3` | `SHR`/`SHL` with `AND 16#…` masks, or BOOL arrays |
| Enumerations with explicit values `(A := 1, B := 5)` | Plain enums `(A, B)`, or integer constants |
| `LTIME`, `LDATE`, … | `TIME`, `DATE` |
| OOP: `METHOD`, `PROPERTY`, `INTERFACE`, `EXTENDS`, `IMPLEMENTS`, `THIS`, `SUPER` | Plain FBs; show OOP in lesson text only, marked "CODESYS/TwinCAT syntax, not testable here" |
| `VAR_GLOBAL` inside a PROGRAM | `VAR_GLOBAL` in the CONFIGURATION, `VAR_EXTERNAL` in the POU |
| Empty body or bare `;` statement | At least one real statement |
| A variable with the same name as a POU, type, configuration, resource or task (the OpenPLC `-p` flag makes these clash). That includes standard functions and FBs (`Limit`, `Max`, `Sel`, `Move`, `Ton` …) and type keywords (`Dt`, `Date`, `Step`) | Unique, descriptive names |
| A POU/type/task name that matches a variable or parameter name used anywhere, **including inside the standard library** (`M`, `P`, `Q`, `IN`, `PT`, `ET`, `CLK`, `CU`, `CV`, `PV` …) | Descriptive POU names (`FB_Pump`, `PumpStation`), never one or two letters |
| An array as a FUNCTION `VAR_INPUT` (compiles, but the C build fails) | Pass arrays to a FUNCTION_BLOCK input (named array type), or as `VAR_IN_OUT` |
| `MUL_TIME`, `DIV_TIME` function names | Write `T * n` and `T / n` (TIME times/divided by a number works) |
| Several FB instances declared in one list (`Pump1, Pump2 : FB_Motor;`); this crashed OpenPLC's compiler in one lab | One FB instance per line |
| Edge-qualified inputs `X : BOOL R_EDGE;` / `F_EDGE` | `R_TRIG`/`F_TRIG` instances inside the FB |
| A named constant (`VAR CONSTANT`) as a `CASE` label | Literals or enumeration values as labels (enums are the better design anyway) |
| Enumeration values or variables named like keywords (`Program`, `Step`, `Transition`, `Action`, `Word`, `By`) | Other names; identifiers are case-insensitive |

Supported and verified: `IF/ELSIF/CASE` with ranges, `FOR ... BY`, `WHILE`, `REPEAT`, `EXIT`,
`CONTINUE`, `RETURN`, `VAR_TEMP`, `VAR RETAIN`, `VAR CONSTANT`, `VAR_IN_OUT`, functions, FB
calls with `=>` output binding, calling an FB after setting inputs as fields (`T1.IN := x; T1();`),
structs (including arrays inside structs), arrays of structs, multi-dimensional arrays, array
and struct initialisers (`[1, 2, 3(0)]`, `(A := 5, B := TRUE)`), plain enums with `E_X#Value`,
subranges `INT(0..100)`, `SHL/SHR/ROL/ROR`, `AND/OR/XOR/NOT` on `WORD`, `LIMIT/SEL/MUX/MAX/MIN`,
`MOD`, `**`, `EXPT`, `SQRT`, `LN`, `SIN` …, TIME arithmetic (`T1 + T2`, `T1 - T2`, `T * n`,
`ADD_TIME`, `SUB_TIME`) and comparisons, `DT/TOD/DATE`
literals, `REF_TO`/`REF()`/`^`, string functions (`CONCAT`, `LEN`, `LEFT`, `FIND`,
`INT_TO_STRING`), textual **SFC** (`INITIAL_STEP`, `STEP`, `TRANSITION FROM … TO … := …`,
`ACTION`) and **IL**.

Standard FBs available: `R_TRIG F_TRIG SR RS CTU CTD CTUD` (plus `_DINT/_LINT/_UDINT/_ULINT`
variants), `TP TON TOF`, and OpenPLC/MATIEC extras `PID RAMP HYSTERESIS INTEGRAL DERIVATIVE
RTC SEMA`. There is no `RTO` (retentive timer), so build one when needed; that makes a good lab.

Behaviour notes:

- Integer division truncates toward zero (`-7 / 2 = -3`). `MOD` takes the sign of the dividend
  (`-7 MOD 2 = -1`). `REAL_TO_INT` rounds to the nearest integer, and in MATIEC exact halves go
  to the even neighbour (2.5 → 2, 3.5 → 4, −2.5 → −2). Other platforms may round halves
  differently, so labs must not depend on ties. `TRUNC` truncates toward zero
  (`TRUNC(-2.7) = -2`).
- **TIME conversions use seconds in MATIEC and OpenPLC:** `TIME_TO_DINT(T#2500ms)` = 2
  (whole seconds, truncated), `TIME_TO_REAL(T#2500ms)` = 2.5, `DINT_TO_TIME(1500)` = 1500 s.
  CODESYS and most other tools use **milliseconds**. Avoid these conversions in lab logic
  where you can: compare TIME values directly, or keep elapsed time as TIME. If you must
  convert, say so in a comment and in the lesson.
- `plctest` supplies a fix for an upstream MATIEC code-generation bug in `TIME + TIME` and
  `TIME - TIME`. OpenPLC's own compiler is not affected.
- `plctest` gives located inputs the value 0/FALSE at the start of every scenario, so the test
  must set NC inputs TRUE.
- The first scan in `plctest` runs at t = one task interval (10 ms).
- Don't write tests that depend on what an edge detector does on the very first scan.
  The standard's reference F_TRIG, used by upstream MATIEC (`plctest`) and the OpenPLC
  runtime, outputs TRUE on its first call when CLK is FALSE. Other libraries may differ.
