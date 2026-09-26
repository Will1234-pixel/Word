(* Lab 11-2: A reusable on/off valve function block with limit switches.
   Module 11 (Program organisation). STARTER - the FB interface, the program
   I/O and the two instances are declared for you. Write:
     1. the body of FB_Valve (and any internal variables it needs), and
     2. the program logic that calls XV101 and XV102 and drives the outputs.
   Then run:
     python3 tools/plctest.py 11-program-organization/labs/starter/11-2-valve-fb.st

   XV101  reactor feed valve      fail CLOSED, 5 s travel time
   XV102  jacket cooling valve    fail OPEN,   8 s travel time
   Training exercise only: a real reactor trip belongs in a safety
   instrumented system, not in basic control logic (Module 20). *)

FUNCTION_BLOCK FB_Valve
  (* Single-solenoid, spring-return on/off valve with open and closed limit
     switches. Keep these pin names: the test reads IsOpen, IsClosed,
     TravelFault, LimitFault and Fault. *)
  VAR_INPUT
    OpenCmd    : BOOL;            (* TRUE = open, FALSE = close *)
    OpenLS     : BOOL;            (* open limit switch (ZSO), TRUE = fully open *)
    ClosedLS   : BOOL;            (* closed limit switch (ZSC), TRUE = fully closed *)
    Reset      : BOOL;            (* fault reset *)
    FailOpen   : BOOL;            (* configuration: TRUE = spring opens the valve *)
    TravelTime : TIME := T#10s;   (* longest acceptable stroke *)
  END_VAR
  VAR_OUTPUT
    Solenoid    : BOOL;           (* solenoid output *)
    IsOpen      : BOOL;           (* confirmed open *)
    IsClosed    : BOOL;           (* confirmed closed *)
    TravelFault : BOOL;           (* latched: did not reach / stay in position *)
    LimitFault  : BOOL;           (* latched: both limit switches made for 500 ms *)
    Fault       : BOOL;           (* TravelFault OR LimitFault *)
  END_VAR
  (* TODO: add a VAR ... END_VAR block here for internal variables
     (timers, the previous command, ...). *)

  (* TODO: replace these placeholder lines with the valve logic. *)
  Solenoid := FALSE;
  IsOpen := FALSE;
  IsClosed := FALSE;
  TravelFault := FALSE;
  LimitFault := FALSE;
  Fault := FALSE;
END_FUNCTION_BLOCK


PROGRAM ReactorValves
  VAR (* inputs *)
    XV101_OpenSw AT %IX0.0 : BOOL;  (* XV-101 panel selector: TRUE = OPEN, FALSE = CLOSE *)
    XV101_ZSO    AT %IX0.1 : BOOL;  (* XV-101 open limit switch *)
    XV101_ZSC    AT %IX0.2 : BOOL;  (* XV-101 closed limit switch *)
    XV102_OpenSw AT %IX0.3 : BOOL;  (* XV-102 panel selector: TRUE = OPEN, FALSE = CLOSE *)
    XV102_ZSO    AT %IX0.4 : BOOL;  (* XV-102 open limit switch *)
    XV102_ZSC    AT %IX0.5 : BOOL;  (* XV-102 closed limit switch *)
    ResetPB      AT %IX0.6 : BOOL;  (* Fault reset push-button, NO *)
  END_VAR
  VAR (* outputs *)
    XV101_SOL    AT %QX0.0 : BOOL;  (* XV-101 solenoid: energise to OPEN (fail closed) *)
    XV102_SOL    AT %QX0.1 : BOOL;  (* XV-102 solenoid: energise to CLOSE (fail open) *)
    FaultLamp    AT %QX0.2 : BOOL;  (* Common "valve fault" lamp *)
  END_VAR
  VAR (* device instances - keep these names *)
    XV101 : FB_Valve;               (* reactor feed valve *)
    XV102 : FB_Valve;               (* jacket cooling-water valve *)
  END_VAR

  (* TODO: call XV101 and XV102 with their inputs and configuration,
     then drive the solenoids and the fault lamp from their outputs. *)
  XV101_SOL := FALSE;
  XV102_SOL := FALSE;
  FaultLamp := FALSE;
END_PROGRAM


CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : ReactorValves;
  END_RESOURCE
END_CONFIGURATION
