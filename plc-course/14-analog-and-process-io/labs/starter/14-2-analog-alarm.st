(* Lab 14-2: FB_AnalogAlarm - HH/H/L/LL process alarms with a deadband
   (hysteresis) and an on-delay, so a noisy signal cannot make them chatter.
   Module 14 (Analog signals and process I/O). STARTER - the interface and the
   program that uses the block are done for you; write the body of
   FB_AnalogAlarm where it says TODO, then run:
     python3 tools/plctest.py 14-analog-and-process-io/labs/starter/14-2-analog-alarm.st

   Tip: four limits behave the same way (two mirrored). You may write a
   small helper FUNCTION_BLOCK for ONE limit and use four instances of it.
   MATIEC cannot make an array of FB instances, so declare four variables.
   Don't call an input "Limit": LIMIT is a standard function name. *)

FUNCTION_BLOCK FB_AnalogAlarm
  VAR_INPUT
    PV       : REAL;   (* process value, engineering units *)
    HH_Limit : REAL;   (* high-high limit *)
    H_Limit  : REAL;   (* high limit *)
    L_Limit  : REAL;   (* low limit *)
    LL_Limit : REAL;   (* low-low limit *)
    Deadband : REAL;   (* engineering units, the same for all four limits *)
    OnDelay  : TIME;   (* the same for all four limits; each needs its own timer *)
  END_VAR
  VAR_OUTPUT
    HH : BOOL;         (* PV >= HH_Limit for OnDelay; clears below HH_Limit - Deadband *)
    H  : BOOL;         (* PV >= H_Limit  for OnDelay; clears below H_Limit  - Deadband *)
    L  : BOOL;         (* PV <= L_Limit  for OnDelay; clears above L_Limit  + Deadband *)
    LL : BOOL;         (* PV <= LL_Limit for OnDelay; clears above LL_Limit + Deadband *)
  END_VAR
  VAR
    (* Add your internal variables here (timers, helper FB instances ...). *)
    HH_Timer : TON;
  END_VAR

  (* TODO: replace these placeholder lines with your logic (see the
     requirements in the Module 14 README, Lab 14-2). *)
  HH := FALSE;
  H := FALSE;
  L := FALSE;
  LL := FALSE;
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

  (* The program is complete: do not change these calls. *)
  LevelAlm(PV := Level, HH_Limit := 90.0, H_Limit := 80.0, L_Limit := 20.0, LL_Limit := 10.0,
           Deadband := 2.0, OnDelay := T#3s);

  PressAlm(PV := Pressure, HH_Limit := 8.0, H_Limit := 7.0, L_Limit := 2.0, LL_Limit := 1.0,
           Deadband := 0.2, OnDelay := T#0s);
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : AlarmDemo;
  END_RESOURCE
END_CONFIGURATION
