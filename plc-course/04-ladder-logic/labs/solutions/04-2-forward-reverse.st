(* Lab 04-2: Forward/reverse motor with interlocks and travel limits.
   Module 04 (Ladder logic fundamentals).
   REFERENCE SOLUTION - try the lab yourself first.
   The same logic drawn as ladder rungs is in the Module 04 README (Lab 04-2).
   The software interlock here does NOT replace the electrical interlock
   (auxiliary NC contacts) and the mechanical interlock of the reversing
   contactor pair: a real starter has all three. Training exercise only. *)

PROGRAM ForwardReverse
  VAR (* I/O - addresses follow the OpenPLC convention *)
    FwdPB         AT %IX0.0 : BOOL;  (* Forward push-button, NO: TRUE while pressed *)
    RevPB         AT %IX0.1 : BOOL;  (* Reverse push-button, NO: TRUE while pressed *)
    StopPB_NC     AT %IX0.2 : BOOL;  (* Stop push-button, NC: TRUE while NOT pressed *)
    FwdLimitOK_NC AT %IX0.3 : BOOL;  (* Forward end-of-travel limit switch, NC: TRUE while NOT at the limit *)
    RevLimitOK_NC AT %IX0.4 : BOOL;  (* Reverse end-of-travel limit switch, NC: TRUE while NOT at the limit *)
    OverloadOK_NC AT %IX0.5 : BOOL;  (* Overload relay auxiliary contact, NC: TRUE while healthy *)
    FwdK          AT %QX0.0 : BOOL;  (* Forward contactor coil *)
    RevK          AT %QX0.1 : BOOL;  (* Reverse contactor coil *)
  END_VAR

  (* Rung 1 - FORWARD contactor.
     Start branch: FwdPB AND NOT RevPB. If both direction buttons are pressed
     together the command is ambiguous, so neither direction starts. Without
     this, rung order would decide: forward would always win.
     Seal-in: FwdK in parallel with the start branch.
     In series with everything (they break the seal-in):
       - StopPB_NC and OverloadOK_NC stop both directions;
       - FwdLimitOK_NC stops FORWARD only, so the operator can still reverse
         away from the forward limit;
       - NOT RevK is the software interlock: forward cannot start while
         reverse is on. The operator must stop before changing direction. *)
  FwdK := ((FwdPB AND NOT RevPB) OR FwdK)
          AND StopPB_NC AND OverloadOK_NC AND FwdLimitOK_NC AND NOT RevK;

  (* Rung 2 - REVERSE contactor, the mirror image of rung 1.
     NOT FwdK reads the value rung 1 has just written in this scan, so the
     two contactors can never both be TRUE at the end of a scan. *)
  RevK := ((RevPB AND NOT FwdPB) OR RevK)
          AND StopPB_NC AND OverloadOK_NC AND RevLimitOK_NC AND NOT FwdK;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : ForwardReverse;
  END_RESOURCE
END_CONFIGURATION
