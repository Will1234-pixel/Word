(* Lab 14-1: FB_AnalogInput - raw counts to engineering units, with
   NAMUR NE43 fault detection, clamping, a first-order filter, a quality
   flag and substitute-value behaviour.
   Module 14 (Analog signals and process I/O). STARTER - the interface and the
   program that uses the block are done for you; write the body of
   FB_AnalogInput where it says TODO, then run:
     python3 tools/plctest.py 14-analog-and-process-io/labs/starter/14-1-analog-input.st

   Raw-count convention used by every lab in this module (Siemens style):
     Raw = 0     ->  4 mA   (bottom of the rated range)
     Raw = 27648 -> 20 mA   (top of the rated range)
     1 mA = 27648 / 16 = 1728 counts.
   Values outside 0..27648 are under- and over-range. The simulated card
   in this lab is linear over the whole INT range, so 0 mA reads -6912 and
   21 mA reads 29376. *)

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
    UnderRange : BOOL;   (* current <= 3.6 mA for FaultDelay: wire break, failure low *)
    OverRange  : BOOL;   (* current >= 21.0 mA for FaultDelay: short circuit, failure high *)
    Fault      : BOOL;   (* UnderRange OR OverRange *)
  END_VAR
  VAR CONSTANT
    COUNTS_PER_MA : REAL := 1728.0;   (* 27648 counts / 16 mA *)
    FAIL_LOW_MA   : REAL := 3.6;      (* NE43: at or below = failure signal *)
    FAIL_HIGH_MA  : REAL := 21.0;     (* NE43: at or above = failure signal *)
  END_VAR
  VAR
    (* Suggested internal variables - add, rename or remove as you like. *)
    LowTimer    : TON;    (* confirmation delay for the low failure band *)
    HighTimer   : TON;    (* confirmation delay for the high failure band *)
    Filtered    : REAL;   (* filter state; also the last good value *)
    FilterReady : BOOL;   (* FALSE until the filter holds a real measurement *)
  END_VAR

  (* TODO: replace these placeholder lines with your logic (see the
     requirements in the Module 14 README, Lab 14-1). Suggested order:
       1. Raw -> Current_mA (convert to REAL first!)
       2. NE43 limits with the FaultDelay -> UnderRange, OverRange, Fault, Good
       3. Scale 4..20 mA to EuMin..EuMax and clamp
       4. First-order filter, fed only with good readings
       5. Value: substitute, hold or live *)
  Current_mA := 0.0;
  Value := 0.0;
  Good := FALSE;
  UnderRange := FALSE;
  OverRange := FALSE;
  Fault := FALSE;
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

  (* The program is complete: do not change these calls. *)
  LT101(Raw := LT101_Raw, EuMin := 0.0, EuMax := 4.0,
        FilterTime := T#2s, FaultDelay := T#1s,
        UseSubst := FALSE, SubstValue := 0.0, CycleTime := T#10ms);

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
