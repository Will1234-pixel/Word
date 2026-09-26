(* Lab 13-2: Batch tank sequence with watchdogs, Hold/Resume and Abort.
   Module 13 (Sequential control). STARTER - the declarations are done for you;
   write the logic where it says TODO, then run:
     python3 tools/plctest.py 13-sequential-control/labs/starter/13-2-batch-tank.st

   The enumeration and the internal variables are suggestions: the test only
   looks at the I/O, TankTemp, the settings, FaultCode and BatchCount. *)

TYPE
  E_Batch : (Idle, Filling, Mixing, Heating, Draining, Complete, Held, Faulted);
END_TYPE

PROGRAM BatchTank
  VAR (* I/O *)
    StartPB      AT %IX0.0 : BOOL;  (* start a batch, NO *)
    HoldPB       AT %IX0.1 : BOOL;  (* hold the batch, NO *)
    ResumePB     AT %IX0.2 : BOOL;  (* resume a held batch, NO *)
    AbortPB      AT %IX0.3 : BOOL;  (* abort the batch, NO *)
    ResetPB      AT %IX0.4 : BOOL;  (* fault reset, NO *)
    LevelHighLS  AT %IX0.5 : BOOL;  (* high-level switch: TRUE when the tank is full *)
    LevelLowLS   AT %IX0.6 : BOOL;  (* low-level switch: TRUE while liquid covers it (and the heater) *)
    InletValve   AT %QX0.0 : BOOL;  (* fill valve *)
    Agitator     AT %QX0.1 : BOOL;  (* mixer motor *)
    Heater       AT %QX0.2 : BOOL;  (* immersion heater contactor *)
    OutletValve  AT %QX0.3 : BOOL;  (* drain valve *)
    RunLamp      AT %QX0.4 : BOOL;  (* batch running *)
    HeldLamp     AT %QX0.5 : BOOL;  (* batch held *)
    FaultLamp    AT %QX0.6 : BOOL;  (* sequence fault *)
    CompleteLamp AT %QX0.7 : BOOL;  (* batch complete *)
  END_VAR
  VAR (* process value, written by the analog-input layer (Module 14) *)
    TankTemp : REAL;                (* tank temperature, degC *)
  END_VAR
  VAR (* settings *)
    TempSP       : REAL := 60.0;    (* heat until TankTemp >= TempSP *)
    MixTime      : TIME := T#10s;   (* total mixing time *)
    FillTimeout  : TIME := T#30s;   (* watchdog: filling *)
    HeatTimeout  : TIME := T#60s;   (* watchdog: heating *)
    DrainTimeout : TIME := T#30s;   (* watchdog: draining *)
  END_VAR
  VAR (* status for the HMI *)
    FaultCode  : INT;               (* 0 none, 1 fill, 2 heat, 3 drain timeout *)
    BatchCount : INT;               (* completed batches *)
  END_VAR
  VAR (* internal - suggestions; add or change as you like *)
    State     : E_Batch := E_Batch#Idle;
    PrevState : E_Batch := E_Batch#Idle;
    HeldFrom  : E_Batch := E_Batch#Idle;  (* the step to resume *)
    FirstScan : BOOL := TRUE;
    StepEntry : BOOL;               (* TRUE on the first scan in a state *)
    StepTimer : TON;                (* time in the current state *)
    MixDone   : TIME;               (* mixing completed before a hold *)
    Running   : BOOL;               (* in one of the four process steps *)
    (* One instance per line: OpenPLC's compiler can crash on a list of
       FB instances in one declaration (see Appendix E). *)
    StartEdge : R_TRIG;
    HoldEdge : R_TRIG;
    ResumeEdge : R_TRIG;
    AbortEdge : R_TRIG;
    ResetEdge : R_TRIG;
    StartCmd, HoldCmd, ResumeCmd, AbortCmd, ResetCmd : BOOL;
  END_VAR

  (* TODO: replace these placeholder lines with your logic.
     1. Operator commands on the rising edge (R_TRIG).
     2. Step bookkeeping: StepEntry and StepTimer, reset on every change.
     3. Entry actions (BatchCount), before the transitions.
     4. Transitions: Abort first, then Hold, then CASE State OF ...
        with a watchdog in Filling, Heating and Draining.
     5. One assignment per output, derived from State, plus the heater and
        inlet interlocks. *)
  InletValve := FALSE;
  Agitator := FALSE;
  Heater := FALSE;
  OutletValve := FALSE;
  RunLamp := FALSE;
  HeldLamp := FALSE;
  FaultLamp := FALSE;
  CompleteLamp := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : BatchTank;
  END_RESOURCE
END_CONFIGURATION
