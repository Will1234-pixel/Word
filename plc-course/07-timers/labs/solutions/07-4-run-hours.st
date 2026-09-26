(* Lab 07-4: Accumulating run-hours meter.
   Module 07 (Timers). REFERENCE SOLUTION - try the lab yourself first.

   Idea: use a TON purely as a stopwatch. Its ET shows how long the motor has
   been running in the current run. Every scan, add how much ET has grown
   since the previous scan to a small TIME "Fraction", and carry each whole
   second from Fraction into an integer counter. Nothing is thrown away when
   the motor stops, and no time is lost by restarting a short timer every
   second.

   The total lives in a DINT, not a TIME: on many PLCs TIME is a 32-bit
   millisecond count that overflows after about 24.8 days, and a pump can run
   for years. A DINT of seconds lasts about 68 years.

   MATIEC note: infix + and - on TIME values do not build in this toolchain,
   so ADD_TIME and SUB_TIME are used. In CODESYS or TIA Portal you would write
   Fraction + (Stopwatch.ET - LastET). *)

PROGRAM RunHours
  VAR (* I/O *)
    Running    AT %IX0.0 : BOOL;  (* motor running feedback *)
    ResetPB    AT %IX0.1 : BOOL;  (* reset the meter, e.g. after an overhaul (NO) *)
    ServiceDue AT %QX0.0 : BOOL;  (* service-due lamp *)
  END_VAR
  VAR RETAIN (* on a real PLC these must survive a power cut *)
    TotalSeconds : DINT;          (* total running time, whole seconds *)
    Fraction     : TIME;          (* running time not yet counted, below 1 s *)
  END_VAR
  VAR (* display values, recalculated every scan *)
    Hours   : DINT;               (* whole hours *)
    Minutes : DINT;               (* minutes past the whole hour, 0..59 *)
  END_VAR
  VAR (* settings *)
    ServiceHours : DINT := 1000;  (* service interval in running hours *)
  END_VAR
  VAR (* internal *)
    Stopwatch : TON;              (* measures the current run *)
    LastET    : TIME;             (* Stopwatch.ET at the previous scan *)
  END_VAR

  (* 1. Stopwatch. It runs while the motor runs. Its ET would stick at PT, so
        it restarts itself once an hour; that costs two scans an hour
        (0.0006 % with a 10 ms task), which is negligible. *)
  Stopwatch(IN := Running AND NOT Stopwatch.Q, PT := T#1h);

  (* 2. Add the time that has passed since the previous scan. ET only grows
        while the stopwatch is running. When the motor stops (or the stopwatch
        restarts) ET falls back to zero and nothing is added. *)
  IF Stopwatch.ET > LastET THEN
    Fraction := ADD_TIME(Fraction, SUB_TIME(Stopwatch.ET, LastET));
  END_IF;
  LastET := Stopwatch.ET;

  (* 3. Carry whole seconds into the counter. *)
  IF Fraction >= T#1s THEN
    TotalSeconds := TotalSeconds + 1;
    Fraction := SUB_TIME(Fraction, T#1s);
  END_IF;

  (* 4. Reset: clears the total AND the part-second, and holds both at zero
        while the button is pressed. *)
  IF ResetPB THEN
    TotalSeconds := 0;
    Fraction := T#0s;
  END_IF;

  (* 5. Display values and service reminder. *)
  Hours := TotalSeconds / 3600;
  Minutes := (TotalSeconds MOD 3600) / 60;
  ServiceDue := Hours >= ServiceHours;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : RunHours;
  END_RESOURCE
END_CONFIGURATION
