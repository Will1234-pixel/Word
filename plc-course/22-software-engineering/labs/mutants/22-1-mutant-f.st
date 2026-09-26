(* Lab 22-1: Write the tests - pump dry-run trip.
   Module 22 (Software engineering). MUTANT F.

   This is a copy of labs/22-1-dry-run-trip.st with ONE deliberate bug,
   the kind a real programmer could easily make. Your tests must FAIL on
   this file. Please do not read it before you have run your tests
   against it: the line marked MUTATION gives the answer away. *)

(* @plctest test=../solutions/22-1-dry-run-trip.test *)

FUNCTION_BLOCK FB_DryRunTrip
  VAR_INPUT
    StartCmd  : BOOL;            (* start request, TRUE while pressed *)
    StopOK    : BOOL;            (* stop circuit healthy (NC stop button) *)
    FlowOK    : BOOL;            (* TRUE while the flow switch proves flow *)
    ResetCmd  : BOOL;            (* alarm reset request *)
    PrimeTime : TIME := T#10s;   (* priming time after every start *)
    LossTime  : TIME := T#5s;    (* continuous no-flow time that trips the pump *)
  END_VAR
  VAR_OUTPUT
    Run   : BOOL;                (* pump run command *)
    Alarm : BOOL;                (* dry-run alarm, latched until reset *)
  END_VAR
  VAR
    PrimeTimer : TON;            (* arms the flow check PrimeTime after a start *)
    LossTimer  : TON;            (* measures CONTINUOUS no-flow time while armed *)
    ResetEdge  : R_TRIG;         (* one reset per press *)
    Armed      : BOOL;           (* flow check armed *)
  END_VAR

  (* 1. Reset acts on the rising edge only, so a held or jammed reset
        button cannot keep the protection switched off. *)
  ResetEdge(CLK := ResetCmd);
  IF ResetEdge.Q THEN
    Alarm := FALSE;
  END_IF;

  (* 2. Start/stop with seal-in. Stop has priority, and an active alarm
        blocks starting. *)
  Run := (StartCmd OR Run) AND StopOK AND NOT Alarm;

  (* 3. The prime timer restarts from zero at every start, because its
        input is the run command itself. The loss timer only runs while
        the check is armed AND there is no flow, so any return of flow
        resets it: it measures continuous loss. *)
  PrimeTimer(IN := Run, PT := PrimeTime);
  IF PrimeTimer.Q THEN
    Armed := TRUE;        (* MUTATION: set once, never cleared when the pump stops *)
  END_IF;
  LossTimer(IN := Run AND Armed AND NOT FlowOK, PT := LossTime);

  (* 4. Trip: latch the alarm and drop the run command (and with it the
        seal-in), so a reset alone can never restart the pump. *)
  IF LossTimer.Q THEN
    Alarm := TRUE;
    Run := FALSE;
  END_IF;
END_FUNCTION_BLOCK

PROGRAM DryRunTrip
  VAR (* I/O *)
    StartPB     AT %IX0.0 : BOOL;  (* Start push-button, NO *)
    StopPB_NC   AT %IX0.1 : BOOL;  (* Stop push-button, NC: TRUE while not pressed *)
    FlowSw      AT %IX0.2 : BOOL;  (* Discharge flow switch FS-101: TRUE = flow *)
    ResetPB     AT %IX0.3 : BOOL;  (* Alarm reset push-button, NO *)
    PumpRun     AT %QX0.0 : BOOL;  (* Pump P-101 contactor *)
    DryRunAlarm AT %QX0.1 : BOOL;  (* Dry-run alarm lamp *)
  END_VAR
  VAR (* internal *)
    P101 : FB_DryRunTrip;          (* transfer pump P-101, default times *)
  END_VAR

  P101(StartCmd := StartPB,
       StopOK   := StopPB_NC,
       FlowOK   := FlowSw,
       ResetCmd := ResetPB);
  PumpRun := P101.Run;
  DryRunAlarm := P101.Alarm;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : DryRunTrip;
  END_RESOURCE
END_CONFIGURATION
