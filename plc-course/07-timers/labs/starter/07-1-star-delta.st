(* Lab 07-1: Star-delta starter.
   Module 07 (Timers). STARTER - the declarations are done for you;
   write the logic where it says TODO, then run:
     python3 tools/plctest.py 07-timers/labs/starter/07-1-star-delta.st *)

PROGRAM StarDelta
  VAR (* I/O *)
    StartPB       AT %IX0.0 : BOOL;  (* Start push-button, NO: TRUE while pressed *)
    StopPB_NC     AT %IX0.1 : BOOL;  (* Stop push-button, NC: TRUE while NOT pressed *)
    OverloadOK_NC AT %IX0.2 : BOOL;  (* Overload relay contact, NC: TRUE while healthy *)
    MainK         AT %QX0.0 : BOOL;  (* Main (line) contactor *)
    StarK         AT %QX0.1 : BOOL;  (* Star contactor *)
    DeltaK        AT %QX0.2 : BOOL;  (* Delta contactor *)
  END_VAR
  VAR (* settings, e.g. written from an HMI *)
    StarTime : TIME := T#5s;         (* how long the motor starts in star *)
  END_VAR
  VAR (* internal - you may add more variables here *)
    StarTimer : TON;                 (* times the star period *)
    GapTimer  : TON;                 (* changeover dead time, star off -> delta on *)
  END_VAR

  (* TODO: replace these placeholder lines with your logic.
     1. Run latch for MainK (Start, Stop, overload).
     2. StarTimer: star period of StarTime.
     3. GapTimer: 100 ms with both star and delta off.
     4. DeltaK after the gap. Call each timer once per scan, unconditionally. *)
  MainK := FALSE;
  StarK := FALSE;
  DeltaK := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : StarDelta;
  END_RESOURCE
END_CONFIGURATION
