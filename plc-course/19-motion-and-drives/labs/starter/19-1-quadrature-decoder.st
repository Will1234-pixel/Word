(* Lab 19-1: Quadrature decoder (x4) with direction and illegal-transition error.
   Module 19 (Motion control, drives and positioning). STARTER - the declarations are done
   for you; write the logic where it says TODO, then run:
     python3 tools/plctest.py 19-motion-and-drives/labs/starter/19-1-quadrature-decoder.st

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
  VAR (* internal - add, rename or remove these as you like *)
    Initialised : BOOL;         (* FALSE until the first scan has captured the A/B state *)
    PrevA       : BOOL;         (* channel A one scan ago *)
    PrevB       : BOOL;         (* channel B one scan ago *)
  END_VAR

  (* TODO: replace these placeholder lines with your decoder.
     Suggested order: capture A/B on the first scan, compare with the previous scan,
     count +1 / -1 or flag an illegal transition, store A/B for the next scan, then reset.
     (MATIEC needs at least one statement in a program body.) *)
  Position := 0;
  Direction := 0;
  EncError := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : QuadDecoder;
  END_RESOURCE
END_CONFIGURATION
