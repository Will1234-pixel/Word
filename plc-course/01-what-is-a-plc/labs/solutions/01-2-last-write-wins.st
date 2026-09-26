(* Lab 01-2: Last write wins - fix a sump pump program that writes its
   outputs in two places.
   Module 01 (What is a PLC?). REFERENCE SOLUTION - try the lab yourself first. *)

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
  VAR (* internal *)
    HandRun  : BOOL;  (* HAND asks the pump to run *)
    AutoRun  : BOOL;  (* AUTO asks the pump to run *)
    HHAlarm  : BOOL;  (* high-high level (or a broken LSHH wire) *)
    OLAlarm  : BOOL;  (* pump overload tripped (or a broken wire) *)
  END_VAR

  (* The bug in the original program: Pump and AlarmLamp were each written in
     two places. The PLC executes the program from top to bottom, and only the
     value a variable holds at the END of the scan reaches the output module,
     so the later rung always won and the earlier one was lost:
       - in AUTO, rung 3 (HAND) wrote Pump := FALSE after rung 1 had set it;
       - rung 4 (overload) overwrote the high-high alarm from rung 2.

     The fix: work out each CONDITION on its own line (these are ordinary
     internal variables, written once each), then write each OUTPUT exactly
     once, combining the conditions. Anyone reading the program now finds
     everything that drives Pump in one place. *)

  (* Conditions *)
  HandRun := HandSel;
  AutoRun := AutoSel AND LevelHigh;
  HHAlarm := NOT LevelHH_NC;       (* NC contact: FALSE means high-high or a broken wire *)
  OLAlarm := NOT OverloadOK_NC;    (* NC contact: FALSE means tripped or a broken wire *)

  (* Outputs - one assignment each. Note the brackets: AND binds more tightly
     than OR, so without them the overload would only stop the AUTO branch. *)
  Pump      := (HandRun OR AutoRun) AND OverloadOK_NC;
  AlarmLamp := HHAlarm OR OLAlarm;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : SumpPump;
  END_RESOURCE
END_CONFIGURATION
