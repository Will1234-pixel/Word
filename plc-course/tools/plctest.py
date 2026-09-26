#!/usr/bin/env python3
"""plctest - compile IEC 61131-3 Structured Text with MATIEC and run scan-by-scan tests.

This is the practice harness for the course. It lets you check a PLC program
without any PLC hardware:

  1. Your .st file is compiled with iec2c (the MATIEC compiler, the same one
     OpenPLC uses), so syntax and type errors are caught exactly as OpenPLC
     would catch them.
  2. A small C "virtual PLC" is generated around the compiled program. It runs
     the scan cycle, advances the PLC clock by the task interval each scan, and
     executes the steps in a .test scenario file: set inputs, run scans or wait
     for time to pass, then check outputs.

Usage:
  plctest.py program.st                 compile, then run program.test if it exists next to
                                        the file or one folder up (labs/solutions/X.st uses
                                        labs/X.test)
  plctest.py program.st my.test         compile and run a specific scenario file
  plctest.py --all DIR                  check every *.st under DIR (see below)
  plctest.py --keep ...                 keep the generated C code for inspection
  plctest.py --matiec PATH ...          MATIEC checkout (default: $MATIEC_HOME or tools/.matiec)

--all rules: a file normally must pass its scenario file. Files in starter/ and
mutants/ folders must FAIL theirs, which proves the tests really check
something. A file may override this with a directive comment:
  (* @plctest test=../other.test expect=fail *)    or    (* @plctest mode=compile *)

Scenario (.test) language, one command per line, '#' starts a comment:

  scenario <name>            start a fresh run: re-initialise the PLC, clock = 0
  set <path> <value>         write a variable (an input, or any variable)
  scan [N]                   run N PLC scans (default 1)
  wait <duration>            run scans until <duration> of PLC time has passed
                             (durations: 500ms, 2s, 1m30s or T#2s)
  expect <path> [op] <value> check a value; op is = <> < <= > >= (default =)
  expect <path> ~ <value> <tolerance>
                             check a REAL/TIME within +/- tolerance
  until <path> [op] <value> within <duration>
                             run scans until the condition holds; fail on timeout
  print <path>               show a value (debugging aid)

Paths: Inst.Var, Inst.FbInstance.Output, Inst.Struct.Field, Inst.Array[3],
a global name, or a direct address such as %IX0.0 / %QX0.1 / %IW2. If the
configuration has exactly one program instance, the instance prefix may be
omitted (e.g. "set StartPB TRUE").

Values: TRUE FALSE, 42, -7, 16#FF, 2#1010, 3.14, T#1m30s, T#250ms,
'text', an enumeration value (Idle or E_State#Idle).

Timing: the PLC clock starts at 0. Each scan first advances the clock by the
task interval (the TASK INTERVAL in your CONFIGURATION) and then executes the
program, so "t=" in the output is the time of the most recent scan and
"wait 2s" with a 10 ms task runs exactly 200 scans.
"""

import argparse
import glob
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))

SIGNED = {"SINT", "INT", "DINT", "LINT"}
UNSIGNED = {"USINT", "UINT", "UDINT", "ULINT", "BYTE", "WORD", "DWORD", "LWORD"}
REALS = {"REAL", "LREAL"}
TIMES = {"TIME"}
STRINGS = {"STRING"}
ELEMENTARY = SIGNED | UNSIGNED | REALS | TIMES | STRINGS | {"BOOL", "DATE", "TOD", "DT"}

# Member macros used inside __DECLARE_*_TYPE( ... ) and how to reach the value in C.
#   "val"  -> <base>.<NAME>.value
#   "ptr"  -> (*<base>.<NAME>.value)
#   "fb"   -> <base>.<NAME>          (a nested FB/program data struct)
#   "fbp"  -> (*<base>.<NAME>)
#   "raw"  -> <base>.<NAME>
MEMBER_ACCESS = {
    "VAR": "val", "ARRAY_VAR": "val", "STRUCT_VAR": "val",
    "LOCATED": "ptr", "LOCATED_ARRAY": "ptr", "LOCATED_STRUCT": "ptr",
    "EXTERNAL": "ptr", "EXTERNAL_ARRAY": "ptr", "EXTERNAL_STRUCT": "ptr",
    "FB": "fb", "EXTERNAL_FB": "fbp", "COMPLEX_VAR": "raw",
}


class PlcTestError(Exception):
    pass


# --------------------------------------------------------------------------
# Locating and running MATIEC
# --------------------------------------------------------------------------

def find_matiec(explicit):
    candidates = [explicit, os.environ.get("MATIEC_HOME"), os.path.join(HERE, ".matiec")]
    for c in candidates:
        if c and os.path.isfile(os.path.join(c, "iec2c")):
            return os.path.abspath(c)
    raise PlcTestError(
        "MATIEC (iec2c) not found. Run tools/setup-matiec.sh once, or set MATIEC_HOME "
        "to a built MATIEC checkout.")


def compile_st(matiec, st_file, outdir):
    # Same flags the OpenPLC runtime uses (webserver/scripts/compile_program.sh).
    cmd = [os.path.join(matiec, "iec2c"), "-f", "-l", "-p", "-r", "-R", "-a", "-I", os.path.join(matiec, "lib"), "-T", outdir, st_file]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    except subprocess.TimeoutExpired:
        raise PlcTestError("iec2c timed out")
    output = (proc.stdout + proc.stderr).strip()
    # iec2c lists the files it writes on success; keep only diagnostics.
    diag = "\n".join(l for l in output.splitlines()
                     if not re.fullmatch(r"[\w.]+\.(c|h)", l.strip()))
    if proc.returncode != 0:
        if proc.returncode < 0:
            diag += ("\niec2c crashed (signal %d). Known MATIEC crash triggers include "
                     "STRING[n]/STRING(n) length declarations." % -proc.returncode)
        raise PlcTestError("compile failed:\n" + diag)
    return diag


# --------------------------------------------------------------------------
# Reading the generated C headers into a type table
# --------------------------------------------------------------------------

def _balanced_args(text, start):
    """text[start] is '('; return (inner, end_index_after_close)."""
    depth = 0
    for i in range(start, len(text)):
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                return text[start + 1:i], i + 1
    raise PlcTestError("unbalanced parentheses in generated header")


class TypeTable:
    def __init__(self):
        self.pous = {}      # POU data type -> {MEMBER: (access, TYPE)}
        self.structs = {}   # struct type -> {MEMBER: (access, TYPE)}
        self.enums = {}     # enum type -> [C constant names]
        self.arrays = {}    # array type -> (element TYPE, [dims], complex?)
        self.aliases = {}   # derived type -> base type

    def resolve(self, t):
        seen = set()
        while t in self.aliases and t not in seen:
            seen.add(t)
            t = self.aliases[t]
        return t

    def parse(self, text):
        for m in re.finditer(r"__DECLARE_(FB_TYPE|PROGRAM_TYPE|STRUCT_TYPE|ENUMERATED_TYPE|"
                             r"ARRAY_TYPE|ARRAY_OF_COMPLEX_TYPE|ARRAY_DERIVED_TYPE|DERIVED_TYPE|"
                             r"REFTO_TYPE)\s*\(", text):
            kind = m.group(1)
            inner, _ = _balanced_args(text, m.end() - 1)
            name, _, rest = inner.partition(",")
            name = name.strip()
            if kind in ("FB_TYPE", "PROGRAM_TYPE", "STRUCT_TYPE"):
                members = {}
                for mm in re.finditer(r"__DECLARE_(\w+)\s*\(\s*(\w+)\s*,\s*(\w+)\s*\)", rest):
                    macro, mtype, mname = mm.groups()
                    if macro in MEMBER_ACCESS:
                        members[mname] = (MEMBER_ACCESS[macro], mtype)
                (self.structs if kind == "STRUCT_TYPE" else self.pous)[name] = members
            elif kind == "ENUMERATED_TYPE":
                self.enums[name] = [c.strip() for c in rest.split(",") if c.strip()]
            elif kind in ("ARRAY_TYPE", "ARRAY_OF_COMPLEX_TYPE"):
                base, _, dims = rest.partition(",")
                self.arrays[name] = ([int(d) for d in re.findall(r"__DIM\((\d+)\)", dims)],
                                     base.strip(), kind == "ARRAY_OF_COMPLEX_TYPE")
            elif kind in ("ARRAY_DERIVED_TYPE", "DERIVED_TYPE"):
                self.aliases[name] = rest.strip()


def load_program_model(outdir):
    types = TypeTable()
    std_fb = os.path.join(MATIEC_LIB_C, "iec_std_FB.h")
    with open(std_fb) as f:
        types.parse(f.read())
    with open(os.path.join(outdir, "POUS.h")) as f:
        types.parse(f.read())

    instances = {}  # INSTANCE -> (C symbol, POU type)
    for cfile in glob.glob(os.path.join(outdir, "*.c")):
        if os.path.basename(cfile) == "POUS.c":
            continue
        with open(cfile) as f:
            for m in re.finditer(r"^(\w+)_data__ ((\w+?)__(\w+));", f.read(), re.M):
                instances[m.group(4)] = (m.group(2), m.group(1))

    globals_ = {}   # NAME -> (access, TYPE)
    config_headers = []
    for hfile in glob.glob(os.path.join(outdir, "*.h")):
        base = os.path.basename(hfile)
        if base in ("POUS.h", "LOCATED_VARIABLES.h", "GLOBALS.h"):
            continue
        with open(hfile) as f:
            text = f.read()
        config_headers.append(base)
        for m in re.finditer(r"__DECLARE_GLOBAL_PROTOTYPE(_FB)?\(\s*(\w+)\s*,\s*(\w+)\s*\)", text):
            globals_[m.group(3)] = ("gfb" if m.group(1) else "gval", m.group(2))

    located = {}    # C symbol (__IX0_0) -> TYPE
    with open(os.path.join(outdir, "LOCATED_VARIABLES.h")) as f:
        for m in re.finditer(r"__LOCATED_VAR\(\s*(\w+)\s*,\s*(\w+)\s*,", f.read()):
            located[m.group(2)] = m.group(1)
    return types, instances, globals_, located, config_headers


# --------------------------------------------------------------------------
# Array lower bounds come from the ST source (the C code is zero-based)
# --------------------------------------------------------------------------

def array_lower_bounds(st_text, var_name, type_name):
    clean = re.sub(r"\(\*.*?\*\)", " ", st_text, flags=re.S)
    clean = re.sub(r"//[^\n]*", " ", clean)
    found = set()
    for ident in (var_name, type_name):
        if not ident or ident.startswith("__"):
            continue
        pat = r"\b%s\b\s*(?:AT\s+%%\S+\s*)?:\s*ARRAY\s*\[([^\]]+)\]" % re.escape(ident)
        for m in re.finditer(pat, clean, re.I):
            lows = []
            for rng in m.group(1).split(","):
                lo = rng.split("..")[0].strip()
                if not re.fullmatch(r"[+-]?\d+", lo):
                    raise PlcTestError("array %s: only integer-literal bounds are supported "
                                       "in tests (found '%s')" % (var_name, lo))
                lows.append(int(lo))
            found.add(tuple(lows))
        if found:
            break
    if len(found) != 1:
        raise PlcTestError("cannot determine the lower bound of array '%s' (declare it with "
                           "ARRAY[lo..hi] and a name that is unique in the file)" % var_name)
    return list(found.pop())


# --------------------------------------------------------------------------
# Path resolution: "P1.Valve.Count" -> ("RES0__P1.VALVE.COUNT.value", "INT")
# --------------------------------------------------------------------------

class Resolver:
    def __init__(self, model, st_text):
        self.types, self.instances, self.globals, self.located, _ = model
        self.st_text = st_text

    def resolve(self, path):
        path = path.strip()
        m = re.fullmatch(r"%([IQM])([XBWDL]?)(\d+(?:\.\d+)*)", path, re.I)
        if m:
            area, size, nums = m.group(1).upper(), m.group(2).upper(), m.group(3)
            sym = "__%s%s%s" % (area, size, nums.replace(".", "_"))
            if sym not in self.located:
                raise PlcTestError("address %s is not used by the program" % path)
            return "(*%s)" % sym, self.located[sym]

        segs = self._split(path)
        first, idx0 = segs[0]
        up = first.upper()
        if up in self.instances:
            expr, ctype, kind = self.instances[up][0], self.instances[up][1], "pou"
            rest = segs[1:]
            if idx0:
                raise PlcTestError("cannot index a program instance: %s" % path)
        elif up in self.globals:
            access, t = self.globals[up]
            if access == "gfb":
                expr, ctype, kind = "(*__GET_GLOBAL_%s())" % up, t, "pou"
            else:
                expr, ctype, kind = "(*__GET_GLOBAL_%s())" % up, t, "value"
            expr, ctype, kind = self._index(expr, ctype, kind, idx0, first)
            rest = segs[1:]
        elif len(self.instances) == 1:
            inst = next(iter(self.instances.values()))
            expr, ctype, kind = inst[0], inst[1], "pou"
            rest = segs
        else:
            raise PlcTestError("unknown name '%s' (program instances: %s)"
                               % (first, ", ".join(sorted(self.instances)) or "none"))

        for name, idx in rest:
            expr, ctype, kind = self._member(expr, ctype, kind, name, path)
            expr, ctype, kind = self._index(expr, ctype, kind, idx, name)
        if kind == "pou":
            raise PlcTestError("'%s' is a function block/program instance, not a value" % path)
        return expr, self.types.resolve(ctype)

    @staticmethod
    def _split(path):
        segs, pos = [], 0
        tok = re.compile(r"([A-Za-z_]\w*)((?:\[\s*-?\d+(?:\s*,\s*-?\d+)*\s*\])*)")
        while True:
            m = tok.match(path, pos)
            if not m:
                raise PlcTestError("cannot parse path '%s'" % path)
            idx = []
            for group in re.findall(r"\[([^\]]*)\]", m.group(2)):
                idx += [int(x) for x in group.split(",")]
            segs.append((m.group(1), idx))
            pos = m.end()
            if pos == len(path):
                return segs
            if path[pos] != ".":
                raise PlcTestError("cannot parse path '%s'" % path)
            pos += 1

    def _member(self, expr, ctype, kind, name, path):
        key = name.upper()
        if kind == "pou":
            members = self.types.pous.get(ctype)
        else:
            members = self.types.structs.get(self.types.resolve(ctype))
        if members is None or key not in members:
            raise PlcTestError("'%s' has no member '%s' (in path %s)" % (ctype, name, path))
        access, mtype = members[key]
        if access == "val":
            return "%s.%s.value" % (expr, key), mtype, "value"
        if access == "ptr":
            return "(*%s.%s.value)" % (expr, key), mtype, "value"
        if access == "fb":
            return "%s.%s" % (expr, key), mtype, "pou"
        if access == "fbp":
            return "(*%s.%s)" % (expr, key), mtype, "pou"
        return "%s.%s" % (expr, key), mtype, "value"

    def _index(self, expr, ctype, kind, idx, name):
        if not idx:
            return expr, ctype, kind
        t = self.types.resolve(ctype)
        if t not in self.types.arrays:
            raise PlcTestError("'%s' is not an array" % name)
        dims, base, complex_ = self.types.arrays[t]
        if len(idx) != len(dims):
            raise PlcTestError("'%s' needs %d index(es)" % (name, len(dims)))
        lows = array_lower_bounds(self.st_text, name, ctype)
        sub = ""
        for i, lo, n in zip(idx, lows, dims):
            if not lo <= i < lo + n:
                raise PlcTestError("index %d out of range for '%s'" % (i, name))
            sub += "[%d]" % (i - lo)
        if complex_:
            return "%s.table%s" % (expr, sub), base, "value"
        return "%s.table%s.value" % (expr, sub), base, "value"


# --------------------------------------------------------------------------
# Literals
# --------------------------------------------------------------------------

TIME_UNITS = [("d", 86400e9), ("h", 3600e9), ("ms", 1e6), ("us", 1e3), ("ns", 1.0),
              ("m", 60e9), ("s", 1e9)]


def parse_time_ns(text):
    t = text.strip()
    m = re.fullmatch(r"(?:T|TIME)#(-?)(.+)", t, re.I)
    if not m:
        raise PlcTestError("bad TIME literal '%s' (use e.g. T#1s, T#250ms, T#1m30s)" % text)
    sign, body = (-1 if m.group(1) else 1), m.group(2).replace("_", "")
    total, pos = 0.0, 0
    while pos < len(body):
        mm = re.match(r"(\d+(?:\.\d+)?)(d|h|ms|us|ns|m|s)", body[pos:], re.I)
        if not mm:
            raise PlcTestError("bad TIME literal '%s'" % text)
        total += float(mm.group(1)) * dict(TIME_UNITS)[mm.group(2).lower()]
        pos += mm.end()
    return sign * total


def parse_int(text):
    t = text.replace("_", "")
    t = re.sub(r"^[A-Za-z]+#(?=[-\d])", "", t)  # INT#5 -> 5
    m = re.fullmatch(r"(-?)(2|8|16)#([0-9A-Fa-f]+)", t)
    if m:
        v = int(m.group(3), int(m.group(2)))
        return -v if m.group(1) else v
    if re.fullmatch(r"[+-]?\d+", t):
        return int(t)
    raise PlcTestError("bad integer literal '%s'" % text)


def c_literal(value, ctype, types):
    """Return a C expression for 'value' of IEC type 'ctype'."""
    v = value.strip()
    if ctype == "BOOL":
        u = v.upper()
        if u in ("TRUE", "1"):
            return "1"
        if u in ("FALSE", "0"):
            return "0"
        raise PlcTestError("expected TRUE/FALSE, got '%s'" % value)
    if ctype in SIGNED or ctype in UNSIGNED:
        return "%dLL" % parse_int(v)
    if ctype in REALS:
        try:
            return repr(float(re.sub(r"^[A-Za-z]+#", "", v).replace("_", "")))
        except ValueError:
            raise PlcTestError("bad REAL literal '%s'" % value)
    if ctype in TIMES:
        ns = parse_time_ns(v)
        sec = math.floor(ns / 1e9)
        return "(TIME){%dLL, %d}" % (sec, int(round(ns - sec * 1e9)))
    if ctype in STRINGS:
        m = re.fullmatch(r"'(.*)'", v)
        if not m:
            raise PlcTestError("STRING values are written in single quotes: 'text'")
        s = m.group(1).replace("$'", "'")
        return "(STRING){%d, \"%s\"}" % (len(s), s.replace("\\", "\\\\").replace('"', '\\"'))
    if ctype in types.enums:
        ident = v.split("#")[-1].upper()
        const = "%s__%s" % (ctype, ident)
        if const not in types.enums[ctype]:
            raise PlcTestError("'%s' is not a value of %s (%s)" % (
                value, ctype, ", ".join(c.split("__", 1)[1] for c in types.enums[ctype])))
        return const
    raise PlcTestError("values of type %s cannot be used in tests" % ctype)


def c_number(expr, ctype, types):
    """A C expression giving the value as long double (for comparisons/printing)."""
    if ctype in TIMES:
        return "((long double)(%s).tv_sec * 1000.0L + (long double)(%s).tv_nsec / 1.0e6L)" % (expr, expr)
    if ctype in STRINGS:
        raise PlcTestError("internal: strings are not numeric")
    if ctype == "BOOL" or ctype in SIGNED or ctype in UNSIGNED or ctype in REALS or ctype in types.enums:
        return "((long double)(%s))" % expr
    raise PlcTestError("values of type %s cannot be compared in tests" % ctype)


def expected_number(value, ctype, types):
    if ctype in TIMES:
        return "%.6fL" % (parse_time_ns(value) / 1e6)
    lit = c_literal(value, ctype, types)
    return "((long double)(%s))" % lit


# --------------------------------------------------------------------------
# Scenario compilation to C
# --------------------------------------------------------------------------

C_PRELUDE = r"""
#include <stdio.h>
#include <string.h>
#include "iec_std_lib.h"
#include "accessor.h"
#include "POUS.h"
%(config_includes)s

TIME __CURRENT_TIME;
BOOL __DEBUG;

/* Newer MATIEC versions route snprintf and maths through functions that the
   PLC runtime must supply; the virtual PLC supplies them from the C library. */
#include <stdarg.h>
#include <math.h>
int iec_lib_snprintf(char *s, size_t n, const char *fmt, ...) {
  va_list ap; va_start(ap, fmt); int r = vsnprintf(s, n, fmt, ap); va_end(ap); return r;
}
double iec_lib_acos(double x) { return acos(x); }
double iec_lib_asin(double x) { return asin(x); }
double iec_lib_atan(double x) { return atan(x); }
double iec_lib_cos(double x) { return cos(x); }
double iec_lib_exp(double x) { return exp(x); }
double iec_lib_fmod(double x, double y) { return fmod(x, y); }
double iec_lib_log(double x) { return log(x); }
double iec_lib_log10(double x) { return log10(x); }
double iec_lib_pow(double x, double y) { return pow(x, y); }
double iec_lib_sin(double x) { return sin(x); }
double iec_lib_sqrt(double x) { return sqrt(x); }
double iec_lib_tan(double x) { return tan(x); }
extern unsigned long long common_ticktime__;
void config_init__(void);
void config_run__(unsigned long tick);
%(instance_externs)s
%(located_storage)s

static unsigned long tick__;
static int failures__, checks__;

static void reset_plc__(void) {
%(located_reset)s
  __CURRENT_TIME.tv_sec = 0; __CURRENT_TIME.tv_nsec = 0;
  tick__ = 0;
  config_init__();
}

static void scan__(void) {
  long long ns = (long long)__CURRENT_TIME.tv_nsec + (long long)common_ticktime__;
  __CURRENT_TIME.tv_sec += ns / 1000000000LL;
  __CURRENT_TIME.tv_nsec = ns %% 1000000000LL;
  config_run__(tick__++);
}

static long double now_ms__(void) {
  return (long double)__CURRENT_TIME.tv_sec * 1000.0L + (long double)__CURRENT_TIME.tv_nsec / 1.0e6L;
}

static void check__(int ok, int line, const char *what, const char *actual) {
  checks__++;
  if (ok) {
    printf("  ok      line %%-4d %%s\n", line, what);
  } else {
    failures__++;
    printf("  FAIL    line %%-4d %%s   (actual: %%s, at t=%%.0Lf ms)\n", line, what, actual, now_ms__());
  }
}

int main(void) {
  char buf__[256];
  (void)buf__;
  reset_plc__();
"""

C_EPILOGUE = r"""
  printf("%d check(s), %d failure(s)\n", checks__, failures__);
  return failures__ ? 1 : 0;
}
"""


def c_str(s):
    return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"')


def format_actual(expr, ctype, types):
    """C statements that write a printable form of expr into buf__."""
    if ctype == "BOOL":
        return 'snprintf(buf__, sizeof buf__, "%%s", (%s) ? "TRUE" : "FALSE");' % expr
    if ctype in SIGNED:
        return 'snprintf(buf__, sizeof buf__, "%%lld", (long long)(%s));' % expr
    if ctype in UNSIGNED:
        return 'snprintf(buf__, sizeof buf__, "%%llu", (unsigned long long)(%s));' % expr
    if ctype in REALS:
        return 'snprintf(buf__, sizeof buf__, "%%.6g", (double)(%s));' % expr
    if ctype in TIMES:
        return 'snprintf(buf__, sizeof buf__, "T#%%.3Lfms", %s);' % c_number(expr, ctype, types)
    if ctype in STRINGS:
        return 'snprintf(buf__, sizeof buf__, "\'%%.*s\'", (int)(%s).len, (const char*)(%s).body);' % (expr, expr)
    if ctype in types.enums:
        cases = " ".join('case %s: snprintf(buf__, sizeof buf__, "%s"); break;' % (c, c.split("__", 1)[1])
                         for c in types.enums[ctype])
        return "switch (%s) { %s default: snprintf(buf__, sizeof buf__, \"?\"); }" % (expr, cases)
    raise PlcTestError("values of type %s cannot be printed" % ctype)


def condition(resolver, types, path, op, value, tol, lineno):
    expr, ctype = resolver.resolve(path)
    cop = {"=": "==", "==": "==", "<>": "!=", "!=": "!=", "<": "<", "<=": "<=", ">": ">", ">=": ">="}
    if ctype in STRINGS:
        if op not in ("=", "==", "<>", "!="):
            raise PlcTestError("line %d: strings support only = and <>" % lineno)
        lit = c_literal(value, ctype, types)
        cond = "((%s).len == (%s).len && memcmp((%s).body, (%s).body, (%s).len) == 0)" % (
            expr, lit, expr, lit, lit)
        return (cond if op in ("=", "==") else "!" + cond), expr, ctype
    actual = c_number(expr, ctype, types)
    expected = expected_number(value, ctype, types)
    if op == "~":
        if tol is None:
            raise PlcTestError("line %d: '~' needs a tolerance, e.g. expect X ~ 50.0 0.5" % lineno)
        tol_v = parse_time_ns(tol) / 1e6 if ctype in TIMES else float(tol)
        return "(fabsl(%s - %s) <= %.9gL)" % (actual, expected, tol_v), expr, ctype
    if op not in cop:
        raise PlcTestError("line %d: unknown operator '%s'" % (lineno, op))
    if ctype in REALS and op in ("=", "==", "<>", "!="):
        near = "(fabsl(%s - %s) <= 1e-4L * (1.0L + fabsl(%s)))" % (actual, expected, expected)
        return (near if op in ("=", "==") else "!" + near), expr, ctype
    return "(%s %s %s)" % (actual, cop[op], expected), expr, ctype


def parse_check(args, lineno):
    """'<path> [op] <value> [tol]' -> (path, op, value, tol)."""
    m = re.fullmatch(r"(\S+)\s+(=|==|<>|!=|<=|>=|<|>|~)\s+(\S+|'.*')(?:\s+(\S+))?", args)
    if m:
        return m.group(1), m.group(2), m.group(3), m.group(4)
    m = re.fullmatch(r"(\S+)\s+(\S+|'.*')", args)
    if m:
        return m.group(1), "=", m.group(2), None
    raise PlcTestError("line %d: expected '<path> [op] <value>'" % lineno)


def duration_scans_code(duration):
    d = duration.strip()
    ns = parse_time_ns(d if "#" in d else "T#" + d)
    if ns < 0:
        raise PlcTestError("negative duration")
    return ns


def compile_scenarios(test_text, resolver, types):
    body = []
    have_scenario = False
    for lineno, raw in enumerate(test_text.splitlines(), 1):
        # '#' starts a comment only at the start of a line or after whitespace,
        # so literals such as T#5s, 16#FF and E_State#Idle are left alone.
        line = re.sub(r"(^|\s)#.*$", "", raw).strip()
        if not line:
            continue
        cmd, _, args = line.partition(" ")
        cmd, args = cmd.lower(), args.strip()
        if cmd == "scenario":
            if have_scenario:
                body.append("  reset_plc__();")
            have_scenario = True
            body.append('  printf("\\n%s\\n", %s);' % ("%s", c_str("scenario: " + (args or "?"))))
        elif cmd == "set":
            m = re.fullmatch(r"(\S+)\s+(.+)", args)
            if not m:
                raise PlcTestError("line %d: usage: set <path> <value>" % lineno)
            expr, ctype = resolver.resolve(m.group(1))
            body.append("  %s = %s;" % (expr, c_literal(m.group(2), ctype, types)))
        elif cmd == "scan":
            n = int(args) if args else 1
            body.append("  for (int i__ = 0; i__ < %d; i__++) scan__();" % n)
        elif cmd == "wait":
            ns = duration_scans_code(args)
            body.append("  { long double end__ = now_ms__() + %.6fL; while (now_ms__() < end__ - 1e-9L) scan__(); }"
                        % (ns / 1e6))
        elif cmd == "expect":
            path, op, value, tol = parse_check(args, lineno)
            cond, expr, ctype = condition(resolver, types, path, op, value, tol, lineno)
            what = "expect " + args
            body.append("  { %s check__(%s, %d, %s, buf__); }"
                        % (format_actual(expr, ctype, types), cond, lineno, c_str(what)))
        elif cmd == "until":
            m = re.fullmatch(r"(.+?)\s+within\s+(\S+)", args, re.I)
            if not m:
                raise PlcTestError("line %d: usage: until <path> [op] <value> within <duration>" % lineno)
            path, op, value, tol = parse_check(m.group(1).strip(), lineno)
            cond, expr, ctype = condition(resolver, types, path, op, value, tol, lineno)
            ns = duration_scans_code(m.group(2))
            what = "until " + args
            body.append(
                "  { long double end__ = now_ms__() + %.6fL; int ok__ = 0;\n"
                "    for (;;) { if (%s) { ok__ = 1; break; } if (now_ms__() >= end__ - 1e-9L) break; scan__(); }\n"
                "    %s check__(ok__, %d, %s, buf__); }"
                % (ns / 1e6, cond, format_actual(expr, ctype, types), lineno, c_str(what)))
        elif cmd == "print":
            expr, ctype = resolver.resolve(args)
            body.append('  { %s printf("  print   line %-4d %s = %%s   (t=%%.0Lf ms)\\n", buf__, now_ms__()); }'
                        % (format_actual(expr, ctype, types), lineno, args.replace("%", "%%")))
        else:
            raise PlcTestError("line %d: unknown command '%s'" % (lineno, cmd))
    return "\n".join(body)


# --------------------------------------------------------------------------
# Build and run
# --------------------------------------------------------------------------

MATIEC_LIB_C = None


def run_one(matiec, st_file, test_file, keep=False, quiet=False):
    global MATIEC_LIB_C
    MATIEC_LIB_C = os.path.join(matiec, "lib", "C")
    work = tempfile.mkdtemp(prefix="plctest_")
    try:
        diag = compile_st(matiec, os.path.abspath(st_file), work)
        if diag and not quiet:
            print(diag)
        if not test_file:
            return 0, 0
        model = load_program_model(work)
        types, instances, globals_, located, config_headers = model
        with open(st_file) as f:
            st_text = f.read()
        with open(test_file) as f:
            test_text = f.read()
        resolver = Resolver(model, st_text)
        body = compile_scenarios(test_text, resolver, types)

        prelude = C_PRELUDE % {
            "config_includes": "\n".join('#include "%s"' % h for h in sorted(config_headers)),
            "instance_externs": "\n".join("extern %s_data__ %s;" % (t, sym)
                                          for sym, t in instances.values()),
            "located_storage": "\n".join("static %s %s_storage__; %s *%s = &%s_storage__;"
                                         % (t, s, t, s, s) for s, t in located.items()),
            "located_reset": "\n".join("  memset(&%s_storage__, 0, sizeof %s_storage__);" % (s, s)
                                       for s in located),
        }
        harness = os.path.join(work, "plctest_main.c")
        with open(harness, "w") as f:
            f.write(prelude + body + C_EPILOGUE)

        sources = [harness] + [c for c in glob.glob(os.path.join(work, "*.c"))
                               if os.path.basename(c) not in ("POUS.c", "plctest_main.c")]
        exe = os.path.join(work, "plc.bin")
        cc = os.environ.get("CC", "gcc")
        cmd = [cc, "-std=gnu11", "-w", "-O0", "-I", MATIEC_LIB_C, "-I", work, "-o", exe] + sources + ["-lm"]
        proc = subprocess.run(cmd, capture_output=True, text=True)
        if proc.returncode != 0:
            raise PlcTestError("C build of the test harness failed:\n" + proc.stderr[-4000:])
        try:
            proc = subprocess.run([exe], capture_output=True, text=True, timeout=60)
        except subprocess.TimeoutExpired:
            raise PlcTestError("the program did not finish within 60 s of real time. Is there a "
                               "loop that never ends (WHILE/REPEAT waiting for an input)? A real "
                               "PLC would stop with a watchdog / scan-time fault.")
        out = proc.stdout
        if not quiet:
            sys.stdout.write(out)
        if proc.returncode not in (0, 1):
            raise PlcTestError("test program crashed (exit %d)\n%s" % (proc.returncode, proc.stderr))
        m = re.search(r"(\d+) check\(s\), (\d+) failure\(s\)", out)
        return (int(m.group(1)), int(m.group(2))) if m else (0, 1)
    finally:
        if keep:
            print("kept build directory:", work)
        else:
            shutil.rmtree(work, ignore_errors=True)


def read_directives(st_file):
    """Optional '(* @plctest key=value ... *)' comment in a .st file.

    test=<path>       scenario file to use (relative to the .st file)
    expect=pass|fail  whether the scenario should pass (default: pass, but fail
                      for files in starter/ and mutants/ folders)
    mode=compile      only compile this file
    """
    with open(st_file) as f:
        text = f.read()
    d = {}
    for m in re.finditer(r"\(\*\s*@plctest\b(.*?)\*\)", text, re.S):
        for kv in m.group(1).split():
            k, _, v = kv.partition("=")
            d[k.strip().lower()] = v.strip()
    if "test" in d:
        d["test"] = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(st_file)), d["test"]))
    if d.get("expect") not in (None, "pass", "fail"):
        raise PlcTestError("@plctest expect= must be pass or fail")
    return d


def find_test_for(st_file):
    """X.test next to X.st, or in the parent folder (labs/solutions/X.st -> labs/X.test)."""
    base = os.path.splitext(os.path.basename(st_file))[0] + ".test"
    here = os.path.dirname(os.path.abspath(st_file))
    for d in (here, os.path.dirname(here)):
        if os.path.exists(os.path.join(d, base)):
            return os.path.join(d, base)
    return None


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("st", nargs="?", help="Structured Text file")
    ap.add_argument("test", nargs="?", help="scenario file (.test)")
    ap.add_argument("--all", metavar="DIR", help="check every .st file under DIR")
    ap.add_argument("--matiec", help="path to a built MATIEC checkout")
    ap.add_argument("--keep", action="store_true", help="keep the generated C for inspection")
    args = ap.parse_args()

    try:
        matiec = find_matiec(args.matiec)
    except PlcTestError as e:
        print("error:", e)
        return 2

    if args.all:
        files = sorted(glob.glob(os.path.join(args.all, "**", "*.st"), recursive=True))
        bad = []
        for st in files:
            rel = os.path.relpath(st)
            try:
                d = read_directives(st)
                parts = os.path.normpath(st).split(os.sep)
                test = None if d.get("mode") == "compile" else (d.get("test") or find_test_for(st))
                expect = d.get("expect") or ("fail" if ("starter" in parts or "mutants" in parts) else "pass")
                checks, fails = run_one(matiec, st, test, quiet=True)
                if not test:
                    ok, detail = True, "compiles"
                elif expect == "fail":
                    ok = fails > 0
                    detail = ("fails its test as expected (%d/%d checks fail)" % (fails, checks) if ok
                              else "expected to FAIL its test but passed all %d checks" % checks)
                else:
                    ok = fails == 0
                    detail = "%d checks" % checks if ok else "%d of %d checks failed" % (fails, checks)
                status = "PASS" if ok else "FAIL"
            except PlcTestError as e:
                ok, status, detail = False, "ERROR", str(e).strip().splitlines()[-1]
            print("%-5s %s  (%s)" % (status, rel, detail))
            if not ok:
                bad.append(rel)
        print("\n%d file(s), %d problem(s)" % (len(files), len(bad)))
        return 1 if bad else 0

    if not args.st:
        ap.print_help()
        return 2
    try:
        test = args.test or read_directives(args.st).get("test") or find_test_for(args.st)
    except (PlcTestError, OSError) as e:
        print("error:", e)
        return 1
    try:
        checks, fails = run_one(matiec, args.st, test, keep=args.keep)
    except PlcTestError as e:
        print("error:", e)
        return 1
    if test is None:
        print("compiled OK:", args.st, "(no .test file, nothing run)")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
