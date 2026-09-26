(* Lab 13-3: Drilling station in textual SFC, with action qualifiers.
   Module 13 (Sequential control). REFERENCE SOLUTION - try the lab yourself first.

   The whole program body is a Sequential Function Chart written in the
   textual form of IEC 61131-3 (the form MATIEC compiles, and the form the
   OpenPLC Editor generates from a graphical chart).

        Idle          ReadyLamp(N)
          + StartPB AND PartPE AND DrillUpLS
        Clamp         ClampValve(S)
          + ClampedLS
        Drill         Spindle(S), FeedDown(D, SpinUpTime)
          + DrillDownLS                 + NOT DrillDownLS AND Drill.T >= FeedTimeout
        Dwell         CountHole(P)      FeedFault   FaultLamp(N), Spindle(R)
          + Dwell.T >= DwellTime          + ResetPB  (jump to Retract)
        Retract       FeedUp(N), BlowAir(L, BlowTime)
          + DrillUpLS
        Unclamp       Spindle(R), ClampValve(R)
          + NOT ClampedLS
        Unload        (waits for the part to be taken out)
          + NOT PartPE  (jump back to Idle)

   Why these qualifiers:
     S/R  the clamp and the spindle stay on across several steps, so they
          are set in one step and reset in a later one;
     D    the feed starts only after the spindle has run up to speed;
     L    the chip blow-off lasts at most BlowTime, and stops earlier if the
          drill reaches the top first;
     P    the hole counter is incremented once, when the Dwell step starts;
     N    everything else is on exactly while its step is active.
   The two transitions out of Drill are written to be mutually exclusive:
   MATIEC fires every enabled transition whose condition is TRUE. *)

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

  TRANSITION FROM Idle TO Clamp
    := StartPB AND PartPE AND DrillUpLS;
  END_TRANSITION

  STEP Clamp:
    ClampValve(S);
  END_STEP

  TRANSITION FROM Clamp TO Drill
    := ClampedLS;
  END_TRANSITION

  STEP Drill:
    Spindle(S);
    FeedDown(D, SpinUpTime);
  END_STEP

  (* Alternative branch: depth reached, or the feed watchdog. *)
  TRANSITION FROM Drill TO Dwell
    := DrillDownLS;
  END_TRANSITION

  TRANSITION FROM Drill TO FeedFault
    := NOT DrillDownLS AND (Drill.T >= FeedTimeout);
  END_TRANSITION

  STEP Dwell:
    CountHole(P);
  END_STEP

  TRANSITION FROM Dwell TO Retract
    := Dwell.T >= DwellTime;
  END_TRANSITION

  STEP Retract:
    FeedUp(N);
    BlowAir(L, BlowTime);
  END_STEP

  TRANSITION FROM Retract TO Unclamp
    := DrillUpLS;
  END_TRANSITION

  STEP Unclamp:
    Spindle(R);
    ClampValve(R);
  END_STEP

  TRANSITION FROM Unclamp TO Unload
    := NOT ClampedLS;
  END_TRANSITION

  STEP Unload:
  END_STEP

  TRANSITION FROM Unload TO Idle
    := NOT PartPE;
  END_TRANSITION

  (* Fault branch: stop the spindle and hold the feed where it is, keep the
     part clamped, and retract only when the operator resets. *)
  STEP FeedFault:
    FaultLamp(N);
    Spindle(R);
  END_STEP

  TRANSITION FROM FeedFault TO Retract
    := ResetPB;
  END_TRANSITION

  ACTION CountHole:
    HoleCount := HoleCount + 1;
  END_ACTION
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : DrillCycle;
  END_RESOURCE
END_CONFIGURATION
