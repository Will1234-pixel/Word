(* Capstone 24-2: Batch mixing plant (mixing vessel T-201).
   Module 24 (Capstone projects). STARTER - the interface, the recipe,
   configuration, HMI and report data types, and the plant simulation are
   done for you. Write the control logic where it says TODO (add your own
   functions, function blocks and variables as you wish), then run:
     python3 tools/plctest.py 24-capstone-projects/labs/starter/24-2-batch-mixing-plant.st
   Brief: 24-capstone-projects/24-2-batch-mixing-plant.md *)

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

  (* ===== 2. YOUR CONTROL LOGIC ==========================================
     TODO: replace the placeholder lines below. A suggested layout (see
     "Suggested architecture" in the brief):
       2. time base; HMI commands (latch them, then clear the Cmd bits)
       3. measurements: LT-201 and TT-203 scaling, NE43 checks, flow totals
       4. alarms and faults: detect, latch, reset, acknowledge
       5. batch state machine (Idle/Running/Holding/Held/...) and the
          phase sequence (ChargeA -> ChargeB -> Heat -> Mix -> Drain)
       6. equipment control: inlet dosing, agitator, TIC-203 PID and
          steam valve, drain valve and pump, all with their interlocks
       7. outputs, e-stop override, HMI status and the batch report
     Keep the names in the brief's interface tables: the acceptance test
     uses them. *)
  InletAValve := FALSE;
  InletBValve := FALSE;
  OutletValve := FALSE;
  AgitatorRun := FALSE;
  PumpRun := FALSE;
  HeatValveRaw := 0;
  AlarmHorn := FALSE;
  AlarmLamp := FALSE;
  Hmi.State := Idle;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : BatchMixer;
  END_RESOURCE
END_CONFIGURATION
