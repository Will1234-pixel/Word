(* Lab 07-5: Two-hand control timing.
   Module 07 (Timers). STARTER - the interface is declared for you;
   write the logic where it says TODO, then run:
     python3 tools/plctest.py 07-timers/labs/starter/07-5-two-hand-control.st

   TRAINING EXERCISE ONLY. Real two-hand control needs safety-rated devices
   and a safety relay or safety PLC (Module 20). *)

PROGRAM TwoHandControl
  VAR (* I/O *)
    LeftPB    AT %IX0.0 : BOOL;  (* left palm button, NO: TRUE while pressed *)
    RightPB   AT %IX0.1 : BOOL;  (* right palm button, NO: TRUE while pressed *)
    PressDown AT %QX0.0 : BOOL;  (* press stroke valve *)
  END_VAR
  VAR (* internal - add your own timers and helper variables here *)
    Window : TON;                (* suggested: time since the first button was pressed *)
  END_VAR

  (* TODO: replace this placeholder line with your logic. *)
  PressDown := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : TwoHandControl;
  END_RESOURCE
END_CONFIGURATION
