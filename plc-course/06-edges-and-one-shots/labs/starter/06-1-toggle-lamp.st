(* Lab 06-1: One-button floodlight toggle (push-on / push-off).
   Module 06 (Edge detection and one-shots). STARTER - the declarations are done
   for you; write the logic where it says TODO, then run:
     python3 tools/plctest.py 06-edges-and-one-shots/labs/starter/06-1-toggle-lamp.st *)

PROGRAM ToggleLamp
  VAR (* I/O - addresses follow the OpenPLC convention *)
    LightPB      AT %IX0.0 : BOOL;  (* Floodlight push-button, NO: TRUE while pressed *)
    LightsEnable AT %IX0.1 : BOOL;  (* Gatehouse key switch: TRUE = bay lighting enabled *)
    Floodlight   AT %QX0.0 : BOOL;  (* Floodlight contactor coil *)
  END_VAR
  VAR (* internal - add your own variables here (an R_TRIG instance, or a
         "previous value" bit) *)
    Spare : BOOL;
  END_VAR

  (* TODO: replace this placeholder with your logic.
     Each PRESS of LightPB must toggle Floodlight, however long it is held.
     LightsEnable = FALSE forces the light off and ignores the button. *)
  Floodlight := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : ToggleLamp;
  END_RESOURCE
END_CONFIGURATION
