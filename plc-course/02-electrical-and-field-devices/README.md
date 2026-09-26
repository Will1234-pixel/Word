# 02 — Electrical Fundamentals and Field Devices

> **Level:** 1 — Foundations · **Time:** ~8–10 hours · **Prerequisites:** [Module 01](../01-what-is-a-plc/)

A PLC program is only as good as its understanding of what is at the other end of each wire.
Is that input TRUE because the pump is running, or because a contact is healthy? What
happens to the valve if the PLC stops, the 24 V fuse blows or the air fails? Why does a
proximity sensor that works on the bench stay "on" when wired to the plant's input card? Why
does the analog reading stop at 95 % on a long cable run through an intrinsically safe
barrier?

This module covers the electrical knowledge a PLC programmer needs: basic circuit
calculations, 24 V DC control, the devices on the output side (relays, contactors, motor
starters, drives, solenoid valves) and the input side (buttons, switches, sensors), fail-safe
design, reading drawings, analog signals, hazardous areas and electrical safety. It is not an
electrician's course, and it does not qualify you to work on electrical equipment. It will let
you read the drawings, talk to the electricians and instrument technicians as a colleague,
and write logic that fails safe.

> **Safety first.** Never work on or test live circuits unless you are trained, authorised and
> following your site's rules (isolation, lock-out/tag-out, permits). Everything in this module
> that describes wiring is for understanding, not an instruction to do the work. The labs are
> simulations and training exercises, never designs for real safety functions.

## Learning objectives

By the end of this module you should be able to:

- Use Ohm's law and the power formula to check coil currents, output loading, cable voltage
  drop and burden-resistor voltages.
- Explain why 24 V DC is the standard for control, and the role of power supplies, circuit
  protection and the 0 V reference.
- Describe relays, contactors, motor starters, interposing relays, coil suppression, drive
  signals and solenoid valves, including each valve type's fail position.
- Select and connect input devices correctly: PNP versus NPN, sinking versus sourcing, 2-wire
  versus 3-wire, light-operate versus dark-operate.
- Apply fail-safe principles (NC wiring, de-energise-to-trip, wire break = safe state) and
  program NC inputs correctly.
- Read electrical schematics, device designations, terminal and I/O drawings, loop diagrams,
  P&IDs and ISA-5.1 instrument tags.
- Explain 4–20 mA loops, the 250 Ω burden, loop-resistance budgets, HART, 0–10 V, RTDs and
  thermocouples.
- Explain zones and divisions, intrinsic safety, barriers versus isolators, and NAMUR
  line-fault detection, and what they mean for PLC logic.
- State the basic rules of electrical safety that apply to PLC work, including why a PLC
  output is never an isolation point.

## 1. Electrical basics for PLC people

### Voltage, current and resistance

- **Voltage** (V, volts) is the electrical "pressure" between two points. A 24 V DC supply
  holds its + terminal 24 V above its 0 V terminal.
- **Current** (I, amperes or amps, A) is the flow of charge through a circuit. It flows only
  around a complete loop: from the supply, through the load, and back. A broken wire anywhere
  in the loop stops it everywhere in the loop.
- **Resistance** (R, ohms, Ω) opposes current. A relay coil, a lamp, a length of cable and a
  250 Ω burden resistor all have resistance.

### Ohm's law and power

```text
   V = I x R          I = V / R          R = V / I
   P = V x I          P = I^2 x R        P = V^2 / R        (P in watts, W)
```

**Worked numbers.**

- *A relay coil.* A 24 V DC interposing relay coil is rated 0.5 W.
  I = P / V = 0.5 / 24 = 0.021 A (21 mA). Its resistance is R = V / I = 24 / 0.0208 ≈ 1150 Ω.
- *Can a transistor output drive this solenoid?* A 24 V DC solenoid valve coil is rated 8 W.
  I = 8 / 24 = 0.33 A. A transistor output rated 0.5 A per point can drive it. Now check
  the **group** rating as well. If eight such solenoids on one output group can be on
  together, that is 2.7 A, and many modules limit the total current per group of outputs
  (check the data sheet).
- *The 250 Ω burden resistor.* A 4–20 mA signal through 250 Ω gives
  V = 0.004 × 250 = **1 V** at 4 mA and V = 0.020 × 250 = **5 V** at 20 mA. That is the
  familiar 1–5 V signal. The resistor dissipates P = 0.02² × 250 = 0.1 W at 20 mA.
- *Voltage drop on a long cable.* A solenoid 100 m from the panel is fed through 200 m of
  conductor (out and back) of 1.5 mm² copper. Copper's resistivity is about 0.0172
  Ω·mm²/m at 20 °C, so R = 0.0172 × 200 / 1.5 = 2.3 Ω. At 0.33 A the drop is
  2.3 × 0.33 = 0.76 V, leaving about 23.2 V at the coil, which is fine. A 2 A load on the same
  cable would lose 4.6 V and see only about 19.4 V, which may be below the coil's minimum
  operating voltage.

### AC and DC

**Direct current (DC)** flows one way with a constant polarity: +24 V DC stays +24 V.
**Alternating current (AC)** reverses direction many times a second: 50 Hz in Europe and much
of the world, 60 Hz in North America. AC voltages are quoted as RMS (effective) values. A
230 V AC supply peaks at about 325 V (230 × √2).

### 24 V DC control, and legacy AC control

Modern control circuits almost always run at **24 V DC**:

- It is in the *extra-low voltage* band, so the shock risk at operator stations, sensors and
  push-buttons is far lower than with mains voltages.
- It suits electronics: PLC inputs and outputs, sensors, HMIs and network devices all use it.
- One supply standard across the panel simplifies design and spares.

You will still meet **AC control circuits**: 110–120 V AC is traditional in North America and
common in older installations elsewhere (for example 110 V AC from a control transformer), and
230 V AC control exists too. PLCs have AC input and output modules for these. The logic is
the same. The danger to the person working on them is not.

### Power supplies, circuit protection and the 0 V reference

- **Power supplies.** Switch-mode DIN-rail supplies convert the mains to 24 V DC. They are
  sized for the total load plus inrush currents plus a margin. Critical systems use two
  supplies with a redundancy module. Many designs feed the PLC and its I/O modules from a
  different supply, or at least a different protected circuit, than the field devices, so a
  field short circuit cannot reset the CPU.
- **Circuit protection.** Fuses, miniature circuit breakers (MCBs) and electronic circuit
  breakers protect the **cable** from overcurrent and limit the damage a short circuit can
  do. The 24 V distribution is usually split into several protected circuits (for example
  inputs, outputs, field instruments, each area of the machine) so one fault takes down only
  one part of the plant. A blown fuse on an input circuit makes every input on it read FALSE,
  which is one more reason for fail-safe wiring (section 4).
- **The 0 V reference.** Many plants connect the 0 V of the 24 V DC system to protective
  earth at one point (an *earthed* system). Others leave it floating and use an
  insulation-monitoring device to detect earth faults. Follow the site standard. In an earthed
  0 V system, the rule is to **switch the +24 V side and connect the other end of each load to
  0 V**. Then an earth fault on the switched wire shorts it to 0 V, so the protective device
  trips and the load drops out; the fault cannot switch the load on. If the load were
  instead switched on its 0 V side, an earth fault on the wire between load and switch would
  complete the circuit through earth and **energise the load**. This is one reason
  sourcing (PNP, positive-switching) outputs and sensors, wired to sinking inputs, are the
  norm in many regions (section 3).

## 2. Output-side devices

### Relays and contactors

A **relay** is an electrically operated switch. Current through its **coil** (terminals
A1/A2) creates a magnetic field that moves its **contacts**:

- a **normally-open (NO)** contact is open when the coil is de-energised and closes when it
  is energised;
- a **normally-closed (NC)** contact is closed when de-energised and opens when energised;
- a **changeover (CO)** contact has both.

"Normally" always means **in the de-energised (shelf) state**, not "during normal operation".
Section 4 comes back to this, because it causes endless confusion.

A **contactor** is a heavy-duty relay built to switch power circuits: motors, heaters, large
lighting loads. It has **main contacts (poles)** for the power circuit, usually marked
1/L1–2/T1, 3/L2–4/T2, 5/L3–6/T3, and **auxiliary contacts** for control and feedback. In the
standard numbering for auxiliary contacts, the second digit tells you the type: **x3–x4 is
NO, x1–x2 is NC** (13–14 is the first NO, 21–22 an NC, and so on). An auxiliary NO contact
wired back to a PLC input tells the program that the contactor really pulled in. That is
**feedback**, as opposed to the **command** the PLC sent (Module 07 shows how to detect
disagreement between the two).

### Suppressing the inductive kick

A coil stores energy in its magnetic field. When the current is switched off, the collapsing
field produces a voltage spike that can be many times the supply voltage. It arcs relay
contacts, can damage transistor outputs, and radiates interference into nearby signal
cables. The cure is a **suppressor** across the coil:

| Suppressor | Works on | Notes |
|---|---|---|
| **Diode** (freewheeling diode) | DC only; polarity matters | Very effective, but slows the drop-out of the relay or valve noticeably |
| **Diode plus Zener or TVS diode** | DC | Clamps the spike but allows faster drop-out |
| **RC snubber** (resistor and capacitor) | AC and DC | Common on AC contactor coils |
| **Varistor (MOV)** | AC and DC | Clamps above a set voltage; simple, but the voltage is not clamped as low |

Many contactors and relays accept plug-in suppressor modules, and terminal-block relays often
have one built in. PLC transistor outputs usually include some internal protection, but
suppressing the load at the coil is still good practice. Check the module manual.

### Interposing relays

An **interposing relay** sits between a PLC output and the real load. Use one when:

- the load needs more current than the output can give (a large contactor coil);
- the load uses a different voltage (a 230 V AC coil driven from a 24 V DC output);
- you want isolation between the PLC and a separate or external circuit;
- you want a cheap, replaceable part to take the wear of frequent switching instead of the
  PLC module;
- you need several contacts from one signal.

The costs are one more part that can fail, a few milliseconds of extra delay, and more wiring
to check.

### Motor starters

The simplest motor starter is **direct on-line (DOL)**: the motor is switched straight onto
the supply.

```text
   L1 L2 L3
    |  |  |
  [ short-circuit protection: fuses, MCB or motor-protective circuit breaker ]
    |  |  |
  [ contactor -Q1 main contacts ]  <-- coil A1/A2 switched by the PLC (via an interposing relay)
    |  |  |
  [ thermal overload relay -F2 ]   --> auxiliary contacts 95-96 (NC) and 97-98 (NO)
    |  |  |
      (M)   motor -M1
```

- The **overload relay** protects the motor from overheating by measuring its current.
  Thermal types use bimetal strips; electronic types measure the current directly. It is set
  to the motor's full-load current from the nameplate. It does not switch the power circuit
  itself: when it trips, it opens its **auxiliary NC contact 95–96** and closes its NO
  contact 97–98. Designs use these contacts in two ways. In a **hard-wired** arrangement,
  95–96 is in series with the contactor coil, so a trip drops the contactor even if the PLC
  output has failed on, and the PLC learns about the trip from 97–98 (or from an extra
  auxiliary contact, where the device has one). In a **PLC-monitored** arrangement, 95–96
  goes to a PLC input, which is TRUE while healthy so that a broken wire looks like a trip,
  and the program drops the contactor. Lab 02-1 and the I/O drawing in section 5 use the
  second arrangement. Always read the drawing: an input wired to 97–98 is TRUE when
  *tripped*, the opposite sense, and a broken wire on it goes unnoticed.
- A **motor-protective circuit breaker (MPCB)** combines short-circuit protection and
  thermal overload protection in one device with a manual on/off operator. Its auxiliary
  contacts can tell the PLC "switched on" and "tripped".
- Overload relays can be set to **manual or automatic reset**. Automatic reset combined with
  maintained (2-wire) control means the motor restarts on its own when the overload cools
  down. Unexpected restarts injure people, so manual reset is the normal choice.

**2-wire and 3-wire control.** These old terms describe the start/stop circuit, not the
sensor wiring. With **2-wire control**, a maintained contact (a switch, a float switch)
runs the motor directly, so the motor restarts by itself after a power cut. With
**3-wire control**, momentary Start and Stop buttons and a seal-in contact run it, and a power
cut drops the seal-in, so the motor stays off until someone presses Start. Your PLC seal-in
(`Motor := (StartPB OR Motor) AND StopPB_NC`) is the software version of 3-wire control. It
also stays off after a PLC restart, because non-retentive variables start FALSE.

**Star-delta starting** reduces the starting current of larger motors. The motor starts with
its windings connected in star, so each winding sees 1/√3 of the line voltage and the
starting current and torque fall to about one third of their direct-on-line values. After a
set time a second contactor arrangement switches the windings to delta for full running.
It needs three contactors (main, star and delta). The star and delta contactors must
**never** close together, which would short-circuit the supply, so they are interlocked
mechanically, electrically and in the program, with a short pause between them. Module 07
builds this sequence with timers. **Soft starters** and **variable-speed drives** are the
modern alternatives.

### Variable-speed drives (VFDs) from the PLC's point of view

A variable-frequency drive controls the speed of an AC motor. The PLC typically exchanges:

| Signal | Direction | Typical form |
|---|---|---|
| Run / stop command, direction | PLC to drive | digital outputs, or a control word over a network |
| Speed reference | PLC to drive | 0–10 V or 4–20 mA analog output, or over a network |
| Ready / running / at speed | drive to PLC | digital inputs, or a status word |
| Fault (often wired as "healthy") | drive to PLC | a relay contact; closed = healthy is the fail-safe choice |
| Actual speed or current | drive to PLC | analog inputs, or over a network |
| Fault reset | PLC to drive | digital output, or a control-word bit |

Stop and start the motor with the **run command**, not by switching the drive's mains supply,
and don't open a contactor between a running drive and its motor. Drive manuals usually
limit how often the mains may be switched. Drives also have a safety input, **Safe Torque
Off (STO)**, which is part of a safety function and is wired through safety-rated devices, not
the standard PLC (Modules 19 and 20). The network control and status words are covered in
Module 17.

### Solenoid valves and fail positions

A **solenoid valve** uses a coil to move a valve spool. It may switch a process fluid
directly, or, very often, it switches instrument air to the **actuator** of a larger process
valve. On a P&ID that on/off process valve is typically an **XV** (section 5).

- A **single-solenoid, spring-return** (monostable) valve is actuated while its coil is
  energised. When the coil is de-energised, for any reason, a spring returns it. Paired with a
  spring-return actuator, the process valve goes to its **fail position** whenever the signal,
  the 24 V supply or the air is lost. To hold the valve open, the PLC output must stay on for
  the whole time.
- A **double-solenoid** (bistable, detented) valve has two coils. A pulse on one coil moves
  the spool and it **stays there** when the coil is de-energised. Paired with a double-acting
  actuator (no spring), the process valve stays in its last position when power is lost:
  **fail last**. To close it, the PLC must actively energise the *close* coil. Switching the
  *open* coil off does nothing. The two coils should never be energised together. Depending
  on the valve, the result is undefined or one coil simply wins, so design it out.
- Three-position valves (with a closed or exhausted centre position) also exist, for example
  to stop a cylinder mid-stroke.

Fail positions are marked on P&IDs and valve data sheets: **FC** (fail closed), **FO** (fail
open) and **FL** (fail last or locked). Which is safe is a process question. A fuel valve is
normally fail closed, a cooling-water valve often fail open, and a vent valve often fail open.

The comparison matters so much that Lab 02-2 is about it:

| Event | Single-solenoid valve + spring-return actuator | Double-solenoid valve + double-acting actuator |
|---|---|---|
| Program switches its output(s) off | Valve goes to its fail position | **Nothing happens**: valve stays where it is |
| PLC goes to STOP (outputs off) | Fail position | Stays where it is |
| 24 V supply to the solenoids lost | Fail position | Stays where it is |
| Instrument air lost | Spring drives it to the fail position | Nothing holds it: position not guaranteed |
| How to close it | Switch the output off | Energise the close coil |

This is why **trips use spring-return valves with de-energise-to-trip solenoids**, and
double-solenoid valves are chosen where holding the last position matters more than going to
a defined state, such as some machine cylinders.

### Pilot lights and sounders

Pilot lights (almost always LEDs today) and sounders are simple outputs, but the colours of
lights carry meaning. IEC 60204-1, the machinery electrical standard, uses **red** for
emergency or dangerous conditions, **yellow** for abnormal conditions, **green** for normal,
**blue** for "action required" and **white** for other information. Industries have their
own conventions too. In many North American power and process plants, for example, red
means "running/energised" and green "stopped". Follow the site standard and don't mix
conventions in one plant. Push-button colours are specified too; the emergency stop is red on
a yellow background.

## 3. Input-side devices

### Push-buttons, contact blocks and selector switches

A push-button is an **operator** (the part you press) plus one or more **contact blocks**
clipped on behind it. Each block is NO or NC; blocks are often numbered x3–x4 for NO and
x1–x2 for NC, as on relays. Stop buttons use NC blocks and start buttons NO blocks
(section 4).

**Selector switches** have two or three positions, and each position can be maintained (it
stays) or spring-return (it comes back when released). A three-position HAND-OFF-AUTO
selector typically has two contacts: one closed in HAND, the other closed in AUTO, both open
in OFF. That is what the PLC sees in Lab 01-2.

### Emergency-stop buttons

An emergency stop (e-stop) has a red mushroom head on a yellow background and **latches** when
pressed: it stays pressed until it is deliberately released by twisting, pulling or with a
key. Its contacts are **NC with direct (positive) opening action**: pressing the head forces
the contacts apart mechanically, even if they are welded together. The emergency-stop function
is specified in ISO 13850.

An e-stop circuit is a **safety function**. It normally acts through a safety relay or
safety PLC that removes power from the hazardous motion directly (Module 20). The standard PLC
receives a *monitoring* signal, for example a contact from the safety relay, so the program
can drop its run commands and report which e-stop was pressed. The standard PLC's program is
never what makes the e-stop work.

### Limit switches

A mechanical limit switch has an actuator (lever, roller, plunger) operated by a moving part.
It detects end of travel, valve positions (open/closed limit switches ZSO/ZSC), or a guard
position. Versions with positive-opening NC contacts are used in safety applications. Being
mechanical, limit switches wear and need correct alignment. Many problems during
commissioning are a limit switch that is almost, but not quite, made.

### Proximity sensors

- **Inductive** sensors detect metal without contact, using a high-frequency field. Their
  range is short (millimetres to a few tens of millimetres) and is quoted for mild steel.
  Non-ferrous metals such as aluminium and copper are detected at a shorter distance, and the
  data sheet gives correction factors. *Flush* (embeddable) types can be mounted level with
  metal; *non-flush* ones reach further but need clear space around the face.
- **Capacitive** sensors detect almost any material, including plastics, liquids, powders and
  granules, and can often sense a level through a non-metallic tank wall. They have a
  sensitivity adjustment and can be fooled by moisture or build-up on the face.
- **Magnetic** (reed or Hall-effect) sensors clip onto pneumatic cylinders and detect a magnet
  in the piston.

### Photoelectric sensors

| Type | How it works | Strengths | Watch out for |
|---|---|---|---|
| **Through-beam** | Separate emitter and receiver facing each other; the object breaks the beam | Longest range, most reliable detection | Two devices to mount, align and wire |
| **Retro-reflective** | Emitter and receiver in one housing; light returns from a reflector | One device to wire, long range | Shiny objects can reflect the beam and look like "no object"; *polarised* versions reduce this |
| **Diffuse** (proximity) | The object itself reflects light back to the receiver | No reflector needed | Range depends on the object's colour and surface; *background suppression* versions ignore things behind the target |

Each type can be set to **light-operate (LO)**, where the output is ON when the receiver sees
light, or **dark-operate (DO)**, where the output is ON when it does not. Choose so that a
failure gives the safe reading. For example, a through-beam sensor detecting jams on a
conveyor could be set so its output is ON while the beam is *clear*. A jam, a dead emitter or
a broken wire then all read OFF, and all of them raise the alarm.

### Process switches

Process switches turn a process variable into an on/off signal: **pressure switches** (PSH,
PSL), **level switches** (float, vibrating fork, conductive, capacitive), **flow switches**
(paddle, thermal dispersion) and **temperature switches**. Each has a set point and a
differential (hysteresis), the gap between the switching point on a rising value and on a
falling value.

The contact of a process switch is described in its **shelf state**, with no process pressure
or level applied. A pressure switch's "NO" contact may therefore be closed for its whole
working life, because the pressure is normally above the set point. What matters for the PLC
is: *in which condition is the contact closed, and is that the healthy condition?*

### 2-wire and 3-wire DC sensors

A **3-wire** DC sensor has +24 V and 0 V supply wires and a separate output wire. The usual
colour code is brown (+), blue (0 V) and black (output). The output switches the load, here
the PLC input, like a transistor.

A **2-wire** sensor is wired in series with the load, like a switch, and must power itself
through the same two wires. That has two consequences:

- When OFF, it still passes a small **leakage (residual) current** to keep its electronics
  alive, typically in the region of a milliamp. Check the data sheet.
- When ON, it has a **voltage drop** of a few volts across it, so the input sees less than
  24 V.

The PLC input must see the leakage current as OFF. IEC 61131-2 defines digital input types
with different current thresholds, and some are specified to work with 2-wire proximity
sensors; the input module's data sheet says which type it is. If an input sees the leakage as
ON, or flickers, a **bleeder resistor** in parallel with the input can fix it.

**Worked example (assumed values).** A 2-wire sensor leaks up to 1.5 mA when OFF. The PLC
input behaves like a 4.7 kΩ resistor and needs less than 5 V to read OFF reliably. With the
sensor OFF, the leakage alone gives the input 1.5 mA × 4.7 kΩ ≈ 7 V, which is above the OFF
limit: the input may read ON or flicker. Add a 4.7 kΩ bleeder in parallel: the combined
resistance is 2.35 kΩ and the OFF voltage becomes 1.5 mA × 2.35 kΩ ≈ 3.5 V, now reliably OFF.
When the sensor is ON, the bleeder dissipates about 24² / 4700 ≈ 0.12 W, so a 0.5 W resistor
is comfortable. Better still, choose a sensor and input that are specified to work together.

### PNP and NPN, sourcing and sinking

This terminology confuses everyone at first. Hold on to one idea: **current must flow in a
loop, so one side must source (supply) current and the other must sink (return) it to 0 V.**

- A **PNP (sourcing, positive-switching)** sensor switches **+24 V** onto its output wire.
  Current flows *out of* the sensor, into the load.
- An **NPN (sinking, negative-switching)** sensor switches its output wire to **0 V**. Current
  flows from the load *into* the sensor.
- A **sinking input** module has its common connected to 0 V. Current flows *into* the input
  terminal, so it needs a device that *sources* current: a **PNP** sensor or a switch
  connected to +24 V.
- A **sourcing input** module has its common connected to +24 V. Current flows *out of* the
  input terminal, so it needs a device that *sinks* current: an **NPN** sensor or a switch
  connected to 0 V.

**A sinking input pairs with a PNP (sourcing) sensor. A sourcing input pairs with an NPN
(sinking) sensor.**

```text
  PNP (sourcing) sensor on a SINKING input

    +24 V o----------+
                     | brown
               +-----+-----+
               |    PNP    |  black                 PLC input card (sinking)
               |   sensor  |------->----------------o %IX0.0
               +-----+-----+  current flows INTO     |
                     | blue   the input terminal    [input circuit]
                     |                               |
     0 V o-----------+-------------------------------o common (to 0 V)


  NPN (sinking) sensor on a SOURCING input

    +24 V o----------+-------------------------------o common (to +24 V)
                     | brown                         |
               +-----+-----+                        [input circuit]
               |    NPN    |  black                  |
               |   sensor  |-------<----------------o %IX0.0
               +-----+-----+  current flows OUT OF  PLC input card (sourcing)
                     | blue   the input, into the sensor
     0 V o-----------+
```

Why vendors confuse matters: some documents describe "sink" and "source" from the point of view
of the module, some from the field device, and some use "positive/negative switching" or
"P-type/N-type" instead. Some modules can be wired either way depending on where the common
goes. **Always check the wiring diagram in the module manual:** where does the common go,
+24 V or 0 V?

Regional habits differ: PNP sensors with sinking inputs are the norm in Europe, NPN was
traditional in parts of Asia, and North American plants have both. There is also a fail-safe
argument in an earthed-0 V system. With PNP and a sinking input, an earth fault on the signal
wire pulls the input to 0 V, so it reads OFF. With NPN and a sourcing input, the same earth
fault connects the input to 0 V, which is exactly what the sensor does when it switches ON,
so the input reads ON.

### Digital output types

| | Relay | Transistor, sourcing (PNP, high-side) | Transistor, sinking (NPN, low-side) | Triac |
|---|---|---|---|---|
| **Loads** | AC or DC | DC only | DC only | AC only |
| **Current per point** | typically about 2 A | commonly 0.5 A (some more) | similar | typically around 0.5–1 A |
| **Switching speed** | slow, milliseconds | fast, well under 1 ms | fast | follows the AC half-cycle |
| **Life** | limited by contact wear (number of operations, worse with inductive loads) | effectively unlimited | effectively unlimited | effectively unlimited |
| **Notes** | isolated contacts; different voltages on different commons; not for rapid cycling | often short-circuit protected; check group limits | an earth fault on the load wire can switch the load ON in an earthed-0 V system | off-state leakage can keep small loads (LED lamps, small relays) glowing or pulled in; may need a minimum load |

The figures are typical ranges only. Check both the **per-point** and **per-group** (common)
current limits, and the derating at high panel temperature. Lamps, capacitive loads and AC
coils draw an inrush current well above their steady current when switched on.

## 4. Fail-safe design

### Normal state versus logic state

A device's NO/NC label describes its **shelf state**. The PLC input simply reads **TRUE when
current flows**. What matters is the combination:

| Device | Contact used | Input when healthy / not operated | Input when operated | Input with a broken wire | Broken wire looks like... |
|---|---|---|---|---|---|
| Start button | NO | FALSE | TRUE | FALSE | "not pressed": can't start (safe) |
| Stop button | NC | **TRUE** | FALSE | FALSE | "Stop pressed" (safe) |
| Overload relay 95–96 | NC | **TRUE** | FALSE (tripped) | FALSE | "tripped" (safe) |
| Low-pressure trip switch | closed while pressure healthy | **TRUE** | FALSE (low pressure) | FALSE | "low pressure" (safe) |
| High-level alarm switch wired NO | open while level normal | FALSE | TRUE (high) | FALSE | "level normal" (**unsafe**: the alarm is lost) |

The last row shows what not to do. A signal that stops, trips or alarms should be wired so
that the **healthy condition is the one that passes current**. Then any break in the
circuit, whether a pressed button, a broken wire, a loose terminal, a blown fuse or a failed
supply, produces the safe reading. This is the job the course's `_NC` suffix does: `StopPB_NC`
is TRUE when all is well.

In the program, **use a healthy-TRUE input directly** in the run condition:

```iecst
Motor := (StartPB OR Motor) AND StopPB_NC AND OverloadOK_NC;
```

There is no `NOT` in front of `StopPB_NC`. In Ladder, the physically NC stop button is
programmed with a **normally-open** contact instruction (`--] [--`, XIC), because the
instruction asks "is the input TRUE?". That surprises almost every beginner, and Module 04
treats it in depth.

### De-energise to trip

**De-energise-to-trip** means everything that must happen in a trip happens when power is
*removed*: solenoids are energised in normal operation and drop out to trip, and contactors
drop out to stop. Loss of power, a PLC stopping, a blown fuse or a broken wire all lead to the
tripped (safe) state. Most process shutdown systems work this way (Module 20).

The opposite, **energise-to-trip**, is used where a spurious trip would itself be dangerous or
very costly, fire and gas deluge systems being the classic example. It needs line monitoring
(so that a broken wire is detected) and very reliable power, because a failure otherwise
means the trip silently cannot happen.

### What fail-safe wiring does not cover

NC wiring makes **open-circuit** faults safe. It does not protect against every fault:

- a short circuit from +24 V onto an NC input's wire keeps it reading TRUE whatever the button
  does;
- a welded relay contact or a failed-short output transistor keeps a load energised;
- a stuck mechanical device (a jammed limit switch) gives a healthy reading that is wrong.

Safety systems deal with these through redundancy and diagnostics: two channels, test
pulses, mechanically linked (mirror) contacts on contactors, feedback monitoring. That is
Module 20 territory. For a standard PLC, fail-safe wiring is still the essential first step.

## 5. Reading electrical and instrument drawings

### Ladder-format schematics and IEC-style schematics

**North American ladder-format schematics** draw two vertical supply rails (for example L1
and L2 from a control transformer, or +24 V and 0 V) with the circuits as horizontal rungs
between them, numbered down the left side. Coils sit on the right. Next to each coil, a
**cross-reference** lists the line numbers where its contacts are used. On many drawings NC
contacts are marked in the list, for example underlined. Here is 3-wire start/stop control:

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

Read it as: *coil M on line 1 has contacts on lines 2 and 3.* This is an **electrical
drawing**: `]/[` here is the physical NC contact of the stop button and the overload relay.
The US tradition draws the overload contact on the right of the coil.

**IEC-style schematics** (the norm in Europe and in tools such as EPLAN) usually draw the
current paths vertically between horizontal supply rails at the top and bottom of each sheet.
The sheet is divided into numbered **columns**, and a cross-reference such as `/14.3` means
*sheet 14, column 3*. Under each coil a small **contact image** lists every contact of that
device and where it is used:

```text
     -Q1  contactor coil, sheet 12 column 3
     contact image:   1-2  /14.2     3-4  /14.3     5-6  /14.4      (main poles, power sheet)
                     13-14 /12.4    21-22 /15.1                     (auxiliaries)
```

Symbols differ too. IEC 60617 symbols draw a coil as a rectangle and contacts as switch blades,
and a lamp as a circle with a cross. North American (ANSI/IEEE and NFPA 79 style) drawings draw
a coil as a circle labelled with the device name (CR1, M), contacts as `| |` and `|/|`, and a
lamp as a circle with a letter for its colour. The logic is identical. Every good drawing set
has a **legend sheet**: read it first.

### Device designations

Every device on a drawing has a **reference designation** that is also printed on a label on
the real device. Conventions vary between countries, companies and decades, so treat this
table as examples and always check the project's legend:

| Device | Older IEC / DIN style (still very common) | Newer IEC 81346-2 style (examples) | US style (examples) |
|---|---|---|---|
| Contactor | -K1, -KM1 (French practice), or -Q1 | -QA1 | M, 1M |
| Control relay | -K1 | -KF1 | CR1 |
| Push-button, switch | -S1 | two-letter codes, check the legend | PB1, SS1 (selector switch) |
| Overload relay, fuse, breaker | -F1, -Q1 | two-letter codes, check the legend | OL, FU, CB |
| Motor | -M1 | two-letter codes, check the legend | MTR1 |
| Indicator lamp | -H1 | two-letter codes, check the legend | PL1, LT1 |
| Terminal strip | -X1 | two-letter codes, check the legend | TB1 |
| Solenoid (valve) | -Y1 | two-letter codes, check the legend | SOL1 |

IEC 81346 designations can also carry a **function** prefix `=` and a **location** prefix
`+`: `=PU01+CP1-Q1` reads "contactor Q1, of function PU01, located in panel CP1".

### Wire numbers, terminals and cross-references

- **Wire numbers** identify each conductor, marked at both ends with ferrules. Some schemes
  give every wire at the same potential the same number, and others number wires by line or
  by sheet and column. Knowing the scheme lets you find a wire in the panel from the drawing.
- **Terminal strips** (-X1:1, -X1:2, ...) are where field cables meet panel wiring. Some
  terminals are fused, and **disconnect (knife) terminals** let a technician open a circuit
  for testing without removing wires, which is very useful during loop checks.
- **Cross-references** link a coil to its contacts and a wire that continues on another
  sheet to its destination. Fault-finding is mostly following cross-references.

### PLC I/O drawings

Each I/O module has its own drawing showing every channel: the terminal, the PLC address, the
field device and its tag, the wire numbers, and where the channel's supply and common come
from. For a sinking 24 V DC input module:

```text
  PLC digital input module -A2 (slot 2), 16 x 24 V DC, sinking
  +24 V for the field devices from fused terminal -X10:1 (fuse -F10)

  Terminal  Address  Wire  Field device                          PLC tag
     1      %IX0.0   201   -S2  Start push-button (NO)             StartPB
     2      %IX0.1   202   -S1  Stop push-button (NC)              StopPB_NC
     3      %IX0.2   203   -F2  Overload relay, contact 95-96 (NC) OverloadOK_NC
     4      %IX0.3   204   spare
    ...
    20      common   0V    0 V (module common)
```

Reading this, you know that `StopPB_NC` is TRUE when healthy, that all three devices share
fuse -F10 (if it blows, the motor cannot start and running motors stop), and which terminals
to check with a meter.

### Loop diagrams

A **loop diagram** (the format is standardised in ANSI/ISA-5.4) shows one instrument loop from
end to end on one sheet: the field instrument, every junction box and terminal, cable and
core numbers, the marshalling, any barrier or isolator, and the I/O card channel, with
polarities and where the loop power comes from. You will read them as a chain, for example:

```text
  LT-301 (2-wire, 4-20 mA, Zone 1)
    (+) -- JB-301 TB1:1 -- cable C-301 pair 3 (+) -- isolator -A12 field terminal 1 (+, supplies loop power)
    (-) -- JB-301 TB1:2 -- cable C-301 pair 3 (-) -- isolator -A12 field terminal 2 (-)
  isolator -A12 output 7/8 (4-20 mA, safe area) -- PLC AI module -A5, channel 3 (+/-)
  PLC tag: LT301_Raw   range 0-4000 mm   alarms per the instrument index
```

When a loop check fails, the loop diagram tells you every point where you can measure.

### P&IDs and ISA-5.1 instrument tags

A **P&ID** (piping and instrumentation diagram) shows the process: vessels, pipes, pumps and
valves, plus every instrument and control function. Instruments are drawn as **bubbles**. In
ISA-5.1, a plain circle is a field-mounted instrument, and a circle with a horizontal line
through it is in the main control room, accessible to the operator. Functions in a shared
display and control system, such as a DCS, are drawn as a circle inside a square, and ISA-5.1
has further symbols for computer and PLC functions. Companies adapt these conventions, so
check the P&ID legend sheet. Each bubble carries a **tag**:

- The **first letter** is the measured or initiating variable: **A** analysis, **F** flow,
  **H** hand (manual), **L** level, **P** pressure, **T** temperature, **S** speed, **W**
  weight, **Z** position, and **X** "unclassified", widely used for on/off valves (XV).
- An optional **modifier** follows: **D** differential (PDT), **Q** totalise (FQ).
- The **succeeding letters** give the function: **T** transmit, **I** indicate, **C** control,
  **S** switch, **A** alarm, **E** primary element, **V** valve, **Y** relay/compute/convert,
  **G** gauge. **H** and **L** (and HH, LL) mean high and low.
- A **loop number** follows the letters, often with an area prefix.

| Tag | Meaning |
|---|---|
| FT-101 | flow transmitter |
| LT-301 | level transmitter |
| PT-205 / TT-205 / TE-205 | pressure transmitter / temperature transmitter / temperature element (RTD or thermocouple) |
| PDT-110 | differential pressure transmitter |
| FIC-101 | flow indicating controller (a PID loop, usually running in the DCS or PLC) |
| FV-101 | flow control valve (also written FCV) |
| LSHH-302 | level switch high-high (typically a trip) |
| PSL-120 | pressure switch low |
| XV-201 | on/off (block) valve; companies also use tags such as SDV or ESDV for shutdown valves |
| ZSO-201 / ZSC-201 | position switch open / closed on XV-201 |
| HS-201 | hand switch (a push-button or selector) |
| PSV-150 | pressure safety (relief) valve: mechanical, no PLC involved |

### I/O lists and instrument indexes

The **I/O list** is the controls engineer's master table: one row per signal, with the tag,
description, signal type (DI, DO, AI, AO), electrical type (24 V DC, 4–20 mA, NAMUR, ...),
range and engineering units, fail-safe state or wiring (NO/NC), PLC address or channel,
cabinet, and drawing references. The **instrument index** is the instrument engineer's
equivalent, one row per instrument, with data sheet and loop drawing references. The PLC
program's tag names, scaling and alarm limits all come from these documents, so keeping them
in step with the program is part of management of change (Module 01).

## 6. Analog signals

### 4–20 mA current loops

The most common analog signal in industry is a **4–20 mA current loop**. The transmitter
sets the current in the loop between 4 mA (0 % of range) and 20 mA (100 %):

```text
   I (mA) = 4 + 16 x (value in % / 100)          value (%) = (I - 4) / 16 x 100
```

For example, a level transmitter ranged 0–4000 mm sending 14 mA: (14 − 4) / 16 = 62.5 %, so
the level is 2500 mm. Why current and not voltage?

- **The current is the same everywhere in a series loop.** Cable resistance and terminal
  resistance cause voltage drops, but they don't change the current, so the signal arrives
  unchanged as long as the loop has enough voltage (see the budget below).
- **Noise immunity.** The loop is a low-impedance circuit, so interference picked up on the
  cable disturbs it much less than it would a high-impedance voltage signal.
- **Live zero.** 0 % is 4 mA, not 0 mA. A current near zero therefore means a broken wire,
  a failed transmitter or lost loop power. That is a fault the PLC can detect, not a valid
  reading. The NAMUR recommendation NE 43 builds on this. Transmitters signal their own
  faults by driving the current to 3.6 mA or below, or to 21 mA or above, while normal
  readings stay between about 3.8 and 20.5 mA. Module 14 turns this into PLC logic.

### Loop-powered (2-wire) and 4-wire transmitters

- A **2-wire (loop-powered)** transmitter draws its operating power from the loop itself.
  The same two wires carry power and signal. Something else in the loop provides the voltage:
  the AI card, an isolator or a separate loop supply. This is the most common type for
  pressure, temperature and many level transmitters.
- A **4-wire** transmitter has its own power supply (for example 24 V DC or mains) on
  separate wires and **drives** the 4–20 mA output itself. Many analysers and flowmeters are
  4-wire. A **3-wire** transmitter shares the 0 V between supply and signal.

**Active and passive inputs.** From the AI card's point of view, an **active** input (or
"input with loop supply") provides the loop power, and suits a 2-wire transmitter. A
**passive** input only measures a current driven by someone else, and suits a 4-wire
transmitter or an external loop supply. Two sources in the same loop fight each other, and
with no source at all the loop reads 0 mA. Vendors use "active" and "passive" from different
viewpoints (the transmitter's or the card's), so check the wiring diagram rather than
trusting the word.

### The 250 Ω burden resistor

A PLC or DCS measures a loop current by measuring the voltage across a precision resistor in
the loop. With **250 Ω**, 4–20 mA becomes exactly **1–5 V** (Ohm's law, section 1). That is
why 250 Ω resistors appear on so many loop drawings, often on a terminal next to a
voltage-input card. Many current-input cards have the resistor built in, with a value that
varies by card. Two more reasons for 250 Ω:

- **HART** communication (below) needs a minimum loop resistance, usually quoted as about
  230 Ω. A 250 Ω burden meets it.
- The accuracy of the measurement depends on the resistor, so precision resistors (for
  example 0.1 %) are used.

If a burden resistor is removed, say to fit a meter, the loop is broken and the signal is
lost. Loop designs often include test terminals so the current can be measured without that.

### Worked example: a loop-resistance budget

*A 2-wire level transmitter in a hazardous area is connected through a shunt-diode barrier
to a PLC input with a 250 Ω burden. Will it work?*

All the numbers here are **assumed for the example**. Take the real values from the data
sheets.

| Item | Assumed value |
|---|---|
| Loop supply | 24.0 V DC |
| Transmitter minimum terminal voltage | 12.0 V (from its data sheet) |
| Highest current the loop must carry | 22 mA (covers NE 43 fault currents of 21 mA and above) |
| Burden resistor | 250 Ω |
| Cable: 600 m route, 0.5 mm² copper, so 1200 m of conductor | 0.0172 × 1200 / 0.5 = 41.3 Ω |
| Shunt-diode barrier, end-to-end resistance | 300 Ω (from its data sheet) |

1. Voltage available for everything except the transmitter: 24.0 − 12.0 = **12.0 V**.
2. Maximum total loop resistance at 22 mA: 12.0 / 0.022 = **545 Ω**.
3. Actual loop resistance: 250 + 41.3 + 300 = **591 Ω**. That is too much.
4. Check it the other way. At 22 mA the resistances drop 0.022 × 591 = 13.0 V, leaving
   24.0 − 13.0 = 11.0 V for the transmitter, below its 12.0 V minimum. At 20 mA they drop
   11.8 V, leaving 12.2 V, which is just enough.

So the loop works over the normal range, but only just. The most current it can carry is
(24.0 − 12.0) / 591 ≈ 20.3 mA, so the transmitter **cannot signal over-range or its high
fault current** (21 mA or more): the reading sticks at about 102 % instead, and the upscale
fault alarm never works. With a little more resistance, a lower supply voltage or a
transmitter that needs more voltage, the ceiling drops below 20 mA and the reading saturates
below 100 %: the classic "the reading never gets above 95 %" problem. Options: a galvanically
isolated barrier that supplies the loop itself (check the voltage it guarantees at its field
terminals), a larger cable, or a higher supply voltage within the barrier's limits. A
lower-resistance input is only an option without HART, which needs its minimum loop
resistance. Without the barrier the loop would be 291 Ω, dropping only 6.4 V at 22 mA.

### HART

**HART** superimposes a digital signal on the 4–20 mA analog signal. It uses frequency-shift
keying: 1200 Hz for a 1 and 2200 Hz for a 0, at a low level. The tones average out to zero, so
the analog value is undisturbed. HART lets a handheld communicator, an asset-management system,
or a HART-capable AI card or isolator read and configure smart instruments: range,
damping, diagnostics, and secondary variables (a Coriolis flowmeter can report density and
temperature as well as flow). It needs that minimum loop resistance, and every barrier or
isolator in the loop must pass HART. Wireless versions exist. Module 17 covers it further.

### 0–10 V signals

**0–10 V** is common for drive speed references and some sensors. It is simple, but the
receiving input draws a little current, so long cables drop voltage and pick up noise. It
has **no live zero**: 0 V could be a genuine zero or a broken wire. A 2–10 V variant
restores a live zero. Use 0–10 V over short distances inside or near a panel, and prefer
4–20 mA for field signals.

### RTDs (Pt100)

A **resistance temperature detector (RTD)** is a resistor whose value rises with temperature.
The common industrial type, **Pt100**, is platinum with 100 Ω at 0 °C and about 138.5 Ω at
100 °C: roughly 0.385 Ω per °C (IEC 60751). Because the sensor is a resistance, **the cable
resistance adds to it**:

- **2-wire** connection: both lead resistances add to the reading. *Worked example:* 25 m of
  0.5 mm² copper per lead is 0.0172 × 25 / 0.5 = 0.86 Ω, so 1.72 Ω for the pair, which reads
  as 1.72 / 0.385 ≈ **4.5 °C too high**.
- **3-wire** connection: the input measures and cancels the lead resistance, assuming the
  leads are equal. This is the most common industrial connection.
- **4-wire** connection: separate wires carry the measuring current and sense the voltage,
  eliminating lead resistance. Used for the best accuracy.

RTDs connect to RTD input cards, or to a head-mounted transmitter at the sensor that sends
4–20 mA. Pt1000 (1000 Ω at 0 °C) sensors reduce the effect of lead resistance.

### Thermocouples

A **thermocouple** is two different metals joined at the measuring ("hot") junction. It
produces a small voltage, tens of microvolts per °C (about 41 µV/°C for the common type K),
that depends on the temperature **difference** between the hot junction and the point where
the thermocouple wires meet copper (the "cold" or reference junction). The input measures the
temperature at its terminals and adds it back: **cold-junction compensation**. Practical rules:

- Run **thermocouple extension or compensating cable** of the correct type all the way to the
  input. Ordinary copper cable in the middle creates extra junctions and errors.
- Observe polarity. Colour codes differ between the IEC and North American standards, so a
  cable colour that means + in one plant can mean something else in another.
- Types: **K** (general purpose, wide range), **J**, **T** (lower temperatures), **N**, and
  **R/S/B** (platinum types for very high temperatures).
- A broken thermocouple (**burnout**) can be configured to drive the reading upscale or
  downscale. Choose the direction that makes the process logic fail safe: upscale for a
  high-temperature trip, for example.

### Analog outputs to valve positioners

An AO card drives a 4–20 mA signal into a control valve's **positioner**, which moves the
valve until its position matches the signal. Which end of the range means "closed" is
configured in the positioner. The valve's fail action on loss of air comes from the
actuator's spring, and many positioners drive the valve to its fail position if the signal is
lost. Check the AO card's **maximum load resistance**: it must drive 20 mA (or more) through
the positioner's input, the cable and any isolator. Smart positioners support HART, and many
valves have a separate position transmitter (ZT) wired back to an AI for feedback.

In the PLC, analog values arrive as raw integers whose range depends on the card: for
example, Siemens modules use a nominal range of 0–27648. Module 03 covers the data types and
Module 14 the scaling, fault detection and alarms.

## 7. Hazardous areas for PLC people

Many process plants handle flammable gases, vapours or dusts. Equipment in those areas must
not ignite them. A PLC programmer rarely designs hazardous-area installations, but you will
read the drawings, you will see barriers and isolators in the loops, and some of your signals
will carry line-fault information.

### Zones and divisions

| System | Gas and vapour | Dust |
|---|---|---|
| **Zones** (IEC 60079 and most of the world) | **Zone 0**: explosive atmosphere present continuously or for long periods. **Zone 1**: likely to occur in normal operation occasionally. **Zone 2**: not likely in normal operation, and brief if it does occur. | Zones 20, 21, 22, with the same idea |
| **Classes and divisions** (traditional North American) | **Class I** (gases), **Division 1** (hazard can exist in normal operation) and **Division 2** (hazard not normally present) | Class II (dusts), Class III (fibres) |

The North American codes also allow the zone system. **Area classification** is done by
specialists and recorded on hazardous-area classification drawings. Equipment is also marked
with a **gas group** (IIA, IIB, IIC, with IIC the most easily ignited gases such as hydrogen)
and a **temperature class** (T1 to T6, with T6 the coolest surface temperature).

### Protection concepts

| Code | Concept | Idea |
|---|---|---|
| Ex d | Flameproof enclosure | An explosion inside the enclosure is contained and cannot ignite the surroundings |
| Ex e | Increased safety | Design measures prevent arcs, sparks and hot surfaces (terminal boxes, motors) |
| Ex i | Intrinsic safety (ia, ib, ic) | The circuit's energy is too low to ignite the atmosphere, even with faults |
| Ex p | Pressurisation | The enclosure is purged and kept at a positive pressure with clean air or inert gas |
| Ex m | Encapsulation | Parts that could ignite are sealed in compound |
| Ex t | Protection by enclosure (dust) | Dust is kept out and surface temperatures limited |

### Intrinsic safety

**Intrinsic safety (IS)** limits the voltage, current and power in the hazardous-area circuit,
and the energy stored in cable capacitance and inductance, so that neither a spark nor a hot
surface can ignite the atmosphere, even under specified fault conditions. It is the usual
method for instrument signals. An IS loop is a **system**: the field device (*intrinsically
safe apparatus*), the **associated apparatus** in the safe area (the barrier or isolator), and
the cable between them. The system is verified by comparing **entity parameters**. The
barrier's output values (Uo, Io, Po, and the allowed Co, Lo) must suit the field device's input
values (Ui, Ii, Pi, Ci, Li) plus the cable's capacitance and inductance. IS wiring is kept
segregated from other wiring and clearly identified, often with light-blue cable and
terminals.

### Shunt-diode barriers versus galvanic isolators

| | Shunt-diode (Zener) barrier | Galvanically isolated barrier (isolator) |
|---|---|---|
| **How it works** | Zener diodes divert excess voltage to earth, a resistor limits current, a fuse protects the diodes | Transformers or optocouplers isolate the field circuit from the safe-area circuit |
| **IS earth** | **Required**: a dedicated, high-integrity earth connection, because fault energy is diverted to earth | Not required |
| **Isolation** | None: the field circuit is referenced to the IS earth, which can create earth loops | Full isolation between field, safe-area and supply circuits |
| **Loop budget** | Adds series resistance (see the worked example) | Usually supplies the loop itself; states the voltage available at its field terminals |
| **Extras** | Passive, simple, compact, cheap | Needs power; can provide loop power, repeat 4–20 mA with HART, act as a switch amplifier for NAMUR sensors, detect line faults |

Isolators are widely used in new installations because they remove the IS earth
requirement and add features. Barriers remain common, especially in existing plants.

### NAMUR sensors and line-fault detection

A **NAMUR** sensor (the DC interface is standardised in IEC 60947-5-6) is a 2-wire sensor
that behaves like a variable resistance rather than a switch. Its **switch amplifier** (often
an IS isolator) supplies about 8.2 V through about 1 kΩ and measures the current:

```text
   loop current
       ^
       |   SHORT CIRCUIT   well above the ON band (threshold set by the amplifier)
       | - - - - - - - - -
       |   ON              above 2.1 mA
       | ----- 2.1 mA ----
       |   switching band  (hysteresis between the two thresholds)
       | ----- 1.2 mA ----
       |   OFF             below 1.2 mA
       | - - - - - - - - -
       |   OPEN CIRCUIT    a small fraction of a milliamp (threshold set by the amplifier)
       0
```

Because a healthy sensor always draws a small current when OFF and never a very large one
when ON, the amplifier can tell **four** conditions apart, not two: OFF, ON, open circuit
(broken wire) and short circuit. This is **line-fault detection (LFD)**. The exact fault
thresholds depend on the amplifier. "ON" here means the high-current state, which is not
necessarily "object present": an inductive NAMUR proximity sensor, for example, draws the
*low* current when metal is in front of it. The sensor data sheet and the amplifier's
normal/inverted setting decide what the PLC finally sees. Mechanical contacts can be used on NAMUR inputs too, if
fitted with a resistor network so that the amplifier still sees "healthy" currents.

The amplifier passes this to the PLC as a switching output plus a fault signal, or, on remote
I/O modules that accept NAMUR sensors directly, as a channel value plus diagnostic status bits.
On a fault, many amplifiers also force their switching output to a defined state. Check the
data sheet and its settings, including any normal/inverted mode switch.

**What this means for PLC logic.** On a line fault, the switching state **cannot be trusted**,
and a short circuit is especially nasty because it looks like the ON state. The program
should:

1. treat either fault as "signal invalid";
2. substitute the **safe value** for the signal (for a high-level switch: "high");
3. raise an alarm that stays latched until someone resets it after the fault has gone;
4. decide deliberately what the equipment does when the fault clears.

Lab 02-3 is exactly this.

### Earthing, screens and segregation

- **Protective earth (PE)** is for safety: it connects exposed metalwork to earth so that an
  insulation fault trips the protection instead of leaving the metal live.
- **Functional or instrument earth** ("clean earth") is a reference for signals and cable
  screens. It is kept separate from noisy power earths within the panel and bonded to the
  main earthing system at a defined point. Practices vary: follow the site earthing standard.
- **IS earth**, where Zener barriers are used, is a dedicated high-integrity connection.
- **Cable screens.** Analog instrument cables are commonly screened, with the screen earthed
  at one end only (usually the control-room end) to avoid earth-loop currents. Screens that
  must block high-frequency interference, such as on VFD motor cables and many industrial
  Ethernet and fieldbus cables, are bonded at both ends with 360° clamps, on a good
  equipotential bonding system. Follow the manufacturer's installation guidelines.
- **Segregation.** Route power, control, and instrument/signal cables separately, in
  separate trays or with specified spacing, crossing at right angles where they must cross.
  Keep VFD output cables well away from analog signals. IS cables are segregated from all
  non-IS wiring.

Poor earthing and segregation show up in the PLC as noisy analog values, spurious counts,
flickering inputs and communication errors, so they are worth recognising.

## 8. Electrical safety for PLC people

You will spend much of your career near live panels. The rules below are general. Your site's
rules and your country's regulations are what apply.

- **Competence and authorisation.** Only people who are trained, competent and authorised
  for that type of work work on electrical equipment. Titles and rules vary between countries
  and companies ("competent person", "authorised person", "qualified person"). Know yours.
- **Isolation and lock-out/tag-out (LOTO).** Before work, switch off at a proper **isolating
  device** (a disconnector or isolator designed for the purpose), lock it in the off position
  with your personal lock, and tag it. In the US this is regulated by OSHA's lockout/tagout rule
  (29 CFR 1910.147). In Europe EN 50110 covers the operation of electrical installations. In
  the UK the Electricity at Work Regulations apply.
- **Prove dead.** Test with an approved voltage indicator, and prove the indicator on a known
  live source **before and after** the test.
- **Other energy.** Isolation of the supply is not the end. Variable-speed drives keep a
  charged DC bus for minutes after isolation (wait the time on the drive's warning label and
  measure). Pneumatics and hydraulics store pressure, and springs, suspended loads and
  flywheels store mechanical energy.
- **More than one supply.** Panels often contain circuits fed from elsewhere: an interlock
  from another panel, a UPS-backed circuit, 230 V AC inputs powered from the field. Look for
  the warning labels and read the drawings.
- **Arc flash.** A fault in a high-energy panel can produce an arc flash that causes severe
  burns at a distance. In North America **NFPA 70E** sets out the risk assessment, labelling and
  PPE requirements. Other countries have their own regulations and guidance.
- **Wiring rules.** Installations follow wiring regulations such as **IEC 60364** (in the UK,
  **BS 7671**) or the **NEC (NFPA 70)** in the US, and machinery electrical equipment follows
  **IEC 60204-1** or **NFPA 79**.

### A PLC output is never an isolation point

An output that is OFF is **not** isolated. It can be switched on by a program change, an
online edit, a force from the programming software (Module 23), an HMI command, another task
in the PLC, or a failure: output transistors can fail short-circuit and relay contacts can
weld. Transistor and triac outputs also pass a small leakage current when off. The load
stays connected to its supply the whole time. **Isolate at the proper isolating device,
every time**, and never rely on "the PLC has it switched off" or a software interlock as a
safe method of work. The same applies to a CPU in STOP.

## Worked examples

### Worked example 1: from a drawing to PLC logic

*A transfer pump has a local Start button (-S2, NO), a Stop button (-S1, NC), a thermal
overload relay (-F2) and a low suction-pressure switch PSL-120 whose contact is closed while
suction pressure is healthy. The drawing shows the overload's 95–96 contact wired to a PLC
input, and the PLC switching contactor -Q1 through an interposing relay.*

Step 1: list the I/O and what each input reads when healthy.

| Tag | Device | Contact | Healthy reads | Fault or broken wire reads |
|---|---|---|---|---|
| `StartPB` | -S2 | NO | FALSE (TRUE while pressed) | FALSE |
| `StopPB_NC` | -S1 | NC | TRUE | FALSE |
| `OverloadOK_NC` | -F2 | NC | TRUE | FALSE |
| `SuctionOK` | PSL-120 | closed while healthy | TRUE | FALSE |
| `PumpRun` | output to -Q1 (via an interposing relay) | | | |

Step 2: write the logic. Every "healthy-TRUE" input goes straight into the run condition,
with no `NOT`:

```iecst
PumpRun := (StartPB OR PumpRun) AND StopPB_NC AND OverloadOK_NC AND SuctionOK;
```

Step 3: check each failure against the table. A broken wire on any of the three healthy-TRUE
inputs stops the pump. A broken Start wire only prevents starting. A pressure dip drops the
seal-in, so the pump does not restart by itself when pressure recovers.

Step 4: look for what the logic cannot cover. Here the overload acts only through the PLC.
If the output failed on (a welded interposing-relay contact or a shorted output transistor),
an overload would not stop the pump. Where that matters, the designer puts 95–96 in series
with the -Q1 coil instead (the hard-wired arrangement in section 2) and brings the trip to
the PLC on 97–98. The input is then TRUE when tripped, so it would get a name such as
`OverloadTripped` and be used with `NOT` in the run condition. The drawing decides which
logic is right.

One detail for later: if the operator holds Start (or the button sticks) when the suction
pressure recovers, this logic restarts the pump, because Start is read as a level, not a
press. Module 06 fixes that with edge detection.

### Worked example 2: choosing a sensor for an input card

*The panel has a 16-channel 24 V DC **sinking** input card with its common on 0 V. The stores
have inductive sensors in PNP and NPN versions, and an old 2-wire sensor. Which can be used?*

- A sinking input needs a device that sources current into it: the **PNP** sensor. Brown to
  +24 V, blue to 0 V, black to the input.
- The **NPN** sensor would switch the input to 0 V, which is where the common already is, so
  no current would flow and the input would never turn on. It needs a sourcing input.
- The **2-wire** sensor can work if the input type accepts its leakage and voltage drop.
  Check the input's specified OFF current against the sensor's leakage (see the bleeder
  resistor example in section 3).

### Worked example 3: which state is "safe"?

*A cooling-water valve on a reactor jacket is fail-open (FO). The PLC drives its
single-solenoid, spring-return pilot valve. What does the program have to do to close the
cooling water, and what happens if the PLC stops?*

A fail-open valve opens when de-energised, so the solenoid must be **energised to close**
the water. If the PLC stops, the fuse blows or the air fails, the valve opens and cooling is
maximised, which is the safe direction for an exothermic reaction. In the program, the output
is TRUE only when the logic positively wants the water shut, for example
`CoolingCloseSol := CoolingNotNeeded AND NOT HighTemp;`, and a new engineer should find a
comment that explains the inverted sense.

## Common mistakes and how to avoid them

| Mistake | Consequence | How to avoid it |
|---|---|---|
| Programming an NC stop input with `NOT` (or an NC contact in Ladder) | The machine runs only while Stop is pressed, or a broken wire starts it | Name NC inputs `..._NC`, and use them directly in the run condition |
| Wiring a trip or alarm switch so that the healthy state is "no current" | A broken wire hides the alarm or trip | Healthy = current flowing; check each row of the fail-safe table |
| Treating a double-solenoid valve like a single-solenoid one | "Close" does nothing; the valve stays open after a stop or power cut | Drive the close coil explicitly, never energise both coils, and choose spring-return valves for trips |
| Mixing up PNP/NPN and sinking/sourcing | Inputs that never switch, or a false ON on an earth fault | Sinking input + PNP sensor, sourcing input + NPN sensor; check where the common goes |
| Connecting a 2-wire sensor to an input that sees its leakage as ON | An input that is stuck on or flickers | Check the input type; use a bleeder resistor or a 3-wire sensor |
| Ignoring output group current limits | Output modules overheating or shutting down | Add up the loads that can be on together per group |
| No suppression on inductive loads | Arcing, output damage, electrical noise on signals | Suppress at the coil: diode for DC, RC or varistor for AC |
| Forgetting the loop budget on IS loops | Readings that saturate below 100 % and fault currents that never arrive | Do the budget at the maximum current, with data-sheet values |
| Using 0–10 V for long field runs | Offsets and noise; a broken wire reads as zero | Prefer 4–20 mA with live zero |
| Trusting a NAMUR or 4–20 mA value when the channel reports a fault | A short circuit reads as "dry" or "OK" | Substitute the safe value on any line fault, and alarm |
| Treating a PLC output or a CPU in STOP as an isolation | Unexpected energisation while someone is working | Isolate, lock, tag and prove dead at the proper isolating device |

## Vendor notes

**Siemens.** Digital input and output modules come in sinking and sourcing variants, and
European installations mostly use PNP sensors with sinking inputs. Analog input modules
deliver raw integers with a nominal range of 0–27648 for the rated range (for example
4–20 mA), with overrange and underrange values beyond that. With channel diagnostics
enabled, they report wire break and other faults. Siemens also makes NAMUR input modules for
its distributed I/O, which report open circuit and short circuit per channel, and HART-capable
analog modules. Output module behaviour when the CPU stops is set in the hardware
configuration (Module 01).

**Rockwell (Allen-Bradley).** Digital module catalogue numbers show the electrical type: for
the ControlLogix 1756 family, for example, sinking 24 V DC inputs and sourcing inputs are
different catalogue numbers, as are sourcing and sinking outputs. Read the module's wiring
diagram before connecting sensors. Logix analog modules can scale raw values to engineering
units in the module configuration, and they report channel faults (such as an open wire or
out-of-range signal) as status tags in the controller.

**CODESYS-based controllers.** The I/O system is configured in the device tree from the I/O
modules' device descriptions, including input filters, diagnostics and analog ranges. How raw
analog values are scaled depends on the module manufacturer (WAGO, Beckhoff, ifm, ...), so read
its documentation.

**OpenPLC.** Digital inputs and outputs map `%IX`/`%QX` addresses to the pins of the board or
PLC hardware that runs the Runtime, and analog inputs map to `%IW`. The electrical interface
(voltage levels, sinking or sourcing) is whatever that hardware provides. A Raspberry Pi's pins
are 3.3 V logic and must never be connected directly to 24 V signals. Use a proper input and
output interface board.

## Labs

### Lab 02-1: Fail-safe motor circuit

**Goal:** program a motor starter whose stop button and overload contact are wired
normally-closed, so that every open-circuit fault stops the motor, and make sure the motor
never restarts on its own.

A pump motor is started by contactor -Q1. The thermal overload relay -F2 is wired with its
95–96 NC contact to a PLC input, as on the I/O drawing in section 5. An amber lamp tells the
operator the overload has tripped.

**Interface** (use these names exactly):

| Tag | Address | Type | Description |
|---|---|---|---|
| `StartPB` | `%IX0.0` | BOOL | Start push-button -S2, **NO**: TRUE while pressed |
| `StopPB_NC` | `%IX0.1` | BOOL | Stop push-button -S1, **NC**: TRUE while **not** pressed (FALSE if pressed or the wire breaks) |
| `OverloadOK_NC` | `%IX0.2` | BOOL | Overload relay -F2 contact 95–96, **NC**: TRUE while healthy (FALSE if tripped or the wire breaks) |
| `Motor` | `%QX0.0` | BOOL | Motor contactor -Q1 coil (through an interposing relay) |
| `TripLamp` | `%QX0.1` | BOOL | Amber "overload tripped" lamp |

**Requirements:**

1. At power-up the motor is off.
2. Start runs the motor, and it keeps running after Start is released.
3. Stop stops the motor, and Stop wins if both buttons are pressed.
4. An overload trip stops a running motor immediately and prevents starting while tripped.
5. `TripLamp` is on whenever the overload input is not healthy, and off otherwise. It stays
   off for a normal stop.
6. When the overload is reset, the motor must **not** restart by itself. A new press of Start
   is needed, and a Start press made while the overload was tripped must not be
   "remembered".
7. A broken wire on either NC input must stop the motor. A broken overload wire also lights
   `TripLamp`.

**Run the test:**

```bash
python3 tools/plctest.py 02-electrical-and-field-devices/labs/starter/02-1-fail-safe-motor.st
```

Then copy the starter to `my-work/`, write the logic, and test your copy against
`02-electrical-and-field-devices/labs/02-1-fail-safe-motor.test`. For extra practice, draw the
rung in Ladder in OpenPLC Editor and notice which contact symbol you use for `StopPB_NC`.

<details>
<summary>Hint (open only if stuck)</summary>

Start from the Lab 00-1 seal-in. Where must the overload condition go so that it breaks the
seal-in and not just the start branch? Consider this version:
`RunReq := (StartPB OR RunReq) AND StopPB_NC; Motor := RunReq AND OverloadOK_NC;`. It stops the
motor on a trip. What happens when the overload is reset?
</details>

### Lab 02-2: Single-solenoid versus double-solenoid valves

**Goal:** drive two valve types from the same commands, and see why "switch the output off"
means completely different things for each.

A transfer line to a receiving tank has two on/off valves in series, installed at different
times. **XV-201** has a single-solenoid, spring-return pilot valve: fail closed. **XV-202**
has a double-solenoid pilot valve on a double-acting actuator: fail last. One pair of buttons
opens and closes the whole line. The receiving tank has a high-high level switch (LSHH),
wired NC, that must close the line.

**Interface** (use these names exactly):

| Tag | Address | Type | Description |
|---|---|---|---|
| `OpenPB` | `%IX0.0` | BOOL | "Open line" push-button, **NO**: TRUE while pressed |
| `ClosePB_NC` | `%IX0.1` | BOOL | "Close line" push-button, **NC**: TRUE while **not** pressed. Closing is the safe direction, so it is wired like a stop button. |
| `HighLevelOK_NC` | `%IX0.2` | BOOL | LSHH on the receiving tank, **NC**: TRUE while the level is **not** high-high (FALSE on high-high or a broken wire) |
| `XV201_Sol` | `%QX0.0` | BOOL | XV-201 solenoid (single, spring return): TRUE = open |
| `XV202_OpenSol` | `%QX0.1` | BOOL | XV-202 "open" coil |
| `XV202_CloseSol` | `%QX0.2` | BOOL | XV-202 "close" coil |

**Requirements:**

1. At power-up, XV-201's solenoid is off, and XV-202 is **driven closed** (`XV202_CloseSol`
   on). The PLC cannot know where XV-202 was left when the power failed.
2. Pressing Open (with Close not pressed and no high-high) opens both valves, and they stay
   open after Open is released.
3. Pressing Close closes both valves, and they stay closed after Close is released.
4. Close wins if both buttons are pressed.
5. XV-202 is driven with **maintained** signals: while the line is open `XV202_OpenSol` stays
   on, and while it is closed `XV202_CloseSol` stays on. The two XV-202 coils must **never**
   be on in the same scan.
6. A high-high level (`HighLevelOK_NC` FALSE) closes both valves as in requirement 3, and
   Open is ignored while it lasts.
7. When the high-high clears, the valves stay closed until Open is pressed again.
8. A broken wire on `ClosePB_NC` or `HighLevelOK_NC` closes the line.

This is a training exercise. A real high-high level protection that matters for safety or the
environment would be engineered as a separate safety function (Module 20) and would use a
spring-return, fail-closed valve.

**Run the test:**

```bash
python3 tools/plctest.py 02-electrical-and-field-devices/labs/starter/02-2-solenoid-valves.st
```

Then work on a copy in `my-work/`, tested against
`02-electrical-and-field-devices/labs/02-2-solenoid-valves.test`. Afterwards, answer for
yourself: if the PLC lost its 24 V output supply while the line was open, which valve would
close? Is the line then closed?

<details>
<summary>Hint (open only if stuck)</summary>

Work out one internal "line should be open" command with a seal-in, broken by Close and by the
high-high switch. Then derive the three outputs from it. For the double-solenoid valve, ask:
what must be energised to make it *close*? Pulsing the coils with timers (Module 07) is another
common practice. This lab asks for maintained signals.
</details>

### Lab 02-3: NAMUR level switch with line-fault detection

**Goal:** turn a switching signal plus open-circuit and short-circuit status bits into a
validated signal and a fault, substitute the safe value, and latch the fault for the
operator.

Tank T-301 is filled through inlet valve XV-301 (single solenoid, spring return, fail closed)
while the operator's Fill selector is on. A vibrating-fork level switch **LSH-301** with a
NAMUR output stops the filling at high level. It connects through an IS switch amplifier with
line-fault detection. The fork is set up fail-safe: in normal operation it is **dry and draws
the ON current**, so a dead sensor reads as "wet" (high level). The amplifier gives the PLC
the switching state plus two status bits.

**Interface** (use these names exactly):

| Tag | Address | Type | Description |
|---|---|---|---|
| `FillSel` | `%IX0.0` | BOOL | Fill selector: TRUE = the operator wants the tank filled |
| `SensorOn` | `%IX0.1` | BOOL | LSH-301 switching state: TRUE = NAMUR current in the ON band = fork **dry** (level below the switch) |
| `WireBreak` | `%IX0.2` | BOOL | Amplifier status: open circuit detected (TRUE = fault) |
| `ShortCircuit` | `%IX0.3` | BOOL | Amplifier status: short circuit detected (TRUE = fault) |
| `ResetPB` | `%IX0.4` | BOOL | Fault reset push-button, NO: TRUE while pressed |
| `InletValve` | `%QX0.0` | BOOL | XV-301 inlet valve solenoid: TRUE = open |
| `FaultLamp` | `%QX0.1` | BOOL | Amber "LSH-301 line fault" lamp |
| `LineFault` | (internal) | BOOL | Declared in the starter. TRUE while either line fault is present |
| `HighLevel` | (internal) | BOOL | Declared in the starter. Validated high level: TRUE when the level is high **or** the signal cannot be trusted |

**Requirements:**

1. `LineFault` is TRUE while `WireBreak` or `ShortCircuit` (or both) is TRUE.
2. `HighLevel` is TRUE when the fork reports wet (`SensorOn` FALSE) **or** `LineFault` is
   TRUE. On a line fault, ignore `SensorOn`: a short circuit makes it read "dry".
3. `FaultLamp` comes on as soon as `LineFault` is TRUE, even if `ResetPB` is held, and stays on
   (latched) after the fault clears, even a very brief one.
4. `ResetPB` turns `FaultLamp` off only when `LineFault` is FALSE. Pressing it while the fault
   is present does nothing, and the lamp stays on after the fault clears until Reset is
   pressed again.
5. `InletValve` is open only while `FillSel` is TRUE, `HighLevel` is FALSE **and** `FaultLamp`
   is off. A real high level closes it, and filling resumes by itself when the level falls
   (a process condition). A line fault closes it until the fault has gone and been reset
   (an equipment problem that needs a person to look at it).

This is a training exercise. LSH-301 is a control function. An independent high-high
protection layer would be engineered separately (Module 20).

**Run the test:**

```bash
python3 tools/plctest.py 02-electrical-and-field-devices/labs/starter/02-3-namur-line-fault.st
```

Then work on a copy in `my-work/`, tested against
`02-electrical-and-field-devices/labs/02-3-namur-line-fault.test`.

<details>
<summary>Hint (open only if stuck)</summary>

Write the four lines in the order the data flows: `LineFault`, then `HighLevel`, then
`FaultLamp`, then `InletValve`. The latch has the same shape as a seal-in, but the fault must
win over the reset: `FaultLamp := LineFault OR (FaultLamp AND NOT ResetPB);`. Why does that
already satisfy "reset only works when the fault has gone"?

One limitation to notice: this reset works on the *level* of the button. If Reset is held
down (or stuck) while a brief fault comes and goes, the lamp goes out as soon as the fault
clears, so the operator never sees it. Module 06 makes the reset act only on a new *press*
(an edge), which closes that gap.
</details>

## Check your understanding

1. A 24 V DC solenoid coil is rated 6 W. What current does it draw, and can a 0.5 A transistor
   output drive it? What else must you check?
2. Explain the difference between a device's "normally closed" contact and the PLC input
   being TRUE in normal operation. Use a low-pressure trip switch as your example.
3. A PNP proximity sensor is connected to an input module whose common is wired to +24 V.
   Will it work? Why or why not?
4. A 2-wire proximity sensor makes a PLC input flicker while the sensor is OFF. What is the
   likely cause and what are two remedies?
5. What happens to (a) a single-solenoid spring-return valve and (b) a double-solenoid valve
   when the PLC goes to STOP with all outputs off? Which one would you use for a process trip?
6. A 4–20 mA flow transmitter is ranged 0–120 m³/h. What current corresponds to 90 m³/h?
   What voltage appears across a 250 Ω burden at that flow? What does a reading of 0.5 mA
   tell you?
7. A 2-wire transmitter needs at least 11 V. The loop supply is 24 V, and the loop contains a
   250 Ω burden, 60 Ω of cable and a barrier of 340 Ω. Will it deliver 21 mA? Show the
   numbers.
8. Why can a short circuit on a NAMUR sensor's cable be more dangerous than an open circuit,
   and how does the PLC logic in Lab 02-3 deal with it?
9. What is the difference between a shunt-diode barrier and a galvanically isolated barrier,
   from the point of view of earthing and the loop budget?
10. An electrician asks you to "turn the conveyor output off in the PLC" so he can change a
    motor terminal box. What do you say?

<details>
<summary>Answers</summary>

1. I = P / V = 6 / 24 = 0.25 A, which is within a 0.5 A output's rating. Also check the group
   (common) current limit for all loads that can be on together, derating at the panel
   temperature, and that the coil has suppression (a diode for DC).
2. "Normally closed" describes the contact with no process pressure applied (shelf state). A
   low-pressure trip switch is wired so its contact is **closed while the pressure is
   healthy**, so the input is TRUE in normal operation and goes FALSE on low pressure **or**
   a broken wire. That is fail-safe: both give the trip.
3. No. With the common on +24 V the module is a sourcing input, and it needs a sinking (NPN)
   device. A PNP sensor also switches +24 V, so there is no voltage difference across the
   input and no current flows: the input never turns on. Use an NPN sensor or rewire the
   common (if the module allows) as a sinking input.
4. The sensor's OFF-state leakage current is enough to raise the input voltage above its OFF
   threshold. Remedies: use an input type specified for 2-wire sensors, add a bleeder resistor
   in parallel with the input (sized so the leakage gives less than the OFF voltage), or use a
   3-wire sensor.
5. (a) It goes to its fail position (for example closed), because the spring returns it when
   the coil de-energises. (b) It stays where it was, because de-energising a bistable valve
   does nothing. For a trip, use the single-solenoid spring-return valve with
   de-energise-to-trip.
6. 90 / 120 = 75 %, so I = 4 + 16 × 0.75 = **16 mA**. Across 250 Ω: 0.016 × 250 = **4.0 V**.
   0.5 mA is far below 4 mA (and below the NE 43 fault limit of 3.6 mA), so it is not a flow
   reading. It means a broken wire, lost loop power or a failed transmitter.
7. Total resistance 250 + 60 + 340 = 650 Ω. At 21 mA the drop is 0.021 × 650 = 13.65 V,
   leaving 24 − 13.65 = 10.35 V for the transmitter, below its 11 V minimum. So **no**. The
   maximum current it can drive is (24 − 11) / 650 = 20.0 mA: just enough for the normal range
   and nothing for fault signalling.
8. A healthy NAMUR sensor draws a higher current in its ON state. A short circuit draws a very
   high current, which, without line-fault detection, looks like ON. In Lab 02-3, ON means
   "dry", the permissive for filling, so an undetected short would keep filling a full tank.
   The logic treats a short (or open) circuit as a fault, substitutes the safe value
   (`HighLevel` TRUE), closes the valve and latches an alarm.
9. A shunt-diode barrier diverts fault energy to earth, so it needs a dedicated high-integrity
   IS earth, provides no isolation (earth loops are possible), and adds series resistance that
   must fit in the loop budget. A galvanic isolator needs no IS earth, isolates the circuits,
   usually supplies the loop itself with a stated field voltage, and often adds HART pass-through
   and line-fault detection.
10. No. A PLC output is never an isolation point. The output could be switched on by a program
    change, a force, an HMI command or a failed output, and the motor circuit remains connected
    to its supply. He must isolate at the motor's isolator or starter, lock it, tag it and
    prove dead, under the site's permit system.
</details>

## Further reading

- The data sheets and wiring diagrams for one PLC input module, one output module and one
  analog module of the platform you use: find the input type, the group current limits, the
  sink/source wiring and the analog raw value range.
- ISA-5.1 (instrumentation symbols and identification) and ISA-5.4 (instrument loop diagrams),
  for anyone who works with P&IDs and loop drawings.
- A manufacturer's application guide to intrinsic safety and to NAMUR switch amplifiers. The
  major IS interface manufacturers publish free, readable introductions.
- IEC 60204-1 (or NFPA 79 in North America) for the electrical equipment of machines.

---
Previous: [01 — What Is a PLC?](../01-what-is-a-plc/) · Next: [03 — Data Types and Addressing](../03-data-types-and-addressing/)
