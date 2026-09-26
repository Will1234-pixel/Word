(* Lab 05-1: Transfer pump P-101 start permissive.
   Module 05 (Boolean logic and FBD). STARTER - the declarations are done for you;
   write the logic where it says TODO, then run:
     python3 tools/plctest.py 05-boolean-logic-and-fbd/labs/starter/05-1-pump-permissive.st

   The whole lab is combinational: no seal-in, latch or timer is needed. *)

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
  (* You may add your own internal variables in a separate VAR block here. *)

  (* TODO: replace these placeholder lines with your logic.
     (MATIEC needs at least one statement in a program body.) *)
  PermissiveOK := FALSE;
  SelectorFault := FALSE;
  Pump := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : TransferPump;
  END_RESOURCE
END_CONFIGURATION
