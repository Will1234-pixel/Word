# PLC Playground: Open, Simulate, Play

A ready-made OpenPLC project with **five small programs** that you can run in the OpenPLC Editor
simulator straight away. Nothing to type. Open it, press Play, click the contacts and watch
the logic work.

It was built and compiled with OpenPLC Editor 4.3.1. Each program's logic was also checked
with the course's automatic tests.

| Program | Language | What you'll see |
|---|---|---|
| **P1_StartStop** | Ladder | A motor that stays on after you let go of Start: the seal-in |
| **P2_Timers** | Ladder | A lamp that waits 3 s (on-delay) and a fan that runs on for 5 s (off-delay) |
| **P3_Flasher** | Ladder | A beacon flashing on its own, made from two timers |
| **P4_Counter** | Ladder | Bottles counted up to 5, then "box full" |
| **P5_TankLevel** | Structured Text | A tank level rising and falling between 20 % and 80 %, plotted live |

All five run at the same time, so you can switch between them while the simulator runs.

## 1. Get it and open it (2 minutes)

1. Download **[PLC-Playground.zip](PLC-Playground.zip)**: open the link on GitHub and click
   the download button (↓) or **View raw**. If you already have the whole repository on your
   PC, you can skip the zip and use the `PLC-Playground` folder next to this page.
2. Unzip it somewhere easy, for example `Documents\PLC-Playground`.
3. In **OpenPLC Editor** choose **File → Open Project** and select the **`PLC-Playground`**
   folder (the one that contains `project.json`).
4. In the project tree on the left, open **Programs → P1_StartStop**.

## 2. Start the simulator

1. Click the **Play** icon (**Start Simulator**) in the bar on the left of the editor. The
   first build takes about 5–10 seconds.
2. When it runs, the **Debugger** panel opens at the bottom with the program's variables.
3. The rungs come alive:
   - **green** means TRUE (power is flowing);
   - **blue** means FALSE;
   - a contact you have *forced* shows in a different shade, so you can see what you are
     overriding.

**To "press a button": click a contact while the simulator runs.** A small menu offers
**Force True**, **Force False** and **Release Force**.

- To press a button, choose **Force True**.
- To let go of it, choose **Force False**.
- **Release Force** hands the variable back to the program.

When you edit anything, click **Stop Simulator** and then **Start Simulator** again, so
your change is rebuilt.

## 3. Play

### P1_StartStop: the seal-in (the "hello world" of PLCs)

```text
      StartPB         StopPB_NC                          Motor
 |-----] [-----+-------] [---------------------------------( )-----|
 |             |
 |     Motor   |
 |-----] [-----+

      Motor                                              RunLamp
 |-----] [-----------------------------------------------( )-----|
```

1. Click **StartPB → Force True**. Power flows, and **Motor** and **RunLamp** turn green.
2. Click **StartPB → Force False**, which is you letting go of the button. **Motor stays
   on.** Power now flows through the **Motor** contact underneath StartPB: the motor is
   holding itself on. That is the seal-in.
3. Click **StopPB_NC → Force False**, which is pressing Stop. The motor drops out.
4. Click **StopPB_NC → Force True**, which is releasing Stop. The motor **does not**
   restart by itself. That is what you want on a real machine.

*Why does StopPB_NC start TRUE?* A real stop button is wired **normally closed**: it sends
TRUE while it is *not* pressed, and FALSE when pressed or when its wire breaks. So a broken
wire stops the motor too (fail-safe). Modules [02](../02-electrical-and-field-devices/) and
[04](../04-ladder-logic/) explain this.

**Try this:** force StartPB and StopPB_NC both TRUE, then force StopPB_NC FALSE. Who
wins, Start or Stop?

### P2_Timers: on-delay and off-delay

1. **DelayPB → Force True** and keep watching **DelayET** in the Debugger. It counts up
   towards 3 s, and at 3 s **DelayLamp** turns on.
2. **DelayPB → Force False**. The lamp goes off at once and DelayET resets.
3. Force DelayPB True again, but set it False *before* 3 s have passed. The lamp never comes
   on. An on-delay timer needs the input to stay on for the whole time.
4. **FanSwitch → Force True**. The **Fan** starts at once.
5. **FanSwitch → Force False**. The Fan **keeps running**, **RunOnET** counts, and after 5 s
   the Fan stops. That's an off-delay, like a bathroom extractor fan.

Real uses: an on-delay confirms a signal is genuine (a level that stays high for 3 s, not a
splash). An off-delay keeps a cooling fan running after a motor stops.
See [Module 07](../07-timers/).

### P3_Flasher: logic that runs by itself

Nothing to press. As soon as the simulator starts, **Beacon** flashes: half a second on,
half a second off.

How it works: **OnTimer** times the lit half, then **OffTimer** times the dark half. When
OffTimer finishes, OffDone (the `]/[` contact on rung 1) resets OnTimer, and the cycle
starts again. Watch the three rungs light up in turn.

- **Enable → Force False** stops the beacon. Release Force starts it again.
- **Try this:** stop the simulator, change `T#500ms` on the OnTimer to `T#200ms`, and start
  again. Now it's a short blink and a long pause.

### P4_Counter: counting bottles

1. Click **BottleSensor → Force True**, then **Force False**. That's one bottle passing the
   photo-eye. **Count** goes to 1.
2. Do it four more times. At 5, **BoxFull** turns on.
3. Holding BottleSensor TRUE doesn't count again, because the counter counts **changes**
   from FALSE to TRUE (edges), not how long the input is on. See
   [Module 06](../06-edges-and-one-shots/) and [Module 08](../08-counters/).
4. **ResetPB → Force True**, then **Force False**. Count goes back to 0.

### P5_TankLevel: a live process (Structured Text)

This program is written in **Structured Text**, which reads like a short recipe:

```iecst
IF Level <= StartLevel THEN          (* 20 %: tank low, start filling *)
  InletPump := TRUE;
ELSIF Level >= StopLevel THEN        (* 80 %: tank high, stop *)
  InletPump := FALSE;
END_IF;
```

The rest of the program pretends to be the tank. The pump adds water, and the open outlet
lets it out.

1. Start the simulator and open **P5_TankLevel**.
2. In the Debugger panel, **click `Level`** to add it to the chart. Set the range to 1 or
   2 minutes. You'll see a saw-tooth: the level falls to 20 %, the pump starts, the level
   climbs to 80 %, the pump stops, and so on.
3. Also plot **InletPump** and watch it switch at exactly those two levels.

That gap between 20 % and 80 % is called **hysteresis**. Without it the pump would switch on
and off every few seconds around a single setpoint and wear out.
See [Module 14](../14-analog-and-process-io/).

**Try this:** stop the simulator, change `StopLevel`'s initial value to `95.0` in the
variable table, and start again. The tank now overfills past 90 %, and **HighAlarm**
comes on.

## 4. Now build your own

The fastest way to learn is to change things and predict what happens *before* you
press Play:

1. **P1:** add a second Stop button (`StopPB2_NC`) in series with the first. Both must be
   healthy for the motor to run.
2. **P1:** add a **Jog** button that runs the motor only while it is held, without sealing in.
3. **P2:** make DelayLamp need 5 s instead of 3 s.
4. **P4:** make the box hold 12 bottles, and make BoxFull switch the (P1) Motor off.
5. **New program:** traffic lights, with red, then green, then amber, using three on-delay
   timers.

Each of these is a proper exercise in the course labs, with automatic tests:
[Module 04](../04-ladder-logic/) (start/stop, jog, forward/reverse),
[Module 07](../07-timers/) (star-delta, flasher, run-hours),
[Module 08](../08-counters/) (bottle packing) and
[Module 13](../13-sequential-control/) (traffic lights).

## Troubleshooting

- **Nothing turns green:** make sure the simulator is running (the Play button changes to
  Stop), and that you opened the program from the project tree.
- **A contact won't change:** it may still be forced from an earlier test. Click it and
  choose **Release Force**.
- **"Open Project" doesn't accept the folder:** select the folder that directly contains
  `project.json`, not the one above it.
- **You changed something and nothing happened:** click Stop Simulator, then Start
  Simulator. Every change needs a rebuild.

---

For maintainers: [`tools/openplc-playground/`](../tools/openplc-playground/) contains the
script that generated this project with the OpenPLC Editor's own rung-building code, and a
`plctest` version of the same logic with 25 behaviour checks.
