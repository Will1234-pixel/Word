(* Lab 04-4: Tank fill valve with set/reset (latch/unlatch).
   Module 04 (Ladder logic fundamentals).
   REFERENCE SOLUTION - try the lab yourself first.
   The same logic drawn as ladder rungs is in the Module 04 README (Lab 04-4).
   Training exercise only: overfill protection that matters for safety or
   the environment is a separate, independent function (Module 20). *)

PROGRAM TankFill
  VAR (* I/O - addresses follow the OpenPLC convention *)
    AutoSel        AT %IX0.0 : BOOL;  (* OFF/AUTO selector: TRUE = AUTO *)
    LevelAboveLow  AT %IX0.1 : BOOL;  (* LSL-101 low level switch: TRUE while the level is ABOVE it (switch covered) *)
    HighLevelOK_NC AT %IX0.2 : BOOL;  (* LSH-102 high level switch, NC: TRUE while the level is BELOW it; FALSE at high level or broken wire *)
    ResetPB        AT %IX0.3 : BOOL;  (* Fault reset push-button, NO: TRUE while pressed *)
    FillValve      AT %QX0.0 : BOOL;  (* XV-100 inlet valve solenoid: TRUE = open (spring return, fail closed) *)
    SensorFault    AT %QX0.1 : BOOL;  (* Amber lamp: level switches disagree (latched) *)
  END_VAR
  VAR (* internal *)
    SwitchesDisagree : BOOL;  (* low switch says "low" while high switch says "high": impossible *)
    FaultLatch       : SR;    (* IEC SR = SET-dominant bistable (input S1 wins) *)
  END_VAR
  (* FillValve and FaultLatch are deliberately NOT retentive: after any
     restart the valve starts closed and waits for the low switch. *)

  (* Rung 1 - plausibility check. The level cannot be below the low switch
     and above the high switch at the same time, so one of the two switches
     (or its wiring) is wrong. *)
  SwitchesDisagree := NOT LevelAboveLow AND NOT HighLevelOK_NC;

  (* Rung 2 - fault latch, SET-dominant: while the disagreement is still
     there, holding Reset cannot clear it. *)
  FaultLatch(S1 := SwitchesDisagree, R := ResetPB);
  SensorFault := FaultLatch.Q1;

  (* Rung 3 - SET (latch) the valve: AUTO and the level has fallen below the
     low switch. Like a set coil, this only ever writes TRUE. *)
  IF AutoSel AND NOT LevelAboveLow THEN
    FillValve := TRUE;
  END_IF;

  (* Rung 4 - RESET (unlatch) the valve: high level reached, AUTO switched
     off, or a sensor fault. Like a reset coil, this only ever writes FALSE.
     It comes AFTER the set rung, so if both are true in the same scan the
     reset wins (last write wins): high level always closes the valve. *)
  IF NOT HighLevelOK_NC OR NOT AutoSel OR SensorFault THEN
    FillValve := FALSE;
  END_IF;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : TankFill;
  END_RESOURCE
END_CONFIGURATION
