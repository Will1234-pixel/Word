(* Lab 22-2: Refactor safely - chemical dosing skid.
   Module 22 (Software engineering). STARTER = the LEGACY PROGRAM.

   This program is running on a real (imaginary) plant. It works, and it
   PASSES the characterisation test labs/22-2-dosing-skid-refactor.test.
   Your job: restructure it into well-named functions and function blocks
   WITHOUT changing what it does. Keep every interface name (the located
   I/O and the HMI tags). Run the test after every small step:
     python3 tools/plctest.py my-work/22-2-dosing-skid-refactor.st 22-software-engineering/labs/22-2-dosing-skid-refactor.test

   Everything below the next comment is the original legacy code, warts and
   all. Read it carefully before you change anything. *)

(* @plctest expect=pass *)

PROGRAM DosingSkid
  VAR
    P1_StartPB   AT %IX0.0 : BOOL;
    P1_StopPB_NC AT %IX0.1 : BOOL;
    P2_StartPB   AT %IX0.2 : BOOL;
    P2_StopPB_NC AT %IX0.3 : BOOL;
    P1_RunFb     AT %IX0.4 : BOOL;
    P2_RunFb     AT %IX0.5 : BOOL;
    ResetPB      AT %IX0.6 : BOOL;
    LevelRaw     AT %IW0   : INT;
    P1_Run       AT %QX0.0 : BOOL;
    P2_Run       AT %QX0.1 : BOOL;
    P1_FaultLamp AT %QX0.2 : BOOL;
    P2_FaultLamp AT %QX0.3 : BOOL;
    LowLevelLamp AT %QX0.4 : BOOL;
  END_VAR
  VAR
    LevelPct  : REAL;
    P1_Starts : INT;
    P2_Starts : INT;
    T1 : TON;
    T2 : TON;
    F1 : BOOL;
    F2 : BOOL;
    LL : BOOL;
    X : REAL;
    OLD1 : BOOL;
    OLD2 : BOOL;
    OLDR : BOOL;
    TMP2 : INT;
  END_VAR

  (* level *)
  X := INT_TO_REAL(LevelRaw);
  LevelPct := X * 100.0 / 27648.0;
  IF LevelPct < 10.0 THEN
    LL := TRUE;
  END_IF;
  IF LevelPct > 15.0 THEN
    LL := FALSE;
  END_IF;
  LowLevelLamp := LL;

  (* reset *)
  IF ResetPB AND NOT OLDR THEN
    F1 := FALSE;
    F2 := FALSE;
  END_IF;
  OLDR := ResetPB;

  (* P1 *)
  (* P1_Run := P1_StartPB AND P1_StopPB_NC; old version, JK 2009 *)
  IF P1_StopPB_NC THEN
    IF NOT F1 THEN
      IF NOT LL THEN
        IF P1_StartPB THEN
          P1_Run := TRUE;
        END_IF;
      ELSE
        P1_Run := FALSE;
      END_IF;
    ELSE
      P1_Run := FALSE;
    END_IF;
  ELSE
    P1_Run := FALSE;
  END_IF;
  T1(IN := P1_Run AND NOT P1_RunFb, PT := T#3s);  (* 3 sec *)
  IF T1.Q THEN
    F1 := TRUE;
    P1_Run := FALSE;
  END_IF;
  P1_FaultLamp := F1;
  IF P1_Run AND NOT OLD1 THEN
    P1_Starts := P1_Starts + 1;
  END_IF;
  OLD1 := P1_Run;

  (* P2 - copy of P1 *)
  IF P2_StopPB_NC THEN
    IF NOT F2 THEN
      IF NOT LL THEN
        IF P2_StartPB THEN
          P2_Run := TRUE;
        END_IF;
      ELSE
        P2_Run := FALSE;
      END_IF;
    ELSE
      P2_Run := FALSE;
    END_IF;
  ELSE
    P2_Run := FALSE;
  END_IF;
  T2(IN := P2_Run AND NOT P2_RunFb, PT := T#5s);  (* 4 sec *)
  IF T2.Q THEN
    F2 := TRUE;
    P2_Run := FALSE;
  END_IF;
  P2_FaultLamp := F2;
  IF P2_Run AND NOT OLD2 THEN
    P2_Starts := P2_Starts + 1;
  END_IF;
  OLD2 := P2_Run;
  TMP2 := 0;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : DosingSkid;
  END_RESOURCE
END_CONFIGURATION
