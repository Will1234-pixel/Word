(* Lab 20-2: Cause-and-effect matrix for feed drum V-301 and feed pump P-301 -
   latched trips, reset only when healthy, first-out indication, and
   time-limited maintenance bypasses with a bypass-active alarm.
   Module 20 (Functional safety). STARTER - the interface is done for you;
   write the logic where it says TODO, then run:
     python3 tools/plctest.py 20-functional-safety/labs/starter/20-2-cause-and-effect.st

   TRAINING EXERCISE ONLY. A real shutdown matrix is implemented in a
   certified safety logic solver from an approved SRS and C&E, and is
   verified and validated by competent people under IEC 61511. Nothing here
   is a design for a real plant.

   The matrix (X = the cause trips the effect; the lesson has the full table):

                          E1 XV-301   E2 P-301   E3 XV-302   E4 XV-303
                          close       stop       close       open (blowdown)
   C1 HS-300   ESD PB        X           X          X           X        never bypassed
   C2 LSHH-301 level HH      X
   C3 LSLL-301 level LL                  X          X                    2 s delay
   C4 PSHH-301 V-301 PHH     X                                  X
   C5 PSHH-302 P-301 PHH                 X
   C6 TSHH-303 bearing THH               X                               5 s delay *)

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
    BYPASS_TIME : TIME := T#60s;   (* shortened for the exercise; real limits come from the SRS *)
  END_VAR
  (* TODO: add your own function block(s), constants and internal variables.
     Remember that MATIEC cannot make an ARRAY OF TON or an array of your own
     FB instances: use six named instances. *)

  (* TODO: replace these placeholder lines with your logic:
     1. cause processing: delay, bypass (key, rising-edge request, 60 s
        expiry, request removed, key off), latch, reset only when healthy
        or bypassed, on the rising edge of ResetPB,
     2. the matrix: each effect trips if any latched cause has an X in its column,
     3. outputs (de-energise to trip), TripAlm, BypassAlm and FirstOut. *)
  CauseLatched[1] := FALSE;
  Bypassed[1] := FALSE;
  FirstOut := 0;
  XV301_Sol := FALSE;
  P301_Permit := FALSE;
  XV302_Sol := FALSE;
  XV303_Sol := FALSE;
  TripAlm := FALSE;
  BypassAlm := FALSE;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : FeedDrumCE;
  END_RESOURCE
END_CONFIGURATION
