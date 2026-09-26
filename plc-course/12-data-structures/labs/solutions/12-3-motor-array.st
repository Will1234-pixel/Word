(* Lab 12-3: Four pumps, one data model, one loop.
   Module 12 (Data structures). REFERENCE SOLUTION - try the lab yourself first.

   Four identical feed pumps, P-101 to P-104. In CODESYS or TIA Portal you
   might declare ARRAY[1..4] OF FB_Motor and call each element in a loop.
   MATIEC (and so OpenPLC) has no arrays of function block instances and no
   FB instances inside a structure, so the design here keeps EVERYTHING a
   pump needs, including what a TON would have remembered, in a structure:

     ST_MotorData = Cmd (HMI -> PLC) + Cfg (settings) + Sts (PLC -> HMI)
                    + Alm (latched alarms) + the feedback and a timing counter

   and processes ARRAY[1..4] OF ST_MotorData with ONE function block instance
   that loops over the array once per scan. The timing is done with a
   millisecond clock: each pump counts the ms for which its command and its
   feedback have disagreed, instead of owning a TON.

   Training exercise: the area stop here is an ordinary control stop, not an
   emergency stop. Emergency stops belong in a safety system (Module 20). *)

TYPE
  E_MotorState : (Stopped, Starting, Running, Faulted);

  ST_MotorCmd :
  STRUCT                          (* HMI -> PLC. The HMI sets a bit; the PLC clears it. *)
    Start : BOOL;
    Stop  : BOOL;
    Reset : BOOL;                 (* clears latched alarms; never starts the pump *)
  END_STRUCT;

  ST_MotorCfg :
  STRUCT                          (* engineer settings (retentive and change-controlled on a real plant) *)
    FbTimeoutMs : DINT := 2000;   (* ms that command and feedback may disagree *)
  END_STRUCT;

  ST_MotorSts :
  STRUCT                          (* PLC -> HMI, written by the PLC every scan *)
    State  : E_MotorState;
    RunCmd : BOOL;                (* command to the contactor *)
    Starts : DINT;                (* successful starts (Starting -> Running) since power-up *)
  END_STRUCT;

  ST_MotorAlm :
  STRUCT                          (* PLC -> HMI, latched until Reset *)
    FailToStart : BOOL;           (* started, but no feedback within FbTimeoutMs *)
    FbLost      : BOOL;           (* was running, feedback gone for FbTimeoutMs *)
    Uncommanded : BOOL;           (* stopped, but feedback present for FbTimeoutMs *)
  END_STRUCT;

  ST_MotorData :
  STRUCT
    Cmd        : ST_MotorCmd;
    Cfg        : ST_MotorCfg;
    Sts        : ST_MotorSts;
    Alm        : ST_MotorAlm;
    RunFb      : BOOL;            (* run feedback, copied from the input by the mapping layer *)
    DisagreeMs : DINT;            (* internal: ms that RunCmd and RunFb have disagreed *)
  END_STRUCT;
END_TYPE


FUNCTION_BLOCK FB_MotorGroup
  (* Runs the motor logic for every element of Motors, once per call.
     Call it exactly once per scan. All per-pump memory is in the array
     elements; the only memory of its own is the clock value of the last call.

     Per pump:
       Stopped  --Start (no Stop, no StopAll)-->  Starting
       Starting --RunFb-->                        Running   (Starts + 1)
       Starting/Running --Stop or StopAll-->      Stopped
       any state but Faulted: command and feedback disagree for
         FbTimeoutMs --> Faulted, with the alarm that matches the state:
         Starting: FailToStart, Running: FbLost, Stopped: Uncommanded
       Faulted  --Reset-->                        Stopped   (never Starting)
     RunCmd is TRUE in Starting and Running only. Command bits are cleared
     after every call. *)
  VAR_IN_OUT
    Motors : ARRAY[1..4] OF ST_MotorData;
  END_VAR
  VAR_INPUT
    NowMs   : DINT;               (* free-running millisecond clock *)
    StopAll : BOOL;               (* TRUE = stop every pump (area stop) *)
  END_VAR
  VAR_OUTPUT
    RunningCount : INT;           (* pumps in state Running *)
    AnyFault     : BOOL;          (* at least one pump in state Faulted *)
  END_VAR
  VAR
    LastMs   : DINT;              (* NowMs at the previous call *)
    ScanMs   : DINT;              (* ms since the previous call *)
    i        : INT;
    Disagree : BOOL;
  END_VAR
  VAR CONSTANT
    NO_CMD    : ST_MotorCmd := (Start := FALSE, Stop := FALSE, Reset := FALSE);
    NO_ALARMS : ST_MotorAlm := (FailToStart := FALSE, FbLost := FALSE, Uncommanded := FALSE);
  END_VAR

  ScanMs := NowMs - LastMs;
  LastMs := NowMs;
  RunningCount := 0;
  AnyFault := FALSE;

  FOR i := 1 TO 4 DO
    (* -- Reset clears the alarms and leaves a faulted pump stopped. If the
       cause is still there, the alarm comes back after another full
       FbTimeoutMs. The timing restarts only for a FAULTED pump: a Reset
       pressed while a disagreement is still being timed must not postpone
       (and so hide) the alarm. -- *)
    IF Motors[i].Cmd.Reset THEN
      Motors[i].Alm := NO_ALARMS;
      IF Motors[i].Sts.State = E_MotorState#Faulted THEN
        Motors[i].Sts.State := E_MotorState#Stopped;
        Motors[i].DisagreeMs := 0;
      END_IF;
    END_IF;

    (* -- Commands. Stop (and the area stop) win over Start. A start is only
       accepted from Stopped, so a faulted pump cannot be started. -- *)
    CASE Motors[i].Sts.State OF
      E_MotorState#Stopped:
        IF Motors[i].Cmd.Start AND NOT Motors[i].Cmd.Stop AND NOT StopAll THEN
          Motors[i].Sts.State := E_MotorState#Starting;
        END_IF;
      E_MotorState#Starting, E_MotorState#Running:
        IF Motors[i].Cmd.Stop OR StopAll THEN
          Motors[i].Sts.State := E_MotorState#Stopped;
        END_IF;
    END_CASE;

    (* -- Feedback proves the start. -- *)
    IF Motors[i].Sts.State = E_MotorState#Starting AND Motors[i].RunFb THEN
      Motors[i].Sts.State := E_MotorState#Running;
      Motors[i].Sts.Starts := Motors[i].Sts.Starts + 1;
    END_IF;

    (* -- Supervision: this pump's "timer" is a counter of milliseconds in the
       structure. It restarts whenever command and feedback agree, and it
       stops counting at the timeout (like a TON's ET stops at PT), so it
       cannot overflow however long a disagreement lasts. -- *)
    Motors[i].Sts.RunCmd := Motors[i].Sts.State = E_MotorState#Starting
                            OR Motors[i].Sts.State = E_MotorState#Running;
    Disagree := Motors[i].Sts.RunCmd XOR Motors[i].RunFb;
    IF NOT Disagree THEN
      Motors[i].DisagreeMs := 0;
    ELSIF Motors[i].DisagreeMs < Motors[i].Cfg.FbTimeoutMs THEN
      Motors[i].DisagreeMs := Motors[i].DisagreeMs + ScanMs;
    END_IF;

    IF Motors[i].DisagreeMs >= Motors[i].Cfg.FbTimeoutMs THEN
      CASE Motors[i].Sts.State OF
        E_MotorState#Starting: Motors[i].Alm.FailToStart := TRUE;
        E_MotorState#Running:  Motors[i].Alm.FbLost := TRUE;
        E_MotorState#Stopped:  Motors[i].Alm.Uncommanded := TRUE;
      END_CASE;
      Motors[i].Sts.State := E_MotorState#Faulted;
    END_IF;

    (* -- Final command and the group summary. -- *)
    Motors[i].Sts.RunCmd := Motors[i].Sts.State = E_MotorState#Starting
                            OR Motors[i].Sts.State = E_MotorState#Running;
    IF Motors[i].Sts.State = E_MotorState#Running THEN
      RunningCount := RunningCount + 1;
    END_IF;
    IF Motors[i].Sts.State = E_MotorState#Faulted THEN
      AnyFault := TRUE;
    END_IF;

    Motors[i].Cmd := NO_CMD;              (* every command bit is acted on once *)
  END_FOR;
END_FUNCTION_BLOCK


PROGRAM FeedPumps
  VAR (* physical inputs *)
    P101_RunFb AT %IX0.0 : BOOL;          (* P-101 contactor auxiliary contact *)
    P102_RunFb AT %IX0.1 : BOOL;          (* P-102 contactor auxiliary contact *)
    P103_RunFb AT %IX0.2 : BOOL;          (* P-103 contactor auxiliary contact *)
    P104_RunFb AT %IX0.3 : BOOL;          (* P-104 discharge flow switch (slow to make) *)
    StopAll_NC AT %IX1.0 : BOOL;          (* area stop push-button, NC: TRUE = healthy *)
  END_VAR
  VAR (* physical outputs *)
    P101_Contactor AT %QX0.0 : BOOL;
    P102_Contactor AT %QX0.1 : BOOL;
    P103_Contactor AT %QX0.2 : BOOL;
    P104_Contactor AT %QX0.3 : BOOL;
    FaultLamp      AT %QX0.4 : BOOL;      (* ON while any pump is faulted *)
  END_VAR
  VAR (* the data model: one element per pump, read and written by the HMI.
         Cfg.FbTimeoutMs starts at the ST_MotorCfg default of 2000 ms; the
         first-scan block gives P-104 its 5000 ms. *)
    Motors : ARRAY[1..4] OF ST_MotorData;
    RunningCount : INT;                   (* pumps proven running *)
  END_VAR
  VAR (* clock - given, do not change *)
    UpTime : TON;
    NowMs  : DINT;                        (* ms since power-up *)
  END_VAR
  VAR
    Initialised : BOOL;                   (* NOT retentive: FALSE until the first-scan block has run *)
    Group : FB_MotorGroup;                (* ONE instance for all four pumps *)
  END_VAR

  (* ---- First scan only (given): P-104's flow switch is slow to make, so it
     gets 5000 ms instead of the default 2000 ms. Standard IEC 61131-3 would
     say this in the declaration, with an initialiser for the array of
     structures:
       Motors : ARRAY[1..4] OF ST_MotorData := [3((Cfg := (FbTimeoutMs := 2000))),
                                                 (Cfg := (FbTimeoutMs := 5000))];
     OpenPLC's compiler does not accept this initialiser (see Appendix E), so
     the value is set here, at the very top, before the pump logic first
     reads it. Pumps 1 to 3 keep the default from ST_MotorCfg. Initialised
     is not RETAIN, so the block runs again after every restart, just as the
     initialiser would apply again. (Cfg is retentive on a real plant, and
     then Initialised must be RETAIN too, or every warm restart would undo
     the engineer's settings.) ---- *)
  IF NOT Initialised THEN
    Motors[4].Cfg.FbTimeoutMs := 5000;
    Initialised := TRUE;
  END_IF;

  (* ---- Millisecond clock (given): see Lab 12-2. ---- *)
  UpTime(IN := TRUE, PT := T#24d);
  NowMs := LREAL_TO_DINT(TIME_TO_LREAL(UpTime.ET) / TIME_TO_LREAL(T#1s) * 1000.0);

  (* ---- Input mapping. Located variables cannot be arrays in MATIEC, so
     each input is copied into its element by hand, here and only here. ---- *)
  Motors[1].RunFb := P101_RunFb;
  Motors[2].RunFb := P102_RunFb;
  Motors[3].RunFb := P103_RunFb;
  Motors[4].RunFb := P104_RunFb;

  (* ---- All four pumps, one call. ---- *)
  Group(Motors := Motors, NowMs := NowMs, StopAll := NOT StopAll_NC);
  RunningCount := Group.RunningCount;

  (* ---- Output mapping: the one place each output is written. ---- *)
  P101_Contactor := Motors[1].Sts.RunCmd;
  P102_Contactor := Motors[2].Sts.RunCmd;
  P103_Contactor := Motors[3].Sts.RunCmd;
  P104_Contactor := Motors[4].Sts.RunCmd;
  FaultLamp := Group.AnyFault;
END_PROGRAM


CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : FeedPumps;
  END_RESOURCE
END_CONFIGURATION
