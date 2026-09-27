(* A tank filled by a pump with on/off (hysteresis) control. Runs by itself: plot Level in the debugger to see it rise and fall between 20 % and 80 %. Force StopLevel higher to see HighAlarm. *)

PROGRAM P5_TankLevel
  VAR
    Level : REAL := 50.0; (* Tank level in % (simulated) *)
    InletPump : BOOL; (* Pump filling the tank *)
    OutletOpen : BOOL := TRUE; (* Outlet valve: the plant is using water *)
    StartLevel : REAL := 20.0; (* Pump starts at or below this level (%) *)
    StopLevel : REAL := 80.0; (* Pump stops at or above this level (%) *)
    HighAlarm : BOOL; (* Level at or above 90 % *)
  END_VAR

(* 1. CONTROL: on/off level control with hysteresis.
   The pump starts at StartLevel and keeps running until StopLevel. *)
IF Level <= StartLevel THEN
  InletPump := TRUE;
ELSIF Level >= StopLevel THEN
  InletPump := FALSE;
END_IF;
HighAlarm := Level >= 90.0;

(* 2. SIMULATED PLANT: in a real plant this part is the tank itself.
   The pump adds 0.1 % per scan, the open outlet removes 0.04 % per scan. *)
IF InletPump THEN
  Level := Level + 0.1;
END_IF;
IF OutletOpen THEN
  Level := Level - 0.04;
END_IF;
Level := LIMIT(0.0, Level, 100.0);

END_PROGRAM