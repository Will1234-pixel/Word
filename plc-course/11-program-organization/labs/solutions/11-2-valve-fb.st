(* Lab 11-2: A reusable on/off valve function block with limit switches.
   Module 11 (Program organisation). REFERENCE SOLUTION - try the lab yourself first.

   Two spring-return pneumatic valves on a reactor use the same FB_Valve:
     XV101  reactor feed valve      fail CLOSED (loss of air/power stops the feed)
     XV102  jacket cooling valve    fail OPEN   (loss of air/power keeps cooling on)
   The FB is told which way its valve fails and works out the solenoid state
   for itself. Training exercise only: a real reactor trip belongs in a
   safety instrumented system, not in basic control logic (Module 20). *)

FUNCTION_BLOCK FB_Valve
  (* ------------------------------------------------------------------
     FB_Valve - single-solenoid, spring-return on/off valve with open and
     closed limit switches (ZSO / ZSC).

     Behaviour
       - OpenCmd TRUE = open the valve, FALSE = close it (a level command,
         as a sequence or HMI would give it).
       - FailOpen says where the spring takes the valve when the solenoid is
         de-energised. The solenoid is energised to move the valve AWAY from
         that fail position:  Solenoid = OpenCmd XOR FailOpen.
       - IsOpen / IsClosed are only TRUE when exactly one limit switch is made.
       - TravelFault latches if the valve is not in the commanded end position
         for longer than TravelTime. The timer restarts whenever the command
         changes, so a reversal mid-stroke gets a full TravelTime. It also
         catches a valve that drifts out of position with no command change
         (for example loss of instrument air).
       - LimitFault latches if both limit switches are made together for
         500 ms (a switch, adjustment or wiring fault; the filter ignores a
         momentary overlap).
       - On any fault the solenoid is de-energised, so the valve goes to its
         fail position, and stays there until Reset.
       - Reset clears both faults. A limit fault whose cause is still present
         is set again in the same scan, so it never appears to clear. After a
         reset the valve follows OpenCmd again and gets a fresh TravelTime; a
         valve that is still stuck trips again when that time runs out.

     Version history
       1.0  first release (Lab 11-2)
     ------------------------------------------------------------------ *)
  VAR_INPUT
    OpenCmd    : BOOL;            (* TRUE = open, FALSE = close *)
    OpenLS     : BOOL;            (* open limit switch (ZSO), TRUE = fully open *)
    ClosedLS   : BOOL;            (* closed limit switch (ZSC), TRUE = fully closed *)
    Reset      : BOOL;            (* fault reset *)
    FailOpen   : BOOL;            (* configuration: TRUE = spring opens the valve *)
    TravelTime : TIME := T#10s;   (* longest acceptable stroke *)
  END_VAR
  VAR_OUTPUT
    Solenoid    : BOOL;           (* solenoid output *)
    IsOpen      : BOOL;           (* confirmed open *)
    IsClosed    : BOOL;           (* confirmed closed *)
    TravelFault : BOOL;           (* latched: did not reach / stay in position *)
    LimitFault  : BOOL;           (* latched: both limit switches made *)
    Fault       : BOOL;           (* TravelFault OR LimitFault *)
  END_VAR
  VAR
    TravelTmr  : TON;
    LimitTmr   : TON;
    InPosition : BOOL;            (* at the end position the command asks for *)
    LastCmd    : BOOL;            (* OpenCmd on the previous call *)
  END_VAR

  (* 1. Decode the limit switches. Exactly one must be made. *)
  IsOpen := OpenLS AND NOT ClosedLS;
  IsClosed := ClosedLS AND NOT OpenLS;

  (* 2. Reset first, so a fault whose cause is still present re-latches below. *)
  IF Reset THEN
    TravelFault := FALSE;
    LimitFault := FALSE;
  END_IF;

  (* 3. Limit switch discrepancy: both made is physically impossible. *)
  LimitTmr(IN := OpenLS AND ClosedLS, PT := T#500ms);
  IF LimitTmr.Q THEN
    LimitFault := TRUE;
  END_IF;

  (* 4. Travel supervision. The timer runs while the valve is not where it
        was told to be. It is held off for one call when the command changes
        (so it restarts) and while a fault is latched (so that a reset gives
        the valve a fresh TravelTime instead of an instant re-trip). *)
  IF OpenCmd THEN
    InPosition := IsOpen;
  ELSE
    InPosition := IsClosed;
  END_IF;
  TravelTmr(IN := NOT InPosition AND (OpenCmd = LastCmd)
                  AND NOT TravelFault AND NOT LimitFault,
            PT := TravelTime);
  IF TravelTmr.Q THEN
    TravelFault := TRUE;
  END_IF;
  LastCmd := OpenCmd;

  (* 5. Outputs. On a fault the solenoid drops out: the spring takes the
        valve to its fail (safe) position, whichever way that is. *)
  Fault := TravelFault OR LimitFault;
  IF Fault THEN
    Solenoid := FALSE;
  ELSE
    Solenoid := OpenCmd XOR FailOpen;
  END_IF;
END_FUNCTION_BLOCK


PROGRAM ReactorValves
  VAR (* inputs *)
    XV101_OpenSw AT %IX0.0 : BOOL;  (* XV-101 panel selector: TRUE = OPEN, FALSE = CLOSE *)
    XV101_ZSO    AT %IX0.1 : BOOL;  (* XV-101 open limit switch *)
    XV101_ZSC    AT %IX0.2 : BOOL;  (* XV-101 closed limit switch *)
    XV102_OpenSw AT %IX0.3 : BOOL;  (* XV-102 panel selector: TRUE = OPEN, FALSE = CLOSE *)
    XV102_ZSO    AT %IX0.4 : BOOL;  (* XV-102 open limit switch *)
    XV102_ZSC    AT %IX0.5 : BOOL;  (* XV-102 closed limit switch *)
    ResetPB      AT %IX0.6 : BOOL;  (* Fault reset push-button, NO *)
  END_VAR
  VAR (* outputs *)
    XV101_SOL    AT %QX0.0 : BOOL;  (* XV-101 solenoid: energise to OPEN (fail closed) *)
    XV102_SOL    AT %QX0.1 : BOOL;  (* XV-102 solenoid: energise to CLOSE (fail open) *)
    FaultLamp    AT %QX0.2 : BOOL;  (* Common "valve fault" lamp *)
  END_VAR
  VAR (* device instances *)
    XV101 : FB_Valve;               (* reactor feed valve *)
    XV102 : FB_Valve;               (* jacket cooling-water valve *)
  END_VAR

  XV101(OpenCmd    := XV101_OpenSw,
        OpenLS     := XV101_ZSO,
        ClosedLS   := XV101_ZSC,
        Reset      := ResetPB,
        FailOpen   := FALSE,        (* spring closes it: stop feeding on loss of air *)
        TravelTime := T#5s);
  XV101_SOL := XV101.Solenoid;

  XV102(OpenCmd    := XV102_OpenSw,
        OpenLS     := XV102_ZSO,
        ClosedLS   := XV102_ZSC,
        Reset      := ResetPB,
        FailOpen   := TRUE,         (* spring opens it: keep cooling on loss of air *)
        TravelTime := T#8s);        (* larger valve, slower actuator *)
  XV102_SOL := XV102.Solenoid;

  FaultLamp := XV101.Fault OR XV102.Fault;
END_PROGRAM


CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : ReactorValves;
  END_RESOURCE
END_CONFIGURATION
