(* Lab 15-2: PID controller function block, tested in closed loop.
   Module 15 (PID and closed-loop control). STARTER - the interface, the plant model
   and the test bench are done for you; write the body of FB_PID where it says TODO,
   then run:
     python3 tools/plctest.py 15-pid-control/labs/starter/15-2-pid-controller.st

   Requirements (see the lesson for details):
   1. Ideal (ISA standard) form: Out = Kc * (E + 1/Ti * integral(E dt) + D-part),
      with Kc in % per engineering unit and Ti, Td in SECONDS.
   2. E = SP - PV when DirectAction = FALSE (reverse acting, e.g. heating) and
      E = PV - SP when DirectAction = TRUE (direct acting, e.g. cooling).
   3. Proportional acts on the error. Derivative acts on PV only (no kick on a
      setpoint step), filtered with Tf = Td / N (N = 10 suggested).
   4. Ti = 0 means no integral action; the output is then Kc * E plus a constant
      bias (the bias is what bumpless transfer adjusts). Td = 0 means no derivative.
   5. Out always stays within OutMin..OutMax, in automatic and in manual.
   6. Anti-windup: while the output is on a limit, the integral must not keep
      growing in the direction that holds it there.
   7. Manual = TRUE: Out = ManualOut (limited). Switching to automatic must not
      bump the output, however large the error.
   8. Use Ts for all timing: TIME_TO_REAL(Ts) / TIME_TO_REAL(T#1s) gives seconds. *)

FUNCTION_BLOCK FB_PID
  VAR_INPUT
    SP           : REAL;           (* setpoint, engineering units *)
    PV           : REAL;           (* process variable, engineering units *)
    Kc           : REAL := 1.0;    (* controller gain: % output per engineering unit of error *)
    Ti           : REAL := 0.0;    (* integral time, s (seconds per repeat); 0 = no integral action *)
    Td           : REAL := 0.0;    (* derivative time, s; 0 = no derivative action *)
    DirectAction : BOOL := FALSE;  (* FALSE = reverse acting: output rises when PV falls below SP *)
    Manual       : BOOL := FALSE;  (* TRUE = manual mode: Out = ManualOut *)
    ManualOut    : REAL := 0.0;    (* output in manual, % *)
    OutMin       : REAL := 0.0;    (* output low limit, % *)
    OutMax       : REAL := 100.0;  (* output high limit, % *)
    Ts           : TIME := T#10ms; (* sample time: the interval at which this instance is called *)
  END_VAR
  VAR_OUTPUT
    Out : REAL;                    (* controller output, % *)
  END_VAR
  (* TODO: add the internal variables you need (VAR, VAR_TEMP, VAR CONSTANT). *)

  (* TODO: replace this placeholder with the PID algorithm. *)
  Out := 0.0;
END_FUNCTION_BLOCK


(* ---------------------------------------------------------------------------------
   Given: the plant model from Lab 15-1 (reference solution). You may paste your own
   FB_FOPDT here instead, as long as it passes the Lab 15-1 tests.
   --------------------------------------------------------------------------------- *)
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


PROGRAM PidLab
  (* Test bench (given - do not change). A heater controls a temperature:
       Loop  : FB_PID   the temperature controller (TIC-101), reverse acting
       Plant : FB_FOPDT the simulated process: K = 0.8 degC per %, Tau = 20 s,
                        dead time 3 s, 20 degC with the heater off
       Bench : FB_PID   a second, unconnected instance for open-loop tests; the
                        tests write its inputs directly (Bench.SP, Bench.PV, ...) *)
  VAR (* loop tags, as an HMI faceplate would read and write them *)
    SP        : REAL := 40.0;      (* setpoint, degC *)
    Manual    : BOOL := TRUE;      (* TRUE = manual, FALSE = automatic *)
    ManualOut : REAL := 25.0;      (* heater power in manual, % *)
    Kc        : REAL := 2.5;       (* gain, % per degC (lambda tuning, see the lesson) *)
    Ti        : REAL := 20.0;      (* integral time, s *)
    Td        : REAL := 0.0;       (* derivative time, s *)
    OutMax    : REAL := 100.0;     (* heater power high limit, % *)
    PV        : REAL := 0.0;       (* measured temperature, degC *)
    CV        : REAL := 25.0;      (* controller output = heater power, % (starts = ManualOut) *)
  END_VAR
  VAR (* simulation and test aids *)
    Load      : REAL := 0.0;       (* load disturbance, % of heater power (negative = extra heat loss) *)
    PlantInit : BOOL := FALSE;     (* TRUE: hold the plant at steady state for the present CV *)
    PVMax     : REAL := 0.0;       (* highest PV seen since a test last wrote this *)
    PVMin     : REAL := 1000.0;    (* lowest PV seen since a test last wrote this *)
  END_VAR
  VAR
    Loop  : FB_PID;
    Plant : FB_FOPDT;
    Bench : FB_PID;
  END_VAR

  (* 1. Simulated plant: the "outside world". It responds to the output written on
        the previous scan, as real plant responds between the output update at the
        end of one scan and the input update at the start of the next. On its first
        call it starts at steady state for CV = 25 %: PV = 20 + 0.8 x 25 = 40 degC. *)
  Plant(CV := CV, Load := Load, Gain := 0.8, Tau := 20.0, DeadTime := 3.0, PV0 := 20.0,
        Init := PlantInit, Ts := T#10ms);
  PV := Plant.PV;

  (* 2. Controller: reads PV, writes CV. The task runs every 10 ms. *)
  Loop(SP := SP, PV := PV, Kc := Kc, Ti := Ti, Td := Td, DirectAction := FALSE,
       Manual := Manual, ManualOut := ManualOut, OutMin := 0.0, OutMax := OutMax,
       Ts := T#10ms);
  CV := Loop.Out;

  (* 3. Monitors for the tests. *)
  PVMax := MAX(PVMax, PV);
  PVMin := MIN(PVMin, PV);

  (* 4. Open-loop test instance: only the sample time is wired. *)
  Bench(Ts := T#10ms);
END_PROGRAM


CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : PidLab;
  END_RESOURCE
END_CONFIGURATION
