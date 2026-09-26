(* Lab 10-3: Tank strapping table - level to volume by piecewise-linear lookup.
   Module 10 (Structured Text). STARTER - the declarations are done for you;
   write the logic where it says TODO, then run:
     python3 tools/plctest.py 10-structured-text/labs/starter/10-3-strapping-table.st *)

PROGRAM StrappingTable
  VAR (* interface *)
    Level      : REAL;   (* measured level, m (already scaled from the 4-20 mA signal) *)
    Volume     : REAL;   (* volume in the tank, m3 *)
    OutOfTable : BOOL;   (* TRUE when Level is below the first or above the last breakpoint *)
    (* Strapping table of a horizontal cylindrical tank, 2.0 m diameter and
       5.0 m long (15.708 m3 when full). The test may load other tables. *)
    LevelBP  : ARRAY[1..9] OF REAL := [0.0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    VolumeBP : ARRAY[1..9] OF REAL := [0.0, 1.133, 3.071, 5.380, 7.854, 10.328, 12.637, 14.575, 15.708];
  END_VAR
  VAR (* add your own working variables here *)
    i : INT;
  END_VAR

  (* TODO: clamp outside the table and set OutOfTable; otherwise find the
     segment that contains Level and interpolate between its two ends.
     You may write a FUNCTION for the lookup (see the lesson), or put the
     loop here in the program. *)
  Volume := 0.0;
  OutOfTable := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : StrappingTable;
  END_RESOURCE
END_CONFIGURATION
