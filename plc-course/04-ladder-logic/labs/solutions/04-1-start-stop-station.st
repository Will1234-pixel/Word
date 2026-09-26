(* Lab 04-1: Start/stop from two stations (local and remote).
   Module 04 (Ladder logic fundamentals).
   REFERENCE SOLUTION - try the lab yourself first.
   The same logic drawn as ladder rungs is in the Module 04 README (Lab 04-1).
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

  (* Rung 1 - pump motor, seal-in from two stations.
     Starts in PARALLEL (OR): either station can start the pump, and the
     motor's own bit in parallel with them holds it on (the seal-in).
     Stops in SERIES (AND): either station can stop it.
     Both stop buttons are wired NC, so each reads TRUE while it is healthy
     and not pressed. They are examined with NORMALLY-OPEN contacts in ladder
     (XIC), which is why there is no NOT in front of them here.
     The stops are outside the OR, so a stop beats a start that is held at
     the other station (stop-dominant). *)
  Motor := (LocalStartPB OR RemoteStartPB OR Motor)
           AND LocalStopPB_NC AND RemoteStopPB_NC;

  (* Rungs 2 and 3 - lamps. They come after rung 1, so they show the motor
     state from THIS scan, not the previous one. StoppedLamp uses a
     normally-closed contact on an internal bit: here NOT is exactly right. *)
  RunLamp := Motor;
  StoppedLamp := NOT Motor;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : TwoStationStart;
  END_RESOURCE
END_CONFIGURATION
