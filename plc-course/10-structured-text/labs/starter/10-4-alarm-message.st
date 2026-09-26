(* Lab 10-4: Build an alarm message string for the operator.
   Module 10 (Structured Text). STARTER - the declarations are done for you;
   write the logic where it says TODO, then run:
     python3 tools/plctest.py 10-structured-text/labs/starter/10-4-alarm-message.st *)

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
  VAR (* suggested working variables *)
    Tenths    : INT;      (* PV rounded to whole tenths *)
    ValueText : STRING;   (* PV formatted with one decimal place *)
    StateText : STRING;   (* 'HIGH HIGH', 'HIGH', ... *)
  END_VAR

  (* TODO:
     1. Format PV with one decimal place into ValueText, using REAL_TO_INT,
        integer division, MOD and INT_TO_STRING. Watch the sign.
     2. Build Message with CONCAT, highest priority first:
        BadPV, HiHi, LoLo, Hi, Lo, otherwise ''. *)
  Message := CONCAT(TagName, ' TODO');
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : AlarmMessage;
  END_RESOURCE
END_CONFIGURATION
