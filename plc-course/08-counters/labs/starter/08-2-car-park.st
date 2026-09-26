(* Lab 08-2: Car park up/down counter with capacity, FULL sign and manual preset.
   Module 08 (Counters). STARTER - the declarations are done for you;
   write the logic where it says TODO, then run:
     python3 tools/plctest.py 08-counters/labs/starter/08-2-car-park.st *)

PROGRAM CarPark
  VAR (* I/O - addresses follow the OpenPLC convention *)
    EntryLoop AT %IX0.0 : BOOL;  (* Vehicle detector, entry lane: TRUE while a car is over the loop *)
    ExitLoop  AT %IX0.1 : BOOL;  (* Vehicle detector, exit lane: TRUE while a car is over the loop *)
    PresetPB  AT %IX0.2 : BOOL;  (* Attendant's preset push-button, NO: load PresetValue into the count *)
    FullSign  AT %QX0.0 : BOOL;  (* "FULL" sign at the entrance *)
  END_VAR
  VAR (* HMI settings and displays - part of the lab interface *)
    Capacity    : INT := 50;     (* number of parking spaces *)
    PresetValue : INT;           (* cars the attendant counted by walking round *)
    SpacesFree  : INT;           (* for the "spaces" sign: never negative *)
  END_VAR
  VAR RETAIN (* the cars do not leave when the power fails *)
    CarCount    : INT;           (* cars in the car park *)
  END_VAR
  VAR (* internal - add your own variables here: edge detectors or a
         counter block ... *)
    Spare : BOOL;
  END_VAR

  (* TODO: replace these placeholders with your logic.
     - CarCount: +1 per car arriving on EntryLoop, -1 per car arriving on
       ExitLoop. Never below 0. It may go ABOVE Capacity.
     - FullSign when CarCount >= Capacity; SpacesFree never negative.
     - PresetPB loads PresetValue (negative counts as 0). *)
  CarCount := 0;
  FullSign := FALSE;
  SpacesFree := 0;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : CarPark;
  END_RESOURCE
END_CONFIGURATION
