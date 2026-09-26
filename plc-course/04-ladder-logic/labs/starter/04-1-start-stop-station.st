(* Lab 04-1: Start/stop from two stations (local and remote).
   Module 04 (Ladder logic fundamentals).
   STARTER - the declarations are done for you; write the logic where it
   says TODO, then run:
     python3 tools/plctest.py 04-ladder-logic/labs/starter/04-1-start-stop-station.st
   Training exercise only: emergency stops are hard-wired or use
   safety-rated devices (Module 20). *)

PROGRAM TwoStationStart
  VAR (* I/O - addresses follow the OpenPLC convention *)
    LocalStartPB    AT %IX0.0 : BOOL;  (* Start at the local station beside the pump, NO: TRUE while pressed *)
    LocalStopPB_NC  AT %IX0.1 : BOOL;  (* Stop at the local station, NC: TRUE while NOT pressed *)
    RemoteStartPB   AT %IX0.2 : BOOL;  (* Start on the control-room panel, NO: TRUE while pressed *)
    RemoteStopPB_NC AT %IX0.3 : BOOL;  (* Stop on the control-room panel, NC: TRUE while NOT pressed *)
    Motor           AT %QX0.0 : BOOL;  (* Pump motor contactor coil *)
    RunLamp         AT %QX0.1 : BOOL;  (* "Running" lamp *)
    StoppedLamp     AT %QX0.2 : BOOL;  (* "Stopped" lamp *)
  END_VAR

  (* TODO: replace these placeholder lines with your logic.
     Sketch the ladder rung first: which contacts go in parallel, which in
     series, and which contact symbol does an NC stop button need?
     (MATIEC needs at least one statement in a program body.) *)
  Motor := FALSE;
  RunLamp := FALSE;
  StoppedLamp := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : TwoStationStart;
  END_RESOURCE
END_CONFIGURATION
