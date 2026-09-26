(* Lab 03-3: Temperature in tenths - integer versus REAL arithmetic.
   Module 03 (Numbers, data types and addressing). STARTER - the declarations are done for you;
   write the logic where it says TODO, then run:
     python3 tools/plctest.py 03-data-types-and-addressing/labs/starter/03-3-temperature-tenths.st

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

  (* TODO: set SensorFault when RawTenths is outside RAW_MIN..RAW_MAX.
     TODO: for good readings, calculate TempC, TempF and TempF_x10 (tenths of degF,
     rounded to the nearest tenth, correct over the whole range). On a fault, keep the
     last good values. Watch out for integer division and INT overflow.
     Replace these placeholder lines with your logic. *)
  SensorFault := FALSE;
  TempC := 0.0;
  TempF := 0.0;
  TempF_x10 := 0;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : TempTenths;
  END_RESOURCE
END_CONFIGURATION
