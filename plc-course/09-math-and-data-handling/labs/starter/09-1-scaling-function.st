(* Lab 09-1: A general scaling function, F_Scale.
   Module 09 (Maths, comparison, data movement and bit manipulation).
   STARTER - the function's inputs and the program's interface are declared
   for you; write the logic where it says TODO, then run:
     python3 tools/plctest.py 09-math-and-data-handling/labs/starter/09-1-scaling-function.st

   Raw-count convention (as in Module 14): 0..27648 = 4..20 mA. *)

FUNCTION F_Scale : REAL
  VAR_INPUT
    In     : REAL;   (* the value to convert *)
    InMin  : REAL;   (* input value that corresponds to OutMin *)
    InMax  : REAL;   (* input value that corresponds to OutMax *)
    OutMin : REAL;   (* result when In = InMin *)
    OutMax : REAL;   (* result when In = InMax *)
    Clamp  : BOOL;   (* TRUE: keep the result inside the output range *)
  END_VAR
  (* TODO: add a VAR ... END_VAR block for any local variables you need. *)

  (* TODO: straight-line scaling with divide-by-zero protection and an
     optional clamp. OutMin may be larger than OutMax.
     Replace this placeholder line with your logic. *)
  F_Scale := 0.0;
END_FUNCTION

PROGRAM ScalingDemo
  VAR (* I/O *)
    LevelRaw AT %IW0 : INT;   (* LT-101 tank level, raw counts from the analog input card *)
    SpeedAO  AT %QW0 : INT;   (* SC-103 drive speed reference, raw counts: 0..27648 = 4..20 mA *)
    ValveAO  AT %QW1 : INT;   (* FV-102 valve demand, raw counts: 0 = 4 mA = fully OPEN *)
  END_VAR
  VAR (* settings: configuration of the card, the transmitter and the drive *)
    RawAt4mA   : REAL := 0.0;      (* raw count the card gives at 4 mA *)
    RawAt20mA  : REAL := 27648.0;  (* raw count the card gives at 20 mA *)
    DriveMinHz : REAL := 0.0;      (* drive speed at 4 mA (drive parameter) *)
    DriveMaxHz : REAL := 50.0;     (* drive speed at 20 mA (drive parameter) *)
  END_VAR
  VAR (* HMI values *)
    Level_m      : REAL;           (* LT-101 level in metres, NOT clamped *)
    LevelPct     : REAL;           (* LT-101 level in % of range, clamped 0..100 for the bar graph *)
    SpeedRef_Hz  : REAL;           (* speed setpoint entered on the HMI *)
    ValveCmd_Pct : REAL;           (* valve opening demand: 0 = closed, 100 = fully open *)
  END_VAR
  VAR CONSTANT
    LEVEL_MIN_M : REAL := 0.5;     (* LT-101 range: 0.5 m at 4 mA (the tapping is 0.5 m above the floor) ... *)
    LEVEL_MAX_M : REAL := 4.5;     (* ... 4.5 m at 20 mA *)
    AO_RAW_4MA  : REAL := 0.0;     (* analog output raw count for 4 mA *)
    AO_RAW_20MA : REAL := 27648.0; (* analog output raw count for 20 mA *)
  END_VAR

  (* TODO: calculate the four values with F_Scale (see the lab requirements
     in the Module 09 README). Replace these placeholder lines. *)
  Level_m := 0.0;
  LevelPct := 0.0;
  SpeedAO := 0;
  ValveAO := 0;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : ScalingDemo;
  END_RESOURCE
END_CONFIGURATION
