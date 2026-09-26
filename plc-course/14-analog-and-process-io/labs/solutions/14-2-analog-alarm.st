(* Lab 14-2: FB_AnalogAlarm - HH/H/L/LL process alarms with a deadband
   (hysteresis) and an on-delay, so a noisy signal cannot make them chatter.
   Module 14 (Analog signals and process I/O). REFERENCE SOLUTION - try the lab yourself first.

   Design: one small block, FB_LimitAlarm, handles a single limit. The
   analog alarm block uses four instances of it. MATIEC cannot make an
   array of FB instances, so they are four separate variables. *)

FUNCTION_BLOCK FB_LimitAlarm
  VAR_INPUT
    PV         : REAL;  (* process value, engineering units *)
    LimitValue : REAL;  (* alarm limit ("Limit" would clash with the LIMIT function) *)
    Deadband   : REAL;  (* how far back inside the limit the PV must go to clear *)
    OnDelay    : TIME;  (* how long the PV must stay beyond the limit to raise *)
    HighAlarm  : BOOL;  (* TRUE: alarm above the limit; FALSE: alarm below it *)
  END_VAR
  VAR_OUTPUT
    Active     : BOOL;  (* alarm condition is active *)
  END_VAR
  VAR
    DelayTimer : TON;
    Beyond     : BOOL;  (* PV is at or beyond the limit right now *)
    Returned   : BOOL;  (* PV is back inside the limit by more than the deadband *)
  END_VAR

  IF HighAlarm THEN
    Beyond := PV >= LimitValue;
    Returned := PV < LimitValue - Deadband;
  ELSE
    Beyond := PV <= LimitValue;
    Returned := PV > LimitValue + Deadband;
  END_IF;

  (* The timer runs only while the PV is beyond the limit. Any return
     inside the limit resets it, so the delay always means "continuously
     beyond the limit for OnDelay". *)
  DelayTimer(IN := Beyond, PT := OnDelay);

  (* Raise after the delay; clear at once, but only when the PV has come
     back through the deadband. In between, keep the previous state: that
     is the hysteresis. *)
  IF DelayTimer.Q THEN
    Active := TRUE;
  ELSIF Returned THEN
    Active := FALSE;
  END_IF;
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_AnalogAlarm
  VAR_INPUT
    PV       : REAL;   (* process value, engineering units *)
    HH_Limit : REAL;   (* high-high limit *)
    H_Limit  : REAL;   (* high limit *)
    L_Limit  : REAL;   (* low limit *)
    LL_Limit : REAL;   (* low-low limit *)
    Deadband : REAL;   (* engineering units, the same for all four limits *)
    OnDelay  : TIME;   (* the same for all four limits; each has its own timer *)
  END_VAR
  VAR_OUTPUT
    HH : BOOL;         (* PV >= HH_Limit for OnDelay; clears below HH_Limit - Deadband *)
    H  : BOOL;         (* PV >= H_Limit  for OnDelay; clears below H_Limit  - Deadband *)
    L  : BOOL;         (* PV <= L_Limit  for OnDelay; clears above L_Limit  + Deadband *)
    LL : BOOL;         (* PV <= LL_Limit for OnDelay; clears above LL_Limit + Deadband *)
  END_VAR
  VAR
    HH_Check : FB_LimitAlarm;
    H_Check  : FB_LimitAlarm;
    L_Check  : FB_LimitAlarm;
    LL_Check : FB_LimitAlarm;
  END_VAR

  HH_Check(PV := PV, LimitValue := HH_Limit, Deadband := Deadband, OnDelay := OnDelay, HighAlarm := TRUE);
  H_Check(PV := PV, LimitValue := H_Limit, Deadband := Deadband, OnDelay := OnDelay, HighAlarm := TRUE);
  L_Check(PV := PV, LimitValue := L_Limit, Deadband := Deadband, OnDelay := OnDelay, HighAlarm := FALSE);
  LL_Check(PV := PV, LimitValue := LL_Limit, Deadband := Deadband, OnDelay := OnDelay, HighAlarm := FALSE);

  (* The alarms are independent: at a very high PV both H and HH are
     active. Suppressing H while HH is on is an HMI or alarm-system
     decision (Module 16), not something to bury in the logic. *)
  HH := HH_Check.Active;
  H := H_Check.Active;
  L := L_Check.Active;
  LL := LL_Check.Active;
END_FUNCTION_BLOCK

PROGRAM AlarmDemo
  VAR (* process values: in a real program these come from FB_AnalogInput
         (Lab 14-1). Here the test writes them directly. *)
    Level    : REAL;   (* LT-201 tank level, % *)
    Pressure : REAL;   (* PT-202 header pressure, bar *)
  END_VAR
  VAR
    LevelAlm : FB_AnalogAlarm;
    PressAlm : FB_AnalogAlarm;
  END_VAR

  (* Level: 2 % deadband, 3 s delay - a sloshing surface must not chatter. *)
  LevelAlm(PV := Level, HH_Limit := 90.0, H_Limit := 80.0, L_Limit := 20.0, LL_Limit := 10.0,
           Deadband := 2.0, OnDelay := T#3s);

  (* Pressure: 0.2 bar deadband, no delay. *)
  PressAlm(PV := Pressure, HH_Limit := 8.0, H_Limit := 7.0, L_Limit := 2.0, LL_Limit := 1.0,
           Deadband := 0.2, OnDelay := T#0s);
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : AlarmDemo;
  END_RESOURCE
END_CONFIGURATION
