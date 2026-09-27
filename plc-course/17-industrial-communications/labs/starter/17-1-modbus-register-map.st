(* Lab 17-1: Modbus register map for glycol skid GC-3.
   Module 17 (Industrial communications). STARTER - the declarations are done for you;
   write the logic where it says TODO, then run:
     python3 tools/plctest.py 17-industrial-communications/labs/starter/17-1-modbus-register-map.st

   You may add your own FUNCTIONs above the PROGRAM (for example one that joins two
   WORDs into a DINT). Keep every name in the interface table exactly as it is. *)

PROGRAM ModbusMap
  VAR (* field inputs *)
    PumpRunning   AT %IX0.0 : BOOL; (* P-301 running (contactor auxiliary contact) *)
    OverloadOK_NC AT %IX0.1 : BOOL; (* P-301 motor protection, NC: TRUE while healthy,
                                       FALSE when tripped or when its wire is broken *)
  END_VAR
  VAR (* holding registers served to SCADA. OpenPLC Runtime v3: %MW0 = holding register 1024 *)
    HR_Status   AT %MW0 : WORD;     (* PLC -> SCADA: status bits *)
    HR_Pressure AT %MW1 : INT;      (* PLC -> SCADA: PT-301 discharge pressure, bar x 100 *)
    HR_RunSecA  AT %MW2 : WORD;     (* PLC -> SCADA: RunSeconds, first register *)
    HR_RunSecB  AT %MW3 : WORD;     (* PLC -> SCADA: RunSeconds, second register *)
    HR_SupplySP AT %MW4 : INT := 50; (* SCADA -> PLC: glycol supply setpoint, degC x 10 *)
  END_VAR
  VAR (* registers read from flow meter FT-301 by the Modbus client *)
    MeterRegA AT %IW100 : WORD;     (* first register of the meter's totaliser *)
    MeterRegB AT %IW101 : WORD;     (* second register of the meter's totaliser *)
  END_VAR
  VAR (* the PLC side of the map *)
    PressureBar     : REAL;         (* PT-301 pressure in bar, from the analog input scaling *)
    RunSeconds      : DINT;         (* P-301 running time in seconds *)
    RunSecLowFirst  : BOOL;         (* FALSE: HR_RunSecA = high word. TRUE: HR_RunSecA = low word *)
    MeterLowFirst   : BOOL;         (* same meaning for MeterRegA / MeterRegB *)
    MeterTotal      : DINT;         (* FT-301 totaliser in litres *)
    SupplySP        : REAL := 5.0;  (* glycol supply setpoint in use, degC *)
    PressOutOfRange : BOOL;         (* pressure did not fit in HR_Pressure and was clamped *)
    SPRejected      : BOOL;         (* HR_SupplySP holds a value outside -10.0 .. +15.0 degC *)
  END_VAR

  (* TODO 1: split RunSeconds into HR_RunSecA / HR_RunSecB (word order: RunSecLowFirst).
     TODO 2: join MeterRegA / MeterRegB into MeterTotal (word order: MeterLowFirst).
     TODO 3: PressureBar -> HR_Pressure (x 100, rounded), clamp and set PressOutOfRange.
     TODO 4: HR_SupplySP -> SupplySP (/ 10) if -100..150, otherwise keep it and set SPRejected.
     TODO 5: build HR_Status: PumpRunning, pump fault (= NOT OverloadOK_NC), PressOutOfRange,
             SPRejected.
     Replace these placeholder lines with your logic. *)
  HR_Status := 16#0000;
  HR_Pressure := 0;
  MeterTotal := 0;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : ModbusMap;
  END_RESOURCE
END_CONFIGURATION
