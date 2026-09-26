(* Lab 23-2: Subtle faults - drum filling station.
   Module 23 (Commissioning and troubleshooting). REFERENCE SOLUTION - try the lab yourself first.

   The starter's three faults are fixed here and marked "FIX 1", "FIX 2", "FIX 3".
   None of them shows up in a quick bench test: one needs the HMI, one needs a
   busy shift and one needs a power cut in the middle of a fill. *)

TYPE
  E_FillStep : (Idle, Filling, Done);
END_TYPE

PROGRAM DrumFiller
  VAR (* I/O - addresses follow the OpenPLC convention *)
    StartPB       AT %IX0.0 : BOOL;  (* Start push-button, NO *)
    StopPB_NC     AT %IX0.1 : BOOL;  (* Stop push-button, NC: TRUE while NOT pressed *)
    DrumPresentPX AT %IX0.2 : BOOL;  (* Proximity switch: a drum is in position on the scale *)
    WeightRaw     AT %IW0   : INT;   (* Scale transmitter via 4-20 mA input: 0..27648 = 0..300 kg *)
    FillValve     AT %QX0.0 : BOOL;  (* Fill valve solenoid, spring-return: de-energised = closed *)
    DoneLamp      AT %QX0.1 : BOOL;  (* White lamp: drum full, remove it *)
  END_VAR
  VAR (* HMI commands: the HMI writes TRUE, the PLC clears them (momentary) *)
    HmiStartCmd      : BOOL;  (* HMI "Start fill" button *)
    HmiResetCountCmd : BOOL;  (* HMI "Reset shift count" button *)
  END_VAR
  VAR (* HMI display values *)
    Weight_kg : REAL;  (* gross weight on the scale *)
    TotalKg   : DINT;  (* nominal kg filled this shift = DrumCount x 200 kg *)
  END_VAR
  VAR RETAIN (* must survive a power cut *)
    DrumCount : INT;   (* drums filled this shift *)
  END_VAR
  VAR (* internal *)
    (* FIX 3 (part 1): the step is no longer declared RETAIN. There is no
       reason to remember it through a power cut. But see the start-up section:
       some platforms keep every value anyway, so the code must not rely on it. *)
    FillStep    : E_FillStep := Idle;
    StartupDone : BOOL;  (* non-retentive: FALSE again after every PLC start *)
    StartReq    : BOOL;
    Tare_kg     : REAL;  (* weight of the empty drum, captured at the start *)
    Net_kg      : REAL;  (* product added so far *)
  END_VAR
  VAR CONSTANT
    TargetNet_kg   : REAL := 200.0;  (* product per drum *)
    EmptyMax_kg    : REAL := 50.0;   (* heavier than this = not an empty drum *)
    DrumNominal_kg : INT := 200;     (* used for the shift total *)
  END_VAR

  (* ---- 0. Start-up ----------------------------------------------------------
     FIX 3 (part 2): on the first scan after every PLC start the sequence is
     forced to Idle, whatever the memory holds, BEFORE any logic that drives an
     output. A fill interrupted by a power cut is never resumed automatically:
     the tare was lost and nobody has checked the drum. The retained shift count
     is deliberately left alone. *)
  IF NOT StartupDone THEN
    FillStep := Idle;
    StartupDone := TRUE;
  END_IF;

  (* ---- 1. Scale: raw counts to kilograms (Module 14) *)
  Weight_kg := INT_TO_REAL(WeightRaw) * 300.0 / 27648.0;

  (* ---- 2. Start request from the panel push-button or the HMI *)
  StartReq := StartPB OR HmiStartCmd;

  (* ---- 3. Fill sequence *)
  CASE FillStep OF
    Idle:
      (* Start only with a healthy stop circuit and an EMPTY drum in place *)
      IF StartReq AND StopPB_NC AND DrumPresentPX AND (Weight_kg < EmptyMax_kg) THEN
        Tare_kg := Weight_kg;
        Net_kg := 0.0;
        FillStep := Filling;
      END_IF;

    Filling:
      Net_kg := Weight_kg - Tare_kg;
      IF NOT StopPB_NC OR NOT DrumPresentPX THEN
        FillStep := Idle;                      (* abort: this drum is not counted *)
      ELSIF Net_kg >= TargetNet_kg THEN
        DrumCount := DrumCount + 1;
        FillStep := Done;
      END_IF;

    Done:
      IF NOT DrumPresentPX THEN            (* full drum taken away *)
        FillStep := Idle;
      END_IF;
  END_CASE;

  (* ---- 4. Shift totals *)
  IF HmiResetCountCmd THEN
    DrumCount := 0;
  END_IF;
  (* FIX 2: convert to DINT FIRST, then multiply. In the starter the product
     DrumCount * 200 was an INT and overflowed at 164 drums (32 800 kg), before
     INT_TO_DINT ever saw it. *)
  TotalKg := INT_TO_DINT(DrumCount) * INT_TO_DINT(DrumNominal_kg);

  (* ---- 5. Momentary HMI commands are cleared by the PLC.
     FIX 1: this happens AFTER the logic that reads them. The HMI writes between
     scans, so clearing them at the top of the program (as the starter did)
     wiped every command before the logic could see it. Clearing them every scan,
     accepted or not, means a refused command is never remembered. *)
  HmiStartCmd := FALSE;
  HmiResetCountCmd := FALSE;

  (* ---- 6. Outputs, written once, from the step *)
  FillValve := (FillStep = Filling);
  DoneLamp := (FillStep = Done);
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : DrumFiller;
  END_RESOURCE
END_CONFIGURATION
