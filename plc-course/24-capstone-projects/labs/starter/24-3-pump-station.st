(* Capstone 24-3: Wastewater pump station (wet-well lift station).
   Module 24 (Capstone projects). STARTER - the interface, the SCADA data
   types and the plant simulation are done for you. Write the control
   logic where it says TODO (add your own functions, function blocks and
   variables as you wish), then run:
     python3 tools/plctest.py 24-capstone-projects/labs/starter/24-3-pump-station.st
   Brief: 24-capstone-projects/24-3-pump-station.md *)

(* =====================================================================
   GIVEN TYPES - part of the project interface. Do not change them: the
   acceptance test and the SCADA register map depend on these names.
   ===================================================================== *)
TYPE
  (* Fault injection for the simulated level transmitter *)
  E_XmtrFault : (XmtrOK,          (* healthy: 4-20 mA follows the level  *)
                 XmtrWireBreak,   (* loop open: 0 mA                     *)
                 XmtrLow,         (* failed downscale: 3.5 mA            *)
                 XmtrHigh,        (* failed upscale: 21.5 mA             *)
                 XmtrFrozen);     (* output stuck at its present value   *)

  (* Setpoints. SCADA writes these (holding registers 40101-40108). The
     levels are integers in millimetres above the wet-well floor. *)
  ST_Config : STRUCT
    DutyStartMm      : INT := 1500;   (* lead pump starts at or above       *)
    DutyStopMm       : INT := 600;    (* lead pump stops at or below        *)
    AssistStartMm    : INT := 1900;   (* assist pump starts at or above     *)
    AssistStopMm     : INT := 900;    (* assist pump stops at or below      *)
    HighAlarmMm      : INT := 2200;   (* high-level alarm                   *)
    LowAlarmMm       : INT := 450;    (* low-level alarm and dry-run cut-out *)
    MaxStartsPerHour : INT := 6;      (* per pump, rolling 60 min; 0 = off  *)
    BalanceByHours   : BOOL := FALSE; (* FALSE = rotate lead each cycle,
                                         TRUE = lead = least run time      *)
  END_STRUCT;

  (* One pump in the SCADA interface (4 registers + 2 x 32-bit values) *)
  ST_PumpScada : STRUCT
    Status         : WORD;  (* bit 0 in Auto, 1 available, 2 run command,
                               3 running, 4 overload fault, 5 feedback fault,
                               6 start-limited *)
    Starts         : DINT;  (* total starts (rising edges of the running feedback) *)
    RunSeconds     : DINT;  (* total running time, s *)
    StartsLastHour : INT;   (* starts in the last 60 minutes *)
  END_STRUCT;

  (* The whole SCADA interface image *)
  ST_Scada : STRUCT
    StationStatus : WORD;   (* bit 0 level control, 1 float backup, 2 pumping,
                               3 any alarm active, 4 any alarm unacknowledged *)
    AlmActive     : WORD;   (* one bit per alarm, see the brief *)
    AlmUnack      : WORD;   (* same bits: alarm not yet acknowledged *)
    LevelMm       : INT;    (* measured level, mm (0-4000) *)
    LeadPump      : INT;    (* 1-3: pump that leads this cycle / the next cycle *)
    PumpsRunning  : INT;    (* number of running feedbacks *)
    Pump          : ARRAY[1..3] OF ST_PumpScada;
    CmdAck        : BOOL;   (* SCADA command: acknowledge alarms (PLC clears it) *)
    CmdReset      : BOOL;   (* SCADA command: reset faults (PLC clears it) *)
  END_STRUCT;
END_TYPE

(* =====================================================================
   GIVEN PLANT SIMULATION - do not change.
   FB_WetWellSim models the wet well, the three pumps and the level
   instruments well enough to test the control logic. It also records
   "observer" statistics that the acceptance test uses as an independent
   referee (for example, did any pump ever run dry?).

   The program calls it once per scan with the pump run commands, and
   copies its outputs into the input image. The test drives it by writing
   its inputs directly (set Sim.InflowLps 20.0, set Sim.Trip2 TRUE, ...).

   Model:
   - Wet well plan area 4.0 m2, so 1 m of level = 4000 L (1 cm = 40 L).
   - Level transmitter 0-4.00 m = 4-20 mA. The analog card reads
     4 mA = 0 and 20 mA = 27648 counts (1728 counts per mA) and clips at
     -4864 and 32511. A healthy transmitter stays within 3.8-20.5 mA.
   - Floats (with 5 cm switching differential):
       low float    wet at >= 0.40 m, dry at <= 0.35 m
       high float   trips at >= 2.50 m, resets at <= 2.45 m (NC contact)
       HH float     trips at >= 2.80 m, resets at <= 2.75 m (NC contact)
   - Station outflow: 1 pump 25 L/s, 2 pumps 40 L/s, 3 pumps 48 L/s
     (the rising main limits parallel pumping). The flow falls to zero as
     the level drops from 0.25 m (minimum submergence) to 0.10 m.
   - A pump gives its running feedback 0.5 s after its run command, unless
     it is tripped (TripN) or will not run (NoRunN). The feedback drops as
     soon as the command drops or the pump trips.
   - Above 3.20 m the well spills to the emergency overflow.
   - The level is integrated in fixed 0.1 s steps, independent of the
     task interval.
   ===================================================================== *)
FUNCTION_BLOCK FB_WetWellSim
  VAR_INPUT
    Run1 : BOOL;                 (* run commands from the PLC outputs *)
    Run2 : BOOL;
    Run3 : BOOL;
    InflowLps : REAL := 0.0;     (* sewage inflow to the well, L/s *)
    Trip1 : BOOL;                (* fault injection: overload relay tripped *)
    Trip2 : BOOL;
    Trip3 : BOOL;
    NoRun1 : BOOL;               (* fault injection: pump will not run and *)
    NoRun2 : BOOL;               (* gives no feedback (e.g. contactor coil  *)
    NoRun3 : BOOL;               (* open circuit)                           *)
    XmtrFault : E_XmtrFault := XmtrOK;  (* fault injection: transmitter *)
  END_VAR
  VAR_OUTPUT
    (* field signals, copied to the PLC input image *)
    LevelRaw : INT;              (* analog input, counts *)
    LowFloatWet : BOOL;          (* TRUE = low float submerged *)
    HighFloat_NC : BOOL := TRUE; (* FALSE = high float tripped *)
    HHFloat_NC : BOOL := TRUE;   (* FALSE = high-high float tripped *)
    Running1 : BOOL;             (* running feedbacks *)
    Running2 : BOOL;
    Running3 : BOOL;
    OverloadOK1_NC : BOOL := TRUE;  (* FALSE = overload tripped *)
    OverloadOK2_NC : BOOL := TRUE;
    OverloadOK3_NC : BOOL := TRUE;
    (* process state: a test may SET Level to jump to a new level *)
    Level : REAL := 1.0;         (* true level above the well floor, m *)
    OutflowLps : REAL;           (* pumped flow, L/s *)
    (* observer statistics, for the tests *)
    PumpsRunning : INT;          (* pumps running now *)
    MaxPumpsRunning : INT;       (* most pumps ever running together *)
    Starts1 : DINT;              (* starts seen per pump *)
    Starts2 : DINT;
    Starts3 : DINT;
    MaxStartsInHour : INT;       (* most starts of one pump in any 60 min *)
    DryRunS : REAL;              (* s that a pump ran below 0.25 m *)
    SpillL : REAL;               (* litres spilled to the overflow *)
    MinLevel : REAL;             (* lowest and highest true level seen *)
    MaxLevel : REAL;
  END_VAR
  VAR CONSTANT
    AREA_M2 : REAL := 4.0;
    SPAN_M : REAL := 4.0;
    COUNTS_PER_MA : REAL := 1728.0;
    OVERFLOW_M : REAL := 3.20;
    SUBMERGENCE_M : REAL := 0.25;
    SUCTION_M : REAL := 0.10;
    LOW_WET_M : REAL := 0.40;
    LOW_DRY_M : REAL := 0.35;
    HIGH_TRIP_M : REAL := 2.50;
    HIGH_RESET_M : REAL := 2.45;
    HH_TRIP_M : REAL := 2.80;
    HH_RESET_M : REAL := 2.75;
    STEP_TIME : TIME := T#100ms;
    STEP_S : REAL := 0.1;
    START_DELAY : TIME := T#500ms;
    HOUR_STEPS : DINT := 36000;  (* 60 min in 0.1 s steps *)
  END_VAR
  VAR
    Clock : TON;
    LastET : TIME;
    DeltaT : TIME;
    StepAcc : TIME;
    Steps : DINT;
    Started : BOOL;
    Cmd : ARRAY[1..3] OF BOOL;
    Trip : ARRAY[1..3] OF BOOL;
    NoRun : ARRAY[1..3] OF BOOL;
    Runs : ARRAY[1..3] OF BOOL;
    WasRunning : ARRAY[1..3] OF BOOL;
    StartAcc : ARRAY[1..3] OF TIME;
    StartCount : ARRAY[1..3] OF DINT;
    StartStamp : ARRAY[1..3, 0..31] OF DINT;
    NextStamp : ARRAY[1..3] OF INT;
    Flow : REAL;
    mA : REAL;
    HeldmA : REAL;
    i : INT;
    k : INT;
    n : INT;
    InHour : INT;
  END_VAR

  (* --- time since the previous call (IEC has no system clock function) --- *)
  Clock(IN := TRUE, PT := T#24h);
  DeltaT := SUB_TIME(Clock.ET, LastET);
  LastET := Clock.ET;
  IF Clock.Q THEN                 (* re-arm once a day *)
    Clock(IN := FALSE);
    LastET := T#0s;
  END_IF;
  IF NOT Started THEN
    Started := TRUE;
    MinLevel := Level;
    MaxLevel := Level;
    HeldmA := 4.0 + 16.0 * Level / SPAN_M;
  END_IF;

  Cmd[1] := Run1;    Cmd[2] := Run2;    Cmd[3] := Run3;
  Trip[1] := Trip1;  Trip[2] := Trip2;  Trip[3] := Trip3;
  NoRun[1] := NoRun1; NoRun[2] := NoRun2; NoRun[3] := NoRun3;

  (* --- pumps and their feedback --- *)
  n := 0;
  FOR i := 1 TO 3 DO
    IF Cmd[i] AND NOT Trip[i] AND NOT NoRun[i] THEN
      IF StartAcc[i] < START_DELAY THEN
        StartAcc[i] := ADD_TIME(StartAcc[i], DeltaT);
      END_IF;
    ELSE
      StartAcc[i] := T#0s;
    END_IF;
    Runs[i] := StartAcc[i] >= START_DELAY;
    IF Runs[i] THEN
      n := n + 1;
    END_IF;
    IF Runs[i] AND NOT WasRunning[i] THEN
      (* observer: count the start and the starts in the last 60 min *)
      StartCount[i] := StartCount[i] + 1;
      StartStamp[i, NextStamp[i]] := Steps;
      NextStamp[i] := (NextStamp[i] + 1) MOD 32;
      InHour := 0;
      FOR k := 0 TO 31 DO
        IF INT_TO_DINT(k) < StartCount[i] AND Steps - StartStamp[i, k] < HOUR_STEPS THEN
          InHour := InHour + 1;
        END_IF;
      END_FOR;
      MaxStartsInHour := MAX(MaxStartsInHour, InHour);
    END_IF;
    WasRunning[i] := Runs[i];
  END_FOR;
  PumpsRunning := n;
  MaxPumpsRunning := MAX(MaxPumpsRunning, n);

  (* --- wet-well level, fixed 0.1 s integration steps --- *)
  StepAcc := ADD_TIME(StepAcc, DeltaT);
  WHILE StepAcc >= STEP_TIME DO
    StepAcc := SUB_TIME(StepAcc, STEP_TIME);
    Steps := Steps + 1;
    CASE n OF
      0: Flow := 0.0;
      1: Flow := 25.0;
      2: Flow := 40.0;
    ELSE
      Flow := 48.0;
    END_CASE;
    Flow := Flow * LIMIT(0.0, (Level - SUCTION_M) / (SUBMERGENCE_M - SUCTION_M), 1.0);
    Level := Level + (InflowLps - Flow) * STEP_S / (1000.0 * AREA_M2);
    IF Level > OVERFLOW_M THEN
      SpillL := SpillL + (Level - OVERFLOW_M) * AREA_M2 * 1000.0;
      Level := OVERFLOW_M;
    ELSIF Level < 0.0 THEN
      Level := 0.0;
    END_IF;
    IF n > 0 AND Level < SUBMERGENCE_M THEN
      DryRunS := DryRunS + STEP_S;
    END_IF;
    MinLevel := MIN(MinLevel, Level);
    MaxLevel := MAX(MaxLevel, Level);
  END_WHILE;
  OutflowLps := Flow;

  (* --- floats --- *)
  IF Level >= LOW_WET_M THEN
    LowFloatWet := TRUE;
  ELSIF Level <= LOW_DRY_M THEN
    LowFloatWet := FALSE;
  END_IF;
  IF Level >= HIGH_TRIP_M THEN
    HighFloat_NC := FALSE;
  ELSIF Level <= HIGH_RESET_M THEN
    HighFloat_NC := TRUE;
  END_IF;
  IF Level >= HH_TRIP_M THEN
    HHFloat_NC := FALSE;
  ELSIF Level <= HH_RESET_M THEN
    HHFloat_NC := TRUE;
  END_IF;

  (* --- level transmitter and analog input card --- *)
  mA := LIMIT(3.8, 4.0 + 16.0 * Level / SPAN_M, 20.5);
  CASE XmtrFault OF
    XmtrWireBreak: mA := 0.0;
    XmtrLow:       mA := 3.5;
    XmtrHigh:      mA := 21.5;
    XmtrFrozen:    mA := HeldmA;
  END_CASE;
  HeldmA := mA;
  LevelRaw := REAL_TO_INT(LIMIT(-4864.0, (mA - 4.0) * COUNTS_PER_MA, 32511.0));

  (* --- outputs --- *)
  Running1 := Runs[1];
  Running2 := Runs[2];
  Running3 := Runs[3];
  OverloadOK1_NC := NOT Trip1;
  OverloadOK2_NC := NOT Trip2;
  OverloadOK3_NC := NOT Trip3;
  Starts1 := StartCount[1];
  Starts2 := StartCount[2];
  Starts3 := StartCount[3];
END_FUNCTION_BLOCK

PROGRAM PumpStation
  VAR (* digital inputs - station *)
    LowFloatWet        AT %IX0.0 : BOOL;  (* low float: TRUE = submerged (wet) *)
    HighFloat_NC       AT %IX0.1 : BOOL;  (* high float, NC: FALSE = >= 2.50 m or wire broken *)
    HHFloat_NC         AT %IX0.2 : BOOL;  (* high-high float, NC: FALSE = >= 2.80 m or broken *)
    AckPB              AT %IX0.3 : BOOL;  (* panel push-button: acknowledge alarms *)
    ResetPB            AT %IX0.4 : BOOL;  (* panel push-button: reset faults *)
  END_VAR
  VAR (* digital inputs - pumps *)
    Pump1Auto          AT %IX1.0 : BOOL;  (* Hand-Off-Auto switch in Auto *)
    Pump1Running       AT %IX1.1 : BOOL;  (* running feedback (contactor aux / VFD running relay) *)
    Pump1OverloadOK_NC AT %IX1.2 : BOOL;  (* motor protection healthy, NC: FALSE = tripped *)
    Pump2Auto          AT %IX2.0 : BOOL;
    Pump2Running       AT %IX2.1 : BOOL;
    Pump2OverloadOK_NC AT %IX2.2 : BOOL;
    Pump3Auto          AT %IX3.0 : BOOL;
    Pump3Running       AT %IX3.1 : BOOL;
    Pump3OverloadOK_NC AT %IX3.2 : BOOL;
  END_VAR
  VAR (* analog input *)
    LevelRaw           AT %IW0   : INT;   (* level transmitter 0-4.00 m, 4 mA = 0, 20 mA = 27648 *)
  END_VAR
  VAR (* digital outputs *)
    Pump1Run           AT %QX0.0 : BOOL;  (* run command to starter / VFD *)
    Pump2Run           AT %QX0.1 : BOOL;
    Pump3Run           AT %QX0.2 : BOOL;
    AlarmBeacon        AT %QX0.3 : BOOL;  (* flashing = unacknowledged, steady = active *)
  END_VAR
  VAR RETAIN (* setpoints survive a power cycle *)
    Cfg : ST_Config;                      (* written by SCADA *)
  END_VAR
  VAR (* given *)
    Scada : ST_Scada;                     (* SCADA interface image *)
    Sim : FB_WetWellSim;                  (* plant simulation *)
    SimEnable : BOOL := TRUE;             (* set FALSE (or delete section 1) on a real PLC *)
  END_VAR

  (* ===== 1. PLANT SIMULATION (given - do not change) ====================
     The simulation plays the part of the field: it reads last scan's
     outputs and writes this scan's input image, just as the I/O system
     would. On a real PLC this section is removed and nothing else changes. *)
  IF SimEnable THEN
    Sim(Run1 := Pump1Run, Run2 := Pump2Run, Run3 := Pump3Run);
    LevelRaw := Sim.LevelRaw;
    LowFloatWet := Sim.LowFloatWet;
    HighFloat_NC := Sim.HighFloat_NC;
    HHFloat_NC := Sim.HHFloat_NC;
    Pump1Running := Sim.Running1;
    Pump2Running := Sim.Running2;
    Pump3Running := Sim.Running3;
    Pump1OverloadOK_NC := Sim.OverloadOK1_NC;
    Pump2OverloadOK_NC := Sim.OverloadOK2_NC;
    Pump3OverloadOK_NC := Sim.OverloadOK3_NC;
  END_IF;

  (* ===== 2. YOUR CONTROL LOGIC ==========================================
     TODO: replace the placeholder lines below. A suggested layout (see
     "Suggested architecture" in the brief):
       2. time base and operator commands (AckPB, ResetPB, Scada.CmdAck,
          Scada.CmdReset - clear the SCADA command bits after use)
       3. level measurement: scaling, NE43 signal check, hold-last-good,
          float cross-check, latched transmitter fault -> float backup mode
       4. pump demand: duty / assist start-stop levels, float overrides,
          dry-run cut-out, never more than two pumps
       5. lead pump (rotation or run-time balancing), pump selection with
          start stagger and substitution, one pump block per pump
          (faults, availability, starts, run time, starts-per-hour)
       6. alarms: conditions -> AlmActive / AlmUnack, acknowledge, beacon
       7. SCADA image: status words, counters, level, lead pump
     Keep the variable names in the brief's interface tables: the
     acceptance test uses them. Read the plant only through the I/O
     variables, never through Sim.xxx: one FAT scenario switches the
     simulation off (SimEnable FALSE) and drives the inputs itself. *)
  Pump1Run := FALSE;
  Pump2Run := FALSE;
  Pump3Run := FALSE;
  AlarmBeacon := FALSE;
  Scada.LeadPump := 1;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : PumpStation;
  END_RESOURCE
END_CONFIGURATION
