(* Lab 07-4: Accumulating run-hours meter.
   Module 07 (Timers). STARTER - the interface is declared for you;
   add your own internal variables and write the logic where it says TODO,
   then run:
     python3 tools/plctest.py 07-timers/labs/starter/07-4-run-hours.st

   MATIEC note: infix + and - on TIME values do not build in this toolchain.
   Use ADD_TIME(a, b) and SUB_TIME(a, b) instead; comparisons such as
   MyTime >= T#1s work normally. *)

PROGRAM RunHours
  VAR (* I/O *)
    Running    AT %IX0.0 : BOOL;  (* motor running feedback *)
    ResetPB    AT %IX0.1 : BOOL;  (* reset the meter, e.g. after an overhaul (NO) *)
    ServiceDue AT %QX0.0 : BOOL;  (* service-due lamp *)
  END_VAR
  VAR RETAIN (* on a real PLC the total must survive a power cut *)
    TotalSeconds : DINT;          (* total running time, whole seconds *)
  END_VAR
  VAR (* display values *)
    Hours   : DINT;               (* whole hours *)
    Minutes : DINT;               (* minutes past the whole hour, 0..59 *)
  END_VAR
  VAR (* settings *)
    ServiceHours : DINT := 1000;  (* service interval in running hours *)
  END_VAR
  (* TODO: add a VAR ... END_VAR block here for your timers and helper
     variables (MATIEC does not accept an empty VAR block, so none is given). *)

  (* TODO: replace these placeholder lines with your logic. *)
  TotalSeconds := 0;
  Hours := 0;
  Minutes := 0;
  ServiceDue := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : RunHours;
  END_RESOURCE
END_CONFIGURATION
