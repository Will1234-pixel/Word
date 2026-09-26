(* Lab 21-2: ISA-88 style dosing phase for reactor R-201.
   Module 21 (Architecture and standards). STARTER - the types, the code
   translation functions, both control modules and all declarations are
   done for you. Write the phase logic where it says TODO, then run:
     python3 tools/plctest.py 21-architecture-and-standards/labs/starter/21-2-dosing-phase.st

   Layers, bottom to top:
     - Control modules (given): FB_OnOffValve for XV-201 and FB_Totaliser for
       FQ-201. They know nothing about batches. The valve's high-level
       interlock lives here, so it protects whoever owns the valve.
     - Equipment phase (this program, your job): the Dose phase of the R-201 dosing
       equipment module. It owns XV-201 and FQ-201, runs the ISA-88 state
       model and talks to the batch manager / HMI through a command/state
       interface: PhaseCmd in, PhaseState, DosedTotal_L and FailureCode out.

   Training exercise only. Overfill protection on a real reactor is a
   safety function and belongs in an independent, safety-rated system
   (Module 20), not in batch phase logic. *)

TYPE
  (* Phase states used in this lab: the ISA-88 example model without
     Pausing/Paused. Codes on the interface come from F_PhaseStateCode. *)
  E_PhaseState : (Idle, Running, Complete, Holding, Held, Restarting,
                  Stopping, Stopped, Aborting, Aborted);
  E_PhaseCmd : (PcNone, PcStart, PcHold, PcRestart, PcStop, PcAbort, PcReset,
                PcInvalid);
END_TYPE

FUNCTION F_PhaseCmdFromCode : E_PhaseCmd
  (* PhaseCmd register -> command. 0 = no command. *)
  VAR_INPUT
    Code : INT;
  END_VAR
  CASE Code OF
    0: F_PhaseCmdFromCode := PcNone;
    1: F_PhaseCmdFromCode := PcStart;
    2: F_PhaseCmdFromCode := PcHold;
    3: F_PhaseCmdFromCode := PcRestart;
    4: F_PhaseCmdFromCode := PcStop;
    5: F_PhaseCmdFromCode := PcAbort;
    6: F_PhaseCmdFromCode := PcReset;
  ELSE
    F_PhaseCmdFromCode := PcInvalid;
  END_CASE;
END_FUNCTION

FUNCTION F_PhaseStateCode : INT
  (* State -> PhaseState code on the interface. *)
  VAR_INPUT
    State : E_PhaseState;
  END_VAR
  F_PhaseStateCode := 0;
  CASE State OF
    Idle:       F_PhaseStateCode := 1;
    Running:    F_PhaseStateCode := 2;
    Complete:   F_PhaseStateCode := 3;
    Holding:    F_PhaseStateCode := 4;
    Held:       F_PhaseStateCode := 5;
    Restarting: F_PhaseStateCode := 6;
    Stopping:   F_PhaseStateCode := 7;
    Stopped:    F_PhaseStateCode := 8;
    Aborting:   F_PhaseStateCode := 9;
    Aborted:    F_PhaseStateCode := 10;
  END_CASE;
END_FUNCTION

FUNCTION_BLOCK FB_OnOffValve
  (* ------------------------------------------------------------------
     FB_OnOffValve - control module for a spring-return, fail-closed on/off
     valve with a closed limit switch (ZSC).

     Behaviour     Solenoid = OpenReq AND Permit. The permissive (interlock)
                   acts in every state and mode; the owner cannot override it.
                   Closed = de-energised and ZSC made.
                   Interlocked = open requested but refused by the interlock.
     Version       1.0  given with Lab 21-2
     ------------------------------------------------------------------ *)
  VAR_INPUT
    OpenReq : BOOL;      (* owner's request: TRUE = open *)
    Permit  : BOOL;      (* interlock permissive: FALSE = the valve must stay closed *)
    ZSC     : BOOL;      (* closed limit switch: TRUE = closed *)
  END_VAR
  VAR_OUTPUT
    Solenoid    : BOOL;  (* to the solenoid: TRUE = open *)
    Closed      : BOOL;  (* proved closed *)
    Interlocked : BOOL;  (* request refused by the interlock *)
  END_VAR
  Solenoid := OpenReq AND Permit;
  Closed := ZSC AND NOT Solenoid;
  Interlocked := OpenReq AND NOT Permit;
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_Totaliser
  (* ------------------------------------------------------------------
     FB_Totaliser - control module: integrates a flow rate into a total.

     Behaviour     While Run, adds Flow * CycleTime to Total on every call.
                   Flows below LowFlowCutoff (including negative values from
                   transmitter noise at zero flow) count as zero. Reset sets
                   Total to 0 and wins over Run.
     Assumptions   Called once per scan from a cyclic task whose interval is
                   CycleTime. Flow is in units per minute.
     Version       1.0  given with Lab 21-2
     ------------------------------------------------------------------ *)
  VAR_INPUT
    Flow          : REAL;           (* flow rate, units/min (here L/min) *)
    Run           : BOOL;           (* TRUE = integrate *)
    Reset         : BOOL;           (* TRUE = Total := 0 (wins over Run) *)
    LowFlowCutoff : REAL := 0.5;    (* flows below this count as zero, units/min *)
    CycleTime     : TIME := T#10ms; (* interval of the calling task *)
  END_VAR
  VAR_OUTPUT
    Total       : REAL;             (* units (here L) *)
    FlowPresent : BOOL;             (* Flow >= LowFlowCutoff *)
  END_VAR
  FlowPresent := Flow >= LowFlowCutoff;
  IF Reset THEN
    Total := 0.0;
  ELSIF Run AND FlowPresent THEN
    (* a ratio of two TIMEs is correct whether TIME_TO_REAL gives s or ms *)
    Total := Total + Flow * TIME_TO_REAL(CycleTime) / TIME_TO_REAL(T#1m);
  END_IF;
END_FUNCTION_BLOCK

PROGRAM ReactorDosing
  VAR (* physical inputs *)
    XV201_ZSC AT %IX0.0 : BOOL;   (* XV-201 closed limit switch: TRUE = valve closed *)
    LSH201_NC AT %IX0.1 : BOOL;   (* R-201 high level switch, fail-safe: TRUE = level below high *)
  END_VAR
  VAR (* physical outputs *)
    XV201_SOL AT %QX0.0 : BOOL;   (* XV-201 solenoid: TRUE = open (valve fails closed) *)
  END_VAR
  VAR (* process value from the analog input layer (Module 14) *)
    FT201_Flow_Lpm : REAL;        (* FT-201 dosing flow, L/min, already scaled *)
  END_VAR
  VAR (* phase interface: written/read by the batch manager or HMI *)
    PhaseCmd     : INT;           (* 1 Start 2 Hold 3 Restart 4 Stop 5 Abort 6 Reset; the PLC clears it to 0 *)
    PhaseState   : INT := 1;      (* 1 Idle 2 Running 3 Complete 4 Holding 5 Held 6 Restarting
                                     7 Stopping 8 Stopped 9 Aborting 10 Aborted *)
    DoseTarget_L : REAL;          (* parameter: quantity to dose, L; valid if 0 < target <= 500 *)
    DosedTotal_L : REAL;          (* report: quantity dosed in this run, L *)
    FailureCode  : INT;           (* 0 none, 1 no flow, 2 high-level interlock *)
  END_VAR
  VAR CONSTANT
    MAX_DOSE_L   : REAL := 500.0; (* largest dose R-201 can take *)
    NO_FLOW_TIME : TIME := T#5s;  (* valve open without flow for this long = failure *)
  END_VAR
  VAR
    XV201       : FB_OnOffValve;  (* control module: dosing valve *)
    FQ201       : FB_Totaliser;   (* control module: dosing totaliser *)
    NoFlowTimer : TON;
    State       : E_PhaseState := Idle;
    Cmd         : E_PhaseCmd;
    Target_L    : REAL;           (* DoseTarget_L as latched at Start *)
    OpenReq     : BOOL;           (* phase -> valve CM *)
    TotRun      : BOOL;           (* phase -> totaliser CM *)
    TotReset    : BOOL;
    ScanStartState : E_PhaseState; (* the state at the start of this scan *)
    Initialised : BOOL;           (* FALSE only on the first scan after power-up *)
  END_VAR

  (* TODO: the phase logic. A suggested order for each scan:
       1. commands: decode PhaseCmd, clear it, discard it on the first scan
          after power-up, and apply the ones that are valid in this state
          (Start: validate and latch the target, reset the totaliser);
       2. failure monitoring in Running (interlock -> FailureCode 2,
          no flow for NO_FLOW_TIME -> FailureCode 1; both hold the phase);
       3. measure: call FQ201 (it runs in every active state);
       4. decide: the "work done" transitions (only for a state that was
          already active when the scan began: see ScanStartState), then
          the valve request;
       5. act: call XV201, then the no-flow timer;
       6. outputs and status.
     Replace these placeholder lines. *)
  ScanStartState := State;
  XV201(OpenReq := FALSE, Permit := LSH201_NC, ZSC := XV201_ZSC);
  FQ201(Flow := FT201_Flow_Lpm, Run := FALSE, Reset := FALSE,
        LowFlowCutoff := 0.5, CycleTime := T#10ms);
  XV201_SOL := XV201.Solenoid;
  PhaseState := F_PhaseStateCode(State);
  DosedTotal_L := FQ201.Total;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : ReactorDosing;
  END_RESOURCE
END_CONFIGURATION
