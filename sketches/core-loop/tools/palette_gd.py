"""The game's palette for recipes: reads src/core/palette.gd so a colour lives in one place.

`HEX` maps each `const NAME := Color("rrggbb")` in palette.gd to its lowercase hex, without '#'.
`RECIPE` is the same palette under the names the Blender kit paints with (tools/blender/common.py
HEX): bone is SAND, oxide is RUST, petrol is VERDIGRIS, mint is ARC; the rest are the constant's
name in lower case. No dependencies, so the icon generator and Blender's Python both import it.
"""
import os
import re

PALETTE_GD = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "core", "palette.gd"))
_CONST = re.compile(r'^const ([A-Z_]+) := Color\("([0-9a-fA-F]{6})"\)', re.M)

# Recipe names that differ from the game's constant names.
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
