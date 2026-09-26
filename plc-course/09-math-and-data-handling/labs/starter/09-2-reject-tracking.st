(* Lab 09-2: Conveyor reject tracking with a bit shift register.
   Module 09 (Maths, comparison, data movement and bit manipulation).
   STARTER - the interface is declared for you; write the logic where it
   says TODO, then run:
     python3 tools/plctest.py 09-math-and-data-handling/labs/starter/09-2-reject-tracking.st

   Each bit of TrackWord stands for one position on the belt:

      bit:      15  ...  6   5   4   3   2   1   0
      position: 15  ...  6   5   4   3   2   1   0 (camera)
                              ^ reject gate (RejectPos = 5)

   MATIEC has no bit access such as TrackWord.5: use masks and shifts,
   for example (TrackWord AND SHL(WORD#16#0001, n)) <> 0 to test bit n. *)

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
  VAR (* suggested internal variables: add, rename or remove as you like *)
    PulseEdge : R_TRIG;             (* the belt has moved one pitch *)
  END_VAR

  (* TODO: mark, shift, test the gate bit, count and reset (see the lab
     requirements in the Module 09 README). Replace these placeholder lines. *)
  PulseEdge(CLK := EncoderPulse);
  TrackWord := WORD#16#0000;
  RejectGate := FALSE;
  RejectCount := 0;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : RejectTracking;
  END_RESOURCE
END_CONFIGURATION
