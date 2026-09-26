(* Lab 08-2: Car park up/down counter with capacity, FULL sign and manual preset.
   Module 08 (Counters). REFERENCE SOLUTION - try the lab yourself first.

   Why not a CTUD with PV := Capacity? It is the obvious block, but:
   - the standard leaves the counting limits to the implementation. The
     MATIEC library behind OpenPLC and plctest stops counting UP at PV, so
     cars that ignore the FULL sign would be lost from the count. Siemens
     counts on, but also counts DOWN below 0.
   - on every platform, LD loads PV, so LD could only load Capacity, not
     the attendant's count.
   So this solution counts with ADD/SUB and sets its own limits explicitly:
   never below 0, never past the INT maximum. README section 6.3 shows a
   CTUD version that works around both problems. *)

PROGRAM CarPark
  VAR (* I/O - addresses follow the OpenPLC convention *)
    EntryLoop AT %IX0.0 : BOOL;  (* Vehicle detector, entry lane: TRUE while a car is over the loop *)
    ExitLoop  AT %IX0.1 : BOOL;  (* Vehicle detector, exit lane: TRUE while a car is over the loop *)
    PresetPB  AT %IX0.2 : BOOL;  (* Attendant's preset push-button, NO: load PresetValue into the count *)
    FullSign  AT %QX0.0 : BOOL;  (* "FULL" sign at the entrance *)
  END_VAR
  VAR (* HMI settings and displays - part of the lab interface *)
    Capacity    : INT := 50;     (* number of parking spaces *)
    PresetValue : INT;           (* cars the attendant counted by walking round *)
    SpacesFree  : INT;           (* for the "spaces" sign: never negative *)
  END_VAR
  VAR RETAIN (* the cars do not leave when the power fails *)
    CarCount    : INT;           (* cars in the car park *)
  END_VAR
  VAR (* internal *)
    CarIn  : R_TRIG;             (* a car has just arrived on the entry loop *)
    CarOut : R_TRIG;             (* a car has just arrived on the exit loop *)
  END_VAR

  (* 1. Edge detection on every scan, outside any IF, so the edge memories
        always follow the loops - also while the preset button is held. *)
  CarIn(CLK := EntryLoop);
  CarOut(CLK := ExitLoop);

  (* 2. Preset has priority, like LD on a CTUD: while it is held the count
        is PresetValue (a negative entry is treated as 0) and no cars are
        counted. A car that is on a loop when the button is released has
        already been seen by the edge detector, so it is not counted late. *)
  IF PresetPB THEN
    CarCount := MAX(PresetValue, 0);
  ELSE
    (* Two separate IFs, not IF...ELSIF: a car can enter and another leave
       in the same scan, and both must be counted. *)
    IF CarIn.Q AND CarCount < 32767 THEN      (* INT limit: never wrap to -32768 *)
      CarCount := CarCount + 1;
    END_IF;
    IF CarOut.Q AND CarCount > 0 THEN         (* never below 0 *)
      CarCount := CarCount - 1;
    END_IF;
  END_IF;

  (* 3. Signs. The count may be above Capacity (drivers ignore the sign,
        motorcycles share a space ...): the FULL sign then stays on, and the
        spaces sign shows 0, not a negative number. *)
  FullSign := CarCount >= Capacity;
  SpacesFree := MAX(Capacity - CarCount, 0);
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : CarPark;
  END_RESOURCE
END_CONFIGURATION
