(* Lab 08-1: Bottle packing - count bottles into a box, index the full box, start again.
   Module 08 (Counters). STARTER - the declarations are done for you;
   write the logic where it says TODO, then run:
     python3 tools/plctest.py 08-counters/labs/starter/08-1-bottle-packing.st *)

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
  VAR (* internal - add your own variables here: a counter, a timer,
         edge detectors ... *)
    Spare : BOOL;
  END_VAR

  (* TODO: replace these placeholders with your logic.
     - Count bottles (rising edges of BottlePE) into BottleCount.
     - When BottleCount reaches BoxSize: stop the infeed at once, run the box
       conveyor for IndexTime, add one to BoxesPacked.
     - When the index ends: count from zero again and restart the infeed.
     - ResetPB: count held at zero and infeed stopped while it is held. *)
  InfeedConv := FALSE;
  BoxConv := FALSE;
  BottleCount := 0;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : BottlePacking;
  END_RESOURCE
END_CONFIGURATION
