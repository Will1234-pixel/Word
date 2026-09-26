(* Lab 12-3: Four pumps, one data model, one loop.
   Module 12 (Data structures). STARTER - the data model (types), the
   program I/O, the array of pumps and the millisecond clock are done for you.
   MATIEC has no arrays of FB instances and no FB instances inside a STRUCT,
   so everything a pump must remember lives in its ST_MotorData element.
   Write:
     1. the input mapping (feedback inputs into Motors[i].RunFb),
     2. the pump logic for all four pumps in ONE FOR loop - in the program
        body, or in one FUNCTION_BLOCK instance that loops over the array,
     3. RunningCount and the output mapping (contactors, fault lamp).
   You may add members to the types (tests only use the documented ones).
   Then run:
     python3 tools/plctest.py 12-data-structures/labs/starter/12-3-motor-array.st

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
  VAR (* the data model: one element per pump, read and written by the HMI *)
    Motors : ARRAY[1..4] OF ST_MotorData := [3((Cfg := (FbTimeoutMs := 2000))),
                                              (Cfg := (FbTimeoutMs := 5000))];
    RunningCount : INT;                   (* pumps proven running *)
  END_VAR
  VAR (* clock - given, do not change *)
    UpTime : TON;
    NowMs  : DINT;                        (* ms since power-up *)
  END_VAR
  (* TODO: add a VAR ... END_VAR block here for your internal variables. *)

  (* ---- Millisecond clock (given): ms since power-up. See Lab 12-2. ---- *)
  UpTime(IN := TRUE, PT := T#24d);
  NowMs := LREAL_TO_DINT(TIME_TO_LREAL(UpTime.ET) / TIME_TO_LREAL(T#1s) * 1000.0);

  (* TODO: replace these placeholder lines with the input mapping, the loop
     over Motors[1..4], RunningCount and the output mapping. *)
  P101_Contactor := FALSE;
  RunningCount := 0;
END_PROGRAM


CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : FeedPumps;
  END_RESOURCE
END_CONFIGURATION
