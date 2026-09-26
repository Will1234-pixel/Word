(* Lab 09-1: A general scaling function, F_Scale.
   Module 09 (Maths, comparison, data movement and bit manipulation).
   REFERENCE SOLUTION - try the lab yourself first.

   One function does every straight-line conversion in the program:
     raw counts -> metres     (level, not clamped, so over-range stays visible)
     raw counts -> percent    (bar graph, clamped)
     hertz      -> raw counts (drive speed reference, clamped)
     percent    -> raw counts (reverse-acting valve: 0 % open = 20 mA)

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
  VAR
    InSpan : REAL;
    Result : REAL;
  END_VAR

  InSpan := InMax - InMin;

  (* Divide-by-zero protection. A span of exactly 0.0 is the one case that
     makes the division below return infinity or NaN, so this is one of the
     few places where "=" on a REAL is the right test. A bad configuration
     gives the bottom of the output range: a defined, visible value. *)
  IF InSpan = 0.0 THEN
    Result := OutMin;
  ELSE
    (* y = (x - x0) * (y1 - y0) / (x1 - x0) + y0, all in REAL *)
    Result := (In - InMin) * (OutMax - OutMin) / InSpan + OutMin;
  END_IF;

  (* Clamp to the output range. OutMin may be larger than OutMax (a
     reverse-acting output), so find the lower and upper bounds first:
     LIMIT(MN, IN, MX) needs MN <= MX. *)
  IF Clamp THEN
    Result := LIMIT(MIN(OutMin, OutMax), Result, MAX(OutMin, OutMax));
  END_IF;

  F_Scale := Result;
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

  (* Level for the operator and for alarms: not clamped, so a reading of
     4.7 m or 0.3 m shows that the transmitter or loop needs attention
     (Module 14: check the signal before you clamp it). *)
  Level_m := F_Scale(In := INT_TO_REAL(LevelRaw),
                     InMin := RawAt4mA, InMax := RawAt20mA,
                     OutMin := LEVEL_MIN_M, OutMax := LEVEL_MAX_M,
                     Clamp := FALSE);

  (* Bar graph: clamped so it never shows -3 % or 106 %. *)
  LevelPct := F_Scale(In := INT_TO_REAL(LevelRaw),
                      InMin := RawAt4mA, InMax := RawAt20mA,
                      OutMin := 0.0, OutMax := 100.0,
                      Clamp := TRUE);

  (* Drive speed reference: clamped, so a mistyped 500 Hz can never send more
     than 20 mA. The clamp is applied to the REAL before REAL_TO_INT, which
     also keeps the conversion inside the INT range. *)
  SpeedAO := REAL_TO_INT(F_Scale(In := SpeedRef_Hz,
                                 InMin := DriveMinHz, InMax := DriveMaxHz,
                                 OutMin := AO_RAW_4MA, OutMax := AO_RAW_20MA,
                                 Clamp := TRUE));

  (* Reverse-acting valve: 0 % open needs 20 mA and 100 % open needs 4 mA,
     so the output range is simply given "upside down". *)
  ValveAO := REAL_TO_INT(F_Scale(In := ValveCmd_Pct,
                                 InMin := 0.0, InMax := 100.0,
                                 OutMin := AO_RAW_20MA, OutMax := AO_RAW_4MA,
                                 Clamp := TRUE));
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : ScalingDemo;
  END_RESOURCE
END_CONFIGURATION
