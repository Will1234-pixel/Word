(* Lab 12-2: Event log - a ring buffer of structures.
   Module 12 (Data structures). REFERENCE SOLUTION - try the lab yourself first.

   A pump station keeps its last ten events (trips, alarms, operator actions)
   in the PLC, so that the HMI can show them and a historian can collect them.
   Each event is a structure: a code and a time stamp in milliseconds.

   The log is a RING BUFFER: entries are written into ten fixed slots,
   EventLog[0], [1], ... [9], then [0] again, and only the index Newest moves.
   Nothing is ever shifted, so logging costs the same however full the log
   is, and a reader always finds an entry in the slot where it was written.
   When the log is full, each new event overwrites the oldest one.

   Arithmetic used: next slot = (Newest + 1) MOD 10, and the slot of the event
   "Age" events back = (Newest - Age + 10) MOD 10. The "+ 10" matters: MOD
   keeps the sign of the dividend, so (0 - 1) MOD 10 is -1, not 9. *)

TYPE
  ST_Event :
  STRUCT
    Code  : INT;    (* event code, 1..32767; 0 = empty entry *)
    Stamp : DINT;   (* ms since power-up when the event was logged *)
  END_STRUCT;
END_TYPE


PROGRAM EventLogger
  VAR (* requests from the rest of the program and the HMI *)
    NewCode  : INT;                      (* code of the event to log *)
    LogReq   : BOOL;                     (* TRUE = log NewCode now; the logger clears it *)
    ClearCmd : BOOL;                     (* TRUE = empty the log; the logger clears it *)
    ViewAge  : INT;                      (* HMI: 0 = newest event, 1 = the one before, ... *)
  END_VAR
  VAR (* the log - keep these names *)
    EventLog : ARRAY[0..9] OF ST_Event;  (* the ring: ten fixed slots *)
    Newest   : INT;                      (* slot of the newest entry (0 while the log is empty) *)
    Count    : INT;                      (* valid entries, 0..10 *)
    Total    : DINT;                     (* events logged since power-up or the last clear *)
    View     : ST_Event;                 (* the event ViewAge events back from the newest *)
    ViewValid : BOOL;                    (* TRUE when View holds a real event *)
  END_VAR
  VAR (* clock - given, do not change *)
    UpTime   : TON;
    NowMs    : DINT;                     (* ms since power-up *)
  END_VAR
  VAR CONSTANT
    LOG_SIZE : INT := 10;                (* keep in step with ARRAY[0..9] *)
    NO_EVENT : ST_Event := (Code := 0, Stamp := 0);
  END_VAR
  VAR
    i        : INT;
    ViewSlot : INT;
  END_VAR

  (* ---- 0. Millisecond clock (given). TIME_TO_LREAL gives seconds in
     MATIEC and milliseconds in CODESYS; dividing by TIME_TO_LREAL(T#1s)
     gives seconds on both, and * 1000.0 makes milliseconds. The TON's ET
     stops at PT, so this clock is good for 24 days: fine for a lab. ---- *)
  UpTime(IN := TRUE, PT := T#24d);
  NowMs := LREAL_TO_DINT(TIME_TO_LREAL(UpTime.ET) / TIME_TO_LREAL(T#1s) * 1000.0);

  (* ---- 1. Clear: empty every slot and start again at slot 0. ---- *)
  IF ClearCmd THEN
    FOR i := 0 TO LOG_SIZE - 1 DO
      EventLog[i] := NO_EVENT;           (* whole-structure assignment *)
    END_FOR;
    Newest := 0;
    Count := 0;
    Total := 0;
    ClearCmd := FALSE;
  END_IF;

  (* ---- 2. Log one event per request. Codes 0 and below are not events:
     the request is dropped (and still cleared). ---- *)
  IF LogReq THEN
    IF NewCode > 0 THEN
      IF Count > 0 THEN
        Newest := (Newest + 1) MOD LOG_SIZE;   (* step on, wrapping 9 -> 0 *)
      END_IF;                                  (* the first entry goes into slot 0 *)
      EventLog[Newest].Code := NewCode;
      EventLog[Newest].Stamp := NowMs;
      IF Count < LOG_SIZE THEN
        Count := Count + 1;                    (* once full, Count stays 10 and the
                                                  oldest entry has just been overwritten *)
      END_IF;
      Total := Total + 1;
    END_IF;
    LogReq := FALSE;
  END_IF;

  (* ---- 3. View for the HMI, every scan. ViewAge comes from the HMI, so it
     is checked against Count before it is used to find a slot. ---- *)
  IF ViewAge >= 0 AND ViewAge < Count THEN
    ViewSlot := (Newest - ViewAge + LOG_SIZE) MOD LOG_SIZE;
    View := EventLog[ViewSlot];
    ViewValid := TRUE;
  ELSE
    View := NO_EVENT;
    ViewValid := FALSE;
  END_IF;
END_PROGRAM


CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : EventLogger;
  END_RESOURCE
END_CONFIGURATION
