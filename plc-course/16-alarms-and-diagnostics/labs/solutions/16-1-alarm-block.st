(* Lab 16-1: FB_Alarm - one alarm with an on-delay, optional latching,
   edge-triggered acknowledge and reset, and the alarm states an HMI needs.
   Module 16 (Alarms, diagnostics and fault handling). REFERENCE SOLUTION - try the lab yourself first.

   Design: an alarm has two independent properties.
     Active  - is the alarm condition there (or, for a latching alarm, still latched)?
     Unacked - has the operator acknowledged the latest activation?
   The State output combines them, plus "has the condition gone?" for a
   latching alarm, into one value that an HMI can show directly. *)

TYPE
  E_AlarmState : (
    Normal,        (* not active, nothing to acknowledge *)
    ActiveUnack,   (* active, not yet acknowledged: flash + horn *)
    ActiveAcked,   (* active, acknowledged, condition still present: steady *)
    RtnUnack,      (* returned to normal before anyone acknowledged it *)
    LatchedRtn     (* latching alarm: acknowledged, condition gone, waiting for reset *)
  );
END_TYPE

FUNCTION_BLOCK FB_Alarm
  (* ------------------------------------------------------------------
     FB_Alarm - one annunciated alarm.

     Behaviour   Condition must last OnDelay before the alarm activates.
                 Each activation sets Active and Unacked and adds 1 to Count.
                 Ack (press) clears Unacked. Non-latching: Active follows
                 the confirmed condition. Latching: Active stays TRUE until
                 a Reset press while acknowledged and the condition is gone.
                 Reset never acknowledges and never affects a non-latching
                 alarm.
     Version     1.0  first release
     ------------------------------------------------------------------ *)
  VAR_INPUT
    Condition : BOOL;   (* raw alarm condition from the process logic *)
    OnDelay   : TIME;   (* Condition must last this long before the alarm activates *)
    Latching  : BOOL;   (* TRUE: stays active after the condition clears, until Reset *)
    Ack       : BOOL;   (* acknowledge command: acts on its rising edge *)
    Reset     : BOOL;   (* reset command for a latching alarm: acts on its rising edge *)
  END_VAR
  VAR_OUTPUT
    Active    : BOOL;   (* alarm is active: confirmed condition, or latched *)
    Unacked   : BOOL;   (* the latest activation has not been acknowledged *)
    State     : E_AlarmState;
    Count     : DINT;   (* activations since power-up, for alarm statistics *)
  END_VAR
  VAR
    DelayTimer : TON;
    AckEdge    : R_TRIG;
    ResetEdge  : R_TRIG;
    Confirmed  : BOOL;  (* Condition has lasted for OnDelay *)
  END_VAR

  (* 1. Confirm the condition. Any gap restarts the delay, so a fleeting
        condition shorter than OnDelay never reaches the operator. *)
  DelayTimer(IN := Condition, PT := OnDelay);
  Confirmed := DelayTimer.Q;

  AckEdge(CLK := Ack);
  ResetEdge(CLK := Reset);

  (* 2. Acknowledge BEFORE new activations are processed: a press can only
        acknowledge alarms that existed before it. Acting on the edge means
        a held or jammed button cannot acknowledge alarms that come later. *)
  IF AckEdge.Q THEN
    Unacked := FALSE;
  END_IF;

  (* 3. Return to normal. *)
  IF NOT Confirmed THEN
    IF NOT Latching THEN
      Active := FALSE;            (* Unacked is kept: "returned to normal, unacknowledged" *)
    ELSIF ResetEdge.Q AND NOT Unacked THEN
      Active := FALSE;            (* latched: only an acknowledged reset clears it *)
    END_IF;
  END_IF;

  (* 4. Activation: a confirmed condition on an alarm that is not active is
        a new occurrence, which the operator must acknowledge again. A
        latching alarm that is still latched is already active, so the
        condition coming back is not a new occurrence. *)
  IF Confirmed AND NOT Active THEN
    Active := TRUE;
    Unacked := TRUE;
    Count := Count + 1;
  END_IF;

  (* 5. One state value for the HMI. *)
  IF Active AND Unacked THEN
    State := ActiveUnack;
  ELSIF Active AND Confirmed THEN
    State := ActiveAcked;
  ELSIF Active THEN
    State := LatchedRtn;
  ELSIF Unacked THEN
    State := RtnUnack;
  ELSE
    State := Normal;
  END_IF;
END_FUNCTION_BLOCK

PROGRAM AlarmDemo
  VAR (* panel push-buttons and horn *)
    AckPB   AT %IX0.0 : BOOL;   (* Acknowledge push-button, NO *)
    ResetPB AT %IX0.1 : BOOL;   (* Reset push-button, NO *)
    Horn    AT %QX0.0 : BOOL;   (* Alarm horn *)
  END_VAR
  VAR (* alarm conditions: in a real program they come from process logic
         (for example FB_AnalogAlarm, Lab 14-2). Here the test writes them. *)
    TempHigh : BOOL;   (* TT-201 compressor bearing temperature high *)
    VibHigh  : BOOL;   (* VT-202 compressor vibration high-high *)
    DoorOpen : BOOL;   (* acoustic enclosure door open *)
  END_VAR
  VAR
    TempAlm : FB_Alarm;
    VibAlm  : FB_Alarm;
    DoorAlm : FB_Alarm;
  END_VAR

  (* The program is complete in the starter: only FB_Alarm is to be written. *)
  TempAlm(Condition := TempHigh, OnDelay := T#3s, Latching := FALSE, Ack := AckPB, Reset := ResetPB);
  VibAlm(Condition := VibHigh, OnDelay := T#1s, Latching := TRUE, Ack := AckPB, Reset := ResetPB);
  DoorAlm(Condition := DoorOpen, OnDelay := T#0s, Latching := FALSE, Ack := AckPB, Reset := ResetPB);

  (* The horn sounds while any alarm is unacknowledged. *)
  Horn := TempAlm.Unacked OR VibAlm.Unacked OR DoorAlm.Unacked;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : AlarmDemo;
  END_RESOURCE
END_CONFIGURATION
