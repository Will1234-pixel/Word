(* Capstone 24-3: Wastewater pump station (wet-well lift station).
   Module 24 (Capstone projects). REFERENCE SOLUTION - build your own first.
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

(* =====================================================================
   SOLUTION TYPES AND BUILDING BLOCKS
   ===================================================================== *)
TYPE
  (* Counters that must survive a power cycle. They live in a RETAIN
     array in the program, outside the SCADA image, so a bad SCADA write
     to the image cannot corrupt them. *)
  ST_PumpCounters : STRUCT
    Starts     : DINT;   (* total starts *)
    RunSeconds : DINT;   (* total running time, whole seconds *)
    RunPart    : TIME;   (* part-second carried to the next scan *)
  END_STRUCT;

  (* One flag per pump. Wrapped in a struct because MATIEC cannot pass a
     bare array to a function. *)
  ST_PumpFlags : STRUCT
    P : ARRAY[1..3] OF BOOL;
  END_STRUCT;
END_TYPE

(* A WORD with only bit Bit set when Value is TRUE, otherwise 0.
   Used to pack BOOLs into status and alarm words. *)
FUNCTION F_Bit : WORD
  VAR_INPUT
    Value : BOOL;
    Bit : INT;
  END_VAR
  IF Value THEN
    F_Bit := SHL(WORD#1, Bit);
  ELSE
    F_Bit := WORD#0;
  END_IF;
END_FUNCTION

(* The next pump after Current (in the order 1-2-3-1) whose flag is TRUE.
   Current itself is tried last. Returns Current when no flag is set. *)
FUNCTION F_NextPump : INT
  VAR_INPUT
    Current : INT;
    Flags : ST_PumpFlags;
  END_VAR
  VAR
    k : INT;
    Candidate : INT;
  END_VAR
  F_NextPump := Current;
  FOR k := 1 TO 3 DO
    Candidate := (Current + k - 1) MOD 3 + 1;
    IF Flags.P[Candidate] THEN
      F_NextPump := Candidate;
      RETURN;
    END_IF;
  END_FOR;
END_FUNCTION

(* Station time base. IEC 61131-3 has no standard "read the clock"
   function, so elapsed time is taken from a free-running TON. On a real
   controller you would normally use the system tick instead. *)
FUNCTION_BLOCK FB_Clock
  VAR_OUTPUT
    DeltaT : TIME;   (* time since the previous scan *)
    NowS : DINT;     (* whole seconds since start-up (wraps after ~68 years) *)
  END_VAR
  VAR
    Tick : TON;
    LastET : TIME;
    Part : TIME;
  END_VAR
  Tick(IN := TRUE, PT := T#24h);
  DeltaT := SUB_TIME(Tick.ET, LastET);
  LastET := Tick.ET;
  IF Tick.Q THEN                 (* re-arm once a day; one scan is lost *)
    Tick(IN := FALSE);
    LastET := T#0s;
  END_IF;
  Part := ADD_TIME(Part, DeltaT);
  WHILE Part >= T#1s DO
    Part := SUB_TIME(Part, T#1s);
    NowS := NowS + 1;
  END_WHILE;
END_FUNCTION_BLOCK

(* Level transmitter: scaling, NAMUR NE43 signal check, hold-last-good,
   cross-check against the floats, and a latched fault (FS-01 to FS-06). *)
FUNCTION_BLOCK FB_LevelXmtr
  VAR_INPUT
    Raw : INT;                 (* card counts: 4 mA = 0, 20 mA = 27648 *)
    LowFloatWet : BOOL;
    HighFloatTripped : BOOL;
    Reset : BOOL;              (* one-scan reset pulse *)
  END_VAR
  VAR_OUTPUT
    LevelM : REAL;             (* level, m; holds the last good value while the signal is bad *)
    SignalBad : BOOL;          (* signal outside the NE43 limits right now *)
    Discrepancy : BOOL;        (* transmitter disagrees with a float right now *)
    Fault : BOOL;              (* latched: use float backup control *)
  END_VAR
  VAR CONSTANT
    SPAN_M : REAL := 4.0;          (* 0-4.00 m = 4-20 mA *)
    COUNTS_SPAN : REAL := 27648.0; (* counts for 16 mA *)
    RAW_MIN : INT := -691;         (* 3.6 mA: NE43 failure limit, low *)
    RAW_MAX : INT := 29376;        (* 21.0 mA: NE43 failure limit, high *)
    HIGH_FLOAT_M : REAL := 2.50;   (* surveyed float elevations *)
    LOW_FLOAT_M : REAL := 0.35;
    MARGIN_M : REAL := 0.30;       (* allowed disagreement *)
  END_VAR
  VAR
    BadTimer : TON;
    DiscrepancyTimer : TON;
  END_VAR

  SignalBad := Raw < RAW_MIN OR Raw > RAW_MAX;                        (* FS-02 *)
  IF NOT SignalBad THEN
    LevelM := INT_TO_REAL(Raw) * SPAN_M / COUNTS_SPAN;
  END_IF;   (* else: keep the last good value, never control on a failed signal (FS-03) *)

  (* A float that has tripped is the stronger evidence: the transmitter
     is wrong if it reads well below a tripped high float, or well above a
     low float that has gone dry (a frozen or drifting transmitter). FS-05 *)
  Discrepancy := (HighFloatTripped AND LevelM < HIGH_FLOAT_M - MARGIN_M)
              OR (NOT LowFloatWet AND LevelM > LOW_FLOAT_M + MARGIN_M);

  BadTimer(IN := SignalBad, PT := T#2s);                               (* FS-04 *)
  DiscrepancyTimer(IN := Discrepancy, PT := T#5s);                     (* FS-05 *)
  IF BadTimer.Q OR DiscrepancyTimer.Q THEN
    Fault := TRUE;
  ELSIF Reset AND NOT SignalBad AND NOT Discrepancy THEN              (* FS-06 *)
    Fault := FALSE;
  END_IF;
END_FUNCTION_BLOCK

(* Analog limit alarm with deadband and on-delay. *)
FUNCTION_BLOCK FB_LimitAlarm
  VAR_INPUT
    Enable : BOOL;          (* FALSE suppresses the alarm (e.g. bad measurement) *)
    Value : REAL;
    Threshold : REAL;
    Deadband : REAL;        (* the value must come this far back to clear *)
    HighAlarm : BOOL;       (* TRUE: alarm at or above Threshold; FALSE: at or below *)
    Delay : TIME;           (* on-delay *)
  END_VAR
  VAR_OUTPUT
    Alarm : BOOL;
  END_VAR
  VAR
    Beyond : BOOL;
    OnDelay : TON;
  END_VAR
  IF HighAlarm THEN
    IF Value >= Threshold THEN
      Beyond := TRUE;
    ELSIF Value < Threshold - Deadband THEN
      Beyond := FALSE;
    END_IF;
  ELSE
    IF Value <= Threshold THEN
      Beyond := TRUE;
    ELSIF Value > Threshold + Deadband THEN
      Beyond := FALSE;
    END_IF;
  END_IF;
  OnDelay(IN := Enable AND Beyond, PT := Delay);
  Alarm := OnDelay.Q;
END_FUNCTION_BLOCK

(* Up to sixteen alarms handled together, one bit each (FS-36, FS-37).
   Active  = the alarm condition is present now,
   Unacked = the alarm has come in and nobody has acknowledged it yet.
   An alarm that clears before it is acknowledged stays Unacked, so the
   operator still sees that it happened. *)
FUNCTION_BLOCK FB_AlarmWord
  VAR_INPUT
    Conditions : WORD;      (* alarm conditions, already delayed *)
    Ack : BOOL;             (* one-scan acknowledge pulse *)
  END_VAR
  VAR_OUTPUT
    Active : WORD;
    Unacked : WORD;
  END_VAR
  VAR
    Previous : WORD;
  END_VAR
  IF Ack THEN
    Unacked := WORD#0;
  END_IF;
  Active := Conditions;
  Unacked := Unacked OR (Active AND NOT Previous);   (* newly active alarms *)
  Previous := Active;
END_FUNCTION_BLOCK

(* One pump: fault supervision, availability, run command, starts and
   run-time counting, starts-per-hour window and status word.
   The station logic decides WHICH pumps should run (Request); this block
   decides whether this pump CAN run and reports what it is doing. *)
FUNCTION_BLOCK FB_Pump
  VAR_INPUT
    Request : BOOL;            (* station selection wants this pump running *)
    AutoSel : BOOL;            (* Hand-Off-Auto switch in Auto *)
    RunningFb : BOOL;          (* running feedback *)
    OverloadOK : BOOL;         (* motor protection healthy (NC contact) *)
    Reset : BOOL;              (* one-scan fault reset pulse *)
    NowS : DINT;               (* station clock, s *)
    DeltaT : TIME;             (* time since the previous scan *)
    MaxStartsPerHour : INT;    (* 0 or less = no limit *)
  END_VAR
  VAR_IN_OUT
    Cnt : ST_PumpCounters;     (* retentive counters, owned by the program *)
  END_VAR
  VAR_OUTPUT
    RunCmd : BOOL;
    Available : BOOL;          (* in Auto and no latched fault *)
    FaultOverload : BOOL;      (* latched *)
    FaultFeedback : BOOL;      (* latched: failed to start, or stopped by itself *)
    StartLimited : BOOL;       (* too many starts in the last 60 min *)
    StartsLastHour : INT;
    Status : WORD;
  END_VAR
  VAR CONSTANT
    FEEDBACK_TIME : TIME := T#5s;
    HISTORY : INT := 32;       (* start times remembered *)
    WINDOW_S : DINT := 3600;
  END_VAR
  VAR
    FeedbackTimer : TON;
    WasRunning : BOOL;
    StartTime : ARRAY[0..31] OF DINT;
    Recorded : INT;
    NextSlot : INT;
    i : INT;
  END_VAR

  (* 1. Commanded but no running feedback for 5 s (FS-26). RunCmd is last scan's. *)
  FeedbackTimer(IN := RunCmd AND NOT RunningFb, PT := FEEDBACK_TIME);

  (* 2. Latched faults. The set condition is tested first, so a reset only
     works once the cause has gone (an overload relay that is still
     tripped cannot be reset from SCADA). FS-25 to FS-28 *)
  IF NOT OverloadOK THEN
    FaultOverload := TRUE;
  ELSIF Reset THEN
    FaultOverload := FALSE;
  END_IF;
  IF FeedbackTimer.Q THEN
    FaultFeedback := TRUE;
  ELSIF Reset THEN
    FaultFeedback := FALSE;
  END_IF;

  (* 3. Availability and command *)
  Available := AutoSel AND NOT FaultOverload AND NOT FaultFeedback;
  RunCmd := Request AND Available;

  (* 4. Count each start (rising edge of the feedback) and remember when (FS-29, FS-32) *)
  IF RunningFb AND NOT WasRunning THEN
    Cnt.Starts := Cnt.Starts + 1;
    StartTime[NextSlot] := NowS;
    NextSlot := (NextSlot + 1) MOD HISTORY;
    IF Recorded < HISTORY THEN
      Recorded := Recorded + 1;
    END_IF;
  END_IF;
  WasRunning := RunningFb;

  (* 5. Starts in the last 60 minutes: a rolling window, not clock hours (FS-30) *)
  StartsLastHour := 0;
  FOR i := 0 TO HISTORY - 1 DO
    IF i < Recorded AND NowS - StartTime[i] < WINDOW_S THEN
      StartsLastHour := StartsLastHour + 1;
    END_IF;
  END_FOR;
  StartLimited := MaxStartsPerHour > 0
                  AND StartsLastHour >= MIN(MaxStartsPerHour, HISTORY);

  (* 6. Run time in whole seconds. The part-second is carried over, so
     there is no drift and no REAL rounding however long the pump runs (FS-33). *)
  IF RunningFb THEN
    Cnt.RunPart := ADD_TIME(Cnt.RunPart, DeltaT);
    WHILE Cnt.RunPart >= T#1s DO
      Cnt.RunPart := SUB_TIME(Cnt.RunPart, T#1s);
      Cnt.RunSeconds := Cnt.RunSeconds + 1;
    END_WHILE;
  END_IF;

  (* 7. Status word for SCADA (section 6.2 of the brief) *)
  Status := F_Bit(AutoSel, 0) OR F_Bit(Available, 1) OR F_Bit(RunCmd, 2)
            OR F_Bit(RunningFb, 3) OR F_Bit(FaultOverload, 4)
            OR F_Bit(FaultFeedback, 5) OR F_Bit(StartLimited, 6);
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
  VAR RETAIN (* solution: data that must survive a power cycle *)
    PumpCnt : ARRAY[1..3] OF ST_PumpCounters;  (* starts and run time per pump *)
    LeadPump : INT := 1;                       (* pump that leads the next / current cycle *)
  END_VAR
  VAR CONSTANT
    STAGGER : TIME := T#5s;          (* minimum time between two pump starts *)
    LEVEL_DEADBAND_M : REAL := 0.05; (* level alarm deadband *)
    LEVEL_ALARM_DELAY : TIME := T#2s;
    MAX_LEVEL_MM : REAL := 4000.0;
  END_VAR
  VAR (* solution internals *)
    Clock : FB_Clock;
    AckEdge : R_TRIG;
    ResetEdge : R_TRIG;
    AckCmd : BOOL;                   (* one-scan pulses from panel or SCADA *)
    ResetCmd : BOOL;
    Xmtr : FB_LevelXmtr;
    FloatMode : BOOL;                (* TRUE = transmitter faulty, float backup control *)
    HighFloatTrip : BOOL;
    HHFloatTrip : BOOL;
    DutyStartM : REAL;               (* setpoints in metres *)
    DutyStopM : REAL;
    AssistStartM : REAL;
    AssistStopM : REAL;
    HighAlarmM : REAL;
    LowAlarmM : REAL;
    LeadDemand : BOOL;               (* the station wants one pump ... *)
    AssistDemand : BOOL;             (* ... or a second one *)
    DryRunCutout : BOOL;
    PumpsWanted : INT;               (* 0, 1 or 2 - never 3 *)
    WasPumping : BOOL;
    BypassStartLimit : BOOL;         (* a float has tripped: overflow beats motor wear *)
    Avail : ST_PumpFlags;
    CanStart : ST_PumpFlags;
    Request : ARRAY[1..3] OF BOOL;   (* pumps selected to run *)
    SinceStart : TIME := T#1m;       (* time since the last pump start *)
    Kept : INT;
    Best : INT;
    Pos : INT;
    PumpNo : INT;
    Pump1 : FB_Pump;
    Pump2 : FB_Pump;
    Pump3 : FB_Pump;
    HighLevelAlm : FB_LimitAlarm;
    LowLevelAlm : FB_LimitAlarm;
    AlarmConditions : WORD;
    Alarms : FB_AlarmWord;
    FlashTimer : TON;
    FlashOn : BOOL;
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

  (* ===== 2. TIME BASE AND OPERATOR COMMANDS ============================= *)
  Clock();
  AckEdge(CLK := AckPB);                  (* edges: a held or stuck button *)
  ResetEdge(CLK := ResetPB);              (* acts once (FS-38, FS-39)      *)
  AckCmd := AckEdge.Q OR Scada.CmdAck;
  ResetCmd := ResetEdge.Q OR Scada.CmdReset;
  Scada.CmdAck := FALSE;                  (* handshake: SCADA sets, PLC clears (FS-43) *)
  Scada.CmdReset := FALSE;

  (* ===== 3. LEVEL MEASUREMENT AND CONTROL MODE ========================== *)
  HighFloatTrip := NOT HighFloat_NC;
  HHFloatTrip := NOT HHFloat_NC;
  Xmtr(Raw := LevelRaw, LowFloatWet := LowFloatWet,
       HighFloatTripped := HighFloatTrip, Reset := ResetCmd);
  FloatMode := Xmtr.Fault;                (* FS-07 *)

  DutyStartM := INT_TO_REAL(Cfg.DutyStartMm) / 1000.0;
  DutyStopM := INT_TO_REAL(Cfg.DutyStopMm) / 1000.0;
  AssistStartM := INT_TO_REAL(Cfg.AssistStartMm) / 1000.0;
  AssistStopM := INT_TO_REAL(Cfg.AssistStopMm) / 1000.0;
  HighAlarmM := INT_TO_REAL(Cfg.HighAlarmMm) / 1000.0;
  LowAlarmM := INT_TO_REAL(Cfg.LowAlarmMm) / 1000.0;

  (* ===== 4. PUMP DEMAND ================================================= *)
  IF FloatMode THEN
    (* Float backup (FS-12): like a hard-wired float circuit. High float
       starts one pump, high-high float a second; both run until the low
       float. Demand that exists when the mode changes simply carries on. *)
    IF HighFloatTrip THEN
      LeadDemand := TRUE;
    END_IF;
    IF HHFloatTrip THEN
      AssistDemand := TRUE;
    END_IF;
  ELSE
    (* Level control (FS-09 to FS-11). Stops are tested first so the starts
       (and the float overrides) win: a tripped float always calls for a pump. *)
    IF Xmtr.LevelM <= DutyStopM THEN
      LeadDemand := FALSE;
    END_IF;
    IF Xmtr.LevelM <= AssistStopM THEN
      AssistDemand := FALSE;
    END_IF;
    IF Xmtr.LevelM >= DutyStartM OR HighFloatTrip THEN
      LeadDemand := TRUE;
    END_IF;
    IF Xmtr.LevelM >= AssistStartM OR HHFloatTrip THEN
      AssistDemand := TRUE;
    END_IF;
  END_IF;

  (* Dry-run protection in both modes, and it overrides everything: the
     low float going dry, or (in level control) the low-level setpoint (FS-13). *)
  DryRunCutout := NOT LowFloatWet OR (NOT FloatMode AND Xmtr.LevelM <= LowAlarmM);
  IF DryRunCutout THEN
    LeadDemand := FALSE;
    AssistDemand := FALSE;
  END_IF;

  (* Never more than two pumps: the rising main is sized for two (FS-14). *)
  PumpsWanted := BOOL_TO_INT(LeadDemand OR AssistDemand)
               + BOOL_TO_INT(LeadDemand AND AssistDemand);
  BypassStartLimit := HighFloatTrip OR HHFloatTrip;   (* FS-31 *)

  (* ===== 5. LEAD PUMP AND PUMP SELECTION ================================ *)
  (* Availability as seen by the pump blocks at the end of the last scan. *)
  Avail.P[1] := Pump1.Available;
  Avail.P[2] := Pump2.Available;
  Avail.P[3] := Pump3.Available;
  CanStart.P[1] := Pump1.Available AND (NOT Pump1.StartLimited OR BypassStartLimit);
  CanStart.P[2] := Pump2.Available AND (NOT Pump2.StartLimited OR BypassStartLimit);
  CanStart.P[3] := Pump3.Available AND (NOT Pump3.StartLimited OR BypassStartLimit);

  (* 5a. Lead pump. Alternation and balancing only act while the station
     is idle, so a healthy lead never changes in the middle of a cycle. *)
  IF PumpsWanted = 0 THEN
    IF WasPumping THEN
      (* end of cycle: alternate (FS-16) *)
      LeadPump := F_NextPump(Current := LeadPump, Flags := Avail);
    END_IF;
    IF Cfg.BalanceByHours THEN
      (* least run time wins; on a tie the lower pump number (FS-17) *)
      Best := 0;
      FOR PumpNo := 1 TO 3 DO
        IF Avail.P[PumpNo] THEN
          IF Best = 0 THEN
            Best := PumpNo;
          ELSIF PumpCnt[PumpNo].RunSeconds < PumpCnt[Best].RunSeconds THEN
            Best := PumpNo;
          END_IF;
        END_IF;
      END_FOR;
      IF Best > 0 THEN
        LeadPump := Best;
      END_IF;
    END_IF;
  END_IF;
  IF NOT Avail.P[LeadPump] THEN
    (* the lead is out of service (fault or not in Auto): pass the lead on
       at once, even mid-cycle, so LeadPump always names a usable pump (FS-18) *)
    LeadPump := F_NextPump(Current := LeadPump, Flags := Avail);
  END_IF;
  WasPumping := PumpsWanted > 0;

  (* 5b. Keep the pumps that are already selected and still available,
     in priority order (lead, then the next pumps in rotation), up to the
     number wanted. Anything beyond that - the assist when the level falls
     to its stop level - is released (FS-20, FS-21, FS-24). *)
  Kept := 0;
  FOR Pos := 1 TO 3 DO
    PumpNo := (LeadPump + Pos - 2) MOD 3 + 1;
    IF Request[PumpNo] AND Avail.P[PumpNo] AND Kept < PumpsWanted THEN
      Kept := Kept + 1;
    ELSE
      Request[PumpNo] := FALSE;
    END_IF;
  END_FOR;

  (* 5c. Start at most one more pump per stagger interval. A pump that is
     unavailable or start-limited is skipped, so the next one in the order
     (the standby, if need be) takes its place (FS-22, FS-23, FS-30). *)
  IF SinceStart < STAGGER THEN
    SinceStart := ADD_TIME(SinceStart, Clock.DeltaT);
  END_IF;
  IF Kept < PumpsWanted AND SinceStart >= STAGGER THEN
    FOR Pos := 1 TO 3 DO
      PumpNo := (LeadPump + Pos - 2) MOD 3 + 1;
      IF NOT Request[PumpNo] AND CanStart.P[PumpNo] THEN
        Request[PumpNo] := TRUE;
        SinceStart := T#0s;
        EXIT;
      END_IF;
    END_FOR;
  END_IF;

  (* 5d. Pump blocks and outputs *)
  Pump1(Request := Request[1], AutoSel := Pump1Auto, RunningFb := Pump1Running,
        OverloadOK := Pump1OverloadOK_NC, Reset := ResetCmd, NowS := Clock.NowS,
        DeltaT := Clock.DeltaT, MaxStartsPerHour := Cfg.MaxStartsPerHour,
        Cnt := PumpCnt[1]);
  Pump2(Request := Request[2], AutoSel := Pump2Auto, RunningFb := Pump2Running,
        OverloadOK := Pump2OverloadOK_NC, Reset := ResetCmd, NowS := Clock.NowS,
        DeltaT := Clock.DeltaT, MaxStartsPerHour := Cfg.MaxStartsPerHour,
        Cnt := PumpCnt[2]);
  Pump3(Request := Request[3], AutoSel := Pump3Auto, RunningFb := Pump3Running,
        OverloadOK := Pump3OverloadOK_NC, Reset := ResetCmd, NowS := Clock.NowS,
        DeltaT := Clock.DeltaT, MaxStartsPerHour := Cfg.MaxStartsPerHour,
        Cnt := PumpCnt[3]);
  Pump1Run := Pump1.RunCmd;
  Pump2Run := Pump2.RunCmd;
  Pump3Run := Pump3.RunCmd;

  (* ===== 6. ALARMS ====================================================== *)
  (* Level alarms are suppressed in float mode: the measurement is bad and
     the transmitter-fault alarm already tells the operator. *)
  HighLevelAlm(Enable := NOT FloatMode, Value := Xmtr.LevelM, Threshold := HighAlarmM,
               Deadband := LEVEL_DEADBAND_M, HighAlarm := TRUE, Delay := LEVEL_ALARM_DELAY);
  LowLevelAlm(Enable := NOT FloatMode, Value := Xmtr.LevelM, Threshold := LowAlarmM,
              Deadband := LEVEL_DEADBAND_M, HighAlarm := FALSE, Delay := LEVEL_ALARM_DELAY);

  AlarmConditions := F_Bit(HighLevelAlm.Alarm, 0)
                  OR F_Bit(HighFloatTrip, 1)
                  OR F_Bit(HHFloatTrip, 2)
                  OR F_Bit(LowLevelAlm.Alarm, 3)
                  OR F_Bit(Xmtr.Fault, 4)
                  OR F_Bit(Pump1.FaultOverload OR Pump1.FaultFeedback, 5)
                  OR F_Bit(Pump2.FaultOverload OR Pump2.FaultFeedback, 6)
                  OR F_Bit(Pump3.FaultOverload OR Pump3.FaultFeedback, 7)
                  OR F_Bit(NOT (Pump1.Available OR Pump2.Available OR Pump3.Available), 8)
                  OR F_Bit(Pump1.StartLimited OR Pump2.StartLimited OR Pump3.StartLimited, 9);
  Alarms(Conditions := AlarmConditions, Ack := AckCmd);

  (* Beacon: flashing while anything is unacknowledged, steady while an
     acknowledged alarm is still active, off when all is clear (FS-40). *)
  FlashTimer(IN := NOT FlashTimer.Q, PT := T#500ms);
  IF FlashTimer.Q THEN
    FlashOn := NOT FlashOn;
  END_IF;
  IF Alarms.Unacked <> WORD#0 THEN
    AlarmBeacon := FlashOn;
  ELSE
    AlarmBeacon := Alarms.Active <> WORD#0;
  END_IF;

  (* ===== 7. SCADA INTERFACE IMAGE (FS-42, section 6 of the brief) ====== *)
  Scada.StationStatus := F_Bit(NOT FloatMode, 0)
                      OR F_Bit(FloatMode, 1)
                      OR F_Bit(Pump1Running OR Pump2Running OR Pump3Running, 2)
                      OR F_Bit(Alarms.Active <> WORD#0, 3)
                      OR F_Bit(Alarms.Unacked <> WORD#0, 4);
  Scada.AlmActive := Alarms.Active;
  Scada.AlmUnack := Alarms.Unacked;
  Scada.LevelMm := REAL_TO_INT(LIMIT(0.0, Xmtr.LevelM * 1000.0, MAX_LEVEL_MM));
  Scada.LeadPump := LeadPump;
  Scada.PumpsRunning := BOOL_TO_INT(Pump1Running) + BOOL_TO_INT(Pump2Running)
                      + BOOL_TO_INT(Pump3Running);

  Scada.Pump[1].Status := Pump1.Status;
  Scada.Pump[1].Starts := PumpCnt[1].Starts;
  Scada.Pump[1].RunSeconds := PumpCnt[1].RunSeconds;
  Scada.Pump[1].StartsLastHour := Pump1.StartsLastHour;
  Scada.Pump[2].Status := Pump2.Status;
  Scada.Pump[2].Starts := PumpCnt[2].Starts;
  Scada.Pump[2].RunSeconds := PumpCnt[2].RunSeconds;
  Scada.Pump[2].StartsLastHour := Pump2.StartsLastHour;
  Scada.Pump[3].Status := Pump3.Status;
  Scada.Pump[3].Starts := PumpCnt[3].Starts;
  Scada.Pump[3].RunSeconds := PumpCnt[3].RunSeconds;
  Scada.Pump[3].StartsLastHour := Pump3.StartsLastHour;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : PumpStation;
  END_RESOURCE
END_CONFIGURATION
