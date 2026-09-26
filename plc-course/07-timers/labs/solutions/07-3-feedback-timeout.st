(* Lab 07-3: Motor with run-feedback monitoring.
   Module 07 (Timers). REFERENCE SOLUTION - try the lab yourself first.

   Two supervision timers compare what we ASK the motor to do (MotorRun)
   with what it REPORTS (RunFbk):
     - fail to start: no feedback within StartTimeout of the start,
     - feedback lost: feedback was proven, then missing for LossDelay.
   A fault latches, stops the motor, and can be reset only while the run
   command is off, so a reset can never restart the motor by surprise. *)

PROGRAM FeedbackTimeout
  VAR (* I/O *)
    RunCmd    AT %IX0.0 : BOOL;  (* run request (maintained), TRUE = run *)
    RunFbk    AT %IX0.1 : BOOL;  (* running feedback: contactor aux contact or drive "running" *)
    ResetPB   AT %IX0.2 : BOOL;  (* fault reset push-button, NO *)
    MotorRun  AT %QX0.0 : BOOL;  (* contactor coil / drive run command *)
    FaultLamp AT %QX0.1 : BOOL;  (* fault lamp: on while any fault is latched *)
  END_VAR
  VAR (* settings *)
    StartTimeout : TIME := T#3s;     (* time allowed for feedback after a start *)
    LossDelay    : TIME := T#500ms;  (* feedback dropout tolerated while running *)
  END_VAR
  VAR (* alarms for the HMI *)
    FailToStart : BOOL;          (* latched: no feedback after starting *)
    FbkLost     : BOOL;          (* latched: feedback lost while running *)
  END_VAR
  VAR (* internal *)
    Proven     : BOOL;           (* feedback has been seen during this run *)
    StartTimer : TON;            (* supervises the start *)
    LossTimer  : TON;            (* supervises the running motor *)
  END_VAR

  (* 1. "Proven" remembers that feedback arrived during the current run.
        It is cleared whenever the motor is not being commanded, so every new
        start is supervised by the start timer again. MotorRun here is the
        value written at the end of the previous scan. *)
  IF NOT MotorRun THEN
    Proven := FALSE;
  ELSIF RunFbk THEN
    Proven := TRUE;
  END_IF;

  (* 2. Supervision timers. Both are called on every scan; their IN
        conditions decide when they time. *)
  StartTimer(IN := MotorRun AND NOT Proven, PT := StartTimeout);
  LossTimer(IN := MotorRun AND Proven AND NOT RunFbk, PT := LossDelay);

  (* 3. Latch the faults. *)
  IF StartTimer.Q THEN
    FailToStart := TRUE;
  END_IF;
  IF LossTimer.Q THEN
    FbkLost := TRUE;
  END_IF;

  (* 4. Reset, accepted only while the run command is off. *)
  IF ResetPB AND NOT RunCmd THEN
    FailToStart := FALSE;
    FbkLost := FALSE;
  END_IF;

  (* 5. Outputs. *)
  FaultLamp := FailToStart OR FbkLost;
  MotorRun := RunCmd AND NOT FaultLamp;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : FeedbackTimeout;
  END_RESOURCE
END_CONFIGURATION
