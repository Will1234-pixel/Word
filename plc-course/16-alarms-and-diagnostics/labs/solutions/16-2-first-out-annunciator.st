(* Lab 16-2: First-out annunciator for the eight shutdown inputs of a gas
   compressor, with horn, acknowledge, reset, lamp test and a run permissive.
   Module 16 (Alarms, diagnostics and fault handling). REFERENCE SOLUTION - try the lab yourself first.

   TRAINING EXERCISE ONLY: on a real compressor the shutdown function itself
   belongs in a properly designed (often safety-rated) trip system. This lab
   is about annunciation: showing the operator what tripped, and what
   tripped FIRST.

   Design: the eight inputs are copied into an array once per scan, and
   every rule is then a FOR loop over the channels. The order of the steps
   inside the scan is part of the design:
     1. acknowledge   (a press only acknowledges what was there before it)
     2. reset         (only acknowledged channels whose input is healthy)
     3. armed?        (worked out ONCE, before any new trip is latched)
     4. latch new trips, and mark them first-out if the panel was armed
     5. lamps, horn and run permissive *)

PROGRAM FirstOutPanel
  VAR (* trip inputs: NC contacts, TRUE = healthy, FALSE = tripped or wire broken *)
    Trip1_NC   AT %IX0.0 : BOOL;  (* PSLL-401 suction pressure low-low *)
    Trip2_NC   AT %IX0.1 : BOOL;  (* PSHH-402 discharge pressure high-high *)
    Trip3_NC   AT %IX0.2 : BOOL;  (* TSHH-403 discharge temperature high-high *)
    Trip4_NC   AT %IX0.3 : BOOL;  (* PSLL-404 lube oil pressure low-low *)
    Trip5_NC   AT %IX0.4 : BOOL;  (* VSHH-405 vibration high-high *)
    Trip6_NC   AT %IX0.5 : BOOL;  (* LSHH-406 suction scrubber level high-high *)
    Trip7_NC   AT %IX0.6 : BOOL;  (* HS-407 local shutdown push-button (monitoring contact) *)
    Trip8_NC   AT %IX0.7 : BOOL;  (* XA-408 main motor protection relay trip *)
    AckPB      AT %IX1.0 : BOOL;  (* Acknowledge (silence) push-button, NO *)
    ResetPB    AT %IX1.1 : BOOL;  (* Reset push-button, NO *)
    LampTestPB AT %IX1.2 : BOOL;  (* Lamp test push-button, NO *)
    Lamp1      AT %QX0.0 : BOOL;  (* annunciator window lamps, one per channel *)
    Lamp2      AT %QX0.1 : BOOL;
    Lamp3      AT %QX0.2 : BOOL;
    Lamp4      AT %QX0.3 : BOOL;
    Lamp5      AT %QX0.4 : BOOL;
    Lamp6      AT %QX0.5 : BOOL;
    Lamp7      AT %QX0.6 : BOOL;
    Lamp8      AT %QX0.7 : BOOL;
    Horn       AT %QX1.0 : BOOL;  (* audible alarm *)
    RunPermit  AT %QX1.1 : BOOL;  (* TRUE = compressor may be started (no channel latched) *)
  END_VAR
  VAR (* status for the HMI, one element per channel *)
    Latched  : ARRAY[1..8] OF BOOL;  (* channel has tripped and has not been reset *)
    Unacked  : ARRAY[1..8] OF BOOL;  (* channel trip not yet acknowledged *)
    FirstOut : ARRAY[1..8] OF BOOL;  (* channel was (one of) the first to trip *)
  END_VAR
  VAR
    Healthy    : ARRAY[1..8] OF BOOL;  (* copy of the eight NC inputs *)
    LampState  : ARRAY[1..8] OF BOOL;  (* lamp outputs before mapping to %QX *)
    AckEdge    : R_TRIG;
    ResetEdge  : R_TRIG;
    FlashTimer : TON;
    FlashOn    : BOOL;   (* toggles about every 0.5 s *)
    Armed      : BOOL;   (* no channel latched: the next trip is a first-out *)
    AnyLatched : BOOL;
    AnyUnacked : BOOL;
    I          : INT;
  END_VAR

  (* Input mapping: one place where the hardware meets the logic. *)
  Healthy[1] := Trip1_NC;
  Healthy[2] := Trip2_NC;
  Healthy[3] := Trip3_NC;
  Healthy[4] := Trip4_NC;
  Healthy[5] := Trip5_NC;
  Healthy[6] := Trip6_NC;
  Healthy[7] := Trip7_NC;
  Healthy[8] := Trip8_NC;

  AckEdge(CLK := AckPB);
  ResetEdge(CLK := ResetPB);

  (* 1. Acknowledge all channels on the PRESS of the button. A held button
        does not acknowledge trips that arrive later. *)
  IF AckEdge.Q THEN
    FOR I := 1 TO 8 DO
      Unacked[I] := FALSE;
    END_FOR;
  END_IF;

  (* 2. Reset clears only channels that are acknowledged AND healthy. A
        channel whose input is still tripped stays latched, with its
        first-out flag, so the evidence is not lost. *)
  IF ResetEdge.Q THEN
    FOR I := 1 TO 8 DO
      IF Healthy[I] AND NOT Unacked[I] THEN
        Latched[I] := FALSE;
        FirstOut[I] := FALSE;
      END_IF;
    END_FOR;
  END_IF;

  (* 3. Armed = nothing latched at this point of the scan. Decide it ONCE,
        before latching anything, so that every channel tripping in this
        scan is treated the same: within one scan the PLC cannot tell
        which came first, so they are all first-outs. *)
  Armed := TRUE;
  FOR I := 1 TO 8 DO
    IF Latched[I] THEN
      Armed := FALSE;
    END_IF;
  END_FOR;

  (* 4. Latch new trips. A channel that is already latched ignores its
        input until it has been reset. *)
  FOR I := 1 TO 8 DO
    IF (NOT Healthy[I]) AND (NOT Latched[I]) THEN
      Latched[I] := TRUE;
      Unacked[I] := TRUE;
      FirstOut[I] := Armed;
    END_IF;
  END_FOR;

  (* 5. Flasher: FlashOn toggles each time the timer runs out (about every
        0.5 s; the timer restarts on the scan after it finishes). *)
  FlashTimer(IN := NOT FlashTimer.Q, PT := T#500ms);
  IF FlashTimer.Q THEN
    FlashOn := NOT FlashOn;
  END_IF;

  (* 6. Lamps: flashing = needs attention (unacknowledged) or is the first
        cause; steady = acknowledged subsequent trip; off = not latched.
        The lamp test lights every lamp and changes nothing else. *)
  AnyLatched := FALSE;
  AnyUnacked := FALSE;
  FOR I := 1 TO 8 DO
    AnyLatched := AnyLatched OR Latched[I];
    AnyUnacked := AnyUnacked OR Unacked[I];
    IF LampTestPB THEN
      LampState[I] := TRUE;
    ELSIF Latched[I] AND (Unacked[I] OR FirstOut[I]) THEN
      LampState[I] := FlashOn;
    ELSE
      LampState[I] := Latched[I];
    END_IF;
  END_FOR;

  Horn := AnyUnacked;
  (* The permissive only ALLOWS a start. Reset never starts the compressor:
     that needs a separate, deliberate start command elsewhere. *)
  RunPermit := NOT AnyLatched;

  (* Output mapping *)
  Lamp1 := LampState[1];
  Lamp2 := LampState[2];
  Lamp3 := LampState[3];
  Lamp4 := LampState[4];
  Lamp5 := LampState[5];
  Lamp6 := LampState[6];
  Lamp7 := LampState[7];
  Lamp8 := LampState[8];
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : FirstOutPanel;
  END_RESOURCE
END_CONFIGURATION
