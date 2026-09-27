(* Lab 22-2: Refactor safely - chemical dosing skid.
   Module 22 (Software engineering). REFERENCE SOLUTION - try the lab yourself first.

   Same behaviour as the legacy program (the characterisation test proves it),
   restructured into:
     F_ScaleRaw     FUNCTION: straight-line scaling (no memory, easy to test)
     FB_LowAlarm    FUNCTION_BLOCK: low alarm with set/clear hysteresis
     FB_DosingPump  FUNCTION_BLOCK: one pump; two instances replace the
                    copy-pasted code, and the one real difference between
                    the copies (the feedback timeout) became a parameter
   plus named constants instead of magic numbers, and a program body that
   reads in plant order: level, pumps, outputs.

   Legacy quirks KEPT on purpose (each needs its own approved change and test):
     - P-202 feedback timeout is 5 s. The old comment said 4 s; the code has
       always used 5 s, and the plant has run like that. The comment was wrong.
     - LevelPct is not clamped: raw values outside 0..27648 give < 0 % or > 100 %.
     - Start counters are INT (wrap after 32767) and not RETAIN (lost at a
       cold restart).
     - No check for "running without a run command" (welded contactor). *)

FUNCTION F_ScaleRaw : REAL
  VAR_INPUT
    Raw   : INT;    (* raw counts from the analog input card *)
    RawLo : REAL;   (* raw counts at the bottom of the range *)
    RawHi : REAL;   (* raw counts at the top of the range *)
    EngLo : REAL;   (* engineering value at RawLo *)
    EngHi : REAL;   (* engineering value at RawHi *)
  END_VAR
  (* Straight line through (RawLo, EngLo) and (RawHi, EngHi). No clamping.
     A zero-width raw range would divide by zero, so return EngLo instead. *)
  IF RawHi <> RawLo THEN
    F_ScaleRaw := EngLo + (INT_TO_REAL(Raw) - RawLo) * (EngHi - EngLo) / (RawHi - RawLo);
  ELSE
    F_ScaleRaw := EngLo;
  END_IF;
END_FUNCTION

FUNCTION_BLOCK FB_LowAlarm
  VAR_INPUT
    Value      : REAL;  (* measured value *)
    SetBelow   : REAL;  (* alarm comes on when Value < SetBelow *)
    ClearAbove : REAL;  (* alarm clears when Value > ClearAbove; must be > SetBelow *)
  END_VAR
  VAR_OUTPUT
    Active : BOOL;      (* between the two limits the alarm keeps its state *)
  END_VAR
  IF Value < SetBelow THEN
    Active := TRUE;
  ELSIF Value > ClearAbove THEN
    Active := FALSE;
  END_IF;
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_DosingPump
  VAR_INPUT
    StartPB   : BOOL;          (* local start push-button, NO *)
    StopOK    : BOOL;          (* local stop push-button, NC: TRUE = not pressed *)
    RunFb     : BOOL;          (* contactor auxiliary contact: TRUE = running *)
    Permit    : BOOL;          (* process permissive, e.g. tank level OK *)
    ResetCmd  : BOOL;          (* fault reset request, acts on the rising edge *)
    FbTimeout : TIME := T#3s;  (* max time from run command to run feedback *)
  END_VAR
  VAR_OUTPUT
    Run    : BOOL;             (* pump contactor command *)
    Fault  : BOOL;             (* no run feedback: latched until reset *)
    Starts : INT;              (* start counter for maintenance *)
  END_VAR
  VAR
    FbTimer   : TON;           (* run command without feedback *)
    ResetEdge : R_TRIG;
    RunEdge   : R_TRIG;
  END_VAR

  (* Reset on the press only: a held reset button cannot hide a new fault. *)
  ResetEdge(CLK := ResetCmd);
  IF ResetEdge.Q THEN
    Fault := FALSE;
  END_IF;

  (* Seal-in. Stop, a missing permissive and a fault all drop the seal, so
     nothing restarts on its own when they clear. *)
  Run := (StartPB OR Run) AND StopOK AND Permit AND NOT Fault;

  FbTimer(IN := Run AND NOT RunFb, PT := FbTimeout);
  IF FbTimer.Q THEN
    Fault := TRUE;
    Run := FALSE;
  END_IF;

  RunEdge(CLK := Run);
  IF RunEdge.Q THEN
    Starts := Starts + 1;
  END_IF;
END_FUNCTION_BLOCK

PROGRAM DosingSkid
  VAR (* I/O - names unchanged from the legacy program *)
    P1_StartPB   AT %IX0.0 : BOOL;  (* P-201 start push-button, NO *)
    P1_StopPB_NC AT %IX0.1 : BOOL;  (* P-201 stop push-button, NC *)
    P2_StartPB   AT %IX0.2 : BOOL;  (* P-202 start push-button, NO *)
    P2_StopPB_NC AT %IX0.3 : BOOL;  (* P-202 stop push-button, NC *)
    P1_RunFb     AT %IX0.4 : BOOL;  (* P-201 contactor auxiliary: TRUE = running *)
    P2_RunFb     AT %IX0.5 : BOOL;  (* P-202 contactor auxiliary: TRUE = running *)
    ResetPB      AT %IX0.6 : BOOL;  (* fault reset push-button, NO *)
    LevelRaw     AT %IW0   : INT;   (* LT-200 day-tank level, 0..27648 = 4..20 mA *)
    P1_Run       AT %QX0.0 : BOOL;  (* P-201 contactor *)
    P2_Run       AT %QX0.1 : BOOL;  (* P-202 contactor *)
    P1_FaultLamp AT %QX0.2 : BOOL;
    P2_FaultLamp AT %QX0.3 : BOOL;
    LowLevelLamp AT %QX0.4 : BOOL;
  END_VAR
  VAR (* HMI tags - names unchanged *)
    LevelPct  : REAL;               (* LT-200 level, % *)
    P1_Starts : INT;                (* P-201 start counter *)
    P2_Starts : INT;                (* P-202 start counter *)
  END_VAR
  VAR CONSTANT
    RAW_AT_4MA      : REAL := 0.0;      (* raw counts at 4 mA (0 %) *)
    RAW_AT_20MA     : REAL := 27648.0;  (* raw counts at 20 mA (100 %) *)
    LOW_LEVEL_SET   : REAL := 10.0;     (* %: stop the pumps below this *)
    LOW_LEVEL_CLEAR : REAL := 15.0;     (* %: allow starts again above this *)
    P1_FB_TIMEOUT   : TIME := T#3s;
    P2_FB_TIMEOUT   : TIME := T#5s;     (* legacy value, kept on purpose: see the header *)
  END_VAR
  VAR
    LowLevel : FB_LowAlarm;         (* LAL-200 *)
    Pump1    : FB_DosingPump;       (* P-201 *)
    Pump2    : FB_DosingPump;       (* P-202 *)
  END_VAR

  (* 1. Day-tank level *)
  LevelPct := F_ScaleRaw(Raw := LevelRaw,
                         RawLo := RAW_AT_4MA, RawHi := RAW_AT_20MA,
                         EngLo := 0.0, EngHi := 100.0);
  LowLevel(Value := LevelPct, SetBelow := LOW_LEVEL_SET, ClearAbove := LOW_LEVEL_CLEAR);

  (* 2. Dosing pumps: one reset button serves both *)
  Pump1(StartPB := P1_StartPB, StopOK := P1_StopPB_NC, RunFb := P1_RunFb,
        Permit := NOT LowLevel.Active, ResetCmd := ResetPB,
        FbTimeout := P1_FB_TIMEOUT);
  Pump2(StartPB := P2_StartPB, StopOK := P2_StopPB_NC, RunFb := P2_RunFb,
        Permit := NOT LowLevel.Active, ResetCmd := ResetPB,
        FbTimeout := P2_FB_TIMEOUT);

  (* 3. Outputs and HMI *)
  P1_Run := Pump1.Run;
  P2_Run := Pump2.Run;
  P1_FaultLamp := Pump1.Fault;
  P2_FaultLamp := Pump2.Fault;
  LowLevelLamp := LowLevel.Active;
  P1_Starts := Pump1.Starts;
  P2_Starts := Pump2.Starts;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : DosingSkid;
  END_RESOURCE
END_CONFIGURATION
