(* Lab 10-4: Build an alarm message string for the operator.
   Module 10 (Structured Text). REFERENCE SOLUTION - try the lab yourself first. *)

PROGRAM AlarmMessage
  VAR (* interface *)
    TagName : STRING := 'TT-104';   (* instrument tag *)
    Units   : STRING := 'degC';     (* engineering units *)
    PV      : REAL;                 (* process value, -3000.0 .. 3000.0 *)
    HiHi    : BOOL;                 (* alarm states from the alarm logic *)
    Hi      : BOOL;
    Lo      : BOOL;
    LoLo    : BOOL;
    BadPV   : BOOL;                 (* signal fault: the value cannot be trusted *)
    Message : STRING;               (* text for the alarm banner, '' when healthy *)
  END_VAR
  VAR
    Tenths    : INT;      (* PV rounded to tenths: 87.46 -> 875 *)
    Sign      : STRING;   (* '-' or '' *)
    ValueText : STRING;   (* PV formatted with one decimal, e.g. '-0.4' *)
    StateText : STRING;   (* 'HIGH HIGH', 'HIGH', ... *)
  END_VAR

  (* 1. Format PV with exactly one decimal place.
        REAL_TO_STRING is no use here: MATIEC prints 87.4 as '87.40000153',
        and other platforms use other formats. Work in whole tenths instead. *)
  Tenths := REAL_TO_INT(PV * 10.0);      (* rounds to the nearest tenth *)
  IF Tenths < 0 THEN
    (* Take the sign off first. Otherwise -0.4 gives Tenths / 10 = 0 and the
       minus sign is lost, and MOD of a negative number is negative. *)
    Sign := '-';
    Tenths := -Tenths;
  ELSE
    Sign := '';                          (* -0.04 rounds to 0 and prints as 0.0 *)
  END_IF;
  ValueText := CONCAT(Sign, INT_TO_STRING(Tenths / 10), '.', INT_TO_STRING(Tenths MOD 10));

  (* 2. Choose the text for the most important active state. The order of the
        ELSIF chain IS the priority: the first TRUE condition wins. The
        trip-level alarms (HiHi, LoLo) come before the pre-alarms (Hi, Lo),
        because a latched low-low still matters more than a new high. *)
  IF BadPV THEN
    Message := CONCAT(TagName, ' BAD PV');   (* no value: it would be meaningless *)
  ELSE
    IF HiHi THEN
      StateText := 'HIGH HIGH';
    ELSIF LoLo THEN
      StateText := 'LOW LOW';
    ELSIF Hi THEN
      StateText := 'HIGH';
    ELSIF Lo THEN
      StateText := 'LOW';
    ELSE
      StateText := '';
    END_IF;

    IF StateText = '' THEN
      Message := '';                         (* healthy: clear the banner *)
    ELSE
      Message := CONCAT(TagName, ' ', StateText, ' ', ValueText, ' ', Units);
    END_IF;
  END_IF;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : AlarmMessage;
  END_RESOURCE
END_CONFIGURATION
