(* Lab 14-3: Sump pump level control - a pump-down on/off controller with
   hysteresis, a high-level alarm, an independent low-low float for dry-run
   protection, pump fault handling, and a level-transmitter fault.
   Module 14 (Analog signals and process I/O). STARTER - the declarations are
   done for you; write the logic where it says TODO, then run:
     python3 tools/plctest.py 14-analog-and-process-io/labs/starter/14-3-sump-pump.st

   TRAINING EXERCISE ONLY. The low-low float trip here is ordinary control
   logic in a standard PLC, not a designed safety function (Module 20).

   Raw-count convention: 0..27648 = 4..20 mA, 1728 counts per mA.
   LT-301 range 0.0..4.0 m, so 1 m = 6912 counts.

   Reuse your work: paste your FB_AnalogInput from Lab 14-1 (and, if you
   like, FB_AnalogAlarm from Lab 14-2) ABOVE the PROGRAM, then declare an
   instance of it below. MATIEC compiles one file, so the blocks must be
   in this file. *)

PROGRAM SumpPump
  VAR (* I/O *)
    LT301_Raw     AT %IW0   : INT;   (* LT-301 sump level: 0..27648 = 4..20 mA = 0.0..4.0 m *)
    LSLL302_NC    AT %IX0.0 : BOOL;  (* low-low float, NC: TRUE while water is above it *)
    PumpRunFb     AT %IX0.1 : BOOL;  (* pump contactor auxiliary contact: TRUE = pulled in *)
    PumpOL_NC     AT %IX0.2 : BOOL;  (* motor overload relay, NC: TRUE = healthy *)
    ResetPB       AT %IX0.3 : BOOL;  (* fault reset push-button, NO *)
    PumpRun       AT %QX0.0 : BOOL;  (* pump contactor coil *)
    HighLevelAlm  AT %QX0.1 : BOOL;  (* high sump level alarm *)
    LowLowAlm     AT %QX0.2 : BOOL;  (* low-low float operated (latched) *)
    PumpFaultAlm  AT %QX0.3 : BOOL;  (* pump fault: overload or no run feedback (latched) *)
    LevelFaultAlm AT %QX0.4 : BOOL;  (* LT-301 signal outside the NE43 limits *)
  END_VAR
  VAR
    Level : REAL;                    (* sump level in m, for the HMI *)
  END_VAR
  VAR CONSTANT
    START_LEVEL    : REAL := 2.0;    (* pump starts at or above this level, m *)
    STOP_LEVEL     : REAL := 1.0;    (* pump stops at or below this level, m *)
    HIGH_ALM_LEVEL : REAL := 3.0;    (* high level alarm limit, m *)
    HIGH_ALM_DB    : REAL := 0.1;    (* high level alarm deadband, m *)
  END_VAR
  VAR
    (* Suggested internal variables - add, rename or remove as you like.
       For example: LT301 : FB_AnalogInput; (after pasting the block) *)
    HighAlmTimer : TON;              (* 5 s on-delay for the high level alarm *)
    FbTimer      : TON;              (* 2 s run-feedback supervision *)
    ResetEdge    : R_TRIG;           (* reset acts on the press *)
    Demand       : BOOL;             (* the level controller wants the pump on *)
  END_VAR

  (* TODO: replace these placeholder lines with your logic (see the
     requirements in the Module 14 README, Lab 14-3). *)
  Level := 0.0;
  PumpRun := FALSE;
  HighLevelAlm := FALSE;
  LowLowAlm := FALSE;
  PumpFaultAlm := FALSE;
  LevelFaultAlm := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : SumpPump;
  END_RESOURCE
END_CONFIGURATION
