(* Lab 02-2: Solenoid valves - single-solenoid spring-return versus
   double-solenoid (bistable) valves on the same transfer line.
   Module 02 (Electrical fundamentals and field devices).
   REFERENCE SOLUTION - try the lab yourself first.
   Training exercise only: a real high-high level trip is a safety function
   and would be engineered separately (Module 20). *)

PROGRAM SolenoidValves
  VAR (* I/O - addresses follow the OpenPLC convention *)
    OpenPB         AT %IX0.0 : BOOL;  (* "Open line" push-button, NO: TRUE while pressed *)
    ClosePB_NC     AT %IX0.1 : BOOL;  (* "Close line" push-button, NC: TRUE while NOT pressed *)
    HighLevelOK_NC AT %IX0.2 : BOOL;  (* LSHH on the receiving tank, NC: TRUE while level is NOT high-high *)
    XV201_Sol      AT %QX0.0 : BOOL;  (* XV-201 solenoid: single-solenoid, spring return, fail closed *)
    XV202_OpenSol  AT %QX0.1 : BOOL;  (* XV-202 "open" coil: double-solenoid valve, stays put (fail last) *)
    XV202_CloseSol AT %QX0.2 : BOOL;  (* XV-202 "close" coil *)
  END_VAR
  VAR (* internal *)
    LineOpenCmd : BOOL;  (* TRUE = the line should be open *)
  END_VAR

  (* One command for the line, with a seal-in. Close and the high-high trip
     are NC inputs in series, so a pressed button, a high-high level or a
     broken wire all drop the command. When the trip clears, the command stays
     FALSE until an operator presses Open again: no automatic re-opening. *)
  LineOpenCmd := (OpenPB OR LineOpenCmd) AND ClosePB_NC AND HighLevelOK_NC;

  (* Single-solenoid, spring-return valve: energised = open. The output must
     stay on for as long as the valve is to be open; removing it (by the
     program, by the PLC stopping, or by a power cut) lets the spring close
     the valve. That is why this valve type is used for trips. *)
  XV201_Sol := LineOpenCmd;

  (* Double-solenoid valve: de-energising a coil does NOT move it. The PLC must
     actively drive the close coil to close it. Maintained signals are used:
     the coil for the commanded position stays energised, which re-asserts the
     position if someone has used the manual override, and the two coils are
     complementary, so they can never both be on. At power-up LineOpenCmd is
     FALSE, so the PLC drives the valve closed: after a power cut the program
     cannot know where the valve was left. *)
  XV202_OpenSol  := LineOpenCmd;
  XV202_CloseSol := NOT LineOpenCmd;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : SolenoidValves;
  END_RESOURCE
END_CONFIGURATION
