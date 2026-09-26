(* Lab 23-1: Find the bugs - transfer conveyor with jog and jam detection.
   Module 23 (Commissioning and troubleshooting). REFERENCE SOLUTION - try the lab yourself first.

   This is the starter program with its three bugs fixed. Each fix is marked
   "FIX 1", "FIX 2" or "FIX 3" so you can compare it with your own repair.
   Everything else is unchanged: in a real plant you fix the fault, not rewrite
   the program. *)

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

  (* ---- 1. Jam detection -------------------------------------------------
     FIX 2: the timer is called on EVERY scan, outside any IF. The running
     condition has moved into IN, so the timer resets as soon as the conveyor
     stops or the beam clears. A timer that is not called cannot reset: in the
     starter it kept its old state while the conveyor was stopped. *)
  JamTimer(IN := RunLatch AND JamPE, PT := T#3s);

  (* ---- 2. Fault latch: set by the cause, reset only when the cause has gone *)
  IF JamTimer.Q OR NOT OverloadOK_NC THEN
    Fault := TRUE;
  ELSIF ResetPB AND NOT JamPE AND OverloadOK_NC THEN
    Fault := FALSE;
  END_IF;

  (* ---- 3. Automatic run latch --------------------------------------------
     FIX 3: a fault now drops the run latch. In the starter the latch stayed
     set during a fault, so pressing Reset restarted the conveyor by itself. *)
  RunLatch := (StartPB OR RunLatch) AND StopPB_NC AND NOT Fault;

  (* ---- 4. Jog for maintenance: momentary, only when stopped and healthy *)
  JogRun := JogPB AND StopPB_NC AND NOT RunLatch AND NOT Fault;

  (* ---- 5. Outputs --------------------------------------------------------
     FIX 1: the motor output is written in exactly ONE place. In the starter it
     was assigned twice ("double coil") and the jog line, being last, won. *)
  ConveyorMotor := RunLatch OR JogRun;
  RunLamp := RunLatch;
  FaultLamp := Fault;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : TransferConveyor;
  END_RESOURCE
END_CONFIGURATION
