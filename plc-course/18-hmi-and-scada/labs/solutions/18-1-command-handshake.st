(* Lab 18-1: HMI command handshake for transfer pump P-101.
   Module 18 (HMI and SCADA). REFERENCE SOLUTION - try the lab yourself first.

   The HMI talks to the PLC over Modbus TCP. It never switches the pump
   directly: it writes a COMMAND WORD (one bit per command), and the PLC
   decides. The PLC acts on each command exactly once, clears the word
   ("PLC clears the command"), reports its state in a STATUS WORD, and
   explains every refusal with a REJECT CODE.

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
  VAR
    FirstScanDone : BOOL;            (* FALSE only on the first scan after power-up *)
    Cmd           : WORD;            (* this scan's snapshot of HmiCmd *)
    Result        : INT;             (* reject code for this command word *)
    LastReject    : INT;             (* result of the last command word, kept *)
    Faulted       : BOOL;            (* latched overload fault *)
    Running       : BOOL;            (* run latch *)
    Sts           : WORD;            (* status word being built *)
    ActiveSpeed   : INT := 50;       (* the setpoint in use. SpeedSP is only a copy for
                                        the HMI, so a stray write to it changes nothing *)
  END_VAR

  (* 1. Take a snapshot of the command word and clear it at once.
        Everything below works on the snapshot, so the command is acted on
        exactly once, and a comms drop can never leave a bit "stuck on". *)
  Cmd := HmiCmd;
  HmiCmd := 16#0000;

  (* A command that is already waiting on the first scan was written
     before the power cut (or is left in retentive memory). Executing it now
     could start the pump unexpectedly, so it is discarded. *)
  IF NOT FirstScanDone THEN
    Cmd := 16#0000;
    FirstScanDone := TRUE;
  END_IF;

  (* 2. Protection first: the overload latches a fault at any time. *)
  IF NOT OverloadOK_NC THEN
    Faulted := TRUE;
  END_IF;

  (* 3. Handle the command word (only when there is one). *)
  IF Cmd <> 16#0000 THEN
    Result := REJ_NONE;

    IF (Cmd AND CMD_STOP) <> 16#0000 THEN
      (* Stop wins over everything and is never refused. *)
      Running := FALSE;

    ELSIF (Cmd AND NOT CMD_DEFINED) <> 16#0000 THEN
      (* A bit we do not understand: do nothing rather than guess. *)
      Result := REJ_UNKNOWN;

    ELSE
      (* Reset first, so that Reset + Start in one word works. *)
      IF (Cmd AND CMD_RESET) <> 16#0000 THEN
        IF OverloadOK_NC THEN
          Faulted := FALSE;          (* reset never starts the pump *)
        ELSIF Result = REJ_NONE THEN
          Result := REJ_FAULT_HERE;
        END_IF;
      END_IF;

      IF (Cmd AND CMD_START) <> 16#0000 THEN
        IF Faulted THEN
          IF Result = REJ_NONE THEN Result := REJ_FAULTED; END_IF;
        ELSIF NOT SuctionOK THEN
          IF Result = REJ_NONE THEN Result := REJ_NO_PERMIT; END_IF;
        ELSE
          Running := TRUE;           (* already running: accepted, no change *)
        END_IF;
      END_IF;

      IF (Cmd AND CMD_APPLY) <> 16#0000 THEN
        (* Written as "inside the range" so that anything odd is refused. *)
        IF SpeedReq >= SPEED_MIN AND SpeedReq <= SPEED_MAX THEN
          ActiveSpeed := SpeedReq;
        ELSIF Result = REJ_NONE THEN
          Result := REJ_SP_RANGE;    (* the old setpoint stays in use *)
        END_IF;
      END_IF;
    END_IF;

    LastReject := Result;            (* kept until the next command word *)
  END_IF;

  (* 4. Interlocks: a trip or a lost permissive stops the pump. It does not
        restart when the condition clears - that needs a new Start. *)
  IF Faulted OR NOT SuctionOK THEN
    Running := FALSE;
  END_IF;
  PumpRun := Running;

  (* 5. Publish the status for the HMI. These registers are written every
        scan, so nothing written into them from outside can stick. *)
  SpeedSP := ActiveSpeed;
  RejectCode := LastReject;
  Sts := 16#0000;
  IF Running THEN Sts := Sts OR STS_RUNNING; END_IF;
  IF Faulted THEN Sts := Sts OR STS_FAULTED; END_IF;
  IF NOT Running AND NOT Faulted AND SuctionOK THEN Sts := Sts OR STS_READY; END_IF;
  IF SuctionOK THEN Sts := Sts OR STS_PERMOK; END_IF;
  IF LastReject <> REJ_NONE THEN Sts := Sts OR STS_REJECTED; END_IF;
  HmiSts := Sts;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : CmdHandshake;
  END_RESOURCE
END_CONFIGURATION
