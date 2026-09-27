(* Lab 13-2: Batch tank sequence with watchdogs, Hold/Resume and Abort.
   Module 13 (Sequential control). REFERENCE SOLUTION - try the lab yourself first.

   Fill -> Mix -> Heat -> Drain, as a CASE state machine. Every step that
   waits for the plant has a watchdog that leads to a fault state. Hold
   parks the batch safely and Resume returns to the step it came from;
   Abort ends the batch from any running or held state.

   Order of the program:
     1. operator commands (rising edges)
     2. step bookkeeping: entry flag and step timer
     3. entry actions
     4. transitions: Abort, then Hold, then the step's own transitions
     5. outputs derived from the state, plus interlocks that apply in
        every state *)

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
  VAR (* internal *)
    State     : E_Batch := Idle;
    PrevState : E_Batch := Idle;
    HeldFrom  : E_Batch := Idle;  (* the step to resume *)
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

  (* 1. Commands act once per press. A button that is already held when the
        PLC starts is not treated as a press. *)
  StartEdge(CLK := StartPB);
  HoldEdge(CLK := HoldPB);
  ResumeEdge(CLK := ResumePB);
  AbortEdge(CLK := AbortPB);
  ResetEdge(CLK := ResetPB);
  StartCmd  := StartEdge.Q AND NOT FirstScan;
  HoldCmd   := HoldEdge.Q AND NOT FirstScan;
  ResumeCmd := ResumeEdge.Q AND NOT FirstScan;
  AbortCmd  := AbortEdge.Q AND NOT FirstScan;
  ResetCmd  := ResetEdge.Q AND NOT FirstScan;

  (* 2. Step bookkeeping: StepEntry is TRUE for one scan after each change,
        and the step timer restarts from zero on every entry. *)
  StepEntry := (State <> PrevState) OR FirstScan;
  FirstScan := FALSE;
  PrevState := State;
  StepTimer(IN := NOT StepEntry, PT := T#24h);

  (* 3. Entry actions: done once, on the first scan in a state. They come
        BEFORE the transitions, because StepEntry belongs to the state the
        scan started in. *)
  IF StepEntry AND (State = Complete) THEN
    BatchCount := BatchCount + 1;
  END_IF;

  Running := (State = Filling) OR (State = Mixing)
          OR (State = Heating) OR (State = Draining);

  (* 4. Transitions. Abort beats Hold, and both beat the step's own
        transitions, so they are tested first. *)
  IF AbortCmd AND (Running OR (State = Held)) THEN
    State := Idle;

  ELSIF HoldCmd AND Running THEN
    IF State = Mixing THEN
      (* bank the mixing done so far: it still counts after Resume *)
      MixDone := ADD_TIME(MixDone, StepTimer.ET);
    END_IF;
    HeldFrom := State;
    State := Held;

  ELSE
    CASE State OF
      Idle, Complete:
        IF StartCmd THEN
          MixDone := T#0s;
          State := Filling;
        END_IF;

      Filling:
        IF LevelHighLS THEN
          State := Mixing;
        ELSIF StepTimer.ET >= FillTimeout THEN
          FaultCode := 1;
          State := Faulted;
        END_IF;

      Mixing:
        IF ADD_TIME(MixDone, StepTimer.ET) >= MixTime THEN
          State := Heating;
        END_IF;

      Heating:
        IF TankTemp >= TempSP THEN
          State := Draining;
        ELSIF StepTimer.ET >= HeatTimeout THEN
          FaultCode := 2;
          State := Faulted;
        END_IF;

      Draining:
        IF NOT LevelLowLS THEN
          State := Complete;
        ELSIF StepTimer.ET >= DrainTimeout THEN
          FaultCode := 3;
          State := Faulted;
        END_IF;

      Held:
        IF ResumeCmd THEN
          State := HeldFrom;        (* its step timer and watchdog restart *)
        END_IF;

      Faulted:
        IF ResetCmd THEN
          FaultCode := 0;
          State := Idle;    (* the operator decides what happens next *)
        END_IF;
    ELSE
      FaultCode := 99;              (* impossible state value: stop safely *)
      State := Faulted;
    END_CASE;
  END_IF;

  (* 5. Outputs from the state (recomputed after the transitions, so an
        output changes in the same scan as its state). The interlocks are
        written here, separately from the sequence, so they hold whatever
        state the sequence is in. *)
  Running := (State = Filling) OR (State = Mixing)
          OR (State = Heating) OR (State = Draining);

  InletValve  := (State = Filling) AND NOT LevelHighLS;  (* never overfill *)
  Agitator    := (State = Mixing) OR (State = Heating);
  Heater      := (State = Heating) AND LevelLowLS;       (* elements covered *)
  OutletValve := State = Draining;

  RunLamp      := Running;
  HeldLamp     := State = Held;
  FaultLamp    := State = Faulted;
  CompleteLamp := State = Complete;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : BatchTank;
  END_RESOURCE
END_CONFIGURATION
