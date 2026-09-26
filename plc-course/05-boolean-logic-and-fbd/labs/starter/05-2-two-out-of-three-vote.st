(* Lab 05-2: Two-out-of-three (2oo3) high-pressure trip vote.
   Module 05 (Boolean logic and FBD). STARTER - the declarations are done for you;
   write the logic where it says TODO, then run:
     python3 tools/plctest.py 05-boolean-logic-and-fbd/labs/starter/05-2-two-out-of-three-vote.st

   TRAINING EXERCISE ONLY - not a design for a real safety function. *)

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
  (* You may add your own internal variables in a separate VAR block here. *)

  (* TODO: replace these placeholder lines with your logic.
     (MATIEC needs at least one statement in a program body.) *)
  Trip := FALSE;
  SDVSolenoid := FALSE;
  Discrepancy := FALSE;
  DiscA := FALSE;
  DiscB := FALSE;
  DiscC := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : TripVote;
  END_RESOURCE
END_CONFIGURATION
