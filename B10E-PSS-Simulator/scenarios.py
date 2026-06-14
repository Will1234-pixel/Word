#!/usr/bin/env python3
"""
Worked scenarios for the B10E PSS simulator.

Each scenario is a short story: set some inputs, advance time, and check the
outputs are what the Cause & Effect matrix says they should be. Run it with:

    python3 scenarios.py

It prints a PASS/FAIL line per scenario and a short trace, so you can read it
like a test procedure. If everything passes, the simulator agrees with the C&E.
"""

from pss_sim import PSS, OPEN, OPEN_READY, STANDBY, BEAM_ON

GREEN, RED, DIM, RST = "\033[32m", "\033[31m", "\033[2m", "\033[0m"


def check(name, cond):
    tag = f"{GREEN}PASS{RST}" if cond else f"{RED}FAIL{RST}"
    print(f"  [{tag}] {name}")
    return cond


def do_full_search(p, enable_beam=True):
    """Perform a valid, in-order search all the way to BEAM_ON."""
    p.press("CARD")                 # insert search card (with keys already ON)
    # OPEN_READY auto-advances to START_SEARCH once permissive is met
    seq = ["LCRX", "ASB01", "ASB02", "ASB03", "ASB04", "ASBF"]
    for ev in seq:
        p.tick(10)                  # wait a valid 10s (>=5s, <=60s) in each step
        p.press(ev)
    if enable_beam:
        p.press("BEAM_ENABLE")
        p.tick(180)                 # the 180s 'radiation imminent' dwell
    return p


def scenario_happy_path():
    print(f"\n{'='*70}\nSCENARIO 1: Normal search -> BEAM ON (the happy path)\n{'='*70}")
    p = PSS()
    print(f"  start state = {p.step}  (doors closed, keys in)")
    ok = check("starts in OPEN_READY", p.step == OPEN_READY)
    do_full_search(p)
    o = p.outputs()
    ok &= check("reached BEAM_ON", p.step == BEAM_ON)
    ok &= check("electron-source contactors CON01-05 ENERGISED", all(o[f"CON0{i}"] for i in range(1, 6)))
    ok &= check("RF contactors CON06-10 ENERGISED", all(o[f"CON0{i}" if i < 10 else "CON10"] for i in range(6, 11)))
    ok &= check("all doors LOCKED (GADL/SADL energised)", o["GADL01"] and o["SADL01"])
    ok &= check("annunciator shows BEAM ON", o["ANNBON"] and not o["ANNOPN"])
    ok &= check("Beam-On indicator + blue lights ON", o["BONI"] and o["BLUEL01"])
    return ok


def scenario_beam_off_button():
    print(f"\n{'='*70}\nSCENARIO 2: Beam-Off Button pressed during BEAM ON -> trip\n{'='*70}")
    p = PSS()
    do_full_search(p)
    check("beam is on first", p.step == BEAM_ON)
    p.press_bob("BOB03", True)       # press one of the 8 beam-off buttons (1oo7)
    o = p.outputs()
    ok = check("SIF-08 dropped electron source (CON01-05 OFF)", not any(o[f"CON0{i}"] for i in range(1, 6)))
    ok &= check("SIF-08 dropped RF (CON06-10 OFF)", not o["CON06"] and not o["CON10"])
    ok &= check("returned out of BEAM_ON", p.step != BEAM_ON)
    ok &= check("trip is LATCHED (still tripped after button released)",
                (p.press_bob("BOB03", False) or p.latch_bob))
    # cannot restart without reset + fresh search
    o2 = p.outputs()
    ok &= check("source stays OFF until reset", not o2["CON01"])
    p.reset("BOB")
    ok &= check("after BOB reset, latch clears", not p.latch_bob)
    return ok


def scenario_door_during_beam():
    print(f"\n{'='*70}\nSCENARIO 3: General access door opened during BEAM ON -> trip\n{'='*70}")
    p = PSS()
    do_full_search(p)
    check("beam is on first", p.step == BEAM_ON)
    # open the door: needs 2oo3 of GADC01..03 to vote 'open'
    p.set_door("GADC01", True)
    o1 = p.outputs()
    check("1 of 3 door switches open -> NOT yet tripped (2oo3)", o1["CON01"] is True or p.step == BEAM_ON)
    p.set_door("GADC02", True)        # now 2 of 3 -> trips
    o = p.outputs()
    ok = check("2oo3 door open -> source contactors OFF", not o["CON01"])
    ok &= check("dropped out of BEAM_ON (T9)", p.step != BEAM_ON)
    ok &= check("SEARCHED_AND_LOCKED latch broken (needs new search)", not p.searched_and_locked)
    return ok


def scenario_out_of_order():
    print(f"\n{'='*70}\nSCENARIO 4: Out-of-order search button -> ABORT\n{'='*70}")
    p = PSS()
    p.press("CARD")
    p.tick(10); p.press("LCRX")       # T2 ok
    p.tick(10); p.press("ASB02")      # WRONG: expected ASB01
    ok = check("search aborted", p.abort_reason is not None and p.step in (OPEN, OPEN_READY))
    ok &= check("no beam", p.step not in (BEAM_ON,))
    print(f"  {DIM}abort reason: {p.abort_reason}{RST}")
    return ok


def scenario_too_fast():
    print(f"\n{'='*70}\nSCENARIO 5: Pressing the next button too fast (<5s) -> ABORT\n{'='*70}")
    p = PSS()
    p.press("CARD")
    p.tick(10); p.press("LCRX")       # enter HUTCH_ENTERED
    p.tick(2);  p.press("ASB01")      # only 2s elapsed -> too fast
    ok = check("aborted for being too fast", p.abort_reason and "fast" in p.abort_reason)
    print(f"  {DIM}abort reason: {p.abort_reason}{RST}")
    return ok


def scenario_oxygen():
    print(f"\n{'='*70}\nSCENARIO 6: Oxygen depletion (SIF-11, 1oo4) -> LN2 valve + alarms\n{'='*70}")
    p = PSS()
    n, m, scheme = p.group_count("H")
    print(f"  oxygen group H votes {scheme} ({m} monitors). Healthy O2 ~20.9%.")
    o = p.outputs()
    check("LN2 valve OPEN while O2 healthy", o["SDVLN2"])
    check("O2 traffic-lights GREEN", o["IND01"])
    p.set_analog("OXMON02", 18.0)     # one monitor reads 18% (< 19.5 setpoint)
    o = p.outputs()
    ok = check("1oo4 oxygen low -> LN2 valve CLOSES", not o["SDVLN2"])
    ok &= check("O2 traffic-lights go RED", not o["IND01"])
    ok &= check("alarm beacon program SP03/latched", p.latch_gas)
    p.set_analog("OXMON02", 20.9)     # restore
    p.reset("GAS")
    ok &= check("after GAS reset (O2 restored), valve re-opens", p.outputs()["SDVLN2"])
    return ok


def scenario_voting():
    print(f"\n{'='*70}\nSCENARIO 7: Demonstrate 2oo3 voting on the current transmitters\n{'='*70}")
    p = PSS()
    print("  Group E = electron-source CURRENT transmitters IT01/02/03, voting 2oo3.")
    p.set_analog("IT01", 12.0)        # 1 transmitter high
    check("1 of 3 high -> radiation NOT voted present", not p.conditions()["radiation_present"])
    p.set_analog("IT02", 12.0)        # 2 transmitters high
    ok = check("2 of 3 high -> radiation voted PRESENT (2oo3)", p.conditions()["radiation_present"])
    ok &= check("doors held LOCKED while radiation present (SIF-03)", p.outputs()["GADL01"])
    return ok


def main():
    results = []
    for fn in (scenario_happy_path, scenario_beam_off_button, scenario_door_during_beam,
               scenario_out_of_order, scenario_too_fast, scenario_oxygen, scenario_voting):
        results.append((fn.__name__, fn()))
    print(f"\n{'='*70}\nSUMMARY\n{'='*70}")
    npass = sum(1 for _, r in results if r)
    for name, r in results:
        tag = f"{GREEN}PASS{RST}" if r else f"{RED}FAIL{RST}"
        print(f"  [{tag}] {name}")
    print(f"\n  {npass}/{len(results)} scenarios passed.")
    return 0 if npass == len(results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
