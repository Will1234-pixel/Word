(* Lab 20-1: 2oo3 pressure trip - voting on three transmitters, degraded
   voting on bad quality, deviation alarm, latched trip and manual reset.
   Module 20 (Functional safety). REFERENCE SOLUTION - try the lab yourself first.

   TRAINING EXERCISE ONLY. This file shows how voting logic behaves. It is
   not a design for a real safety instrumented function: a real SIF runs in
   a certified safety logic solver, is specified in a safety requirements
   specification (SRS) and is verified and validated by competent people
   under IEC 61511. A standard PLC or OpenPLC must never be relied on for it.

   Raw-count convention (the same as Module 14, Siemens style):
     Raw = 0     ->  4 mA -> 0 bar
     Raw = 27648 -> 20 mA -> 10 bar      (1 mA = 1728 counts)
   The card is linear outside that range, so a wire break (0 mA) reads -6912. *)

(* ---- Given helpers (also in the starter) ---------------------------- *)

FUNCTION F_RawToBar : REAL
  VAR_INPUT
    Raw : INT;   (* raw count from the analog input card *)
  END_VAR
  (* 0..27648 counts = 0..10 bar. Not clamped: an over-range reading of
     20.5 mA still reads as a (valid) pressure above 10 bar. *)
  F_RawToBar := INT_TO_REAL(Raw) * 10.0 / 27648.0;
END_FUNCTION

FUNCTION F_RawGood : BOOL
  VAR_INPUT
    Raw : INT;   (* raw count from the analog input card *)
  END_VAR
  VAR
    Current_mA : REAL;
  END_VAR
  (* NAMUR NE43: a loop current at or below 3.6 mA, or at or above 21.0 mA,
     is a failure signal (wire break, transmitter fault), not a measurement. *)
  Current_mA := 4.0 + INT_TO_REAL(Raw) / 1728.0;
  F_RawGood := (Current_mA > 3.6) AND (Current_mA < 21.0);
END_FUNCTION

(* ---- The lab --------------------------------------------------------- *)

PROGRAM PressureTrip2oo3
  VAR (* I/O *)
    PT201A_Raw   AT %IW0   : INT;   (* PT-201A, V-201 pressure, 0..10 bar *)
    PT201B_Raw   AT %IW1   : INT;   (* PT-201B *)
    PT201C_Raw   AT %IW2   : INT;   (* PT-201C *)
    ResetPB      AT %IX0.0 : BOOL;  (* trip reset push-button, NO *)
    OpenPB       AT %IX0.1 : BOOL;  (* operator "open XV-201" push-button, NO *)
    XV201_Sol    AT %QX0.0 : BOOL;  (* XV-201 solenoid: TRUE = energised = valve open *)
    TripLamp     AT %QX0.1 : BOOL;  (* trip indication (latched) *)
    DevAlarm     AT %QX0.2 : BOOL;  (* common transmitter deviation alarm *)
    ChanFaultAlm AT %QX0.3 : BOOL;  (* at least one transmitter has bad quality *)
  END_VAR
  VAR (* status, shown on the HMI and read by the tests *)
    A_Bad        : BOOL;   (* channel A has bad quality *)
    B_Bad        : BOOL;
    C_Bad        : BOOL;
    HealthyCount : INT;    (* number of channels with good quality, 0..3 *)
    VotedTrip    : BOOL;   (* live (unlatched) result of the voting *)
    Tripped      : BOOL;   (* latched trip *)
    DevA         : BOOL;   (* channel A deviates from the median (3 healthy only) *)
    DevB         : BOOL;
    DevC         : BOOL;
  END_VAR
  VAR CONSTANT
    TRIP_BAR      : REAL := 8.0;    (* trip at or above this pressure *)
    DEV_LIMIT_BAR : REAL := 0.5;    (* deviation from the median that raises DevX *)
    DEV_DELAY     : TIME := T#3s;   (* the deviation must last this long *)
  END_VAR
  VAR
    PA, PB, PC   : REAL;   (* pressures, bar *)
    Median       : REAL;   (* middle value of the three *)
    HighVotes    : INT;    (* healthy channels at or above the trip point *)
    DevTimerA    : TON;
    DevTimerB    : TON;
    DevTimerC    : TON;
    ResetEdge    : R_TRIG;
    OpenEdge     : R_TRIG;
    OpenReq      : BOOL;   (* the operator's open request (the BPCS side) *)
  END_VAR

  (* 1. Signal validation. *)
  PA := F_RawToBar(PT201A_Raw);
  PB := F_RawToBar(PT201B_Raw);
  PC := F_RawToBar(PT201C_Raw);
  A_Bad := NOT F_RawGood(PT201A_Raw);
  B_Bad := NOT F_RawGood(PT201B_Raw);
  C_Bad := NOT F_RawGood(PT201C_Raw);

  HealthyCount := 0;
  HighVotes := 0;
  IF NOT A_Bad THEN
    HealthyCount := HealthyCount + 1;
    IF PA >= TRIP_BAR THEN HighVotes := HighVotes + 1; END_IF;
  END_IF;
  IF NOT B_Bad THEN
    HealthyCount := HealthyCount + 1;
    IF PB >= TRIP_BAR THEN HighVotes := HighVotes + 1; END_IF;
  END_IF;
  IF NOT C_Bad THEN
    HealthyCount := HealthyCount + 1;
    IF PC >= TRIP_BAR THEN HighVotes := HighVotes + 1; END_IF;
  END_IF;

  (* 2. Voting, exactly as the SRS for this exercise states it:
        3 healthy -> 2oo3; 2 healthy -> 1oo2 on the two that are left;
        0 or 1 healthy -> trip, because the function can no longer be
        trusted to see a real overpressure. *)
  CASE HealthyCount OF
    3: VotedTrip := HighVotes >= 2;
    2: VotedTrip := HighVotes >= 1;
  ELSE
    VotedTrip := TRUE;
  END_CASE;

  (* 3. Deviation alarm: compare each channel with the median of the three.
        The median ignores one wild channel; an average would be dragged
        towards it and could flag the two good channels instead. With a
        bad channel there is no trustworthy median, so the check pauses
        and the channel fault alarm tells the operator what is wrong. *)
  Median := MAX(MIN(PA, PB), MIN(MAX(PA, PB), PC));
  DevTimerA(IN := (HealthyCount = 3) AND (ABS(PA - Median) > DEV_LIMIT_BAR), PT := DEV_DELAY);
  DevTimerB(IN := (HealthyCount = 3) AND (ABS(PB - Median) > DEV_LIMIT_BAR), PT := DEV_DELAY);
  DevTimerC(IN := (HealthyCount = 3) AND (ABS(PC - Median) > DEV_LIMIT_BAR), PT := DEV_DELAY);
  DevA := DevTimerA.Q;
  DevB := DevTimerB.Q;
  DevC := DevTimerC.Q;
  DevAlarm := DevA OR DevB OR DevC;
  ChanFaultAlm := A_Bad OR B_Bad OR C_Bad;

  (* 4. Latched trip. The trip always wins; the reset acts on the press
        (rising edge), and only while the voted trip is clear. *)
  ResetEdge(CLK := ResetPB);
  IF VotedTrip THEN
    Tripped := TRUE;
  ELSIF ResetEdge.Q THEN
    Tripped := FALSE;
  END_IF;
  TripLamp := Tripped;

  (* 5. Reset must not restart. A trip cancels the open request, so after a
        reset the valve stays shut until the operator presses Open again.
        Open acts on the press, so a button held (or stuck) through the
        reset cannot re-open the valve either. *)
  OpenEdge(CLK := OpenPB);
  IF Tripped THEN
    OpenReq := FALSE;
  ELSIF OpenEdge.Q THEN
    OpenReq := TRUE;
  END_IF;

  (* De-energise to trip: the solenoid is energised only when nothing
     stops it. Power loss, a blown fuse or a broken wire also shut XV-201. *)
  XV201_Sol := OpenReq AND NOT Tripped;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : PressureTrip2oo3;
  END_RESOURCE
END_CONFIGURATION
