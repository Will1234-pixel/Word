(* Capstone 24-1: Conveyor sorting cell SC-1.
   Module 24 (Capstone projects). STARTER - the interface is done for you.

   Everything the acceptance test (FAT) uses is declared here: the I/O, the
   HMI interface structure and the configuration. Do not rename any of it.
   Everything else is your design. Read the brief first:
     24-capstone-projects/24-1-conveyor-sorting-cell.md

   Suggested workflow:
     1. Add your own types (state enumeration, tracking record, ...) in a
        second TYPE block, and your function blocks (for example FB_Alarm,
        FB_Pusher, FB_Tracker) between the TYPE blocks and the PROGRAM.
     2. Replace the placeholder body of SortingCell with your logic.
     3. Run the FAT and work through it milestone by milestone (M1..M7):
          python3 tools/plctest.py my-work/24-1-conveyor-sorting-cell.st \
                  24-capstone-projects/labs/24-1-conveyor-sorting-cell.test

   Training exercise only. The emergency stop is read here as an ordinary
   input so that the program can react to it. On a real machine the
   emergency stop is a safety function: a safety relay or safety PLC
   removes power from the motor and the pusher valves directly, and the
   standard PLC only monitors it (Module 20). *)

TYPE
  (* ---- HMI interface: part of the specification, do not change ---- *)
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
END_TYPE

(* TODO: your own TYPE block and your function blocks go here. *)

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
  (* TODO: your internal variables and function block instances. *)

  (* TODO: replace these placeholder lines with the cell logic.
     (MATIEC needs at least one statement in a program body.) *)
  ConveyorRun := FALSE;
  PusherA_Sol := FALSE;
  PusherB_Sol := FALSE;
  Horn := FALSE;
  GreenLamp := FALSE;
  AmberLamp := FALSE;
  RedLamp := FALSE;
  HMI.Sts.State := 1;
END_PROGRAM


CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : SortingCell;
  END_RESOURCE
END_CONFIGURATION
