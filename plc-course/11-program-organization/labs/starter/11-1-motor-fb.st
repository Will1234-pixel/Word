(* Lab 11-1: A reusable motor function block, used three times.
   Module 11 (Program organisation). STARTER - the FB interface, the program
   I/O and the three instances are declared for you. Write:
     1. the body of FB_Motor (and any internal variables it needs), and
     2. the program logic that calls Pump1, Pump2 and Fan1 and drives the outputs.
   Then run:
     python3 tools/plctest.py 11-program-organization/labs/starter/11-1-motor-fb.st *)

FUNCTION_BLOCK FB_Motor
  (* Direct-on-line motor with run feedback supervision.
     Keep these pin names: the test reads RunCmd, Running and Fault. *)
  VAR_INPUT
    Start       : BOOL;          (* start request, TRUE = start (pulse or held) *)
    Stop        : BOOL;          (* stop request, TRUE = stop; wins over Start *)
    InterlockOK : BOOL;          (* TRUE = allowed to run; FALSE stops the motor *)
    RunFb       : BOOL;          (* run feedback: contactor aux contact or airflow switch *)
    Reset       : BOOL;          (* fault reset *)
    FbTimeout   : TIME := T#2s;  (* how long RunFb may disagree with RunCmd *)
  END_VAR
  VAR_OUTPUT
    RunCmd      : BOOL;          (* command to the contactor coil *)
    Running     : BOOL;          (* proven running: RunCmd AND RunFb *)
    Fault       : BOOL;          (* latched feedback fault; needs Reset *)
    RunSeconds  : DINT;          (* optional extension (not tested): seconds of proven running *)
  END_VAR
  (* TODO: add a VAR ... END_VAR block here for internal variables,
     for example a TON instance for the feedback check. *)

  (* TODO: replace these placeholder lines with the motor logic. *)
  RunCmd := FALSE;
  Running := FALSE;
  Fault := FALSE;
END_FUNCTION_BLOCK


PROGRAM DosingRoom
  VAR (* inputs *)
    Pump1StartPB   AT %IX0.0 : BOOL;  (* Pump 1 start push-button, NO *)
    Pump1StopPB_NC AT %IX0.1 : BOOL;  (* Pump 1 stop push-button, NC: TRUE while not pressed *)
    Pump1RunFb     AT %IX0.2 : BOOL;  (* Pump 1 contactor auxiliary contact: TRUE = contactor in *)
    Pump2StartPB   AT %IX0.3 : BOOL;  (* Pump 2 start push-button, NO *)
    Pump2StopPB_NC AT %IX0.4 : BOOL;  (* Pump 2 stop push-button, NC *)
    Pump2RunFb     AT %IX0.5 : BOOL;  (* Pump 2 contactor auxiliary contact *)
    Fan1StartPB    AT %IX0.6 : BOOL;  (* Extract fan start push-button, NO *)
    Fan1StopPB_NC  AT %IX0.7 : BOOL;  (* Extract fan stop push-button, NC *)
    Fan1AirflowSw  AT %IX1.0 : BOOL;  (* Extract duct airflow switch: TRUE = air moving *)
    TankLowLow_NC  AT %IX1.1 : BOOL;  (* Day-tank low-low level switch, fail-safe:
                                         TRUE = level healthy, FALSE = low-low or wire break *)
    ResetPB        AT %IX1.2 : BOOL;  (* Fault reset push-button, NO *)
  END_VAR
  VAR (* outputs *)
    Pump1Contactor AT %QX0.0 : BOOL;  (* Pump 1 contactor coil *)
    Pump2Contactor AT %QX0.1 : BOOL;  (* Pump 2 contactor coil *)
    Fan1Contactor  AT %QX0.2 : BOOL;  (* Extract fan contactor coil *)
    FaultLamp      AT %QX0.3 : BOOL;  (* Common "motor fault" lamp *)
  END_VAR
  VAR (* one instance of FB_Motor per motor - keep these names *)
    Pump1 : FB_Motor;
    Pump2 : FB_Motor;
    Fan1  : FB_Motor;
  END_VAR

  (* TODO: call Fan1, Pump1 and Pump2 with the right inputs and parameters,
     then drive the contactors and the fault lamp from their outputs. *)
  Pump1Contactor := FALSE;
  Pump2Contactor := FALSE;
  Fan1Contactor := FALSE;
  FaultLamp := FALSE;
END_PROGRAM


CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : DosingRoom;
  END_RESOURCE
END_CONFIGURATION
