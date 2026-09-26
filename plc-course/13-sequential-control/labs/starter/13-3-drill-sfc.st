(* Lab 13-3: Drilling station in textual SFC, with action qualifiers.
   Module 13 (Sequential control). STARTER - the declarations are done for you;
   write the chart where it says TODO, then run:
     python3 tools/plctest.py 13-sequential-control/labs/starter/13-3-drill-sfc.st

   The program body is a Sequential Function Chart in the textual form of
   IEC 61131-3. Only the initial step is written so far. Add the steps,
   transitions and actions described in the lab, for example:

     STEP Clamp:
       ClampValve(S);
     END_STEP

     TRANSITION FROM Idle TO Clamp
       := StartPB AND PartPE AND DrillUpLS;
     END_TRANSITION

     ACTION CountHole:
       HoleCount := HoleCount + 1;
     END_ACTION

   Remember: a step name cannot be the same as a variable name, and two
   transitions leaving the same step must never be TRUE together. *)

PROGRAM DrillCycle
  VAR (* I/O *)
    StartPB     AT %IX0.0 : BOOL;  (* cycle start push-button, NO *)
    PartPE      AT %IX0.1 : BOOL;  (* part present in the fixture *)
    ClampedLS   AT %IX0.2 : BOOL;  (* clamp closed *)
    DrillUpLS   AT %IX0.3 : BOOL;  (* drill head at the top (home) *)
    DrillDownLS AT %IX0.4 : BOOL;  (* drill at full depth *)
    ResetPB     AT %IX0.5 : BOOL;  (* fault reset push-button, NO *)
    ClampValve  AT %QX0.0 : BOOL;  (* clamp solenoid valve: TRUE = clamp *)
    Spindle     AT %QX0.1 : BOOL;  (* spindle motor contactor *)
    FeedDown    AT %QX0.2 : BOOL;  (* feed valve, down *)
    FeedUp      AT %QX0.3 : BOOL;  (* feed valve, up (neither = hold position) *)
    BlowAir     AT %QX0.4 : BOOL;  (* chip blow-off air valve *)
    ReadyLamp   AT %QX0.5 : BOOL;  (* ready for a new part *)
    FaultLamp   AT %QX0.6 : BOOL;  (* feed fault *)
  END_VAR
  VAR (* settings and counters *)
    SpinUpTime  : TIME := T#500ms; (* spindle run-up before the feed starts *)
    DwellTime   : TIME := T#1s;    (* dwell at full depth *)
    BlowTime    : TIME := T#1s;    (* longest blow-off during the retract *)
    FeedTimeout : TIME := T#5s;    (* longest time allowed to reach depth *)
    HoleCount   : INT;             (* holes drilled to full depth *)
  END_VAR

  INITIAL_STEP Idle:
    ReadyLamp(N);
  END_STEP

  (* TODO: the rest of the chart: Clamp, Drill, Dwell, Retract, Unclamp,
     Unload, and the FeedFault branch, with their transitions and the
     action qualifiers N, S, R, D, L and P. *)
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : DrillCycle;
  END_RESOURCE
END_CONFIGURATION
