(* Lab 08-3: Production counts - good/reject counters, total, yield, shift reset.
   Module 08 (Counters). REFERENCE SOLUTION - try the lab yourself first.

   The counts are kept with ADD (Count := Count + 1 on an edge) rather than
   with CTU blocks. A CTU's reset input wins over its count input, so a pack
   that arrives in the very scan of the shift reset would be lost. Here the
   shift change is handled first and the counting afterwards, so no pack is
   ever lost. There is no preset to reach, so a CTU would add nothing. *)

PROGRAM ProductionCounts
  VAR (* I/O - addresses follow the OpenPLC convention *)
    GoodPE       AT %IX0.0 : BOOL;  (* Photo-eye on the outfeed: TRUE while an accepted pack is in the beam *)
    RejectPE     AT %IX0.1 : BOOL;  (* Photo-eye on the reject chute: TRUE while a rejected pack passes *)
    ShiftResetPB AT %IX0.2 : BOOL;  (* Shift-change push-button, NO *)
    LowYieldLamp AT %QX0.0 : BOOL;  (* Low-yield warning lamp on the line *)
  END_VAR
  VAR (* HMI settings - part of the lab interface *)
    MinSample  : DINT := 20;        (* no yield warning until this many packs this shift *)
    YieldLimit : REAL := 95.0;      (* warn when the yield is below this, % *)
  END_VAR
  VAR RETAIN (* HMI displays that must survive a power cut *)
    GoodCount       : DINT;         (* accepted packs this shift *)
    RejectCount     : DINT;         (* rejected packs this shift *)
    LastShiftGood   : DINT;         (* snapshot taken at the last shift change *)
    LastShiftReject : DINT;
    LastShiftYield  : REAL;
    LifetimeTotal   : DINT;         (* every pack since commissioning: no reset *)
  END_VAR
  VAR (* HMI displays, recalculated every scan *)
    TotalCount : DINT;              (* GoodCount + RejectCount *)
    YieldPct   : REAL;              (* 100 x good / total; 0.0 while the total is 0 *)
  END_VAR
  VAR CONSTANT
    DINT_MAX : DINT := 2147483647;  (* largest DINT: 2^31 - 1 *)
  END_VAR
  VAR (* internal *)
    GoodIn    : R_TRIG;             (* an accepted pack has just arrived *)
    RejectIn  : R_TRIG;             (* a rejected pack has just arrived *)
    ShiftEdge : R_TRIG;             (* the shift button has just been pressed *)
  END_VAR

  (* 1. Edge detection, every scan. *)
  GoodIn(CLK := GoodPE);
  RejectIn(CLK := RejectPE);
  ShiftEdge(CLK := ShiftResetPB);

  (* 2. Shift change, on the PRESS of the button only. Holding the button
        must not repeat it, or the next scan would copy the fresh zeros over
        the snapshot. Snapshot first, then clear. YieldPct still holds the
        value calculated at the end of the previous scan from these same
        counts, so it is the finished shift's yield. *)
  IF ShiftEdge.Q THEN
    LastShiftGood := GoodCount;
    LastShiftReject := RejectCount;
    LastShiftYield := YieldPct;
    GoodCount := 0;
    RejectCount := 0;
  END_IF;

  (* 3. Counting, after the shift change, so a pack arriving in the same scan
        as the reset counts in the new shift. Independent IFs: a good pack
        and a reject can arrive in the same scan. *)
  IF GoodIn.Q THEN
    GoodCount := GoodCount + 1;
  END_IF;
  IF RejectIn.Q THEN
    RejectCount := RejectCount + 1;
  END_IF;

  (* The lifetime total must never wrap round to a negative number: it stops
     at the largest DINT. (At 10 packs a second that takes about 6.8 years.) *)
  IF GoodIn.Q AND LifetimeTotal < DINT_MAX THEN
    LifetimeTotal := LifetimeTotal + 1;
  END_IF;
  IF RejectIn.Q AND LifetimeTotal < DINT_MAX THEN
    LifetimeTotal := LifetimeTotal + 1;
  END_IF;

  (* 4. Total and yield. Convert to REAL BEFORE dividing: in integer maths
        2 / 3 = 0. And never divide by zero: at power-up and just after a
        shift change the total is 0. *)
  TotalCount := GoodCount + RejectCount;
  IF TotalCount > 0 THEN
    YieldPct := 100.0 * DINT_TO_REAL(GoodCount) / DINT_TO_REAL(TotalCount);
  ELSE
    YieldPct := 0.0;
  END_IF;

  (* 5. A yield worked out from a handful of packs means little (one reject
        in the first pack of the shift is "0 %"), so only warn once the
        sample is big enough. *)
  LowYieldLamp := (TotalCount >= MinSample) AND (YieldPct < YieldLimit);
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : ProductionCounts;
  END_RESOURCE
END_CONFIGURATION
