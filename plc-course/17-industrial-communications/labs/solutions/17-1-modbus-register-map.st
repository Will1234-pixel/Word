(* Lab 17-1: Modbus register map for glycol skid GC-3.
   Module 17 (Industrial communications). REFERENCE SOLUTION - try the lab yourself first.

   The PLC is a Modbus server for SCADA and a Modbus client of flow meter FT-301.
   This program is the "mapping layer" between the PLC's own variables and the
   16-bit registers that travel on the network:
     - a DINT split into two registers, in either word order,
     - two registers joined back into a DINT, in either word order,
     - a REAL sent as a scaled INT (x100), with rounding and clamping,
     - a scaled INT (x10) received from SCADA, range-checked before use,
     - a status WORD packed from BOOLs. *)

(* ---- Helper functions: small, pure and reusable ---------------------------- *)

FUNCTION F_HighWord : WORD
  VAR_INPUT
    Value : DINT;
  END_VAR
  (* Bits 16..31 of the DINT. DINT_TO_DWORD keeps the bit pattern, so this is
     correct for negative values too. Dividing by 65536 would NOT be: integer
     division truncates toward zero, so -100000 / 65536 = -1 (16#FFFF), but the
     correct high word of -100000 (16#FFFE_7960) is 16#FFFE. *)
  F_HighWord := DWORD_TO_WORD(SHR(DINT_TO_DWORD(Value), 16));
END_FUNCTION

FUNCTION F_LowWord : WORD
  VAR_INPUT
    Value : DINT;
  END_VAR
  (* Bits 0..15 of the DINT. *)
  F_LowWord := DWORD_TO_WORD(DINT_TO_DWORD(Value) AND 16#0000_FFFF);
END_FUNCTION

FUNCTION F_WordsToDint : DINT
  VAR_INPUT
    HighWord : WORD;
    LowWord  : WORD;
  END_VAR
  (* WORD_TO_DWORD fills the top bits with zeros, so a low word with bit 15 set
     (for example 16#86A0) cannot sign-extend into the high word. *)
  F_WordsToDint := DWORD_TO_DINT(SHL(WORD_TO_DWORD(HighWord), 16) OR WORD_TO_DWORD(LowWord));
END_FUNCTION

(* ---- The mapping program ------------------------------------------------- *)

PROGRAM ModbusMap
  VAR (* field inputs *)
    PumpRunning AT %IX0.0 : BOOL;   (* P-301 running (contactor auxiliary contact) *)
    PumpFault   AT %IX0.1 : BOOL;   (* P-301 motor protection tripped *)
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
  VAR
    Scaled : REAL;                  (* pressure x 100, before conversion to INT *)
    Sts    : WORD;                  (* status word under construction *)
  END_VAR

  (* 1. RunSeconds -> two registers, in the word order SCADA expects. *)
  IF RunSecLowFirst THEN
    HR_RunSecA := F_LowWord(RunSeconds);
    HR_RunSecB := F_HighWord(RunSeconds);
  ELSE
    HR_RunSecA := F_HighWord(RunSeconds);
    HR_RunSecB := F_LowWord(RunSeconds);
  END_IF;

  (* 2. Two meter registers -> DINT, in the word order the meter uses. *)
  IF MeterLowFirst THEN
    MeterTotal := F_WordsToDint(HighWord := MeterRegB, LowWord := MeterRegA);
  ELSE
    MeterTotal := F_WordsToDint(HighWord := MeterRegA, LowWord := MeterRegB);
  END_IF;

  (* 3. Pressure: REAL bar -> INT bar x 100. Check the range on the REAL value,
     BEFORE converting: REAL_TO_INT of a value outside -32768..32767 wraps
     round (400.0 bar would arrive as -25536). *)
  Scaled := PressureBar * 100.0;
  IF Scaled > 32767.0 THEN
    HR_Pressure := 32767;
    PressOutOfRange := TRUE;
  ELSIF Scaled < -32768.0 THEN
    HR_Pressure := -32768;
    PressOutOfRange := TRUE;
  ELSE
    HR_Pressure := REAL_TO_INT(Scaled);   (* rounds to the nearest integer *)
    PressOutOfRange := FALSE;
  END_IF;

  (* 4. Setpoint from SCADA: INT degC x 10 -> REAL degC. Validate the raw value
     first; a bad write leaves the setpoint in use unchanged. Convert to REAL
     before dividing, or 125 / 10 would give 12, not 12.5. *)
  IF HR_SupplySP >= -100 AND HR_SupplySP <= 150 THEN
    SupplySP := INT_TO_REAL(HR_SupplySP) / 10.0;
    SPRejected := FALSE;
  ELSE
    SPRejected := TRUE;
  END_IF;

  (* 5. Status word, rebuilt from zero every scan so no bit can go stale. *)
  Sts := 16#0000;
  IF PumpRunning     THEN Sts := Sts OR 16#0001; END_IF;
  IF PumpFault       THEN Sts := Sts OR 16#0002; END_IF;
  IF PressOutOfRange THEN Sts := Sts OR 16#0004; END_IF;
  IF SPRejected      THEN Sts := Sts OR 16#0008; END_IF;
  HR_Status := Sts;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : ModbusMap;
  END_RESOURCE
END_CONFIGURATION
