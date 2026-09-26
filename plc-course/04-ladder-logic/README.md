# 04 — Ladder Logic Fundamentals

> **Level:** 2 — Core programming · **Time:** ~8–10 hours (about half of it on the labs) · **Prerequisites:** [Module 01](../01-what-is-a-plc/), [Module 02](../02-electrical-and-field-devices/), [Module 03](../03-data-types-and-addressing/)

Ladder Diagram (LD) is the PLC language you will meet most often. Motor starters, valve
interlocks, pump permissives and conveyor controls all over the world are written in it, and
it is what the maintenance electrician opens at three in the morning when a pump will not
start. It looks like the relay schematics from [Module 02](../02-electrical-and-field-devices/).
That resemblance is its great strength, because anyone who can read a control circuit can
follow a rung. It is also the source of the most common beginner mistakes, because a ladder
rung is **not** a circuit. It is a program that the PLC evaluates, one rung after another,
once per scan.

This module teaches how a ladder program really executes and how to build the circuits
everything else rests on:

- the normally-open/normally-closed confusion that catches almost every beginner;
- the seal-in and set/reset patterns that give a PLC memory;
- the double-coil bug;
- interlocking, the logic that stops two things from happening at once or in the wrong order.

You will also learn to translate between ladder and Structured Text (ST) in both directions.
The labs are checked in ST, many real projects mix the two languages, and being able to read a
rung as a Boolean equation is the fastest way to understand what it does.

## Learning objectives

By the end of this module you will be able to:

- **Describe** how a PLC evaluates a ladder program (left to right along a rung, rungs top to
  bottom, once per scan) and predict the effect of rung order on a result.
- **Write** series (AND), parallel (OR) and nested branch logic, and **redraw** a relay
  circuit that cannot be entered directly into a PLC editor.
- **Explain** why a physically normally-closed stop button is programmed with a
  normally-open contact (XIC), and choose the right contact instruction for any combination
  of device wiring and required behaviour.
- **Build** stop-dominant and start-dominant seal-in circuits, including several start/stop
  stations, and place each condition correctly on the rung: start branch, seal-in branch or
  main path.
- **Use** set/reset coils and the `SR`/`RS` bistables, choose their dominance, predict what
  they do after a power cycle, and decide when a seal-in is the better choice.
- **Recognise, trace and fix** the double-coil bug.
- **Design** interlocks for a reversing starter with travel limits, permissives and a jog
  function, and explain why a software interlock never replaces an electrical one.
- **Document** a ladder program with rung comments, tag descriptions and cross-references,
  and **translate** rungs between LD, ST and FBD.

## 1. How a ladder diagram is built

### 1.1 Rails, rungs, contacts and coils

A ladder diagram is drawn between two vertical lines, the **power rails**. The left rail is
thought of as "live". Between the rails run horizontal **rungs** (Siemens and CODESYS call
them **networks**). On each rung, **contacts** on the left form a condition, and **coils** or
function block boxes on the right act on the result. IEC 61131-3 allows the right rail to be
left out, and some editors don't draw it.

```text
 left power rail                                                  right power rail
 |                                                                               |
 |      A              B                                         Out1            |
 |-----] [------------]/[---------------------------------------( )--------------|   rung 1
 |                                                                               |
 |      C                                                        Out2            |
 |-----] [------------------------------------------------------(S)--------------|   rung 2
 |                                                                               |
```

| Element | Symbol in this course | What it does |
|---|---|---|
| Normally-open contact | `--] [--` | Passes power when its bit is **TRUE** (1) |
| Normally-closed contact | `--]/[--` | Passes power when its bit is **FALSE** (0) |
| Coil | `--( )--` | Writes the rung result to its bit on **every** scan: TRUE if power reaches it, FALSE if not |
| Set coil | `--(S)--` | Writes TRUE when power reaches it. Otherwise it leaves the bit alone |
| Reset coil | `--(R)--` | Writes FALSE when power reaches it. Otherwise it leaves the bit alone |
| Negated coil | `--(/)--` | Writes the inverse of the rung result. Legal, but it makes rungs hard to read, so avoid it |
| Box | a drawn block | A function or function block (timer, counter, `SR`, `RS`...) with the rung as one of its inputs |

The two most important sentences in this module:

> **A contact is a question about one bit. A coil is an assignment to one bit.**

Every contact names a **tag** (a variable): an input, an output, or an internal memory bit.
You can use the same bit in as many contacts as you like, in any rung. A real relay has only
a handful of contacts, and a PLC bit has an unlimited number. What you must **not** do is
write the same bit from more than one coil (section 5).

### 1.2 A rung is a program, not a circuit

Ladder was designed to look like relay schematics so that electricians could read it. The
resemblance ends at the drawing:

| | Hard-wired relay schematic (Module 02) | PLC ladder |
|---|---|---|
| A contact symbol is | a physical contact on a device, drawn in its shelf (unoperated) state | an instruction that tests one bit in memory |
| `]/[` means | a contact that is closed when the device is at rest | "pass power if this bit is 0" |
| Evaluation | every path at once, continuously | one rung at a time, top to bottom, once per scan |
| Current direction | wherever the circuit lets it flow, sometimes in unexpected directions | left to right only |
| Contacts per device | limited by the contact blocks fitted | unlimited |
| Timing | pick-up and drop-out times, contact races | the order of the rungs |
| Feedback | a wire back to an earlier point | the coil's bit used as a contact |

Keep the right-hand column in mind and most ladder puzzles solve themselves.

### 1.3 How a rung is evaluated

Imagine the left rail carries power, that is, a logical TRUE. Each contact passes the power
on to its right if its test succeeds. A coil receives TRUE if at least one unbroken path of
passing contacts connects it to the left rail, and FALSE otherwise. Rockwell's manuals call
the state arriving at an instruction the **rung-condition-in**, and the state it passes on the
**rung-condition-out**. The idea is the same in every vendor's tool.

The execution rules:

1. **Each rung is solved as one Boolean expression**, conventionally described as left to
   right. The order within a rung matters only for instructions with side effects, such as
   one-shots ([Module 06](../06-edges-and-one-shots/)) and function blocks placed in the
   middle of a rung.
2. **Rungs execute top to bottom**, each one once per scan, unless jumps or subroutine calls
   change the order.
3. **A coil writes its bit in memory immediately.** A rung further down in the same scan
   sees the new value. A rung further up sees it only in the next scan.
4. **A coil executes even when its rung is false**, and then it writes FALSE. This is why a
   coil "forgets" and a set coil doesn't (section 4), and it is the root of the double-coil
   bug (section 5). Boxes need a little more care. A timer box normally takes the rung as its
   first input (`IN`) and is executed on every scan, so a false rung simply gives it
   `IN` = FALSE and resets it. Rockwell's `TON` and the usual IEC `TON` connection in CODESYS
   and TIA Portal both work this way. If instead the rung drives a box's `EN` (enable) input,
   which IEC-style editors offer for most blocks, a false rung skips the box altogether and
   its outputs freeze at their last values. [Module 07](../07-timers/) shows why that matters
   for timers.
5. **Physical outputs change at the end of the scan**, when the output image is copied to the
   output modules. That is the classic scan model of [Module 01](../01-what-is-a-plc/). Some
   platforms, Rockwell Logix among them, update I/O asynchronously to the scan (Module 01
   explains the consequences). Rules 1 to 4 about the order of evaluation hold either way.

Rule 3 in action. `A` switches on:

```text
 rung 1     B                                                     C
 |---------] [--------------------------------------------------( )-----|

 rung 2     A                                                     B
 |---------] [--------------------------------------------------( )-----|
```

| Scan | `A` | Rung 1 reads `B` | `C` after rung 1 | `B` after rung 2 |
|---|---|---|---|---|
| n (A turns on) | TRUE | FALSE (last scan's value) | FALSE | TRUE |
| n+1 | TRUE | TRUE | **TRUE** | TRUE |

`C` lags `B` by one scan. Swap the two rungs and `C` follows in the same scan. For a lamp
this doesn't matter. For handshakes, sequences and edge detection it does, so write rungs in
the order the data flows: inputs, then logic, then outputs.

**Online monitoring.** When you watch a running program, the editor shows which contacts
are passing power and which bits are on. Studio 5000 highlights true instructions in green.
TIA Portal's program status draws paths that carry power as solid green lines and the others
as dashed blue lines. A highlighted contact tells you about the **bit**, not the device. A
highlighted `--] [-- StopPB_NC` means "the stop circuit is healthy", not "stop pressed".

### 1.4 Series is AND, parallel is OR

**Contacts in series are AND.** Power has to pass through both:

```text
        A              B                                         Lamp
 |-----] [------------] [---------------------------------------( )-----|
```

`Lamp := A AND B;`

**Contacts in parallel (a branch) are OR.** Power can take either path:

```text
        A                                                        Lamp
 |-----] [------+-----------------------------------------------( )-----|
 |              |
 |      B       |
 |-----] [------+
```

`Lamp := A OR B;`

**A normally-closed contact is NOT** of its bit. Put the three together:

```text
        A              C                                         Lamp
 |-----] [------+-----]/[---------------------------------------( )-----|
 |              |
 |      B       |
 |-----] [------+
```

`Lamp := (A OR B) AND NOT C;`

| A | B | C | A OR B | NOT C | Lamp |
|---|---|---|---|---|---|
| 0 | 0 | 0 | 0 | 1 | 0 |
| 0 | 0 | 1 | 0 | 0 | 0 |
| 0 | 1 | 0 | 1 | 1 | **1** |
| 0 | 1 | 1 | 1 | 0 | 0 |
| 1 | 0 | 0 | 1 | 1 | **1** |
| 1 | 0 | 1 | 1 | 0 | 0 |
| 1 | 1 | 0 | 1 | 1 | **1** |
| 1 | 1 | 1 | 1 | 0 | 0 |

The brackets matter. In ST, `AND` binds more tightly than `OR`, so `A OR B AND NOT C` means
`A OR (B AND NOT C)`, which is a different circuit (the `C` contact would sit only in the
lower branch). **Every parallel branch that is in series with something else needs
brackets in ST.** [Module 05](../05-boolean-logic-and-fbd/) takes the algebra further.

### 1.5 Series inside parallel, and nested branches

A branch can itself contain contacts in series. Here is a pump permissive: the suction valve
must be open, and either the tank level is OK or a supervisor has keyed in an override:

```text
      SuctionOpen      LevelOK                                   Permit
 |-------] [-------+------] [----------------------+------------( )-----|
 |                 |                               |
 |                 |   Override        SupKey      |
 |                 +----] [-----------] [----------+
```

`Permit := SuctionOpen AND (LevelOK OR (Override AND SupKey));`

A **nested branch** is a branch inside a branch:

```text
        A              B                                         Out
 |-----] [------+-----] [------+------+-------------------------( )-----|
 |              |              |      |
 |              |      C       |      |
 |              +-----] [------+      |
 |                                    |
 |      D                             |
 |-----] [----------------------------+
```

`Out := (A AND (B OR C)) OR D;`

To read a complicated rung, find the innermost branch, write it as one bracketed term, and
work outwards. To draw one, work the other way: write the Boolean expression first, then
turn every `AND` into series and every `OR` into a branch.

### 1.6 Branch rules in real editors

PLC editors are stricter than a pencil. The rules below hold, in one form or another, in
every mainstream editor:

1. **Power flows only from left to right.** There is no reverse flow through a contact.
2. **Contacts sit on horizontal lines only.** You cannot put a contact on a vertical link
   between two branches.
3. **Branches open and close cleanly.** A branch starts at one point on the rung and rejoins
   it further right, and branches don't cross each other.
4. **Feedback is done with the coil's bit**, never with a wire looping back to the left.
5. **Several coils can hang in parallel at the right-hand end of one rung.** They all receive
   the same rung result:

```text
       Motor                                                    RunLamp
 |-----] [------------------------------------------+-----------( )-----|
 |                                                  |
 |                                                  |          HMI_Running
 |                                                  +-----------( )-----|
```

Editors differ in the details. IEC 61131-3 lets a coil pass its input state on to the right,
and some editors (Studio 5000, for example) accept further conditions after an output
instruction on the same rung. Others insist that coils sit at the right-hand end. Older
platforms and some editors limit how many elements fit on a rung and how deeply branches may
nest. If you hit such a limit, the rung is too complicated anyway: split it with an internal
bit.

**The bridge circuit.** Rules 1 and 2 bite when you convert old relay panels. Relay designers
sometimes used a **bridge**: a contact between two parallel paths that current can cross in
either direction.

```text
   relay schematic: current can flow either way through contact E

             A                  B
  L1 ---+---] [-------+--------] [-------+----( K1 )---- N
        |             |                  |
        |             E  (vertical)      |
        |             |                  |
        +---] [-------+--------] [-------+
             C                  D
```

Current reaches `K1` through four paths: A-B, C-D, A-E-D (down through E) and C-E-B (up
through E). You can't draw E on a vertical link in a PLC editor, so list every path as its
own series branch:

```text
        A              B                                         K1
 |-----] [------------] [-----------------+---------------------( )-----|
 |                                        |
 |      C              D                  |
 |-----] [------------] [-----------------+
 |                                        |
 |      A              E              D   |
 |-----] [------------] [------------] [--+
 |                                        |
 |      C              E              B   |
 |-----] [------------] [------------] [--+
```

`K1 := (A AND B) OR (C AND D) OR (A AND E AND D) OR (C AND E AND B);`

In relay circuits an unintended path of this kind is called a **sneak path**, and it can
cause baffling faults. When you convert a panel, ask whether every path was really intended.
The conversion is a good moment to find out.

## 2. The NO/NC confusion

### 2.1 Contacts examine bits, not devices

Rockwell's instruction names say exactly what a contact does:

- **XIC, Examine If Closed:** true when the bit is 1. The course draws it `--] [--`.
- **XIO, Examine If Open:** true when the bit is 0. The course draws it `--]/[--`.

"Closed" and "open" describe the input circuit as the PLC sees it. An input bit is 1 when
current flows in the input circuit, because whatever is wired to it is closed, and 0 when
it doesn't ([Module 02](../02-electrical-and-field-devices/)). The instruction has no idea what kind of
device is wired to the terminal, what its contacts look like, or whether it is a push-button
or a pressure switch. It looks at the bit and nothing else.

That is the key to the confusion. **"Normally closed" on a device and "normally closed" on a
ladder contact are two different things**, and they only share a name and a symbol.

### 2.2 The four combinations

First, what the input bit reads for each device:

| Device (wiring) | Device state | Current into the input? | Input bit |
|---|---|---|---|
| Start button (NO contact) | released | no | 0 |
| Start button (NO contact) | pressed | yes | 1 |
| Start button (NO contact) | wire broken | no | 0 |
| Stop button (NC contact) | released | **yes** | **1** |
| Stop button (NC contact) | pressed | no | 0 |
| Stop button (NC contact) | wire broken | no | 0 |

Now put each device into the seal-in rung with each kind of contact instruction, and ask
what happens. All four are legal programs. Only two are correct:

| # | Device | Instruction used | Rung | What happens | Verdict |
|---|---|---|---|---|---|
| 1 | NO start | `--] [--` (XIC) | `(StartPB OR Motor) AND ...` | Pressing Start passes power | **Correct** |
| 2 | NO start | `--]/[--` (XIO) | `(NOT StartPB OR Motor) AND ...` | Passes power while Start is **not** pressed: the motor starts by itself at power-up | Wrong |
| 3 | NC stop | `--] [--` (XIC) | `... AND StopPB_NC` | Passes power while Stop is not pressed. Pressing Stop **or a broken wire** removes it | **Correct and fail-safe** |
| 4 | NC stop | `--]/[--` (XIO) | `... AND NOT StopPB_NC` | Passes power only while Stop is pressed, or once its wire has broken | **Wrong and dangerous** |

Combination 4 is the classic beginner's rung. It comes from copying the relay schematic
symbol for symbol: the stop button is drawn `]/[` on the electrical drawing because it is a
physical NC contact, so it gets drawn `]/[` in the program too. Follow what it does:

- Normal operation: `NOT StopPB_NC` is `NOT TRUE` = FALSE. The motor **never starts**.
- Hold Stop and press Start: the motor runs. Release Stop: it stops. The stop button has
  become a run button.
- The stop wire breaks: `StopPB_NC` reads FALSE for good, `NOT StopPB_NC` is TRUE, and Start
  now runs the motor while the stop button does **nothing at all**.

The physical NC contact has already done its job in the wiring. It makes the healthy state
the one that passes current. In the program you only ask **"is the stop circuit healthy?"**,
and the answer is "is the bit 1?", which is XIC.

The rule that always works:

> Decide in words when the contact must pass power ("when the stop is **not** pressed").
> Work out which bit value that situation gives (NC stop, not pressed: current flows, bit 1).
> Use `--] [--` for 1 and `--]/[--` for 0.

### 2.3 Reading `StopPB_NC` and other healthy-TRUE tags

The course's `_NC` suffix ([Module 00](../00-start-here/)) tells you that the device is wired
normally-closed, so the bit is TRUE when all is well. Read the contacts aloud like this:

| Contact | Read it as |
|---|---|
| `--] [-- StopPB_NC` | "stop not pressed", or "stop circuit healthy" |
| `--]/[-- StopPB_NC` | "stop pressed, or its wire broken" |
| `--] [-- OverloadOK_NC` | "overload healthy" |
| `--]/[-- OverloadOK_NC` | "overload tripped, or its wire broken" |
| `--] [-- LevelHH_NC` | "level **not** high-high" |

Many plants use other conventions for the same idea: `StopOK`, `Stop_Healthy`,
`PSL101_OK`, or the device tag from the drawings with the meaning written in the tag
description. Whatever the name, a well-kept program makes it impossible to misread which state
is TRUE. The name, the tag description and the I/O list should all say it (section 7). When
you inherit a program where they don't, check the loop drawing or the I/O list before you
trust any contact on a stop, trip or permissive.

Process plant has many healthy-TRUE signals besides stop buttons: low-pressure switches
closed while pressure is healthy, level switches wired to open on a high-high level, "drive
healthy" relay contacts from VFDs, "no fault" contacts from gas detectors and fire panels.
Each one is used with `--] [--` where the logic needs "healthy", and with `--]/[--` where it
needs "tripped".

### 2.4 When `--]/[--` is exactly right

An NC contact instruction is correct wherever the condition you want is "this bit is 0":

- **Acting on the tripped state of an NC input.** A trip lamp:
  `--]/[-- OverloadOK_NC --( TripLamp )`.
- **Internal bits and outputs.** A stopped lamp: `--]/[-- Motor --( StoppedLamp )`. An
  interlock: `--]/[-- RevK` in the forward rung (section 6).
- **An NO input where you want "not active".** For example `--]/[-- DoorOpenLS`, "door not
  open".
- **Reset coils.** The rung `--]/[-- StopPB_NC --(R)-- Motor` resets the motor when Stop
  **is** pressed. Section 4 explains why the same stop button is `] [` in a seal-in and `]/[`
  in a reset rung.

## 3. The seal-in circuit

### 3.1 How it works

You met the seal-in (latching) circuit in [Module 00](../00-start-here/) and traced it scan by
scan in [Module 01](../01-what-is-a-plc/) (worked example 4):

```text
      StartPB         StopPB_NC                                  Motor
 |-----] [------+------] [--------------------------------------( )-----|
 |              |
 |     Motor    |
 |-----] [------+
```

```iecst
Motor := (StartPB OR Motor) AND StopPB_NC;
```

The `Motor` contact in parallel with Start is the **seal-in** (also called the holding or
latching contact). Start turns the coil on. From the next scan on, the coil's own bit keeps
the rung true after Start is released. Stop breaks the rung, the coil writes FALSE, and the
seal-in contact is gone with it, so releasing Stop does not restart the motor.

In a hard-wired starter the seal-in is the contactor's own auxiliary NO contact (often
terminals 13-14) wired across the start button. This is the **3-wire control** of Module 02.
Its most valuable property is what happens after a power failure: the contactor drops out and
stays out until someone presses Start. The PLC version behaves the same way, because a normal
(non-retentive) variable starts FALSE after a restart (section 3.6).

### 3.2 Stop-dominant versus start-dominant

Where you put the stop contact decides what happens when Start and Stop are pressed at the
same time.

**Stop-dominant**: the stop is in series with the whole OR, so it breaks every path.

```text
      StartPB         StopPB_NC                                  Motor
 |-----] [------+------] [--------------------------------------( )-----|
 |              |
 |     Motor    |
 |-----] [------+
```

`Motor := (StartPB OR Motor) AND StopPB_NC;`

**Start-dominant**: the stop is only in the seal-in branch, so Start bypasses it.

```text
      StartPB                                                    Motor
 |-----] [-----------------------------------+------------------( )-----|
 |                                           |
 |     Motor          StopPB_NC              |
 |-----] [-------------] [-------------------+
```

`Motor := StartPB OR (Motor AND StopPB_NC);`

| `StartPB` | `StopPB_NC` | `Motor` before | Stop-dominant: `Motor` after | Start-dominant: `Motor` after |
|---|---|---|---|---|
| FALSE | TRUE | FALSE | FALSE | FALSE |
| FALSE | TRUE | TRUE | TRUE | TRUE |
| TRUE | TRUE | FALSE | TRUE | TRUE |
| TRUE | TRUE | TRUE | TRUE | TRUE |
| FALSE | FALSE | FALSE | FALSE | FALSE |
| FALSE | FALSE | TRUE | FALSE | FALSE |
| TRUE | FALSE | FALSE | **FALSE** | **TRUE** |
| TRUE | FALSE | TRUE | **FALSE** | **TRUE** |

The last two rows are the whole difference. With start-dominance, holding Start overrides
Stop, and it also overrides a **broken stop wire**. For anything that moves or carries
energy, that is unacceptable. **Motors, pumps, fans, heaters and valves driven from
push-buttons are always stop-dominant.**

Set-dominance (the general name for start-dominance) has its proper uses, but they are
**memories of events**, not run commands. A trip or fault latch should be set-dominant: while
the trip condition is still present, pressing Reset, or a Reset button jammed down, must not
clear it. Section 4.6 comes back to this, and Lab 04-4 uses it.

### 3.3 Where each condition belongs on the rung

A seal-in rung has three places to put a contact, and each gives a different behaviour:

```text
     StartPB    DamperClosed        StopPB_NC    OverloadOK_NC           FanK
 |----] [--------] [--------+--------] [-------------] [----------------( )-----|
 |                          |
 |    FanK                  |
 |----] [-------------------+

 |<-- start branch: ------->|<------------- main path: ------------------->|
      start permissives           stops, trips, running interlocks
```

| Position | Effect | Use it for |
|---|---|---|
| **Main path**, in series with the whole OR | Must be true to start **and** to keep running. Going false drops the seal-in, and the motor stays off when it comes back | Stops, overloads, trips, running interlocks, travel limits |
| **Start branch**, in series with the start button only | Must be true to start. Ignored once running | **Start permissives**: conditions needed only at the moment of starting |
| **Seal-in branch**, in series with the seal-in contact only | Ignored while Start is held | Almost never correct for a stop (start-dominance, above) |

The example is a large centrifugal fan. Fans like this are often started with the inlet
damper closed to limit the starting load, and the damper opens once the fan is running. So
`DamperClosed` is a start permissive: it must be true to start, and it would be wrong for it
to stop the fan when the damper opens. Put the same contact in the main path and the fan
would trip the moment the damper started to open.

```iecst
FanK := ((StartPB AND DamperClosed) OR FanK) AND StopPB_NC AND OverloadOK_NC;
```

### 3.4 Several start and stop stations

A pump may have a local control station beside it and a panel in the control room. Wire it
the way a hard-wired circuit would: **starts in parallel** (any start closes a path) and
**stops in series** (any stop opens the path).

```text
     LocalStartPB     LocalStopPB_NC    RemoteStopPB_NC                  Motor
 |------] [-------+-------] [----------------] [------------------------( )-----|
 |                |
 |  RemoteStartPB |
 |------] [-------+
 |                |
 |      Motor     |
 |------] [-------+
```

```iecst
Motor := (LocalStartPB OR RemoteStartPB OR Motor)
         AND LocalStopPB_NC AND RemoteStopPB_NC;
```

Two practical points:

- **One input per station, or all stops wired in series to one input?** Wiring every stop
  button in series in the field and bringing the loop to one PLC input saves inputs, and it
  is still fail-safe. But the PLC can't tell which station stopped the motor. Separate inputs
  let you log "stopped from local station" and show it on the HMI, which operators and
  maintenance value when a pump stops "for no reason".
- **Stops normally work from every station**, whichever station has control. Starts are
  often restricted by a LOCAL/REMOTE selector ([Module 18](../18-hmi-and-scada/)). That
  selector goes in the start branch, never in series with the stops.

Lab 04-1 is this circuit.

### 3.5 Seal on the command bit, or on feedback?

In a hard-wired starter the seal-in contact belongs to the contactor itself. In a PLC you have
a choice:

- **Seal on the output bit** (`Motor`, as above). This is the normal practice. The seal-in
  holds as long as the PLC is commanding the motor.
- **Seal on the contactor's auxiliary contact**, wired back to an input (`MotorRunFB`). If
  the contactor drops out for a reason the PLC can't see, such as a hard-wired overload
  contact in the coil circuit, lost control power or a hard-wired emergency stop, the PLC's
  run command drops too. It won't sit there "still running" and pull the contactor back in
  when control power returns. The price: the start button has to be held until the contactor
  has pulled in (tens of milliseconds), and a failed feedback contact makes the motor
  impossible to hold on.

A common compromise seals on the command bit and **monitors the feedback** separately.
If the feedback doesn't arrive within a few seconds of the command, or disappears while
running, a discrepancy fault drops the command and raises an alarm. That needs a timer, so it
is built in [Module 07](../07-timers/).

### 3.6 What happens at power-up

The seal-in bit is an ordinary variable. After a restart it takes its initial value, FALSE,
so the motor stays off until someone presses Start. That is exactly the "no automatic
restart" behaviour that machinery standards such as IEC 60204-1 expect where a restart could
be hazardous. Two ways to lose it:

- Declaring the seal-in bit `RETAIN` or putting it in retentive memory (a retentive `M` range
  on Siemens, for example). The motor then restarts when power returns.
- Using set/reset coils on a platform where the bit survives a power cycle (section 4.3).

[Module 03](../03-data-types-and-addressing/) (section 7) covers retentive memory in detail.

## 4. Set and reset coils

### 4.1 Latch and unlatch

A **set coil** `--(S)--` (Rockwell **OTL**, Output Latch) writes TRUE when its rung is true,
and **does nothing** when its rung is false. A **reset coil** `--(R)--` (Rockwell **OTU**,
Output Unlatch) writes FALSE when its rung is true, and does nothing otherwise. Together they
make a memory with separate set and reset conditions:

```text
      StartPB                                                    Motor
 |-----] [------------------------------------------------------(S)-----|

      StopPB_NC                                                  Motor
 |-----]/[------------------------------------------------------(R)-----|
```

Look at the second rung. The stop button is `--]/[--` here, and that is **correct**: the
reset must act when Stop **is** pressed, which is when the bit is 0. In the seal-in rung the
same button was `--] [--`, because there the contact had to pass power when Stop was **not**
pressed. Same button, same wiring, opposite contact. The instruction follows the logic you
want, never the device.

In ST, a set coil is an `IF` with no `ELSE`:

```iecst
IF StartPB THEN
  Motor := TRUE;          (* set coil: writes only TRUE *)
END_IF;
IF NOT StopPB_NC THEN
  Motor := FALSE;         (* reset coil: writes only FALSE *)
END_IF;
```

The difference from an ordinary coil is exactly the missing `ELSE`. `Motor := StartPB;` (an
ordinary coil) is the same as `IF StartPB THEN Motor := TRUE; ELSE Motor := FALSE; END_IF;`.
It writes on every scan, and the motor would run only while Start is held.

### 4.2 Program order decides dominance

If the set rung and the reset rung are both true in the same scan, both write, and the **last
write wins**. Trace one scan with Start and Stop pressed together, set rung first:

| Point in the scan | `Motor` in memory |
|---|---|
| Start of scan (from last scan) | FALSE |
| After the set rung (Start pressed) | TRUE |
| After the reset rung (Stop pressed) | **FALSE** |
| Output write | FALSE: stop wins |

With the reset rung **after** the set rung the latch is reset-dominant. Swap them and it
becomes set-dominant. The order of the rungs is a design decision, so make it visible:

- Keep the set and reset rungs of a bit **next to each other**, with a comment that says which
  one wins.
- Put the **reset last** unless you deliberately want set-dominance.
- Don't let rungs **between** them read the bit. In the table above, a rung between the two
  would see `Motor` TRUE for part of a scan in which the motor never ran.

Several set rungs and several reset rungs for the same bit are legal and common, for example
one reset rung per trip condition, each with its own comment. That is not the double-coil bug,
because set and reset coils write only when their rung is true. It still spreads the logic of
one bit around the program, so group them. **Never** mix an ordinary coil with set/reset
coils on the same bit. The ordinary coil writes FALSE on every scan that its rung is false and
wipes out the latch.

### 4.3 Retentive behaviour across power cycles

A set coil writes only when its rung is true, so nothing in the program clears the bit at
start-up. Whether a latched bit survives a power cycle therefore depends on where the bit
lives and on the platform, not on the coil. Know which applies to yours:

| Platform | A bit latched with a set coil, after power returns |
|---|---|
| **IEC 61131-3, CODESYS, OpenPLC** | Depends on the declaration. A normal `VAR` starts at its initial value (FALSE). A `VAR RETAIN` bit keeps its value on a warm restart (CODESYS also has `PERSISTENT`). |
| **Rockwell Logix** (ControlLogix, CompactLogix) | Tag values are held through a power cycle. When the controller enters Run mode, including at power-up in Run, a **prescan** clears bits written by `OTE` but leaves bits written by `OTL`/`OTU` **unchanged**. An `OTL`-latched run bit comes back latched. |
| **Siemens S7-1200/S7-1500** | Depends on the memory. A bit in an `M` range marked retentive, or a data block member marked *Retain*, keeps its value. Otherwise it is initialised at start-up. Outputs are normally not retentive. |

The danger is obvious from the Rockwell row. If a conveyor's run command is latched with
`OTL`, the conveyor can start by itself the moment the controller powers up in Run, with
somebody's hands in it. The usual remedies:

- Use a seal-in (`OTE`) for anything that moves or carries energy.
- If you use set/reset, **reset the latch at start-up**: on the first scan (Rockwell `S:FS`,
  or a first-scan flag, [Module 06](../06-edges-and-one-shots/)) or in a startup routine
  (Siemens startup OB).
- Make every retentive choice deliberately and write it in the tag description.

Some latches **should** survive a power cycle: a lockout that must be investigated before
anything restarts, or a "batch in progress" flag that tells the restart logic a vessel was
part-way through a phase ([Module 13](../13-sequential-control/)). Make those retentive on
purpose, and make the restart logic check the plant before it acts.

### 4.4 Seal-in or set/reset?

| Situation | Prefer | Why |
|---|---|---|
| Motor, pump, fan, heater or valve from push-buttons | **Seal-in** | Every condition is on one rung, and what you see is all there is. Unless the bit has been made retentive on purpose, it drops out and stays out at power-up on every mainstream platform. That includes Rockwell, where all tags keep their values but the prescan clears `OTE` bits. |
| Many separate conditions that each stop or reset something (several trips) | **Set/reset**, grouped together | Each condition gets its own rung and comment |
| Remembering a short event: a fault, alarm or first-out | **Set/reset**, or a set-dominant `SR` | The event may last one scan. The memory must outlast it |
| Fill or empty between two level switches | **Either.** Set/reset reads like the specification: "open at low, close at high" | Lab 04-4 |
| Sequence steps | Set/reset or, better, a state variable | [Module 13](../13-sequential-control/) |

Whichever you choose, one bit should be written by **one** mechanism: one ordinary coil, or
one group of set/reset rungs.

### 4.5 The `SR` and `RS` bistable function blocks

IEC 61131-3 defines two standard function blocks that package a latch with a fixed
dominance. The input whose name ends in **1** is the dominant one:

```text
          SR                                   RS
     +-----------+                        +-----------+
     |    SR     |                        |    RS     |
 ----|S1       Q1|----                ----|S        Q1|----
 ----|R          |                    ----|R1         |
     +-----------+                        +-----------+
   set-dominant                           reset-dominant
   Q1 := S1 OR (NOT R AND Q1)             Q1 := NOT R1 AND (S OR Q1)
```

| Set input | Reset input | `SR.Q1` | `RS.Q1` |
|---|---|---|---|
| FALSE | FALSE | unchanged | unchanged |
| TRUE | FALSE | TRUE | TRUE |
| FALSE | TRUE | FALSE | FALSE |
| TRUE | TRUE | **TRUE** (set wins) | **FALSE** (reset wins) |

They are function blocks, so each latch needs its own **instance** with its own memory:

```iecst
(* declarations: FaultLatch : SR;  RunLatchFB : RS; *)
FaultLatch(S1 := TripCondition, R := ResetPB);   (* a trip must win over reset *)
Tripped := FaultLatch.Q1;

RunLatchFB(S := StartPB, R1 := NOT StopPB_NC);   (* stop must win over start *)
Motor := RunLatchFB.Q1;
```

In ladder, the box sits on the rung with its inputs wired from contacts, and a coil on
`Q1` drives the output.

> **Naming trap.** Siemens TIA Portal names its boxes the other way round from IEC. The
> Siemens `SR` has inputs `S` and `R1` and is **reset**-dominant. The Siemens `RS` has
> inputs `R` and `S1` and is **set**-dominant. CODESYS follows IEC (`SR` with `SET1`/`RESET`,
> `RS` with `SET`/`RESET1`). Rockwell Logix has no `SR`/`RS` in ladder (you use
> `OTL`/`OTU`), but it offers `SETD` (set dominant) and `RESD` (reset dominant) in FBD and
> ST. The rule that works everywhere: **the input marked 1 wins**. Never trust the box's
> name alone. Check the pin names or the instruction help.

### 4.6 Choosing the dominance

| Latch | Dominance | Reason |
|---|---|---|
| Run command of a motor, pump, heater or valve | **Reset (stop)** | Stop must always win, including over a held or stuck start button |
| Trip, fault or alarm memory | **Set** | While the fault is present, Reset can't clear it. A reset button held down, or taped down (it happens), must not hide a live fault |
| Fill valve between level switches | **Reset (high level)** | The high switch must close the valve even if the low switch also says "low" |

[Module 06](../06-edges-and-one-shots/) improves the fault latch further: resetting on the
*edge* of the reset button, so that a jammed button resets once and no more.

## 5. The double-coil bug

### 5.1 A worked example in ladder

[Module 01](../01-what-is-a-plc/) showed this bug in Structured Text. Here it is in ladder,
the way it usually appears on a real plant.

*A transfer conveyor CV-3 runs in AUTO when the line sequence requests it, but only while the
downstream conveyor CV-4 is running, so that product doesn't pile up. During commissioning a
manual mode was added by copying the coil into a new rung near the end of the program:*

```text
 Rung 12 - CV-3 in AUTO
      AutoMode     CV3_AutoReq     CV4_Running                      CV3_Motor
 |------] [-----------] [-------------] [---------------------------( )-----|

 ... rungs 13 to 46 ...

 Rung 47 - CV-3 in MANUAL (added during commissioning)
      ManualMode   CV3_ManualPB                                     CV3_Motor
 |------] [-----------] [-------------------------------------------( )-----|
```

Trace one scan in AUTO with the conveyor requested and CV-4 running:

| Point in the scan | `CV3_Motor` in memory |
|---|---|
| Start of scan (from last scan) | FALSE |
| After rung 12 (all three contacts true) | **TRUE** |
| Rungs 13 to 46 | TRUE (any rung that reads `CV3_Motor` sees TRUE) |
| After rung 47 (`ManualMode` FALSE, so the coil writes FALSE) | **FALSE** |
| Output write | FALSE: **CV-3 never runs in AUTO** |

The symptoms are typical. Manual works, because rung 47 is last. AUTO never works. Worse, if
the upstream conveyor's rung (somewhere between 13 and 46) uses `CV3_Motor` as its
"downstream running" interlock, it sees TRUE and runs product onto a conveyor that is stopped.

When you monitor the program online, rung 12 shows all three contacts passing power, yet
`CV3_Motor` reads FALSE in the tag monitor or watch table. Editors differ in how they
highlight a coil. Where the highlighting follows the bit's value, the coil is shown off even
though its rung is true. **A true rung whose coil's bit reads FALSE is the classic sign that
something else writes the same bit.**

### 5.2 The fix

Write the bit once. Combine the conditions on one rung. Doing that forces a question the
two-rung version was hiding: should the CV-4 interlock apply in manual too? It should, since
product piles up either way, so the interlock goes in the main path:

```text
      AutoMode     CV3_AutoReq                      CV4_Running         CV3_Motor
 |------] [-----------] [-----------+-------------------] [-------------( )-----|
 |                                  |
 |    ManualMode   CV3_ManualPB     |
 |------] [-----------] [-----------+
```

```iecst
CV3_Motor := ((AutoMode AND CV3_AutoReq) OR (ManualMode AND CV3_ManualPB))
             AND CV4_Running;
```

For bigger cases, build each mode's request on its own rung (`CV3_AutoRun`, `CV3_ManRun`),
each with its own comment, and combine them in **one** final output rung with the interlocks.
This scales to many modes and keeps the "why" of each condition visible.

### 5.3 Variants of the same bug

- **Two coils in different routines or programs.** They have the same effect and are harder
  to find.
- **An ordinary coil plus set/reset coils on the same bit.** The ordinary coil clears the
  latch on every scan.
- **A coil in code that isn't executed.** A coil in a section skipped by a jump, or in a
  subroutine that isn't called this scan, is not executed, so it doesn't write at all. Its bit
  keeps its last value, and an output can stay "frozen" on.
- **The HMI and a coil both write the same bit.** The coil overwrites the HMI's value on every
  scan, so the button on the screen "does nothing". Commands from an HMI go into their own
  bits, which the program reads ([Module 18](../18-hmi-and-scada/)).
- **Two tasks write the same bit** ([Module 11](../11-program-organization/)).

### 5.4 Finding it

Every PLC tool has a **cross-reference**: a list of every place a tag is used, showing
whether each use reads it (a contact) or writes it (a coil or another destructive
instruction), with the routine and rung. Before adding any coil, look up the tag. When
troubleshooting "it works in one mode but not the other", look up the output and count the
writes. Some tools warn at verification: Studio 5000, for example, reports a *duplicate
destructive bit reference*. Others warn only if you run an optional static-analysis check.
CODESYS Static Analysis, for example, has a rule for outputs written in more than one place,
and it works in Structured Text too. Many tools don't warn at all, so the discipline is
yours: **one bit, one writer**.
[Module 22](../22-software-engineering/) turns this into a general rule for whole projects.

## 6. Interlocking

### 6.1 Interlocks and permissives

- An **interlock** prevents an action, and stops it if it becomes false while the action is
  running. On a seal-in rung it sits in the **main path**.
- A **permissive** must be true for an action to start, but is not checked again once it has
  started. It sits in the **start branch**.

Terminology varies between companies and industries. Some call everything an interlock, and
many process plants reserve "trip" for protective shutdowns.
[Module 05](../05-boolean-logic-and-fbd/) treats permissives and interlocks as a design
topic. Keep one thing clear from the start: the interlocks in this module are **basic
control** functions. A function that protects people or the environment against a hazard is a
**safety function**. It is designed, implemented and tested under the functional safety
standards, normally in separate safety-rated hardware ([Module 20](../20-functional-safety/)).

### 6.2 Forward/reverse: the software interlock

A three-phase motor reverses when two of its phases are swapped. A reversing starter does
that with two contactors: forward `-K1` connects L1-L2-L3 to the motor's U-V-W, and reverse
`-K2` connects them with two phases exchanged. If both contactors close at once, two phases
are connected directly together through the contactors. That is a **phase-to-phase short
circuit**: at best the short-circuit protection trips, at worst the contacts weld or an arc
flash follows.

The software interlock puts each contactor's bit, with a `--]/[--` contact, in the main path
of the other one's rung:

```text
       FwdPB        StopPB_NC    OverloadOK_NC       RevK               FwdK
 |------] [------+------] [------------] [------------]/[--------------( )-----|
 |               |
 |      FwdK     |
 |------] [------+

       RevPB        StopPB_NC    OverloadOK_NC       FwdK               RevK
 |------] [------+------] [------------] [------------]/[--------------( )-----|
 |               |
 |      RevK     |
 |------] [------+
```

```iecst
FwdK := (FwdPB OR FwdK) AND StopPB_NC AND OverloadOK_NC AND NOT RevK;
RevK := (RevPB OR RevK) AND StopPB_NC AND OverloadOK_NC AND NOT FwdK;
```

What it does:

- Forward can't start while reverse is on, and the other way round.
- While running forward, the Reverse button is simply ignored. **To change direction the
  operator must press Stop first.**
- **The two bits can never both be TRUE at the end of a scan.** Rung 2 reads the value of
  `FwdK` that rung 1 has just written. If forward is on, reverse is forced off.

Now try pressing both buttons at the same moment from standstill. Rung 1 runs first:
`RevK` is still FALSE from the last scan, so `FwdK` becomes TRUE. Rung 2 then sees `FwdK`
TRUE and keeps `RevK` off. Forward wins, purely because its rung comes first. That is safe,
since only one contactor closes, but it is arbitrary. Lab 04-2 asks you to make "both buttons
at once" start nothing, by adding `--]/[-- RevPB` to the forward start branch and
`--]/[-- FwdPB` to the reverse start branch.

In hard-wired practice, NC contacts of the direction push-buttons are sometimes wired into the
opposite contactor's circuit, so that pressing Reverse drops Forward immediately and picks up
Reverse (reversing without Stop, called "plugging" when done at speed). That puts heavy
electrical and mechanical stress on the drive, and it is only acceptable where the machine is
designed for it. This module's designs always require Stop first.

### 6.3 The electrical and mechanical interlocks

The software interlock is **not enough on its own**. It knows only about the PLC's bits, and
several real failures are invisible to it:

- **Contactor timing.** When the PLC switches forward off and reverse on 10 ms later, the
  forward contactor's main contacts are still opening. A contactor needs tens of
  milliseconds to drop out, and the arc across its contacts needs time to extinguish. The
  reverse contactor could close into it.
- **A welded contact.** If forward's main contacts weld shut, the PLC thinks forward is off
  and will happily switch reverse on.
- **Failures outside the program.** A shorted output transistor, a forced output, an
  interposing relay stuck on, or someone pushing a contactor's armature in by hand.

So a reversing starter has **three** layers:

1. **Mechanical interlock**: a mechanical linkage between the two contactors, usually
   supplied as part of a reversing-contactor kit, so that both armatures cannot close at once.
2. **Electrical interlock**: an auxiliary **NC** contact of each contactor wired in series
   with the **other** contactor's coil. While `-K1` is closed, its NC auxiliary contact is
   open and `-K2`'s coil circuit is broken, whatever the PLC does.
3. **Software interlock**, as above. In practice it usually also has a short changeover delay
   after a stop ([Module 07](../07-timers/)) and monitoring of the contactors' feedback
   contacts.

The control circuit, drawn as an **electrical schematic**. Here `]/[` is a real NC auxiliary
contact, not a ladder instruction:

```text
   PLC output terminals

   %QX0.0 (FwdK) o------]/[-----------------( -K1 )------+
                       -K2 21-22             forward      |
                       (aux NC)              coil         |       -F2 95-96
                                                          +--------]/[----------- 0 V
                                                          |     (overload NC, one
   %QX0.1 (RevK) o------]/[-----------------( -K2 )------+      contact shared by
                       -K1 21-22             reverse               both coils)
                       (aux NC)              coil
```

The overload relay has one 95-96 contact, so it sits in the part of the circuit that both
coils share and drops whichever contactor is on. The PLC's `OverloadOK_NC` input comes from a
second contact on the overload relay (worked example 1, step 3). Terminal numbers such as
21-22 for an NC auxiliary contact and 95-96 for the overload relay's NC contact follow a
common convention, but always check the device data and the drawings. Larger contactors are
driven through interposing relays, as in Module 02.

### 6.4 Why stop before reversing

Reversing a running motor directly:

- draws a starting-sized current for longer than a normal start, and heats the rotor several
  times as much, because the motor is first braked against its own rotation and then
  accelerated the other way;
- gives a mechanical shock to couplings, gearboxes and the load (a loaded conveyor, a
  mixer full of product);
- risks the contactor arc problem above.

So the design requires Stop first. A real reversing starter also waits a short time after a
stop before allowing the other direction, which needs a timer
([Module 07](../07-timers/)). Where frequent reversing is part of the process, a
variable-speed drive does it properly with deceleration and acceleration ramps
([Module 19](../19-motion-and-drives/)).

One gap remains in the purely logical design, and it is worth seeing. Suppose the operator
holds the Reverse button while the motor runs forward. It is ignored, correctly. Now forward
stops for some other reason, such as reaching its travel limit. In that same scan (with the
rungs in the order above), reverse's interlock clears, Reverse is still held, and reverse
starts with no Stop pressed and no pause. The PLC switches `FwdK` off and `RevK` on in the
same scan, which is exactly the contactor-timing case the electrical interlock (section 6.3)
is there for. The tools that close this gap are an edge-triggered start, which needs a
**fresh** press ([Module 06](../06-edges-and-one-shots/)), and the changeover delay
([Module 07](../07-timers/)).

### 6.5 Travel limit switches

A machine that travels between two ends, such as a shuttle car, a sliding gate or a
motorised damper, has a **limit switch at each end of travel**:

- Each limit stops **only the direction heading towards it**. The other direction must still
  work, so the operator can drive away from the limit.
- Wire limits **NC** (TRUE while not at the limit). A broken wire then stops that direction,
  which is the safe failure.
- Put the limit in the **main path** of its own direction's rung. In the start branch it would
  only stop the motor *starting* at the limit. A motor already running would drive straight
  through the limit and into the mechanical end stop.
- A limit stop drops the seal-in, so the motor does not restart when the load coasts back
  off the switch.

```iecst
FwdK := (FwdPB OR FwdK) AND StopPB_NC AND OverloadOK_NC AND FwdLimitOK_NC AND NOT RevK;
RevK := (RevPB OR RevK) AND StopPB_NC AND OverloadOK_NC AND RevLimitOK_NC AND NOT FwdK;
```

Beyond the working limits, many machines have **over-travel limits** that cut the contactor
coils directly in the hard-wired circuit, because a software limit relies on the PLC, its
program and its outputs all working. The same pattern appears in **motor-operated valve
actuators**: open and close contactors (often inside the actuator), with end-of-travel limit
switches and torque switches stopping each direction.

Lab 04-2 is a reversing starter with both limits.

### 6.6 Permissives in practice

Permissives are "ready to start" checks. Typical examples:

| Equipment | Start permissive | Why it is not a running interlock |
|---|---|---|
| Large fan | Inlet damper closed | The damper opens once the fan is running |
| Centrifugal pump started against a closed discharge valve | Discharge valve closed (position switch) | The valve is opened once the pump is running |
| Conveyor in a line | Downstream conveyor running | Usually **also** a running interlock: if downstream stops, this one must stop too |
| Anything with a LOCAL/REMOTE selector | Selector in the matching position for this station's start | On many plants, switching the selector does not stop a running drive (practice varies, so follow the site standard) |

The third row is a reminder to ask "must it also keep running?" for every condition. Many
conditions are both, and then the contact belongs in the main path (which covers the start as
well). Show unmet permissives on the HMI ("start not permitted: damper not closed"). An
operator who presses Start and sees nothing happen will otherwise call maintenance.

### 6.7 Jog versus run

**Jogging** (also called inching) runs a motor only while a button is held. It is used to
position a machine, track a belt, clear a jam or set up tooling, often with a person close to
the moving parts. The one rule: **a jog must never seal in.** The person jogging expects the
motor to stop the instant they let go.

Here is the obvious-looking and wrong way to add a jog to a seal-in circuit:

```text
      StartPB         StopPB_NC                                  Motor
 |-----] [------+------] [--------------------------+-----------( )-----|    WRONG
 |              |                                   |
 |     Motor    |                                   |
 |-----] [------+                                   |
 |                                                  |
 |      JogPB                                       |
 |-----] [------------------------------------------+
```

```iecst
Motor := ((StartPB OR Motor) AND StopPB_NC) OR JogPB;    (* WRONG *)
```

| Scan | `JogPB` | `Motor` before | Result | `Motor` after |
|---|---|---|---|---|
| 1 | TRUE (pressed) | FALSE | `((F OR F) AND T) OR T` | TRUE |
| 2 | FALSE (released) | TRUE | `((F OR T) AND T) OR F` | **TRUE: sealed in** |

The jog turned the motor on, the motor's own seal-in contact caught it, and the belt keeps
running after the button is released. (As a bonus bug, `JogPB` bypasses the stop.) The fault
is that **the seal-in reads the output that the jog also drives**.

The correct pattern seals an **internal run bit**, never the output, and drives the output
from exactly one rung:

```text
      StartPB          RunSel      StopPB_NC                     RunLatch
 |-----] [------+------] [-----------] [------------------------( )-----|
 |              |
 |   RunLatch   |
 |-----] [------+

       JogPB           RunSel      StopPB_NC                     JogCmd
 |-----] [-------------]/[-----------] [------------------------( )-----|

      RunLatch                                                   Motor
 |-----] [------+-----------------------------------------------( )-----|
 |              |
 |    JogCmd    |
 |-----] [------+
```

```iecst
RunLatch := (StartPB OR RunLatch) AND RunSel AND StopPB_NC;
JogCmd := JogPB AND NOT RunSel AND StopPB_NC;
Motor := RunLatch OR JogCmd;
```

Nothing reads `Motor` back, so nothing can seal in through it. `RunSel` is a JOG/RUN selector
switch. It is in series with the whole run rung, so turning it to JOG drops the run latch, and
jogging is allowed only in JOG.

Relay designers knew this problem well. A jog made by opening the seal-in path with a
push-button's NC contact can occasionally seal in: when the button is released quickly, its NC
contact can close again before the contactor's auxiliary contact has opened. That is why relay
jog circuits use a jog/run selector switch or a separate jog relay. In a PLC the scan makes the
order exact, but the principle is the same: the jog path and the seal-in path must never meet.

On real machines, jogging with guards open is a **safety function** with its own requirements:
reduced speed, hold-to-run or enabling devices, and safety-rated hardware
([Module 19](../19-motion-and-drives/), [Module 20](../20-functional-safety/)). Lab 04-3 is
the logic only.

## 7. Documenting ladder

A ladder program is read far more often than it is written, usually by someone else, under
pressure, with the plant stopped. Documentation is part of the program.

### 7.1 Rung comments

- **Say why, not what.** The rung already shows *what*. A seal-in rung needs no comment that
  says "start/stop motor". It needs one that says what isn't visible:
  *"Stop-dominant. Local and remote stops in series: either stops the pump. Start permissive:
  discharge valve closed (starting against a closed valve limits the starting load)."*
- **Refer to the source of a requirement**: the functional design specification, the
  cause-and-effect chart, the interlock list, a change request. When someone wants to remove
  an interlock "because it keeps tripping", the comment tells them who asked for it and why.
- **Mark the unusual**: set-dominance, deliberate retentive bits, rungs that must stay in a
  particular order.
- **Give each section and routine a header**: what the equipment is, its P&ID or
  drawing tags, and its modes.

Siemens networks have a title and a comment field. Rockwell rungs carry rung comments.
CODESYS and OpenPLC networks can carry comments too.

### 7.2 Tag descriptions

Every tag needs a description that answers four questions: *which device, where, what does
TRUE mean, and where is it drawn?*

| Tag | Address | Description |
|---|---|---|
| `StopPB_NC` | `%IX0.1` | P-101 stop push-button -S1 at local station LCS-101. **NC: TRUE = not pressed.** Drawing 12, column 3 |
| `FwdLimitOK_NC` | `%IX0.3` | Shuttle car forward end-of-travel limit -B3. **NC: TRUE = not at limit.** Drawing 14, column 6 |
| `DryRunTrip` | internal | P-101 dry-run trip, set on T-100 low-low while running. **Set-dominant**, reset by `ResetPB` once the level has recovered. **Not retentive** |

The I/O list ([Module 03](../03-data-types-and-addressing/)) and the tag descriptions should
agree. Many plants generate one from the other.

### 7.3 Cross-references

Cross-references connect the program to itself and to the drawings:

- **Within the program**: every rung where a tag is read or written, as in section 5.4. This
  is how you find a double coil, and how you find everything an interlock affects before you
  change it.
- **Coil to contacts**: many editors can show, next to a coil, the rungs that use its bit as
  a contact. This is the program's version of the coil and contact cross-references on a
  relay schematic (Module 02).
- **Program to drawings**: tag, address, terminal, device tag, drawing sheet and column. When
  a contact is highlighted but the pump doesn't run, this chain takes you from the rung to the
  right terminal in the right panel.

### 7.4 A documented rung

```text
 Rung 3 - P-101 transfer pump run command
 Stop-dominant seal-in.
 Start permissive: discharge valve ZSC-101 closed (pump starts against a closed valve).
 Running interlocks: stop, overload, T-200 high level (LSH-200), T-100 low-low
 (LSLL-100), dry-run trip (latched in rungs 1 and 2).
 Ref: FDS section "P-101 control", interlock list items for P-101.

      StartPB     DischargeClosed    StopPB_NC   OverloadOK_NC ...           Pump
 |-----] [------------] [-------+-----] [-----------] [--------- ...--------( )-----|
 |                              |
 |     Pump                     |
 |-----] [----------------------+
```

The complete rung is worked example 2 below.

## 8. Translating between LD, ST and FBD

### 8.1 Ladder to ST

| Ladder | Structured Text |
|---|---|
| `--] [-- A` | `A` |
| `--]/[-- A` | `NOT A` |
| Contacts in series | `AND` |
| A parallel branch | `OR`, **with brackets around the whole branch** |
| `--( )-- X` at the end of the rung | `X := <rung expression>;` |
| `--(S)-- X` | `IF <rung expression> THEN X := TRUE; END_IF;` |
| `--(R)-- X` | `IF <rung expression> THEN X := FALSE; END_IF;` |
| Several coils in parallel | One assignment per coil, or an intermediate bit assigned once and copied |
| Rung order | Statement order |

**Method.** Start at the innermost branch. Write each branch as a bracketed `OR` of its paths,
and each path as an `AND` of its contacts. Then join the pieces left to right with `AND`.

Example 1, the Lab 04-1 rung from section 3.4:

```iecst
Motor := (LocalStartPB OR RemoteStartPB OR Motor)
         AND LocalStopPB_NC AND RemoteStopPB_NC;
```

Example 2, the nested rung from section 1.5: the inner branch is `(B OR C)`. In series with
`A` it gives `A AND (B OR C)`. In parallel with `D` it gives `(A AND (B OR C)) OR D`.

Example 3, a set/reset pair: each rung becomes an `IF` with no `ELSE`, in the same order as
the rungs (section 4.1).

### 8.2 ST to ladder

1. **Turn `IF` statements into Boolean assignments or set/reset rungs.** `IF c THEN X := TRUE;
   ELSE X := FALSE; END_IF;` is an ordinary coil (`X := c;`). An `IF` with only `THEN` is a set
   or reset coil.
2. **Push every `NOT` down onto single bits.** A ladder contact can negate one bit, not a
   bracket. Use De Morgan's laws ([Module 05](../05-boolean-logic-and-fbd/)):
   `NOT (A OR B) = NOT A AND NOT B` and `NOT (A AND B) = NOT A OR NOT B`.
3. **Turn each `AND` into series and each `OR` into a branch.**

Example:

```iecst
NoFlowAlarm := PumpRun AND NOT (FlowOK OR Bypass);
(* De Morgan: NOT (FlowOK OR Bypass) = NOT FlowOK AND NOT Bypass *)
NoFlowAlarm := PumpRun AND NOT FlowOK AND NOT Bypass;
```

```text
      PumpRun        FlowOK         Bypass                      NoFlowAlarm
 |-----] [------------]/[-----------]/[---------------------------( )-----|
```

Siemens LAD offers another route: the **invert RLO** contact `-|NOT|-` inverts the result of
everything to its left on the rung, so `NOT (FlowOK OR Bypass)` can be drawn as the branch
followed by `-|NOT|-`. Most other editors have no equivalent in ladder, so De Morgan or an
intermediate bit is the portable answer.

An `IF`/`ELSIF` latch in ST is the seal-in in disguise:

```iecst
IF NOT StopPB_NC THEN
  Motor := FALSE;           (* stop first: stop-dominant *)
ELSIF StartPB THEN
  Motor := TRUE;
END_IF;
(* same behaviour as  Motor := (StartPB OR Motor) AND StopPB_NC;  *)
```

Check the equivalence by cases. With Stop pressed, both give FALSE. With Stop released and
Start pressed, both give TRUE. With neither pressed, the `IF` doesn't write, so `Motor` keeps
its value, and the equation gives `(FALSE OR Motor) AND TRUE = Motor`.

### 8.3 FBD preview

Function Block Diagram draws the same logic as boxes with signals flowing left to right. The
seal-in:

```text
              +-------+
 StartPB -----|  OR   |          +-------+
              |       |----------|  AND  |
 Motor -------|       |          |       |------- Motor
              +-------+          |       |
 StopPB_NC ----------------------|       |
                                 +-------+
```

and the same function with a reset-dominant `RS` block, drawn with the IEC pin names that
MATIEC uses (CODESYS calls the same pins `SET` and `RESET1`). The small circle on the `R1`
input negates it, just like `NOT StopPB_NC`:

```text
                 +-----------+
                 |    RS     |
 StartPB --------|S        Q1|------- Motor
 StopPB_NC -----o|R1         |
                 +-----------+
```

[Module 05](../05-boolean-logic-and-fbd/) covers FBD properly, including how feedback
loops like the seal-in are drawn and executed.

## Worked examples

### Worked example 1: from a relay schematic to PLC ladder

*Module 02 showed this hard-wired 3-wire starter. Convert it to a PLC.*

```text
          L1 (120 V AC)                                              L2
           |                                                          |
  line 1   |---]/[---+---] [---+---------------------( M )----]/[-----|   2, 3
           |   PB1   |   PB2   |                             OL       |
           |   STOP  |   START |                                      |
  line 2   |         +---] [---+                                      |
           |              M                                           |
  line 3   |---] [-----------------------------------( PL1 )----------|
           |    M                                     RUN LIGHT       |
```

**Step 1: the I/O.** Every device that makes a decision becomes an input, and every load
becomes an output. Keep each device's contact type exactly as it is in the field:

| Tag | Address | Device | Wired | TRUE means |
|---|---|---|---|---|
| `StartPB` | `%IX0.0` | PB2 start | NO | pressed |
| `StopPB_NC` | `%IX0.1` | PB1 stop | **NC** | **not** pressed |
| `OverloadOK_NC` | `%IX0.2` | OL auxiliary contact | **NC** | **healthy** |
| `Motor` | `%QX0.0` | Coil M (via interposing relay if needed) | | energise contactor |
| `RunLamp` | `%QX0.1` | PL1 run light | | lamp on |

**Step 2: the rungs.** Every physical NC contact that appeared as `]/[` on the schematic
becomes `--] [--` in the program. The field wiring has already made "healthy" equal 1. The
seal-in contact M becomes the `Motor` bit.

```text
      StartPB         StopPB_NC      OverloadOK_NC               Motor
 |-----] [------+------] [--------------] [---------------------( )-----|
 |              |
 |     Motor    |
 |-----] [------+

       Motor                                                     RunLamp
 |-----] [------------------------------------------------------( )-----|
```

```iecst
Motor := (StartPB OR Motor) AND StopPB_NC AND OverloadOK_NC;
RunLamp := Motor;
```

**Step 3: what stays hard-wired.** In a real panel the overload's 95-96 contact normally stays
in series with the contactor coil as well, so that a trip drops the contactor even if the PLC
or its output has failed. The PLC then gets the overload's status from a second auxiliary
contact of the overload relay (Module 02). Check which contacts your relay has free: if the
only one left is the NO contact (97-98), the input reads TRUE when **tripped**, and the tag
must be named and used accordingly (`OverloadTripped`, used with `--]/[--` in the motor rung).
Emergency stops also stay in hard-wired or safety-rated circuits, with only a status signal to
the PLC ([Module 20](../20-functional-safety/)).

**Step 4: check against the schematic.** Walk through the same situations on paper and in
the program: start, release, stop, both pressed, overload trip, broken stop wire, power
failure. They must behave the same, except that the PLC version is more predictable.

### Worked example 2: a transfer pump with a permissive, interlocks and a latched trip

*Pump P-101 transfers liquid from tank T-100 to tank T-200. The specification:*

- *Start and Stop push-buttons at a local station. Stop-dominant.*
- *The pump starts against a closed discharge valve: position switch ZSC-101 must show
  "closed" to start. The valve is opened afterwards (by other logic) and that must not stop
  the pump.*
- *Overload trip (NC contact).*
- *T-200 high level (LSH-200, wired NC) stops the pump. It may be restarted by hand once the
  level has dropped.*
- *T-100 low-low level (LSLL-100, wired NC) prevents starting. If it occurs while the pump is
  running, it stops the pump and latches a dry-run trip. The trip can only be reset once the
  level has recovered, and the reset must not restart the pump.*

**Design.** Sort each condition into its place (section 3.3):

| Condition | Where | Why |
|---|---|---|
| `DischargeClosed` | Start branch | Start permissive only |
| `StopPB_NC`, `OverloadOK_NC` | Main path | Stops |
| `DestHighOK_NC` | Main path | Running interlock, no latch |
| `LevelLLOK_NC` | Main path | Prevents starting on an empty tank, and stops at once |
| `DryRunTrip` (set/reset latch) | `--]/[--` in the main path | Holds the pump off until reset |

```text
 Rung 1 - DryRunTrip SET: pump was running when T-100 reached low-low
       Pump        LevelLLOK_NC                                   DryRunTrip
 |-----] [------------]/[---------------------------------------(S)-----|

 Rung 2 - DryRunTrip RESET: operator reset, only once the level has recovered
      ResetPB      LevelLLOK_NC                                   DryRunTrip
 |-----] [-------------] [--------------------------------------(R)-----|

 Rung 3 - P-101 run command
      StartPB   DischargeClosed   StopPB_NC  OverloadOK_NC  DestHighOK_NC  LevelLLOK_NC  DryRunTrip      Pump
 |-----] [---------] [-------+-----] [-----------] [-------------] [-----------] [-----------]/[--------( )-----|
 |                           |
 |     Pump                  |
 |-----] [-------------------+

 Rung 4 - trip lamp
     DryRunTrip                                                   TripLamp
 |-----] [------------------------------------------------------( )-----|
```

```iecst
(* Rung 1: DryRunTrip SET - pump was running when T-100 reached low-low *)
IF Pump AND NOT LevelLLOK_NC THEN
  DryRunTrip := TRUE;
END_IF;
(* Rung 2: DryRunTrip RESET - only once the level has recovered *)
IF ResetPB AND LevelLLOK_NC THEN
  DryRunTrip := FALSE;
END_IF;
(* Rung 3: P-101 run command *)
Pump := ((StartPB AND DischargeClosed) OR Pump)
        AND StopPB_NC AND OverloadOK_NC AND DestHighOK_NC
        AND LevelLLOK_NC AND NOT DryRunTrip;
(* Rung 4: trip lamp *)
TripLamp := DryRunTrip;
```

**How it behaves**, event by event:

| Event | What happens |
|---|---|
| Start pressed, discharge valve closed, all healthy | Pump starts and seals in |
| Start pressed with the discharge valve open | Nothing: permissive not met |
| Pump running, discharge valve opens | Pump keeps running: `DischargeClosed` is only in the start branch |
| T-200 reaches high | Pump stops. When the level drops, it stays off until Start is pressed |
| T-100 reaches low-low while running | Rung 1 sees `Pump` (from the last scan) and the low-low, and sets the trip. Rung 3 stops the pump in the same scan. The trip lamp lights |
| Reset pressed while still at low-low | Nothing: rung 2 needs `LevelLLOK_NC` TRUE (the trip is effectively set-dominant) |
| Level recovers, Reset pressed | Trip clears. The pump stays off: the reset only makes a restart **possible** |
| T-100 at low-low with the pump stopped, Start pressed | Nothing starts. No trip is latched either, because the pump wasn't running |

Two details are worth noticing. Rung 1 reads `Pump` before rung 3 writes it, so it uses the
value from the previous scan, and that is exactly what "was running" means. And
`LevelLLOK_NC` appears in both the trip and the main path. Without it in the main path, a pump
standing at low-low could be started, would run for one scan and would then trip.

This is basic process control. If running T-100 dry or overfilling T-200 were a safety or
environmental hazard, protection against it would be an independent safety function
([Module 20](../20-functional-safety/)).

### Worked example 3: reading vendor rungs

*A colleague sends you a rung from a Rockwell project as rung text, and the same idea from a
Siemens project as a screenshot description. Write each as IEC ladder and ST.*

**Rockwell rung text** (the text form Studio 5000 shows and exports; square brackets are a
branch, and commas separate its legs):

```text
XIC(AutoSel)[XIC(LevelLow) ,XIC(FillValve) ]XIO(LevelHigh)OTE(FillValve);
```

Read it left to right: examine `AutoSel` is 1; then a branch with two legs, `LevelLow` or
`FillValve`; then examine `LevelHigh` is 0; then energise `FillValve`.

```text
      AutoSel         LevelLow          LevelHigh                FillValve
 |-----] [------+------] [------+--------]/[--------------------( )-----|
 |              |               |
 |              |   FillValve   |
 |              +------] [------+
```

```iecst
FillValve := AutoSel AND (LevelLow OR FillValve) AND NOT LevelHigh;
```

It is a seal-in between two level switches. Note `XIO(LevelHigh)`: this program's high-level
switch is evidently wired so that TRUE means "high". Check the I/O list before you assume
anything, and ask whether a broken wire on that switch would be detected (it wouldn't: it would
read "not high").

**Siemens network**, described in words: a `-| |-` contact `"Auto"`, a `-| |-` contact
`"Start_Req"`, a `-|/|-` contact `"Fault"`, and a `-(S)-` coil `"Run_Cmd"`; a second network
with a `-| |-` contact `"Stop_Req"` in parallel with a `-| |-` contact `"Fault"`, driving a
`-(R)-` coil `"Run_Cmd"`.

```text
       Auto          Start_Req        Fault                      Run_Cmd
 |-----] [------------] [------------]/[------------------------(S)-----|

      Stop_Req                                                   Run_Cmd
 |-----] [------+-----------------------------------------------(R)-----|
 |              |
 |     Fault    |
 |-----] [------+
```

```iecst
IF Auto AND Start_Req AND NOT Fault THEN
  Run_Cmd := TRUE;
END_IF;
IF Stop_Req OR Fault THEN
  Run_Cmd := FALSE;
END_IF;
```

Questions to ask about it: the reset network comes second, so it is reset-dominant (good). Is
`Run_Cmd` in retentive memory (section 4.3)? And is `Run_Cmd` written anywhere else? Run the
cross-reference.

## Common mistakes and how to avoid them

| Mistake | Why it happens | How to avoid it |
|---|---|---|
| Programming an NC stop button with `--]/[--` | Copying the electrical schematic symbol for symbol | Contacts test bits. Decide when the contact must pass power, work out the bit value, and choose `] [` for 1, `]/[` for 0 (section 2) |
| Start-dominant motor rung | Putting the stop contact in the seal-in branch instead of the main path | Stops in series with the whole OR. Test "Start and Stop pressed together" |
| Interlock in the start branch | Treating a running interlock as a permissive | Ask of every condition: must it also stop a running motor? If yes, main path |
| The same bit written by two coils | Adding a new mode as a new rung at the bottom | Cross-reference before adding a coil. One bit, one writer. Combine the conditions on one rung |
| Mixing an ordinary coil with set/reset on one bit | Adding a quick latch to existing logic | Pick one mechanism per bit |
| Set rung after reset rung by accident | Rung order not treated as a design decision | Keep set and reset rungs together, reset last, and comment the dominance |
| A latched run bit restarts the plant after a power cut | Retentive latch (for example `OTL` on Rockwell, or a retentive `M` bit) | Seal-ins for motion. Reset latches on the first scan. Decide every retentive bit deliberately |
| Jog that seals in | The seal-in contact reads the output that the jog also drives | Seal an internal run bit. Drive the output from one rung: run OR jog |
| Relying on the software interlock alone for a reversing starter | "The program already prevents both" | Mechanical and electrical interlocks as well. The program can't see welded contacts or failed outputs |
| Travel limit that stops both directions | Putting both limits in both rungs | Each limit in its own direction's main path, so the other direction can drive away |
| Missing brackets when translating a branch to ST | `AND` binds more tightly than `OR` | Put brackets around every parallel branch |
| Trusting the name of a Siemens `SR`/`RS` box | IEC and Siemens use the names the other way round | The input marked 1 wins. Check the pin names |
| Rung comments that repeat the logic | Writing comments last, in a hurry | Comment the *why*: the requirement, the dominance, the reason for an unusual contact |

## Vendor notes

**Rockwell (Studio 5000 Logix Designer: ControlLogix, CompactLogix).** The bit instructions
are `XIC` (examine if closed, `--] [--`), `XIO` (examine if open, `--]/[--`), `OTE` (output
energise, `--( )--`), `OTL` (output latch) and `OTU` (output unlatch). One-shots are `ONS`,
`OSR` and `OSF` ([Module 06](../06-edges-and-one-shots/)). A rung can be viewed and edited as
**rung text** such as `XIC(A)[XIC(B) ,XIC(C) ]OTE(D);`, which is handy for documentation and
for bulk edits. Branches may be nested, and several outputs may sit in parallel. Every tag and
rung can carry a description or comment, and **Cross Reference** lists every use of a tag.
Verification warns of a duplicate destructive bit reference when a bit written by an `OTE`
is also written by another `OTE`, an `OTL` or an `OTU`. When the controller enters Run mode, the **prescan** clears bits written by `OTE` and
leaves `OTL`/`OTU` bits unchanged, so latched bits survive a power cycle (section 4.3). The
first-scan status bit is `S:FS`. There are no `SR`/`RS` boxes in Logix ladder: use
`OTL`/`OTU`, or `SETD`/`RESD` in FBD and ST. The Micro800 family, programmed with Connected
Components Workbench (CCW), follows IEC 61131-3 more closely, so its ladder and function
blocks look more like the rest of this course.

**Siemens (TIA Portal, S7-1200/S7-1500).** LAD programs are organised in **networks**, each
with a title and a comment. Bit logic: `-| |-` normally-open contact, `-|/|-` normally-closed
contact, `-|NOT|-` invert RLO (the *result of logic operation*, Siemens' name for the power
flow so far), `-( )-` assignment, `-(/)-` negated assignment, `-(S)-` set, `-(R)-` reset,
`SET_BF`/`RESET_BF` to set or reset a range of bits, and edge contacts and coils
([Module 06](../06-edges-and-one-shots/)). The `SR` box has inputs `S`/`R1` (reset-dominant)
and the `RS` box has `R`/`S1` (set-dominant), the opposite of the IEC names. Whether a bit
survives a restart depends on its memory area's retentive settings (Module 03). The
**cross-reference** list shows every use of a tag, and the **assignment list** gives an
overview of which inputs, outputs and memory bits are used.

**CODESYS (and CODESYS-based platforms).** Ladder is edited in CODESYS's combined FBD/LD/IL
editor. Contacts come in normal and negated forms, coils in normal, negated, set and reset
forms, and any function block (`SR`, `RS`, `TON`...) can be placed on a rung as a box. `SR`
(inputs `SET1`, `RESET`) and `RS` (`SET`, `RESET1`) follow IEC. Networks carry comments, the **Cross Reference List**
shows every use of a variable, and online mode shows live values directly on the contacts and
coils. Retentiveness follows the declaration: `VAR RETAIN` and `VAR PERSISTENT`.

**OpenPLC.** The long-established OpenPLC Editor is built on the open-source Beremiz/PLCopen
Editor, and its ladder editor works like this (newer releases may look different, but the
elements are the same IEC ones). You place the left and right power rails, then contacts
(normal, negated, rising edge, falling edge), coils (normal, negated, set, reset, rising
edge, falling edge) and blocks from the library, including `SR`, `RS` and the timers.
Variables, including located I/O such as `%IX0.0`, are declared in the POU's variable table.
The current Editor (v4) has a built-in simulator: run the program on your PC, change inputs
in the debugger and watch power flow through the rungs. When you build the project, the
Editor translates the diagram into Structured Text, the same language the course's `plctest`
runs. If your version lets you save that generated file, you can also test a ladder solution
with the lab's `.test` file
([Module 00](../00-start-here/#testing-ladder-you-drew-in-openplc-editor)). Treat the test
result, or a requirement-by-requirement check in the simulator, not the look of the diagram,
as the proof that the rung order and logic are right.

**Master control relay (MCR) zones.** Rockwell's `MCR` instruction, used in pairs, fences off
a zone of rungs. When the zone's condition is false, every rung inside it is executed as if it
were false: `OTE` outputs go off, while `OTL`/`OTU` bits keep their state. Rockwell's own
documentation states that the `MCR` instruction is **not** a substitute for a hard-wired master
control relay providing emergency-stop capability. Siemens offers a similar master control
relay function on some CPU families. IEC 61131-3 has no MCR. MCR zones make a rung's
behaviour depend on something outside the rung, so many coding standards discourage them:
put the condition on the rungs themselves.

## Labs

Run each lab from the `plc-course` folder. Copy the starter to your own folder first, as
described in [Module 00](../00-start-here/). Each starter compiles and fails its test until
you write the logic. For every lab, **sketch the ladder rungs on paper first**, then write the
ST. If you have OpenPLC Editor, draw the ladder there as well and prove each numbered
requirement in its simulator. If your Editor version can save the generated ST, run that
against the same test too (Module 00, *Testing Ladder you drew in OpenPLC Editor*). The
reference ladder for each lab is in a collapsed section at the end of the lab. Open it only
after your own solution passes.

### Lab 04-1: Start/stop from two stations

**Goal:** a stop-dominant seal-in with two start stations in parallel and two NC stop
stations in series, plus running and stopped lamps.

**Story.** Cooling-water pump P-301 can be started and stopped from a local control station
beside the pump and from the panel in the control room. Either station can start it, and
either can stop it. A stop at one station must win even if someone is holding Start at the
other. Both stop buttons are wired normally-closed.

**Interface** (use these names exactly):

| Tag | Address | Type | Description |
|---|---|---|---|
| `LocalStartPB` | `%IX0.0` | BOOL | Start at the local station, **NO**: TRUE while pressed |
| `LocalStopPB_NC` | `%IX0.1` | BOOL | Stop at the local station, **NC**: TRUE while **not** pressed (FALSE if pressed or the wire breaks) |
| `RemoteStartPB` | `%IX0.2` | BOOL | Start on the control-room panel, **NO**: TRUE while pressed |
| `RemoteStopPB_NC` | `%IX0.3` | BOOL | Stop on the control-room panel, **NC**: TRUE while **not** pressed |
| `Motor` | `%QX0.0` | BOOL | Pump motor contactor coil |
| `RunLamp` | `%QX0.1` | BOOL | "Running" lamp |
| `StoppedLamp` | `%QX0.2` | BOOL | "Stopped" lamp |

**Requirements:**

1. At power-up the motor is off, `RunLamp` is off and `StoppedLamp` is on.
2. Start at either station runs the motor, and it keeps running after Start is released.
3. Stop at either station stops the motor, whichever station started it. Releasing Stop
   does not restart it. A new Start press is needed.
4. Stop wins: with Stop pressed at either station, Start at either station (or both) does
   nothing, including a Start that is being held when Stop is pressed.
5. A broken wire on either stop circuit stops the motor and prevents starting from both
   stations.
6. `RunLamp` is on exactly when the motor is on and `StoppedLamp` exactly when it is off,
   **in the same scan** (write the lamps after the motor).

**Run the test:**

```bash
python3 tools/plctest.py 04-ladder-logic/labs/starter/04-1-start-stop-station.st      # watch it fail
mkdir -p my-work && cp 04-ladder-logic/labs/starter/04-1-start-stop-station.st my-work/
python3 tools/plctest.py my-work/04-1-start-stop-station.st 04-ladder-logic/labs/04-1-start-stop-station.test
```

<details>
<summary>Hint (open only if stuck)</summary>

One rung for the motor: three contacts in parallel (two starts and the seal-in), then two
contacts in series. Both stop contacts are **normally-open** instructions (`--] [--`, no
`NOT`), because each reads TRUE while its button is healthy and not pressed. The stopped lamp
is the one place in this lab where a normally-closed contact (`NOT`) is right. Why?
</details>

<details>
<summary>Reference ladder (open after your solution passes)</summary>

```text
     LocalStartPB     LocalStopPB_NC    RemoteStopPB_NC                  Motor
 |------] [-------+-------] [----------------] [------------------------( )-----|
 |                |
 |  RemoteStartPB |
 |------] [-------+
 |                |
 |      Motor     |
 |------] [-------+

        Motor                                                            RunLamp
 |------] [-------------------------------------------------------------( )-----|

        Motor                                                            StoppedLamp
 |------]/[-------------------------------------------------------------( )-----|
```

The ST version is in `labs/solutions/04-1-start-stop-station.st`.
</details>

### Lab 04-2: Forward/reverse motor with interlocks

**Goal:** a reversing starter with a software interlock, "stop before reversing", and travel
limit switches that stop only their own direction.

**Story.** A shuttle car carries drums between a filling station (forward end) and a storage
bay (reverse end). Its motor has a reversing starter with forward contactor `-K1` and reverse
contactor `-K2`, which are also mechanically and electrically interlocked in the panel
(section 6.3). The PLC provides the software interlock. At each end of the track an NC limit
switch stops the car. An overload relay protects the motor.

**Interface** (use these names exactly):

| Tag | Address | Type | Description |
|---|---|---|---|
| `FwdPB` | `%IX0.0` | BOOL | Forward push-button, **NO**: TRUE while pressed |
| `RevPB` | `%IX0.1` | BOOL | Reverse push-button, **NO**: TRUE while pressed |
| `StopPB_NC` | `%IX0.2` | BOOL | Stop push-button, **NC**: TRUE while **not** pressed |
| `FwdLimitOK_NC` | `%IX0.3` | BOOL | Forward end-of-travel limit switch, **NC**: TRUE while the car is **not** at the forward limit (FALSE at the limit or on a broken wire) |
| `RevLimitOK_NC` | `%IX0.4` | BOOL | Reverse end-of-travel limit switch, **NC**: TRUE while **not** at the reverse limit |
| `OverloadOK_NC` | `%IX0.5` | BOOL | Overload relay auxiliary contact, **NC**: TRUE while healthy (FALSE when tripped or on a broken wire) |
| `FwdK` | `%QX0.0` | BOOL | Forward contactor `-K1` coil |
| `RevK` | `%QX0.1` | BOOL | Reverse contactor `-K2` coil |

**Requirements:**

1. At power-up both contactors are off.
2. Forward starts forward travel and it seals in. Reverse does the same for reverse travel.
3. Stop stops either direction, and wins over either direction button. Releasing Stop
   restarts nothing.
4. `FwdK` and `RevK` are **never** on together, in any scan.
5. While the car runs in one direction, the other direction's button is ignored and the car
   carries on. To change direction the operator presses Stop, then the other button. (A
   button that is still held when the car stops at a limit is the one case this simple
   design misses. See section 6.4 and the untested exercise below.)
6. If both direction buttons are pressed together while the car is stopped, **neither**
   contactor switches on.
7. The forward limit stops forward travel and prevents a forward start while it is operated.
   Reverse is still allowed, so the car can drive away from the limit. The same applies to the
   reverse limit and reverse travel. A car that has just left a limit (switch still operated)
   keeps running.
8. After a limit stop the motor does not restart when the switch releases.
9. An overload trip stops the motor and prevents both directions. Resetting the overload
   restarts nothing.
10. A broken wire on any NC input has the same effect as that input operating.

**Run the test:**

```bash
python3 tools/plctest.py 04-ladder-logic/labs/starter/04-2-forward-reverse.st
python3 tools/plctest.py my-work/04-2-forward-reverse.st 04-ladder-logic/labs/04-2-forward-reverse.test
```

*Also do (not tested):* draw the hard-wired control circuit for `-K1` and `-K2` with the
auxiliary NC interlocks and the overload contact, and explain in two sentences what each of
the three interlock layers protects against that the other two don't. Then look at section
6.4's "held button" gap and work out whether your solution has it. (The reference solution
does. The fix needs [Module 06](../06-edges-and-one-shots/) or [Module 07](../07-timers/).)

<details>
<summary>Hint (open only if stuck)</summary>

Start from the two interlocked rungs in section 6.2. Add each limit to the **main path** of
its own direction only. For requirement 6, add a normally-closed contact of the *other*
direction's button to each **start branch**. Ask yourself why it must not go in the main path
(requirement 5: pressing the other button while running must not stop the car).
</details>

<details>
<summary>Reference ladder (open after your solution passes)</summary>

```text
       FwdPB       RevPB       StopPB_NC  OverloadOK_NC FwdLimitOK_NC    RevK          FwdK
 |------] [-------]/[-----+------] [----------] [------------] [----------]/[----------( )-----|
 |                        |
 |       FwdK             |
 |------] [---------------+

       RevPB       FwdPB       StopPB_NC  OverloadOK_NC RevLimitOK_NC    FwdK          RevK
 |------] [-------]/[-----+------] [----------] [------------] [----------]/[----------( )-----|
 |                        |
 |       RevK             |
 |------] [---------------+
```

The ST version is in `labs/solutions/04-2-forward-reverse.st`.
</details>

### Lab 04-3: Jog/run selector

**Goal:** a motor that can run continuously (sealed in) or be jogged (runs only while a button
is held), where the jog can never seal in.

**Story.** A packing-line conveyor has a JOG/RUN selector switch, Start, Stop and Jog
push-buttons. In RUN, operators start and stop the belt normally. In JOG, maintenance inch the
belt to track it or to clear a jammed carton. The "running" lamp tells the line leader the
belt is in continuous production, so it must stay off while jogging.

**Interface** (use these names exactly):

| Tag | Address | Type | Description |
|---|---|---|---|
| `StartPB` | `%IX0.0` | BOOL | Start push-button, **NO**: TRUE while pressed |
| `StopPB_NC` | `%IX0.1` | BOOL | Stop push-button, **NC**: TRUE while **not** pressed |
| `JogPB` | `%IX0.2` | BOOL | Jog push-button, **NO**: TRUE while pressed |
| `RunSel` | `%IX0.3` | BOOL | JOG/RUN selector: TRUE = RUN, FALSE = JOG |
| `OverloadOK_NC` | `%IX0.4` | BOOL | Overload relay auxiliary contact, **NC**: TRUE while healthy (FALSE when tripped or on a broken wire) |
| `Motor` | `%QX0.0` | BOOL | Conveyor motor contactor coil |
| `RunLamp` | `%QX0.1` | BOOL | "Running" lamp: on during continuous running only, **not** while jogging |

**Requirements:**

1. At power-up the motor is off, in either selector position.
2. In RUN, Start runs the motor and it seals in, and `RunLamp` is on. Stop stops it. The Jog
   button does nothing in RUN: it neither starts a stopped motor nor affects a running one.
3. In JOG, the motor runs only while Jog is held and stops the moment it is released,
   however long it was held. It never seals in, and `RunLamp` stays off. Start does nothing in
   JOG, even if it is held while jogging.
4. Turning the selector from RUN to JOG while running stops the motor. Turning it back to
   RUN does not restart it: a new Start is needed.
5. Turning the selector from JOG to RUN while jogging stops the motor, and nothing latches.
6. Stop wins over Start and over Jog in both positions, and a broken stop wire stops the
   motor and prevents both running and jogging.
7. An overload trip stops the motor and prevents running and jogging. Resetting the overload
   restarts nothing.

(Notice how the selector is used: a broken wire on `RunSel` reads as JOG, which stops
continuous running and leaves only hold-to-run motion. That is the safer failure.)

**Run the test:**

```bash
python3 tools/plctest.py 04-ladder-logic/labs/starter/04-3-jog-run.st
python3 tools/plctest.py my-work/04-3-jog-run.st 04-ladder-logic/labs/04-3-jog-run.test
```

<details>
<summary>Hint (open only if stuck)</summary>

Re-read section 6.7. You need an internal bit for continuous running (the starter gives you a
spare `VAR` block for it). Only that bit seals in, and `RunSel` goes in its main path. The jog
rung has no seal-in contact at all. `Motor` is written in exactly one place, from the run bit
OR the jog condition, and no rung reads `Motor` as a seal-in. `RunLamp` shows the run bit, not
the motor.
</details>

<details>
<summary>Reference ladder (open after your solution passes)</summary>

```text
      StartPB          RunSel      StopPB_NC   OverloadOK_NC                RunLatch
 |-----] [------+------] [-----------] [------------] [--------------------( )-----|
 |              |
 |   RunLatch   |
 |-----] [------+

       JogPB           RunSel      StopPB_NC   OverloadOK_NC                JogCmd
 |-----] [-------------]/[-----------] [------------] [--------------------( )-----|

      RunLatch                                                              Motor
 |-----] [------+----------------------------------------------------------( )-----|
 |              |
 |    JogCmd    |
 |-----] [------+

      RunLatch                                                              RunLamp
 |-----] [-----------------------------------------------------------------( )-----|
```

The ST version is in `labs/solutions/04-3-jog-run.st`.
</details>

### Lab 04-4: Tank fill valve with set/reset (optional)

**Goal:** use set and reset coils for "start at one switch, stop at another", choose the
dominance of two latches, and define the power-up behaviour.

**Story.** Buffer tank T-100 is topped up through inlet valve XV-100: a single-solenoid,
spring-return valve that fails closed. In AUTO the valve opens when the level falls to the low
level switch LSL-101, and closes when it rises to the high level switch LSH-102. The level must
be allowed to fall all the way back to LSL-101 before the valve opens again. The two switches
also check each other. The level cannot be below LSL-101 and above LSH-102 at the same time,
so if the switches say it is, one of them (or its wiring) has failed. That raises a latched
sensor fault, which keeps the valve closed until the switches agree and an operator has reset
the fault.

**Interface** (use these names exactly):

| Tag | Address | Type | Description |
|---|---|---|---|
| `AutoSel` | `%IX0.0` | BOOL | OFF/AUTO selector: TRUE = AUTO |
| `LevelAboveLow` | `%IX0.1` | BOOL | LSL-101: TRUE while the level is **above** the low switch (switch covered). FALSE = level low, or a broken wire |
| `HighLevelOK_NC` | `%IX0.2` | BOOL | LSH-102, **NC**: TRUE while the level is **below** the high switch. FALSE = high level, or a broken wire |
| `ResetPB` | `%IX0.3` | BOOL | Fault reset push-button, **NO**: TRUE while pressed |
| `FillValve` | `%QX0.0` | BOOL | XV-100 solenoid: TRUE = open |
| `SensorFault` | `%QX0.1` | BOOL | Amber lamp: level switches disagree (latched) |

**Requirements:**

1. In AUTO, the valve opens when `LevelAboveLow` goes FALSE. It stays open while the level
   rises past the low switch, and closes when `HighLevelOK_NC` goes FALSE. It stays closed while
   the level falls back below the high switch, until the low switch is uncovered again.
2. **Power-up behaviour.** The PLC keeps no memory of the valve across a restart. At power-up
   with the level between the switches the valve stays closed until the level reaches the low
   switch. At power-up in AUTO with the level already below the low switch it opens
   immediately. At power-up at high level it stays closed.
3. Selecting OFF closes the valve at once. Returning to AUTO with the level between the
   switches does not reopen it. With the level below the low switch it does.
4. The high switch always wins: whenever `HighLevelOK_NC` is FALSE the valve is closed. A
   broken wire on the high switch therefore closes the valve.
5. If `LevelAboveLow` is FALSE while `HighLevelOK_NC` is FALSE, in either selector position,
   `SensorFault` turns on and latches. While it is on, the valve is closed and cannot open,
   even if the level falls to the low switch.
6. The fault latch is **set-dominant**: pressing Reset while the switches still disagree
   does not clear it. Once they agree again, a press of Reset clears it. The reset itself
   never opens the valve, and normal AUTO rules then apply.
7. Program the valve with a **set** rung and a **reset** rung (in ST, an `IF` that only
   writes TRUE and an `IF` that only writes FALSE), and put them in the order that makes
   requirement 4 true. This one is a learning requirement: the test can't see how you wrote
   it.

After you finish, answer for yourself: what would change if `FillValve`'s latch were retentive
and the power failed during a fill? Is that better or worse for this tank? Who should decide?
(Section 4.3.)

**Run the test:**

```bash
python3 tools/plctest.py 04-ladder-logic/labs/starter/04-4-tank-fill.st
python3 tools/plctest.py my-work/04-4-tank-fill.st 04-ladder-logic/labs/04-4-tank-fill.test
```

This is a training exercise. Overfill protection that matters for safety or the environment
is an independent function, typically with its own high-high switch and final element
([Module 20](../20-functional-safety/)).

<details>
<summary>Hint (open only if stuck)</summary>

Four rungs, in this order. (1) An internal bit for "switches disagree": `NOT LevelAboveLow
AND NOT HighLevelOK_NC`. (2) The fault latch: an `SR` instance (IEC `SR` is set-dominant) or
a set rung followed by a reset rung that also requires the disagreement to be gone. (3) Set
the valve: AUTO and level low. (4) Reset the valve: high level, not AUTO, or sensor fault.
Rung 4 must come after rung 3. Why?
</details>

<details>
<summary>Reference ladder (open after your solution passes)</summary>

```text
   LevelAboveLow   HighLevelOK_NC                                  SwitchesDisagree
 |-----]/[--------------]/[---------------------------------------( )-----|

                           FaultLatch
                         +------------+
   SwitchesDisagree      |     SR     |                       SensorFault
 |------] [--------------|S1        Q1|-----------------------( )-----|
 |                       |            |
 |       ResetPB         |            |
 |------] [--------------|R           |
 |                       +------------+

      AutoSel      LevelAboveLow                                   FillValve
 |-----] [--------------]/[---------------------------------------(S)-----|

   HighLevelOK_NC                                                  FillValve
 |-----]/[--------+-----------------------------------------------(R)-----|
 |                |
 |    AutoSel     |
 |-----]/[--------+
 |                |
 |   SensorFault  |
 |-----] [--------+
```

Notice the contacts on the NC-wired high switch: `--]/[--` in the reset rung, because the
valve must close when the bit is 0 (high level). The ST version is in
`labs/solutions/04-4-tank-fill.st`.
</details>

## Check your understanding

1. A colleague converts a relay panel and draws the stop button in the motor rung as
   `--]/[-- StopPB_NC`, exactly as it appears on the schematic. Describe what the motor does
   (a) in normal operation, (b) when Stop and Start are pressed together, (c) after the stop
   button's wire breaks.
2. Write this rung as one line of ST, then say what `Out` is when `A`, `C` and `D` are TRUE and
   `B` and `E` are FALSE.
   ```text
          A              B                           E           Out
    |----] [------+-----] [------+------------------]/[---------( )----|
    |             |              |
    |             |      C       |
    |             +-----] [------+
    |                            |
    |      D                     |
    |----] [---------------------+
   ```
3. Draw `Alarm := Running AND NOT (PressureOK AND FlowOK);` as a ladder rung that uses only
   contacts on single bits.
4. `Motor := StartPB OR (Motor AND StopPB_NC);`. Is this stop-dominant or start-dominant?
   What happens if the stop button's wire breaks while someone holds Start? Give one kind of
   latch for which this dominance *is* the right choice.
5. A program has a set rung for `Pump` at rung 20 and a reset rung for `Pump` at rung 18. Both
   conditions are true in the same scan. What does the pump do? What would you change?
6. A Studio 5000 program starts a conveyor with `OTL(ConvRun)` and stops it with
   `OTU(ConvRun)`. The power fails while the conveyor is running. What can happen when power
   returns, and why? Give two ways to prevent it.
7. Operators report: "The agitator runs in manual but never in auto, and the auto rung shows
   all its contacts green online, but the coil isn't lit." What is the most likely cause, how do
   you confirm it, and how do you fix it?
8. A reversing starter's program already guarantees that `FwdK` and `RevK` are never TRUE in
   the same scan. Give three reasons why the panel still needs mechanical and electrical
   interlocks.
9. In a forward/reverse rung, someone moves `FwdLimitOK_NC` from the main path into the start
   branch. Which behaviour changes, and what physically happens at the end of the track?
10. You need a latch that is set by a trip condition and reset by a push-button, and the trip
    must win. In a CODESYS project you use `SR`. The same logic is being ported to TIA Portal.
    Which Siemens box do you use, and how do you check you've got it right?

<details>
<summary>Answers</summary>

1. The rung is `Motor := (StartPB OR Motor) AND NOT StopPB_NC`. (a) With Stop not pressed,
   `StopPB_NC` is TRUE, so `NOT StopPB_NC` is FALSE and the motor never starts. (b) Holding
   Stop and pressing Start runs the motor. Releasing Stop stops it, so Stop has become a run
   button. (c) With the wire broken, `StopPB_NC` is FALSE for good, so Start runs the motor and
   the stop button can no longer stop it. That is the most dangerous case. The correct contact
   is `--] [-- StopPB_NC`.
2. `Out := ((A AND (B OR C)) OR D) AND NOT E;`. With A, C and D TRUE and B and E FALSE:
   `B OR C` = TRUE, `A AND TRUE` = TRUE, `TRUE OR D` = TRUE, `NOT E` = TRUE, so `Out` is TRUE.
   Note the brackets: `E` is in series with the whole branch structure, including the `D` path.
3. De Morgan: `NOT (PressureOK AND FlowOK) = NOT PressureOK OR NOT FlowOK`. So
   `Alarm := Running AND (NOT PressureOK OR NOT FlowOK)`:
   ```text
         Running       PressureOK                        Alarm
    |-----] [------+-----]/[------+----------------------( )-----|
    |              |              |
    |              |     FlowOK   |
    |              +-----]/[------+
   ```
   (In Siemens LAD you could also draw the series pair followed by `-|NOT|-`.)
4. Start-dominant: `StartPB` bypasses the stop. With the stop wire broken, `StopPB_NC` is
   FALSE, but holding Start still runs the motor, and releasing Start stops it (the seal-in
   branch is broken). So the motor runs with no working stop for as long as Start is held.
   Set-dominance is right for trip, fault and alarm latches, where the fault condition must win
   over Reset.
5. Rung 18 (reset) writes FALSE, then rung 20 (set) writes TRUE. The last write wins, so the
   pump runs: the latch is set-dominant, so a stop that arrives together with a start is
   ignored. Move the reset rung after the set rung (keep them together, comment the
   dominance), or replace the pair with a stop-dominant seal-in.
6. On Logix, tag values survive the power cycle and the prescan leaves `OTL`/`OTU` bits
   unchanged. `ConvRun` comes back TRUE, and the conveyor can start by itself as soon as the
   controller is in Run. Prevention: use a seal-in with `OTE` (the prescan clears it), or unlatch
   `ConvRun` on the first scan (`S:FS`). Also check the controller's power-up mode and apply the
   machinery rule of no automatic restart.
7. A double coil: the agitator output is written by a second, later rung (the manual rung).
   In auto that rung is false and writes FALSE after the auto rung has written TRUE. Confirm
   with the cross-reference, which shows two destructive writes to the same tag. Fix: one rung
   that ORs the auto and manual conditions (with the shared interlocks in its main path), or
   separate request bits combined in one output rung.
8. Any three of these. A contactor takes tens of milliseconds to open and its arc must clear,
   so the other contactor could close into it after a quick changeover. A welded main contact
   leaves a contactor closed while the PLC thinks it is open. A shorted output, a forced output
   or a stuck interposing relay energises a coil regardless of the program. Someone can operate
   a contactor by hand. The program can't see any of these, but a mechanical interlock and
   auxiliary NC contacts in the coil circuits act on the real devices.
9. The limit then only prevents *starting* forward while the car is at the limit. A car that
   is already running forward seals in past the limit. The limit opens, but it is no longer in
   the main path, so `FwdK` stays on and the car runs into the mechanical end stop (or the
   hard-wired over-travel limit, if there is one).
10. You need **set**-dominance. In TIA Portal that is the `RS` box (inputs `R` and `S1`), whose
    `S1` input dominates. Connect the trip to `S1`. Check it by pin names, not by the box name
    (the input marked 1 wins), confirm in the instruction help, and test it: trip and reset
    TRUE together must leave the output TRUE.
</details>

## Further reading

- IEC 61131-3, the Ladder Diagram section: the standard's definitions of contacts, coils,
  power rails and network evaluation.
- Your vendor's instruction reference for its bit instructions (Rockwell: the Logix 5000
  general instructions reference; Siemens: the LAD bit logic instructions in the TIA Portal
  help; CODESYS: the online help for the LD editor and the Standard library's bistable
  blocks). Look up exactly what each coil does on prescan, at restart and in an MCR zone.
- A good motor-control textbook or a contactor manufacturer's application guide, for
  hard-wired reversing, jogging and multi-station circuits. Reading the hard-wired versions
  side by side with PLC ladder is the best way to fix the difference in your mind.
- [Appendix A](../appendices/A-vendor-cross-reference.md) for a side-by-side table of
  instruction names.

---

Previous: [03 — Numbers, Data Types and Addressing](../03-data-types-and-addressing/) · Next: [05 — Boolean Logic, Truth Tables and Function Block Diagram](../05-boolean-logic-and-fbd/)
