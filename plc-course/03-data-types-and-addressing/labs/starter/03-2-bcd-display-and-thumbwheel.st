(* Lab 03-2: BCD display and thumbwheel - converting between binary INT and 4-digit BCD.
   Module 03 (Numbers, data types and addressing). STARTER - the declarations are done for you;
   write the logic where it says TODO, then run:
     python3 tools/plctest.py 03-data-types-and-addressing/labs/starter/03-2-bcd-display-and-thumbwheel.st

   An older batching skid has a 4-digit BCD display (16 digital outputs) and a 4-decade BCD
   thumbwheel switch (16 digital inputs). Each decimal digit uses one nibble (4 bits):
     bits 15..12 = thousands, 11..8 = hundreds, 7..4 = tens, 3..0 = units.
   So 1234 is sent as 16#1234, not as the binary value 16#04D2.
   Work out the digits yourself with / MOD SHL SHR AND OR. (MATIEC also offers
   UINT_TO_BCD_WORD and WORD_BCD_TO_UINT, but you still need your own range and
   validity checks, so try it by hand first.) *)

PROGRAM BcdPanel
  VAR (* I/O *)
    ThumbwheelBCD    AT %IW0   : WORD;  (* 16 inputs from the thumbwheel switch, 4 BCD digits *)
    DisplayBCD       AT %QW0   : WORD;  (* 16 outputs to the display, 4 BCD digits *)
    DisplayOverRange AT %QX0.0 : BOOL;  (* lamp: DisplayValue cannot be shown in 4 digits *)
    ThumbwheelFault  AT %QX0.1 : BOOL;  (* lamp: the thumbwheel reading has an invalid digit *)
  END_VAR
  VAR (* interface to the rest of the program *)
    DisplayValue : INT;  (* value to show on the display, written by other logic *)
    BatchSize    : INT;  (* decoded thumbwheel setting, 0..9999 *)
  END_VAR
  VAR (* internal: add any helper variables you need here *)
    ShowValue : INT;     (* suggestion: DisplayValue after clamping to 0..9999 *)
  END_VAR

  (* TODO Part A: clamp DisplayValue to 0..9999 (DisplayOverRange TRUE when it had to be
     clamped) and write it to DisplayBCD as four BCD digits.
     TODO Part B: decode ThumbwheelBCD into BatchSize. If any digit is 10..15, set
     ThumbwheelFault and keep the last good BatchSize.
     Replace these placeholder lines with your logic. *)
  DisplayBCD := 16#0000;
  DisplayOverRange := FALSE;
  BatchSize := 0;
  ThumbwheelFault := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : BcdPanel;
  END_RESOURCE
END_CONFIGURATION
