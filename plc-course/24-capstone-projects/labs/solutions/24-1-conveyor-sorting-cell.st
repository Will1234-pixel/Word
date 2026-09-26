(* Capstone 24-1: Conveyor sorting cell SC-1.
   Module 24 (Capstone projects). REFERENCE SOLUTION - build your own first.

   The cell sorts drum closures coming out of a washer: metal closures are
   pushed into lane A, plastic ones into lane B, and anything too tall
   (stacked or deformed closures) runs off the end of the belt into the
   reject bin. The requirement numbers FS-xx refer to the project brief,
   24-capstone-projects/24-1-conveyor-sorting-cell.md.

   Structure (one writer for every output, device logic inside FBs):

     FB_Alarm     one alarm: latching, acknowledgement, reset rules
     FB_Debounce  on/off delay filter (lane-full eyes)
     FB_Pusher    one pneumatic pusher: stroke sequence and supervision
     FB_Tracker   encoder-based part tracking: gate decisions, deliveries,
                  jam (overdue part) detection
     F_OldestPart helper for FB_Tracker: which tracked part does a delivery
                  eye confirm?
     SortingCell  the cell: commands, alarms, state machine, I/O mapping

   Training exercise only. The emergency stop is read here as an ordinary
   input so that the program can react to it. On a real machine the
   emergency stop is a safety function: a safety relay or safety PLC
   removes power from the motor and the pusher valves directly, and the
   standard PLC only monitors it (Module 20). *)

TYPE
  (* ---- HMI interface (given in the starter) ---- *)
  ST_CellCmd : STRUCT            (* HMI -> PLC. The HMI sets a bit, the PLC acts once and clears it *)
    Start        : BOOL;         (* start the cell (Auto) *)
    Stop         : BOOL;         (* normal stop, always obeyed *)
    Ack          : BOOL;         (* acknowledge all alarms *)
    Reset        : BOOL;         (* acknowledge and reset alarms whose cause has gone *)
    CyclePusherA : BOOL;         (* Manual: one supervised stroke of pusher A *)
    CyclePusherB : BOOL;         (* Manual: one supervised stroke of pusher B *)
    ClearCounts  : BOOL;         (* zero all six production counters *)
  END_STRUCT;

  ST_CellSts : STRUCT            (* PLC -> HMI, rewritten every scan *)
    State          : INT;        (* 1 STOPPED, 2 STARTING, 3 RUNNING, 4 FAULTED, 5 MANUAL *)
    Ready          : BOOL;       (* a Start now would be accepted *)
    LaneAFull      : BOOL;       (* debounced lane-full status *)
    LaneBFull      : BOOL;
    PartsInTransit : INT;        (* registered parts not yet delivered *)
    CountMetal     : DINT;       (* classified at the entry station *)
    CountPlastic   : DINT;
    CountOversize  : DINT;
    CountLaneA     : DINT;       (* delivered, counted by the delivery eyes *)
    CountLaneB     : DINT;
    CountReject    : DINT;
  END_STRUCT;

  ST_CellAlm : STRUCT            (* PLC -> HMI. TRUE from detection until a successful reset *)
    EStop         : BOOL;
    MotorOverload : BOOL;
    EntryJam      : BOOL;        (* entry eye blocked too long *)
    Jam           : BOOL;        (* a part did not reach its delivery eye in time *)
    PusherA       : BOOL;        (* pusher A did not extend / retract / stay home *)
    PusherB       : BOOL;
    TrackOverflow : BOOL;        (* more parts on the belt than the tracking table holds *)
    Unacked       : BOOL;        (* at least one alarm not yet acknowledged *)
  END_STRUCT;

  ST_CellCfg : STRUCT            (* engineer settings; the defaults are the commissioning values *)
    StartWarnTime : TIME := T#3s;    (* horn before the belt moves (never less than 2 s) *)
    DistA         : INT  := 500;     (* mm from registration to pusher A *)
    DistB         : INT  := 1000;    (* mm from registration to pusher B *)
    JamTimeA      : TIME := T#3s;    (* running time allowed from registration to LaneA_PE *)
    JamTimeB      : TIME := T#4s;    (* ... to LaneB_PE *)
    JamTimeR      : TIME := T#5s;    (* ... to RejectPE *)
    EntryJamTime  : TIME := T#2s;    (* entry eye blocked while running *)
    PusherTimeout : TIME := T#1s;    (* each pusher movement must finish within this *)
    LaneFullTime  : TIME := T#1s;    (* lane-full eye debounce, on and off *)
  END_STRUCT;

  ST_CellHmi : STRUCT
    Cmd : ST_CellCmd;
    Sts : ST_CellSts;
    Alm : ST_CellAlm;
    Cfg : ST_CellCfg;
  END_STRUCT;

  (* ---- internal types (not part of the interface) ---- *)
  E_CellState   : (CS_STOPPED, CS_STARTING, CS_RUNNING, CS_FAULTED, CS_MANUAL);
  E_PusherPhase : (PS_IDLE, PS_EXTEND, PS_RETRACT);
  E_Dest        : (DEST_NONE, DEST_LANE_A, DEST_LANE_B, DEST_REJECT);

  ST_TrackedPart : STRUCT
    Active : BOOL;               (* this slot holds a part *)
    Dest   : E_Dest;             (* where the part is going now *)
    Travel : DINT;               (* belt travel since registration, mm *)
    Age    : TIME;               (* conveyor running time since registration *)
    Pushed : BOOL;               (* its pusher has been fired *)
  END_STRUCT;

  T_PartTable : ARRAY[1..16] OF ST_TrackedPart;
END_TYPE


FUNCTION_BLOCK FB_Alarm
  (* One alarm (ISA-18.2 style: active and acknowledged are separate states).
     Latching alarms stay active after the condition clears, until a Reset
     while Hold is FALSE. Non-latching alarms follow Condition; use them to
     mirror a device FB that latches its own fault. A new activation is
     always unacknowledged. Ack and Reset are one-shots. *)
  VAR_INPUT
    Condition : BOOL;            (* the abnormal condition *)
    Latching  : BOOL;            (* TRUE: active until reset *)
    Hold      : BOOL;            (* TRUE: the cause is still present, refuse reset *)
    Ack       : BOOL;
    Reset     : BOOL;            (* also acknowledges *)
  END_VAR
  VAR_OUTPUT
    Active  : BOOL;
    Unacked : BOOL;
  END_VAR
  VAR
    WasActive : BOOL;
  END_VAR

  IF Ack OR Reset THEN
    Unacked := FALSE;
  END_IF;

  IF NOT Latching THEN
    Active := Condition;
  ELSIF Condition THEN
    Active := TRUE;
  ELSIF Reset AND NOT Hold THEN
    Active := FALSE;
  END_IF;

  IF Active AND NOT WasActive THEN
    Unacked := TRUE;             (* every new occurrence needs its own acknowledgement *)
  END_IF;
  WasActive := Active;
END_FUNCTION_BLOCK


FUNCTION_BLOCK FB_Debounce
  (* Out goes TRUE when Raw has been TRUE for OnDelay, and FALSE when Raw has
     been FALSE for OffDelay. Used for the lane-full eyes, which parts
     sliding past block for a moment. *)
  VAR_INPUT
    Raw      : BOOL;
    OnDelay  : TIME;
    OffDelay : TIME;
  END_VAR
  VAR_OUTPUT
    Out : BOOL;
  END_VAR
  VAR
    OnTmr  : TON;
    OffTmr : TON;
  END_VAR

  OnTmr(IN := Raw, PT := OnDelay);
  OffTmr(IN := NOT Raw, PT := OffDelay);
  IF OnTmr.Q THEN
    Out := TRUE;
  ELSIF OffTmr.Q THEN
    Out := FALSE;
  END_IF;
END_FUNCTION_BLOCK


FUNCTION_BLOCK FB_Pusher
  (* Single-solenoid, spring-return pneumatic pusher with extended and
     retracted reed switches (FS-18 to FS-20).

     Fire (one-shot) starts one stroke: the solenoid is energised until the
     cylinder is extended, then released so the spring retracts it.

     Supervision: whatever the phase, the position it asks for must be
     reached within Timeout:
       PS_EXTEND   extended       (FaultCode 1: did not extend)
       PS_RETRACT  retracted      (FaultCode 2: did not retract)
       PS_IDLE     retracted      (FaultCode 3: left home without a command)
     "Extended" and "retracted" need exactly one switch made, so a stuck or
     shorted switch is also caught. A fault de-energises the solenoid and
     latches until Reset, which is only accepted with the pusher home.

     Abort (level) releases the solenoid at once (e-stop, fault stop). A
     stroke that is aborted finishes as a normal retraction, still
     supervised. *)
  VAR_INPUT
    Fire    : BOOL;
    Abort   : BOOL;
    ExtLS   : BOOL;
    RetLS   : BOOL;
    Reset   : BOOL;
    Timeout : TIME;
  END_VAR
  VAR_OUTPUT
    Sol       : BOOL;            (* solenoid valve *)
    Available : BOOL;            (* idle, home and healthy: Fire would be accepted *)
    Busy      : BOOL;            (* a stroke is in progress *)
    Fault     : BOOL;
    FaultCode : INT;             (* 0 none, 1 extend, 2 retract, 3 left home *)
  END_VAR
  VAR
    Phase     : E_PusherPhase;  (* not "Step": STEP is an SFC keyword *)
    LastPhase : E_PusherPhase;
    Extended  : BOOL;
    Retracted : BOOL;
    AtTarget  : BOOL;
    SupTmr    : TON;
  END_VAR

  Extended := ExtLS AND NOT RetLS;
  Retracted := RetLS AND NOT ExtLS;

  (* Reset first, so that a fault whose cause is still present stays. *)
  IF Reset AND Fault AND Retracted THEN
    Fault := FALSE;
    FaultCode := 0;
    Phase := PS_IDLE;
  END_IF;

  CASE Phase OF
    PS_IDLE:
      IF Fire AND NOT Fault AND NOT Abort AND Retracted THEN
        Phase := PS_EXTEND;
      END_IF;
    PS_EXTEND:
      IF Extended OR Abort OR Fault THEN
        Phase := PS_RETRACT;
      END_IF;
    PS_RETRACT:
      IF Retracted THEN
        Phase := PS_IDLE;
      END_IF;
  END_CASE;

  (* Supervision. The timer restarts on every phase change and stops while
     a fault is latched. *)
  IF Phase = PS_EXTEND THEN
    AtTarget := Extended;
  ELSE
    AtTarget := Retracted;
  END_IF;
  SupTmr(IN := NOT AtTarget AND (Phase = LastPhase) AND NOT Fault, PT := Timeout);
  IF SupTmr.Q THEN
    Fault := TRUE;
    IF Phase = PS_EXTEND THEN
      FaultCode := 1;
    ELSIF Phase = PS_RETRACT THEN
      FaultCode := 2;
    ELSE
      FaultCode := 3;
    END_IF;
    Phase := PS_IDLE;
  END_IF;
  LastPhase := Phase;

  Sol := (Phase = PS_EXTEND) AND NOT Fault AND NOT Abort;
  Busy := Phase <> PS_IDLE;
  Available := (Phase = PS_IDLE) AND Retracted AND NOT Fault AND NOT Abort;
END_FUNCTION_BLOCK


FUNCTION F_OldestPart : INT
  (* Index of the active part bound for Dest that is furthest along the
     belt (the oldest), or 0 if there is none. With NeedPushed TRUE only
     parts whose pusher has fired count: nothing else can arrive in a lane. *)
  VAR_IN_OUT
    Parts : T_PartTable;
  END_VAR
  VAR_INPUT
    Dest       : E_Dest;
    NeedPushed : BOOL;
  END_VAR
  VAR
    i : INT;
  END_VAR

  F_OldestPart := 0;
  FOR i := 1 TO 16 DO
    IF Parts[i].Active AND Parts[i].Dest = Dest AND (Parts[i].Pushed OR NOT NeedPushed) THEN
      IF F_OldestPart = 0 THEN
        F_OldestPart := i;
      ELSIF Parts[i].Travel > Parts[F_OldestPart].Travel THEN
        F_OldestPart := i;
      END_IF;
    END_IF;
  END_FOR;
END_FUNCTION


FUNCTION_BLOCK FB_Tracker
  (* Encoder-based part tracking (FS-13 to FS-17, FS-22, FS-26).

     Every registered part gets a slot in a table of 16. Each scan:
       1. the belt movement since the last scan (with 16-bit wrap-around)
          is added to every part's Travel, and the conveyor running time to
          its Age;
       2. delivery-eye edges remove the oldest part bound for that exit;
       3. a part bound for a lane that has reached its gate is pushed if
          the gate is free, otherwise it is re-routed to the reject bin;
       4. a part older than the jam time for its destination sets Jam;
       5. a new part is registered at Travel 0.
     Position (for the pushers) and time (for jams) are measured
     independently on purpose. A part stuck against a guide while the belt
     slides under it (the encoder keeps counting), and a belt slipping on
     its drive drum while the motor runs (the measuring wheel stops, so the
     encoder stops too), both show up the same way: a part that is late. *)
  VAR_INPUT
    EncCount    : UINT;          (* high-speed counter, 1 count = 1 mm, wraps 65535 -> 0 *)
    BeltRunning : BOOL;          (* conveyor motor on: running time accumulates *)
    Clear       : BOOL;          (* forget every tracked part *)
    Register    : BOOL;          (* one-shot: a part has just cleared the entry eye *)
    RegDest     : E_Dest;
    GateAFree   : BOOL;          (* lane A not full and pusher A available *)
    GateBFree   : BOOL;
    ConfirmA    : BOOL;          (* one-shots from the delivery eyes *)
    ConfirmB    : BOOL;
    ConfirmR    : BOOL;
    DistA       : DINT;          (* mm from registration to pusher A *)
    DistB       : DINT;
    JamTimeA    : TIME;
    JamTimeB    : TIME;
    JamTimeR    : TIME;
  END_VAR
  VAR_OUTPUT
    FireA     : BOOL;            (* one-shot: stroke pusher A now *)
    FireB     : BOOL;
    Jam       : BOOL;            (* at least one part is overdue *)
    Overflow  : BOOL;            (* a part could not be registered (latched until Clear) *)
    InTransit : INT;
  END_VAR
  VAR
    Parts     : T_PartTable;
    Started   : BOOL;
    LastCount : UINT;
    Delta     : DINT;            (* belt travel this scan, mm *)
    Stopwatch : TON;             (* free-running: measures the scan-to-scan time *)
    LastET    : TIME;
    ScanTime  : TIME;            (* time since the previous scan *)
    AFree     : BOOL;
    BFree     : BOOL;
    JamLimit  : TIME;
    Idx       : INT;
    i         : INT;
  END_VAR

  (* 1a. Belt travel since the last scan. The counter is 16 bits, so the
         raw difference is folded back into -32768..32767. At 0.5 m/s the
         belt moves about 5 mm per scan, far inside that range. *)
  IF NOT Started THEN
    LastCount := EncCount;       (* first call: no movement yet *)
    Started := TRUE;
  END_IF;
  Delta := UINT_TO_DINT(EncCount) - UINT_TO_DINT(LastCount);
  IF Delta < -32768 THEN
    Delta := Delta + 65536;      (* wrapped forwards, 65535 -> 0: this cell *)
  ELSIF Delta > 32767 THEN
    Delta := Delta - 65536;      (* wrapped backwards (a counter that can count down) *)
  END_IF;
  LastCount := EncCount;

  (* 1b. Time since the last scan, from a stopwatch that restarts itself
         once an hour (the Lab 07-4 technique). The restart costs two scans
         of running time an hour (about 20 ms), far below the jam times. *)
  Stopwatch(IN := NOT Stopwatch.Q, PT := T#1h);
  IF Stopwatch.ET > LastET THEN
    ScanTime := Stopwatch.ET - LastET;
  ELSE
    ScanTime := T#0s;
  END_IF;
  LastET := Stopwatch.ET;

  IF Clear THEN
    FOR i := 1 TO 16 DO
      Parts[i].Active := FALSE;
    END_FOR;
    Overflow := FALSE;
  END_IF;

  FOR i := 1 TO 16 DO
    IF Parts[i].Active THEN
      Parts[i].Travel := Parts[i].Travel + Delta;
      IF BeltRunning THEN
        Parts[i].Age := Parts[i].Age + ScanTime;
      END_IF;
    END_IF;
  END_FOR;

  (* 2. Deliveries. An edge with no matching part (for example a part that
        was on the belt when tracking was cleared) is simply not matched;
        the cell still counts it. *)
  IF ConfirmA THEN
    Idx := F_OldestPart(Parts := Parts, Dest := DEST_LANE_A, NeedPushed := TRUE);
    IF Idx > 0 THEN
      Parts[Idx].Active := FALSE;
    END_IF;
  END_IF;
  IF ConfirmB THEN
    Idx := F_OldestPart(Parts := Parts, Dest := DEST_LANE_B, NeedPushed := TRUE);
    IF Idx > 0 THEN
      Parts[Idx].Active := FALSE;
    END_IF;
  END_IF;
  IF ConfirmR THEN
    Idx := F_OldestPart(Parts := Parts, Dest := DEST_REJECT, NeedPushed := FALSE);
    IF Idx > 0 THEN
      Parts[Idx].Active := FALSE;
    END_IF;
  END_IF;

  (* 3 and 4. Gate decisions and overdue parts. At most one stroke per
        pusher per scan: a second part at the same gate goes to reject. *)
  FireA := FALSE;
  FireB := FALSE;
  Jam := FALSE;
  AFree := GateAFree;
  BFree := GateBFree;
  FOR i := 1 TO 16 DO
    IF Parts[i].Active THEN
      IF Parts[i].Dest = DEST_LANE_A AND NOT Parts[i].Pushed AND Parts[i].Travel >= DistA THEN
        IF AFree THEN
          FireA := TRUE;
          Parts[i].Pushed := TRUE;
          AFree := FALSE;
        ELSE
          Parts[i].Dest := DEST_REJECT;      (* lane full or pusher not ready (FS-15) *)
        END_IF;
      ELSIF Parts[i].Dest = DEST_LANE_B AND NOT Parts[i].Pushed AND Parts[i].Travel >= DistB THEN
        IF BFree THEN
          FireB := TRUE;
          Parts[i].Pushed := TRUE;
          BFree := FALSE;
        ELSE
          Parts[i].Dest := DEST_REJECT;
        END_IF;
      END_IF;

      IF Parts[i].Dest = DEST_LANE_A THEN
        JamLimit := JamTimeA;
      ELSIF Parts[i].Dest = DEST_LANE_B THEN
        JamLimit := JamTimeB;
      ELSE
        JamLimit := JamTimeR;
      END_IF;
      IF Parts[i].Age > JamLimit THEN
        Jam := TRUE;
      END_IF;
    END_IF;
  END_FOR;

  (* 5. Registration, after this scan's movement, so the part starts at 0. *)
  IF Register THEN
    Idx := 0;
    FOR i := 1 TO 16 DO
      IF NOT Parts[i].Active THEN
        Idx := i;
        EXIT;
      END_IF;
    END_FOR;
    IF Idx > 0 THEN
      Parts[Idx].Active := TRUE;
      Parts[Idx].Dest := RegDest;
      Parts[Idx].Travel := 0;
      Parts[Idx].Age := T#0s;
      Parts[Idx].Pushed := FALSE;
    ELSE
      Overflow := TRUE;
    END_IF;
  END_IF;

  InTransit := 0;
  FOR i := 1 TO 16 DO
    IF Parts[i].Active THEN
      InTransit := InTransit + 1;
    END_IF;
  END_FOR;
END_FUNCTION_BLOCK


PROGRAM SortingCell
  VAR (* operator panel *)
    StartPB    AT %IX0.0 : BOOL;   (* Start, NO *)
    StopPB_NC  AT %IX0.1 : BOOL;   (* Stop, NC: TRUE while not pressed *)
    EStop_NC   AT %IX0.2 : BOOL;   (* e-stop circuit monitoring, NC: TRUE while healthy *)
    ResetPB    AT %IX0.3 : BOOL;   (* Reset, NO *)
    ModeAuto   AT %IX0.4 : BOOL;   (* mode selector in AUTO *)
    ModeManual AT %IX0.5 : BOOL;   (* mode selector in MAN *)
    JogPB      AT %IX0.6 : BOOL;   (* Jog forward, NO, hold-to-run *)
    MotorOL_NC AT %IX0.7 : BOOL;   (* conveyor motor overload relay, NC: TRUE while healthy *)
  END_VAR
  VAR (* conveyor sensors *)
    EntryPE       AT %IX1.0 : BOOL;  (* entry eye: TRUE while a part blocks it *)
    MetalPX       AT %IX1.1 : BOOL;  (* inductive sensor: TRUE = metal *)
    TallPE        AT %IX1.2 : BOOL;  (* height eye: TRUE = part too tall *)
    LaneA_PE      AT %IX1.3 : BOOL;  (* lane A delivery eye *)
    LaneB_PE      AT %IX1.4 : BOOL;  (* lane B delivery eye *)
    RejectPE      AT %IX1.5 : BOOL;  (* reject chute eye *)
    LaneA_FullPE  AT %IX1.6 : BOOL;  (* lane A full eye: TRUE = blocked *)
    LaneB_FullPE  AT %IX1.7 : BOOL;  (* lane B full eye *)
    PusherA_ExtLS AT %IX2.0 : BOOL;  (* pusher A extended *)
    PusherA_RetLS AT %IX2.1 : BOOL;  (* pusher A retracted (home) *)
    PusherB_ExtLS AT %IX2.2 : BOOL;  (* pusher B extended *)
    PusherB_RetLS AT %IX2.3 : BOOL;  (* pusher B retracted (home) *)
    EncCount      AT %IW0 : UINT;    (* belt encoder via high-speed counter: 1 count = 1 mm *)
  END_VAR
  VAR (* outputs *)
    ConveyorRun AT %QX0.0 : BOOL;    (* conveyor motor contactor *)
    PusherA_Sol AT %QX0.1 : BOOL;    (* pusher A solenoid valve: TRUE = extend *)
    PusherB_Sol AT %QX0.2 : BOOL;    (* pusher B solenoid valve *)
    Horn        AT %QX0.3 : BOOL;    (* start-up warning horn *)
    GreenLamp   AT %QX0.4 : BOOL;    (* stack light green: running *)
    AmberLamp   AT %QX0.5 : BOOL;    (* stack light amber: lane full *)
    RedLamp     AT %QX0.6 : BOOL;    (* stack light red: alarm *)
  END_VAR
  VAR (* HMI interface *)
    HMI : ST_CellHmi;
  END_VAR
  VAR RETAIN (* production counters: on a real PLC they survive a power cut *)
    CountMetal    : DINT;
    CountPlastic  : DINT;
    CountOversize : DINT;
    CountLaneA    : DINT;
    CountLaneB    : DINT;
    CountReject   : DINT;
  END_VAR
  VAR (* internal *)
    State       : E_CellState;       (* the real state; HMI.Sts.State is only a copy *)
    Cfg         : ST_CellCfg;        (* validated working copy of HMI.Cfg *)
    Cmd         : ST_CellCmd;        (* this scan's snapshot of HMI.Cmd *)
    NoCmd       : ST_CellCmd;        (* all FALSE: used to clear HMI.Cmd *)
    Initialised : BOOL;              (* FALSE only during the first scan *)

    StartReq, StopReq, ResetReq, AckReq : BOOL;
    AutoSel, ManualSel : BOOL;
    Ready, AnyAlarm, AnyUnacked : BOOL;
    MotorOn, ClearTracking : BOOL;
    SawMetal, SawTall, NewPart : BOOL;
    NewDest : E_Dest;
    Flash : BOOL;

    StartEdge, ResetEdge : R_TRIG;
    LaneAEdge, LaneBEdge, RejectEdge : R_TRIG;
    EntryFall   : F_TRIG;
    WarnTmr     : TON;
    EntryJamTmr : TON;
    FlashTmr    : TON;
    LaneAFull, LaneBFull : FB_Debounce;

    AlmEStop, AlmOverload, AlmEntryJam, AlmJam, AlmOverflow : FB_Alarm;
    AlmPusherA, AlmPusherB : FB_Alarm;

    Tracker : FB_Tracker;
    PusherA : FB_Pusher;
    PusherB : FB_Pusher;
  END_VAR

  (* ================================================================
     1. Configuration: never use an HMI value without checking it (FS-35).
        The start-up warning in particular can never be removed by a typo.
     ================================================================ *)
  Cfg.StartWarnTime := LIMIT(T#2s, HMI.Cfg.StartWarnTime, T#30s);
  Cfg.DistA         := LIMIT(100, HMI.Cfg.DistA, 3000);
  Cfg.DistB         := LIMIT(100, HMI.Cfg.DistB, 3000);
  Cfg.JamTimeA      := LIMIT(T#1s, HMI.Cfg.JamTimeA, T#60s);
  Cfg.JamTimeB      := LIMIT(T#1s, HMI.Cfg.JamTimeB, T#60s);
  Cfg.JamTimeR      := LIMIT(T#1s, HMI.Cfg.JamTimeR, T#60s);
  Cfg.EntryJamTime  := LIMIT(T#500ms, HMI.Cfg.EntryJamTime, T#30s);
  Cfg.PusherTimeout := LIMIT(T#200ms, HMI.Cfg.PusherTimeout, T#5s);
  Cfg.LaneFullTime  := LIMIT(T#200ms, HMI.Cfg.LaneFullTime, T#10s);

  (* ================================================================
     2. Commands. HMI commands: snapshot, then clear at once (FS-02).
        Anything waiting at the first scan was written before the
        restart and is thrown away, and so is a Start or Reset button
        that is already held at power-up (FS-01).
     ================================================================ *)
  Cmd := HMI.Cmd;
  HMI.Cmd := NoCmd;

  StartEdge(CLK := StartPB);
  ResetEdge(CLK := ResetPB);

  IF NOT Initialised THEN
    Cmd := NoCmd;
    StartReq := FALSE;
    ResetReq := FALSE;
    Initialised := TRUE;
  ELSE
    StartReq := StartEdge.Q OR Cmd.Start;
    ResetReq := ResetEdge.Q OR Cmd.Reset;
  END_IF;
  StopReq := NOT StopPB_NC OR Cmd.Stop;           (* a held Stop keeps stopping *)
  AckReq := Cmd.Ack OR ResetReq;                   (* Reset also acknowledges (FS-30) *)

  AutoSel := ModeAuto AND NOT ModeManual;          (* both or neither = Off (FS-03) *)
  ManualSel := ModeManual AND NOT ModeAuto;

  (* ================================================================
     3. Field signals.
     ================================================================ *)
  LaneAFull(Raw := LaneA_FullPE, OnDelay := Cfg.LaneFullTime, OffDelay := Cfg.LaneFullTime);
  LaneBFull(Raw := LaneB_FullPE, OnDelay := Cfg.LaneFullTime, OffDelay := Cfg.LaneFullTime);
  LaneAEdge(CLK := LaneA_PE);
  LaneBEdge(CLK := LaneB_PE);
  RejectEdge(CLK := RejectPE);
  EntryFall(CLK := EntryPE);

  (* Entry jam: the entry eye stays blocked while the belt runs (FS-25). *)
  EntryJamTmr(IN := EntryPE AND State = CS_RUNNING, PT := Cfg.EntryJamTime);

  (* ================================================================
     4. Alarms (FS-27 to FS-30). Device faults that the pusher FBs latch
        themselves are mirrored (non-latching); the rest latch here.
        Hold = "the cause is still there", which refuses the reset.
     ================================================================ *)
  AlmEStop(Condition := NOT EStop_NC, Latching := TRUE, Hold := FALSE,
           Ack := AckReq, Reset := ResetReq);
  AlmOverload(Condition := NOT MotorOL_NC, Latching := TRUE, Hold := FALSE,
              Ack := AckReq, Reset := ResetReq);
  AlmEntryJam(Condition := EntryJamTmr.Q, Latching := TRUE, Hold := EntryPE,
              Ack := AckReq, Reset := ResetReq);
  AlmJam(Condition := Tracker.Jam, Latching := TRUE, Hold := FALSE,
         Ack := AckReq, Reset := ResetReq);
  AlmOverflow(Condition := Tracker.Overflow, Latching := TRUE, Hold := FALSE,
              Ack := AckReq, Reset := ResetReq);
  AlmPusherA(Condition := PusherA.Fault, Latching := FALSE, Hold := FALSE,
             Ack := AckReq, Reset := ResetReq);
  AlmPusherB(Condition := PusherB.Fault, Latching := FALSE, Hold := FALSE,
             Ack := AckReq, Reset := ResetReq);

  AnyAlarm := AlmEStop.Active OR AlmOverload.Active OR AlmEntryJam.Active OR AlmJam.Active
              OR AlmOverflow.Active OR AlmPusherA.Active OR AlmPusherB.Active;
  AnyUnacked := AlmEStop.Unacked OR AlmOverload.Unacked OR AlmEntryJam.Unacked OR AlmJam.Unacked
                OR AlmOverflow.Unacked OR AlmPusherA.Unacked OR AlmPusherB.Unacked;

  (* ================================================================
     5. Cell state machine (FS-04 to FS-11, FS-28, FS-31).
        Any alarm wins from every state. Entering MANUAL or FAULTED
        forgets the tracking: someone may be about to touch the parts.
     ================================================================ *)
  Ready := AutoSel AND StopPB_NC AND NOT AnyAlarm
           AND PusherA.Available AND PusherB.Available;
  ClearTracking := FALSE;

  CASE State OF
    CS_STOPPED:
      IF AnyAlarm THEN
        State := CS_FAULTED;
        ClearTracking := TRUE;
      ELSIF ManualSel THEN
        State := CS_MANUAL;
        ClearTracking := TRUE;
      ELSIF StartReq AND Ready THEN
        State := CS_STARTING;
      END_IF;

    CS_STARTING:
      IF AnyAlarm THEN
        State := CS_FAULTED;
        ClearTracking := TRUE;
      ELSIF StopReq OR NOT AutoSel THEN
        State := CS_STOPPED;
      ELSIF WarnTmr.Q THEN
        State := CS_RUNNING;
      END_IF;

    CS_RUNNING:
      IF AnyAlarm THEN
        State := CS_FAULTED;
        ClearTracking := TRUE;
      ELSIF StopReq OR NOT AutoSel THEN
        State := CS_STOPPED;              (* normal stop: tracking is kept (FS-08) *)
      END_IF;

    CS_MANUAL:
      IF AnyAlarm THEN
        State := CS_FAULTED;
        ClearTracking := TRUE;
      ELSIF NOT ManualSel THEN
        State := CS_STOPPED;
      END_IF;

    CS_FAULTED:
      IF NOT AnyAlarm THEN
        State := CS_STOPPED;              (* never straight back to running (FS-31) *)
      END_IF;
  END_CASE;

  WarnTmr(IN := State = CS_STARTING, PT := Cfg.StartWarnTime);

  (* Conveyor: runs in RUNNING, or in MANUAL while Jog is held (FS-09). *)
  MotorOn := (State = CS_RUNNING)
             OR (State = CS_MANUAL AND JogPB AND StopPB_NC
                 AND PusherA.Available AND PusherB.Available);

  (* ================================================================
     6. Classification and registration (FS-12, FS-13). The sensors are
        remembered for as long as the part blocks the entry eye, so a
        sensor mounted a little off the eye's line still counts.
     ================================================================ *)
  IF EntryPE THEN
    SawMetal := SawMetal OR MetalPX;
    SawTall := SawTall OR TallPE;
  END_IF;
  NewPart := FALSE;
  IF EntryFall.Q THEN
    IF State = CS_RUNNING THEN
      NewPart := TRUE;
      IF SawTall THEN
        NewDest := DEST_REJECT;
        CountOversize := CountOversize + 1;
      ELSIF SawMetal THEN
        NewDest := DEST_LANE_A;
        CountMetal := CountMetal + 1;
      ELSE
        NewDest := DEST_LANE_B;
        CountPlastic := CountPlastic + 1;
      END_IF;
    END_IF;
    SawMetal := FALSE;
    SawTall := FALSE;
  END_IF;

  (* ================================================================
     7. Tracking and pushers.
     ================================================================ *)
  Tracker(EncCount := EncCount,
          BeltRunning := MotorOn,
          Clear := ClearTracking,
          Register := NewPart,
          RegDest := NewDest,
          GateAFree := NOT LaneAFull.Out AND PusherA.Available,
          GateBFree := NOT LaneBFull.Out AND PusherB.Available,
          ConfirmA := LaneAEdge.Q,
          ConfirmB := LaneBEdge.Q,
          ConfirmR := RejectEdge.Q,
          DistA := INT_TO_DINT(Cfg.DistA),
          DistB := INT_TO_DINT(Cfg.DistB),
          JamTimeA := Cfg.JamTimeA,
          JamTimeB := Cfg.JamTimeB,
          JamTimeR := Cfg.JamTimeR);

  (* A normal stop does not abort a stroke (FS-08); a fault does (FS-28).
     Manual strokes only in MANUAL with the belt stopped (FS-10). *)
  PusherA(Fire := Tracker.FireA OR (State = CS_MANUAL AND Cmd.CyclePusherA AND NOT MotorOn),
          Abort := State = CS_FAULTED,
          ExtLS := PusherA_ExtLS,
          RetLS := PusherA_RetLS,
          Reset := ResetReq,
          Timeout := Cfg.PusherTimeout);
  PusherB(Fire := Tracker.FireB OR (State = CS_MANUAL AND Cmd.CyclePusherB AND NOT MotorOn),
          Abort := State = CS_FAULTED,
          ExtLS := PusherB_ExtLS,
          RetLS := PusherB_RetLS,
          Reset := ResetReq,
          Timeout := Cfg.PusherTimeout);

  (* ================================================================
     8. Delivery counters: physical parts, counted in every state (FS-21).
     ================================================================ *)
  IF LaneAEdge.Q THEN
    CountLaneA := CountLaneA + 1;
  END_IF;
  IF LaneBEdge.Q THEN
    CountLaneB := CountLaneB + 1;
  END_IF;
  IF RejectEdge.Q THEN
    CountReject := CountReject + 1;
  END_IF;
  IF Cmd.ClearCounts THEN
    CountMetal := 0;
    CountPlastic := 0;
    CountOversize := 0;
    CountLaneA := 0;
    CountLaneB := 0;
    CountReject := 0;
  END_IF;

  (* ================================================================
     9. Outputs: each written in exactly one place (FS-28, FS-32).
     ================================================================ *)
  ConveyorRun := MotorOn;
  PusherA_Sol := PusherA.Sol;
  PusherB_Sol := PusherB.Sol;
  Horn := State = CS_STARTING;
  GreenLamp := State = CS_RUNNING;
  AmberLamp := LaneAFull.Out OR LaneBFull.Out;

  FlashTmr(IN := NOT FlashTmr.Q, PT := T#500ms);   (* 1 Hz flasher *)
  IF FlashTmr.Q THEN
    Flash := NOT Flash;
  END_IF;
  RedLamp := (AnyUnacked AND Flash) OR (AnyAlarm AND NOT AnyUnacked);

  (* ================================================================
     10. HMI status: copied from the real state every scan, so a stray
         write from the HMI changes nothing (FS-33, FS-34).
     ================================================================ *)
  CASE State OF
    CS_STOPPED:  HMI.Sts.State := 1;
    CS_STARTING: HMI.Sts.State := 2;
    CS_RUNNING:  HMI.Sts.State := 3;
    CS_FAULTED:  HMI.Sts.State := 4;
    CS_MANUAL:   HMI.Sts.State := 5;
  END_CASE;
  HMI.Sts.Ready := Ready AND State = CS_STOPPED;
  HMI.Sts.LaneAFull := LaneAFull.Out;
  HMI.Sts.LaneBFull := LaneBFull.Out;
  HMI.Sts.PartsInTransit := Tracker.InTransit;
  HMI.Sts.CountMetal := CountMetal;
  HMI.Sts.CountPlastic := CountPlastic;
  HMI.Sts.CountOversize := CountOversize;
  HMI.Sts.CountLaneA := CountLaneA;
  HMI.Sts.CountLaneB := CountLaneB;
  HMI.Sts.CountReject := CountReject;

  HMI.Alm.EStop := AlmEStop.Active;
  HMI.Alm.MotorOverload := AlmOverload.Active;
  HMI.Alm.EntryJam := AlmEntryJam.Active;
  HMI.Alm.Jam := AlmJam.Active;
  HMI.Alm.PusherA := AlmPusherA.Active;
  HMI.Alm.PusherB := AlmPusherB.Active;
  HMI.Alm.TrackOverflow := AlmOverflow.Active;
  HMI.Alm.Unacked := AnyUnacked;
END_PROGRAM


CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : SortingCell;
  END_RESOURCE
END_CONFIGURATION
