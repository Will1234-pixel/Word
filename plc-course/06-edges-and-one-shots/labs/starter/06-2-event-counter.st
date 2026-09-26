(* Lab 06-2: Carton and product-change counter (event counting and change-of-value).
   Module 06 (Edge detection and one-shots). STARTER - the declarations are done
   for you; write the logic where it says TODO, then run:
     python3 tools/plctest.py 06-edges-and-one-shots/labs/starter/06-2-event-counter.st *)

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
  VAR (* internal - add your own variables here: edge detectors, "previous
         value" variables, a first-scan flag ... *)
    Spare : BOOL;
  END_VAR

  (* TODO: replace these placeholders with your logic.
     - PartCount: +1 for every carton that ARRIVES at the photo-eye.
     - SelChanges: +1 for every change of ProductSel.
     - The input values present at power-up are not events.
     - ResetPB: counts are 0 while it is held; nothing is counted meanwhile,
       and nothing is counted "late" when it is released. *)
  PartCount := 0;
  SelChanges := 0;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : EventCounter;
  END_RESOURCE
END_CONFIGURATION
