(* Lab 15-2: PID controller function block, tested in closed loop.
   Module 15 (PID and closed-loop control). REFERENCE SOLUTION - try the lab yourself first.

   FB_PID is a positional-form PID with output limits, anti-windup, direct/reverse
   action and bumpless manual-to-automatic transfer. The test bench (program PidLab)
   runs it against the FB_FOPDT plant model from Lab 15-1. *)

FUNCTION_BLOCK FB_PID
  (* PID controller, positional form, ideal (ISA "standard") parameters:

       Out = Kc * ( E  +  1/Ti * integral(E dt)  -  Td * dPV/dt * Sign )

     - E = SP - PV for reverse action, PV - SP for direct action.
     - Proportional acts on the error, so a setpoint step gives a proportional step.
     - Derivative acts on PV only (no "derivative kick" on a setpoint step) and is
       filtered by a first-order lag with Tf = Td / DERIV_N.
     - The integral term is stored in output units (%). That makes three things easy:
       Ti = 0 simply freezes it (it becomes the bias of a P-only controller), manual
       mode can back-calculate it for bumpless transfer, and changing Ti never bumps
       the output. *)
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
  VAR CONSTANT
    DERIV_N : REAL := 10.0;        (* derivative filter: Tf = Td / DERIV_N *)
  END_VAR
  VAR
    ITerm   : REAL := 0.0;         (* integral term, % *)
    DTerm   : REAL := 0.0;         (* filtered derivative term, % *)
    PVLast  : REAL := 0.0;         (* PV at the previous call *)
    Started : BOOL := FALSE;       (* FALSE until the first call *)
  END_VAR
  VAR_TEMP
    TsSec : REAL;                  (* sample time, s *)
    Sign  : REAL;                  (* +1 direct action, -1 reverse action *)
    E     : REAL;                  (* control error, signed for the action *)
    PTerm : REAL;                  (* proportional term, % *)
    Tf    : REAL;                  (* derivative filter time constant, s *)
    DI    : REAL;                  (* integral increment this sample, % *)
    U     : REAL;                  (* unlimited output, % *)
  END_VAR

  TsSec := TIME_TO_REAL(Ts) / TIME_TO_REAL(T#1s);  (* seconds on any platform *)

  IF DirectAction THEN
    Sign := 1.0;                   (* direct: PV above SP drives the output UP *)
  ELSE
    Sign := -1.0;                  (* reverse: PV below SP drives the output UP *)
  END_IF;
  E := Sign * (PV - SP);

  IF NOT Started THEN
    PVLast := PV;                  (* no derivative kick on the first call *)
    Started := TRUE;
  END_IF;

  (* Proportional, on the error. *)
  PTerm := Kc * E;

  (* Derivative, on PV only, through a first-order filter (backward Euler):
       Tf * dD/dt + D = Kc * Td * Sign * dPV/dt
     It runs in manual too, so PVLast and DTerm are always up to date. *)
  IF Td > 0.0 AND TsSec > 0.0 THEN
    Tf := Td / DERIV_N;
    DTerm := (Tf * DTerm + Kc * Td * Sign * (PV - PVLast)) / (Tf + TsSec);
  ELSE
    DTerm := 0.0;
  END_IF;
  PVLast := PV;

  IF Manual THEN
    (* Manual: the operator sets the output. Back-calculate the integral term so
       that P + I + D equals the present output: the first automatic sample then
       starts exactly here (bumpless transfer by output tracking). *)
    Out := LIMIT(OutMin, ManualOut, OutMax);
    ITerm := Out - PTerm - DTerm;
  ELSE
    (* Integral, with anti-windup by conditional integration (clamping): do not
       integrate further in the direction that would push the output deeper into
       a limit. Integration in the other direction is always allowed. *)
    IF Ti > 0.0 AND TsSec > 0.0 THEN
      DI := Kc * TsSec / Ti * E;
      U := PTerm + ITerm + DTerm;
      IF NOT ((U >= OutMax AND DI > 0.0) OR (U <= OutMin AND DI < 0.0)) THEN
        ITerm := ITerm + DI;
      END_IF;
    END_IF;
    (* Ti = 0: ITerm keeps its value and acts as the manual-reset bias. *)
    Out := LIMIT(OutMin, PTerm + ITerm + DTerm, OutMax);
  END_IF;
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
                        tests write its inputs directly (Bench.SP, Bench.PV, ...)
       SlowBench : FB_PID  a third, unconnected instance, called every 10th
                        scan with Ts = T#100ms, to check that the block uses Ts *)
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
    BenchPVRate : REAL := 0.0;     (* when not 0, Bench.PV ramps at this rate, units per second *)
  END_VAR
  VAR
    Loop      : FB_PID;
    Plant     : FB_FOPDT;
    Bench     : FB_PID;
    SlowBench : FB_PID;
    SlowCount : INT := 0;          (* counts scans for SlowBench *)
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

  (* 4. Open-loop test instances: only the sample time is wired, the tests write
        the other inputs. BenchPVRate ramps Bench.PV smoothly (rate x the 10 ms task
        interval each scan), so the tests can check the size of the derivative
        action whatever derivative filter the block uses. *)
  IF BenchPVRate <> 0.0 THEN
    Bench.PV := Bench.PV + BenchPVRate * 0.01;
  END_IF;
  Bench(Ts := T#10ms);

  (* SlowBench is called on scans 1, 11, 21, ...: every 100 ms of PLC time, as if it
     lived in a 100 ms task. *)
  IF SlowCount = 0 THEN
    SlowBench(Ts := T#100ms);
  END_IF;
  SlowCount := SlowCount + 1;
  IF SlowCount >= 10 THEN
    SlowCount := 0;
  END_IF;
END_PROGRAM


CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : PidLab;
  END_RESOURCE
END_CONFIGURATION
