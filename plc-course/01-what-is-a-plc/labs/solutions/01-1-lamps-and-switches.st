(* Lab 01-1: Lamps and switches - Boolean logic and the lab workflow.
   Module 01 (What is a PLC?). REFERENCE SOLUTION - try the lab yourself first. *)

PROGRAM LampsAndSwitches
  VAR (* I/O - addresses follow the OpenPLC convention *)
    SwitchA    AT %IX0.0 : BOOL;  (* Toggle switch A: TRUE when switched on *)
    SwitchB    AT %IX0.1 : BOOL;  (* Toggle switch B: TRUE when switched on *)
    LampTestPB AT %IX0.2 : BOOL;  (* Lamp-test push-button, NO: TRUE while pressed *)
    LampFollow  AT %QX0.0 : BOOL; (* On when switch A is on *)
    LampInverse AT %QX0.1 : BOOL; (* On when switch A is off *)
    LampBoth    AT %QX0.2 : BOOL; (* On when switches A and B are both on *)
    LampEither  AT %QX0.3 : BOOL; (* On when switch A or B (or both) is on *)
  END_VAR

  (* Each lamp is one Boolean expression, written in exactly one place.
     The lamp-test button is ORed into every lamp, so pressing it lights all
     four lamps whatever the switches say. Nothing here refers to its own
     output, so nothing can latch: every scan, each lamp is worked out again
     from the inputs read at the start of that scan. *)
  LampFollow  := SwitchA OR LampTestPB;               (* follow:  A        *)
  LampInverse := (NOT SwitchA) OR LampTestPB;         (* inverse: NOT A    *)
  LampBoth    := (SwitchA AND SwitchB) OR LampTestPB; (* both:    A AND B  *)
  LampEither  := SwitchA OR SwitchB OR LampTestPB;    (* either:  A OR B   *)
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : LampsAndSwitches;
  END_RESOURCE
END_CONFIGURATION
