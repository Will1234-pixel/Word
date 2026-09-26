(* Lab 15-1: FOPDT plant simulator.
   Module 15 (PID and closed-loop control). REFERENCE SOLUTION - try the lab yourself first.

   FB_FOPDT simulates a first-order-plus-dead-time process, the standard model of a
   self-regulating process (a heater, a heat exchanger, a flow through a valve):

       Tau * dPV/dt + PV = PV0 + Gain * U(t - DeadTime),     U = CV + Load

   Programs in the next labs use it as the "plant" that a PID controller controls.
   The program PlantLab below is the test bench and is the same in the starter. *)

FUNCTION_BLOCK FB_FOPDT
  VAR_INPUT
    CV       : REAL;           (* plant input, normally the controller output, % *)
    Load     : REAL;           (* load disturbance in CV units, added to CV *)
    Gain     : REAL := 1.0;    (* process gain K: change in PV per unit change in CV *)
    Tau      : REAL := 10.0;   (* time constant, s (0 or less = no lag) *)
    DeadTime : REAL := 0.0;    (* dead time, s (limited to the delay-line length) *)
    PV0      : REAL := 0.0;    (* PV when CV + Load = 0, e.g. ambient temperature *)
    Init     : BOOL := FALSE;  (* TRUE: hold the model at steady state for the present input *)
    Ts       : TIME := T#10ms; (* sample time: the interval at which this instance is called *)
  END_VAR
  VAR_OUTPUT
    PV : REAL;                 (* simulated process variable *)
  END_VAR
  VAR CONSTANT
    BUF_SIZE : INT := 2000;    (* delay-line length in samples: 20 s at 10 ms *)
  END_VAR
  VAR
    Buf     : ARRAY[0..1999] OF REAL;  (* delay line (ring buffer) of past inputs *)
    WrIdx   : INT := 0;        (* index of the newest input in Buf *)
    Started : BOOL := FALSE;   (* FALSE until the first call has initialised the model *)
  END_VAR
  VAR_TEMP
    U        : REAL;           (* total plant input this sample *)
    UDelayed : REAL;           (* the input from DeadTime ago *)
    TsSec    : REAL;           (* sample time in seconds *)
    Samples  : REAL;           (* dead time in samples, before rounding *)
    Delay    : INT;            (* dead time in whole samples *)
    RdIdx    : INT;            (* index of the delayed input in Buf *)
    Alpha    : REAL;           (* lag factor per sample, EXP(-Ts/Tau) *)
    i        : INT;
  END_VAR

  U := CV + Load;

  (* Sample time in seconds. Dividing by TIME_TO_REAL(T#1s) makes this portable:
     MATIEC converts TIME to seconds, CODESYS to milliseconds; the ratio is the same. *)
  TsSec := TIME_TO_REAL(Ts) / TIME_TO_REAL(T#1s);

  IF Init OR NOT Started THEN
    (* Steady state for the present input: the whole delay line holds U and PV has
       settled. Doing this on the first call as well means the model starts at
       steady state instead of climbing up from PV = 0 at power-up. *)
    FOR i := 0 TO BUF_SIZE - 1 DO
      Buf[i] := U;
    END_FOR;
    PV := PV0 + Gain * U;
    Started := TRUE;

  ELSIF TsSec > 0.0 THEN
    (* 1. Dead time, in whole samples. Limit it in REAL before converting, so a
          huge DeadTime cannot overflow the INT, and never look further back
          than the delay line holds. *)
    Samples := DeadTime / TsSec;
    IF Samples > INT_TO_REAL(BUF_SIZE - 1) THEN
      Delay := BUF_SIZE - 1;
    ELSIF Samples < 0.0 THEN
      Delay := 0;
    ELSE
      Delay := REAL_TO_INT(Samples);
    END_IF;

    (* 2. Write the newest input into the ring buffer... *)
    WrIdx := WrIdx + 1;
    IF WrIdx >= BUF_SIZE THEN
      WrIdx := 0;
    END_IF;
    Buf[WrIdx] := U;

    (* ...and read the one written Delay samples ago (Delay = 0 reads the newest). *)
    RdIdx := WrIdx - Delay;
    IF RdIdx < 0 THEN
      RdIdx := RdIdx + BUF_SIZE;
    END_IF;
    UDelayed := Buf[RdIdx];

    (* 3. First-order lag. Exact discretisation of Tau*dPV/dt = target - PV for an
          input that is constant over one sample: PV moves the fraction (1 - Alpha)
          of the way to the target every sample. *)
    IF Tau > 0.0 THEN
      Alpha := EXP(-TsSec / Tau);
      PV := Alpha * PV + (1.0 - Alpha) * (PV0 + Gain * UDelayed);
    ELSE
      PV := PV0 + Gain * UDelayed;
    END_IF;
  END_IF;
END_FUNCTION_BLOCK


PROGRAM PlantLab
  (* Test bench (given, the same in the starter). Two instances of the model get
     the same inputs: Plant is called every scan with Ts = the task interval;
     SlowPlant is called every 10th scan with Ts = T#100ms, as if it lived in a
     100 ms task. With a correct model both give the same response in real time. *)
  VAR (* test-bench inputs: plant input and model parameters *)
    CV       : REAL := 0.0;    (* plant input, % *)
    Load     : REAL := 0.0;    (* load disturbance, % *)
    Gain     : REAL := 1.0;    (* process gain K *)
    Tau      : REAL := 10.0;   (* time constant, s *)
    DeadTime : REAL := 0.0;    (* dead time, s *)
    PV0      : REAL := 0.0;    (* PV at zero input *)
    Init     : BOOL := FALSE;  (* TRUE: hold both models at steady state *)
  END_VAR
  VAR (* test-bench outputs *)
    PV     : REAL;             (* Plant.PV     (called every scan, Ts = T#10ms) *)
    SlowPV : REAL;             (* SlowPlant.PV (called every 10th scan, Ts = T#100ms) *)
  END_VAR
  VAR
    Plant     : FB_FOPDT;
    SlowPlant : FB_FOPDT;
    SlowCount : INT := 0;
  END_VAR

  (* The TASK below runs every 10 ms, so Ts must be T#10ms here. *)
  Plant(CV := CV, Load := Load, Gain := Gain, Tau := Tau, DeadTime := DeadTime,
        PV0 := PV0, Init := Init, Ts := T#10ms);
  PV := Plant.PV;

  (* Called on scans 1, 11, 21, ...: every 100 ms of PLC time. *)
  IF SlowCount = 0 THEN
    SlowPlant(CV := CV, Load := Load, Gain := Gain, Tau := Tau, DeadTime := DeadTime,
              PV0 := PV0, Init := Init, Ts := T#100ms);
  END_IF;
  SlowCount := SlowCount + 1;
  IF SlowCount >= 10 THEN
    SlowCount := 0;
  END_IF;
  SlowPV := SlowPlant.PV;
END_PROGRAM


CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : PlantLab;
  END_RESOURCE
END_CONFIGURATION
