(* Lab 04-3: Jog/run selector.
   Module 04 (Ladder logic fundamentals).
   REFERENCE SOLUTION - try the lab yourself first.
   The same logic drawn as ladder rungs is in the Module 04 README (Lab 04-3).
   Training exercise only: on a real machine, jogging with guards open is a
   safety function with its own rules (reduced speed, hold-to-run devices,
   enabling devices) and safety-rated hardware (Modules 19 and 20). *)

PROGRAM JogRun
  VAR (* I/O - addresses follow the OpenPLC convention *)
    StartPB       AT %IX0.0 : BOOL;  (* Start push-button, NO: TRUE while pressed *)
    StopPB_NC     AT %IX0.1 : BOOL;  (* Stop push-button, NC: TRUE while NOT pressed *)
    JogPB         AT %IX0.2 : BOOL;  (* Jog push-button, NO: TRUE while pressed *)
    RunSel        AT %IX0.3 : BOOL;  (* JOG/RUN selector: TRUE = RUN, FALSE = JOG *)
    OverloadOK_NC AT %IX0.4 : BOOL;  (* Overload relay auxiliary contact, NC: TRUE while healthy *)
    Motor         AT %QX0.0 : BOOL;  (* Conveyor motor contactor coil *)
    RunLamp       AT %QX0.1 : BOOL;  (* "Running" lamp: continuous run only, not jogging *)
  END_VAR
  VAR (* internal *)
    RunLatch : BOOL;  (* continuous-run memory: the ONLY bit that seals in *)
    JogCmd   : BOOL;  (* jog command: never sealed in *)
  END_VAR

  (* Rung 1 - continuous run. A normal seal-in, but it seals on its own
     internal bit RunLatch, NOT on the Motor output. RunSel is in series with
     the whole rung, so switching to JOG drops the latch, and switching back
     to RUN needs a new Start. *)
  RunLatch := (StartPB OR RunLatch) AND RunSel AND StopPB_NC AND OverloadOK_NC;

  (* Rung 2 - jog. Only in JOG mode, only while the button is held, and the
     same stop and overload conditions apply. There is no seal-in contact on
     this rung at all: that is what makes it a jog. *)
  JogCmd := JogPB AND NOT RunSel AND StopPB_NC AND OverloadOK_NC;

  (* Rung 3 - the motor output is driven from ONE place: run OR jog.
     Nothing reads Motor back as a seal-in, so a jog can never latch. *)
  Motor := RunLatch OR JogCmd;

  (* Rung 4 - the lamp shows continuous running only. *)
  RunLamp := RunLatch;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : JogRun;
  END_RESOURCE
END_CONFIGURATION
