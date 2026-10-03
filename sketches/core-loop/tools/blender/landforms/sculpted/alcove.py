"""Seed 927: continuous recessed rock; shallow cracks and gently dipping 8:1 beds.

Run Blender -b -t 8 -P this.py -- --render DIR [--seed 927] [--out FILE].
"""
import os
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cliff_strata import run

if __name__ == "__main__":
    run("alcove")
