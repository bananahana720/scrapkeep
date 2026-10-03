"""Seed 1203: continuous 14 m by 9 m eroded arch, high-to-low CPU bakes.

Run Blender -b -t 8 -P this.py -- --render DIR [--seed 1203] [--out FILE].
"""
import os
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cliff_strata import run

if __name__ == "__main__":
    run("arch")
