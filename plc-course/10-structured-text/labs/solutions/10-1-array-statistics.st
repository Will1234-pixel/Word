(* Lab 10-1: Array statistics - ten cold-store temperature probes.
   Module 10 (Structured Text). REFERENCE SOLUTION - try the lab yourself first. *)

PROGRAM ArrayStats
  VAR (* interface: the I/O mapping routine copies the ten probe readings in here *)
    Samples  : ARRAY[1..10] OF REAL;  (* probe temperatures, degC. Samples[3] is probe TT-303 *)
    MinValue : REAL;                  (* coldest reading, degC *)
    MaxValue : REAL;                  (* warmest reading, degC *)
    Average  : REAL;                  (* mean of the ten readings, degC *)
    MaxIndex : INT;                   (* probe number (1..10) of the warmest reading *)
  END_VAR
  VAR CONSTANT
    NUM_PROBES : INT := 10;           (* must match the upper bound of Samples *)
  END_VAR
  VAR
    i   : INT;                        (* loop index *)
    Sum : REAL;                       (* running total, rebuilt from zero every scan *)
  END_VAR

  (* Start from the first sample, never from 0.0. In a freezer every reading is
     below zero, so a maximum that started at 0.0 would never be beaten. *)
  MinValue := Samples[1];
  MaxValue := Samples[1];
  MaxIndex := 1;
  Sum := 0.0;   (* Sum keeps its value between scans, so it must be cleared here *)

  FOR i := 1 TO NUM_PROBES DO
    Sum := Sum + Samples[i];

    IF Samples[i] < MinValue THEN
      MinValue := Samples[i];
    END_IF;

    (* Strictly greater: when two probes share the warmest value, the
       first one found (the lower probe number) is kept. *)
    IF Samples[i] > MaxValue THEN
      MaxValue := Samples[i];
      MaxIndex := i;
    END_IF;
  END_FOR;

  (* REAL division: both operands must be REAL, so convert the count. *)
  Average := Sum / INT_TO_REAL(NUM_PROBES);
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : ArrayStats;
  END_RESOURCE
END_CONFIGURATION
