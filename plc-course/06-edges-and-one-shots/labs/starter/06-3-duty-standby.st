(* Lab 06-3: Duty-standby pump alternation.
   Module 06 (Edge detection and one-shots). STARTER - the declarations are done
   for you; write the logic where it says TODO, then run:
     python3 tools/plctest.py 06-edges-and-one-shots/labs/starter/06-3-duty-standby.st
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
  VAR (* internal - add your own variables here: an edge detector for the
         demand, the selected pump, which pump ran last ... *)
    Spare : BOOL;
  END_VAR

  (* TODO: replace these placeholders with your logic.
     - Each NEW demand starts the pump that did not run last time
       (Pump 1 first after power-up).
     - A faulted pump is never started; the other one runs instead.
     - Never both pumps at once. *)
  Pump1 := FALSE;
  Pump2 := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : DutyStandby;
  END_RESOURCE
END_CONFIGURATION
