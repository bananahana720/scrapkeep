"""Headless recipe for lamp_straight_module.glb; see kit.py."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from kit import main
main("lamp_straight_module")
