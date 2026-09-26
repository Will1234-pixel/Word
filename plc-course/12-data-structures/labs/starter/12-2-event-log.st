(* Lab 12-2: Event log - a ring buffer of structures.
   Module 12 (Data structures). STARTER - the event structure, the program
   interface and the millisecond clock are done for you.
   A pump station keeps its last ten events (code + time stamp) in a ring
   buffer: slots EventLog[0..9] are filled in turn, and when all ten are in
   use each new event overwrites the oldest. Entries never move. Write:
     1. the clear command,
     2. logging: one event per request into the next slot of the ring,
        overwriting the oldest entry when the log is full,
     3. the View outputs for the HMI.
   Then run:
     python3 tools/plctest.py 12-data-structures/labs/starter/12-2-event-log.st *)

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
  (* TODO: add a VAR ... END_VAR block here for your internal variables. *)

  (* ---- 0. Millisecond clock (given). TIME_TO_LREAL gives seconds in
     MATIEC and milliseconds in CODESYS; dividing by TIME_TO_LREAL(T#1s)
     gives seconds on both, and * 1000.0 makes milliseconds. The TON's ET
     stops at PT, so this clock is good for 24 days: fine for a lab. ---- *)
  UpTime(IN := TRUE, PT := T#24d);
  NowMs := LREAL_TO_DINT(TIME_TO_LREAL(UpTime.ET) / TIME_TO_LREAL(T#1s) * 1000.0);

  (* TODO: replace these placeholder lines with the clear, log and view logic.
     The HMI sets LogReq and ClearCmd; your logic clears them. *)
  LogReq := FALSE;
  ViewValid := FALSE;
END_PROGRAM


CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : EventLogger;
  END_RESOURCE
END_CONFIGURATION
