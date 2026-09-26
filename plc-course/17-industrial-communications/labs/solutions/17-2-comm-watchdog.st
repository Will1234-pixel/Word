(* Lab 17-2: Communication watchdog for a reservoir telemetry link.
   Module 17 (Industrial communications). REFERENCE SOLUTION - try the lab yourself first.

   Pump station PS-1 fills reservoir R-2 over a radio link. The Modbus client polls the
   reservoir outstation about once a second and leaves the last values it received in
   %IW100..%IW102, so if the link fails those values simply FREEZE. The only way to know
   the data is fresh is the outstation's heartbeat counter.

   This is a training exercise, not a design for a real overfill protection. A real
   reservoir needs independent overflow protection that does not depend on the radio. *)

PROGRAM CommWatchdog
  VAR (* data from the reservoir outstation, placed here by the Modbus client *)
    RxHeartbeat AT %IW100 : INT;    (* outstation heartbeat: +1 every second *)
    RxLevel     AT %IW101 : INT;    (* reservoir level, % x 10 (0..1000) *)
    RxStatus    AT %IW102 : WORD;   (* bit 0: reservoir inlet valve open *)
  END_VAR
  VAR (* data to the outstation *)
    TxHeartbeat AT %QW100 : INT;    (* our heartbeat: +1 every second *)
  END_VAR
  VAR (* field output *)
    FillPump AT %QX0.0 : BOOL;      (* fill pump P-1 run command *)
  END_VAR
  VAR (* results *)
    CommLost  : BOOL := TRUE;       (* TRUE: the received data cannot be trusted *)
    LossCount : INT;                (* number of healthy -> lost transitions *)
    LevelPct  : REAL := 100.0;      (* level used by the control logic, % *)
    InletOpen : BOOL;               (* inlet valve state used by the control logic *)
  END_VAR
  VAR
    LastBeat   : INT;               (* heartbeat value seen on the previous scan *)
    BeatSeen   : TOF;               (* Q = the heartbeat changed within the last 3 s *)
    HealthyFor : TON;               (* Q = BeatSeen has been TRUE for 5 s without a break *)
    TxTimer    : TON;               (* 1 s clock for our own heartbeat *)
  END_VAR

  (* 1. Our own heartbeat, so the outstation can supervise us in the same way.
        Wrap explicitly rather than rely on INT overflow. *)
  TxTimer(IN := NOT TxTimer.Q, PT := T#1s);
  IF TxTimer.Q THEN
    IF TxHeartbeat >= 32767 THEN
      TxHeartbeat := 0;
    ELSE
      TxHeartbeat := TxHeartbeat + 1;
    END_IF;
  END_IF;

  (* 2. Heartbeat supervision. Look for ANY change, not for an increase: the counter
        wraps, and it restarts from 0 when the outstation reboots.
        A TOF is a "seen within the last 3 s" detector: each change makes IN TRUE for
        one scan, and Q stays TRUE for 3 s after the last change. At power-up nothing
        has been seen yet, so Q starts FALSE and the link counts as unproven. *)
  BeatSeen(IN := RxHeartbeat <> LastBeat, PT := T#3s);
  LastBeat := RxHeartbeat;

  (* Recovery needs 5 s of continuous health, not a single change: one stray update
     (for example the last frame from a failing radio) must not bring the data back. *)
  HealthyFor(IN := BeatSeen.Q, PT := T#5s);

  IF NOT BeatSeen.Q THEN
    IF NOT CommLost THEN              (* count the transition, once, not every scan *)
      IF LossCount < 32767 THEN
        LossCount := LossCount + 1;
      END_IF;
    END_IF;
    CommLost := TRUE;
  ELSIF HealthyFor.Q THEN
    CommLost := FALSE;
  END_IF;

  (* 3. Values used by the control logic: live data while the link is good, otherwise
        fallback values chosen to drive the logic to its safe state. "Assume full" and
        "assume closed" both stop the fill pump. *)
  IF CommLost THEN
    LevelPct := 100.0;
    InletOpen := FALSE;
  ELSE
    LevelPct := INT_TO_REAL(RxLevel) / 10.0;
    InletOpen := (RxStatus AND 16#0001) <> 16#0000;
  END_IF;

  (* 4. Fill pump with hysteresis: start below 40 %, stop at 90 %. Any stop ends the
        fill cycle, so after a comm loss the pump restarts only if the level is below
        the start point, never half-way up the band. *)
  IF CommLost OR NOT InletOpen OR LevelPct >= 90.0 THEN
    FillPump := FALSE;
  ELSIF LevelPct < 40.0 THEN
    FillPump := TRUE;
  END_IF;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : CommWatchdog;
  END_RESOURCE
END_CONFIGURATION
