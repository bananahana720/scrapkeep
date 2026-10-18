"""Spice up every current pick: split the original take, remix it with evolve.py's --spice chain, master.

    python spice.py <render folder> [cue ...]

Andrew's direction (2026-10-17): the current jazzy tracks stay the picks; mix, master and spice them
up, leaning into the hard end switch-ups and the electro bass. So each pick is used as rendered, at
its own tempo and full length, with no theme retake and no loop cut. Output lands in
<render folder>/spice/<cue>-spiced.wav (<cue>-light.wav for the camp, the run-loss summary and the
ending, which keep their jazz-club feel), plus <cue>-current.wav (the same stems through the plain
master) for a fair A/B.
"""

import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from overnight import DEMUCS, PICKS  # noqa: E402

PY = sys.executable
# Andrew tapped "Keep them lighter" (2026-10-17): these keep the jazz-club feel, with a softer machine bed
LIGHT = {"camp", "summary-loss", "ending"}
COMBAT = ("renders/lab-round6-1/grid129/combat-hype-cover-mechswing-s2601-129bpm.wav", "neutral")


def main(argv):
    root = Path(argv[0])
    picks = {"combat-hype": COMBAT, **{c: (rel, room) for c, (rel, _, room, _) in PICKS.items()}}
    out = root / "spice"
    for cue in argv[1:] or picks:
        rel, room = picks[cue]
        src = root / rel
        stems = out / "stems" / "htdemucs_6s" / src.stem
        if not (stems / "bass.wav").exists():
            subprocess.run(["nice", "-n", "10", str(DEMUCS), "-n", "htdemucs_6s", "-d", "cuda", "-o", str(out / "stems"),
                            str(src)], check=True, capture_output=True)
        top = ("light", ["--light"]) if cue in LIGHT else ("spiced", ["--spice"])
        for name, flag in (top, ("current", [])):
            subprocess.run([PY, "-I", str(HERE / "evolve.py"), "master", str(stems), str(out / f"{cue}-{name}.wav"),
                            "--room", room] + flag, check=True)
        print(cue, "done", flush=True)


if __name__ == "__main__":
    main(sys.argv[1:])
