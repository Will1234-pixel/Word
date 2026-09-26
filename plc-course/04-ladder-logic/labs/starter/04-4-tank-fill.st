(* Lab 04-4: Tank fill valve with set/reset (latch/unlatch).
   Module 04 (Ladder logic fundamentals).
   STARTER - the declarations are done for you; write the logic where it
   says TODO, then run:
     python3 tools/plctest.py 04-ladder-logic/labs/starter/04-4-tank-fill.st
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
  VAR (* internal - add what you need, for example an SR or RS instance *)
    Spare : BOOL;
  END_VAR

  (* TODO: replace these placeholder lines with your logic.
     Use a SET rung and a RESET rung for the valve (in ST: an IF that only
     writes TRUE and an IF that only writes FALSE). Which one must come last?
     (MATIEC needs at least one statement in a program body.) *)
  FillValve := FALSE;
  SensorFault := FALSE;
  Spare := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : TankFill;
  END_RESOURCE
END_CONFIGURATION
