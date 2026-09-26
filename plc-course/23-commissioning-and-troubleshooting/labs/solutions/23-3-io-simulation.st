(* Lab 23-3: I/O simulation layer for checkout - transfer pump P-101.
   Module 23 (Commissioning and troubleshooting). REFERENCE SOLUTION - try the lab yourself first.

   Every field input passes through a small simulation block before the
   application logic sees it. During a FAT or I/O checkout a tester can put a
   point into simulation from the HMI and type a value, but only while the
   "simulation permitted" key switch is on. A lamp and a counter show that
   simulation is active. Training exercise only: a real plant needs site rules
   for who may simulate what, and simulation must never bypass a safety function. *)

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

(* One digital input point. Call it every scan, before the logic that uses Value. *)
FUNCTION_BLOCK FB_SimDI
  VAR_INPUT
    Live   : BOOL;  (* value from the field *)
    Permit : BOOL;  (* simulation permitted (key switch) *)
  END_VAR
  VAR_IN_OUT
    Sim : ST_SimDI;  (* this point's HMI simulation tags *)
  END_VAR
  VAR_OUTPUT
    Value  : BOOL;  (* value for the application logic *)
    Active : BOOL;  (* this point is being simulated *)
  END_VAR
  VAR
    WasActive : BOOL;
  END_VAR

  IF NOT Permit THEN
    Sim.Enable := FALSE;       (* no key: refuse and clear any request *)
  END_IF;
  Active := Sim.Enable;
  IF Active AND NOT WasActive THEN
    Sim.Value := Live;         (* bumpless start: begin from the live value *)
  END_IF;
  WasActive := Active;
  IF Active THEN
    Value := Sim.Value;
  ELSE
    Value := Live;
  END_IF;
END_FUNCTION_BLOCK

(* One analog input point, in engineering units. Same rules as FB_SimDI. *)
FUNCTION_BLOCK FB_SimAI
  VAR_INPUT
    Live   : REAL;
    Permit : BOOL;
  END_VAR
  VAR_IN_OUT
    Sim : ST_SimAI;
  END_VAR
  VAR_OUTPUT
    Value  : REAL;
    Active : BOOL;
  END_VAR
  VAR
    WasActive : BOOL;
  END_VAR

  IF NOT Permit THEN
    Sim.Enable := FALSE;
  END_IF;
  Active := Sim.Enable;
  IF Active AND NOT WasActive THEN
    Sim.Value := Live;
  END_IF;
  WasActive := Active;
  IF Active THEN
    Value := Sim.Value;
  ELSE
    Value := Live;
  END_IF;
END_FUNCTION_BLOCK

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
  VAR (* internal *)
    LT101_Live : REAL;
    SimLSL     : FB_SimDI;
    SimFB      : FB_SimDI;
    SimLT      : FB_SimAI;
    PumpDemand : BOOL;
    FbTimer    : TON;
  END_VAR

  (* ==== SIMULATION LAYER: runs first, so the logic sees this scan's values ==== *)
  LT101_Live := INT_TO_REAL(LT101Raw) * 100.0 / 27648.0;

  SimLSL(Live := LSL101_NC, Permit := SimKeySW, Sim := SimLSL101);
  SimFB(Live := P101RunFB, Permit := SimKeySW, Sim := SimP101FB);
  SimLT(Live := LT101_Live, Permit := SimKeySW, Sim := SimLT101);

  LSL101_OK := SimLSL.Value;
  P101Running := SimFB.Value;
  LT101_Pct := SimLT.Value;

  SimCount := 0;
  IF SimLSL.Active THEN SimCount := SimCount + 1; END_IF;
  IF SimFB.Active THEN SimCount := SimCount + 1; END_IF;
  IF SimLT.Active THEN SimCount := SimCount + 1; END_IF;
  SimActive := SimCount > 0;
  SimLamp := SimActive;

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
