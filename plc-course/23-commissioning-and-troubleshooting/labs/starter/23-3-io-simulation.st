(* Lab 23-3: I/O simulation layer for checkout - transfer pump P-101.
   Module 23 (Commissioning and troubleshooting). STARTER - the types, the
   declarations and the application logic are done for you. Write the
   simulation layer where it says TODO (you may add your own function blocks
   above the program), then run:
     python3 tools/plctest.py 23-commissioning-and-troubleshooting/labs/starter/23-3-io-simulation.st
   Training exercise only: simulation must never bypass a safety function. *)

TYPE
  ST_SimDI : STRUCT
    Enable : BOOL;  (* HMI: put this point into simulation *)
    Value  : BOOL;  (* HMI: simulated value *)
  END_STRUCT;
  ST_SimAI : STRUCT
    Enable : BOOL;  (* HMI: put this point into simulation *)
    Value  : REAL;  (* HMI: simulated value in engineering units *)
  END_STRUCT;
END_TYPE

PROGRAM PumpCheckout
  VAR (* I/O - addresses follow the OpenPLC convention *)
    LSL101_NC AT %IX0.0 : BOOL;  (* LSL-101 low-level switch, NC: TRUE while level is above it *)
    P101RunFB AT %IX0.1 : BOOL;  (* P-101 contactor auxiliary contact: TRUE = running *)
    SimKeySW  AT %IX0.2 : BOOL;  (* key switch "simulation permitted" (commissioning only) *)
    ResetPB   AT %IX0.3 : BOOL;  (* fault reset push-button, NO *)
    LT101Raw  AT %IW0   : INT;   (* LT-101 tank level, 4-20 mA input: 0..27648 = 0..100 % *)
    P101Run   AT %QX0.0 : BOOL;  (* P-101 contactor coil *)
    SimLamp   AT %QX0.1 : BOOL;  (* amber lamp: simulation active *)
    P101Fault AT %QX0.2 : BOOL;  (* red lamp: P-101 failed to start *)
  END_VAR
  VAR (* HMI simulation tags, one structure per point *)
    SimLSL101 : ST_SimDI;
    SimP101FB : ST_SimDI;
    SimLT101  : ST_SimAI;
  END_VAR
  VAR (* processed values: the ONLY input values the application logic uses *)
    LSL101_OK   : BOOL;
    P101Running : BOOL;
    LT101_Pct   : REAL;
  END_VAR
  VAR (* simulation status for the HMI banner *)
    SimActive : BOOL;
    SimCount  : INT;
  END_VAR
  VAR (* internal: add your own variables and FB instances here *)
    PumpDemand : BOOL;
    FbTimer    : TON;
  END_VAR

  (* ==== SIMULATION LAYER ====
     TODO: replace these placeholder lines. For each of the three points, set
     the processed value from the field or from its simulation structure,
     following the lab requirements. Then set SimCount, SimActive and SimLamp. *)
  LSL101_OK := FALSE;
  P101Running := FALSE;
  LT101_Pct := 0.0;
  SimCount := 0;
  SimActive := FALSE;
  SimLamp := FALSE;

  (* ==== APPLICATION LOGIC (given; uses processed values only) ==== *)
  (* Level control with hysteresis: start at 60 %, stop at 20 % *)
  IF LT101_Pct >= 60.0 THEN
    PumpDemand := TRUE;
  ELSIF LT101_Pct <= 20.0 THEN
    PumpDemand := FALSE;
  END_IF;

  (* Start failure: commanded but no running feedback within 2 s *)
  FbTimer(IN := P101Run AND NOT P101Running, PT := T#2s);
  IF FbTimer.Q THEN
    P101Fault := TRUE;
  ELSIF ResetPB THEN
    P101Fault := FALSE;
  END_IF;

  (* Command: demand AND dry-run protection AND no fault *)
  P101Run := PumpDemand AND LSL101_OK AND NOT P101Fault;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : PumpCheckout;
  END_RESOURCE
END_CONFIGURATION
