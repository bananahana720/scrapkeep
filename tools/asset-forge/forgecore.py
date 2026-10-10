"""Stdlib helpers shared by forge.py and the kinds: packs, palette, slots, versions, GLB
read-back, hashing and scoring."""
import ast
import hashlib
import json
import os
import re
import shutil
import stat
import struct
import tempfile
import tomllib
from pathlib import Path

FORGE_DIR = Path(__file__).resolve().parent
REPO = FORGE_DIR.parents[1]
KINDS_DIR = FORGE_DIR / "kinds"
PACKS_DIR = FORGE_DIR / "packs"
# Files the outer forge writes at the top of a version dir; a directory planted at one of
# these names would make the write fail, so sweep removes it.
RESERVED = {"run.log", "result.json", "validate.json", "manifest.json", "agent.json", "agent.stderr", "notes.md"}


def scratch_root():
    return Path(os.environ.get("FORGE_HOME") or REPO / "artifacts" / "local" / "forge")


def sha256_file(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def sha256_text(text):
    return hashlib.sha256(text.encode()).hexdigest()


# --- packs ----------------------------------------------------------------------------
def load_pack(name, packs_dir=None):
    path = Path(packs_dir or PACKS_DIR) / (name + ".toml")
    if not path.is_file():
        raise SystemExit("forge: no pack %r (looked for %s)" % (name, path))
    data = tomllib.loads(path.read_text())
    root = Path(os.environ.get("FORGE_REPO") or REPO)
    for key in ("sketch", "palette_source", "helper_dir", "inspect"):
        if key not in data:
            raise SystemExit("forge: pack %s lacks %r" % (name, key))
        data[key + "_path"] = root / data[key]
    data["pack_file"] = str(path)
    data["repo_root"] = str(root)
    return data


def pack_names(packs_dir=None):
    return sorted(p.stem for p in Path(packs_dir or PACKS_DIR).glob("*.toml"))


def parse_palette(path):
    """palette.gd `const NAME := Color("hex")` lines -> {NAME: hex}."""
    out = {}
    for m in re.finditer(r'^const\s+([A-Z_][A-Z0-9_]*)\s*:?=\s*Color\("#?([0-9a-fA-F]{6})"\)', Path(path).read_text(), re.M):
        out[m.group(1)] = m.group(2).lower()
    return out


def parse_assignment(path, name):
    """Literal value of a module-level `name = {...}` in a Python file, read with ast (the
    helper imports bpy, so it cannot be imported here)."""
    tree = ast.parse(Path(path).read_text())
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == name for t in node.targets):
            return ast.literal_eval(node.value)
    raise SystemExit("forge: %s defines no %s" % (path, name))


def common_py(pack):
    return Path(pack["helper_dir_path"]) / "common.py"


def pack_palette(pack):
    """{role: hex} from palette.gd through the pack's role names, plus declared extensions
    whose hex comes from the helper's HEX table."""
    gd = parse_palette(pack["palette_source_path"])
    roles = {}
    for const, role in pack["palette"]["roles"].items():
        if const not in gd:
            raise SystemExit("forge: palette.gd has no %s" % const)
        roles[role] = gd[const]
    helper_hex = parse_assignment(common_py(pack), "HEX")
    for role in pack["palette"].get("extensions", {}).get("roles", []):
        roles[role] = helper_hex[role]
    return roles


def palette_drift(pack):
    """Roles where the helper's HEX mirror disagrees with palette.gd."""
    helper_hex = parse_assignment(common_py(pack), "HEX")
    return {r: (h, helper_hex.get(r)) for r, h in pack_palette(pack).items() if helper_hex.get(r) != h}


def pack_slots(pack):
    return list(parse_assignment(common_py(pack), "SLOTS"))


def slot_specs(pack):
    return parse_assignment(common_py(pack), "SLOTS")


# --- kinds ----------------------------------------------------------------------------
def kind_names(kinds_dir=None):
    return sorted(p.name for p in Path(kinds_dir or KINDS_DIR).iterdir() if (p / "kind.toml").is_file())


def load_kind(name, kinds_dir=None):
    d = Path(kinds_dir or KINDS_DIR) / name
    if not (d / "kind.toml").is_file():
        raise SystemExit("forge: no kind %r; known kinds: %s" % (name, ", ".join(kind_names(kinds_dir)) or "none"))
    meta = tomllib.loads((d / "kind.toml").read_text())
    meta["dir"] = d
    return meta


def load_module(path, name):
    import importlib.util
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# --- versions -------------------------------------------------------------------------
def asset_dir(pack, asset):
    return scratch_root() / pack / asset


def versions(pack, asset):
    d = asset_dir(pack, asset)
    if not d.is_dir():
        return []
    return sorted(int(p.name[1:]) for p in d.iterdir() if re.fullmatch(r"v\d{3,}", p.name) and p.is_dir())


def alloc_version(pack, asset):
    """Creates the next vNNN directory atomically (mkdir fails if a racer took it)."""
    d = asset_dir(pack, asset)
    d.mkdir(parents=True, exist_ok=True)
    n = (versions(pack, asset) or [0])[-1] + 1
    while True:
        try:
            (d / ("v%03d" % n)).mkdir()
            return d / ("v%03d" % n)
        except FileExistsError:
            n += 1


def version_dir(pack, asset, v):
    v = v if v.startswith("v") else "v" + v
    m = re.fullmatch(r"v(\d+)", v)
    if not m:
        raise SystemExit("forge: bad version %r" % v)
    return asset_dir(pack, asset) / ("v%03d" % int(m.group(1)))


def sweep(vdir):
    """Recipe code can plant symlinks, fifos or sockets in its writable version dir; the
    unsandboxed forge would then read or write through them as Andrew. Delete every entry
    that is not a plain file or directory, before any outer step touches the tree."""
    # The recipe can chmod a directory to write+exec only; os.walk would then skip its
    # contents in silence. Restore owner access before listing, and fail on any listing error.
    def raise_error(exc):
        raise exc

    removed = []
    root = os.path.normpath(os.fspath(vdir))
    os.chmod(root, 0o700)
    for top, dirs, files in os.walk(root, followlinks=False, onerror=raise_error):
        keep = []
        for name in dirs + files:
            p = os.path.join(top, name)
            st = os.lstat(p)
            if stat.S_ISDIR(st.st_mode):
                os.chmod(p, 0o700)
                if top == root and name in RESERVED:
                    shutil.rmtree(p)
                    removed.append(name)
                else:
                    keep.append(name)
            elif stat.S_ISREG(st.st_mode):
                os.chmod(p, 0o600)
            else:
                os.unlink(p)
                removed.append(os.path.relpath(p, root))
        dirs[:] = [d for d in dirs if d in keep]
    return removed


def read_json(path, default=None):
    p = Path(path)
    if p.is_symlink() or not p.is_file():
        return default
    return json.loads(p.read_text())


def write_text(path, text):
    """Write through a fresh temp file and rename it into place: a rename replaces a
    symlink at `path` instead of following it."""
    path = Path(path)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix="." + path.name + ".")
    with os.fdopen(fd, "w") as f:
        f.write(text)
    os.replace(tmp, path)


def write_json(path, data):
    write_text(path, json.dumps(data, indent=2, sort_keys=True) + "\n")


# --- glb read-back ----------------------------------------------------------------------
def glb_info(path):
    data = Path(path).read_bytes()
    if data[:4] != b"glTF":
        raise ValueError("not a GLB")
    jlen = struct.unpack("<I", data[12:16])[0]
    g = json.loads(data[20:20 + jlen])
    nodes = g.get("nodes", [])
    meshes = g.get("meshes", [])
    scene = g["scenes"][g.get("scene", 0)]
    tris = draws = instances = 0
    stack = list(scene.get("nodes", []))
    seen = set()
    while stack:
        i = stack.pop()
        if i in seen:
            continue
        seen.add(i)
        n = nodes[i]
        stack += n.get("children", [])
        if "mesh" in n:
            instances += 1
            for prim in meshes[n["mesh"]]["primitives"]:
                draws += 1
                if prim.get("mode", 4) == 4:
                    count = g["accessors"][prim["indices"]]["count"] if "indices" in prim else g["accessors"][prim["attributes"]["POSITION"]]["count"]
                    tris += count // 3
    return {"nodes": len(nodes), "mesh_nodes": instances, "draw_calls": draws, "triangles": tris,
            "materials": [m.get("name", "") for m in g.get("materials", [])], "bytes": len(data)}


# --- scoring ----------------------------------------------------------------------------
STATES = ("pass", "info", "warn", "fail")


def check(cid, state, value, detail):
    assert state in ("pass", "warn", "fail", "info")
    return {"id": cid, "state": state, "value": value, "detail": detail}


def score(checks):
    fails = sum(c["state"] == "fail" for c in checks)
    warns = sum(c["state"] == "warn" for c in checks)
    s = max(0, 10 - 3 * fails - warns)
    if fails:
        s = min(s, 4)
    elif warns:
        s = min(s, 8)
    worst = "fail" if fails else "warn" if warns else "pass"
    return {"score": s, "state": worst, "passed": not fails}


# --- colour -----------------------------------------------------------------------------
def hex_rgb(h):
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def segment_distance(c, a, b):
    ab = [b[i] - a[i] for i in range(3)]
    den = sum(x * x for x in ab)
    t = 0.0 if den == 0 else max(0.0, min(1.0, sum((c[i] - a[i]) * ab[i] for i in range(3)) / den))
    p = [a[i] + ab[i] * t for i in range(3)]
    return sum((c[i] - p[i]) ** 2 for i in range(3)) ** 0.5


def palette_distance(hexcol, palette_hexes):
    """Distance from a colour to the nearest palette colour or palette mix (a straight
    line between two palette colours, which is what common.mix paints)."""
    c = hex_rgb(hexcol)
    pts = [hex_rgb(h) for h in palette_hexes]
    return min(segment_distance(c, a, b) for a in pts for b in pts)
