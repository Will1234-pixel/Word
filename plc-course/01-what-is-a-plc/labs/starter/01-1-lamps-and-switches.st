(* Lab 01-1: Lamps and switches - Boolean logic and the lab workflow.
   Module 01 (What is a PLC?). STARTER - the declarations are done for you;
   write the logic where it says TODO, then run:
     python3 tools/plctest.py 01-what-is-a-plc/labs/starter/01-1-lamps-and-switches.st *)

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

  (* TODO: replace these placeholder lines with one expression per lamp.
     Remember the lamp-test button (requirement 5).
     (MATIEC needs at least one statement in a program body.) *)
  LampFollow  := FALSE;
  LampInverse := FALSE;
  LampBoth    := FALSE;
  LampEither  := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : LampsAndSwitches;
  END_RESOURCE
END_CONFIGURATION
