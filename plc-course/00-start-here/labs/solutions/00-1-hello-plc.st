(* Lab 00-1: Hello PLC - start/stop a motor with a seal-in circuit.
   Module 00 (Start here). REFERENCE SOLUTION - try the lab yourself first. *)

PROGRAM HelloPlc
  VAR (* I/O - addresses follow the OpenPLC convention *)
    StartPB   AT %IX0.0 : BOOL;  (* Start push-button, NO: TRUE while pressed *)
    StopPB_NC AT %IX0.1 : BOOL;  (* Stop push-button, NC: TRUE while NOT pressed *)
    Motor     AT %QX0.0 : BOOL;  (* Motor contactor coil *)
    RunLamp   AT %QX0.1 : BOOL;  (* Green "running" lamp *)
  END_VAR

  (* Seal-in (latching) circuit, the "hello world" of PLCs:
     - pressing Start switches the motor on,
     - the motor's own status holds it on after Start is released,
     - Stop breaks the circuit. The stop button is wired NC, so a pressed
       button AND a broken wire both read FALSE and both stop the motor. *)
  Motor := (StartPB OR Motor) AND StopPB_NC;
  RunLamp := Motor;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : HelloPlc;
  END_RESOURCE
END_CONFIGURATION
