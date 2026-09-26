(* Lab 17-3: Drive control word and status word (simplified generic drive profile).
   Module 17 (Industrial communications). REFERENCE SOLUTION - try the lab yourself first.

   Conveyor drive M-401 is a VFD on a fieldbus. Every bus cycle the PLC sends a control
   word and a speed reference, and receives a status word. The bit layout is the course's
   SIMPLIFIED GENERIC PROFILE (see the lesson), not PROFIdrive, CiA 402 or the ODVA
   profile. Real drives need their own manual.

   Control word (PLC -> drive)          Status word (drive -> PLC)
     bit 0  RUN    1 = run, 0 = stop       bit 0  READY     healthy, will run on RUN
     bit 1  REV    1 = reverse             bit 1  RUNNING   output active
     bit 2  RESET  acts on 0 -> 1          bit 2  FAULT     tripped
     bits 3-15     always 0                bit 3  AT_SPEED  actual = reference
                                           bits 4-15        vendor-specific, ignored
   Speed reference: 0..16384 = 0..100 % of maximum speed.

   The drive in this profile restarts by itself after a fault reset if RUN is still 1.
   The PLC logic below makes sure that cannot happen. *)

PROGRAM DriveProfile
  VAR (* field input *)
    ResetPB AT %IX0.0 : BOOL;       (* fault reset push-button, NO *)
  END_VAR
  VAR (* fieldbus input data from the drive *)
    DriveSts AT %IW100 : WORD;      (* status word *)
  END_VAR
  VAR (* fieldbus output data to the drive *)
    DriveCtrl     AT %QW100 : WORD; (* control word *)
    DriveSpeedRef AT %QW101 : INT;  (* speed reference, 16384 = 100 % *)
  END_VAR
  VAR (* requests from the conveyor sequence *)
    RunReq  : BOOL;                 (* TRUE = the drive should run *)
    RevReq  : BOOL;                 (* TRUE = reverse direction wanted *)
    SpeedSP : REAL;                 (* speed setpoint, % of maximum *)
  END_VAR
  VAR (* decoded status for the sequence and the HMI *)
    Ready     : BOOL;
    Running   : BOOL;
    Faulted   : BOOL;
    AtSpeed   : BOOL;
    StartFail : BOOL;               (* latched: RUN sent but no RUNNING within 3 s *)
  END_VAR
  VAR
    RunBit      : BOOL;             (* bit 0 of the control word *)
    RevBit      : BOOL;             (* bit 1 of the control word *)
    RunSpent    : BOOL;             (* this RunReq saw a fault: wait for a new one *)
    ResetEdge   : R_TRIG;
    ResetPulse  : TP;               (* fixed-length reset pulse *)
    FeedbackTmr : TON;              (* RUN without RUNNING *)
    Ctrl        : WORD;             (* control word under construction *)
  END_VAR

  (* 1. Decode the status word. Mask each bit; ignore the vendor-specific bits. *)
  Ready   := (DriveSts AND 16#0001) <> 16#0000;
  Running := (DriveSts AND 16#0002) <> 16#0000;
  Faulted := (DriveSts AND 16#0004) <> 16#0000;
  AtSpeed := (DriveSts AND 16#0008) <> 16#0000;

  (* 2. Fault reset. The drive acts on the 0 -> 1 transition of RESET, and the bus
        may be slower than the PLC scan, so a one-scan pulse could be missed. A TP
        gives a fixed 500 ms pulse however long (or stuck) the button is. *)
  ResetEdge(CLK := ResetPB);
  ResetPulse(IN := ResetPB, PT := T#500ms);
  IF ResetEdge.Q THEN
    StartFail := FALSE;             (* the operator acknowledges our own fault too *)
  END_IF;

  (* 3. Feedback supervision: RUN has been sent for 3 s but the drive does not
        report RUNNING (not ready, wiring or parameter problem, lost run feedback). *)
  FeedbackTmr(IN := RunBit AND NOT Running, PT := T#3s);
  IF FeedbackTmr.Q THEN
    StartFail := TRUE;
  END_IF;

  (* 4. A run request that was active while the drive was faulted (or StartFail was
        latched) is "spent". It must be released and given again, so a fault reset
        can never restart the conveyor by itself. *)
  IF Faulted OR StartFail THEN
    RunSpent := TRUE;
  END_IF;
  IF NOT RunReq THEN
    RunSpent := FALSE;
  END_IF;
  RunBit := RunReq AND NOT RunSpent AND NOT Faulted AND NOT StartFail;

  (* 5. Direction may only change while the drive is not running. *)
  IF NOT Running THEN
    RevBit := RevReq;
  END_IF;

  (* 6. Build the control word from zero every scan: bits 3..15 stay 0. *)
  Ctrl := 16#0000;
  IF RunBit THEN Ctrl := Ctrl OR 16#0001; END_IF;
  IF RevBit THEN Ctrl := Ctrl OR 16#0002; END_IF;
  IF ResetPulse.Q THEN Ctrl := Ctrl OR 16#0004; END_IF;
  DriveCtrl := Ctrl;

  (* 7. Speed reference: clamp to 0..100 %, then 100 % = 16384, rounded. *)
  DriveSpeedRef := REAL_TO_INT(LIMIT(0.0, SpeedSP, 100.0) * 163.84);
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : DriveProfile;
  END_RESOURCE
END_CONFIGURATION
