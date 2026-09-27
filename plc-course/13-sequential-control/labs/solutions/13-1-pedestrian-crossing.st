(* Lab 13-1: Pedestrian crossing as a CASE state machine.
   Module 13 (Sequential control). REFERENCE SOLUTION - try the lab yourself first.

   The crossing rests on vehicle green. A pedestrian request is remembered,
   and it is served only after the vehicles have had their minimum green.
   The program has four parts, always in this order:
     1. step bookkeeping: an entry flag and ONE step timer, reset on every
        change of state
     2. the CASE: one branch per state, containing only its transitions
     3. things that are remembered between states (the request latch, the
        flasher)
     4. outputs derived from the state: exactly one assignment per output *)

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
  VAR (* internal *)
    State      : E_Crossing := Startup;
    PrevState  : E_Crossing := Startup;
    FirstScan  : BOOL := TRUE;
    StepEntry  : BOOL;           (* TRUE on the first scan in a state *)
    StepTimer  : TON;            (* time spent in the current state *)
    Request    : BOOL;           (* latched pedestrian request *)
    FlashTimer : TON;            (* 500 ms flasher for the clearance phase *)
    FlashOn    : BOOL;
  END_VAR

  (* 1. Step bookkeeping. StepEntry is TRUE for exactly one scan after every
        change of state (and on the very first scan). Calling the step timer
        with IN := NOT StepEntry resets it for that scan, so StepTimer.ET
        always means "time in the current state". *)
  StepEntry := (State <> PrevState) OR FirstScan;
  FirstScan := FALSE;
  PrevState := State;
  StepTimer(IN := NOT StepEntry, PT := T#24h);

  (* 2. Transitions. Only the branch of the current state runs, so the
        crossing can move at most one state per scan. *)
  CASE State OF
    Startup:
      IF StepTimer.ET >= StartupTime THEN
        State := RedAmber;
      END_IF;

    RedAmber:
      IF StepTimer.ET >= RedAmberTime THEN
        State := Green;
      END_IF;

    Green:
      (* rest here until someone asks, but always give the minimum green *)
      IF Request AND (StepTimer.ET >= MinGreen) THEN
        State := Amber;
      END_IF;

    Amber:
      IF StepTimer.ET >= AmberTime THEN
        State := AllRed;
      END_IF;

    AllRed:
      IF StepTimer.ET >= AllRedTime THEN
        State := Walk;
      END_IF;

    Walk:
      IF StepTimer.ET >= WalkTime THEN
        State := PedClear;
      END_IF;

    PedClear:
      IF StepTimer.ET >= PedClearTime THEN
        State := RedAmber;
      END_IF;
  ELSE
    (* An impossible value: restart through the all-red start-up phase. *)
    State := Startup;
  END_CASE;

  (* 3a. Request latch. A press is remembered in every state except Walk,
         where the pedestrians already have their green. The latch is
         cleared in the same scan as the walk phase starts, so the WAIT lamp
         goes out exactly when the green figure lights. *)
  Request := (Request OR PedPB) AND (State <> Walk);

  (* 3b. Flasher for the clearance phase: toggles every 500 ms and starts
         with the green figure OFF, so pedestrians see the change at once. *)
  FlashTimer(IN := (State = PedClear) AND NOT FlashTimer.Q, PT := T#500ms);
  IF State <> PedClear THEN
    FlashOn := FALSE;
  ELSIF FlashTimer.Q THEN
    FlashOn := NOT FlashOn;
  END_IF;

  (* 4. Outputs, derived from the state. Reading down a column of the lab's
        state/output table gives each of these lines. *)
  CarRed   := (State = Startup) OR (State = RedAmber)
           OR (State = AllRed) OR (State = Walk)
           OR (State = PedClear);
  CarAmber := (State = RedAmber) OR (State = Amber);
  CarGreen := State = Green;
  PedGreen := (State = Walk) OR ((State = PedClear) AND FlashOn);
  PedRed   := (State <> Walk) AND (State <> PedClear);
  WaitLamp := Request;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : PedCrossing;
  END_RESOURCE
END_CONFIGURATION
