"""Headless recipe for strut_bent.glb; see kit.py."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from kit import main
main("strut_bent")
