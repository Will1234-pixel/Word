(* Lab 14-1: FB_AnalogInput - raw counts to engineering units, with
   NAMUR NE43 fault detection, clamping, a first-order filter, a quality
   flag and substitute-value behaviour.
   Module 14 (Analog signals and process I/O). REFERENCE SOLUTION - try the lab yourself first.

   Raw-count convention used by every lab in this module (Siemens style):
     Raw = 0     ->  4 mA   (bottom of the rated range)
     Raw = 27648 -> 20 mA   (top of the rated range)
     1 mA = 27648 / 16 = 1728 counts.
   Values outside 0..27648 are under- and over-range. The simulated card
   in this lab is linear over the whole INT range, so 0 mA reads -6912 and
   21 mA reads 29376. The Siemens underflow/overflow codes (-32768, 32767)
   also land in the failure bands, so this block copes with them too. *)

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

PROGRAM AnalogInputs
  VAR (* I/O - analog inputs, 0..27648 = 4..20 mA *)
    LT101_Raw AT %IW0 : INT;  (* LT-101 tank level transmitter: 0.0..4.0 m *)
    TT102_Raw AT %IW1 : INT;  (* TT-102 reactor temperature transmitter: -50..150 degC *)
  END_VAR
  VAR
    LT101 : FB_AnalogInput;   (* level: filtered, holds the last good value on a fault *)
    TT102 : FB_AnalogInput;   (* temperature: unfiltered, substitutes 150 degC on a fault *)
  END_VAR

  (* Level: 2 s filter to calm a surface that ripples, hold last value on a
     fault (the level alarms in Lab 14-2 then freeze rather than jump). *)
  LT101(Raw := LT101_Raw, EuMin := 0.0, EuMax := 4.0,
        FilterTime := T#2s, FaultDelay := T#1s,
        UseSubst := FALSE, SubstValue := 0.0, CycleTime := T#10ms);

  (* Temperature: no filter (a trip needs the fastest response), and a
     substitute value at the TOP of the range, so a failed transmitter
     drives a high-temperature trip rather than hiding a real overheat. *)
  TT102(Raw := TT102_Raw, EuMin := -50.0, EuMax := 150.0,
        FilterTime := T#0s, FaultDelay := T#2s,
        UseSubst := TRUE, SubstValue := 150.0, CycleTime := T#10ms);
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : AnalogInputs;
  END_RESOURCE
END_CONFIGURATION
