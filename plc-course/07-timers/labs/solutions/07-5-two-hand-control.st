(* Lab 07-5: Two-hand control timing.
   Module 07 (Timers). REFERENCE SOLUTION - try the lab yourself first.

   TRAINING EXERCISE ONLY. A real two-hand control device is a safety function:
   it must use safety-rated buttons (usually one NO and one NC contact each)
   and a safety relay or safety PLC designed to the functional-safety
   standards (Module 20). Never build it from this standard-PLC logic.

   Rules implemented:
     - the stroke runs only while BOTH buttons are held,
     - the second button must follow the first within 500 ms,
     - after any release, BOTH buttons must be released before a new stroke. *)

PROGRAM TwoHandControl
  VAR (* I/O *)
    LeftPB    AT %IX0.0 : BOOL;  (* left palm button, NO: TRUE while pressed *)
    RightPB   AT %IX0.1 : BOOL;  (* right palm button, NO: TRUE while pressed *)
    PressDown AT %QX0.0 : BOOL;  (* press stroke valve *)
  END_VAR
  VAR (* internal *)
    Window : TON;                (* time since the FIRST button was pressed *)
    Ready  : BOOL;               (* both buttons have been released since the last stroke *)
  END_VAR

  (* 1. The synchronisation window starts with whichever button is pressed
        first and resets only when both are released. *)
  Window(IN := LeftPB OR RightPB, PT := T#500ms);

  (* 2. Ready is set only when both buttons are released. It starts FALSE,
        so buttons already held (or tied down) at power-up cannot start a
        stroke. *)
  IF NOT LeftPB AND NOT RightPB THEN
    Ready := TRUE;
  END_IF;

  (* 3. Start: both held, ready, and still inside the window.
        Hold: once running, both held is enough (the window has long expired). *)
  PressDown := LeftPB AND RightPB AND (PressDown OR (Ready AND NOT Window.Q));

  (* 4. A stroke uses up Ready: after any release, both buttons must be
        released before the next stroke. *)
  IF PressDown THEN
    Ready := FALSE;
  END_IF;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : TwoHandControl;
  END_RESOURCE
END_CONFIGURATION
