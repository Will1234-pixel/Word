(* Lab 06-3: Duty-standby pump alternation.
   Module 06 (Edge detection and one-shots). REFERENCE SOLUTION - try the lab yourself first.
   Training exercise only: a real pump station also needs level alarms, run
   feedback, start delays and a design review (Modules 07, 14, 16). *)

PROGRAM DutyStandby
  VAR (* I/O - addresses follow the OpenPLC convention *)
    Demand     AT %IX0.0 : BOOL;  (* Pumping demand from the sump level control: TRUE = pump needed *)
    Pump1OK_NC AT %IX0.1 : BOOL;  (* Pump 1 healthy (overload relay + motor protection), NC: TRUE when healthy *)
    Pump2OK_NC AT %IX0.2 : BOOL;  (* Pump 2 healthy, NC: TRUE when healthy *)
    Pump1      AT %QX0.0 : BOOL;  (* Pump 1 contactor *)
    Pump2      AT %QX0.1 : BOOL;  (* Pump 2 contactor *)
  END_VAR
  VAR (* internal *)
    NewDemand : R_TRIG;           (* one-shot: a new demand has just started *)
    SelectP2  : BOOL;             (* FALSE = Pump 1 selected, TRUE = Pump 2 selected *)
    LastRanP1 : BOOL;             (* TRUE = Pump 1 ran last; FALSE = Pump 2 ran last, or none yet *)
  END_VAR

  (* 1. Alternation - only on the EDGE of a new demand. Choosing on the level
        would swap pumps on every scan while the demand lasts.
        At power-up SelectP2 is FALSE, so Pump 1 is selected even if the edge
        detector does not fire on the first scan (not every platform's does). *)
  NewDemand(CLK := Demand);
  IF NewDemand.Q THEN
    SelectP2 := LastRanP1;        (* the pump that did NOT run last time *)
  END_IF;

  (* 2. Fault handling - checked on every scan. If the selected pump is not
        healthy and the other one is, move the selection to the other pump.
        Nothing moves the selection back when the fault clears, so a pump
        that has taken over keeps running until the demand ends (no bumping). *)
  IF SelectP2 AND NOT Pump2OK_NC AND Pump1OK_NC THEN
    SelectP2 := FALSE;
  ELSIF NOT SelectP2 AND NOT Pump1OK_NC AND Pump2OK_NC THEN
    SelectP2 := TRUE;
  END_IF;

  (* 3. Outputs. The selection is a single BOOL, so both pumps can never be
        commanded at the same time. A faulted pump is never commanded. *)
  Pump1 := Demand AND NOT SelectP2 AND Pump1OK_NC;
  Pump2 := Demand AND SelectP2 AND Pump2OK_NC;

  (* 4. Remember which pump actually ran, for the next alternation. *)
  IF Pump1 THEN
    LastRanP1 := TRUE;
  ELSIF Pump2 THEN
    LastRanP1 := FALSE;
  END_IF;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : DutyStandby;
  END_RESOURCE
END_CONFIGURATION
