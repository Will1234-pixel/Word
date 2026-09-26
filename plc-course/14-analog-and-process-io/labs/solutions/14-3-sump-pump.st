(* Lab 14-3: Sump pump level control - a pump-down on/off controller with
   hysteresis, a high-level alarm, an independent low-low float for dry-run
   protection, pump fault handling, and a level-transmitter fault.
   Module 14 (Analog signals and process I/O). REFERENCE SOLUTION - try the lab yourself first.

   TRAINING EXERCISE ONLY. The low-low float trip here is ordinary control
   logic in a standard PLC, not a designed safety function (Module 20).

   Raw-count convention: 0..27648 = 4..20 mA, 1728 counts per mA.
   LT-301 range 0.0..4.0 m, so 1 m = 6912 counts.

   FB_AnalogInput below is copied unchanged from the Lab 14-1 solution. In a
   real project it would live in a library; MATIEC compiles one file, so
   the lab keeps a copy here. *)

FUNCTION_BLOCK FB_AnalogInput
  VAR_INPUT
    Raw        : INT;    (* raw count from the input card *)
    EuMin      : REAL;   (* engineering value at 4 mA (must be below EuMax) *)
    EuMax      : REAL;   (* engineering value at 20 mA *)
    FilterTime : TIME;   (* first-order filter time constant; T#0s = no filter *)
    FaultDelay : TIME;   (* signal must stay in a failure band this long before Fault *)
    UseSubst   : BOOL;   (* on Fault: TRUE = output SubstValue, FALSE = hold last good value *)
    SubstValue : REAL;   (* substitute value, engineering units *)
    CycleTime  : TIME;   (* interval of the task that calls this block *)
  END_VAR
  VAR_OUTPUT
    Current_mA : REAL;   (* loop current worked out from Raw: not filtered, not clamped *)
    Value      : REAL;   (* engineering value for the rest of the program *)
    Good       : BOOL;   (* TRUE while the loop current is inside the NE43 limits *)
    UnderRange : BOOL;   (* Fault, and the current is <= 3.6 mA: wire break, failure low *)
    OverRange  : BOOL;   (* Fault, and the current is >= 21.0 mA: short circuit, failure high *)
    Fault      : BOOL;   (* outside the NE43 limits for FaultDelay (= UnderRange OR OverRange) *)
  END_VAR
  VAR CONSTANT
    COUNTS_PER_MA : REAL := 1728.0;   (* 27648 counts / 16 mA *)
    FAIL_LOW_MA   : REAL := 3.6;      (* NE43: at or below = failure signal *)
    FAIL_HIGH_MA  : REAL := 21.0;     (* NE43: at or above = failure signal *)
  END_VAR
  VAR
    FaultTimer  : TON;    (* confirmation delay: signal outside the NE43 limits *)
    Scaled      : REAL;   (* engineering value, clamped, before the filter *)
    Filtered    : REAL;   (* filter state; also the last good value *)
    FilterReady : BOOL;   (* FALSE until Filtered holds a real measurement *)
    Alpha       : REAL;   (* filter weight for this scan, 0..1 *)
  END_VAR

  (* 1. Raw count -> loop current. Convert to REAL before doing any
        arithmetic: Raw * 16 in INT would overflow above 2047 counts. *)
  Current_mA := 4.0 + INT_TO_REAL(Raw) / COUNTS_PER_MA;

  (* 2. NAMUR NE43 check. Good = the reading is a live measurement right
        now. It drops at once, without waiting for the delay. *)
  Good := (Current_mA > FAIL_LOW_MA) AND (Current_mA < FAIL_HIGH_MA);

  (* Fault = the confirmed version: outside the limits continuously for
     FaultDelay. One timer covers both failure bands, so a current that
     jumps straight from one band to the other (a transmitter that failed
     upscale and is then disconnected) stays a fault. It clears on the
     first scan the current is back inside the limits. The direction
     flags only say which band the confirmed failure is in. *)
  FaultTimer(IN := NOT Good, PT := FaultDelay);
  Fault := FaultTimer.Q;
  UnderRange := Fault AND (Current_mA <= FAIL_LOW_MA);
  OverRange := Fault AND (Current_mA >= FAIL_HIGH_MA);

  (* 3. Linear scaling 4..20 mA -> EuMin..EuMax, then clamp. Between
        3.6 and 4 mA (and 20 and 21 mA) the reading is still trusted
        but is shown as the end of the range. *)
  Scaled := EuMin + (Current_mA - 4.0) * (EuMax - EuMin) / 16.0;
  Scaled := LIMIT(EuMin, Scaled, EuMax);

  (* 4. First-order lag filter, only fed with good readings. While the
        signal is suspect or faulted, Filtered is left alone, so it holds
        the last good value. *)
  IF Good THEN
    IF NOT FilterReady THEN
      (* First good reading after power-up or after a fault: start the
         filter here instead of ramping up from 0 or from a held value. *)
      Filtered := Scaled;
      FilterReady := TRUE;
    ELSE
      (* Alpha = Ts / (Tf + Ts). A ratio of two times has no unit, so it
         works whatever unit TIME_TO_REAL uses on your platform.
         FilterTime = T#0s gives Alpha = 1: no filtering, no division by 0. *)
      IF FilterTime > T#0s THEN
        Alpha := TIME_TO_REAL(CycleTime) / (TIME_TO_REAL(CycleTime) + TIME_TO_REAL(FilterTime));
      ELSE
        Alpha := 1.0;
      END_IF;
      Filtered := Filtered + Alpha * (Scaled - Filtered);
    END_IF;
  END_IF;

  IF Fault THEN
    FilterReady := FALSE;   (* restart the filter from the live value on recovery *)
  END_IF;

  (* 5. Output: substitute on a confirmed fault if configured, otherwise
        the filter state (live value, or the held last good value). *)
  IF Fault AND UseSubst THEN
    Value := SubstValue;
  ELSE
    Value := Filtered;
  END_IF;
END_FUNCTION_BLOCK

PROGRAM SumpPump
  VAR (* I/O *)
    LT301_Raw     AT %IW0   : INT;   (* LT-301 sump level: 0..27648 = 4..20 mA = 0.0..4.0 m *)
    LSLL302_NC    AT %IX0.0 : BOOL;  (* low-low float, NC: TRUE while water is above it *)
    PumpRunFb     AT %IX0.1 : BOOL;  (* pump contactor auxiliary contact: TRUE = pulled in *)
    PumpOL_NC     AT %IX0.2 : BOOL;  (* motor overload relay, NC: TRUE = healthy *)
    ResetPB       AT %IX0.3 : BOOL;  (* fault reset push-button, NO *)
    PumpRun       AT %QX0.0 : BOOL;  (* pump contactor coil *)
    HighLevelAlm  AT %QX0.1 : BOOL;  (* high sump level alarm *)
    LowLowAlm     AT %QX0.2 : BOOL;  (* low-low float operated (latched) *)
    PumpFaultAlm  AT %QX0.3 : BOOL;  (* pump fault: overload or no run feedback (latched) *)
    LevelFaultAlm AT %QX0.4 : BOOL;  (* LT-301 signal outside the NE43 limits *)
  END_VAR
  VAR
    Level : REAL;                    (* sump level in m, for the HMI *)
  END_VAR
  VAR CONSTANT
    START_LEVEL    : REAL := 2.0;    (* pump starts at or above this level, m *)
    STOP_LEVEL     : REAL := 1.0;    (* pump stops at or below this level, m *)
    HIGH_ALM_LEVEL : REAL := 3.0;    (* high level alarm limit, m *)
    HIGH_ALM_DB    : REAL := 0.1;    (* high level alarm deadband, m *)
  END_VAR
  VAR
    LT301        : FB_AnalogInput;
    HighAlmTimer : TON;              (* 5 s on-delay for the high level alarm *)
    FbTimer      : TON;              (* 2 s run-feedback supervision *)
    ResetEdge    : R_TRIG;           (* reset acts on the press, not the level *)
    Demand       : BOOL;             (* the level controller wants the pump on *)
    Trip         : BOOL;             (* something stops the pump *)
  END_VAR

  (* 1. Level measurement: scaling, clamping and NE43 checking by the
        Lab 14-1 block. No filter, so the controller sees the real level.
        During the 1 s confirmation delay the block holds the last good
        level, so a broken wire does not look like an empty sump. *)
  LT301(Raw := LT301_Raw, EuMin := 0.0, EuMax := 4.0,
        FilterTime := T#0s, FaultDelay := T#1s,
        UseSubst := FALSE, SubstValue := 0.0, CycleTime := T#10ms);
  Level := LT301.Value;
  LevelFaultAlm := LT301.Fault;      (* clears by itself when the signal is healthy again *)

  (* 2. High level alarm: 5 s on-delay, 0.1 m deadband. *)
  HighAlmTimer(IN := Level >= HIGH_ALM_LEVEL, PT := T#5s);
  IF HighAlmTimer.Q THEN
    HighLevelAlm := TRUE;
  ELSIF Level < HIGH_ALM_LEVEL - HIGH_ALM_DB THEN
    HighLevelAlm := FALSE;
  END_IF;

  (* 3. Reset: one press, one reset. A jammed button cannot keep clearing
        faults and restarting a pump that keeps failing. *)
  ResetEdge(CLK := ResetPB);

  (* 4. Low-low float: independent of the transmitter, so it still protects
        the pump when LT-301 reads wrong (stuck, drifted, wrong range).
        Latched: the float should never operate in normal service, so a
        person must look before the pump runs again. The reset only works
        once the float is healthy (the IF sets it again every scan while
        the float is open). *)
  IF NOT LSLL302_NC THEN
    LowLowAlm := TRUE;
  ELSIF ResetEdge.Q THEN
    LowLowAlm := FALSE;
  END_IF;

  (* 5. Pump faults, latched until a reset:
        - overload relay tripped (reset only works once it is healthy)
        - pump commanded but no run feedback for 2 s (contactor failed to
          pull in, or dropped out while running). *)
  FbTimer(IN := PumpRun AND NOT PumpRunFb, PT := T#2s);
  IF (NOT PumpOL_NC) OR FbTimer.Q THEN
    PumpFaultAlm := TRUE;
  ELSIF ResetEdge.Q THEN
    PumpFaultAlm := FALSE;
  END_IF;

  (* 6. Pump-down level control with hysteresis. Any trip stops the pump
        at once and cancels the demand, so after a reset or recovery the
        pump starts again only when the level reaches START_LEVEL. *)
  Trip := LowLowAlm OR PumpFaultAlm OR LevelFaultAlm;

  IF Trip THEN
    Demand := FALSE;
  ELSIF Level >= START_LEVEL THEN
    Demand := TRUE;
  ELSIF Level <= STOP_LEVEL THEN
    Demand := FALSE;
  END_IF;                            (* between the two levels: keep the state *)

  PumpRun := Demand AND NOT Trip;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : SumpPump;
  END_RESOURCE
END_CONFIGURATION
