(* Lab 05-2: Two-out-of-three (2oo3) high-pressure trip vote.
   Module 05 (Boolean logic and FBD). REFERENCE SOLUTION - try the lab yourself first.

   TRAINING EXERCISE ONLY. This shows the Boolean logic of voting. It is not a
   design for a real safety function: real trips run in a safety-rated system
   engineered to IEC 61511 / IEC 61508 (Module 20), and they latch until reset. *)

PROGRAM TripVote
  VAR (* I/O - addresses follow the OpenPLC convention *)
    PSHH_A_NC   AT %IX0.0 : BOOL;  (* PSHH-101A, NC: TRUE = pressure below trip setting (healthy) *)
    PSHH_B_NC   AT %IX0.1 : BOOL;  (* PSHH-101B, NC: as above *)
    PSHH_C_NC   AT %IX0.2 : BOOL;  (* PSHH-101C, NC: as above *)
    Trip        AT %QX0.0 : BOOL;  (* TRUE = at least two channels demand a trip *)
    SDVSolenoid AT %QX0.1 : BOOL;  (* SDV-100 solenoid: TRUE = energised, valve held open *)
    Discrepancy AT %QX0.2 : BOOL;  (* TRUE = the three channels do not all agree *)
    DiscA       AT %QX0.3 : BOOL;  (* TRUE = channel A disagrees with B and C *)
    DiscB       AT %QX0.4 : BOOL;  (* TRUE = channel B disagrees with A and C *)
    DiscC       AT %QX0.5 : BOOL;  (* TRUE = channel C disagrees with A and B *)
  END_VAR
  VAR (* internal: channel trip demands, TRUE = this channel says "trip" *)
    DemA : BOOL;
    DemB : BOOL;
    DemC : BOOL;
  END_VAR

  (* 1. Convert each fail-safe input into "this channel demands a trip".
        High pressure opens the contact, and so does a broken wire: both
        read FALSE, and both count as a demand. *)
  DemA := NOT PSHH_A_NC;
  DemB := NOT PSHH_B_NC;
  DemC := NOT PSHH_C_NC;

  (* 2. Majority vote: any two of the three. *)
  Trip := (DemA AND DemB) OR (DemB AND DemC) OR (DemA AND DemC);

  (* 3. De-energise to trip: the solenoid is powered only while there is no trip. *)
  SDVSolenoid := NOT Trip;

  (* 4. Which channel is the odd one out? A channel disagrees with the others
        when it differs from BOTH of them (which also means the other two agree). *)
  DiscA := (DemA XOR DemB) AND (DemA XOR DemC);
  DiscB := (DemB XOR DemA) AND (DemB XOR DemC);
  DiscC := (DemC XOR DemA) AND (DemC XOR DemB);

  (* 5. With three two-state channels, "not all equal" always means exactly
        one channel is the odd one out, so this is the same as
        (DemA XOR DemB) OR (DemB XOR DemC). *)
  Discrepancy := DiscA OR DiscB OR DiscC;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : TripVote;
  END_RESOURCE
END_CONFIGURATION
