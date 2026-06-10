#!/usr/bin/env python3
"""
Interactive command-line driver for the B10E PSS simulator.

Start it:
    python3 pss_cli.py

You type short commands; it shows the live state of the safety system (inputs,
SFC step, and every output) after each command. Type 'help' for the full list,
or 'search' to auto-run a complete valid hutch search and switch the beam on.
"""

from pss_sim import (PSS, OPEN, OPEN_READY, START_SEARCH, HUTCH_ENTERED,
                     ASB1, ASB2, ASB3, ASB4, STANDBY, BEAM_ON)

G, R, Y, B, DIM, RST = ("\033[32m", "\033[31m", "\033[33m", "\033[36m",
                        "\033[2m", "\033[0m")


def onoff(v, on="ON", off="off"):
    return f"{G}{on}{RST}" if v else f"{DIM}{off}{RST}"


def panel(p: PSS):
    o = p.outputs()
    c = p.conditions()
    tripped, reasons = p.hazard_trip()

    state_colour = {OPEN: G, OPEN_READY: G, BEAM_ON: R}.get(p.step, Y)
    print(f"\n{'='*64}")
    print(f" HUTCH STATE : {state_colour}{p.step}{RST}"
          f"   {DIM}(search {p.search_timer:.0f}s / step {p.step_timer:.0f}s){RST}")
    if p.abort_reason:
        print(f" {Y}last abort : {p.abort_reason}{RST}")
    if reasons:
        print(f" {R}TRIPS      : {', '.join(reasons)}{RST}")

    # --- inputs ---
    keys = "  ".join(f"{k}={onoff(v,'IN','OUT')}" for k, v in p.keys.items())
    print(f"{DIM}-- inputs ---------------------------------------------------{RST}")
    print(f" card={onoff(p.card_inserted,'IN','--')}   {keys}   beam_req={onoff(p.beam_enable_request)}")
    a, m, sc = p.group_count("A"); print(f" Gen DOOR (grp A {sc}) open-votes {a}/{m}   "
                                         f"Gen GATE (grp B) {p.group_count('B')[0]}/{p.group_count('B')[1]}   "
                                         f"Svc DOOR {p.group_count('C')[0]}/3+{p.group_count('D')[0]}/2")
    print(f" CURRENT IT (grp E 2oo3) high-votes {p.group_count('E')[0]}/3   "
          f"VOLTAGE VT (grp F) {p.group_count('F')[0]}/3   "
          f"-> radiation_present={onoff(c['radiation_present'],'YES','no')}")
    print(f" O2 low (grp H 1oo4) {p.group_count('H')[0]}/4   "
          f"BOB (grp J) {p.group_count('J')[0]}/8 latch={onoff(p.latch_bob)}   "
          f"RDMN (grp K) {p.group_count('K')[0]}/2 latch={onoff(p.latch_rdmn)}")

    # --- outputs ---
    print(f"{DIM}-- outputs (ON = energised) --------------------------------{RST}")
    def con(i):
        t = f"CON{i:02d}"
        lab = f"C{i:02d}"
        return onoff(o[t], lab, lab.lower())
    con_src = " ".join(con(i) for i in range(1, 6))
    con_rf = " ".join(con(i) for i in range(6, 11))
    print(f" e-source contactors : {con_src}")
    print(f" RF contactors       : {con_rf}")
    print(f" door/gate locks     : {onoff(o['GADL01'],'LOCKED','unlckd')} (GADL/SADL)")
    print(f" annunciator         : "
          f"{onoff(o['ANNOPN'],'OPEN','open')} {onoff(o['ANNRES'],'RESTRICT','restrict')} "
          f"{onoff(o['ANNSTD'],'STANDBY','standby')} {onoff(o['ANNBON'],'BEAM-ON','beam')}")
    print(f" blue lights / BONI  : {onoff(o['BLUEL01'],'BLUE','blue')}  beam-on-ind {onoff(o['BONI'])}  "
          f"BOB-indic {onoff(o['BOBI01'])}")
    print(f" beacons SP1/2/3     : {onoff(o['SP01'],'1','1')} {onoff(o['SP02'],'2','2')} {onoff(o['SP03'],'3','3')}"
          f"   LN2 valve {onoff(o['SDVLN2'],'OPEN','CLOSED')}   O2 lights {onoff(o['IND01'],'GREEN','RED')}")
    print(f" Open/Reset LED      : {onoff(p.or_led)}")
    print('='*64)


HELP = """
COMMANDS  (inputs are case-insensitive)
  search            run a full valid search and switch beam ON (auto-timed)
  card              insert the search card
  start             (alias) insert card to begin a search
  lcrx              light-curtain single pass-through (advance T2)
  asb1 asb2 asb3 asb4   press an area-search button (advance T3..T6)
  asbf              press final search button (advance T7 -> STANDBY)
  enable            operator 'enable beam' request (after STANDBY)
  wait <sec>        let time pass (e.g. 'wait 10') - needed between steps
  door <tag> open|close     e.g. 'door GADC01 open'  (try GADC01..06, SADC01..05)
  bob <n> [up]      press beam-off button n (1..8); 'bob 3 up' to release
  key KEY01|KEY02|KEY03 on|off
  ai <tag> <value>  set an analog input (e.g. 'ai OXMON02 18'  'ai IT01 12')
  lc                extra light-curtain interrupt (aborts a monitored search)
  reset BOB|RDMN|GAS|OR     press a reset pushbutton
  state             reprint the status panel
  log               show recent event log
  help              this help
  quit              exit
"""


def run():
    p = PSS()
    print(__doc__)
    print(HELP)
    panel(p)
    while True:
        try:
            raw = input(f"{B}pss>{RST} ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            break
        if not raw:
            continue
        parts = raw.split()
        cmd, args = parts[0].lower(), parts[1:]

        try:
            if cmd in ("quit", "q", "exit"):
                break
            elif cmd == "help":
                print(HELP); continue
            elif cmd == "state":
                pass
            elif cmd == "log":
                for line in p.event_log[-15:]:
                    print(f"  {DIM}{line}{RST}")
                continue
            elif cmd == "search":
                p.press("CARD")
                for ev in ["LCRX", "ASB01", "ASB02", "ASB03", "ASB04", "ASBF"]:
                    p.tick(10); p.press(ev)
                p.press("BEAM_ENABLE"); p.tick(180)
            elif cmd in ("card", "start"):
                p.press("CARD")
            elif cmd == "lcrx":
                p.press("LCRX")
            elif cmd in ("asb1", "asb2", "asb3", "asb4"):
                p.press("ASB0" + cmd[-1])
            elif cmd == "asbf":
                p.press("ASBF")
            elif cmd == "enable":
                p.press("BEAM_ENABLE")
            elif cmd == "wait":
                p.tick(float(args[0]) if args else 1.0)
            elif cmd == "door":
                tag, st = args[0].upper(), args[1].lower()
                p.set_door(tag, st == "open")
            elif cmd == "bob":
                n = int(args[0]); up = len(args) > 1 and args[1] == "up"
                p.press_bob(f"BOB0{n}" if n < 10 else f"BOB{n}", not up)
            elif cmd == "key":
                p.set_key(args[0].upper(), args[1].lower() == "on")
            elif cmd == "ai":
                p.set_analog(args[0].upper(), float(args[1]))
            elif cmd == "lc":
                p.light_curtain_interrupt()
            elif cmd == "reset":
                p.reset(args[0].upper())
            else:
                print(f"{R}unknown command: {cmd}{RST} (type 'help')")
                continue
        except (IndexError, ValueError, KeyError) as e:
            print(f"{R}bad arguments: {e}{RST} (type 'help')")
            continue
        panel(p)
    print("bye.")


if __name__ == "__main__":
    run()
