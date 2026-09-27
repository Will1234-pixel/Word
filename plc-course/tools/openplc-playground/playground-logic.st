(* The Playground logic exactly as OpenPLC Editor translated it (from the build output). *)
PROGRAM Playground
  VAR
    StartPB : BOOL; StopPB_NC : BOOL := TRUE; Motor : BOOL; RunLamp : BOOL;
    DelayPB : BOOL; DelayLamp : BOOL; DelayTimer : TON; DelayET : TIME;
    FanSwitch : BOOL; Fan : BOOL; RunOnTimer : TOF; RunOnET : TIME;
    Enable : BOOL := TRUE; OnTimer : TON; OffTimer : TON; OnDone : BOOL; OffDone : BOOL; Beacon : BOOL;
    BottleSensor : BOOL; ResetPB : BOOL; BottleCounter : CTU; Count : INT; BoxFull : BOOL;
    Level : REAL := 50.0; InletPump : BOOL; OutletOpen : BOOL := TRUE;
    StartLevel : REAL := 20.0; StopLevel : REAL := 80.0; HighAlarm : BOOL;
  END_VAR
  Motor := StopPB_NC AND (Motor OR StartPB);
  RunLamp := Motor;
  DelayTimer(IN := DelayPB, PT := T#3s); DelayLamp := DelayTimer.Q; DelayET := DelayTimer.ET;
  RunOnTimer(IN := FanSwitch, PT := T#5s); Fan := RunOnTimer.Q; RunOnET := RunOnTimer.ET;
  OnTimer(IN := (NOT OffDone) AND Enable, PT := T#500ms); OnDone := OnTimer.Q;
  OffTimer(IN := OnDone, PT := T#500ms); OffDone := OffTimer.Q;
  Beacon := (NOT OnDone) AND Enable;
  BottleCounter(CU := BottleSensor, R := ResetPB, PV := 5); BoxFull := BottleCounter.Q; Count := BottleCounter.CV;
  IF Level <= StartLevel THEN InletPump := TRUE; ELSIF Level >= StopLevel THEN InletPump := FALSE; END_IF;
  HighAlarm := Level >= 90.0;
  IF InletPump THEN Level := Level + 0.1; END_IF;
  IF OutletOpen THEN Level := Level - 0.04; END_IF;
  Level := LIMIT(0.0, Level, 100.0);
END_PROGRAM
CONFIGURATION Config0 RESOURCE Res0 ON PLC TASK MainTask(INTERVAL := T#20ms, PRIORITY := 0); PROGRAM Inst0 WITH MainTask : Playground; END_RESOURCE END_CONFIGURATION
