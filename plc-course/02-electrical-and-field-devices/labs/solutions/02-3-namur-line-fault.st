(* Lab 02-3: NAMUR sensor with line-fault detection - turn a switching
   signal plus open-circuit and short-circuit status bits into a validated
   signal and a fault.
   Module 02 (Electrical fundamentals and field devices).
   REFERENCE SOLUTION - try the lab yourself first.
   Training exercise only: this LSH is a control function. An independent
   high-high protection layer would be engineered separately (Module 20). *)

PROGRAM NamurLineFault
  VAR (* I/O - addresses follow the OpenPLC convention *)
    FillSel      AT %IX0.0 : BOOL;  (* Fill selector: TRUE = operator wants the tank filled *)
    SensorOn     AT %IX0.1 : BOOL;  (* LSH-301 via isolator: TRUE = NAMUR current in the ON band = fork dry *)
    WireBreak    AT %IX0.2 : BOOL;  (* Isolator status: open circuit detected (TRUE = fault) *)
    ShortCircuit AT %IX0.3 : BOOL;  (* Isolator status: short circuit detected (TRUE = fault) *)
    ResetPB      AT %IX0.4 : BOOL;  (* Fault reset push-button, NO: TRUE while pressed *)
    InletValve   AT %QX0.0 : BOOL;  (* XV-301 inlet valve solenoid, spring return: TRUE = open *)
    FaultLamp    AT %QX0.1 : BOOL;  (* Amber "LSH-301 line fault" lamp, latched *)
  END_VAR
  VAR (* internal - required by the lab interface *)
    LineFault : BOOL;  (* TRUE while an open or short circuit is present *)
    HighLevel : BOOL;  (* validated high level: TRUE when high OR when the signal cannot be trusted *)
  END_VAR

  (* 1. Signal quality. Either line fault means SensorOn cannot be trusted:
        a broken wire gives no current (reads as "wet"), and a short circuit
        gives a high current (reads as "dry", the DANGEROUS direction). *)
  LineFault := WireBreak OR ShortCircuit;

  (* 2. Validated signal. The fork is set up fail-safe: current flows while it
        is dry, so a dead sensor reads "wet" = high level. On a line fault the
        program substitutes the safe value, high level, instead of using
        SensorOn. *)
  HighLevel := (NOT SensorOn) OR LineFault;

  (* 3. Latched fault lamp. The fault sets the lamp (and wins while it is
        present). Reset clears it only after the fault has gone, so a brief
        or intermittent fault is still visible to the operator later. *)
  FaultLamp := LineFault OR (FaultLamp AND NOT ResetPB);

  (* 4. Control: fill only when asked to, when the level is known to be below
        the switch, and when no line fault is waiting to be reset.
        - A real high level is a process condition: when the level falls below
          the fork again, filling resumes by itself (a permissive).
        - A line fault is an equipment problem: filling stays stopped until
          someone has looked at it and pressed Reset. That also stops a loose
          terminal from making the valve chatter.
        FaultLamp is worked out above, before it is used here, so the valve
        responds to a reset in the same scan (Module 01: order the program in
        the direction the data flows). *)
  InletValve := FillSel AND NOT HighLevel AND NOT FaultLamp;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : NamurLineFault;
  END_RESOURCE
END_CONFIGURATION
