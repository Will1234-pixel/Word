(* Lab 07-2: Flasher beacon with separate on and off times.
   Module 07 (Timers). STARTER - the declarations are done for you;
   write the logic where it says TODO, then run:
     python3 tools/plctest.py 07-timers/labs/starter/07-2-flasher-beacon.st *)

PROGRAM FlasherBeacon
  VAR (* I/O *)
    Enable AT %IX0.0 : BOOL;   (* flash request, e.g. "machine about to start" *)
    Beacon AT %QX0.0 : BOOL;   (* beacon lamp *)
  END_VAR
  VAR (* settings, e.g. written from an HMI *)
    OnTime  : TIME := T#500ms; (* lamp on time *)
    OffTime : TIME := T#1s;    (* lamp off time *)
  END_VAR
  VAR (* internal - you may add more variables here *)
    OnTimer  : TON;            (* ON phase *)
    OffTimer : TON;            (* OFF phase *)
  END_VAR

  (* TODO: make Beacon flash: ON for OnTime, OFF for OffTime, repeating while
     Enable is TRUE, always starting with the ON phase. Replace this line. *)
  Beacon := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : FlasherBeacon;
  END_RESOURCE
END_CONFIGURATION
