(* Lab 18-1: HMI command handshake for transfer pump P-101.
   Module 18 (HMI and SCADA). STARTER - the declarations and the bit/code
   constants are done for you; write the logic where it says TODO, then run:
     python3 tools/plctest.py 18-hmi-and-scada/labs/starter/18-1-command-handshake.st

   The HMI writes a COMMAND WORD (one bit per command). The PLC must act on
   each command once, clear the word, report its state in a STATUS WORD and
   explain every refusal with a REJECT CODE. See the lab sheet in the
   module README for the full requirements.

   In the OpenPLC Runtime v3, %MW0..%MW1023 are Modbus holding registers
   1024..2047, so an HMI would find HmiCmd at holding register 1024. Newer
   OpenPLC releases let you size the register blocks, so check the Modbus
   address table that your version shows. *)

PROGRAM CmdHandshake
  VAR (* field I/O *)
    OverloadOK_NC AT %IX0.0 : BOOL;  (* Overload relay contact, NC: TRUE = healthy *)
    SuctionOK     AT %IX0.1 : BOOL;  (* Start permissive: feed-tank level above low (LSL-101) *)
    PumpRun       AT %QX0.0 : BOOL;  (* Pump contactor *)
  END_VAR
  VAR (* HMI interface - memory words the HMI reads and writes *)
    HmiCmd     AT %MW0 : WORD;       (* HMI -> PLC: command bits. HMI sets, PLC clears *)
    HmiSts     AT %MW1 : WORD;       (* PLC -> HMI: status bits *)
    RejectCode AT %MW2 : INT;        (* PLC -> HMI: result of the last command, 0 = accepted *)
    SpeedReq   AT %MW3 : INT;        (* HMI -> PLC: requested speed, % *)
    SpeedSP    AT %MW4 : INT := 50;  (* PLC -> HMI: active speed setpoint, % *)
  END_VAR
  VAR CONSTANT
    (* Command bits in HmiCmd *)
    CMD_START   : WORD := 16#0001;
    CMD_STOP    : WORD := 16#0002;
    CMD_RESET   : WORD := 16#0004;
    CMD_APPLY   : WORD := 16#0008;
    CMD_DEFINED : WORD := 16#000F;   (* every bit that means something *)
    (* Status bits in HmiSts *)
    STS_RUNNING  : WORD := 16#0001;
    STS_FAULTED  : WORD := 16#0002;
    STS_READY    : WORD := 16#0004;
    STS_PERMOK   : WORD := 16#0008;
    STS_REJECTED : WORD := 16#0010;
    (* Reject codes *)
    REJ_NONE       : INT := 0;
    REJ_UNKNOWN    : INT := 1;
    REJ_FAULTED    : INT := 2;
    REJ_NO_PERMIT  : INT := 3;
    REJ_FAULT_HERE : INT := 4;
    REJ_SP_RANGE   : INT := 5;
    (* Engineered speed limits, % *)
    SPEED_MIN : INT := 30;
    SPEED_MAX : INT := 100;
  END_VAR
  VAR (* suggested internal variables - add or remove as you like *)
    FirstScanDone : BOOL;            (* FALSE only on the first scan after power-up *)
    Cmd           : WORD;            (* this scan's snapshot of HmiCmd *)
    Faulted       : BOOL;            (* latched overload fault *)
    LastReject    : INT;             (* result of the last command word *)
    ActiveSpeed   : INT := 50;       (* the setpoint in use; SpeedSP is only its copy *)
  END_VAR

  (* TODO 1: copy HmiCmd into Cmd and clear HmiCmd straight away.
             On the first scan after power-up, discard the command.
     TODO 2: latch the overload fault.
     TODO 3: if Cmd <> 0, handle it: Stop wins; undefined bits are refused;
             then Reset, Start and Apply in that order. Set RejectCode.
             Test a bit with a mask:  IF (Cmd AND CMD_START) <> 16#0000 THEN
     TODO 4: interlocks, then drive PumpRun.
     TODO 5: publish HmiSts, RejectCode and SpeedSP every scan, from your
             internal variables (never keep state only in an HMI register).
     Replace the placeholder lines below with your logic. *)
  PumpRun := FALSE;
  HmiSts := 16#0000;
  RejectCode := REJ_NONE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : CmdHandshake;
  END_RESOURCE
END_CONFIGURATION
