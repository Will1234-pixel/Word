(* Lab 07-2: Flasher beacon with separate on and off times.
   Module 07 (Timers). REFERENCE SOLUTION - try the lab yourself first.

   Two timers that reset each other form an oscillator:
     OnTimer  times the ON phase  (beacon lit while it is timing),
     OffTimer times the OFF phase (started when OnTimer is done).
   When OffTimer is done, OnTimer's IN goes FALSE for one scan. That resets
   both timers and the cycle starts again with a new ON phase. *)

PROGRAM FlasherBeacon
  VAR (* I/O *)
    Enable AT %IX0.0 : BOOL;   (* flash request, e.g. "machine about to start" *)
    Beacon AT %QX0.0 : BOOL;   (* beacon lamp *)
  END_VAR
  VAR (* settings, e.g. written from an HMI *)
    OnTime  : TIME := T#500ms; (* lamp on time *)
    OffTime : TIME := T#1s;    (* lamp off time *)
  END_VAR
  VAR (* internal *)
    OnTimer  : TON;            (* ON phase *)
    OffTimer : TON;            (* OFF phase *)
  END_VAR

  (* ON phase: runs while enabled, until the OFF phase has finished.
     Removing Enable resets it, so the next enable starts with a full
     ON phase. *)
  OnTimer(IN := Enable AND NOT OffTimer.Q, PT := OnTime);

  (* OFF phase: starts when the ON phase is done. *)
  OffTimer(IN := OnTimer.Q, PT := OffTime);

  (* The lamp is lit while enabled and the ON phase is not yet done. *)
  Beacon := Enable AND NOT OnTimer.Q;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : FlasherBeacon;
  END_RESOURCE
END_CONFIGURATION
