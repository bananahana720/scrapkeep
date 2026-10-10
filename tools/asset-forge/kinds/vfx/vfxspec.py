"""VFX spec: the plain-data description of one particle effect, its defaults and its checks.

Stdlib only. Runs inside the sandbox (entry.py) and outside it (validate.py, promote.py, tests),
so it holds no I/O. A spec is JSON: numbers, strings, bools, lists, dicts. The agent never writes
GDScript or a scene; the forge converts a validated spec (vfxtscn.py).
"""
import math
import re

SCHEMA = 1
BUDGET = 48              # particles per effect: the largest pooled burst in vfx.gd (fountain, 24) x 2
MAX_EMITTERS = 4
MAX_RADIUS = 8.0         # metres the simulated cloud may reach from the effect origin
WARN_RADIUS = 6.0
MESHES = ("quad", "sphere", "box", "prism")
SHAPES = ("point", "sphere", "box")
BLENDS = ("mix", "add")
NAME_RE = re.compile(r"^[a-z][a-z0-9_]{0,23}$")

TOP_KEYS = {"schema", "seed", "emitters"}

# field -> default (None = required). Types and ranges are checked in validate().
EMITTER_DEFAULTS = {
    "name": None, "amount": None, "lifetime": None, "color_ramp": None,
    "one_shot": True, "explosiveness": 1.0, "randomness": 0.0,
    "offset": [0.0, 0.0, 0.0], "shape": "point", "extents": [0.1, 0.1, 0.1],
    "direction": [0.0, 1.0, 0.0], "spread": 45.0, "velocity": [2.0, 5.0],
    "gravity": [0.0, -9.8, 0.0], "damping": [0.0, 0.0], "scale": [1.0, 1.0],
    "scale_curve": [[0.0, 1.0], [1.0, 0.0]], "emissive": 1.0, "blend": "mix",
    "mesh": "box", "mesh_size": [0.12, 0.12, 0.12], "align_y": False,
}


def _num(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v)


def _is_int(v):
    return isinstance(v, int) and not isinstance(v, bool)


def _vec(v, n):
    return isinstance(v, (list, tuple)) and len(v) == n and all(_num(x) for x in v)


def normalize(spec):
    """Spec with every default filled in. Does not check anything: call validate() on the result.
    Unknown or malformed input passes through unchanged so validate() can name it."""
    if not isinstance(spec, dict):
        return spec
    out = {"schema": spec.get("schema", SCHEMA), "seed": spec.get("seed", 1)}
    for k, v in spec.items():
        if k not in out:
            out[k] = v
    ems = spec.get("emitters")
    if isinstance(ems, list):
        out["emitters"] = []
        for e in ems:
            if not isinstance(e, dict):
                out["emitters"].append(e)
                continue
            n = {k: e[k] if k in e else (list(d) if isinstance(d, list) else d)
                 for k, d in EMITTER_DEFAULTS.items() if k in e or d is not None}
            for k, v in e.items():
                if k not in n:
                    n[k] = v
            out["emitters"].append(n)
    return out


def validate(spec, roles, budget=BUDGET, max_emitters=MAX_EMITTERS):
    """List of (code, message). Codes: schema, range, palette, budget, lifetime.
    `roles` is the set of palette role names. Pass a normalized spec."""
    errs = []
    add = lambda code, msg: errs.append((code, msg))  # noqa: E731
    if not isinstance(spec, dict):
        return [("schema", "the spec must be an object, got %s" % type(spec).__name__)]
    for k in spec:
        if k not in TOP_KEYS:
            add("schema", "unknown top-level field %r" % k)
    if spec.get("schema") != SCHEMA:
        add("schema", "schema must be %d" % SCHEMA)
    seed = spec.get("seed")
    if not _is_int(seed) or not 0 <= seed < 2 ** 31:
        add("schema", "seed must be an integer 0 to 2^31-1")
    ems = spec.get("emitters")
    if not isinstance(ems, list) or not ems:
        add("schema", "emitters must be a non-empty list")
        return errs
    if len(ems) > max_emitters:
        add("budget", "%d emitters; the cap is %d (one draw call each)" % (len(ems), max_emitters))
    total = 0
    names = set()
    for i, e in enumerate(ems):
        where = "emitters[%d]" % i
        if not isinstance(e, dict):
            add("schema", "%s must be an object" % where)
            continue
        for k in e:
            if k not in EMITTER_DEFAULTS:
                add("schema", "%s: unknown field %r" % (where, k))
        for k, d in EMITTER_DEFAULTS.items():
            if d is None and k not in e:
                add("schema", "%s: missing required field %r" % (where, k))
        name = e.get("name")
        if not isinstance(name, str) or not NAME_RE.match(name):
            add("schema", "%s: name must match %s" % (where, NAME_RE.pattern))
        elif name in names:
            add("schema", "%s: duplicate name %r" % (where, name))
        else:
            names.add(name)
        amount = e.get("amount")
        if not _is_int(amount):
            add("schema", "%s: amount must be an integer" % where)
        elif amount < 1:
            add("range", "%s: amount must be at least 1" % where)
        else:
            total += amount
        life = e.get("lifetime")
        if not _num(life):
            add("schema", "%s: lifetime must be a number" % where)
        elif not 0.05 <= life <= 2.0:
            add("lifetime", "%s: lifetime %.3f s is outside 0.05 to 2.0" % (where, life))
        for k in ("one_shot", "align_y"):
            if k in e and not isinstance(e[k], bool):
                add("schema", "%s: %s must be true or false" % (where, k))
        for k, lo, hi in (("explosiveness", 0, 1), ("randomness", 0, 1), ("spread", 0, 180), ("emissive", 0, 3)):
            if k in e:
                if not _num(e[k]):
                    add("schema", "%s: %s must be a number" % (where, k))
                elif not lo <= e[k] <= hi:
                    add("range", "%s: %s %s is outside %s to %s" % (where, k, e[k], lo, hi))
        for k, n, lo, hi in (("offset", 3, -3, 3), ("extents", 3, 0, 2), ("gravity", 3, -40, 40),
                             ("mesh_size", 3, 0.02, 1.0)):
            if k in e:
                if not _vec(e[k], n):
                    add("schema", "%s: %s must be a list of %d numbers" % (where, k, n))
                elif not all(lo <= x <= hi for x in e[k]):
                    add("range", "%s: %s %s is outside %s to %s" % (where, k, list(e[k]), lo, hi))
        if "direction" in e:
            if not _vec(e["direction"], 3):
                add("schema", "%s: direction must be a list of 3 numbers" % where)
            elif math.sqrt(sum(x * x for x in e["direction"])) < 1e-6:
                add("range", "%s: direction must not be the zero vector" % where)
        for k, hi, lo in (("velocity", 20.0, 0.0), ("damping", 20.0, 0.0), ("scale", 4.0, 0.05)):
            if k in e:
                if not _vec(e[k], 2):
                    add("schema", "%s: %s must be [min, max]" % (where, k))
                elif not (lo <= e[k][0] <= e[k][1] <= hi):
                    add("range", "%s: %s %s must satisfy %s <= min <= max <= %s" % (where, k, list(e[k]), lo, hi))
        if "shape" in e and e["shape"] not in SHAPES:
            add("schema", "%s: shape %r not in %s" % (where, e["shape"], ", ".join(SHAPES)))
        if "blend" in e and e["blend"] not in BLENDS:
            add("schema", "%s: blend %r not in %s" % (where, e["blend"], ", ".join(BLENDS)))
        if "mesh" in e and e["mesh"] not in MESHES:
            add("schema", "%s: mesh %r not in %s" % (where, e["mesh"], ", ".join(MESHES)))
        _curve(e.get("scale_curve"), where, add)
        _ramp(e.get("color_ramp"), where, roles, add)
    if total > budget:
        add("budget", "%d particles in total; the per-effect budget is %d" % (total, budget))
    return errs


def _curve(c, where, add):
    if c is None:
        return
    if not isinstance(c, list) or not 2 <= len(c) <= 6 or not all(_vec(p, 2) for p in c):
        add("schema", "%s: scale_curve must be 2 to 6 [t, value] keyframes" % where)
        return
    ts = [p[0] for p in c]
    if any(not 0 <= t <= 1 for t in ts) or any(b <= a for a, b in zip(ts, ts[1:])):
        add("range", "%s: scale_curve times must rise strictly inside 0 to 1" % where)
    if any(not 0 <= p[1] <= 2 for p in c):
        add("range", "%s: scale_curve values must be 0 to 2" % where)


def _ramp(r, where, roles, add):
    if r is None:
        return
    if not isinstance(r, list) or not 2 <= len(r) <= 5:
        add("schema", "%s: color_ramp must be 2 to 5 stops" % where)
        return
    ts = []
    for j, s in enumerate(r):
        w = "%s.color_ramp[%d]" % (where, j)
        if not isinstance(s, dict) or set(s) - {"t", "role", "alpha"} or "t" not in s or "role" not in s:
            add("schema", "%s: a stop is {\"t\": 0..1, \"role\": <palette role>, \"alpha\": 0..1}" % w)
            continue
        if not _num(s["t"]) or not 0 <= s["t"] <= 1:
            add("range", "%s: t must be 0 to 1" % w)
        else:
            ts.append(s["t"])
        if not isinstance(s["role"], str) or s["role"] not in roles:
            add("palette", "%s: %r is not a palette role (roles: %s). Hex colours are not allowed."
                % (w, s["role"], ", ".join(sorted(roles))))
        a = s.get("alpha", 1.0)
        if not _num(a) or not 0 <= a <= 1:
            add("range", "%s: alpha must be 0 to 1" % w)
    if any(b <= a for a, b in zip(ts, ts[1:])):
        add("range", "%s: color_ramp times must rise strictly" % where)


def total_amount(spec):
    return sum(e["amount"] for e in spec["emitters"])
