(* Lab 02-2: Solenoid valves - single-solenoid spring-return versus
   double-solenoid (bistable) valves on the same transfer line.
   Module 02 (Electrical fundamentals and field devices).
   STARTER - the declarations are done for you; write the logic where it
   says TODO, then run:
     python3 tools/plctest.py 02-electrical-and-field-devices/labs/starter/02-2-solenoid-valves.st
   Training exercise only: a real high-high level trip is a safety function
   and would be engineered separately (Module 20). *)

PROGRAM SolenoidValves
  VAR (* I/O - addresses follow the OpenPLC convention *)
    OpenPB         AT %IX0.0 : BOOL;  (* "Open line" push-button, NO: TRUE while pressed *)
    ClosePB_NC     AT %IX0.1 : BOOL;  (* "Close line" push-button, NC: TRUE while NOT pressed *)
    HighLevelOK_NC AT %IX0.2 : BOOL;  (* LSHH on the receiving tank, NC: TRUE while level is NOT high-high *)
    XV201_Sol      AT %QX0.0 : BOOL;  (* XV-201 solenoid: single-solenoid, spring return, fail closed *)
    XV202_OpenSol  AT %QX0.1 : BOOL;  (* XV-202 "open" coil: double-solenoid valve, stays put (fail last) *)
    XV202_CloseSol AT %QX0.2 : BOOL;  (* XV-202 "close" coil *)
  END_VAR
  VAR (* internal - add your own variables here if you need them *)
    Spare : BOOL;
  END_VAR

  (* TODO: replace these placeholder lines with your logic.
     The two valves receive the same commands but need different output
     patterns. What does each valve do when its coil is de-energised?
     (MATIEC needs at least one statement in a program body.) *)
  XV201_Sol := FALSE;
  XV202_OpenSol := FALSE;
  XV202_CloseSol := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : SolenoidValves;
  END_RESOURCE
END_CONFIGURATION
