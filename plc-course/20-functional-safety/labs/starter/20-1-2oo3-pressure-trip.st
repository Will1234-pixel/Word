(* Lab 20-1: 2oo3 pressure trip - voting on three transmitters, degraded
   voting on bad quality, deviation alarm, latched trip and manual reset.
   Module 20 (Functional safety). STARTER - the interface and two helper
   functions are done for you; write the logic where it says TODO, then run:
     python3 tools/plctest.py 20-functional-safety/labs/starter/20-1-2oo3-pressure-trip.st

   TRAINING EXERCISE ONLY. This file shows how voting logic behaves. It is
   not a design for a real safety instrumented function: a real SIF runs in
   a certified safety logic solver, is specified in a safety requirements
   specification (SRS) and is verified and validated by competent people
   under IEC 61511. A standard PLC or OpenPLC must never be relied on for it.

   Raw-count convention (the same as Module 14, Siemens style):
     Raw = 0     ->  4 mA -> 0 bar
     Raw = 27648 -> 20 mA -> 10 bar      (1 mA = 1728 counts)
   This exercise treats the card as linear outside that range, so a wire
   break (0 mA) reads -6912. A real card reports an underflow or overflow
   code instead (Module 14); F_RawGood flags those as bad quality too. *)

(* ---- Given helpers: use them as they are ---------------------------- *)

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
  (* TODO: add your own internal variables here (pressures in bar, a median,
     timers, edge detectors, an open request ...) in another VAR block. *)

  (* TODO: replace these placeholder lines with your logic:
     1. quality and pressure for each channel (use the helpers),
     2. HealthyCount and the voting (2oo3 / 1oo2 / trip),
     3. median, per-channel deviation with its delay, the two alarms,
     4. the latched trip with an edge-triggered reset that only works when
        the voted trip is clear,
     5. the open request and XV201_Sol (reset must not restart). *)
  A_Bad := FALSE;
  B_Bad := FALSE;
  C_Bad := FALSE;
  HealthyCount := 3;
  VotedTrip := FALSE;
  Tripped := FALSE;
  DevA := FALSE;
  DevB := FALSE;
  DevC := FALSE;
  XV201_Sol := FALSE;
  TripLamp := FALSE;
  DevAlarm := FALSE;
  ChanFaultAlm := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : PressureTrip2oo3;
  END_RESOURCE
END_CONFIGURATION
