(* Lab 01-2: Last write wins - fix a sump pump program that writes its
   outputs in two places.
   Module 01 (What is a PLC?). STARTER - this is the plant's CURRENT program
   and it has a bug. It compiles, but it fails the acceptance test:
     python3 tools/plctest.py 01-what-is-a-plc/labs/starter/01-2-last-write-wins.st
   Copy it to your work folder, find out why, and restructure the logic so
   that it meets every requirement in the lab sheet. Keep the interface
   (names, types and addresses) exactly as it is. *)

PROGRAM SumpPump
  VAR (* I/O - addresses follow the OpenPLC convention *)
    HandSel       AT %IX0.0 : BOOL;  (* HAND-OFF-AUTO selector: TRUE in HAND *)
    AutoSel       AT %IX0.1 : BOOL;  (* HAND-OFF-AUTO selector: TRUE in AUTO *)
    LevelHigh     AT %IX0.2 : BOOL;  (* LSH float switch: TRUE while the level is above it *)
    LevelHH_NC    AT %IX0.3 : BOOL;  (* LSHH switch, NC: TRUE while the level is NOT high-high *)
    OverloadOK_NC AT %IX0.4 : BOOL;  (* Pump overload relay contact, NC: TRUE while healthy *)
    Pump          AT %QX0.0 : BOOL;  (* Pump motor contactor coil *)
    AlarmLamp     AT %QX0.1 : BOOL;  (* Red common alarm lamp *)
  END_VAR

  (* Rung 1 - automatic operation (original program).
     In AUTO the pump runs while the high-level float is up. *)
  Pump := AutoSel AND LevelHigh AND OverloadOK_NC;

  (* Rung 2 - high-high level alarm (original program). *)
  AlarmLamp := NOT LevelHH_NC;

  (* Rung 3 - HAND operation, added during a later modification.
     In HAND the pump runs whenever the overload is healthy. *)
  Pump := HandSel AND OverloadOK_NC;

  (* Rung 4 - pump overload alarm, added during the same modification. *)
  AlarmLamp := NOT OverloadOK_NC;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : SumpPump;
  END_RESOURCE
END_CONFIGURATION
