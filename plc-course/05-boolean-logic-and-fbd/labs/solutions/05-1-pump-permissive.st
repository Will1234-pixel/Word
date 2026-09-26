(* Lab 05-1: Transfer pump P-101 start permissive.
   Module 05 (Boolean logic and FBD). REFERENCE SOLUTION - try the lab yourself first.

   Everything here is combinational: every output depends only on the inputs
   of the present scan. There is no seal-in, latch or timer. *)

PROGRAM TransferPump
  VAR (* I/O - addresses follow the OpenPLC convention *)
    SuctionOpenLS AT %IX0.0 : BOOL;  (* Suction valve XV-100 open limit switch (ZSO-100): TRUE = fully open *)
    LSL101_NC     AT %IX0.1 : BOOL;  (* Tank low-level switch LSL-101, NC: TRUE = level above the switch (healthy) *)
    MotorFault    AT %IX0.2 : BOOL;  (* Motor protection relay fault contact, NO: TRUE = protection tripped *)
    ManualSel     AT %IX0.3 : BOOL;  (* MAN-OFF-AUTO selector, MAN contact *)
    AutoSel       AT %IX0.4 : BOOL;  (* MAN-OFF-AUTO selector, AUTO contact *)
    Demand        AT %IX0.5 : BOOL;  (* Auto demand from the process: TRUE = liquid wanted *)
    ManualRunCmd  AT %IX0.6 : BOOL;  (* Manual run command, maintained: TRUE = run *)
    Pump          AT %QX0.0 : BOOL;  (* P-101 motor starter: TRUE = run *)
    PermissiveOK  AT %QX0.1 : BOOL;  (* White "Ready" lamp: all start permissives healthy *)
    SelectorFault AT %QX0.2 : BOOL;  (* Both selector contacts made at once *)
  END_VAR
  VAR (* internal *)
    AutoMode   : BOOL;  (* selector cleanly in AUTO *)
    ManualMode : BOOL;  (* selector cleanly in MAN *)
    RunRequest : BOOL;  (* the active mode is asking for the pump *)
  END_VAR

  (* 1. Permissives. Each input is used in the sense that means "healthy":
        LSL101_NC is wired fail-safe and is already TRUE when healthy, so it is
        used as it is. MotorFault is TRUE when faulted, so it needs a NOT. *)
  PermissiveOK := SuctionOpenLS AND LSL101_NC AND NOT MotorFault;

  (* 2. Mode. A healthy three-position selector closes at most one contact.
        Both contacts at once is a fault, and it must not select any mode. *)
  SelectorFault := ManualSel AND AutoSel;
  AutoMode      := AutoSel AND NOT ManualSel;
  ManualMode    := ManualSel AND NOT AutoSel;

  (* 3. What the active mode asks for. The parentheses are not strictly needed
        (AND binds tighter than OR), but they show the intent at a glance. *)
  RunRequest := (AutoMode AND Demand) OR (ManualMode AND ManualRunCmd);

  (* 4. The permissives apply in every mode, so they go outside the OR. *)
  Pump := PermissiveOK AND RunRequest;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : TransferPump;
  END_RESOURCE
END_CONFIGURATION
