(* Lab 10-3: Tank strapping table - level to volume by piecewise-linear lookup.
   Module 10 (Structured Text). REFERENCE SOLUTION - try the lab yourself first. *)

(* Piecewise-linear interpolation in a table of 9 breakpoints.
   XTable must be strictly increasing. Outside the table the result is
   clamped to the first or last Y value and Clamped is set.

   The tables are VAR_IN_OUT, so they are passed by reference and not
   copied on every call. (MATIEC also cannot pass an array to a FUNCTION as
   a VAR_INPUT; CODESYS and TIA Portal can.) This function only reads them. *)
FUNCTION F_Interpolate : REAL
  VAR_IN_OUT
    XTable : ARRAY[1..9] OF REAL;   (* breakpoints, strictly increasing *)
    YTable : ARRAY[1..9] OF REAL;   (* value at each breakpoint *)
  END_VAR
  VAR_INPUT
    X : REAL;                       (* value to look up *)
  END_VAR
  VAR_OUTPUT
    Clamped : BOOL;                 (* TRUE when X is outside the table *)
  END_VAR
  VAR
    i    : INT;
    Span : REAL;
  END_VAR

  (* Guard clauses first: deal with the edge cases and leave early, so the
     main calculation below needs no extra nesting. *)
  Clamped := FALSE;
  IF X < XTable[1] THEN
    Clamped := TRUE;
    F_Interpolate := YTable[1];
    RETURN;
  END_IF;
  IF X > XTable[9] THEN
    Clamped := TRUE;
    F_Interpolate := YTable[9];
    RETURN;
  END_IF;

  (* Find the first segment whose upper breakpoint is at or above X.
     Segment i runs from XTable[i] to XTable[i + 1]. *)
  FOR i := 1 TO 8 DO
    IF X <= XTable[i + 1] THEN
      Span := XTable[i + 1] - XTable[i];
      IF Span > 0.0 THEN
        F_Interpolate := YTable[i] + (YTable[i + 1] - YTable[i]) * (X - XTable[i]) / Span;
      ELSE
        (* Two equal breakpoints: a typing error in the table. Avoid a
           division by zero and use the upper value. *)
        F_Interpolate := YTable[i + 1];
      END_IF;
      RETURN;   (* found it: later segments must not overwrite the result *)
    END_IF;
  END_FOR;

  (* Only reached if the table is not in increasing order. *)
  F_Interpolate := YTable[9];
END_FUNCTION

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

  Volume := F_Interpolate(XTable := LevelBP, YTable := VolumeBP, X := Level,
                          Clamped => OutOfTable);
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : StrappingTable;
  END_RESOURCE
END_CONFIGURATION
