(* Lab 09-3: Flow totaliser.
   Module 09 (Maths, comparison, data movement and bit manipulation).
   STARTER - the interface is declared for you; add your own internal
   variables and write the logic where it says TODO, then run:
     python3 tools/plctest.py 09-math-and-data-handling/labs/starter/09-3-flow-totaliser.st

   Every scan:  increment [m3] = flow [m3/h] x scan time [h]

   MATIEC notes: TIME_TO_REAL and TIME_TO_LREAL return SECONDS here (CODESYS
   returns milliseconds), so a ratio such as
   TIME_TO_LREAL(TaskCycle) / TIME_TO_LREAL(T#1h) is the portable way to get
   hours. Conversions between REAL and LREAL are explicit: REAL_TO_LREAL,
   LREAL_TO_REAL, DINT_TO_LREAL, DINT_TO_REAL. TRUNC(x) cuts off the fraction. *)

PROGRAM FlowTotaliser
  VAR (* I/O *)
    ResetPB  AT %IX0.0 : BOOL;       (* reset the totaliser to zero (NO key switch) *)
    PresetPB AT %IX0.1 : BOOL;       (* load PresetValue_m3 into the totaliser (NO) *)
  END_VAR
  VAR (* process value and settings *)
    FlowRate       : REAL;           (* FT-201 flow in m3/h, already scaled (Module 14) *)
    PresetValue_m3 : DINT;           (* whole m3 to load, e.g. the reading of the meter being replaced *)
    TaskCycle      : TIME := T#10ms; (* the task interval: must match the TASK INTERVAL below *)
  END_VAR
  VAR RETAIN (* on a real PLC the totals must survive a power cut *)
    Total_m3     : LREAL;            (* the accurate total, m3 *)
    TotalReal_m3 : REAL;             (* the naive REAL total, m3: for comparison only *)
  END_VAR
  VAR (* outputs for SCADA and the HMI *)
    TotalWhole_m3 : DINT;            (* whole cubic metres of Total_m3, like a meter's counter *)
  END_VAR
  (* TODO: add a VAR ... END_VAR block here for your helper variables
     (MATIEC does not accept an empty VAR block, so none is given). *)

  (* TODO: integrate FlowRate into Total_m3 (accurately) and into
     TotalReal_m3 (the naive REAL way), with reset and preset; then
     TotalWhole_m3. Replace these placeholder lines with your logic. *)
  Total_m3 := 0.0;
  TotalReal_m3 := 0.0;
  TotalWhole_m3 := 0;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : FlowTotaliser;
  END_RESOURCE
END_CONFIGURATION
