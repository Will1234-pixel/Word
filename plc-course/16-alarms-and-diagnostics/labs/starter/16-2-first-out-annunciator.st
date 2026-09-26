(* Lab 16-2: First-out annunciator for the eight shutdown inputs of a gas
   compressor, with horn, acknowledge, reset, lamp test and a run permissive.
   Module 16 (Alarms, diagnostics and fault handling). STARTER - the I/O and
   the HMI status arrays are declared for you; write the logic where it says
   TODO, then run:
     python3 tools/plctest.py 16-alarms-and-diagnostics/labs/starter/16-2-first-out-annunciator.st

   TRAINING EXERCISE ONLY: on a real compressor the shutdown function itself
   belongs in a properly designed (often safety-rated) trip system. This lab
   is about annunciation: showing the operator what tripped, and what
   tripped FIRST.

   Tip: copy the eight inputs into a BOOL array first, then every rule
   becomes a FOR loop over the channels. Decide carefully in which ORDER
   the steps run inside one scan. *)

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
    (* Add your internal variables here (arrays, edge detectors, flasher ...). *)
    I : INT;
  END_VAR

  (* TODO: replace these placeholder lines with your logic (see the
     requirements in the Module 16 README, Lab 16-2). *)
  Lamp1 := FALSE;
  Lamp2 := FALSE;
  Lamp3 := FALSE;
  Lamp4 := FALSE;
  Lamp5 := FALSE;
  Lamp6 := FALSE;
  Lamp7 := FALSE;
  Lamp8 := FALSE;
  Horn := FALSE;
  RunPermit := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : FirstOutPanel;
  END_RESOURCE
END_CONFIGURATION
