(* Lab 04-3: Jog/run selector.
   Module 04 (Ladder logic fundamentals).
   STARTER - the declarations are done for you; write the logic where it
   says TODO, then run:
     python3 tools/plctest.py 04-ladder-logic/labs/starter/04-3-jog-run.st
   Training exercise only: jogging on a real machine is a safety function
   with its own rules and hardware (Modules 19 and 20). *)

PROGRAM JogRun
  VAR (* I/O - addresses follow the OpenPLC convention *)
    StartPB       AT %IX0.0 : BOOL;  (* Start push-button, NO: TRUE while pressed *)
    StopPB_NC     AT %IX0.1 : BOOL;  (* Stop push-button, NC: TRUE while NOT pressed *)
    JogPB         AT %IX0.2 : BOOL;  (* Jog push-button, NO: TRUE while pressed *)
    RunSel        AT %IX0.3 : BOOL;  (* JOG/RUN selector: TRUE = RUN, FALSE = JOG *)
    OverloadOK_NC AT %IX0.4 : BOOL;  (* Overload relay auxiliary contact, NC: TRUE while healthy *)
    Motor         AT %QX0.0 : BOOL;  (* Conveyor motor contactor coil *)
    RunLamp       AT %QX0.1 : BOOL;  (* "Running" lamp: continuous run only, not jogging *)
  END_VAR
  VAR (* internal - add any internal bits you need here *)
    Spare : BOOL;
  END_VAR

  (* TODO: replace these placeholder lines with your logic.
     Question to answer first: which bit is allowed to seal in, and is it
     the Motor output?
     (MATIEC needs at least one statement in a program body.) *)
  Motor := FALSE;
  RunLamp := FALSE;
  Spare := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : JogRun;
  END_RESOURCE
END_CONFIGURATION
