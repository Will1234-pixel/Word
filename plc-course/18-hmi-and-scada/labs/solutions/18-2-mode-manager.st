(* Lab 18-2: Mode manager for wet-well pump P-201.
   Module 18 (HMI and SCADA). REFERENCE SOLUTION - try the lab yourself first.

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
  VAR
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

  (* 1. Snapshot the HMI requests and clear them: each is handled once. *)
  Req := ModeReq;
  ModeReq := 0;
  Cmd := MotorCmd;
  MotorCmd := 0;

  (* A request already waiting on the first scan was written before a power
     cut or a download. Acting on it now could put the pump in Auto and
     start it with nobody watching, so it is discarded (as in Lab 18-1). *)
  IF NOT FirstScanDone THEN
    Req := 0;
    Cmd := 0;
    FirstScanDone := TRUE;
  END_IF;

  IsLocal := LocalSel;
  StopHeld := NOT LocalStopPB_NC;
  CanRun := RunPermit AND NOT StopHeld;

  (* 2. Control source. Local always means local manual control. The run
        state is not touched, so the transfer is bumpless both ways. *)
  IF IsLocal THEN
    Mode := MODE_MAN;
  END_IF;

  (* 3. HMI requests. The mode request is handled before the motor command,
        and RejectCode reports the first refusal. *)
  IF Req <> 0 OR Cmd <> 0 THEN
    Result := REJ_NONE;

    IF Req <> 0 THEN
      IF IsLocal THEN
        Result := REJ_LOCAL;
      ELSIF Req = MODE_OFF OR Req = MODE_MAN THEN
        Mode := Req;                  (* Manual keeps the pump as it is *)
      ELSIF Req = MODE_AUTO THEN
        IF AutoAvailable AND NOT StopHeld THEN
          Mode := MODE_AUTO;          (* the pump now follows AutoDemand *)
        ELSE
          Result := REJ_NO_AUTO;
        END_IF;
      ELSE
        Result := REJ_INVALID;
      END_IF;
    END_IF;

    IF Cmd = CMD_STOP THEN
      (* A stop is obeyed from any source and in any mode. In Auto it also
         hands the pump to Manual, so the demand cannot restart it. *)
      Running := FALSE;
      IF Mode = MODE_AUTO THEN
        Mode := MODE_MAN;
      END_IF;
    ELSIF Cmd <> 0 THEN
      IF IsLocal THEN
        IF Result = REJ_NONE THEN Result := REJ_LOCAL; END_IF;
      ELSIF Cmd <> CMD_START THEN
        IF Result = REJ_NONE THEN Result := REJ_INVALID; END_IF;
      ELSIF Mode <> MODE_MAN THEN
        IF Result = REJ_NONE THEN Result := REJ_NOT_MANUAL; END_IF;
      ELSIF NOT CanRun THEN
        IF Result = REJ_NONE THEN Result := REJ_NO_PERMIT; END_IF;
      ELSE
        Running := TRUE;
      END_IF;
    END_IF;

    LastReject := Result;             (* kept until the next request *)
  END_IF;

  (* 4. Local push-buttons. Start works only in Local; Stop is covered by
        CanRun below and works everywhere. *)
  IF IsLocal AND LocalStartPB AND CanRun THEN
    Running := TRUE;
  END_IF;

  (* 5. Auto drops to Manual when it can no longer work (mode shedding, the
        pump keeps its state) or when someone presses the local Stop. *)
  IF Mode = MODE_AUTO AND (NOT AutoAvailable OR StopHeld) THEN
    Mode := MODE_MAN;
  END_IF;

  (* 6. The run state for each mode. In Auto, Running is overwritten with the
        demand every scan, so it always holds the pump's real state; that is
        what makes Auto -> Manual bumpless. *)
  IF Mode = MODE_OFF THEN
    Running := FALSE;
  ELSIF Mode = MODE_AUTO THEN
    Running := AutoDemand;
  END_IF;

  (* 7. Permissives win in every mode. In Manual the pump stays off when the
        permissive returns; in Auto it follows the demand again. *)
  IF NOT CanRun THEN
    Running := FALSE;
  END_IF;
  MotorRun := Running;

  (* 8. Publish the status for the HMI. These registers are written every
        scan, so nothing written into them from outside can stick. *)
  ActiveMode := Mode;
  RejectCode := LastReject;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : ModeManager;
  END_RESOURCE
END_CONFIGURATION
