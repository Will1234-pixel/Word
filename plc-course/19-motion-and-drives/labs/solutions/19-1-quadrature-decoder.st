(* Lab 19-1: Quadrature decoder (x4) with direction and illegal-transition error.
   Module 19 (Motion control, drives and positioning). REFERENCE SOLUTION - try the lab
   yourself first.

   Training exercise only. A scanned decoder like this can follow an encoder only while the
   shaft turns very slowly (at most one A/B state change per scan). Real machines count
   encoder pulses in a high-speed counter (HSC) or in the drive - see the lesson. *)

PROGRAM QuadDecoder
  VAR (* I/O *)
    EncA     AT %IX0.0 : BOOL;  (* Encoder channel A *)
    EncB     AT %IX0.1 : BOOL;  (* Encoder channel B *)
    ResetPB  AT %IX0.2 : BOOL;  (* Reset push-button, NO: zero the count and clear the error *)
    EncError AT %QX0.0 : BOOL;  (* Latched: an illegal transition (both channels changed) *)
  END_VAR
  VAR (* results for the rest of the program and the HMI *)
    Position  : DINT;           (* counts, x4 decoding; forward (A leads B) counts up *)
    Direction : INT;            (* +1 after a forward count, -1 after a reverse count, 0 after reset *)
  END_VAR
  VAR (* internal *)
    Initialised : BOOL;         (* FALSE until the first scan has captured the A/B state *)
    NewState    : INT;          (* where A/B are now in the forward sequence, 0..3 *)
    OldState    : INT;          (* the same, one scan ago *)
    StepsFwd    : INT;          (* how many states forward we moved since the last scan, 0..3 *)
  END_VAR

  (* 1. Turn the two channels into a number 0..3 that counts UP along the forward sequence
        AB = 00 -> 10 -> 11 -> 01 -> 00 (A leads B). Quadrature is a 2-bit Gray code, and
        this is simply Gray code converted to binary. *)
  IF EncA THEN
    IF EncB THEN
      NewState := 2;            (* AB = 11 *)
    ELSE
      NewState := 1;            (* AB = 10 *)
    END_IF;
  ELSE
    IF EncB THEN
      NewState := 3;            (* AB = 01 *)
    ELSE
      NewState := 0;            (* AB = 00 *)
    END_IF;
  END_IF;

  (* 2. First scan: there is no previous state to compare with, so take the present state as
        the starting point. Without this, an encoder that powers up at AB = 11 would look like
        an illegal jump from 00, and one at AB = 10 would add a false count. *)
  IF NOT Initialised THEN
    OldState := NewState;
    Initialised := TRUE;
  END_IF;

  (* 3. Steps moved forward since the last scan, modulo 4. Adding 4 first keeps the left
        operand positive, because MOD takes the sign of the dividend. *)
  StepsFwd := (NewState - OldState + 4) MOD 4;

  CASE StepsFwd OF
    1:  (* one state forward *)
      Position := Position + 1;
      Direction := 1;
    3:  (* one state backward (= three forward, modulo 4) *)
      Position := Position - 1;
      Direction := -1;
    2:  (* two states in one scan: both channels changed, so the direction is unknown and
           counts were lost. Do not guess - flag it and keep the flag until a reset. *)
      EncError := TRUE;
  END_CASE;
  (* StepsFwd = 0: no change since the last scan, nothing to do. *)

  (* 4. Always remember the new state - also after an illegal transition and while Reset is
        held - so the next scan compares against where the encoder really is. *)
  OldState := NewState;

  (* 5. Reset last, so it wins while the button is held. *)
  IF ResetPB THEN
    Position := 0;
    Direction := 0;
    EncError := FALSE;
  END_IF;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : QuadDecoder;
  END_RESOURCE
END_CONFIGURATION
