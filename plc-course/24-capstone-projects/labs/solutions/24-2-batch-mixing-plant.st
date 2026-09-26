(* Capstone 24-2: Batch mixing plant (mixing vessel T-201).
   Module 24 (Capstone projects). REFERENCE SOLUTION - build the project
   yourself first. Brief: 24-capstone-projects/24-2-batch-mixing-plant.md

   How this solution is organised
   ------------------------------
   Reusable function blocks (each one does one job and can be tested alone):
     F_RecipeValid  recipe range checks used by the Start permissive
     FB_CycleTime   measures the real time between scans
     FB_AnalogIn    4-20 mA input: scaling, NAMUR NE43 check, filter, hold
     FB_FlowTotal   flow-meter pulse totaliser (DINT count, exact)
     FB_Charge      one dosing phase: preact, settle, no-flow and time watchdogs
     FB_Motor       motor with running-feedback supervision and fault latch
     FB_PID         ideal-form PID with anti-windup and an enable/freeze
   The program BatchMixer runs in this order every scan:
     1 plant simulation (given)
     2 time base and HMI commands (read once, then cleared: a handshake)
     3 measurements
     4 alarms and faults (latch, reset, acknowledge, hold causes)
     5 batch state machine (ISA-88 style states) and phase sequence
     6 equipment control (dosing, agitator, TIC-203, drain), with interlocks
     7 outputs with the e-stop override, HMI status
   The state machine decides WHAT should happen; the equipment section
   decides HOW, and owns every output in exactly one place. *)

(* =====================================================================
   GIVEN TYPES - part of the project interface. Do not change them: the
   acceptance test and the HMI depend on these names.
   ===================================================================== *)
TYPE
  (* Procedural state of the batch (a subset of the ISA-88 state model).
     Holding, Restarting and Aborting are transient: the batch passes
     through them while their actions complete. *)
  E_BatchState : (Idle, Running, Holding, Held, Restarting, Aborting,
                  Aborted, Complete);

  (* Phase of the batch procedure that is active, or was active when the
     batch was held. PhaseNone when no batch is in progress. *)
  E_BatchPhase : (PhaseNone, PhaseChargeA, PhaseChargeB, PhaseHeat,
                  PhaseMix, PhaseDrain);

  (* One recipe (the ISA-88 "formula": the parameters of the procedure) *)
  ST_Recipe : STRUCT
    Name     : STRING;    (* shown on the HMI and in the batch report *)
    QtyA     : REAL;      (* ingredient A to charge, litres *)
    QtyB     : REAL;      (* ingredient B to charge, litres; 0.0 = none *)
    TempSP   : REAL;      (* process temperature setpoint, degC *)
    MixTime  : TIME;      (* minimum agitation time in the mix/hold phase *)
    HoldTime : TIME;      (* time the contents must spend at temperature *)
  END_STRUCT;

  (* Engineering configuration. The defaults suit the plant; the test
     changes a few of them to check that your program uses them. *)
  ST_BatchCfg : STRUCT
    LitresPerPulseA : REAL := 0.5;    (* FT-201 K-factor: 2 pulses per litre *)
    LitresPerPulseB : REAL := 0.1;    (* FT-202 K-factor: 10 pulses per litre *)
    PreactA         : REAL := 4.0;    (* in-flight volume of XV-201, L: close this early *)
    PreactB         : REAL := 1.0;    (* in-flight volume of XV-202, L *)
    SettleTime      : TIME := T#3s;   (* after an inlet closes, before the charge is complete *)
    NoFlowTime      : TIME := T#10s;  (* inlet open, no meter pulse for this long = dosing fault *)
    MaxChargeTime   : TIME := T#5m;   (* longest a charge phase may run = dosing fault *)
    MaxHeatTime     : TIME := T#15m;  (* longest the heating phase may run = heating timeout *)
    TempBand        : REAL := 2.0;    (* "at temperature" = within +/- this of TempSP, degC *)
    TempHighLimit   : REAL := 85.0;   (* high temperature alarm, degC (clears 2 degC below) *)
    TempKc          : REAL := 8.0;    (* TIC-203 gain, % per degC (ideal form) *)
    TempTi          : REAL := 200.0;  (* TIC-203 integral time, s *)
    TempTd          : REAL := 0.0;    (* TIC-203 derivative time, s *)
    AgitStartLevel  : REAL := 10.0;   (* agitator may start at or above this level, % *)
    AgitStopLevel   : REAL := 8.0;    (* agitator stops below this level, % *)
    HeatMinLevel    : REAL := 12.0;   (* heating allowed at or above this level, % *)
    EmptyLevel      : REAL := 1.0;    (* vessel empty at or below this level, % *)
    DrainRunOn      : TIME := T#5s;   (* pump keeps running this long after empty *)
    ValveLeadTime   : TIME := T#2s;   (* XV-204 opens this long before P-204 starts,
                                         and closes this long after it stops *)
    FeedbackTime    : TIME := T#3s;   (* motor command/feedback disagreement = fault *)
    XmtrFaultDelay  : TIME := T#2s;   (* NE43 failure must persist this long *)
    MinBatchL       : REAL := 300.0;  (* smallest valid batch (QtyA + QtyB), L *)
    MaxBatchL       : REAL := 1500.0; (* largest valid batch, L *)
    MinTempSP       : REAL := 20.0;   (* lowest valid recipe setpoint, degC (no cooling) *)
    MaxTempSP       : REAL := 80.0;   (* highest valid recipe setpoint, degC *)
  END_STRUCT;

  (* HMI interface. Commands: the HMI sets them TRUE, the PLC acts on them
     once and clears them in the same scan. Status: written by the PLC. *)
  ST_BatchHmi : STRUCT
    CmdStart     : BOOL;          (* start a batch with recipe RecipeNo *)
    CmdHold      : BOOL;
    CmdRestart   : BOOL;
    CmdAbort     : BOOL;
    CmdReset     : BOOL;          (* reset faults; Complete/Aborted -> Idle *)
    CmdAck       : BOOL;          (* acknowledge all alarms *)
    CmdDrain     : BOOL;          (* empty the vessel (from Idle only) *)
    RecipeNo     : INT := 1;      (* operator's recipe selection, 1..5 *)
    State        : E_BatchState;
    Phase        : E_BatchPhase;
    ActiveRecipe : INT;           (* recipe of the batch in progress; 0 = none *)
    RejectCode   : INT;           (* result of the last Start: 0 = accepted *)
    LevelPct     : REAL;          (* LT-201, % *)
    TempC        : REAL;          (* TT-203, degC *)
    TotalA       : REAL;          (* ingredient A counted this batch, L *)
    TotalB       : REAL;          (* ingredient B counted this batch, L *)
    AlmActive    : WORD;          (* one bit per alarm, see the brief *)
    AlmUnack     : WORD;          (* same bits: not yet acknowledged *)
  END_STRUCT;

  (* Written once per completed batch (quality record) *)
  ST_BatchReport : STRUCT
    BatchCount : DINT;            (* batches completed since power-up *)
    RecipeNo   : INT;
    RecipeName : STRING;
    ActualA    : REAL;            (* litres counted by FT-201, in-flight included *)
    ActualB    : REAL;            (* litres counted by FT-202 *)
    BatchTime  : TIME;            (* Start accepted -> Complete, time held included *)
    MaxTemp    : REAL;            (* highest TT-203 reading during the batch, degC *)
  END_STRUCT;
END_TYPE

(* =====================================================================
   GIVEN PLANT SIMULATION - do not change.
   FB_PlantSim models the vessel, its valves, motors and instruments well
   enough to test the control logic. It also records "observer" values
   that the acceptance test uses as an independent referee (for example,
   how many litres really went into the vessel, whatever your program
   counted).

   The program calls it once per scan with last scan's outputs and copies
   its outputs into the input image. The test drives it by writing its
   inputs (set Sim.FlowFactorA 0.0, set Sim.AgitatorFail TRUE, ...).

   Model (see the brief for more):
   - Vessel T-201: 2000 L = 100 %, flat bottom (1 % = 20 L).
   - XV-201, XV-202, XV-204: 2 s full stroke, spring-return (fail closed).
     Flow is proportional to the valve position.
   - Ingredient A: 4.0 L/s fully open; FT-201 gives one pulse per 0.5 L.
     Ingredient B: 1.0 L/s fully open; FT-202 gives one pulse per 0.1 L.
     Each pulse is a square wave (on for half the pulse volume).
   - P-204 pumps 6.0 L/s through a fully open XV-204; its flow falls away
     below 10 L in the vessel.
   - M-201 running feedback 1.0 s after its command, P-204 0.5 s; both
     drop at once when the command drops or the motor fails.
   - Heating: TV-203 (0..27648 counts = 0..100 %) admits steam to the
     jacket. The heat reaches the contents through a 10 s lag, is reduced
     as the contents approach the 130 degC steam temperature, and falls to
     30 % if the agitator is stopped. The vessel loses heat slowly to the
     20 degC surroundings. TT-203 sits in a thermowell (3 s lag).
     Ingredients enter at 20 degC.
   - LT-201 0..100 % and TT-203 0..150 degC are 4-20 mA transmitters
     (NE43: they saturate at 3.8 and 20.5 mA). The analog card reads
     4 mA = 0 and 20 mA = 27648 counts (1728 counts per mA) and clips at
     -4864 and 32511.
   - LSHH-201 trips at 1800 L (90 %) and resets at 1780 L. NC contact.
   - PowerOK FALSE (safety relay open) removes power from every field
     output: valves close, motors stop, the steam valve closes.
   - Physics is integrated in fixed 10 ms steps.
   ===================================================================== *)
FUNCTION_BLOCK FB_PlantSim
  VAR_INPUT
    InletA       : BOOL;           (* XV-201 open command *)
    InletB       : BOOL;           (* XV-202 open command *)
    Outlet       : BOOL;           (* XV-204 open command *)
    Agitator     : BOOL;           (* M-201 run command *)
    Pump         : BOOL;           (* P-204 run command *)
    HeatValveRaw : INT;            (* TV-203 analog output, counts *)
    PowerOK      : BOOL := TRUE;   (* safety relay closed *)
    (* fault injection and test hooks *)
    FlowFactorA  : REAL := 1.0;    (* supply A: 1.0 normal, 0.0 no flow, 0.3 partly blocked *)
    FlowFactorB  : REAL := 1.0;    (* supply B *)
    AgitatorFail : BOOL;           (* M-201 will not run (or trips if running) *)
    PumpFail     : BOOL;           (* P-204 will not run (or trips if running) *)
    HeatFail     : BOOL;           (* no steam: the jacket gives no heat *)
    HHWireBreak  : BOOL;           (* LSHH-201 circuit open *)
    TtForce      : BOOL;           (* TT-203 loop current replaced by TtForcemA *)
    TtForcemA    : REAL := 12.0;   (*   (a loop calibrator, or a failed loop) *)
    LtForce      : BOOL;           (* LT-201 loop current replaced by LtForcemA *)
    LtForcemA    : REAL := 12.0;
  END_VAR
  VAR_OUTPUT
    (* field signals, copied to the PLC input image *)
    FlowPulseA      : BOOL;
    FlowPulseB      : BOOL;
    AgitatorRunning : BOOL;
    PumpRunning     : BOOL;
    LevelHH_NC      : BOOL := TRUE;
    LevelRaw        : INT;
    TempRaw         : INT;
    (* process state: a test may SET these to jump to a new condition *)
    VolumeL         : LREAL := 0.0;   (* liquid in the vessel, L *)
    TempC           : REAL := 20.0;   (* true temperature of the contents, degC *)
    (* observer values, for the tests *)
    HeatValvePct    : REAL;           (* steam valve position the plant sees, % *)
    DeliveredA      : LREAL;          (* true litres through XV-201 since power-up *)
    DeliveredB      : LREAL;          (* true litres through XV-202 *)
    DrainedL        : LREAL;          (* true litres pumped out *)
    MaxVolumeL      : REAL;           (* highest volume seen *)
    MaxTempC        : REAL := 20.0;   (* highest true temperature seen (a test may reset it) *)
    AgitatorDryS    : REAL;           (* s the agitator ran with less than 150 L in the vessel *)
    HeatNoAgitS     : REAL;           (* s of steam with the agitator stopped or < 200 L *)
    DeadheadS       : REAL;           (* s P-204 ran without XV-204 fully open *)
  END_VAR
  VAR CONSTANT
    STEP_TIME     : TIME := T#10ms;   (* integration step *)
    STEP_S        : REAL := 0.01;
    VESSEL_L      : REAL := 2000.0;
    AMBIENT_C     : REAL := 20.0;
    STROKE_S      : REAL := 2.0;      (* valve full stroke *)
    FLOW_A_LPS    : REAL := 4.0;
    FLOW_B_LPS    : REAL := 1.0;
    PUMP_LPS      : REAL := 6.0;
    HALF_PULSE_A  : LREAL := 0.25;    (* half of 0.5 L per pulse *)
    HALF_PULSE_B  : LREAL := 0.05;    (* half of 0.1 L per pulse *)
    AGIT_START_S  : REAL := 1.0;
    PUMP_START_S  : REAL := 0.5;
    HEAT_DUTY     : REAL := 150.0;    (* L.degC/s at 100 % valve, cold contents *)
    STEAM_C       : REAL := 130.0;
    JACKET_TAU_S  : REAL := 10.0;
    WELL_TAU_S    : REAL := 3.0;
    LOSS_LPS      : REAL := 0.45;     (* heat loss coefficient, L/s *)
    HH_TRIP_L     : LREAL := 1800.0;
    HH_RESET_L    : LREAL := 1780.0;
  END_VAR
  VAR
    Clock : TON;
    LastET : TIME;
    DeltaT : TIME;
    StepAcc : TIME;
    PosA : REAL;
    PosB : REAL;
    PosOut : REAL;
    AgitAcc : REAL;
    PumpAcc : REAL;
    AgitOn : BOOL;
    PumpOn : BOOL;
    QA : REAL;
    QB : REAL;
    QOut : REAL;
    dA : LREAL;
    dB : LREAL;
    dOut : LREAL;
    VRest : LREAL;
    VNew : LREAL;
    PulseAccA : LREAL;
    PulseAccB : LREAL;
    PulseA : BOOL;
    PulseB : BOOL;
    HeatTarget : REAL;
    HeatFlow : REAL;
    VEff : REAL;
    WellC : REAL := 20.0;
    HHWet : BOOL;
    mA : REAL;
    Started : BOOL;
  END_VAR

  (* --- time since the previous call (IEC has no system clock function) --- *)
  Clock(IN := TRUE, PT := T#24h);
  DeltaT := SUB_TIME(Clock.ET, LastET);
  LastET := Clock.ET;
  IF Clock.Q THEN                 (* re-arm once a day *)
    Clock(IN := FALSE);
    LastET := T#0s;
  END_IF;
  IF NOT Started THEN
    Started := TRUE;
    WellC := TempC;
  END_IF;

  IF PowerOK THEN
    HeatValvePct := LIMIT(0.0, INT_TO_REAL(HeatValveRaw) * 100.0 / 27648.0, 100.0);
  ELSE
    HeatValvePct := 0.0;
  END_IF;

  StepAcc := ADD_TIME(StepAcc, DeltaT);
  WHILE StepAcc >= STEP_TIME DO
    StepAcc := SUB_TIME(StepAcc, STEP_TIME);

    (* --- valves: 2 s stroke, spring return --- *)
    IF InletA AND PowerOK THEN
      PosA := MIN(1.0, PosA + STEP_S / STROKE_S);
    ELSE
      PosA := MAX(0.0, PosA - STEP_S / STROKE_S);
    END_IF;
    IF InletB AND PowerOK THEN
      PosB := MIN(1.0, PosB + STEP_S / STROKE_S);
    ELSE
      PosB := MAX(0.0, PosB - STEP_S / STROKE_S);
    END_IF;
    IF Outlet AND PowerOK THEN
      PosOut := MIN(1.0, PosOut + STEP_S / STROKE_S);
    ELSE
      PosOut := MAX(0.0, PosOut - STEP_S / STROKE_S);
    END_IF;

    (* --- motors and their running feedback --- *)
    IF Agitator AND PowerOK AND NOT AgitatorFail THEN
      AgitAcc := MIN(AgitAcc + STEP_S, AGIT_START_S);
    ELSE
      AgitAcc := 0.0;
    END_IF;
    AgitOn := AgitAcc >= AGIT_START_S;
    IF Pump AND PowerOK AND NOT PumpFail THEN
      PumpAcc := MIN(PumpAcc + STEP_S, PUMP_START_S);
    ELSE
      PumpAcc := 0.0;
    END_IF;
    PumpOn := PumpAcc >= PUMP_START_S;

    (* --- flows, L/s, and volumes for this step --- *)
    QA := FLOW_A_LPS * PosA * LIMIT(0.0, FlowFactorA, 2.0);
    QB := FLOW_B_LPS * PosB * LIMIT(0.0, FlowFactorB, 2.0);
    IF PumpOn THEN
      QOut := PUMP_LPS * PosOut * LIMIT(0.0, LREAL_TO_REAL(VolumeL) / 10.0, 1.0);
    ELSE
      QOut := 0.0;
    END_IF;
    dA := REAL_TO_LREAL(QA * STEP_S);
    dB := REAL_TO_LREAL(QB * STEP_S);
    dOut := MIN(REAL_TO_LREAL(QOut * STEP_S), MAX(VolumeL, 0.0));

    (* --- mass balance; feeds enter at ambient temperature --- *)
    VRest := VolumeL - dOut;
    VNew := VRest + dA + dB;
    IF VNew > 0.001 THEN
      TempC := LREAL_TO_REAL((REAL_TO_LREAL(TempC) * VRest
                              + REAL_TO_LREAL(AMBIENT_C) * (dA + dB)) / VNew);
    END_IF;
    VolumeL := LIMIT(0.0, VNew, REAL_TO_LREAL(VESSEL_L));  (* full = overflow line *)
    DeliveredA := DeliveredA + dA;
    DeliveredB := DeliveredB + dB;
    DrainedL := DrainedL + dOut;

    (* --- flow meter pulses: toggle every half pulse volume --- *)
    PulseAccA := PulseAccA + dA;
    IF PulseAccA >= HALF_PULSE_A THEN
      PulseAccA := PulseAccA - HALF_PULSE_A;
      PulseA := NOT PulseA;
    END_IF;
    PulseAccB := PulseAccB + dB;
    IF PulseAccB >= HALF_PULSE_B THEN
      PulseAccB := PulseAccB - HALF_PULSE_B;
      PulseB := NOT PulseB;
    END_IF;

    (* --- heating: steam duty through the jacket lag --- *)
    IF HeatFail THEN
      HeatTarget := 0.0;
    ELSE
      HeatTarget := HEAT_DUTY * HeatValvePct / 100.0
                    * MAX(0.0, (STEAM_C - TempC) / (STEAM_C - AMBIENT_C));
      IF NOT AgitOn THEN
        HeatTarget := HeatTarget * 0.3;
      END_IF;
    END_IF;
    HeatFlow := HeatFlow + (HeatTarget - HeatFlow) * STEP_S / JACKET_TAU_S;
    VEff := MAX(LREAL_TO_REAL(VolumeL), 50.0);
    TempC := TempC + (HeatFlow - LOSS_LPS * (TempC - AMBIENT_C)) / VEff * STEP_S;
    WellC := WellC + (TempC - WellC) * STEP_S / WELL_TAU_S;

    (* --- observers --- *)
    IF AgitOn AND VolumeL < 150.0 THEN
      AgitatorDryS := AgitatorDryS + STEP_S;
    END_IF;
    IF HeatValvePct > 1.0 AND (NOT AgitOn OR VolumeL < 200.0) THEN
      HeatNoAgitS := HeatNoAgitS + STEP_S;
    END_IF;
    IF PumpOn AND PosOut < 0.99 THEN
      DeadheadS := DeadheadS + STEP_S;
    END_IF;
    MaxVolumeL := MAX(MaxVolumeL, LREAL_TO_REAL(VolumeL));
    MaxTempC := MAX(MaxTempC, TempC);
  END_WHILE;

  (* --- high-high level switch, NC: opens on high level or a broken wire --- *)
  IF VolumeL >= HH_TRIP_L THEN
    HHWet := TRUE;
  ELSIF VolumeL <= HH_RESET_L THEN
    HHWet := FALSE;
  END_IF;
  LevelHH_NC := NOT HHWet AND NOT HHWireBreak;

  (* --- transmitters and analog input card --- *)
  mA := LIMIT(3.8, 4.0 + 16.0 * LREAL_TO_REAL(VolumeL) / VESSEL_L, 20.5);
  IF LtForce THEN
    mA := LtForcemA;
  END_IF;
  LevelRaw := REAL_TO_INT(LIMIT(-4864.0, (mA - 4.0) * 1728.0, 32511.0));
  mA := LIMIT(3.8, 4.0 + 16.0 * WellC / 150.0, 20.5);
  IF TtForce THEN
    mA := TtForcemA;
  END_IF;
  TempRaw := REAL_TO_INT(LIMIT(-4864.0, (mA - 4.0) * 1728.0, 32511.0));

  (* --- outputs --- *)
  FlowPulseA := PulseA;
  FlowPulseB := PulseB;
  AgitatorRunning := AgitOn;
  PumpRunning := PumpOn;
END_FUNCTION_BLOCK

(* =====================================================================
   SOLUTION FUNCTIONS AND FUNCTION BLOCKS
   ===================================================================== *)

FUNCTION F_RecipeValid : BOOL
  (* TRUE when a recipe can be run in this vessel. *)
  VAR_INPUT
    R : ST_Recipe;
    C : ST_BatchCfg;
  END_VAR
  F_RecipeValid := (R.QtyA > 0.0) AND (R.QtyB >= 0.0)
                   AND (R.QtyA + R.QtyB >= C.MinBatchL)
                   AND (R.QtyA + R.QtyB <= C.MaxBatchL)
                   AND (R.TempSP >= C.MinTempSP) AND (R.TempSP <= C.MaxTempSP)
                   AND (R.MixTime >= T#0s) AND (R.HoldTime >= T#0s);
END_FUNCTION

FUNCTION_BLOCK FB_CycleTime
  (* Time since the previous call, as TIME and as REAL seconds. Measuring
     it (instead of assuming the task interval) keeps timers, totals and
     the PID right if the task interval is ever changed. *)
  VAR_OUTPUT
    DeltaT  : TIME;
    DeltaS : REAL;
  END_VAR
  VAR
    Clock  : TON;
    LastET : TIME;
  END_VAR
  Clock(IN := TRUE, PT := T#24h);
  DeltaT := SUB_TIME(Clock.ET, LastET);
  LastET := Clock.ET;
  IF Clock.Q THEN                  (* re-arm once a day *)
    Clock(IN := FALSE);
    LastET := T#0s;
  END_IF;
  (* TIME_TO_REAL gives seconds in MATIEC but ms in CODESYS: the ratio
     is right on both (Module 15). *)
  DeltaS := TIME_TO_REAL(DeltaT) / TIME_TO_REAL(T#1s);
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_AnalogIn
  (* 4-20 mA analog input (Module 14). Card: 4 mA = 0, 20 mA = 27648. *)
  VAR_INPUT
    Raw        : INT;
    EuMin      : REAL;             (* engineering value at 4 mA *)
    EuMax      : REAL := 100.0;    (* engineering value at 20 mA *)
    FilterTime : TIME;             (* first-order filter; T#0s = none *)
    FaultDelay : TIME := T#2s;     (* NE43 failure must persist this long *)
    DeltaS        : REAL;             (* seconds since the previous call *)
  END_VAR
  VAR_OUTPUT
    Value : REAL;                  (* holds the last good value while the signal is bad *)
    Good  : BOOL;                  (* current inside the NE43 limits now *)
    Fault : BOOL;                  (* NE43 failure confirmed (not latched) *)
  END_VAR
  VAR
    mA       : REAL;
    Scaled   : REAL;
    Tf       : REAL;
    Ready    : BOOL;
    BadTimer : TON;
  END_VAR
  mA := 4.0 + INT_TO_REAL(Raw) / 1728.0;
  Good := (mA > 3.6) AND (mA < 21.0);
  BadTimer(IN := NOT Good, PT := FaultDelay);
  Fault := BadTimer.Q;
  IF Fault THEN
    Ready := FALSE;                (* restart the filter from the live value later *)
  END_IF;
  IF Good THEN
    Scaled := EuMin + (LIMIT(4.0, mA, 20.0) - 4.0) / 16.0 * (EuMax - EuMin);
    Tf := TIME_TO_REAL(FilterTime) / TIME_TO_REAL(T#1s);
    IF Ready AND Tf > 0.0 THEN
      Value := Value + DeltaS / (Tf + DeltaS) * (Scaled - Value);
    ELSE
      Value := Scaled;
    END_IF;
    Ready := TRUE;
  END_IF;
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_FlowTotal
  (* Flow-meter pulse totaliser (Modules 06, 08, 09). The pulses are
     counted in a DINT, which is exact; a REAL running sum of 0.1 L steps
     would drift. Reset restarts the total. *)
  VAR_INPUT
    Pulse          : BOOL;
    Reset          : BOOL;
    LitresPerPulse : REAL;
  END_VAR
  VAR_OUTPUT
    Litres   : REAL;
    NewPulse : BOOL;               (* TRUE for one scan per pulse *)
  END_VAR
  VAR
    Edge  : R_TRIG;
    Count : DINT;
  END_VAR
  Edge(CLK := Pulse);
  NewPulse := Edge.Q;
  IF Reset THEN
    Count := 0;
  ELSIF NewPulse THEN
    Count := Count + 1;
  END_IF;
  Litres := DINT_TO_REAL(Count) * LitresPerPulse;
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_Charge
  (* One dosing phase. The inlet closes when the metered total reaches
     Target - Preact: the preact is the volume still "in flight" while the
     valve strokes shut, so the final total lands on the target. The phase
     is Done once the valve has been shut for SettleTime, so that the
     in-flight liquid has been counted.
     Fault = no meter pulse for NoFlowTime with the valve open, or the
     phase has run for MaxTime. Run FALSE (held) closes the valve and
     restarts both watchdogs; the total is kept, so a restart doses only
     the remainder. *)
  VAR_INPUT
    Run        : BOOL;
    Permit     : BOOL;             (* interlocks healthy *)
    Target     : REAL;             (* L *)
    Preact     : REAL;             (* L *)
    Total      : REAL;             (* L counted so far this batch *)
    NewPulse   : BOOL;
    SettleTime : TIME;
    NoFlowTime : TIME;
    MaxTime    : TIME;
  END_VAR
  VAR_OUTPUT
    Valve : BOOL;
    Done  : BOOL;
    Fault : BOOL;
  END_VAR
  VAR
    Reached   : BOOL;
    SettleTmr : TON;
    NoFlowTmr : TON;
    PhaseTmr  : TON;
  END_VAR
  Reached := Total >= Target - Preact;
  Valve := Run AND Permit AND NOT Reached;
  SettleTmr(IN := Run AND Reached, PT := SettleTime);
  Done := SettleTmr.Q;
  (* each pulse drops IN for one scan, which restarts the no-flow timer *)
  NoFlowTmr(IN := Valve AND NOT NewPulse, PT := NoFlowTime);
  PhaseTmr(IN := Run, PT := MaxTime);
  Fault := NoFlowTmr.Q OR (PhaseTmr.Q AND NOT Done);
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_Motor
  (* Motor with running-feedback supervision (Module 11). A disagreement
     between command and feedback lasting FbTime latches Fault, which
     drops the command. Reset clears the fault but never starts the motor
     by itself: the caller decides whether Request is still TRUE. *)
  VAR_INPUT
    Request  : BOOL;
    Feedback : BOOL;
    FbTime   : TIME := T#3s;
    Reset    : BOOL;
  END_VAR
  VAR_OUTPUT
    Cmd     : BOOL;
    Running : BOOL;                (* proven running: commanded AND feedback *)
    Fault   : BOOL;
  END_VAR
  VAR
    Mismatch : TON;
  END_VAR
  Mismatch(IN := Cmd XOR Feedback, PT := FbTime);
  IF Mismatch.Q THEN
    Fault := TRUE;
  ELSIF Reset AND NOT Feedback THEN
    Fault := FALSE;
  END_IF;
  Cmd := Request AND NOT Fault;
  Running := Cmd AND Feedback;
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_PID
  (* Ideal-form PID, reverse acting (Module 15): P on error, D on PV with a
     filter, conditional-integration anti-windup.
     Enable FALSE: Out = OutMin and the integral part is frozen, so a
     restart after a hold carries on from where it stopped.
     ResetI: clears the integral part (a "cold start"). The heating phase
     starts cold on purpose: Out then begins at Kc * error, which is the
     full-power heat-up you want, not a slow bumpless climb from 0 %. *)
  VAR_INPUT
    SP     : REAL;
    PV     : REAL;
    Kc     : REAL := 1.0;          (* % per engineering unit *)
    Ti     : REAL;                 (* s; 0 = no integral action *)
    Td     : REAL;                 (* s; 0 = no derivative action *)
    OutMin : REAL := 0.0;
    OutMax : REAL := 100.0;
    Enable : BOOL;
    ResetI : BOOL;
    DeltaS    : REAL;                 (* seconds since the previous call *)
  END_VAR
  VAR_OUTPUT
    Out : REAL;
  END_VAR
  VAR
    Err    : REAL;
    PTerm  : REAL;
    ITerm  : REAL;
    DTerm  : REAL;
    Tf     : REAL;
    U      : REAL;
    Inc    : REAL;
    PVLast : REAL;
    Primed : BOOL;
  END_VAR
  IF ResetI THEN
    ITerm := 0.0;
    DTerm := 0.0;
  END_IF;
  IF NOT Primed OR NOT Enable THEN
    PVLast := PV;                  (* no derivative kick on (re)start *)
    Primed := TRUE;
  END_IF;
  Err := SP - PV;
  PTerm := Kc * Err;
  IF Td > 0.0 THEN
    Tf := Td / 10.0;
    DTerm := (Tf * DTerm - Kc * Td * (PV - PVLast)) / (Tf + DeltaS);
  ELSE
    DTerm := 0.0;
  END_IF;
  PVLast := PV;
  IF Enable THEN
    U := PTerm + ITerm + DTerm;
    IF Ti > 0.0 THEN
      Inc := Kc * DeltaS / Ti * Err;
      IF NOT ((U >= OutMax AND Inc > 0.0) OR (U <= OutMin AND Inc < 0.0)) THEN
        ITerm := ITerm + Inc;
      END_IF;
    END_IF;
    Out := LIMIT(OutMin, PTerm + ITerm + DTerm, OutMax);
  ELSE
    Out := OutMin;
  END_IF;
END_FUNCTION_BLOCK

PROGRAM BatchMixer
  VAR (* digital inputs *)
    FlowPulseA      AT %IX0.0 : BOOL;  (* FT-201 ingredient A meter: one pulse per 0.5 L *)
    FlowPulseB      AT %IX0.1 : BOOL;  (* FT-202 ingredient B meter: one pulse per 0.1 L *)
    AgitatorRunning AT %IX0.2 : BOOL;  (* M-201 agitator running feedback (contactor aux) *)
    PumpRunning     AT %IX0.3 : BOOL;  (* P-204 drain pump running feedback *)
    LevelHH_NC      AT %IX0.4 : BOOL;  (* LSHH-201, NC: FALSE = high-high level or wire broken *)
    EStopOK_NC      AT %IX0.5 : BOOL;  (* safety relay status, NC: FALSE = e-stop operated *)
  END_VAR
  VAR (* analog inputs *)
    LevelRaw        AT %IW0 : INT;     (* LT-201 level 0-100 % (0-2000 L), 4 mA = 0, 20 mA = 27648 *)
    TempRaw         AT %IW1 : INT;     (* TT-203 temperature 0-150 degC, same card range *)
  END_VAR
  VAR (* digital outputs *)
    InletAValve     AT %QX0.0 : BOOL;  (* XV-201 ingredient A inlet valve, TRUE = open *)
    InletBValve     AT %QX0.1 : BOOL;  (* XV-202 ingredient B inlet valve *)
    OutletValve     AT %QX0.2 : BOOL;  (* XV-204 outlet valve *)
    AgitatorRun     AT %QX0.3 : BOOL;  (* M-201 agitator contactor *)
    PumpRun         AT %QX0.4 : BOOL;  (* P-204 drain pump contactor *)
    AlarmHorn       AT %QX0.5 : BOOL;  (* ON while any alarm is unacknowledged *)
    AlarmLamp       AT %QX0.6 : BOOL;  (* ON while any alarm is active *)
  END_VAR
  VAR (* analog output *)
    HeatValveRaw    AT %QW0 : INT;     (* TV-203 steam valve, 0 = closed .. 27648 = fully open *)
  END_VAR
  VAR RETAIN (* recipes and configuration survive a power cycle *)
    Recipes : ARRAY[1..5] OF ST_Recipe := [
      (Name := 'Floor cleaner', QtyA := 400.0, QtyB := 50.0, TempSP := 60.0,
       MixTime := T#60s, HoldTime := T#90s),
      (Name := 'Degreaser', QtyA := 250.0, QtyB := 120.0, TempSP := 45.0,
       MixTime := T#120s, HoldTime := T#30s),
      (Name := 'Cold blend', QtyA := 260.0, QtyB := 40.0, TempSP := 20.0,
       MixTime := T#30s, HoldTime := T#0s)];   (* recipes 4 and 5 are empty *)
    Cfg : ST_BatchCfg;
  END_VAR
  VAR (* given *)
    Hmi : ST_BatchHmi;                 (* HMI interface *)
    Report : ST_BatchReport;           (* last completed batch *)
    Sim : FB_PlantSim;                 (* plant simulation *)
    SimEnable : BOOL := TRUE;          (* set FALSE (or delete section 1) on a real PLC *)
  END_VAR
  VAR (* solution: function block instances *)
    Cycle        : FB_CycleTime;
    LT201        : FB_AnalogIn;    (* level, % *)
    TT203        : FB_AnalogIn;    (* temperature, degC *)
    FQ201        : FB_FlowTotal;   (* ingredient A total, L *)
    FQ202        : FB_FlowTotal;   (* ingredient B total, L *)
    ChargeA      : FB_Charge;
    ChargeB      : FB_Charge;
    Agitator     : FB_Motor;       (* M-201 *)
    Pump         : FB_Motor;       (* P-204 *)
    TIC203       : FB_PID;         (* jacket temperature controller *)
    HeatWatchdog : TON;
    OutletLead   : TON;            (* XV-204 open before P-204 starts *)
    OutletLag    : TOF;            (* XV-204 stays open after P-204 stops *)
    EmptyTimer   : TON;            (* pump run-on after "empty" *)
  END_VAR
  VAR (* solution: commands taken from the HMI this scan *)
    DoStart   : BOOL;
    DoHold    : BOOL;
    DoRestart : BOOL;
    DoAbort   : BOOL;
    DoReset   : BOOL;
    DoAck     : BOOL;
    DoDrain   : BOOL;
  END_VAR
  VAR (* solution: batch data *)
    State       : E_BatchState := Idle;
    Phase       : E_BatchPhase := PhaseNone;
    Active      : ST_Recipe;       (* control recipe: copied at Start *)
    ActiveNo    : INT;
    ManualDrain : BOOL;            (* an "empty vessel" run, not a batch *)
    NewBatch    : BOOL;            (* one scan: reset the totals *)
    PidReset    : BOOL;            (* one scan: cold-start TIC-203 *)
    BatchTime   : TIME;
    MaxTemp     : REAL;
    MixAcc      : TIME;            (* agitated time in PhaseMix (paused while held) *)
    HoldAcc     : TIME;            (* time at temperature in PhaseMix *)
    DrainDone   : BOOL;
    DrainReq    : BOOL;
    OutletCmd   : BOOL;
    AgitLevelOK : BOOL;
    HeatPermit  : BOOL;
    LevelPct    : REAL;
    TempC       : REAL;
  END_VAR
  VAR (* solution: alarms and faults *)
    AlmActive   : WORD;
    AlmPrev     : WORD;
    AlmUnack    : WORD;
    HoldCause   : BOOL;
    TempHigh    : BOOL;
    DoseAFault  : BOOL;
    DoseBFault  : BOOL;
    HeatTimeout : BOOL;
    TtFault     : BOOL;
    LtFault     : BOOL;
  END_VAR
  VAR CONSTANT (* alarm bits in Hmi.AlmActive / Hmi.AlmUnack *)
    ALM_LEVEL_HH  : WORD := 16#0001;
    ALM_TEMP_HIGH : WORD := 16#0002;
    ALM_DOSE_A    : WORD := 16#0004;
    ALM_DOSE_B    : WORD := 16#0008;
    ALM_HEAT_TIME : WORD := 16#0010;
    ALM_AGITATOR  : WORD := 16#0020;
    ALM_PUMP      : WORD := 16#0040;
    ALM_TT_FAULT  : WORD := 16#0080;
    ALM_LT_FAULT  : WORD := 16#0100;
    ALM_ESTOP     : WORD := 16#0200;
    HOLD_MASK     : WORD := 16#01FF;  (* every alarm except the e-stop holds the batch *)
    NO_ALARMS     : WORD := 16#0000;
  END_VAR

  (* ===== 1. PLANT SIMULATION (given - do not change) ====================
     The simulation plays the part of the field: it reads last scan's
     outputs and writes this scan's input image, just as the I/O system
     would. EStopOK_NC is a real input (the test sets it); the simulation
     only uses it to cut power to the field outputs, as the safety relay
     would. On a real PLC this section is removed and nothing else changes. *)
  IF SimEnable THEN
    Sim(InletA := InletAValve, InletB := InletBValve, Outlet := OutletValve,
        Agitator := AgitatorRun, Pump := PumpRun, HeatValveRaw := HeatValveRaw,
        PowerOK := EStopOK_NC);
    FlowPulseA := Sim.FlowPulseA;
    FlowPulseB := Sim.FlowPulseB;
    AgitatorRunning := Sim.AgitatorRunning;
    PumpRunning := Sim.PumpRunning;
    LevelHH_NC := Sim.LevelHH_NC;
    LevelRaw := Sim.LevelRaw;
    TempRaw := Sim.TempRaw;
  END_IF;

  (* ===== 2. TIME BASE AND HMI COMMANDS ===================================
     Each command bit is read once and cleared at once (the HMI never
     clears them). A command therefore acts exactly once, however long
     the HMI takes to notice. *)
  Cycle();
  DoStart := Hmi.CmdStart;      Hmi.CmdStart := FALSE;
  DoHold := Hmi.CmdHold;        Hmi.CmdHold := FALSE;
  DoRestart := Hmi.CmdRestart;  Hmi.CmdRestart := FALSE;
  DoAbort := Hmi.CmdAbort;      Hmi.CmdAbort := FALSE;
  DoReset := Hmi.CmdReset;      Hmi.CmdReset := FALSE;
  DoAck := Hmi.CmdAck;          Hmi.CmdAck := FALSE;
  DoDrain := Hmi.CmdDrain;      Hmi.CmdDrain := FALSE;

  (* ===== 3. MEASUREMENTS ================================================= *)
  LT201(Raw := LevelRaw, EuMin := 0.0, EuMax := 100.0, FilterTime := T#1s,
        FaultDelay := Cfg.XmtrFaultDelay, DeltaS := Cycle.DeltaS);
  TT203(Raw := TempRaw, EuMin := 0.0, EuMax := 150.0, FilterTime := T#0s,
        FaultDelay := Cfg.XmtrFaultDelay, DeltaS := Cycle.DeltaS);
  LevelPct := LT201.Value;
  TempC := TT203.Value;

  (* ===== 4. ALARMS AND FAULTS ============================================
     Faults latch and need a Reset once their cause has gone. Process
     conditions (high-high level, high temperature, e-stop) clear by
     themselves. Every alarm, latched or not, needs an acknowledgement. *)
  IF TT203.Fault THEN
    TtFault := TRUE;
  ELSIF DoReset AND TT203.Good THEN
    TtFault := FALSE;
  END_IF;
  IF LT201.Fault THEN
    LtFault := TRUE;
  ELSIF DoReset AND LT201.Good THEN
    LtFault := FALSE;
  END_IF;
  IF TempC >= Cfg.TempHighLimit THEN
    TempHigh := TRUE;
  ELSIF TempC < Cfg.TempHighLimit - 2.0 THEN      (* 2 degC deadband *)
    TempHigh := FALSE;
  END_IF;
  IF ChargeA.Fault THEN
    DoseAFault := TRUE;
  ELSIF DoReset THEN
    DoseAFault := FALSE;
  END_IF;
  IF ChargeB.Fault THEN
    DoseBFault := TRUE;
  ELSIF DoReset THEN
    DoseBFault := FALSE;
  END_IF;
  IF HeatWatchdog.Q THEN
    HeatTimeout := TRUE;
  ELSIF DoReset THEN
    HeatTimeout := FALSE;
  END_IF;
  (* The motor faults latch inside FB_Motor (reset in section 6). *)

  AlmActive := NO_ALARMS;
  IF NOT LevelHH_NC THEN AlmActive := AlmActive OR ALM_LEVEL_HH; END_IF;
  IF TempHigh THEN AlmActive := AlmActive OR ALM_TEMP_HIGH; END_IF;
  IF DoseAFault THEN AlmActive := AlmActive OR ALM_DOSE_A; END_IF;
  IF DoseBFault THEN AlmActive := AlmActive OR ALM_DOSE_B; END_IF;
  IF HeatTimeout THEN AlmActive := AlmActive OR ALM_HEAT_TIME; END_IF;
  IF Agitator.Fault THEN AlmActive := AlmActive OR ALM_AGITATOR; END_IF;
  IF Pump.Fault THEN AlmActive := AlmActive OR ALM_PUMP; END_IF;
  IF TtFault THEN AlmActive := AlmActive OR ALM_TT_FAULT; END_IF;
  IF LtFault THEN AlmActive := AlmActive OR ALM_LT_FAULT; END_IF;
  IF NOT EStopOK_NC THEN AlmActive := AlmActive OR ALM_ESTOP; END_IF;

  (* Acknowledge first, then add new alarms: an alarm that appears in the
     same scan as an Ack is still reported as unacknowledged. *)
  IF DoAck THEN
    AlmUnack := NO_ALARMS;
  END_IF;
  AlmUnack := AlmUnack OR (AlmActive AND NOT AlmPrev);
  AlmPrev := AlmActive;
  HoldCause := (AlmActive AND HOLD_MASK) <> NO_ALARMS;

  (* ===== 5. BATCH STATE MACHINE AND PHASE SEQUENCE ======================= *)
  IF DoStart AND State <> Idle THEN
    Hmi.RejectCode := 5;                          (* Start only from Idle *)
  END_IF;

  CASE State OF
    Idle:
      IF DoStart THEN
        IF Hmi.RecipeNo < 1 OR Hmi.RecipeNo > 5 THEN
          Hmi.RejectCode := 1;
        ELSIF NOT F_RecipeValid(Recipes[Hmi.RecipeNo], Cfg) THEN
          Hmi.RejectCode := 2;
        ELSIF LevelPct > Cfg.EmptyLevel THEN
          Hmi.RejectCode := 3;
        ELSIF AlmActive <> NO_ALARMS THEN
          Hmi.RejectCode := 4;
        ELSE
          Hmi.RejectCode := 0;
          (* The control recipe is a COPY of the master recipe: editing
             Recipes[] on the HMI cannot change a batch in progress. *)
          Active := Recipes[Hmi.RecipeNo];
          ActiveNo := Hmi.RecipeNo;
          ManualDrain := FALSE;
          NewBatch := TRUE;
          BatchTime := T#0s;
          MaxTemp := TempC;
          Phase := PhaseChargeA;
          State := Running;
        END_IF;
      ELSIF DoDrain AND AlmActive = NO_ALARMS AND LevelPct > Cfg.EmptyLevel THEN
        ManualDrain := TRUE;                      (* empty the vessel, no batch *)
        ActiveNo := 0;
        DrainDone := FALSE;
        Phase := PhaseDrain;
        State := Running;
      END_IF;

    Running:
      IF DoAbort THEN
        State := Aborting;
      ELSIF DoHold OR HoldCause THEN
        State := Holding;
      ELSE
        CASE Phase OF
          PhaseChargeA:
            IF ChargeA.Done THEN
              IF Active.QtyB > 0.0 THEN
                Phase := PhaseChargeB;
              ELSE
                Phase := PhaseHeat;               (* no B in this recipe *)
                PidReset := TRUE;
              END_IF;
            END_IF;
          PhaseChargeB:
            IF ChargeB.Done THEN
              Phase := PhaseHeat;
              PidReset := TRUE;
            END_IF;
          PhaseHeat:
            IF TempC >= Active.TempSP - Cfg.TempBand THEN
              Phase := PhaseMix;
              MixAcc := T#0s;
              HoldAcc := T#0s;
            END_IF;
          PhaseMix:
            IF MixAcc >= Active.MixTime AND HoldAcc >= Active.HoldTime THEN
              Phase := PhaseDrain;
              DrainDone := FALSE;
            END_IF;
          PhaseDrain:
            IF DrainDone AND NOT OutletCmd THEN
              IF ManualDrain THEN
                ManualDrain := FALSE;
                Phase := PhaseNone;
                State := Idle;
              ELSE
                Report.BatchCount := Report.BatchCount + 1;
                Report.RecipeNo := ActiveNo;
                Report.RecipeName := Active.Name;
                Report.ActualA := FQ201.Litres;
                Report.ActualB := FQ202.Litres;
                Report.BatchTime := BatchTime;
                Report.MaxTemp := MaxTemp;
                Phase := PhaseNone;
                State := Complete;
              END_IF;
            END_IF;
        END_CASE;
      END_IF;

    Holding:                                      (* wait for the drain to stop *)
      IF DoAbort THEN
        State := Aborting;
      ELSIF NOT OutletCmd AND NOT Pump.Cmd THEN
        State := Held;
      END_IF;

    Held:
      IF DoAbort THEN
        State := Aborting;
      ELSIF DoRestart AND NOT HoldCause THEN      (* a restart needs a healthy plant *)
        State := Restarting;
      END_IF;

    Restarting:
      IF DoAbort THEN
        State := Aborting;
      ELSIF DoHold OR HoldCause THEN
        State := Holding;
      ELSE
        State := Running;                         (* resume the held phase *)
      END_IF;

    Aborting:
      IF NOT OutletCmd AND NOT Pump.Cmd AND NOT Agitator.Cmd THEN
        State := Aborted;
      END_IF;

    Aborted, Complete:
      IF DoReset THEN
        ActiveNo := 0;
        Phase := PhaseNone;
        State := Idle;
      END_IF;
  END_CASE;

  (* E-stop: the safety relay has already removed output power. The batch
     is aborted at once; it cannot be resumed. *)
  IF NOT EStopOK_NC AND State <> Idle AND State <> Aborted AND State <> Complete THEN
    ManualDrain := FALSE;
    State := Aborted;
  END_IF;

  (* ===== 6. EQUIPMENT CONTROL ============================================ *)
  (* --- flow totals (reset when a batch starts) --- *)
  FQ201(Pulse := FlowPulseA, Reset := NewBatch, LitresPerPulse := Cfg.LitresPerPulseA);
  FQ202(Pulse := FlowPulseB, Reset := NewBatch, LitresPerPulse := Cfg.LitresPerPulseB);
  NewBatch := FALSE;

  (* --- dosing; LSHH-201 closes both inlets directly, whatever the state --- *)
  ChargeA(Run := (State = Running) AND (Phase = PhaseChargeA), Permit := LevelHH_NC,
          Target := Active.QtyA, Preact := Cfg.PreactA, Total := FQ201.Litres,
          NewPulse := FQ201.NewPulse, SettleTime := Cfg.SettleTime,
          NoFlowTime := Cfg.NoFlowTime, MaxTime := Cfg.MaxChargeTime);
  ChargeB(Run := (State = Running) AND (Phase = PhaseChargeB), Permit := LevelHH_NC,
          Target := Active.QtyB, Preact := Cfg.PreactB, Total := FQ202.Litres,
          NewPulse := FQ202.NewPulse, SettleTime := Cfg.SettleTime,
          NoFlowTime := Cfg.NoFlowTime, MaxTime := Cfg.MaxChargeTime);

  (* --- agitator M-201: only with the impeller covered (hysteresis). While
     Holding/Held it keeps running if it is running, but it is never
     started there: a fault reset must not start equipment. --- *)
  IF LevelPct >= Cfg.AgitStartLevel THEN
    AgitLevelOK := TRUE;
  ELSIF LevelPct < Cfg.AgitStopLevel THEN
    AgitLevelOK := FALSE;
  END_IF;
  Agitator(Request := AgitLevelOK AND EStopOK_NC
                      AND ((State = Running) OR (State = Restarting)
                           OR (((State = Holding) OR (State = Held)) AND Agitator.Cmd)),
           Feedback := AgitatorRunning, FbTime := Cfg.FeedbackTime, Reset := DoReset);

  (* --- TIC-203: steam only while heating or mixing, with the agitator
     proven running, the jacket covered and a healthy, normal temperature --- *)
  HeatPermit := (State = Running) AND ((Phase = PhaseHeat) OR (Phase = PhaseMix))
                AND Agitator.Running AND (LevelPct >= Cfg.HeatMinLevel)
                AND NOT TempHigh AND TT203.Good AND NOT TtFault AND EStopOK_NC;
  TIC203(SP := Active.TempSP, PV := TempC, Kc := Cfg.TempKc, Ti := Cfg.TempTi,
         Td := Cfg.TempTd, Enable := HeatPermit, ResetI := PidReset, DeltaS := Cycle.DeltaS);
  PidReset := FALSE;
  HeatWatchdog(IN := (State = Running) AND (Phase = PhaseHeat), PT := Cfg.MaxHeatTime);

  (* --- mix/hold timers: retentive (they pause while held, they do not
     restart); the hold timer counts only while at temperature --- *)
  IF (State = Running) AND (Phase = PhaseMix) THEN
    MixAcc := ADD_TIME(MixAcc, Cycle.DeltaT);
    IF ABS(TempC - Active.TempSP) <= Cfg.TempBand THEN
      HoldAcc := ADD_TIME(HoldAcc, Cycle.DeltaT);
    END_IF;
  END_IF;

  (* --- drain: XV-204 opens, then P-204 starts; P-204 stops, then XV-204
     closes. The pump never runs against a closed valve. --- *)
  DrainReq := (State = Running) AND (Phase = PhaseDrain) AND NOT DrainDone;
  OutletLead(IN := DrainReq, PT := Cfg.ValveLeadTime);
  Pump(Request := DrainReq AND OutletLead.Q AND EStopOK_NC,
       Feedback := PumpRunning, FbTime := Cfg.FeedbackTime, Reset := DoReset);
  OutletLag(IN := Pump.Cmd, PT := Cfg.ValveLeadTime);
  OutletCmd := (DrainReq OR OutletLag.Q) AND EStopOK_NC;
  EmptyTimer(IN := DrainReq AND Pump.Running AND (LevelPct <= Cfg.EmptyLevel),
             PT := Cfg.DrainRunOn);
  IF EmptyTimer.Q THEN
    DrainDone := TRUE;
  END_IF;

  (* --- batch record --- *)
  IF NOT ManualDrain AND ((State = Running) OR (State = Holding) OR (State = Held)
                          OR (State = Restarting) OR (State = Aborting)) THEN
    BatchTime := ADD_TIME(BatchTime, Cycle.DeltaT);
    MaxTemp := MAX(MaxTemp, TempC);
  END_IF;

  (* ===== 7. OUTPUTS AND HMI STATUS =======================================
     Each output is written here and nowhere else. EStopOK_NC is in every
     output as well: the PLC agrees with the safety relay, so nothing
     re-energises when the relay is reset. *)
  InletAValve := ChargeA.Valve AND LevelHH_NC AND EStopOK_NC;
  InletBValve := ChargeB.Valve AND LevelHH_NC AND EStopOK_NC;
  OutletValve := OutletCmd;
  AgitatorRun := Agitator.Cmd AND EStopOK_NC;
  PumpRun := Pump.Cmd AND EStopOK_NC;
  IF EStopOK_NC THEN
    HeatValveRaw := REAL_TO_INT(TIC203.Out * 276.48);   (* 0..100 % -> 0..27648 *)
  ELSE
    HeatValveRaw := 0;
  END_IF;
  AlarmHorn := AlmUnack <> NO_ALARMS;
  AlarmLamp := AlmActive <> NO_ALARMS;

  Hmi.State := State;
  Hmi.Phase := Phase;
  Hmi.ActiveRecipe := ActiveNo;
  Hmi.LevelPct := LevelPct;
  Hmi.TempC := TempC;
  Hmi.TotalA := FQ201.Litres;
  Hmi.TotalB := FQ202.Litres;
  Hmi.AlmActive := AlmActive;
  Hmi.AlmUnack := AlmUnack;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : BatchMixer;
  END_RESOURCE
END_CONFIGURATION
