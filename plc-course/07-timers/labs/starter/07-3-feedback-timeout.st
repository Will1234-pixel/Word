(* Lab 07-3: Motor with run-feedback monitoring.
   Module 07 (Timers). STARTER - the declarations are done for you;
   write the logic where it says TODO, then run:
     python3 tools/plctest.py 07-timers/labs/starter/07-3-feedback-timeout.st *)

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
  VAR (* internal - add your own timers and helper variables here *)
    StartTimer : TON;            (* supervises the start *)
    LossTimer  : TON;            (* supervises the running motor *)
  END_VAR

  (* TODO: replace these placeholder lines with your logic.
     - MotorRun follows RunCmd unless a fault is latched.
     - FailToStart: no RunFbk within StartTimeout after a start.
     - FbkLost: RunFbk seen, then missing for LossDelay while running.
     - ResetPB clears the faults only while RunCmd is FALSE. *)
  FailToStart := FALSE;
  FbkLost := FALSE;
  FaultLamp := FALSE;
  MotorRun := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : FeedbackTimeout;
  END_RESOURCE
END_CONFIGURATION
