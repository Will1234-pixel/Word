(* Lab 19-2: Two-speed positioning with an in-position window, stop and travel timeout.
   Module 19 (Motion control, drives and positioning). STARTER - the declarations and the
   simulated axis are done for you; write the logic where it says TODO, then run:
     python3 tools/plctest.py 19-motion-and-drives/labs/starter/19-2-simple-positioning.st

   A carriage on a screw is driven by a speed-controlled drive (think of a VFD with an
   encoder). The PLC closes the position loop in the simplest possible way: run fast, slow
   to a creep speed near the target, and stop inside an in-position window.
   Training exercise only - not a design for a real machine. Stops and faults here are
   ordinary control functions, not safety functions (see Module 20). *)

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
  VAR (* internal - add, rename or remove these as you like *)
    StartEdge : R_TRIG;            (* rising edge of StartPB *)
    MoveTimer : TON;               (* travel watchdog *)
    Remaining : REAL;              (* TargetPos - ActPos, mm: the sign gives the direction *)
  END_VAR

  (* ---- Simulated plant: PROVIDED, keep it first (it plays the part of the input scan).
          It uses SpeedCmd from the previous scan, just as a real drive would. ---- *)
  Axis(SpeedCmd := SpeedCmd);
  ActPos := Axis.ActPos;

  (* ---- Positioning logic ---- *)
  (* TODO: replace these placeholder lines with your positioning logic.
     A state machine (Module 13) with states such as idle / fast / creep / fault works well.
     Decide the speed from the distance to go, the direction from its sign, and finish
     the move inside InPosWindow. Handle Stop, the travel timeout and Reset.
     (MATIEC needs at least one statement in a program body.) *)
  Busy := FALSE;
  InPosition := FALSE;
  Fault := FALSE;
  SpeedCmd := 0.0;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : SimplePositioning;
  END_RESOURCE
END_CONFIGURATION
