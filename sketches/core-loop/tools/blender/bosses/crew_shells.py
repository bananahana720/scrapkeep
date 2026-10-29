"""Mint the Slag Bowl crowd crew shells (crew_fan, crew_pennant) to shells/<kind>.glb.

python3 crew_shells.py crew_fan crew_pennant   (needs node 22.14+; runs `npx -y mojulo@3.0.0`)
Same driver as rogues/shells.py, pointed at this directory: <kind>.mojulo.json is a workbench spec,
units cm, z up, the crew facing +x with the seat at z = 0. Each piece is its own sampled `fields`
entry whose term ids start with `<Piece>_` (Body, Hat, Teeth).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "rogues"))
import shells

shells.HERE = HERE

if __name__ == "__main__":
    os.makedirs(os.path.join(HERE, "shells"), exist_ok=True)
    for name in sys.argv[1:]:
        shells.build(name)
