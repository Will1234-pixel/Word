(* Lab 23-2: Subtle faults - drum filling station.
   Module 23 (Commissioning and troubleshooting). STARTER - this program passed
   its bench test and has been running on site for a month. It compiles and it
   mostly works, but the site has reported three faults (see the lab sheet in
   the README) and the acceptance test fails. Run it to see the failures:
     python3 tools/plctest.py 23-commissioning-and-troubleshooting/labs/starter/23-2-subtle-faults.st
   Copy it to your own folder, find the three root causes and fix them. Keep
   every name in the interface table; change as little as you can. *)

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
    DrumCount : INT;         (* drums filled this shift *)
    FillStep  : E_FillStep;  (* where the sequence is *)
  END_VAR
  VAR (* internal *)
    StartReq : BOOL;
    Tare_kg  : REAL;  (* weight of the empty drum, captured at the start *)
    Net_kg   : REAL;  (* product added so far *)
  END_VAR
  VAR CONSTANT
    TargetNet_kg   : REAL := 200.0;  (* product per drum *)
    EmptyMax_kg    : REAL := 50.0;   (* heavier than this = not an empty drum *)
    DrumNominal_kg : INT := 200;     (* used for the shift total *)
  END_VAR

  (* ---- 0. Housekeeping: HMI buttons are momentary, so the PLC clears them.
     (Added after an HMI lost its connection with a command stuck TRUE.) *)
  HmiStartCmd := FALSE;
  HmiResetCountCmd := FALSE;

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

  (* ---- 4. Shift totals. TotalKg is a DINT, so it cannot overflow. *)
  IF HmiResetCountCmd THEN
    DrumCount := 0;
  END_IF;
  TotalKg := INT_TO_DINT(DrumCount * DrumNominal_kg);

  (* ---- 5. Outputs, written once, from the step *)
  FillValve := (FillStep = Filling);
  DoneLamp := (FillStep = Done);
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : DrumFiller;
  END_RESOURCE
END_CONFIGURATION
