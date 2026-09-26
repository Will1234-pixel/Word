(* Lab 10-2: Median filter for a noisy tank level.
   Module 10 (Structured Text). STARTER - the declarations are done for you;
   write the logic where it says TODO, then run:
     python3 tools/plctest.py 10-structured-text/labs/starter/10-2-median-filter.st *)

PROGRAM MedianFilter
  VAR (* interface *)
    RawLevel      : REAL;   (* noisy level from the radar transmitter, % *)
    SampleTrig    : BOOL;   (* sample clock: each rising edge takes one sample *)
    FilteredLevel : REAL;   (* median of the last five samples, % *)
    Ready         : BOOL;   (* TRUE once five samples have been collected *)
  END_VAR
  VAR (* suggested internal variables - change them if you prefer another design *)
    History    : ARRAY[1..5] OF REAL;  (* samples in arrival order *)
    Sorted     : ARRAY[1..5] OF REAL;  (* working copy to sort *)
    Count      : INT;                  (* samples collected so far, 0..5 *)
    SampleEdge : R_TRIG;               (* rising-edge detector for SampleTrig *)
    i, j       : INT;
    Temp       : REAL;
  END_VAR

  (* TODO:
     1. On each rising edge of SampleTrig, add RawLevel to the history and
        drop the oldest sample.
     2. Set Ready once five samples have been collected.
     3. While not Ready, pass the newest sample through. When Ready, sort a
        copy of the history and output the middle value. *)
  FilteredLevel := 0.0;
  Ready := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : MedianFilter;
  END_RESOURCE
END_CONFIGURATION
