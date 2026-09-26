(* Lab 15-1: FOPDT plant simulator.
   Module 15 (PID and closed-loop control). STARTER - the interface and the test bench
   are done for you; write the body of FB_FOPDT where it says TODO, then run:
     python3 tools/plctest.py 15-pid-control/labs/starter/15-1-fopdt-plant.st

   FB_FOPDT simulates a first-order-plus-dead-time process:

       Tau * dPV/dt + PV = PV0 + Gain * U(t - DeadTime),     U = CV + Load

   Requirements (see the lesson for details):
   1. On the first call, and on every call while Init is TRUE, the model is at steady
      state for the present input: PV = PV0 + Gain * (CV + Load), and the whole delay
      line holds that input.
   2. Otherwise the input goes through a dead time of DeadTime seconds (a delay line of
      past inputs) and then a first-order lag with time constant Tau seconds.
      Tau <= 0 means no lag.
   3. Use Ts, not a fixed 10 ms, for every time calculation. Ts is a TIME: convert it
      to seconds portably with TIME_TO_REAL(Ts) / TIME_TO_REAL(T#1s).
   4. A dead time that needs more samples than the delay line holds (2000) is limited
      to the delay-line length. Never index outside the array. *)

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
    Buf : ARRAY[0..1999] OF REAL;  (* delay line (ring buffer) of past inputs *)
    (* TODO: add the other internal variables you need (VAR or VAR_TEMP). *)
  END_VAR

  (* TODO: replace this placeholder with the model. *)
  PV := PV0;
END_FUNCTION_BLOCK


PROGRAM PlantLab
  (* Test bench (given - do not change). Two instances of the model get the same
     inputs: Plant is called every scan with Ts = the task interval; SlowPlant is
     called every 10th scan with Ts = T#100ms, as if it lived in a 100 ms task.
     With a correct model both give the same response in real time. *)
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
