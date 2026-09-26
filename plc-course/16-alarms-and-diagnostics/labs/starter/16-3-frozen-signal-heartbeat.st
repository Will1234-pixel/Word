(* Lab 16-3: Frozen-signal and heartbeat diagnostics.
   Module 16 (Alarms, diagnostics and fault handling). STARTER - the block
   interfaces and the program that uses them are done for you. Write:
     1. the body of FB_FrozenSignal,
     2. the body of FB_Heartbeat,
     3. this PLC's own heartbeat (HeartbeatOut) at the end of the program,
   where it says TODO, then run:
     python3 tools/plctest.py 16-alarms-and-diagnostics/labs/starter/16-3-frozen-signal-heartbeat.st

   Two small diagnostic blocks that catch faults a range check cannot see:
     FB_FrozenSignal  a transmitter value that stops moving while the
                      process is running (stuck sensor, transmitter left in
                      fixed-current mode, frozen communication value)
     FB_Heartbeat     a partner's heartbeat counter that stops changing
                      (partner stopped, or the link between us is down) *)

FUNCTION_BLOCK FB_FrozenSignal
  VAR_INPUT
    PV         : REAL;   (* value to watch, engineering units *)
    Tolerance  : REAL;   (* a change larger than this counts as movement *)
    FreezeTime : TIME;   (* no movement for this long = frozen *)
    Enable     : BOOL;   (* TRUE while the process should make PV move *)
  END_VAR
  VAR_OUTPUT
    Frozen     : BOOL;   (* PV has not moved by more than Tolerance for FreezeTime *)
  END_VAR
  VAR
    (* Add your internal variables here. Hint: compare PV with a REFERENCE
       value, not with the previous scan's value. *)
    StillTimer : TON;
  END_VAR

  (* TODO: replace this placeholder line with your logic (see the
     requirements in the Module 16 README, Lab 16-3). *)
  Frozen := FALSE;
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_Heartbeat
  VAR_INPUT
    Counter   : INT;     (* heartbeat counter received from the partner *)
    Timeout   : TIME;    (* no change for this long = partner or link lost *)
  END_VAR
  VAR_OUTPUT
    CommOK    : BOOL;    (* partner proven alive within the last Timeout *)
    CommFault : BOOL;    (* no change for Timeout: raise an alarm *)
  END_VAR
  VAR
    (* Add your internal variables here. *)
    SilentTimer : TON;
  END_VAR

  (* TODO: replace these placeholder lines with your logic. *)
  CommOK := FALSE;
  CommFault := FALSE;
END_FUNCTION_BLOCK

PROGRAM PumpDiagnostics
  VAR (* I/O *)
    PumpRunFb AT %IX0.0 : BOOL;   (* P-301 contactor auxiliary contact: TRUE = running *)
    FrozenAlm AT %QX0.0 : BOOL;   (* a transmitter looks frozen *)
    CommAlm   AT %QX0.1 : BOOL;   (* a heartbeat has been lost *)
  END_VAR
  VAR (* values from the analog input blocks (Lab 14-1) and the communication
         driver (Module 17). Here the test writes them directly. *)
    PT301        : REAL;   (* P-301 discharge pressure, bar *)
    FT302        : REAL;   (* P-301 discharge flow, m3/h *)
    PartnerHB    : INT;    (* heartbeat counter from PLC-2: it adds 1 every second *)
    ScadaHB      : INT;    (* watchdog counter the SCADA server writes every few seconds *)
    HeartbeatOut : INT;    (* this PLC's own heartbeat, read by PLC-2 and SCADA *)
  END_VAR
  VAR
    PT301Chk   : FB_FrozenSignal;
    FT302Chk   : FB_FrozenSignal;
    PartnerMon : FB_Heartbeat;
    ScadaMon   : FB_Heartbeat;
    (* add a timer for HeartbeatOut here *)
  END_VAR

  (* The calls below are complete: do not change them.
     A running pump's discharge pressure and flow always move a little
     (pulsation, turbulence). When the pump is stopped they may be dead
     steady, so the check only runs while the pump runs. *)
  PT301Chk(PV := PT301, Tolerance := 0.05, FreezeTime := T#10s, Enable := PumpRunFb);
  FT302Chk(PV := FT302, Tolerance := 0.5, FreezeTime := T#20s, Enable := PumpRunFb);

  (* PLC-2 counts once a second: a 3 s timeout rides through one lost or
     late update without a false fault. SCADA writes more slowly and less
     regularly: 10 s. *)
  PartnerMon(Counter := PartnerHB, Timeout := T#3s);
  ScadaMon(Counter := ScadaHB, Timeout := T#10s);

  FrozenAlm := PT301Chk.Frozen OR FT302Chk.Frozen;
  CommAlm := PartnerMon.CommFault OR ScadaMon.CommFault;

  (* TODO: this PLC's own heartbeat. HeartbeatOut starts at 0 and adds 1
     every second; after 32767 it goes back to 0. Count in HeartbeatOut
     itself (the test presets it to check the wrap). Replace the placeholder. *)
  HeartbeatOut := 0;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : PumpDiagnostics;
  END_RESOURCE
END_CONFIGURATION
