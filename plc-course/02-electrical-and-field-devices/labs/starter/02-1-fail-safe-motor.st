(* Lab 02-1: Fail-safe motor circuit - NC stop and overload contacts.
   Module 02 (Electrical fundamentals and field devices).
   STARTER - the declarations are done for you; write the logic where it
   says TODO, then run:
     python3 tools/plctest.py 02-electrical-and-field-devices/labs/starter/02-1-fail-safe-motor.st
   Training exercise only: a real machine's emergency stop and safety
   functions are hard-wired or use safety-rated devices (Module 20). *)

PROGRAM FailSafeMotor
  VAR (* I/O - addresses follow the OpenPLC convention *)
    StartPB       AT %IX0.0 : BOOL;  (* Start push-button -S2, NO: TRUE while pressed *)
    StopPB_NC     AT %IX0.1 : BOOL;  (* Stop push-button -S1, NC: TRUE while NOT pressed *)
    OverloadOK_NC AT %IX0.2 : BOOL;  (* Overload relay -F2 contact 95-96, NC: TRUE while healthy *)
    Motor         AT %QX0.0 : BOOL;  (* Motor contactor -Q1 coil (through an interposing relay) *)
    TripLamp      AT %QX0.1 : BOOL;  (* Amber "overload tripped" lamp -H2 *)
  END_VAR

  (* TODO: replace these placeholder lines with your logic.
     Think about what each NC input reads when its wire breaks.
     (MATIEC needs at least one statement in a program body.) *)
  Motor := FALSE;
  TripLamp := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : FailSafeMotor;
  END_RESOURCE
END_CONFIGURATION
