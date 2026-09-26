(* Lab 03-2: BCD display and thumbwheel - converting between binary INT and 4-digit BCD.
   Module 03 (Numbers, data types and addressing). REFERENCE SOLUTION - try the lab yourself first.

   An older batching skid has a 4-digit BCD display (16 digital outputs) and a 4-decade BCD
   thumbwheel switch (16 digital inputs). Each decimal digit uses one nibble (4 bits):
     bits 15..12 = thousands, 11..8 = hundreds, 7..4 = tens, 3..0 = units.
   So 1234 is sent as 16#1234, not as the binary value 16#04D2.
   MATIEC also offers UINT_TO_BCD_WORD and WORD_BCD_TO_UINT; this solution does the work by
   hand so that you can see every step, and because the lab needs its own range and
   validity checks anyway. *)

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
  VAR (* internal *)
    ShowValue : INT;     (* DisplayValue after clamping to 0..9999 *)
    Units     : INT;     (* the four decoded thumbwheel digits *)
    Tens      : INT;
    Hundreds  : INT;
    Thousands : INT;
  END_VAR

  (* ---- Part A: INT -> 4-digit BCD for the display ---- *)
  (* A 4-digit display can only show 0..9999. Clamp and light the over-range lamp,
     so the operator knows the number shown is a limit, not the real value. *)
  IF DisplayValue > 9999 THEN
    ShowValue := 9999;
    DisplayOverRange := TRUE;
  ELSIF DisplayValue < 0 THEN
    ShowValue := 0;
    DisplayOverRange := TRUE;
  ELSE
    ShowValue := DisplayValue;
    DisplayOverRange := FALSE;
  END_IF;

  (* Split into decimal digits with integer division and MOD, then shift each digit
     into its own nibble. Example 1234: units 4, tens 3, hundreds 2, thousands 1. *)
  DisplayBCD := INT_TO_WORD(ShowValue MOD 10)
             OR SHL(INT_TO_WORD((ShowValue / 10) MOD 10), 4)
             OR SHL(INT_TO_WORD((ShowValue / 100) MOD 10), 8)
             OR SHL(INT_TO_WORD(ShowValue / 1000), 12);

  (* ---- Part B: 4-digit BCD from the thumbwheel -> INT ---- *)
  (* Shift each nibble down to bits 3..0 and mask off everything else. *)
  Units     := WORD_TO_INT(ThumbwheelBCD AND 16#000F);
  Tens      := WORD_TO_INT(SHR(ThumbwheelBCD, 4) AND 16#000F);
  Hundreds  := WORD_TO_INT(SHR(ThumbwheelBCD, 8) AND 16#000F);
  Thousands := WORD_TO_INT(SHR(ThumbwheelBCD, 12) AND 16#000F);

  (* A nibble of 10..15 (16#A..16#F) is not a decimal digit: a wiring fault or a damaged
     switch. Never turn such a reading into a batch size. *)
  ThumbwheelFault := (Units > 9) OR (Tens > 9) OR (Hundreds > 9) OR (Thousands > 9);

  (* Only accept a valid reading. On a fault BatchSize keeps its last good value
     (0 after power-up), and the fault lamp tells the operator why. *)
  IF NOT ThumbwheelFault THEN
    BatchSize := Thousands * 1000 + Hundreds * 100 + Tens * 10 + Units;
  END_IF;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : BcdPanel;
  END_RESOURCE
END_CONFIGURATION
