(* Lab 03-3: Temperature in tenths - integer versus REAL arithmetic.
   Module 03 (Numbers, data types and addressing). REFERENCE SOLUTION - try the lab yourself first.

   A temperature transmitter sends its reading as an INT in tenths of a degree Celsius
   (235 means 23.5 degC), a very common convention on Modbus devices. The program makes
     TempC      REAL degC for the HMI
     TempF      REAL degF for the HMI
     TempF_x10  INT tenths of degF, rounded to the nearest tenth, for a legacy SCADA register
   and flags readings outside the sensor's measuring range. *)

PROGRAM TempTenths
  VAR (* I/O *)
    RawTenths   AT %IW0   : INT;   (* from the transmitter: tenths of degC *)
    TempF_x10   AT %QW0   : INT;   (* to legacy SCADA: tenths of degF (Modbus holding register 0 in OpenPLC) *)
    SensorFault AT %QX0.0 : BOOL;  (* reading outside -200.0 .. +850.0 degC *)
  END_VAR
  VAR (* HMI values *)
    TempC : REAL;                  (* degC *)
    TempF : REAL;                  (* degF *)
  END_VAR
  VAR CONSTANT
    RAW_MIN : INT := -2000;        (* -200.0 degC: bottom of the Pt100 range *)
    RAW_MAX : INT := 8500;         (* +850.0 degC: top of the Pt100 range *)
  END_VAR

  (* 1. Validate before converting. The transmitter sends values outside its range
        (32767 for a broken sensor, for example) to signal a fault. *)
  SensorFault := (RawTenths < RAW_MIN) OR (RawTenths > RAW_MAX);

  (* 2. Convert only good readings. On a fault the outputs keep their last good values;
        SensorFault tells everything that uses them not to trust them. *)
  IF NOT SensorFault THEN
    (* Convert to REAL FIRST, then divide by 10.0. INT_TO_REAL(RawTenths / 10) would do an
       integer division and throw the tenths away (235 / 10 = 23). *)
    TempC := INT_TO_REAL(RawTenths) / 10.0;
    TempF := TempC * 1.8 + 32.0;

    (* Tenths of degF = RawTenths * 9 / 5 + 320. Two traps if you do this in INT:
       - RawTenths * 9 does not fit in an INT above 3640 (364.0 degC): 8500 * 9 = 76500.
         Some platforms overflow on that intermediate result, others only when a result
         is stored; either way, don't let the calculation depend on it.
       - integer division truncates instead of rounding (237 would give 746, not 747).
       REAL has plenty of range and precision here, and REAL_TO_INT rounds to the nearest
       integer. The fractional part is always .0 .2 .4 .6 or .8, so exact halves (which
       platforms round differently) never occur. The largest result, 15620, fits in an INT. *)
    TempF_x10 := REAL_TO_INT(TempF * 10.0);
  END_IF;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : TempTenths;
  END_RESOURCE
END_CONFIGURATION
