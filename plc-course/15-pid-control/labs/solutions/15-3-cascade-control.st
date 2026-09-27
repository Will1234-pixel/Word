(* Lab 15-3: Cascade control of a steam heater.
   Module 15 (PID and closed-loop control). REFERENCE SOLUTION - try the lab yourself first.

   The outer temperature controller TIC-101 sets the setpoint of the inner steam-flow
   controller FIC-101. The work in this lab is the mode logic that makes the cascade
   safe to operate: scaling, output tracking, setpoint tracking and PV tracking. *)


(* ---------------------------------------------------------------------------------
   Given: the PID controller from Lab 15-2 (reference solution). You may paste your
   own FB_PID here instead, as long as it passes the Lab 15-2 tests.
   --------------------------------------------------------------------------------- *)
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
   Given: the plant model from Lab 15-1 (reference solution).
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


PROGRAM CascadeLab
  (* A steam heater warms a product stream. TIC-101 (outer, primary loop) controls
     the outlet temperature by setting the setpoint of FIC-101 (inner, secondary
     loop), which controls the steam flow with the steam valve. The flow controller
     has three modes, as on a DCS faceplate:
       MAN  FlowManual = TRUE                        valve set by hand (ValveManual)
       AUTO FlowManual = FALSE, CascadeMode = FALSE  flow loop on its local setpoint
       CAS  FlowManual = FALSE, CascadeMode = TRUE   setpoint comes from TIC-101 *)
  VAR (* operator commands and setpoints (HMI) *)
    TempSP      : REAL := 50.0;    (* outlet temperature setpoint, degC *)
    CascadeMode : BOOL := FALSE;   (* TRUE = FIC-101 takes its setpoint from TIC-101 *)
    FlowManual  : BOOL := TRUE;    (* TRUE = FIC-101 in manual *)
    FlowSPLocal : REAL := 2.5;     (* local steam-flow setpoint, t/h (tracks FlowSP when not in AUTO) *)
    ValveManual : REAL := 50.0;    (* valve position in manual, % (tracks ValvePos when not in MAN) *)
  END_VAR
  VAR (* controller outputs *)
    FlowSP      : REAL := 2.5;     (* setpoint FIC-101 is using, t/h *)
    ValvePos    : REAL := 50.0;    (* steam valve position = FIC-101 output, % *)
  END_VAR
  VAR (* measurements from the simulated plant *)
    FlowPV      : REAL := 0.0;     (* steam flow, t/h *)
    TempPV      : REAL := 0.0;     (* outlet temperature, degC *)
  END_VAR
  VAR (* tuning, from the worked example in the lesson *)
    FlowKc      : REAL := 15.0;    (* % per t/h *)
    FlowTi      : REAL := 1.5;     (* s *)
    TempKc      : REAL := 2.5;     (* % per degC *)
    TempTi      : REAL := 40.0;    (* s *)
  END_VAR
  VAR (* simulation and test aids *)
    SupplyFactor : REAL := 1.0;    (* steam supply pressure: 1.0 normal, 0.7 = 30 % less flow at the same valve position *)
    TempMax      : REAL := 0.0;    (* highest TempPV since a test last wrote this *)
    TempMin      : REAL := 1000.0; (* lowest TempPV since a test last wrote this *)
  END_VAR
  VAR CONSTANT
    FLOW_RANGE  : REAL := 5.0;     (* t/h at 100 % of TIC-101's output *)
  END_VAR
  VAR
    TempPID  : FB_PID;             (* TIC-101, outer loop *)
    FlowPID  : FB_PID;             (* FIC-101, inner loop *)
    FlowProc : FB_FOPDT;           (* valve -> steam flow: 0.05 t/h per %, Tau 1.5 s, dead time 0.5 s *)
    TempProc : FB_FOPDT;           (* steam flow -> temperature: 12 degC per t/h, Tau 40 s, dead time 6 s *)
  END_VAR

  (* ---- 1. Simulated plant (given - do not change) ---------------------------- *)
  FlowProc(CV := ValvePos, Gain := 0.05 * SupplyFactor, Tau := 1.5, DeadTime := 0.5,
           PV0 := 0.0, Ts := T#10ms);
  FlowPV := FlowProc.PV;
  TempProc(CV := FlowPV, Gain := 12.0, Tau := 40.0, DeadTime := 6.0, PV0 := 20.0,
           Ts := T#10ms);
  TempPV := TempProc.PV;

  (* ---- 2. Cascade control ------------------------------------------------------ *)

  (* 2a. The flow setpoint in the modes where TIC-101 is not in charge. In MAN the
         setpoint tracks the measured flow (PV tracking), so that switching to AUTO
         holds the present flow instead of jumping to an old setpoint. It is limited
         like every other setpoint, in case the measured flow is ever above range. *)
  IF FlowManual THEN
    FlowSP := LIMIT(0.0, FlowPV, FLOW_RANGE);
  ELSIF NOT CascadeMode THEN
    FlowSP := LIMIT(0.0, FlowSPLocal, FLOW_RANGE);
  END_IF;

  (* 2b. Outer loop. It only controls in CAS. In MAN and AUTO its output tracks the
         flow setpoint (converted to %), so switching to CAS starts from the flow
         that is already there: no bump, and no integral wound up while it waited. *)
  TempPID(SP := TempSP, PV := TempPV, Kc := TempKc, Ti := TempTi, Td := 0.0,
          DirectAction := FALSE,
          Manual := FlowManual OR NOT CascadeMode,
          ManualOut := FlowSP / FLOW_RANGE * 100.0,
          OutMin := 0.0, OutMax := 100.0, Ts := T#10ms);

  IF CascadeMode AND NOT FlowManual THEN
    FlowSP := TempPID.Out / 100.0 * FLOW_RANGE;   (* 0-100 % -> 0-5 t/h *)
  END_IF;

  (* The local setpoint follows the setpoint in use, so switching from CAS or MAN
     to AUTO keeps the flow where it is. *)
  FlowSPLocal := FlowSP;

  (* 2c. Inner loop. *)
  FlowPID(SP := FlowSP, PV := FlowPV, Kc := FlowKc, Ti := FlowTi, Td := 0.0,
          DirectAction := FALSE,
          Manual := FlowManual, ManualOut := ValveManual,
          OutMin := 0.0, OutMax := 100.0, Ts := T#10ms);
  ValvePos := FlowPID.Out;

  (* The manual valve value follows the valve, so switching to MAN leaves the
     valve where it is. *)
  IF NOT FlowManual THEN
    ValveManual := ValvePos;
  END_IF;

  (* ---- 3. Monitors for the tests (given - do not change) ----------------------- *)
  TempMax := MAX(TempMax, TempPV);
  TempMin := MIN(TempMin, TempPV);
END_PROGRAM


CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : CascadeLab;
  END_RESOURCE
END_CONFIGURATION
