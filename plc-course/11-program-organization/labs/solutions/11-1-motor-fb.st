(* Lab 11-1: A reusable motor function block, used three times.
   Module 11 (Program organisation). REFERENCE SOLUTION - try the lab yourself first.

   A chemical dosing room has two dosing pumps and an extract fan. One
   function block type, FB_Motor, is written and tested once, then used for
   all three motors. Each instance (Pump1, Pump2, Fan1) has its own memory:
   its own seal-in, its own feedback timer and its own fault latch. *)

FUNCTION_BLOCK FB_Motor
  (* ------------------------------------------------------------------
     FB_Motor - direct-on-line motor with run feedback supervision.

     Behaviour
       - Start (TRUE) switches RunCmd on; RunCmd then holds itself on.
       - Stop, loss of InterlockOK, or a Fault switch RunCmd off. Stop wins
         over Start. The motor never restarts on its own: after a stop, an
         interlock trip or a reset it needs a new Start. (Start is a level
         input: a request still held TRUE by automatic logic counts as a new
         Start, so that logic must drop it when a restart is not wanted.)
       - RunFb must agree with RunCmd. If they disagree for longer than
         FbTimeout (failed to start, lost feedback while running, or running
         without a command) Fault latches and RunCmd switches off.
       - Reset clears Fault. It does not restart the motor. If the cause is
         still there, the fault comes straight back.
       - Running = commanded AND feedback present ("proven running").
       - RunSeconds counts seconds of proven running (maintenance hours).
         It uses a 1 s timer that restarts every second, so it runs about
         one scan per second slow (1 % at a 10 ms scan). Good enough for
         maintenance hours, not for billing.

     The FB contains no I/O addresses. The calling program maps its inputs
     and outputs to real signals, so the same FB serves any motor.

     Version history
       1.0  first release (Lab 11-1)
     ------------------------------------------------------------------ *)
  VAR_INPUT
    Start       : BOOL;          (* start request, TRUE = start (pulse or held) *)
    Stop        : BOOL;          (* stop request, TRUE = stop; wins over Start *)
    InterlockOK : BOOL;          (* TRUE = allowed to run. No default TRUE on purpose:
                                    a forgotten connection must stop the motor,
                                    not bypass the interlock *)
    RunFb       : BOOL;          (* run feedback: contactor auxiliary contact,
                                    flow switch or airflow switch *)
    Reset       : BOOL;          (* fault reset *)
    FbTimeout   : TIME := T#2s;  (* how long RunFb may disagree with RunCmd *)
  END_VAR
  VAR_OUTPUT
    RunCmd      : BOOL;          (* command to the contactor coil *)
    Running     : BOOL;          (* proven running: RunCmd AND RunFb *)
    Fault       : BOOL;          (* latched feedback fault; needs Reset *)
    RunSeconds  : DINT;          (* extension: seconds of proven running *)
  END_VAR
  VAR
    FbCheck     : TON;           (* feedback discrepancy timer (a multi-instance) *)
    SecondTick  : TON;           (* 1 s time base for RunSeconds *)
  END_VAR

  (* 1. Reset. Checked first, so the discrepancy check further down can set
        the fault again in the same scan if its cause is still present. *)
  IF Reset THEN
    Fault := FALSE;
  END_IF;

  (* 2. Run command: seal-in with stop priority. Stop, interlock and fault
        are tested first, so none of them can be overridden by Start. *)
  IF Stop OR NOT InterlockOK OR Fault THEN
    RunCmd := FALSE;
  ELSIF Start THEN
    RunCmd := TRUE;
  END_IF;

  (* 3. Feedback supervision. XOR is TRUE whenever command and feedback
        disagree: failed to start, feedback lost while running, or running
        without a command (welded contactor, motor run in "hand"). The timer
        restarts every time they agree again. *)
  FbCheck(IN := RunCmd XOR RunFb, PT := FbTimeout);
  IF FbCheck.Q THEN
    Fault := TRUE;
    RunCmd := FALSE;
  END_IF;

  (* 4. Status *)
  Running := RunCmd AND RunFb;

  (* 5. Run-time accumulation (extension). The timer is restarted in the
        same scan that it finishes, so only one scan per second is lost. *)
  SecondTick(IN := Running, PT := T#1s);
  IF SecondTick.Q THEN
    RunSeconds := RunSeconds + 1;
    SecondTick(IN := FALSE);
  END_IF;
END_FUNCTION_BLOCK


PROGRAM DosingRoom
  VAR (* inputs *)
    Pump1StartPB   AT %IX0.0 : BOOL;  (* Pump 1 start push-button, NO *)
    Pump1StopPB_NC AT %IX0.1 : BOOL;  (* Pump 1 stop push-button, NC: TRUE while not pressed *)
    Pump1RunFb     AT %IX0.2 : BOOL;  (* Pump 1 contactor auxiliary contact: TRUE = contactor in *)
    Pump2StartPB   AT %IX0.3 : BOOL;  (* Pump 2 start push-button, NO *)
    Pump2StopPB_NC AT %IX0.4 : BOOL;  (* Pump 2 stop push-button, NC *)
    Pump2RunFb     AT %IX0.5 : BOOL;  (* Pump 2 contactor auxiliary contact *)
    Fan1StartPB    AT %IX0.6 : BOOL;  (* Extract fan start push-button, NO *)
    Fan1StopPB_NC  AT %IX0.7 : BOOL;  (* Extract fan stop push-button, NC *)
    Fan1AirflowSw  AT %IX1.0 : BOOL;  (* Extract duct airflow switch: TRUE = air moving *)
    TankLowLow_NC  AT %IX1.1 : BOOL;  (* Day-tank low-low level switch, fail-safe:
                                         TRUE = level healthy, FALSE = low-low or wire break *)
    ResetPB        AT %IX1.2 : BOOL;  (* Fault reset push-button, NO *)
  END_VAR
  VAR (* outputs *)
    Pump1Contactor AT %QX0.0 : BOOL;  (* Pump 1 contactor coil *)
    Pump2Contactor AT %QX0.1 : BOOL;  (* Pump 2 contactor coil *)
    Fan1Contactor  AT %QX0.2 : BOOL;  (* Extract fan contactor coil *)
    FaultLamp      AT %QX0.3 : BOOL;  (* Common "motor fault" lamp *)
  END_VAR
  VAR (* one instance of FB_Motor per motor *)
    Pump1 : FB_Motor;
    Pump2 : FB_Motor;
    Fan1  : FB_Motor;
  END_VAR

  (* The fan is called first because the pumps use its Running status.
     Calling it after the pumps would also work, one scan later. *)
  Fan1(Start       := Fan1StartPB,
       Stop        := NOT Fan1StopPB_NC,   (* polarity is handled here, not in the FB *)
       InterlockOK := TRUE,                (* the fan has no process interlock *)
       RunFb       := Fan1AirflowSw,
       Reset       := ResetPB,
       FbTimeout   := T#5s);               (* an airflow switch needs a few seconds to prove *)
  Fan1Contactor := Fan1.RunCmd;

  (* Dosing pumps may run only while the extract fan is PROVEN running and
     the day tank is above low-low. Fan1.Running, not Fan1.RunCmd: a fan
     that has been told to run but moves no air does not ventilate the room. *)
  Pump1(Start       := Pump1StartPB,
        Stop        := NOT Pump1StopPB_NC,
        InterlockOK := Fan1.Running AND TankLowLow_NC,
        RunFb       := Pump1RunFb,
        Reset       := ResetPB);           (* FbTimeout left at its 2 s default *)
  Pump1Contactor := Pump1.RunCmd;

  Pump2(Start       := Pump2StartPB,
        Stop        := NOT Pump2StopPB_NC,
        InterlockOK := Fan1.Running AND TankLowLow_NC,
        RunFb       := Pump2RunFb,
        Reset       := ResetPB);
  Pump2Contactor := Pump2.RunCmd;

  FaultLamp := Pump1.Fault OR Pump2.Fault OR Fan1.Fault;
END_PROGRAM


CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : DosingRoom;
  END_RESOURCE
END_CONFIGURATION
