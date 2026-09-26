(* Lab 05-3: From truth table to minimal logic - wet-well alarm horn.
   Module 05 (Boolean logic and FBD). REFERENCE SOLUTION - try the lab yourself first.

   K-map (rows HighLevel LowLevel, columns Pump1Run Pump2Run, Gray order):

                    P1 P2:  00   01   11   10
     H L = 00               0    0    0    0
     H L = 01               0    1    1    1
     H L = 11               1    1    1    1
     H L = 10               1    0    0    0

   Groups:  L.P2      quad  (rows 01, 11 x columns 01, 11)
            L.P1      quad  (rows 01, 11 x columns 11, 10)
            H.P1'.P2' pair  (rows 11, 10 x column 00)
   Every group is essential, so the minimal sum of products is unique:
     Horn = L.P1 + L.P2 + H.P1'.P2'     (3 terms, 7 literals)

   Reading the terms back as plant rules:
     L.P1, L.P2   a pump is running while the low-level float says "low":
                  the pump is about to run dry.
     H.P1'.P2'    high level and no pump running: the pumps have failed.
   Both floats "on" at once (a float fault) sounds the horn anyway: with no
   pump running the H term covers it, and with a pump running the L terms do,
   so no separate term is needed. *)

PROGRAM WetWellHorn
  VAR (* I/O - addresses follow the OpenPLC convention *)
    HighLevel AT %IX0.0 : BOOL;  (* High-level float relay: TRUE = level high *)
    LowLevel  AT %IX0.1 : BOOL;  (* Low-level float relay: TRUE = level low *)
    Pump1Run  AT %IX0.2 : BOOL;  (* Pump 1 running (contactor auxiliary contact) *)
    Pump2Run  AT %IX0.3 : BOOL;  (* Pump 2 running (contactor auxiliary contact) *)
    Horn      AT %QX0.0 : BOOL;  (* Wet-well alarm horn *)
  END_VAR

  Horn := (LowLevel AND Pump1Run)
       OR (LowLevel AND Pump2Run)
       OR (HighLevel AND NOT Pump1Run AND NOT Pump2Run);
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : WetWellHorn;
  END_RESOURCE
END_CONFIGURATION
