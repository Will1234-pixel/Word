(* Lab 02-1: Fail-safe motor circuit - NC stop and overload contacts.
   Module 02 (Electrical fundamentals and field devices).
   REFERENCE SOLUTION - try the lab yourself first.
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

  (* Both NC inputs read TRUE when everything is healthy. A pressed button, a
     tripped overload, a broken wire, a loose terminal or a blown fuse all make
     them read FALSE, so every one of those faults stops the motor. That is
     the point of NC wiring: the "healthy" state has to be actively proven by
     current flowing, so any break in the circuit fails safe.

     Seal-in with both stop conditions in series (AND) with the whole rung:
     when either NC input goes FALSE, Motor drops out and the seal-in is lost.
     When the overload is reset later, nothing restarts: Motor is FALSE and
     only a fresh press of Start can set it again. *)
  Motor := (StartPB OR Motor) AND StopPB_NC AND OverloadOK_NC;

  (* The lamp shows the overload (or its wiring) is not healthy. *)
  TripLamp := NOT OverloadOK_NC;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : FailSafeMotor;
  END_RESOURCE
END_CONFIGURATION
