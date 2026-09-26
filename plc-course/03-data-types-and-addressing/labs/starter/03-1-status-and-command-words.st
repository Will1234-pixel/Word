(* Lab 03-1: Status word and command word - packing BOOLs into a WORD and back.
   Module 03 (Numbers, data types and addressing). STARTER - the declarations are done for you;
   write the logic where it says TODO, then run:
     python3 tools/plctest.py 03-data-types-and-addressing/labs/starter/03-1-status-and-command-words.st

   A pump station PLC exchanges data with SCADA through two 16-bit registers:
     StatusWord (PLC -> SCADA): bit n = status flag n (bits 0..7), bit 15 = command word rejected
     CmdWord    (SCADA -> PLC): bits 0..7 = eight commands, bits 8..15 reserved (must be 0)
   MATIEC has no bit access such as CmdWord.3, so use shifts and masks (see the README). CODESYS
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

  (* TODO Part A: build StatusWord from the eight status flags (bit n = flag n)
     and set bit 15 while CmdRejected is TRUE. Bits 8..14 are always 0.
     TODO Part B: set CmdRejected when any of bits 8..15 of CmdWord is set, and
     unpack bits 0..7 of CmdWord into CmdStart..CmdSilence (all FALSE when rejected).
     Replace these placeholder lines with your logic. *)
  StatusWord := 16#0000;
  CmdStart := FALSE;
  CmdStop := FALSE;
  CmdReset := FALSE;
  CmdAuto := FALSE;
  CmdManual := FALSE;
  CmdInhibit := FALSE;
  CmdLampTest := FALSE;
  CmdSilence := FALSE;
  CmdRejected := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : PumpWords;
  END_RESOURCE
END_CONFIGURATION
