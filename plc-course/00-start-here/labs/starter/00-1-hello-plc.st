(* Lab 00-1: Hello PLC - start/stop a motor with a seal-in circuit.
   Module 00 (Start here). STARTER - the declarations are done for you;
   write the logic where it says TODO, then run:
     python3 tools/plctest.py 00-start-here/labs/starter/00-1-hello-plc.st *)

PROGRAM HelloPlc
  VAR (* I/O - addresses follow the OpenPLC convention *)
    StartPB   AT %IX0.0 : BOOL;  (* Start push-button, NO: TRUE while pressed *)
    StopPB_NC AT %IX0.1 : BOOL;  (* Stop push-button, NC: TRUE while NOT pressed *)
    Motor     AT %QX0.0 : BOOL;  (* Motor contactor coil *)
    RunLamp   AT %QX0.1 : BOOL;  (* Green "running" lamp *)
  END_VAR

  (* TODO: replace these two placeholder lines with your logic.
     (MATIEC needs at least one statement in a program body.) *)
  Motor := FALSE;
  RunLamp := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : HelloPlc;
  END_RESOURCE
END_CONFIGURATION
