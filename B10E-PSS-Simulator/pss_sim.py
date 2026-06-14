#!/usr/bin/env python3
"""
B10E 'HeXI' Personnel Safety System (PSS) - LOGIC SIMULATOR
===========================================================

Plain-language summary for a junior technical-support engineer
--------------------------------------------------------------
This is a *software model* of the radiation/personnel safety interlock that
protects people working around the Diamond Light Source B10E "HeXI" beamline
hutch (a shielded enclosure). The real system runs on a HIMax redundant safety
PLC, programmed in HIMA SILworX. This simulator does NOT talk to the PLC - it
reproduces the *logic* of two project documents so you can experiment safely:

  * Cause & Effect (C&E) matrix  -> which CAUSES (sensors) trip which EFFECTS
  * I/O schedule (IOS)           -> which physical channel each tag is wired to

and a third (the 713-page SILworX program printout) which gives the exact
sequence/timing/latching. See docs/ for the write-ups.

Mental model of the whole system (READ THIS FIRST)
--------------------------------------------------
The hutch can be in one of these overall states (this is the SFC in SIF-04):

   OPEN  ->  OPEN_READY  ->  START_SEARCH(T1) ->  HUTCH_ENTERED(T2)
        ->  ASB1(T3) -> ASB2(T4) -> ASB3(T5) -> ASB4(T6)
        ->  STANDBY(T7)  ->  BEAM_ON(T8)  ->  (back to OPEN at T9)

* OPEN         : doors unlocked, anyone may enter, no hazard. Sign: OPEN.
* OPEN_READY   : all doors closed & keys in - ready to start a search.
* START_SEARCH : a searcher has begun the walk-through. Sign: RESTRICTED.
* HUTCH_ENTERED: searcher passed the light curtain.
* ASB1..ASB4   : searcher pressed area-search buttons in order, deep->shallow.
* STANDBY      : search complete, all doors LOCKED, 180s warning. Sign: STANDBY.
* BEAM_ON      : after the 180s dwell, beam/hazard is enabled. Sign: BEAM ON.

Safety vocabulary
-----------------
  * De-energise to trip : an output's SAFE state is OFF (contactor opens, door
                          unlocks). Losing power = safe.
  * Demand              : a cause asking for protective action (door open,
                          button pressed, gas low, radiation high, key OFF...).
  * Voting (NooM)       : how many sensors of a group must agree to trip
                          (2oo3 = 2 of 3). Implemented by vote() below.
  * SIF                 : one independent Safety Instrumented Function (01..13).
  * Latch               : a trip 'sticks' until an explicit RESET. Contactors
                          will NOT restart after a trip until a *fresh* search.

Run it:
    python3 pss_cli.py        # interactive keyboard control
    python3 scenarios.py      # automated demonstrations + self-test
"""

from __future__ import annotations
import json
import os
from dataclasses import dataclass, field

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "data")


# ===========================================================================
# 1. VOTING  (2oo3, 1oo2, 1oo4, 1oo7, 1oo1 ...)
# ===========================================================================
def vote(num_tripped: int, total: int, scheme: str) -> bool:
    """True if a sensor group is TRIPPED under its NooM voting scheme.
    '2oo3' means: trip when at least 2 of the 3 sensors are in trip state."""
    n = int(scheme.lower().split("oo")[0])
    return num_tripped >= n


# ===========================================================================
# 2. MODEL  (load the Cause & Effect data file)
# ===========================================================================
class Model:
    def __init__(self, path=None):
        path = path or os.path.join(DATA, "cause_effect.json")
        with open(path) as f:
            self.d = json.load(f)
        self.causes = {c["tag"]: c for c in self.d["causes"]}
        self.effects = {e["tag"]: e for e in self.d["effects"]}
        self.groups = self.d["sensor_groups"]
        self.sifs = {s["id"]: s for s in self.d["sifs"]}
        self.seq = self.d["search_sequence"]


# ===========================================================================
# 3. THE SIMULATOR
# ===========================================================================
# SFC states (verified against program.pdf STATUS-* flags):
OPEN, OPEN_READY, START_SEARCH, HUTCH_ENTERED = (
    "OPEN", "OPEN_READY", "START_SEARCH", "HUTCH_ENTERED")
ASB1, ASB2, ASB3, ASB4 = "ASB1", "ASB2", "ASB3", "ASB4"
STANDBY, BEAM_ON = "STANDBY", "BEAM_ON"

# The single event that legally advances FROM each step:
ADVANCE = {
    OPEN_READY: "START",     # card inserted + KEY01 & KEY02 on + service doors closed
    START_SEARCH: "LCRX",    # single light-curtain pass-through
    HUTCH_ENTERED: "ASB01",
    ASB1: "ASB02",
    ASB2: "ASB03",
    ASB3: "ASB04",
    ASB4: "ASBF",            # final button -> STANDBY (with general doors closed)
}
NEXT = {
    OPEN_READY: START_SEARCH, START_SEARCH: HUTCH_ENTERED,
    HUTCH_ENTERED: ASB1, ASB1: ASB2, ASB2: ASB3, ASB3: ASB4, ASB4: STANDBY,
}
# steps that are policed by the 5s..60s per-step window + light-curtain monitor:
MONITORED_STEPS = {HUTCH_ENTERED, ASB1, ASB2, ASB3}   # light curtain watched T2..T6


@dataclass
class PSS:
    model: Model = field(default_factory=Model)

    def __post_init__(self):
        s = self.model.seq
        self.T_WINDOW = s["window_seconds"]          # 180s overall
        self.T_STEP_MIN = s["step_min_seconds"]      # 5s
        self.T_STEP_MAX = s["step_max_seconds"]      # 60s
        self.T_BEAM = s["beam_on_delay_seconds"]     # 180s
        self.T_RESET = s["reset_delay_seconds"]      # 60s

        # ---- inputs ----
        # demand[tag]=True  => that cause is calling for protective action.
        #   doors: OPEN ; buttons: PRESSED ; rad monitor: HIGH
        self.demand = {}
        self.analog = {}
        for tag, c in self.model.causes.items():
            if c["kind"] == "analog":
                self.analog[tag] = self._safe_analog(c)
            elif c["kind"] == "digital":
                self.demand[tag] = False
        # keys are stored as ON/OFF states (ON = safe/permissive)
        self.keys = {"KEY01": True, "KEY02": True, "KEY03": True}
        self.card_inserted = False
        self.beam_enable_request = False     # operator's 'enable beam' after STANDBY

        # ---- latches (a trip sticks until reset) ----
        self.latch_bob = False               # SIF-08
        self.latch_rdmn = False              # SIF-09
        self.latch_gas = False               # SIF-11 (oxygen)
        self.searched_and_locked = False     # set at STANDBY; gates the contactors

        # ---- SFC state + timers ----
        self.step = OPEN
        self.step_timer = 0.0                # time in current search step
        self.search_timer = 0.0              # time since START_SEARCH (overall)
        self.beam_timer = 0.0                # STANDBY dwell
        self.reset_timer = 0.0
        self.zero_source_timer = 0.0         # SIF-03 20s confirm
        self.abort_reason = None
        self.event_log = []

        self.scan()

    # ----- analog helpers --------------------------------------------------
    @staticmethod
    def _safe_analog(c):
        sp = c.get("setpoint", 0.0)
        return sp - 1.0 if c["trip_when"] == ">" else (sp + 1.0 if c["trip_when"] == "<" else sp)

    def _analog_demand(self, tag) -> bool:
        c = self.model.causes[tag]
        v, sp = self.analog[tag], c["setpoint"]
        return v > sp if c["trip_when"] == ">" else v < sp

    def _cause_demand(self, tag) -> bool:
        c = self.model.causes[tag]
        return self._analog_demand(tag) if c["kind"] == "analog" else self.demand.get(tag, False)

    # ----- voting ----------------------------------------------------------
    def group_tripped(self, gid) -> bool:
        g = self.model.groups[gid]
        n = sum(1 for t in g["members"] if self._cause_demand(t))
        return vote(n, len(g["members"]), g["voting"])

    def group_count(self, gid):
        g = self.model.groups[gid]
        n = sum(1 for t in g["members"] if self._cause_demand(t))
        return n, len(g["members"]), g["voting"]

    # ----- raw (instantaneous) SIF conditions ------------------------------
    def conditions(self) -> dict:
        c = {}
        c["gen_door_open"] = self.group_tripped("A")          # SIF-01 (GADC door)
        c["gen_gate_open"] = self.group_tripped("B")          # SIF-13 (GADC gate)
        c["svc_door_open"] = self.group_tripped("C") or self.group_tripped("D")  # SIF-02
        c["radiation_present"] = self.group_tripped("E") or self.group_tripped("F")  # SIF-03
        c["bob_now"] = self.group_tripped("J")                # SIF-08 (instant)
        c["rdmn_now"] = self.group_tripped("K")               # SIF-09
        c["o2_low_now"] = self.group_tripped("H")             # SIF-11
        c["key_off"] = (not self.keys["KEY01"]) or (not self.keys["KEY03"])  # SIF-10
        return c

    # ----- latched SIF trips ----------------------------------------------
    def _update_latches(self):
        c = self.conditions()
        # set-dominant: a new demand latches; stays latched until cleared+reset
        self.latch_bob = self.latch_bob or c["bob_now"]
        self.latch_rdmn = self.latch_rdmn or c["rdmn_now"]
        self.latch_gas = self.latch_gas or c["o2_low_now"]

    def hazard_trip(self):
        """Conditions that must remove the beam right now (returns reasons)."""
        c = self.conditions()
        r = []
        if c["gen_door_open"]:
            r.append("SIF-01 General Access DOOR open (2oo3)")
        if c["gen_gate_open"]:
            r.append("SIF-13 General Access GATE open (2oo3)")
        if c["svc_door_open"]:
            r.append("SIF-02 Service Access door open")
        if self.latch_bob:
            r.append("SIF-08 Beam-Off Button (latched)")
        if self.latch_rdmn:
            r.append("SIF-09 Radiation Monitor high (latched)")
        if c["key_off"]:
            r.append("SIF-10 Electron-Source Enable Key OFF")
        return (len(r) > 0, r)

    # ----- reset pushbuttons ----------------------------------------------
    def reset(self, kind):
        """kind: 'BOB','RDMN','GAS','OR' (Open/Reset). Only clears if cause gone."""
        c = self.conditions()
        if kind == "BOB" and not c["bob_now"]:
            self.latch_bob = False
        elif kind == "RDMN" and not c["rdmn_now"]:
            self.latch_rdmn = False
        elif kind == "GAS" and not c["o2_low_now"]:
            self.latch_gas = False
        elif kind == "OR":
            # Open/Reset only valid once source read zero for >=20s (SIF-03)
            if not c["radiation_present"] and self.zero_source_timer >= 20:
                if self.step not in (OPEN, OPEN_READY):
                    self._to_open("Open/Reset pressed (source confirmed zero)")
        self.scan()

    @property
    def or_led(self):
        """The Open/Reset button LED: lit only when pressing it is meaningful."""
        c = self.conditions()
        return (not c["radiation_present"]) and self.zero_source_timer >= 20 \
            and self.step not in (OPEN, OPEN_READY)

    # ----- SFC engine ------------------------------------------------------
    def _start_permissive(self) -> bool:
        c = self.conditions()
        return (self.card_inserted and self.keys["KEY01"] and self.keys["KEY02"]
                and not c["svc_door_open"] and not self.latch_bob)

    def _abort(self, reason):
        self.abort_reason = reason
        self.event_log.append(f"ABORT: {reason}")
        self.step = OPEN_READY if self._doors_all_closed() else OPEN
        self.step_timer = self.search_timer = 0.0
        self.searched_and_locked = False
        # An aborted search must be re-initiated: withdraw the card so the
        # sequence does not silently auto-restart on the next scan.
        self.card_inserted = False

    def _doors_all_closed(self):
        c = self.conditions()
        return not (c["gen_door_open"] or c["gen_gate_open"] or c["svc_door_open"])

    def _to_open(self, why=""):
        self.step = OPEN
        self.searched_and_locked = False
        self.beam_enable_request = False
        self.beam_timer = 0.0
        self.card_inserted = False
        if why:
            self.event_log.append(f"-> OPEN: {why}")

    def press(self, event: str):
        """Drive the search. event in:
        'CARD','LCRX','ASB01'..'ASB04','ASBF','BEAM_ENABLE'."""
        if event == "CARD":
            self.card_inserted = True
            self.scan()
            return
        if event == "BEAM_ENABLE":
            self.beam_enable_request = True
            self.scan()
            return

        expected = ADVANCE.get(self.step)
        if expected is None:
            self.event_log.append(f"ignored {event} (no search step active)")
            return
        if event != expected:
            # wrong button while searching = abort
            if self.step in NEXT and self.step != OPEN_READY:
                self._abort(f"out-of-order: got {event}, expected {expected}")
            else:
                self.event_log.append(f"ignored {event} (expected {expected})")
            self.scan()
            return

        # correct event: check the per-step MIN time (anti-tailgating)
        if self.step in MONITORED_STEPS or self.step in (ASB4,):
            if self.step_timer < self.T_STEP_MIN:
                self._abort(f"step too fast (<{self.T_STEP_MIN}s) at {self.step}")
                self.scan()
                return
        # T7 also requires general doors closed (SIF-06)
        if self.step == ASB4 and not (not self.conditions()["gen_door_open"]
                                      and not self.conditions()["gen_gate_open"]):
            self.event_log.append("ASBF ignored: general doors/gate not closed (SIF-06)")
            self.scan()
            return

        self._advance()
        self.scan()

    def _advance(self):
        nxt = NEXT[self.step]
        self.event_log.append(f"OK  {self.step} -> {nxt}")
        self.step = nxt
        self.step_timer = 0.0
        if nxt == START_SEARCH:
            self.search_timer = 0.0
        if nxt == STANDBY:
            self.searched_and_locked = True   # latch: search complete & locked
            self.beam_timer = 0.0
            self.keys["KEY01"] = self.keys["KEY01"]  # KEY01 released (kept for model)

    def light_curtain_interrupt(self):
        """An extra light-curtain break while monitored (T2..T6) aborts."""
        if self.step in MONITORED_STEPS or self.step == ASB4:
            self._abort("light curtain re-interrupted during monitored search")
        self.scan()

    # ----- time -----------------------------------------------------------
    def tick(self, seconds=1.0):
        c = self.conditions()
        # SIF-03 zero-source confirm timer
        if c["radiation_present"]:
            self.zero_source_timer = 0.0
        else:
            self.zero_source_timer += seconds

        if self.step in NEXT and self.step != OPEN_READY:
            self.step_timer += seconds
            self.search_timer += seconds
            if self.step in MONITORED_STEPS or self.step == ASB4:
                if self.step_timer > self.T_STEP_MAX:
                    self._abort(f"step too slow (>{self.T_STEP_MAX}s) at {self.step}")
            if self.search_timer > self.T_WINDOW:
                self._abort(f"overall search >{self.T_WINDOW}s")

        if self.step == STANDBY:
            self.beam_timer += seconds
        if self.step == OPEN:
            self.reset_timer += seconds
        self.scan()

    # ----- the master scan -------------------------------------------------
    def scan(self):
        self._update_latches()
        tripped, reasons = self.hazard_trip()
        c = self.conditions()

        # OPEN <-> OPEN_READY housekeeping
        if self.step == OPEN and self._doors_all_closed() and not tripped \
                and not (self.latch_bob or self.latch_rdmn):
            self.step = OPEN_READY
        if self.step == OPEN_READY and not self._doors_all_closed():
            self.step = OPEN
        # auto-start when the start permissive is satisfied
        if self.step == OPEN_READY and self._start_permissive():
            self._advance()                    # -> START_SEARCH (T1)

        # a live hazard during a running search aborts it
        if self.step in (START_SEARCH, HUTCH_ENTERED, ASB1, ASB2, ASB3, ASB4):
            if tripped or not self.keys["KEY01"] or not self.keys["KEY02"]:
                self._abort("hazard/key-loss during search")

        # STANDBY -> BEAM_ON after dwell + operator enable + permissive
        if self.step == STANDBY:
            if tripped:
                self._to_open("trip while in STANDBY")
            elif self.beam_enable_request and self.beam_timer >= self.T_BEAM \
                    and self._sif07_output():
                self.step = BEAM_ON
                self.event_log.append("OK  STANDBY -> BEAM_ON")

        # any trip during BEAM_ON drops to OPEN (T9) and breaks the latch
        if self.step == BEAM_ON and tripped:
            self._to_open("trip while BEAM_ON (T9)")

        return self.step

    def _sif07_output(self) -> bool:
        """Master beam-on permissive: search complete & locked, doors closed, no trip."""
        tripped, _ = self.hazard_trip()
        return self.searched_and_locked and self._doors_all_closed() and not tripped

    # ===================================================================
    # OUTPUTS  (every physical effect)
    # ===================================================================
    def outputs(self) -> dict:
        st = self.step
        c = self.conditions()
        beam = (st == BEAM_ON)
        armed = st in (STANDBY, BEAM_ON)
        o = {}

        # Electron-source contactors CON01-05: ON only with beam + latch + no trip
        src_ok = beam and self.searched_and_locked and not (
            c["gen_door_open"] or c["gen_gate_open"] or c["svc_door_open"]
            or self.latch_bob or self.latch_rdmn or c["key_off"])
        for t in ("CON01", "CON02", "CON03", "CON04", "CON05"):
            o[t] = src_ok
        # RF contactors CON06-10: also require gate closed + keys (SIF-13/10)
        rf_ok = src_ok and not c["gen_gate_open"]
        for t in ("CON06", "CON07", "CON08", "CON09", "CON10"):
            o[t] = rf_ok

        # Door / gate locks: LOCKED (energised) while armed OR radiation still present
        locked = armed or c["radiation_present"]
        for t in ("GADL01", "GADL02", "GADL03", "GADL04", "SADL01", "SADL02"):
            o[t] = locked

        # Annunciator status sign (mutually exclusive)
        o["ANNOPN"] = (st in (OPEN, OPEN_READY)) and not c["radiation_present"]
        o["ANNRES"] = st in (START_SEARCH, HUTCH_ENTERED, ASB1, ASB2, ASB3, ASB4)
        o["ANNSTD"] = (st == STANDBY)
        o["ANNBON"] = (st == BEAM_ON)

        # Deterrent / indication
        for t in ("BLUEL01", "BLUEL02", "BLUEL03", "BLUEL04"):
            o[t] = armed
        o["BONI"] = beam
        for t in ("BOBI01", "BOBI02", "BOBI03", "BOBI04"):
            o[t] = armed

        # Beacon / speaker programs
        o["SP01"] = o["ANNRES"]                 # cautionary 'search in progress'
        o["SP02"] = armed                       # deterrent 'radiation imminent'
        o["SP03"] = self.latch_bob or self.latch_rdmn   # alarm

        # LN2 shutoff valve: OPEN unless oxygen low (SIF-11)
        o["SDVLN2"] = not self.latch_gas
        # Oxygen traffic lights: GREEN unless oxygen low
        for t in ("IND01", "IND02", "IND03"):
            o[t] = not self.latch_gas
        return o

    # ===================================================================
    # convenience setters used by the CLI / scenarios
    # ===================================================================
    def set_door(self, tag, is_open):
        self.demand[tag] = bool(is_open)
        if is_open and self.step in NEXT and self.step != OPEN_READY:
            self._abort(f"{tag} opened during search")
        self.scan()

    def press_bob(self, tag, pressed=True):
        self.demand[tag] = bool(pressed)
        self.scan()

    def set_key(self, name, on):
        self.keys[name] = bool(on)
        self.scan()

    def set_analog(self, tag, value):
        self.analog[tag] = float(value)
        self.scan()
