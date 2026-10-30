"""Classify drawing text into identifier types.

Every rule here was derived from the text actually present in the supplied
drawing set (HIMA-Sella ESD cabinet C10265H/P3).  A text can yield several
identifiers (e.g. ``FZA 03002 - W01`` gives a tag and an annunciator window).

Identifier kinds
----------------
xref        explicit continuation pointer  ``052.225``  (sheet.grid)
sheet_ref   textual pointer to a drawing   ``SEE DRG C10265H/P3/023``, ``TO SHT 056``
loop_type   pointer to a typical loop      ``LOOP TYPE AI1``
cable       field cable (and core)         ``3/C650``, ``3/C661/3``
tag         instrument / device tag        ``03FZT03002``, ``FZA 03002``
elco        ELCO connector pin             ``1109/1``, ``1109:d10``
connector   ELCO connector / card number   ``1109``, ``1118``
terminal    terminal designation           ``1L+1``, ``XG.21:2``, ``K9202/1``
potential   supply potential / rail        ``1L-``, ``4L+``, ``BL+``
signal      FLD continuation signal        ``3A`` (only when paired with an xref)
dv          DeltaV Modbus point            ``DV3_1``
window      annunciator window             ``W12``, ``WINDOW 07``
module      I/O module type                ``F3236``, ``HIMA F6217``
tb          terminal block                 ``TB3AI``
link        safeclip link / fuse           ``LINK-1``, ``FUSE-A``
sheet_no    bare sheet number on schedules ``051``
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field


@dataclass
class Ident:
    kind: str
    key: str                       # normalised key used for matching
    label: str                     # as written
    extra: dict = field(default_factory=dict)


XREF_RE = re.compile(r"^(\d{3}[A-Z]?)\.(\d{2,3})(?:\s*\(([^()]{1,16})\))?$")   # 052.225, 035.50 (FUSE-A): sheet.grid, optional inline label
SIGNAL_RE = re.compile(r"^\d[A-Z]{1,2}$")

_RULES: list[tuple[str, re.Pattern]] = [
    ("cable", re.compile(r"^(\d{1,2}/C\d{2,4})(?:/(\d{1,2}))?$", re.I)),
    ("tag", re.compile(r"^(\d{2})([A-Z]{2,4})(\d{4,5})([A-Z])?(?:-([A-Z]{2,4}))?$")),
    ("tag_nopfx", re.compile(r"^([A-Z]{2,4})\s?(\d{5})([A-Z])?(?:\s*-\s*(W\d{1,2}))?$")),
    ("elco", re.compile(r"^(\d{4})/(\d{1,2})$")),
    ("elco", re.compile(r"^(\d{4}):([a-z]\d{1,2})$")),
    ("terminal", re.compile(r"^(\d{1,2}[A-Z][+-]\d{1,2})$")),
    ("terminal", re.compile(r"^(XG\.\d{1,2}(?::\d{1,2})?)$", re.I)),
    ("terminal", re.compile(r"^(K\d{4}/\d)$")),
    ("terminal", re.compile(r"^(X\d{1,2}[:/-]\d{1,2})$")),
    ("potential", re.compile(r"^\(?(\d?[A-Z]{1,2}[+-])\)?$")),
    ("dv", re.compile(r"^(DV\d_\d{1,3})$")),
    ("window", re.compile(r"^W(\d{1,2})$")),
    ("window", re.compile(r"^WINDOW\s+(\d{1,2})$", re.I)),
    ("module", re.compile(r"^(?:HIMA\s+)?([FH]\d{4})$")),
    ("tb", re.compile(r"^(TB\d[A-Z]{2})$")),
    ("link", re.compile(r"^((?:LINK|FUSE)-[A-Z0-9]{1,2})$")),
    ("connector", re.compile(r"^(1[12]\d{2})$")),
    ("card_range", re.compile(r"^(1[12]\d{2})-(1[12]\d{2})$")),
]

SHEET_REF_RES = [
    # SEE DRG C10265H/P3/023 ; REF DRG 025 ; SEE DRGS C10265H/070 & 071 ; SEE DWG C10265H/P4-026
    re.compile(r"\b(?:SEE|REF|REFER TO|FROM|TO)\s+(?:DRGS?|DWGS?|SHT|SHEET)S?\.?\s+(.+)$", re.I),
    re.compile(r"\b(?:DRGS?|DWGS?|SHT|SHEET)S?\.?\s+(C?\d{5}H?(?:/P\d)?[/-]\d{3}[A-Z]?.*)$", re.I),
]
LOOP_TYPE_RE = re.compile(r"\bLOOP TYPE\s+([A-Z]{2}\d)\b", re.I)


def classify(text: str, sheet_ids: set[str] | None = None, on_schedule: bool = False) -> list[Ident]:
    """Return identifiers found in *text* (already cleaned)."""
    t = text.strip()
    out: list[Ident] = []
    if not t:
        return out
    m = XREF_RE.match(t)
    if m:
        extra = {"sheet": m.group(1), "grid": int(m.group(2))}
        if m.group(3):
            extra["companion"] = m.group(3).strip()      # '035.50 (FUSE-A)': the label is written in the pointer itself
        out.append(Ident("xref", t, t, extra))
        return out
    m = LOOP_TYPE_RE.search(t)
    if m:
        out.append(Ident("loop_type", m.group(1).upper(), m.group(0)))
    for rx in SHEET_REF_RES:
        m = rx.search(t)
        if m:
            tail = m.group(1)
            refs = _sheet_numbers(tail)
            volume = None
            vm = re.search(r"/(P\d)[/-]", tail, re.I)
            if vm:
                volume = vm.group(1).upper()
            for r in refs:
                out.append(Ident("sheet_ref", r, m.group(0), {"volume": volume}))
            if refs:
                break
    if on_schedule and sheet_ids and re.fullmatch(r"\d{3}[A-Z]?", t) and t in sheet_ids:
        out.append(Ident("sheet_no", t, t))
    for kind, rx in _RULES:
        m = rx.match(t)
        if not m:
            continue
        if kind == "cable":
            out.append(Ident("cable", m.group(1).upper(), t, {"core": m.group(2)}))
        elif kind == "tag":
            plant, func, num, suffix, qual = m.groups()
            base = f"{func}{num}"
            out.append(Ident("tag", f"{plant}{func}{num}{suffix or ''}", t,
                             {"base": base, "plant": plant, "suffix": suffix or "", "qualifier": qual or ""}))
        elif kind == "tag_nopfx":
            func, num, suffix, window = m.groups()
            if func in ("TB",):
                continue
            base = f"{func}{num}"
            out.append(Ident("tag", f"{base}{suffix or ''}", t, {"base": base, "plant": "", "suffix": suffix or "", "qualifier": ""}))
            if window:
                out.append(Ident("window", f"W{int(window[1:])}", window))
        elif kind == "elco":
            conn, pin = m.group(1), m.group(2)
            out.append(Ident("elco", f"{conn}/{pin.lower()}", t, {"connector": conn, "pin": pin.lower()}))
            out.append(Ident("connector", conn, conn))
        elif kind == "window":
            out.append(Ident("window", f"W{int(m.group(1))}", t))
        elif kind == "card_range":
            a, b = int(m.group(1)), int(m.group(2))
            if 0 < b - a <= 8:
                for n in range(a, b + 1):
                    out.append(Ident("connector", str(n), t))
        elif kind == "potential":
            out.append(Ident("potential", m.group(1).upper(), t))
        else:
            out.append(Ident(kind, m.group(1).upper(), t))
        break
    if not out and SIGNAL_RE.match(t):
        out.append(Ident("signal", t, t))
    return out


def _sheet_numbers(tail: str) -> list[str]:
    """Extract drawing sheet numbers from the tail of a textual reference."""
    tail = tail.split("(")[0]
    nums = re.findall(r"(?<![0-9])(\d{3}[A-Z]?)(?![0-9])", tail)
    # drop obvious non-sheet numbers (e.g. 'NOTE 5')
    return [n for n in nums if not re.fullmatch(r"0{3}", n)]


def is_connection_kind(kind: str) -> bool:
    """Kinds whose repeated occurrence hints at the same physical circuit."""
    return kind in ("cable", "tag", "elco", "terminal", "potential", "dv", "window", "signal", "tb", "link", "connector")
