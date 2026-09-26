(* Lab 06-2: Carton and product-change counter (event counting and change-of-value).
   Module 06 (Edge detection and one-shots). REFERENCE SOLUTION - try the lab yourself first. *)

PROGRAM EventCounter
  VAR (* I/O - addresses follow the OpenPLC convention *)
    PartPE  AT %IX0.0 : BOOL;  (* Photo-eye: TRUE while a carton blocks the beam *)
    ResetPB AT %IX0.1 : BOOL;  (* Count reset push-button, NO: TRUE while pressed *)
  END_VAR
  VAR (* HMI values - part of the lab interface *)
    ProductSel : INT;          (* Product number selected by the operator on the HMI, 1..4 *)
    PartCount  : DINT;         (* Cartons counted since the last reset *)
    SelChanges : INT;          (* Changes of ProductSel since the last reset *)
  END_VAR
  VAR (* internal *)
    PartArrived : R_TRIG;      (* rising edge of the photo-eye = a carton has arrived *)
    SelPrev     : INT;         (* ProductSel as it was on the previous scan *)
    SelChanged  : BOOL;        (* TRUE for the one scan in which ProductSel changed *)
    Started     : BOOL;        (* FALSE at power-up, TRUE from the end of the first scan (not RETAIN) *)
    FirstScan   : BOOL;        (* TRUE during the first scan only *)
  END_VAR

  (* 1. Home-made first-scan flag. Started is not retentive, so it is FALSE
        after every power-up and FirstScan is TRUE for exactly one scan. *)
  FirstScan := NOT Started;
  Started := TRUE;

  (* 2. Edge and change detection run on EVERY scan, outside any IF, so their
        memories always follow the inputs - also while Reset is held. *)
  PartArrived(CLK := PartPE);

  SelChanged := ProductSel <> SelPrev;
  SelPrev := ProductSel;               (* remember for the next scan - always LAST *)

  (* 3. Whatever the inputs are at power-up is the starting point, not an event:
        a carton already blocking the beam has not just "arrived", and the
        selector's power-up position is not a change. *)
  IF FirstScan THEN
    SelChanged := FALSE;
  END_IF;

  (* 4. Counting. Reset is level-sensitive and has priority: while it is held
        the counts stay at zero and events are discarded. *)
  IF ResetPB THEN
    PartCount := 0;
    SelChanges := 0;
  ELSE
    IF PartArrived.Q AND NOT FirstScan THEN
      PartCount := PartCount + 1;
    END_IF;
    IF SelChanged THEN
      SelChanges := SelChanges + 1;
    END_IF;
  END_IF;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : EventCounter;
  END_RESOURCE
END_CONFIGURATION
