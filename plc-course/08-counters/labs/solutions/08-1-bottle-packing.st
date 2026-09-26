(* Lab 08-1: Bottle packing - count bottles into a box, index the full box, start again.
   Module 08 (Counters). REFERENCE SOLUTION - try the lab yourself first.

   Idea: one CTU counts bottles and its Q says "box full". A TP turns that
   moment into a box-conveyor run of exactly IndexTime. While the TP runs,
   the counter's R input is held TRUE, so the count restarts from zero and
   anything the photo-eye sees during the index is ignored.

   Another correct design keeps the count at BoxSize during the index and
   resets it when the index ends. The lab allows either. *)

PROGRAM BottlePacking
  VAR (* I/O - addresses follow the OpenPLC convention *)
    BottlePE   AT %IX0.0 : BOOL;  (* Photo-eye at the end of the infeed: TRUE while a bottle blocks the beam *)
    ResetPB    AT %IX0.1 : BOOL;  (* Count reset push-button, NO: the operator has fitted a new, empty box *)
    InfeedConv AT %QX0.0 : BOOL;  (* Infeed conveyor motor: carries bottles into the box *)
    BoxConv    AT %QX0.1 : BOOL;  (* Box conveyor motor: moves the full box out and an empty one in *)
  END_VAR
  VAR (* HMI settings and displays - part of the lab interface *)
    BoxSize     : INT := 12;      (* bottles per box, 1..48 *)
    IndexTime   : TIME := T#2s;   (* how long the box conveyor runs to index one box *)
    BottleCount : INT;            (* bottles counted into the box being filled *)
  END_VAR
  VAR RETAIN (* a production total: on a real PLC it must survive a power cut *)
    BoxesPacked : DINT;           (* full boxes; ResetPB does not touch it *)
  END_VAR
  VAR (* internal *)
    BottleCtr  : CTU;             (* counts bottles into the current box *)
    IndexPulse : TP;              (* runs the box conveyor for IndexTime *)
    BoxFull    : R_TRIG;          (* TRUE for one scan when a box becomes full *)
    CtrPV      : INT;             (* BoxSize, kept inside 1..48 *)
  END_VAR

  (* A preset of 0 or less would make the counter "full" with no bottles at
     all, and the box conveyor would index for ever. Guard the HMI value. *)
  CtrPV := LIMIT(1, BoxSize, 48);

  (* 1. Count bottles. CTU counts RISING edges of CU, so a bottle that stops
        in the beam is still one bottle. R wins over CU: while the operator
        holds Reset, or while the box is indexing, the count is held at zero
        and the counter's internal edge memory still follows the photo-eye.
        So a bottle that is in the beam when R is released is NOT counted
        again. (IndexPulse.Q is last scan's value here: the reset starts one
        scan after the box becomes full.) *)
  BottleCtr(CU := BottlePE, R := ResetPB OR IndexPulse.Q, PV := CtrPV);
  BottleCount := BottleCtr.CV;

  (* 2. Box full. Q is TRUE from the scan the count reaches the preset. It
        drops again on the next scan, when R clears the count, but a TP only
        needs a rising edge on IN: it then runs for exactly PT. *)
  IndexPulse(IN := BottleCtr.Q, PT := IndexTime);
  BoxConv := IndexPulse.Q;

  (* 3. Production total: one per full box, on the rising edge of "full". *)
  BoxFull(CLK := BottleCtr.Q);
  IF BoxFull.Q THEN
    BoxesPacked := BoxesPacked + 1;
  END_IF;

  (* 4. The infeed stops in the same scan as the last bottle is counted, stays
        stopped while the box indexes, and stops while the operator resets the
        count so that no bottle can drop into the box uncounted. *)
  InfeedConv := NOT (BottleCtr.Q OR IndexPulse.Q OR ResetPB);
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : BottlePacking;
  END_RESOURCE
END_CONFIGURATION
