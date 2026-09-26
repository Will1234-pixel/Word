(* Lab 11-3: A small function library and a statistics FB using VAR_IN_OUT.
   Module 11 (Program organisation). STARTER - the record type, the function
   and FB interfaces and the program declarations are done for you. Write:
     1. the bodies of F_InRange and F_Deadband,
     2. the body of FB_SampleStats (and any internal variables it needs), and
     3. the program logic: clear, call Head1 and Head2, drive the reject
        gates and update ReportedMean.
   Then run:
     python3 tools/plctest.py 11-program-organization/labs/starter/11-3-function-library.st *)

TYPE
  ST_Stats :
  STRUCT
    Count    : DINT;    (* samples since the last clear *)
    InSpec   : DINT;    (* samples inside the limits *)
    OutSpec  : DINT;    (* samples outside the limits *)
    MinValue : REAL;    (* smallest sample since the last clear *)
    MaxValue : REAL;    (* largest sample since the last clear *)
    Sum      : LREAL;   (* running total (LREAL keeps precision over a long shift) *)
    Mean     : REAL;    (* Sum / Count *)
  END_STRUCT;
END_TYPE


FUNCTION F_InRange : BOOL
  (* TRUE when Low <= Value <= High (both limits included).
     If Low > High the range is empty: always FALSE. *)
  VAR_INPUT
    Value : REAL;
    Low   : REAL;
    High  : REAL;
  END_VAR
  (* TODO *)
  F_InRange := FALSE;
END_FUNCTION


FUNCTION F_Deadband : REAL
  (* Report-by-exception: return NewValue when it differs from OldValue by
     Band or more, otherwise return OldValue. *)
  VAR_INPUT
    NewValue : REAL;   (* live value *)
    OldValue : REAL;   (* value reported last time *)
    Band     : REAL;   (* smallest change worth reporting *)
  END_VAR
  (* TODO *)
  F_Deadband := 0.0;
END_FUNCTION


FUNCTION_BLOCK FB_SampleStats
  (* Adds one sample to the shared record Stats on each rising edge of
     Sample, and judges it against the limits with F_InRange.
     Keep these pin names: the test reads Reject and Samples. *)
  VAR_INPUT
    Sample    : BOOL;   (* rising edge = Value holds a new sample *)
    Value     : REAL;
    LowLimit  : REAL;
    HighLimit : REAL;
  END_VAR
  VAR_IN_OUT
    Stats     : ST_Stats;
  END_VAR
  VAR_OUTPUT
    Reject    : BOOL;   (* TRUE when this instance's latest sample was out of limits *)
    Samples   : DINT;   (* samples taken by THIS instance since power-up *)
  END_VAR
  (* TODO: add a VAR ... END_VAR block here for internal variables. *)

  (* TODO: replace this placeholder with the statistics logic. *)
  Reject := FALSE;
END_FUNCTION_BLOCK


PROGRAM CheckWeigher
  VAR (* inputs *)
    Head1Ready  AT %IX0.0 : BOOL;  (* check-weigher 1: TRUE when Head1Weight holds a new weight *)
    Head2Ready  AT %IX0.1 : BOOL;  (* check-weigher 2: TRUE when Head2Weight holds a new weight *)
    ClearPB     AT %IX0.2 : BOOL;  (* clear the line statistics (start of shift) *)
  END_VAR
  VAR (* outputs *)
    Head1Reject AT %QX0.0 : BOOL;  (* reject gate after head 1 *)
    Head2Reject AT %QX0.1 : BOOL;  (* reject gate after head 2 *)
  END_VAR
  VAR (* weights from the check-weighers and settings from the HMI *)
    Head1Weight  : REAL;             (* g, written by check-weigher 1 over the network *)
    Head2Weight  : REAL;             (* g, written by check-weigher 2 *)
    LowLimit     : REAL := 495.0;    (* g, lowest acceptable net weight *)
    HighLimit    : REAL := 505.0;    (* g, highest acceptable net weight *)
    MeanDeadband : REAL := 0.5;      (* g, smallest change of mean worth sending to SCADA *)
  END_VAR
  VAR (* data - keep these names *)
    LineStats    : ST_Stats;         (* shared by both heads, read by the HMI *)
    ReportedMean : REAL;             (* mean weight as last sent to SCADA *)
    Head1        : FB_SampleStats;
    Head2        : FB_SampleStats;
  END_VAR

  (* TODO: call Head1 and Head2 so that both update LineStats, keep every
     field of LineStats at zero while ClearPB is pressed (tip: a whole
     structure can be assigned in one statement; think about where in the
     scan to do it), drive the reject gates, and update ReportedMean with
     F_Deadband. *)
  Head1Reject := FALSE;
  Head2Reject := FALSE;
END_PROGRAM


CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : CheckWeigher;
  END_RESOURCE
END_CONFIGURATION
