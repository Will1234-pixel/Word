(* Lab 16-3: Frozen-signal and heartbeat diagnostics.
   Module 16 (Alarms, diagnostics and fault handling). REFERENCE SOLUTION - try the lab yourself first.

   Two small diagnostic blocks that catch faults a range check cannot see:
     FB_FrozenSignal  a transmitter value that stops moving while the
                      process is running (stuck sensor, transmitter left in
                      fixed-current mode, frozen communication value)
     FB_Heartbeat     a partner's heartbeat counter that stops changing
                      (partner stopped, or the link between us is down)
   The program also produces this PLC's own heartbeat for its partners. *)

FUNCTION_BLOCK FB_FrozenSignal
  (* ------------------------------------------------------------------
     FB_FrozenSignal - "has this value stopped moving?"

     Behaviour   While Enable is TRUE, Frozen goes TRUE when PV has stayed
                 within +/- Tolerance of a reference value for FreezeTime.
                 The reference is the PV at the last significant move (or
                 when Enable came on), NOT the previous scan's PV, so a
                 slow drift adds up and counts as movement. Any move of
                 more than Tolerance takes a new reference, restarts the
                 time and clears Frozen. Enable FALSE: no check, Frozen
                 FALSE. Frozen does not latch.
     Assumptions A live signal normally moves by more than Tolerance
                 within FreezeTime while Enable is TRUE (noise, pulsation,
                 normal process variation).
     Version     1.0  first release
     ------------------------------------------------------------------ *)
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
    RefValue   : REAL;   (* PV at the last significant move *)
    Moved      : BOOL;   (* PV moved more than Tolerance away from RefValue this scan *)
    StillTimer : TON;    (* time since the last significant move *)
  END_VAR

  IF NOT Enable THEN
    RefValue := PV;      (* keep the reference fresh while the check is off *)
    Moved := FALSE;
  ELSE
    Moved := ABS(PV - RefValue) > Tolerance;
    IF Moved THEN
      RefValue := PV;    (* new reference: measure the next move from here *)
    END_IF;
  END_IF;

  (* IN goes FALSE for one scan on every move, which restarts the timer.
     While disabled the timer is held at zero, so the full FreezeTime
     starts again when Enable comes back. *)
  StillTimer(IN := Enable AND NOT Moved, PT := FreezeTime);
  Frozen := StillTimer.Q;
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_Heartbeat
  (* ------------------------------------------------------------------
     FB_Heartbeat - supervise a heartbeat counter from a partner.

     Behaviour   Any change of Counter from one scan to the next is a
                 heartbeat: up, down, wrap-around or a reset to 0 after the
                 partner restarts. CommFault = no change for Timeout
                 (counted from power-up until the first change). CommOK =
                 a change has been seen within the last Timeout; it is
                 FALSE after power-up until the first change, because the
                 first value read is not proof that the partner is alive.
     Version     1.0  first release
     ------------------------------------------------------------------ *)
  VAR_INPUT
    Counter   : INT;     (* heartbeat counter received from the partner *)
    Timeout   : TIME;    (* no change for this long = partner or link lost *)
  END_VAR
  VAR_OUTPUT
    CommOK    : BOOL;    (* partner proven alive within the last Timeout *)
    CommFault : BOOL;    (* no change for Timeout: raise an alarm *)
  END_VAR
  VAR
    Started     : BOOL;  (* FALSE until the first call *)
    LastCounter : INT;   (* Counter on the previous scan *)
    Changed     : BOOL;  (* Counter changed since the previous scan *)
    SeenChange  : BOOL;  (* at least one change since power-up *)
    SilentTimer : TON;   (* time since the last change *)
  END_VAR

  IF NOT Started THEN
    LastCounter := Counter;   (* first scan: there is no earlier value to compare with *)
    Started := TRUE;
  END_IF;

  (* "Different", not "greater": a counter that wraps from 32767 to -32768,
     or restarts from 0, is still alive. *)
  Changed := Counter <> LastCounter;
  LastCounter := Counter;
  IF Changed THEN
    SeenChange := TRUE;
  END_IF;

  SilentTimer(IN := NOT Changed, PT := Timeout);
  CommFault := SilentTimer.Q;
  CommOK := SeenChange AND NOT SilentTimer.Q;
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
    BeatTimer  : TON;
  END_VAR

  (* A running pump's discharge pressure and flow always move a little
     (pulsation, turbulence). When the pump is stopped they may be dead
     steady, so the check only runs while the pump runs. *)
  PT301Chk(PV := PT301, Tolerance := 0.05, FreezeTime := T#10s, Enable := PumpRunFb);
  FT302Chk(PV := FT302, Tolerance := 0.5, FreezeTime := T#20s, Enable := PumpRunFb);

  (* PLC-2 counts once a second: 3 s allows two missed updates.
     SCADA writes more slowly and less regularly: 10 s. *)
  PartnerMon(Counter := PartnerHB, Timeout := T#3s);
  ScadaMon(Counter := ScadaHB, Timeout := T#10s);

  FrozenAlm := PT301Chk.Frozen OR FT302Chk.Frozen;
  CommAlm := PartnerMon.CommFault OR ScadaMon.CommFault;

  (* Our own heartbeat: add 1 every second. The explicit wrap keeps the
     counter out of integer overflow, which some platforms report as a
     fault. For the receiver any change is a heartbeat, so the jump from
     32767 back to 0 is fine. *)
  BeatTimer(IN := NOT BeatTimer.Q, PT := T#1s);
  IF BeatTimer.Q THEN
    IF HeartbeatOut >= 32767 THEN
      HeartbeatOut := 0;
    ELSE
      HeartbeatOut := HeartbeatOut + 1;
    END_IF;
  END_IF;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : PumpDiagnostics;
  END_RESOURCE
END_CONFIGURATION
