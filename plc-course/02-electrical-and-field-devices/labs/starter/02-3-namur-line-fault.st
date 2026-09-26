(* Lab 02-3: NAMUR sensor with line-fault detection - turn a switching
   signal plus open-circuit and short-circuit status bits into a validated
   signal and a fault.
   Module 02 (Electrical fundamentals and field devices).
   STARTER - the declarations are done for you; write the logic where it
   says TODO, then run:
     python3 tools/plctest.py 02-electrical-and-field-devices/labs/starter/02-3-namur-line-fault.st
   Training exercise only: this LSH is a control function. An independent
   high-high protection layer would be engineered separately (Module 20). *)

PROGRAM NamurLineFault
  VAR (* I/O - addresses follow the OpenPLC convention *)
    FillSel      AT %IX0.0 : BOOL;  (* Fill selector: TRUE = operator wants the tank filled *)
    SensorOn     AT %IX0.1 : BOOL;  (* LSH-301 via isolator: TRUE = NAMUR current in the ON band = fork dry *)
    WireBreak    AT %IX0.2 : BOOL;  (* Isolator status: open circuit detected (TRUE = fault) *)
    ShortCircuit AT %IX0.3 : BOOL;  (* Isolator status: short circuit detected (TRUE = fault) *)
    ResetPB      AT %IX0.4 : BOOL;  (* Fault reset push-button, NO: TRUE while pressed *)
    InletValve   AT %QX0.0 : BOOL;  (* XV-301 inlet valve solenoid, spring return: TRUE = open *)
    FaultLamp    AT %QX0.1 : BOOL;  (* Amber "LSH-301 line fault" lamp, latched *)
  END_VAR
  VAR (* internal - required by the lab interface *)
    LineFault : BOOL;  (* TRUE while an open or short circuit is present *)
    HighLevel : BOOL;  (* validated high level: TRUE when high OR when the signal cannot be trusted *)
  END_VAR

  (* TODO: replace these placeholder lines with your logic, in this order:
     LineFault, HighLevel, FaultLamp, InletValve.
     (MATIEC needs at least one statement in a program body.) *)
  LineFault := FALSE;
  HighLevel := FALSE;
  FaultLamp := FALSE;
  InletValve := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : NamurLineFault;
  END_RESOURCE
END_CONFIGURATION
