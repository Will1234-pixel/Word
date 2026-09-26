(* Lab 23-1: Find the bugs - transfer conveyor with jog and jam detection.
   Module 23 (Commissioning and troubleshooting). STARTER - this program is
   complete and it compiles, but the site has reported three faults and the
   acceptance test fails. Run it to see the failures:
     python3 tools/plctest.py 23-commissioning-and-troubleshooting/labs/starter/23-1-find-the-bugs.st
   Copy it to your own folder, find the three bugs and fix them with the
   smallest change that removes each root cause. Don't rewrite the program. *)

PROGRAM TransferConveyor
  VAR (* I/O - addresses follow the OpenPLC convention *)
    StartPB       AT %IX0.0 : BOOL;  (* Start push-button, NO: TRUE while pressed *)
    StopPB_NC     AT %IX0.1 : BOOL;  (* Stop push-button, NC: TRUE while NOT pressed *)
    JogPB         AT %IX0.2 : BOOL;  (* Jog push-button, NO: conveyor runs only while held *)
    JamPE         AT %IX0.3 : BOOL;  (* Jam photo-eye at the discharge: TRUE while the beam is blocked *)
    ResetPB       AT %IX0.4 : BOOL;  (* Fault reset push-button, NO *)
    OverloadOK_NC AT %IX0.5 : BOOL;  (* Motor overload relay auxiliary contact, NC: TRUE while healthy *)
    ConveyorMotor AT %QX0.0 : BOOL;  (* Conveyor motor contactor coil *)
    RunLamp       AT %QX0.1 : BOOL;  (* Green lamp: running in automatic *)
    FaultLamp     AT %QX0.2 : BOOL;  (* Red lamp: a fault is latched *)
  END_VAR
  VAR (* internal *)
    RunLatch : BOOL;  (* automatic run, sealed in by Start *)
    JogRun   : BOOL;  (* jog command *)
    Fault    : BOOL;  (* latched fault: jam or motor overload *)
    JamTimer : TON;   (* photo-eye blocked for too long while running = jam *)
  END_VAR

  (* ---- 1. Jam detection: only needed while the conveyor runs ------------ *)
  IF RunLatch THEN
    JamTimer(IN := JamPE, PT := T#3s);
  END_IF;

  (* ---- 2. Fault latch: set by the cause, reset only when the cause has gone *)
  IF JamTimer.Q OR NOT OverloadOK_NC THEN
    Fault := TRUE;
  ELSIF ResetPB AND NOT JamPE AND OverloadOK_NC THEN
    Fault := FALSE;
  END_IF;

  (* ---- 3. Automatic run: Start seals in, Stop (or a broken stop wire) drops it *)
  RunLatch := (StartPB OR RunLatch) AND StopPB_NC;
  ConveyorMotor := RunLatch AND NOT Fault;

  (* ---- 4. Jog for maintenance: momentary, only when stopped and healthy *)
  JogRun := JogPB AND StopPB_NC AND NOT RunLatch AND NOT Fault;
  ConveyorMotor := JogRun;

  (* ---- 5. Lamps *)
  RunLamp := RunLatch AND NOT Fault;
  FaultLamp := Fault;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : TransferConveyor;
  END_RESOURCE
END_CONFIGURATION
