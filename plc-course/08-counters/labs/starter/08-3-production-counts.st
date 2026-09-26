(* Lab 08-3: Production counts - good/reject counters, total, yield, shift reset.
   Module 08 (Counters). STARTER - the declarations are done for you;
   write the logic where it says TODO, then run:
     python3 tools/plctest.py 08-counters/labs/starter/08-3-production-counts.st *)

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
  VAR (* internal - add your own variables here: edge detectors, constants ... *)
    Spare : BOOL;
  END_VAR

  (* TODO: replace these placeholders with your logic.
     - Count good packs and rejects (one per pack), and every pack into
       LifetimeTotal, which must never wrap round.
     - TotalCount and YieldPct (a REAL; 0.0 while TotalCount is 0).
     - On a PRESS of ShiftResetPB: copy the shift figures into the LastShift
       variables, then start the shift counts again from zero.
     - LowYieldLamp: at least MinSample packs AND YieldPct below YieldLimit. *)
  TotalCount := 0;
  YieldPct := 0.0;
  LowYieldLamp := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : ProductionCounts;
  END_RESOURCE
END_CONFIGURATION
