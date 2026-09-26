(* Lab 06-1: One-button floodlight toggle (push-on / push-off).
   Module 06 (Edge detection and one-shots). REFERENCE SOLUTION - try the lab yourself first. *)

PROGRAM ToggleLamp
  VAR (* I/O - addresses follow the OpenPLC convention *)
    LightPB      AT %IX0.0 : BOOL;  (* Floodlight push-button, NO: TRUE while pressed *)
    LightsEnable AT %IX0.1 : BOOL;  (* Gatehouse key switch: TRUE = bay lighting enabled *)
    Floodlight   AT %QX0.0 : BOOL;  (* Floodlight contactor coil *)
  END_VAR
  VAR (* internal *)
    PressEdge : R_TRIG;             (* one-shot: TRUE for one scan when LightPB is pressed *)
  END_VAR

  (* 1. Detect the press. The edge detector is called on EVERY scan and never
        inside an IF, so its memory always follows the button, even while the
        lighting is disabled. A press that began while disabled has already
        been "used up" by the time the key switch comes back on. *)
  PressEdge(CLK := LightPB);

  (* 2. Act on the one-scan pulse, never on the level of the button.
        Holding the button keeps PressEdge.Q FALSE after the first scan,
        so the lamp cannot flicker. The disable wins over everything. *)
  IF NOT LightsEnable THEN
    Floodlight := FALSE;
  ELSIF PressEdge.Q THEN
    Floodlight := NOT Floodlight;
  END_IF;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : ToggleLamp;
  END_RESOURCE
END_CONFIGURATION
