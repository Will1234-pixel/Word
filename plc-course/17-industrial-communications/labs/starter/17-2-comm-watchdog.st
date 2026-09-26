(* Lab 17-2: Communication watchdog for a reservoir telemetry link.
   Module 17 (Industrial communications). STARTER - the declarations are done for you;
   write the logic where it says TODO, then run:
     python3 tools/plctest.py 17-industrial-communications/labs/starter/17-2-comm-watchdog.st

   Pump station PS-1 fills reservoir R-2 over a radio link. The Modbus client polls the
   reservoir outstation about once a second and leaves the last values it received in
   %IW100..%IW102, so if the link fails those values simply FREEZE.

   This is a training exercise, not a design for a real overfill protection. *)

PROGRAM CommWatchdog
  VAR (* data from the reservoir outstation, placed here by the Modbus client *)
    RxHeartbeat AT %IW100 : INT;    (* outstation heartbeat: +1 every second *)
    RxLevel     AT %IW101 : INT;    (* reservoir level, % x 10 (0..1000) *)
    RxStatus    AT %IW102 : WORD;   (* bit 0: reservoir inlet valve open *)
  END_VAR
  VAR (* data to the outstation *)
    TxHeartbeat AT %QW100 : INT;    (* our heartbeat: +1 every second *)
  END_VAR
  VAR (* field output *)
    FillPump AT %QX0.0 : BOOL;      (* fill pump P-1 run command *)
  END_VAR
  VAR (* results *)
    CommLost  : BOOL := TRUE;       (* TRUE: the received data cannot be trusted *)
    LossCount : INT;                (* number of healthy -> lost transitions *)
    LevelPct  : REAL := 100.0;      (* level used by the control logic, % *)
    InletOpen : BOOL;               (* inlet valve state used by the control logic *)
  END_VAR
  VAR
    (* TODO: add the timers and other internal variables you need here. *)
    LastBeat : INT;                 (* heartbeat value seen on the previous scan *)
  END_VAR

  (* TODO 1: our own heartbeat: TxHeartbeat + 1 every second; after 32767 it goes to 0.
     TODO 2: supervise RxHeartbeat: CommLost TRUE 3 s after the last change; FALSE again
             only after the heartbeat has kept changing for 5 s. Count each loss once.
     TODO 3: LevelPct / InletOpen: live values, or the fallback values while CommLost.
     TODO 4: FillPump: start below 40 %, stop at 90 %, stop if CommLost or inlet closed.
     Replace these placeholder lines with your logic. *)
  LastBeat := RxHeartbeat;
  FillPump := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : CommWatchdog;
  END_RESOURCE
END_CONFIGURATION
