(* Lab 18-2: Mode manager for wet-well pump P-201.
   Module 18 (HMI and SCADA). STARTER - the declarations and constants are done for you;
   write the logic where it says TODO, then run:
     python3 tools/plctest.py 18-hmi-and-scada/labs/starter/18-2-mode-manager.st

   Modes:   Off / Manual / Auto, chosen from the HMI (Remote) only.
   Source:  Local (field control station LCS-201) or Remote (HMI/SCADA),
            chosen by the key selector at the pump.
   The mode manager decides who may command the pump, refuses requests that
   are not allowed (with a reason code), and makes every mode and source
   change bumpless: the pump only changes state when the NEW owner wants it.

   Training exercise only. On a real plant, dry-run protection and the local
   stop are usually hardwired as well as handled in the PLC. *)

PROGRAM ModeManager
  VAR (* field I/O *)
    LocalSel       AT %IX0.0 : BOOL;  (* Local/Remote selector at LCS-201: TRUE = Local *)
    LocalStartPB   AT %IX0.1 : BOOL;  (* Local Start push-button, NO *)
    LocalStopPB_NC AT %IX0.2 : BOOL;  (* Local Stop push-button, NC: TRUE while not pressed *)
    RunPermit      AT %IX0.3 : BOOL;  (* LSLL-201: TRUE while level is above low-low *)
    MotorRun       AT %QX0.0 : BOOL;  (* Pump contactor *)
  END_VAR
  VAR (* HMI interface - memory words the HMI reads and writes *)
    ModeReq    AT %MW0 : INT;         (* HMI -> PLC: 0 none, 1 Off, 2 Manual, 3 Auto. PLC clears *)
    MotorCmd   AT %MW1 : INT;         (* HMI -> PLC: 0 none, 1 Start, 2 Stop. PLC clears *)
    ActiveMode AT %MW2 : INT := 1;    (* PLC -> HMI: 1 Off, 2 Manual, 3 Auto *)
    RejectCode AT %MW3 : INT;         (* PLC -> HMI: result of the last HMI request *)
  END_VAR
  VAR (* from the level controller (other code; set by the test in this lab) *)
    AutoDemand    : BOOL;             (* TRUE = the level controller wants the pump *)
    AutoAvailable : BOOL;             (* TRUE = LT-201 healthy, so Auto can work *)
  END_VAR
  VAR CONSTANT
    MODE_OFF  : INT := 1;
    MODE_MAN  : INT := 2;
    MODE_AUTO : INT := 3;
    CMD_START : INT := 1;
    CMD_STOP  : INT := 2;
    REJ_NONE       : INT := 0;
    REJ_LOCAL      : INT := 1;        (* Local selected: the HMI has no control *)
    REJ_INVALID    : INT := 2;        (* value not defined *)
    REJ_NO_AUTO    : INT := 3;        (* Auto not possible now *)
    REJ_NOT_MANUAL : INT := 4;        (* Start is only allowed in Manual *)
    REJ_NO_PERMIT  : INT := 5;        (* start permissive missing *)
  END_VAR
  VAR (* suggested internal variables - add or remove as you like *)
    FirstScanDone : BOOL;             (* FALSE only on the first scan after power-up *)
    Req        : INT;                 (* snapshot of ModeReq *)
    Cmd        : INT;                 (* snapshot of MotorCmd *)
    Result     : INT;                 (* first refusal this scan, or 0 *)
    LastReject : INT;                 (* result of the last HMI request, kept *)
    IsLocal    : BOOL;
    StopHeld   : BOOL;                (* local Stop pressed (or its wire broken) *)
    CanRun     : BOOL;                (* all run permissives healthy *)
    Running    : BOOL;                (* the run state; in Auto it tracks AutoDemand *)
    Mode       : INT := 1;            (* the real mode. ActiveMode is only a copy for
                                         the HMI, so a stray write to it changes nothing *)
  END_VAR

  (* TODO 1: snapshot ModeReq and MotorCmd, then clear both registers.
             On the first scan after power-up, discard both snapshots.
     TODO 2: Local selected -> the mode is Manual.
     TODO 3: if there is a request, handle ModeReq first, then MotorCmd,
             and store the first refusal (or 0) as the result.
             Remember: Stop is obeyed from anywhere, in any mode.
     TODO 4: local Start works only in Local.
     TODO 5: Auto drops to Manual if AutoAvailable is lost or the local
             Stop is held.
     TODO 6: the run state for each mode (Off, Manual, Auto), bumpless.
     TODO 7: permissives win in every mode; drive MotorRun.
     TODO 8: publish ActiveMode and RejectCode every scan.
     Replace the placeholder lines below with your logic. *)
  MotorRun := FALSE;
  ActiveMode := MODE_OFF;
  RejectCode := REJ_NONE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : ModeManager;
  END_RESOURCE
END_CONFIGURATION
