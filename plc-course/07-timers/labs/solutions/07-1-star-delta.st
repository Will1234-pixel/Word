(* Lab 07-1: Star-delta starter.
   Module 07 (Timers). REFERENCE SOLUTION - try the lab yourself first.

   Sequence: Start -> main + star contactors on -> after StarTime the star
   contactor opens -> 100 ms dead time -> delta contactor closes.
   Training exercise only: a real starter also has hard-wired electrical and
   mechanical interlocks between the star and delta contactors. *)

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
  VAR (* internal *)
    StarTimer : TON;                 (* times the star period *)
    GapTimer  : TON;                 (* changeover dead time, star off -> delta on *)
  END_VAR

  (* 1. Run latch. The main contactor seals itself in. Stop and the overload
        both break the seal, so releasing Stop or resetting the overload relay
        can never restart the motor on its own. *)
  MainK := (StartPB OR MainK) AND StopPB_NC AND OverloadOK_NC;

  (* 2. Star period. The timer runs while the main contactor is on and is
        reset as soon as it drops out, so every new start gets a full star
        period. The timer is called on every scan, never inside an IF. *)
  StarTimer(IN := MainK, PT := StarTime);
  StarK := MainK AND NOT StarTimer.Q;

  (* 3. Changeover gap. StarTimer.Q is TRUE from the scan in which the star
        contactor is switched off, so GapTimer measures how long star has been
        off. Delta may close only after 100 ms, when the star contactor has
        had time to open and its arc to clear. *)
  GapTimer(IN := StarTimer.Q, PT := T#100ms);

  (* 4. Delta, with a software interlock against star as a second line of
        defence (the first line is the hard-wired interlock in the panel). *)
  DeltaK := MainK AND GapTimer.Q AND NOT StarK;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : StarDelta;
  END_RESOURCE
END_CONFIGURATION
