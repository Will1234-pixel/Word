(* Lab 17-3: Drive control word and status word (simplified generic drive profile).
   Module 17 (Industrial communications). STARTER - the declarations are done for you;
   write the logic where it says TODO, then run:
     python3 tools/plctest.py 17-industrial-communications/labs/starter/17-3-drive-control-word.st

   The bit layout is the course's SIMPLIFIED GENERIC PROFILE (see the lesson), not
   PROFIdrive, CiA 402 or the ODVA profile.

   Control word (PLC -> drive)          Status word (drive -> PLC)
     bit 0  RUN    1 = run, 0 = stop       bit 0  READY     healthy, will run on RUN
     bit 1  REV    1 = reverse             bit 1  RUNNING   output active
     bit 2  RESET  acts on 0 -> 1          bit 2  FAULT     tripped
     bits 3-15     always 0                bit 3  AT_SPEED  actual = reference
                                           bits 4-15        vendor-specific, ignored
   Speed reference: 0..16384 = 0..100 % of maximum speed. *)

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
    (* TODO: add the edge detector, timers and internal flags you need here. *)
    Ctrl : WORD;                    (* control word under construction *)
  END_VAR

  (* TODO 1: decode Ready / Running / Faulted / AtSpeed from DriveSts.
     TODO 2: fault reset: one 500 ms RESET pulse per press; the press also clears StartFail.
     TODO 3: StartFail: RUN sent for 3 s without RUNNING.
     TODO 4: RUN bit from RunReq, blocked by a fault or StartFail; a request that saw a
             fault is spent until RunReq has been released.
     TODO 5: REV bit from RevReq, only while the drive is not RUNNING.
     TODO 6: build DriveCtrl; bits 3..15 always 0.
     TODO 7: DriveSpeedRef from SpeedSP (clamp 0..100 %, 100 % = 16384).
     Replace these placeholder lines with your logic. *)
  Ctrl := 16#0000;
  DriveCtrl := Ctrl;
  DriveSpeedRef := 0;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : DriveProfile;
  END_RESOURCE
END_CONFIGURATION
