(* Lab 09-3: Flow totaliser.
   Module 09 (Maths, comparison, data movement and bit manipulation).
   REFERENCE SOLUTION - try the lab yourself first.

   A totaliser integrates a rate over time. Every scan:

       increment [m3] = flow [m3/h] x scan time [h]

   With a 10 ms task the increment is tiny (50 m3/h adds 0.000139 m3 per
   scan), and that is exactly what a REAL cannot add to a large number:
   a REAL keeps about 7 significant digits, so near 20000 m3 the gap between
   neighbouring REAL values is about 0.002 m3 and every increment is rounded
   away. This program keeps two totals side by side:
     Total_m3      in LREAL (about 16 digits): correct
     TotalReal_m3  in REAL, the naive way: shown only so you can watch it fail *)

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
  VAR (* internal *)
    Dt_h     : LREAL;                (* scan time in hours *)
    Flow     : REAL;                 (* the flow that is totalised: never negative *)
  END_VAR

  (* 1. Scan time in hours. TIME_TO_LREAL returns seconds in MATIEC but
        milliseconds in CODESYS; the ratio of two conversions is the same on
        every platform, so this line is portable. *)
  Dt_h := TIME_TO_LREAL(TaskCycle) / TIME_TO_LREAL(T#1h);

  (* 2. Only forward flow is totalised. A small negative reading around zero
        flow is noise, not flow going backwards. Writing the test as
        "FlowRate > 0.0" also means a NaN flow (every comparison with NaN is
        FALSE) counts as zero instead of turning the total into NaN for ever. *)
  IF FlowRate > 0.0 THEN
    Flow := FlowRate;
  ELSE
    Flow := 0.0;
  END_IF;

  (* 3. Reset wins over preset; while either is held, nothing is added. *)
  IF ResetPB THEN
    Total_m3 := 0.0;
    TotalReal_m3 := 0.0;
  ELSIF PresetPB THEN
    Total_m3 := DINT_TO_LREAL(PresetValue_m3);
    TotalReal_m3 := DINT_TO_REAL(PresetValue_m3);
  ELSE
    (* The accurate total: the whole calculation in LREAL. *)
    Total_m3 := Total_m3 + REAL_TO_LREAL(Flow) * Dt_h;
    (* The naive total: the same sum in REAL. It is fine while the total is
       small, then loses increments, then stops counting altogether. *)
    TotalReal_m3 := TotalReal_m3 + Flow * LREAL_TO_REAL(Dt_h);
  END_IF;

  (* 4. Whole cubic metres, cut off (not rounded) like a mechanical counter:
        7.9 m3 shows 7 until the eighth cubic metre is complete. *)
  TotalWhole_m3 := TRUNC(Total_m3);
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : FlowTotaliser;
  END_RESOURCE
END_CONFIGURATION
