"""The game's palette for recipes: reads src/core/palette.gd so a colour lives in one place.

`HEX` maps each `const NAME := Color("rrggbb")` in palette.gd to its lowercase hex, without '#'.
`RECIPE` is the same palette under the names the Blender kit paints with (tools/blender/common.py
HEX): bone is SAND, oxide is RUST, petrol is VERDIGRIS, mint is ARC; the rest are the constant's
name in lower case. No dependencies, so the icon generator and Blender's Python both import it.

Check, writing nothing: python3 tools/palette_gd.py --check [common.py]
(exits 1 and names every tools/blender/common.py HEX entry that differs from palette.gd; that table
stays a literal because tools/asset-forge parses it with ast).
"""
import ast
import os
import re
import sys

PALETTE_GD = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "core", "palette.gd"))
_CONST = re.compile(r'^const ([A-Z_]+) := Color\("([0-9a-fA-F]{6})"\)', re.M)

ALIASES = {"bone": "SAND", "oxide": "RUST", "petrol": "VERDIGRIS", "mint": "ARC"}


def read(path=PALETTE_GD):
    with open(path, encoding="utf-8") as f:
        return {name: value.lower() for name, value in _CONST.findall(f.read())}


HEX = read()


def recipe(*names):
    """{recipe name: hex} for the names asked, each an alias or a palette.gd constant in lower case."""
    out = {}
    for name in names:
        const = ALIASES.get(name, name.upper())
        if const not in HEX:
            raise KeyError("palette.gd has no %s (recipe name %r)" % (const, name))
        out[name] = HEX[const]
    return out


COMMON_PY = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "blender", "common.py"))


def mirror_drift(common_py=COMMON_PY):
    """{recipe name: (mirror hex, palette.gd hex)} for every common.py HEX entry that disagrees."""
    with open(common_py, encoding="utf-8") as f:
        tree = ast.parse(f.read())
    table = next(ast.literal_eval(n.value) for n in tree.body
                 if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "HEX" for t in n.targets))
    out = {}
    for name, value in table.items():
        const = ALIASES.get(name, name.upper())
        if HEX.get(const) != value.lower():
            out[name] = (value, HEX.get(const))
    return out


if __name__ == "__main__":
    if sys.argv[1:2] != ["--check"]:
        sys.exit("usage: palette_gd.py --check [common.py]")
    drift = mirror_drift(*sys.argv[2:3])
    for name, (mirror, truth) in sorted(drift.items()):
        print("%s: common.py %s, palette.gd %s" % (name, mirror, truth))
    print("palette mirror: %s" % ("FAIL" if drift else "PASS"))
    sys.exit(1 if drift else 0)
