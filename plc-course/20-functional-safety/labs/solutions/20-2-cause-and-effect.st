(* Lab 20-2: Cause-and-effect matrix for feed drum V-301 and feed pump P-301 -
   latched trips, reset only when healthy, first-out indication, and
   time-limited maintenance bypasses with a bypass-active alarm.
   Module 20 (Functional safety). REFERENCE SOLUTION - try the lab yourself first.

   TRAINING EXERCISE ONLY. A real shutdown matrix is implemented in a
   certified safety logic solver from an approved SRS and C&E, and is
   verified and validated by competent people under IEC 61511. Nothing here
   is a design for a real plant.

   The matrix (X = the cause trips the effect; see the lesson for the table):

                          E1 XV-301   E2 P-301   E3 XV-302   E4 XV-303
                          close       stop       close       open (blowdown)
   C1 HS-300   ESD PB        X           X          X           X
   C2 LSHH-301 level HH      X
   C3 LSLL-301 level LL                  X          X                    2 s
   C4 PSHH-301 V-301 PHH     X                                  X
   C5 PSHH-302 P-301 PHH                 X
   C6 TSHH-303 bearing THH               X                               5 s

   Structure: one FB instance per cause (delay, bypass, latch, reset), then
   the matrix as a constant table, then one loop that ORs each column. The
   table in the code is laid out exactly like the drawing, so a reviewer can
   check it cell by cell. *)

FUNCTION_BLOCK FB_TripCause
  VAR_INPUT
    Healthy    : BOOL;   (* trip contact, NC: TRUE = healthy *)
    TripDelay  : TIME;   (* confirmation delay; T#0s = trip at once *)
    Bypassable : BOOL;   (* FALSE for causes that must never be bypassed *)
    BypassKey  : BOOL;   (* bypass key switch: TRUE = bypassing permitted *)
    BypassReq  : BOOL;   (* bypass request from the HMI (maintained) *)
    BypassTime : TIME;   (* a bypass ends by itself after this time *)
    ResetCmd   : BOOL;   (* one-scan reset pulse *)
  END_VAR
  VAR_OUTPUT
    Latched    : BOOL;   (* the cause has tripped and is not yet reset *)
    Bypassed   : BOOL;   (* a maintenance bypass is active *)
  END_VAR
  VAR
    DelayTimer  : TON;
    BypassTimer : TON;
    ReqEdge     : R_TRIG;
    Present     : BOOL;  (* trip condition confirmed (after the delay) *)
  END_VAR

  (* 1. Bypass. It starts only on a new request (rising edge) with the key
        on, so an expired bypass cannot restart itself while the request
        is still set. It ends when the time is up, the request is removed
        or the key is turned off - whichever comes first. *)
  ReqEdge(CLK := BypassReq);
  IF ReqEdge.Q AND BypassKey AND Bypassable THEN
    Bypassed := TRUE;
  END_IF;
  BypassTimer(IN := Bypassed, PT := BypassTime);
  IF BypassTimer.Q OR NOT BypassReq OR NOT BypassKey OR NOT Bypassable THEN
    Bypassed := FALSE;
  END_IF;

  (* 2. Confirmation delay: the contact must be open for the whole delay.
        A zero delay trips on the scan the contact opens. The delay keeps
        timing during a bypass, so a contact that has been open all through
        the bypass trips on the scan the bypass ends. *)
  DelayTimer(IN := NOT Healthy, PT := TripDelay);
  Present := NOT Healthy AND ((TripDelay = T#0s) OR DelayTimer.Q);

  (* 3. Latch and reset. A trip always wins over a reset. A reset clears
        the latch only if the cause is healthy - or bypassed, which is how
        maintenance clears a trip from a device it is working on. Applying
        a bypass does not clear a latch by itself. *)
  IF Present AND NOT Bypassed THEN
    Latched := TRUE;
  ELSIF ResetCmd AND (Healthy OR Bypassed) THEN
    Latched := FALSE;
  END_IF;
END_FUNCTION_BLOCK

PROGRAM FeedDrumCE
  VAR (* inputs: trip contacts are NC, TRUE = healthy *)
    HS300_NC    AT %IX0.0 : BOOL;  (* C1 ESD push-button *)
    LSHH301_NC  AT %IX0.1 : BOOL;  (* C2 V-301 level high-high *)
    LSLL301_NC  AT %IX0.2 : BOOL;  (* C3 V-301 level low-low *)
    PSHH301_NC  AT %IX0.3 : BOOL;  (* C4 V-301 pressure high-high *)
    PSHH302_NC  AT %IX0.4 : BOOL;  (* C5 P-301 discharge pressure high-high *)
    TSHH303_NC  AT %IX0.5 : BOOL;  (* C6 P-301 bearing temperature high-high *)
    ResetPB     AT %IX0.6 : BOOL;  (* reset push-button, NO *)
    BypassKey   AT %IX0.7 : BOOL;  (* bypass key switch, TRUE = bypassing permitted *)
  END_VAR
  VAR (* outputs: de-energise to trip *)
    XV301_Sol   AT %QX0.0 : BOOL;  (* E1 inlet valve solenoid: FALSE = close *)
    P301_Permit AT %QX0.1 : BOOL;  (* E2 pump run permissive: FALSE = stop *)
    XV302_Sol   AT %QX0.2 : BOOL;  (* E3 outlet valve solenoid: FALSE = close *)
    XV303_Sol   AT %QX0.3 : BOOL;  (* E4 blowdown valve solenoid: FALSE = valve opens *)
    TripAlm     AT %QX0.4 : BOOL;  (* common trip alarm: any cause latched *)
    BypassAlm   AT %QX0.5 : BOOL;  (* any bypass active *)
  END_VAR
  VAR (* HMI interface *)
    BypReq       : ARRAY[1..6] OF BOOL;   (* bypass requests, one per cause *)
    Bypassed     : ARRAY[1..6] OF BOOL;   (* bypass active, one per cause *)
    CauseLatched : ARRAY[1..6] OF BOOL;   (* latched trip, one per cause *)
    FirstOut     : INT;                   (* first cause since the last full reset; 0 = none *)
  END_VAR
  VAR CONSTANT
    (* The cause-and-effect matrix. Row = cause C1..C6, column = effect E1..E4.
                  E1     E2     E3     E4 *)
    CE : ARRAY[1..6, 1..4] OF BOOL :=
                 [TRUE,  TRUE,  TRUE,  TRUE,     (* C1 HS-300   ESD push-button *)
                  TRUE,  FALSE, FALSE, FALSE,    (* C2 LSHH-301 level HH        *)
                  FALSE, TRUE,  TRUE,  FALSE,    (* C3 LSLL-301 level LL        *)
                  TRUE,  FALSE, FALSE, TRUE,     (* C4 PSHH-301 V-301 press HH  *)
                  FALSE, TRUE,  FALSE, FALSE,    (* C5 PSHH-302 P-301 press HH  *)
                  FALSE, TRUE,  FALSE, FALSE];   (* C6 TSHH-303 bearing temp HH *)
    BYPASS_TIME : TIME := T#60s;   (* shortened for the exercise; real limits come from the SRS *)
  END_VAR
  VAR
    (* One instance per line: OpenPLC's compiler can crash on a list
       such as 'Cause1, Cause2 : FB_TripCause;' (see Appendix E). *)
    Cause1 : FB_TripCause;
    Cause2 : FB_TripCause;
    Cause3 : FB_TripCause;
    Cause4 : FB_TripCause;
    Cause5 : FB_TripCause;
    Cause6 : FB_TripCause;
    ResetEdge  : R_TRIG;
    EffectTrip : ARRAY[1..4] OF BOOL;
    AnyLatched : BOOL;
    AnyBypass  : BOOL;
    i, j       : INT;
  END_VAR

  ResetEdge(CLK := ResetPB);

  (* 1. Cause processing. MATIEC cannot make an array of FB instances, so
        there are six named instances; each copies its result into the
        arrays that the matrix loop and the HMI use. *)
  Cause1(Healthy := HS300_NC, TripDelay := T#0s, Bypassable := FALSE,
         BypassKey := BypassKey, BypassReq := BypReq[1], BypassTime := BYPASS_TIME,
         ResetCmd := ResetEdge.Q);
  Cause2(Healthy := LSHH301_NC, TripDelay := T#0s, Bypassable := TRUE,
         BypassKey := BypassKey, BypassReq := BypReq[2], BypassTime := BYPASS_TIME,
         ResetCmd := ResetEdge.Q);
  Cause3(Healthy := LSLL301_NC, TripDelay := T#2s, Bypassable := TRUE,
         BypassKey := BypassKey, BypassReq := BypReq[3], BypassTime := BYPASS_TIME,
         ResetCmd := ResetEdge.Q);
  Cause4(Healthy := PSHH301_NC, TripDelay := T#0s, Bypassable := TRUE,
         BypassKey := BypassKey, BypassReq := BypReq[4], BypassTime := BYPASS_TIME,
         ResetCmd := ResetEdge.Q);
  Cause5(Healthy := PSHH302_NC, TripDelay := T#0s, Bypassable := TRUE,
         BypassKey := BypassKey, BypassReq := BypReq[5], BypassTime := BYPASS_TIME,
         ResetCmd := ResetEdge.Q);
  Cause6(Healthy := TSHH303_NC, TripDelay := T#5s, Bypassable := TRUE,
         BypassKey := BypassKey, BypassReq := BypReq[6], BypassTime := BYPASS_TIME,
         ResetCmd := ResetEdge.Q);

  CauseLatched[1] := Cause1.Latched;  Bypassed[1] := Cause1.Bypassed;
  CauseLatched[2] := Cause2.Latched;  Bypassed[2] := Cause2.Bypassed;
  CauseLatched[3] := Cause3.Latched;  Bypassed[3] := Cause3.Bypassed;
  CauseLatched[4] := Cause4.Latched;  Bypassed[4] := Cause4.Bypassed;
  CauseLatched[5] := Cause5.Latched;  Bypassed[5] := Cause5.Bypassed;
  CauseLatched[6] := Cause6.Latched;  Bypassed[6] := Cause6.Bypassed;

  (* 2. The matrix: an effect trips if any latched cause has an X in its
        column. *)
  FOR j := 1 TO 4 DO
    EffectTrip[j] := FALSE;
    FOR i := 1 TO 6 DO
      IF CauseLatched[i] AND CE[i, j] THEN
        EffectTrip[j] := TRUE;
      END_IF;
    END_FOR;
  END_FOR;

  (* 3. Outputs, de-energise to trip. A reset re-energises them, but that
        only gives the permission back: the BPCS must still restart the
        pump and reopen the valves with new commands. *)
  XV301_Sol := NOT EffectTrip[1];
  P301_Permit := NOT EffectTrip[2];
  XV302_Sol := NOT EffectTrip[3];
  XV303_Sol := NOT EffectTrip[4];

  (* 4. Common alarms and first-out. FirstOut is captured when a cause
        latches while nothing else is latched; if several latch in the same
        scan the lowest cause number is shown. It holds until a reset
        leaves no cause latched. *)
  AnyLatched := FALSE;
  AnyBypass := FALSE;
  FOR i := 1 TO 6 DO
    AnyLatched := AnyLatched OR CauseLatched[i];
    AnyBypass := AnyBypass OR Bypassed[i];
  END_FOR;
  TripAlm := AnyLatched;
  BypassAlm := AnyBypass;

  IF NOT AnyLatched THEN
    FirstOut := 0;
  ELSIF FirstOut = 0 THEN
    FOR i := 1 TO 6 DO
      IF CauseLatched[i] THEN
        FirstOut := i;
        EXIT;
      END_IF;
    END_FOR;
  END_IF;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : FeedDrumCE;
  END_RESOURCE
END_CONFIGURATION
