(* Lab 10-2: Median filter for a noisy tank level.
   Module 10 (Structured Text). REFERENCE SOLUTION - try the lab yourself first. *)

PROGRAM MedianFilter
  VAR (* interface *)
    RawLevel      : REAL;   (* noisy level from the radar transmitter, % *)
    SampleTrig    : BOOL;   (* sample clock: each rising edge takes one sample *)
    FilteredLevel : REAL;   (* median of the last five samples, % *)
    Ready         : BOOL;   (* TRUE once five samples have been collected *)
  END_VAR
  VAR
    History    : ARRAY[1..5] OF REAL;  (* samples in arrival order: [1] oldest, [5] newest *)
    Sorted     : ARRAY[1..5] OF REAL;  (* working copy that gets sorted *)
    Count      : INT;                  (* samples collected so far, 0..5 *)
    SampleEdge : R_TRIG;               (* one sample per rising edge of SampleTrig *)
    i, j       : INT;
    Temp       : REAL;                 (* swap space for the sort *)
  END_VAR

  (* 1. Take a sample on each rising edge only. Holding SampleTrig TRUE for
        many scans must still give exactly one sample. *)
  SampleEdge(CLK := SampleTrig);
  IF SampleEdge.Q THEN
    (* Shift the history one place towards the old end. The oldest sample
       falls off, and the new one goes in at the newest end. *)
    FOR i := 1 TO 4 DO
      History[i] := History[i + 1];
    END_FOR;
    History[5] := RawLevel;
    IF Count < 5 THEN
      Count := Count + 1;
    END_IF;
  END_IF;

  Ready := Count >= 5;

  IF Ready THEN
    (* 2. Sort a COPY. The history must stay in time order, or the next shift
          would throw away the smallest value instead of the oldest one. *)
    Sorted := History;
    (* Bubble sort: each pass moves the largest remaining value to the end.
       Four passes are enough for five values (at most 10 comparisons). *)
    FOR i := 1 TO 4 DO
      FOR j := 1 TO 5 - i DO
        IF Sorted[j] > Sorted[j + 1] THEN
          Temp := Sorted[j];
          Sorted[j] := Sorted[j + 1];
          Sorted[j + 1] := Temp;
        END_IF;
      END_FOR;
    END_FOR;
    (* 3. The median of five sorted values is the middle one. *)
    FilteredLevel := Sorted[3];
  ELSE
    (* Warming up: pass the newest sample straight through, so the output is
       sensible from the first sample (it is 0.0 before any sample). *)
    FilteredLevel := History[5];
  END_IF;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : MedianFilter;
  END_RESOURCE
END_CONFIGURATION
