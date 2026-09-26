(* Lab 09-2: Conveyor reject tracking with a bit shift register.
   Module 09 (Maths, comparison, data movement and bit manipulation).
   REFERENCE SOLUTION - try the lab yourself first.

   Parts travel on a conveyor one pitch apart. A camera at position 0 checks
   each part; the reject pusher is RejectPos pitches further down the belt.
   Each bit of TrackWord stands for one position on the belt:

      bit:      15  ...  6   5   4   3   2   1   0
      position: 15  ...  6   5   4   3   2   1   0 (camera)
                              ^ reject gate (RejectPos = 5)

   A bad result sets bit 0. Every pitch of belt movement (one rising edge of
   EncoderPulse) shifts the word one place left, so the "bad" bit travels
   down the belt with its part. The gate fires while the bit at RejectPos
   is set. *)

PROGRAM RejectTracking
  VAR (* I/O *)
    EncoderPulse AT %IX0.0 : BOOL;  (* one pulse per pitch, from a prox on the drive sprocket *)
    InspectFail  AT %IX0.1 : BOOL;  (* camera at position 0: TRUE = the part in front of it failed *)
    ResetPB      AT %IX0.2 : BOOL;  (* clear the tracking after the belt has been emptied by hand *)
    RejectGate   AT %QX0.0 : BOOL;  (* reject pusher at position RejectPos *)
  END_VAR
  VAR (* settings and HMI values *)
    RejectPos   : INT := 5;         (* pitches from the camera to the reject gate, 1..15 *)
    TrackWord   : WORD;             (* bit n TRUE = the part n pitches past the camera is bad *)
    RejectCount : DINT;             (* bad parts that have reached the reject gate *)
  END_VAR
  VAR (* internal *)
    PulseEdge : R_TRIG;             (* the belt has moved one pitch *)
    GatePos   : INT;                (* RejectPos limited to the bits that exist *)
    GateMask  : WORD;               (* a single 1 in bit GatePos *)
  END_VAR

  (* 1. Which bit is the gate? LIMIT keeps a bad setting inside the word.
        Without it, a shift count of 16 or more is not safe: in MATIEC on a PC,
        16..31 gives a mask of 0 (the gate never fires) and 40 gives the same
        as 8 (the gate fires at the wrong part). Other platforms differ. *)
  GatePos := LIMIT(1, RejectPos, 15);
  GateMask := SHL(WORD#16#0001, GatePos);

  (* 2. Mark: a fail from the camera sets bit 0, the part at the camera.
        OR sets that one bit and leaves the other fifteen alone. This works
        on the level of the signal, so a fail that is still on when the belt
        moves marks the next part too: when in doubt, reject. *)
  IF InspectFail THEN
    TrackWord := TrackWord OR WORD#16#0001;
  END_IF;

  (* 3. Shift once per pitch, on the rising edge only: a pulse that stays on
        while the belt is stopped must not shift the word every scan.
        SHL (not ROL) lets the bit from position 15 fall off the end, and
        brings a 0 (not yet inspected, so not bad) into bit 0.
        Marking comes first, so a camera result that arrives in the same scan
        as the pulse stays with the part it was taken of. *)
  PulseEdge(CLK := EncoderPulse);
  IF PulseEdge.Q THEN
    TrackWord := SHL(TrackWord, 1);
    (* Count here, once per shift, and not on the gate's rising edge: two
       bad parts in a row keep the gate on, but they are two rejects. *)
    IF (TrackWord AND GateMask) <> WORD#16#0000 THEN
      RejectCount := RejectCount + 1;
    END_IF;
  END_IF;

  (* 4. Reset clears the tracking only. The count is production data. *)
  IF ResetPB THEN
    TrackWord := WORD#16#0000;
  END_IF;

  (* 5. The gate follows the bit at its position. *)
  RejectGate := (TrackWord AND GateMask) <> WORD#16#0000;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : RejectTracking;
  END_RESOURCE
END_CONFIGURATION
