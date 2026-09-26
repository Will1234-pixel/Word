(* Lab 16-1: FB_Alarm - one alarm with an on-delay, optional latching,
   edge-triggered acknowledge and reset, and the alarm states an HMI needs.
   Module 16 (Alarms, diagnostics and fault handling). STARTER - the state
   type, the block interface and the program that uses the block are done
   for you; write the body of FB_Alarm where it says TODO, then run:
     python3 tools/plctest.py 16-alarms-and-diagnostics/labs/starter/16-1-alarm-block.st

   Tips: keep Active and Unacked as two separate memories and derive State
   from them at the end. Think about the ORDER of acknowledge and
   activation inside one scan. *)

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
    (* Add your internal variables here (timer, edge detectors ...). *)
    DelayTimer : TON;
  END_VAR

  (* TODO: replace these placeholder lines with your logic (see the
     requirements in the Module 16 README, Lab 16-1). *)
  Active := FALSE;
  Unacked := FALSE;
  State := Normal;
  Count := 0;
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

  (* The program is complete: do not change these calls. *)
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
