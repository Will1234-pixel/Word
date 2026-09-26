(* Lab 19-2: Two-speed positioning with an in-position window, stop and travel timeout.
   Module 19 (Motion control, drives and positioning). REFERENCE SOLUTION - try the lab
   yourself first.

   A carriage on a screw is driven by a speed-controlled drive (think of a VFD with an
   encoder). The PLC closes the position loop in the simplest possible way: run fast, slow
   to a creep speed near the target, and stop inside an in-position window.
   Training exercise only - not a design for a real machine. Stops and faults here are
   ordinary control functions, not safety functions (see Module 20). *)

TYPE
  E_MoveState : (MS_Idle, MS_Fast, MS_Creep, MS_Fault);
END_TYPE

FUNCTION_BLOCK FB_AxisSim
  (* PROVIDED - do not change. A simulated positioning axis: drive + screw + carriage +
     encoder (already scaled to mm) in one block. Call it once per scan.
     - SpeedCmd is limited to +/- MaxSpeed, like a drive's maximum-speed parameter.
     - The actual speed ramps towards SpeedCmd at Accel, like a drive's accel/decel ramp,
       so the carriage does NOT stop dead when SpeedCmd goes to zero.
     - The position is the integral of the actual speed.
     - Jam = TRUE simulates a jammed carriage: it cannot move at all. The tests use it. *)
  VAR_INPUT
    SpeedCmd : REAL;               (* speed reference, mm/s; positive = forward *)
    Jam      : BOOL;               (* test hook: TRUE = carriage jammed *)
  END_VAR
  VAR_OUTPUT
    ActPos   : REAL;               (* actual position, mm (the encoder feedback) *)
    ActSpeed : REAL;               (* actual speed, mm/s *)
  END_VAR
  VAR CONSTANT
    CycleTime : REAL := 0.01;      (* s - must equal the task interval (T#10ms) *)
    Accel     : REAL := 500.0;     (* ramp rate, mm/s^2 (0 -> 100 mm/s takes 0.2 s) *)
    MaxSpeed  : REAL := 150.0;     (* mm/s *)
  END_VAR
  VAR
    RampTarget : REAL;             (* limited speed reference, mm/s *)
    RampStep   : REAL;             (* largest speed change in one cycle, mm/s *)
  END_VAR

  RampTarget := LIMIT(-MaxSpeed, SpeedCmd, MaxSpeed);
  RampStep := Accel * CycleTime;
  IF Jam THEN
    ActSpeed := 0.0;
  ELSIF ActSpeed < RampTarget - RampStep THEN
    ActSpeed := ActSpeed + RampStep;
  ELSIF ActSpeed > RampTarget + RampStep THEN
    ActSpeed := ActSpeed - RampStep;
  ELSE
    ActSpeed := RampTarget;
  END_IF;
  ActPos := ActPos + ActSpeed * CycleTime;
END_FUNCTION_BLOCK

PROGRAM SimplePositioning
  VAR (* I/O *)
    StartPB    AT %IX0.0 : BOOL;   (* Start push-button, NO: a rising edge starts a move *)
    StopPB_NC  AT %IX0.1 : BOOL;   (* Stop push-button, NC: TRUE while NOT pressed *)
    ResetPB    AT %IX0.2 : BOOL;   (* Fault reset push-button, NO *)
    Busy       AT %QX0.0 : BOOL;   (* a move is in progress *)
    InPosition AT %QX0.1 : BOOL;   (* the last move finished and the axis is in the window *)
    Fault      AT %QX0.2 : BOOL;   (* travel timeout, latched until Reset *)
  END_VAR
  VAR (* HMI and drive interface *)
    TargetPos : REAL;              (* target position from the HMI, mm *)
    ActPos    : REAL;              (* actual position from the axis, mm *)
    SpeedCmd  : REAL;              (* speed reference to the drive, mm/s; + = forward *)
  END_VAR
  VAR CONSTANT (* parameters - do not change, the tests rely on them *)
    FastSpeed   : REAL := 100.0;   (* mm/s *)
    CreepSpeed  : REAL := 10.0;    (* mm/s *)
    SlowDist    : REAL := 20.0;    (* change to creep speed this far from the target, mm *)
    InPosWindow : REAL := 0.5;     (* in position when ABS(TargetPos - ActPos) <= this, mm *)
    MoveTimeout : TIME := T#10s;   (* a move still running after this is a fault *)
  END_VAR
  VAR (* simulated plant - PROVIDED *)
    Axis : FB_AxisSim;
  END_VAR
  VAR (* internal *)
    State     : E_MoveState;       (* starts at MS_Idle, the first value *)
    StartEdge : R_TRIG;
    MoveTimer : TON;               (* travel watchdog *)
    Remaining : REAL;              (* TargetPos - ActPos, mm: the sign gives the direction *)
    Distance  : REAL;              (* ABS(Remaining), mm *)
    MoveDone  : BOOL;              (* the last move finished normally *)
  END_VAR

  (* ---- Simulated plant: PROVIDED, keep it first (it plays the part of the input scan).
          It uses SpeedCmd from the previous scan, just as a real drive would. ---- *)
  Axis(SpeedCmd := SpeedCmd);
  ActPos := Axis.ActPos;

  (* ---- Positioning logic ---- *)
  StartEdge(CLK := StartPB);
  Remaining := TargetPos - ActPos;
  Distance := ABS(Remaining);

  (* Travel watchdog: runs only while a move is active, so it restarts from zero for
     every move. It is called before the CASE and so sees the state from the previous
     scan: there is always at least one call with IN = FALSE between two moves, even when
     the next Start comes on the scan right after a move ends. (The 10 ms lag is
     irrelevant next to a 10 s timeout.) *)
  MoveTimer(IN := (State = MS_Fast) OR (State = MS_Creep), PT := MoveTimeout);

  (* State transitions. In the moving states the order of the tests sets the priority:
     Stop first, then the timeout, then normal progress. *)
  CASE State OF
    MS_Idle:
      IF StartEdge.Q AND StopPB_NC THEN
        IF Distance <= InPosWindow THEN
          MoveDone := TRUE;               (* already there: nothing to move *)
        ELSIF Distance <= SlowDist THEN
          MoveDone := FALSE;
          State := MS_Creep;              (* short move: creep all the way *)
        ELSE
          MoveDone := FALSE;
          State := MS_Fast;
        END_IF;
      END_IF;

    MS_Fast:
      IF NOT StopPB_NC THEN
        State := MS_Idle;                 (* move abandoned; a new Start is needed *)
      ELSIF MoveTimer.Q THEN
        State := MS_Fault;
      ELSIF Distance <= SlowDist THEN
        State := MS_Creep;
      END_IF;

    MS_Creep:
      IF NOT StopPB_NC THEN
        State := MS_Idle;
      ELSIF MoveTimer.Q THEN
        State := MS_Fault;
      ELSIF Distance <= InPosWindow THEN
        MoveDone := TRUE;
        State := MS_Idle;
      END_IF;

    MS_Fault:
      IF ResetPB THEN
        State := MS_Idle;                 (* reset clears the fault but never restarts *)
      END_IF;
  END_CASE;

  (* Outputs, from the state. *)
  Busy := (State = MS_Fast) OR (State = MS_Creep);
  Fault := (State = MS_Fault);

  (* In position = the last move finished normally AND the axis is inside the window
     now. It is monitored, not just remembered: if the carriage overshoots or is pushed
     out of the window, the signal drops (and nothing restarts by itself). *)
  InPosition := MoveDone AND (Distance <= InPosWindow);

  CASE State OF
    MS_Fast:
      SpeedCmd := FastSpeed;
    MS_Creep:
      SpeedCmd := CreepSpeed;
  ELSE
    SpeedCmd := 0.0;
  END_CASE;
  IF Remaining < 0.0 THEN
    SpeedCmd := -SpeedCmd;               (* target behind us: run in reverse *)
  END_IF;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : SimplePositioning;
  END_RESOURCE
END_CONFIGURATION
