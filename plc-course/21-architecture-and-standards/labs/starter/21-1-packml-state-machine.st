(* Lab 21-1: PackML base state machine for a case packer.
   Module 21 (Architecture and standards). STARTER - the types, the two code
   translation functions and all declarations are done for you. Write the logic
   where it says TODO, then run:
     python3 tools/plctest.py 21-architecture-and-standards/labs/starter/21-1-packml-state-machine.st

   Suggested structure (the same split an OEM uses on every machine it builds):
     - FB_PackMLStateModel: the generic base state machine. It knows the 17
       PackML states, the commands and state complete (SC), and nothing about
       case packers. The same block goes into every machine.
     - F_PMLCmdFromCode / F_PMLStateCode: translate between the PackTags
       integer codes on the interface and the enumerations used inside.
       Enumerations make the logic readable; the fixed integer codes keep the
       interface stable for the line controller, the HMI and the MES.
     - PROGRAM CasePacker: the machine layer. It decides which command the
       state machine gets on each scan (safety abort, remote request,
       blocked/starved suspend) and publishes the PackTags status. *)

TYPE
  (* PackML states. The order here is only for readability: the codes on the
     interface come from F_PMLStateCode, never from the enumeration's ordinal. *)
  E_PMLState : (Clearing, Stopped, Starting, Idle, Suspended, Execute, Stopping,
                Aborting, Aborted, Holding, Held, Unholding, Suspending,
                Unsuspending, Resetting, Completing, Complete);
  (* PackML commands, plus "no command" and "not a valid command code". *)
  E_PMLCmd : (CmdNone, CmdReset, CmdStart, CmdStop, CmdHold, CmdUnhold,
              CmdSuspend, CmdUnsuspend, CmdAbort, CmdClear, CmdInvalid);
END_TYPE

FUNCTION F_PMLCmdFromCode : E_PMLCmd
  (* PackTags CntrlCmd code -> command. 0 (undefined) and unknown codes
     become CmdInvalid, so a request carrying them is refused. *)
  VAR_INPUT
    Code : DINT;
  END_VAR
  CASE Code OF
    1: F_PMLCmdFromCode := CmdReset;
    2: F_PMLCmdFromCode := CmdStart;
    3: F_PMLCmdFromCode := CmdStop;
    4: F_PMLCmdFromCode := CmdHold;
    5: F_PMLCmdFromCode := CmdUnhold;
    6: F_PMLCmdFromCode := CmdSuspend;
    7: F_PMLCmdFromCode := CmdUnsuspend;
    8: F_PMLCmdFromCode := CmdAbort;
    9: F_PMLCmdFromCode := CmdClear;
  ELSE
    F_PMLCmdFromCode := CmdInvalid;
  END_CASE;
END_FUNCTION

FUNCTION F_PMLStateCode : DINT
  (* State -> PackTags StateCurrent code. *)
  VAR_INPUT
    State : E_PMLState;
  END_VAR
  F_PMLStateCode := 0;                       (* 0 = undefined; never expected *)
  CASE State OF
    Clearing:     F_PMLStateCode := 1;
    Stopped:      F_PMLStateCode := 2;
    Starting:     F_PMLStateCode := 3;
    Idle:         F_PMLStateCode := 4;
    Suspended:    F_PMLStateCode := 5;
    Execute:      F_PMLStateCode := 6;
    Stopping:     F_PMLStateCode := 7;
    Aborting:     F_PMLStateCode := 8;
    Aborted:      F_PMLStateCode := 9;
    Holding:      F_PMLStateCode := 10;
    Held:         F_PMLStateCode := 11;
    Unholding:    F_PMLStateCode := 12;
    Suspending:   F_PMLStateCode := 13;
    Unsuspending: F_PMLStateCode := 14;
    Resetting:    F_PMLStateCode := 15;
    Completing:   F_PMLStateCode := 16;
    Complete:     F_PMLStateCode := 17;
  END_CASE;
END_FUNCTION

FUNCTION_BLOCK FB_PackMLStateModel
  (* ------------------------------------------------------------------
     FB_PackMLStateModel - PackML base state machine (ISA-TR88.00.02 model).
     Behaviour     see the transition table in the lab sheet (README, Lab 21-1)
     Interface     Cmd, StateComplete in; State, CmdAccepted, CmdRejected out
     ------------------------------------------------------------------ *)
  VAR_INPUT
    Cmd           : E_PMLCmd;    (* command for this call; CmdNone = no command *)
    StateComplete : BOOL;        (* SC: the current acting state (or Execute) has finished its work *)
  END_VAR
  VAR_OUTPUT
    State       : E_PMLState := Stopped;  (* power-up state *)
    CmdAccepted : BOOL;          (* this call's Cmd was valid and changed the state *)
    CmdRejected : BOOL;          (* this call's Cmd was not valid in the state: ignored *)
  END_VAR
  VAR
    NextState : E_PMLState;      (* suggestion: work out the next state, then assign it once *)
  END_VAR

  (* TODO: 1. commands (which states accept which command),
           2. state complete (acting states and Execute only),
           3. CmdAccepted / CmdRejected.
     Replace these placeholder lines. *)
  NextState := State;
  CmdAccepted := FALSE;
  CmdRejected := FALSE;
END_FUNCTION_BLOCK

PROGRAM CasePacker
  VAR (* I/O *)
    SafetyOK AT %IX0.0 : BOOL;   (* safety relay monitoring contact: TRUE = e-stops and guards healthy *)
    Starved  AT %IX0.1 : BOOL;   (* infeed has run out of product (upstream cannot supply) *)
    Blocked  AT %IX0.2 : BOOL;   (* outfeed is backed up (downstream cannot accept) *)
  END_VAR
  VAR (* PackTags-style interface to the line controller / HMI *)
    CntrlCmd         : DINT;       (* Command.CntrlCmd: 1 Reset 2 Start 3 Stop 4 Hold 5 Unhold
                                      6 Suspend 7 Unsuspend 8 Abort 9 Clear *)
    CmdChangeRequest : BOOL;       (* Command.CmdChangeRequest: TRUE = execute CntrlCmd; the PLC clears it *)
    StateCurrent     : DINT := 2;  (* Status.StateCurrent, PackML state code *)
    CmdRejected      : BOOL;       (* TRUE = the most recent request was refused *)
  END_VAR
  VAR (* from the machine's own state logic *)
    StateComplete    : BOOL;       (* SC for the current acting state (or Execute) *)
  END_VAR
  VAR
    Unit          : FB_PackMLStateModel;
    Cmd           : E_PMLCmd;      (* the one command the state machine gets this scan *)
    RemoteCmd     : BOOL;          (* TRUE = Cmd came from CmdChangeRequest *)
    AutoSuspended : BOOL;          (* TRUE = the machine suspended itself (starved/blocked) *)
  END_VAR

  (* TODO: 1. choose this scan's command: SafetyOK lost -> Abort; a remote request
           (consume it: clear CmdChangeRequest); Starved/Blocked -> Suspend in
           Execute, and Unsuspend when both clear (only if the machine
           suspended itself).
           2. call Unit.
           3. publish CmdRejected and StateCurrent.
     Replace these placeholder lines. *)
  Cmd := CmdNone;
  RemoteCmd := FALSE;
  AutoSuspended := FALSE;
  Unit(Cmd := Cmd, StateComplete := FALSE);
  StateCurrent := F_PMLStateCode(Unit.State);
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : CasePacker;
  END_RESOURCE
END_CONFIGURATION
