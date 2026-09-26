(* Lab 04-2: Forward/reverse motor with interlocks and travel limits.
   Module 04 (Ladder logic fundamentals).
   STARTER - the declarations are done for you; write the logic where it
   says TODO, then run:
     python3 tools/plctest.py 04-ladder-logic/labs/starter/04-2-forward-reverse.st
   A real reversing starter also has electrical and mechanical interlocks
   between its contactors. Training exercise only. *)

PROGRAM ForwardReverse
  VAR (* I/O - addresses follow the OpenPLC convention *)
    FwdPB         AT %IX0.0 : BOOL;  (* Forward push-button, NO: TRUE while pressed *)
    RevPB         AT %IX0.1 : BOOL;  (* Reverse push-button, NO: TRUE while pressed *)
    StopPB_NC     AT %IX0.2 : BOOL;  (* Stop push-button, NC: TRUE while NOT pressed *)
    FwdLimitOK_NC AT %IX0.3 : BOOL;  (* Forward end-of-travel limit switch, NC: TRUE while NOT at the limit *)
    RevLimitOK_NC AT %IX0.4 : BOOL;  (* Reverse end-of-travel limit switch, NC: TRUE while NOT at the limit *)
    OverloadOK_NC AT %IX0.5 : BOOL;  (* Overload relay auxiliary contact, NC: TRUE while healthy *)
    FwdK          AT %QX0.0 : BOOL;  (* Forward contactor coil *)
    RevK          AT %QX0.1 : BOOL;  (* Reverse contactor coil *)
  END_VAR

  (* TODO: replace these placeholder lines with your logic.
     Start from two seal-in rungs, one per direction. Then ask, for every
     contact: does it belong in the start branch or in series with the whole
     rung? Which limit switch belongs to which direction?
     (MATIEC needs at least one statement in a program body.) *)
  FwdK := FALSE;
  RevK := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : ForwardReverse;
  END_RESOURCE
END_CONFIGURATION
