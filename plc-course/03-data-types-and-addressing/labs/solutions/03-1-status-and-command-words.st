(* Lab 03-1: Status word and command word - packing BOOLs into a WORD and back.
   Module 03 (Numbers, data types and addressing). REFERENCE SOLUTION - try the lab yourself first.

   A pump station PLC exchanges data with SCADA through two 16-bit registers:
     StatusWord (PLC -> SCADA): bit n = status flag n (bits 0..7), bit 15 = command word rejected
     CmdWord    (SCADA -> PLC): bits 0..7 = eight commands, bits 8..15 reserved (must be 0)
   MATIEC has no bit access such as CmdWord.3, so this uses shifts and masks. CODESYS
   (CmdWord.3), TIA Portal (CmdWord.%X3) and Logix (MyDint.3) let you address bits directly. *)

PROGRAM PumpWords
  VAR (* I/O: eight status inputs = one byte of a digital input card (%IB0) *)
    Running       AT %IX0.0 : BOOL;  (* bit 0: pump running (contactor auxiliary contact) *)
    InAuto        AT %IX0.1 : BOOL;  (* bit 1: Hand-Off-Auto selector in AUTO *)
    Tripped       AT %IX0.2 : BOOL;  (* bit 2: motor protection relay tripped *)
    SuctionLow    AT %IX0.3 : BOOL;  (* bit 3: suction pressure low *)
    DischargeHigh AT %IX0.4 : BOOL;  (* bit 4: discharge pressure high *)
    SealLeak      AT %IX0.5 : BOOL;  (* bit 5: mechanical seal leak detected *)
    SumpHigh      AT %IX0.6 : BOOL;  (* bit 6: sump level high *)
    PanelDoorOpen AT %IX0.7 : BOOL;  (* bit 7: control panel door open *)
  END_VAR
  VAR (* SCADA interface: OpenPLC serves %MW0 and %MW1 as Modbus holding registers 1024 and 1025 *)
    StatusWord AT %MW0 : WORD;  (* PLC -> SCADA *)
    CmdWord    AT %MW1 : WORD;  (* SCADA -> PLC *)
  END_VAR
  VAR (* unpacked commands, used by the rest of the program *)
    CmdStart    : BOOL;  (* bit 0 *)
    CmdStop     : BOOL;  (* bit 1 *)
    CmdReset    : BOOL;  (* bit 2 *)
    CmdAuto     : BOOL;  (* bit 3 *)
    CmdManual   : BOOL;  (* bit 4 *)
    CmdInhibit  : BOOL;  (* bit 5 *)
    CmdLampTest : BOOL;  (* bit 6 *)
    CmdSilence  : BOOL;  (* bit 7: silence the horn *)
    CmdRejected : BOOL;  (* TRUE while a reserved bit (8..15) of CmdWord is set *)
  END_VAR

  (* ---- Part B first: check and unpack the command word ----
     Any reserved bit set means the register holds something that is not a command word,
     for example a level value written to the wrong register by a SCADA mapping error.
     Reject the whole word so that no bit of it is acted on. *)
  CmdRejected := (CmdWord AND 16#FF00) <> 0;

  IF CmdRejected THEN
    CmdStart    := FALSE;
    CmdStop     := FALSE;
    CmdReset    := FALSE;
    CmdAuto     := FALSE;
    CmdManual   := FALSE;
    CmdInhibit  := FALSE;
    CmdLampTest := FALSE;
    CmdSilence  := FALSE;
  ELSE
    (* AND with a mask keeps only the bit we want; "<> 0" turns the result into a BOOL. *)
    CmdStart    := (CmdWord AND 16#0001) <> 0;
    CmdStop     := (CmdWord AND 16#0002) <> 0;
    CmdReset    := (CmdWord AND 16#0004) <> 0;
    CmdAuto     := (CmdWord AND 16#0008) <> 0;
    CmdManual   := (CmdWord AND 16#0010) <> 0;
    CmdInhibit  := (CmdWord AND 16#0020) <> 0;
    CmdLampTest := (CmdWord AND 16#0040) <> 0;
    CmdSilence  := (CmdWord AND 16#0080) <> 0;
  END_IF;

  (* ---- Part A: pack the status flags ----
     BOOL_TO_WORD gives 16#0000 or 16#0001, and SHL moves that 1 up to bit n.
     The word is built from nothing every scan, so a bit clears as soon as its flag
     goes FALSE. Bits 8..14 stay 0; bit 15 reports a rejected command word. *)
  StatusWord := BOOL_TO_WORD(Running)
             OR SHL(BOOL_TO_WORD(InAuto), 1)
             OR SHL(BOOL_TO_WORD(Tripped), 2)
             OR SHL(BOOL_TO_WORD(SuctionLow), 3)
             OR SHL(BOOL_TO_WORD(DischargeHigh), 4)
             OR SHL(BOOL_TO_WORD(SealLeak), 5)
             OR SHL(BOOL_TO_WORD(SumpHigh), 6)
             OR SHL(BOOL_TO_WORD(PanelDoorOpen), 7)
             OR SHL(BOOL_TO_WORD(CmdRejected), 15);
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : PumpWords;
  END_RESOURCE
END_CONFIGURATION
