(* Lab 10-1: Array statistics - ten cold-store temperature probes.
   Module 10 (Structured Text). STARTER - the declarations are done for you;
   write the logic where it says TODO, then run:
     python3 tools/plctest.py 10-structured-text/labs/starter/10-1-array-statistics.st *)

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
    Sum : REAL;                       (* running total *)
  END_VAR

  (* TODO: replace these placeholder lines with a FOR loop over Samples that
     finds the minimum, the maximum, the probe number of the maximum and the
     average. Think about what the minimum and maximum should start from. *)
  MinValue := 0.0;
  MaxValue := 0.0;
  Average := 0.0;
  MaxIndex := 0;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : ArrayStats;
  END_RESOURCE
END_CONFIGURATION
