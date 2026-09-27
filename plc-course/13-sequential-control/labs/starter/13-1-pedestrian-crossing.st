(* Lab 13-1: Pedestrian crossing as a CASE state machine.
   Module 13 (Sequential control). STARTER - the declarations are done for you;
   write the logic where it says TODO, then run:
     python3 tools/plctest.py 13-sequential-control/labs/starter/13-1-pedestrian-crossing.st

   The enumeration, the state variables and the step timer are suggestions:
   the test only looks at the I/O and the settings, so you may organise the
   internals differently. *)

TYPE
  E_Crossing : (Startup, RedAmber, Green, Amber, AllRed, Walk, PedClear);
END_TYPE

PROGRAM PedCrossing
  VAR (* I/O *)
    PedPB    AT %IX0.0 : BOOL;  (* pedestrian request push-button, NO *)
    CarRed   AT %QX0.0 : BOOL;  (* vehicle signal, red *)
    CarAmber AT %QX0.1 : BOOL;  (* vehicle signal, amber *)
    CarGreen AT %QX0.2 : BOOL;  (* vehicle signal, green *)
    PedRed   AT %QX0.3 : BOOL;  (* pedestrian signal, red figure: do not cross *)
    PedGreen AT %QX0.4 : BOOL;  (* pedestrian signal, green figure: cross *)
    WaitLamp AT %QX0.5 : BOOL;  (* WAIT lamp on the push-button box *)
  END_VAR
  VAR (* settings *)
    StartupTime  : TIME := T#3s;   (* all red after power-up *)
    RedAmberTime : TIME := T#2s;   (* red + amber before green *)
    MinGreen     : TIME := T#10s;  (* minimum vehicle green *)
    AmberTime    : TIME := T#3s;   (* amber after green *)
    AllRedTime   : TIME := T#2s;   (* all red before the walk phase *)
    WalkTime     : TIME := T#6s;   (* steady green figure *)
    PedClearTime : TIME := T#4s;   (* flashing green figure *)
  END_VAR
  VAR (* internal - add your own helper variables here *)
    State      : E_Crossing := Startup;
    PrevState  : E_Crossing := Startup;
    FirstScan  : BOOL := TRUE;
    StepEntry  : BOOL;           (* TRUE on the first scan in a state *)
    StepTimer  : TON;            (* time spent in the current state *)
    Request    : BOOL;           (* latched pedestrian request *)
    FlashTimer : TON;            (* 500 ms flasher for the clearance phase *)
    FlashOn    : BOOL;
  END_VAR

  (* TODO: replace these placeholder lines with your logic.
     1. Step bookkeeping: StepEntry and StepTimer (reset on every change).
     2. CASE State OF ... with the transitions of each state.
     3. The request latch and the flasher.
     4. One assignment per output, derived from State. *)
  CarRed := TRUE;
  CarAmber := FALSE;
  CarGreen := FALSE;
  PedRed := TRUE;
  PedGreen := FALSE;
  WaitLamp := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : PedCrossing;
  END_RESOURCE
END_CONFIGURATION
