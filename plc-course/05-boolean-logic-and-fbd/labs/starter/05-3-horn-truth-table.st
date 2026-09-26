(* Lab 05-3: From truth table to minimal logic - wet-well alarm horn.
   Module 05 (Boolean logic and FBD). STARTER - the declarations are done for you;
   write the logic where it says TODO, then run:
     python3 tools/plctest.py 05-boolean-logic-and-fbd/labs/starter/05-3-horn-truth-table.st

   Work from the truth table in the lesson (Lab 05-3). Draw the K-map on paper
   first and write your minimal expression in this comment:

     Horn = ...
*)

PROGRAM WetWellHorn
  VAR (* I/O - addresses follow the OpenPLC convention *)
    HighLevel AT %IX0.0 : BOOL;  (* High-level float relay: TRUE = level high *)
    LowLevel  AT %IX0.1 : BOOL;  (* Low-level float relay: TRUE = level low *)
    Pump1Run  AT %IX0.2 : BOOL;  (* Pump 1 running (contactor auxiliary contact) *)
    Pump2Run  AT %IX0.3 : BOOL;  (* Pump 2 running (contactor auxiliary contact) *)
    Horn      AT %QX0.0 : BOOL;  (* Wet-well alarm horn *)
  END_VAR

  (* TODO: replace this placeholder line with your minimal logic.
     (MATIEC needs at least one statement in a program body.) *)
  Horn := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : WetWellHorn;
  END_RESOURCE
END_CONFIGURATION
