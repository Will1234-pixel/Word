(* Lab 11-3: A small function library and a statistics FB using VAR_IN_OUT.
   Module 11 (Program organisation). REFERENCE SOLUTION - try the lab yourself first.

   A filling line has two filling heads, each with its own check-weigher.
   One instance of FB_SampleStats per head judges each weight against the
   limits and adds it to ONE shared statistics record, LineStats, which the
   instances reach through VAR_IN_OUT. Two FUNCTIONs form a small reusable
   library: F_InRange (limit check) and F_Deadband (report-by-exception). *)

TYPE
  ST_Stats :
  STRUCT
    Count    : DINT;    (* samples since the last clear *)
    InSpec   : DINT;    (* samples inside the limits *)
    OutSpec  : DINT;    (* samples outside the limits *)
    MinValue : REAL;    (* smallest sample since the last clear *)
    MaxValue : REAL;    (* largest sample since the last clear *)
    Sum      : LREAL;   (* running total. LREAL: a REAL has only about 7 significant
                           digits. Once a REAL total passes about 8.4 million (some
                           17,000 samples of 500 g) it can only change in whole grams,
                           so every new weight would be rounded to a whole gram *)
    Mean     : REAL;    (* Sum / Count *)
  END_STRUCT;
END_TYPE


FUNCTION F_InRange : BOOL
  (* TRUE when Low <= Value <= High (both limits included).
     If Low > High the range is empty and the result is always FALSE, so a
     limit entry mistake shows up as "everything out of range" rather than
     being silently repaired. No memory: same inputs, same answer. *)
  VAR_INPUT
    Value : REAL;
    Low   : REAL;
    High  : REAL;
  END_VAR
  F_InRange := (Value >= Low) AND (Value <= High);
END_FUNCTION


FUNCTION F_Deadband : REAL
  (* Report-by-exception: returns NewValue when it differs from OldValue by
     Band or more, otherwise returns OldValue unchanged.
     A function has no memory, so the CALLER keeps the last reported value
     and passes it back in as OldValue:
         Reported := F_Deadband(Live, Reported, 0.5);
     Band <= 0.0 passes every change straight through. *)
  VAR_INPUT
    NewValue : REAL;   (* live value *)
    OldValue : REAL;   (* value reported last time *)
    Band     : REAL;   (* smallest change worth reporting *)
  END_VAR
  IF ABS(NewValue - OldValue) >= Band THEN
    F_Deadband := NewValue;
  ELSE
    F_Deadband := OldValue;
  END_IF;
END_FUNCTION


FUNCTION_BLOCK FB_SampleStats
  (* Adds one sample to a statistics record on each rising edge of Sample.
     The record itself is NOT inside the FB: it is passed in by reference
     (VAR_IN_OUT), so several instances can update one shared record and
     the caller decides where it lives (retentive memory, HMI area, ...).
     What IS inside the instance: its own edge detector, its own Reject
     output and its own sample counter. *)
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
  VAR
    SampleEdge : R_TRIG;
  END_VAR

  SampleEdge(CLK := Sample);
  IF SampleEdge.Q THEN
    Samples := Samples + 1;

    (* The first sample after a clear seeds MIN and MAX. Starting them at 0.0
       would leave MinValue stuck at 0.0 for ever. *)
    IF Stats.Count = 0 THEN
      Stats.MinValue := Value;
      Stats.MaxValue := Value;
    ELSE
      Stats.MinValue := MIN(Stats.MinValue, Value);
      Stats.MaxValue := MAX(Stats.MaxValue, Value);
    END_IF;

    Stats.Count := Stats.Count + 1;
    Stats.Sum := Stats.Sum + REAL_TO_LREAL(Value);
    Stats.Mean := LREAL_TO_REAL(Stats.Sum / DINT_TO_LREAL(Stats.Count));  (* Count >= 1 here *)

    IF F_InRange(Value, LowLimit, HighLimit) THEN
      Stats.InSpec := Stats.InSpec + 1;
      Reject := FALSE;
    ELSE
      Stats.OutSpec := Stats.OutSpec + 1;
      Reject := TRUE;
    END_IF;
  END_IF;
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
  VAR (* data *)
    LineStats    : ST_Stats;         (* shared by both heads, read by the HMI *)
    ReportedMean : REAL;             (* mean weight as last sent to SCADA *)
    Head1        : FB_SampleStats;
    Head2        : FB_SampleStats;
  END_VAR
  VAR CONSTANT
    CLEARED_STATS : ST_Stats := (Count := 0, InSpec := 0, OutSpec := 0,
                                 MinValue := 0.0, MaxValue := 0.0,
                                 Sum := 0.0, Mean := 0.0);
  END_VAR

  (* Both instances update the SAME record. VAR_IN_OUT must be connected
     to a variable on every call; a constant or an expression is refused. *)
  Head1(Sample := Head1Ready, Value := Head1Weight,
        LowLimit := LowLimit, HighLimit := HighLimit,
        Stats := LineStats);
  Head2(Sample := Head2Ready, Value := Head2Weight,
        LowLimit := LowLimit, HighLimit := HighLimit,
        Stats := LineStats);

  (* Clear AFTER the calls: the record then reads all zeros for as long as
     ClearPB is held, even if a weight arrives in that scan. Such a weight
     still operates its reject gate; it is just not added to the new shift. *)
  IF ClearPB THEN
    LineStats := CLEARED_STATS;
  END_IF;

  Head1Reject := Head1.Reject;
  Head2Reject := Head2.Reject;

  (* ReportedMean is the memory that F_Deadband itself cannot have. *)
  ReportedMean := F_Deadband(LineStats.Mean, ReportedMean, MeanDeadband);
END_PROGRAM


CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : CheckWeigher;
  END_RESOURCE
END_CONFIGURATION
