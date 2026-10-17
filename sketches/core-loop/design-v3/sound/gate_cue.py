"""Gate one cue's rendered takes: grid, stems, score check, master, mix check.

    python gate_cue.py <score dir> <cue> <run dir> <job prefix> <out dir> [--room NAME] [--loop]

For each take in the run's manifest whose job name starts with <job prefix>: measure the kick
tempo and stretch onto the cue's grid with Rubber Band when it is more than 0.3 BPM off, split
it with htdemucs_6s (the demucs-venv), run check_score.py on the "other" stem, master the stems
with evolve.py, and run check_mix.py --cues on the master. Writes <out dir>/gate.json, one row
per take, and prints a table. <score dir> holds themes.py, check_score.py and check_mix.py.
"""

import json
import subprocess
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import cut_loops  # noqa: E402

PY = sys.executable
DEMUCS = Path.home() / ".local/share/demucs-venv/bin/demucs"


def run_json(cmd):
    out = subprocess.run(cmd, capture_output=True, text=True)
    lines = [ln for ln in out.stdout.splitlines() if ln.startswith("{")]
    return json.loads(lines[-1]) if lines else {"error": (out.stderr or out.stdout)[-400:]}


def main(argv):
    score, cue, run, prefix, out = Path(argv[0]), argv[1], Path(argv[2]), argv[3], Path(argv[4])
    room = argv[argv.index("--room") + 1] if "--room" in argv else "neutral"
    loop = "--loop" in argv
    sys.path.insert(0, str(score))
    import themes
    bpm = themes.CUES[cue]["bpm"]
    out.mkdir(parents=True, exist_ok=True)
    rows = []
    for job in json.loads((run / "manifest.json").read_text()):
        if not job["name"].startswith(prefix) or not job.get("success"):
            continue
        for audio in job["audios"]:
            name = f"{cue}--{job['name']}-s{audio['seed']}"
            take = out / f"{name}.wav"
            x, sr = sf.read(audio["path"])
            mono = x.mean(axis=1) if x.ndim > 1 else x
            flux, rate = cut_loops.onset_envelope(mono, sr)
            read = float(cut_loops.tempo(flux, rate, bpm * 0.85, bpm * 1.15))
            if abs(read - bpm) > 0.3:
                subprocess.run(["rubberband", "-q", "--fine", "-T", f"{bpm / read:.5f}", audio["path"], str(take)],
                               check=True, capture_output=True)
            else:
                sf.write(take, x, sr)
            subprocess.run(["nice", "-n", "10", str(DEMUCS), "-n", "htdemucs_6s", "-d", "cuda", "-o", str(out / "stems"),
                            str(take)], check=True, capture_output=True)
            stems = out / "stems" / "htdemucs_6s" / name
            score_row = run_json([PY, "-I", str(score / "check_score.py"), str(stems / "other.wav"), cue])
            master = out / f"{name}-master.wav"
            subprocess.run([PY, "-I", str(HERE / "evolve.py"), "master", str(stems), str(master), "--room", room]
                           + (["--loop", "--bpm", str(bpm)] if loop else []), check=True)
            mix_json = out / f"{name}-mix.json"
            subprocess.run([PY, "-I", str(score / "check_mix.py"), "--cues"] + (["--loops"] if loop else [])
                           + [str(master), "--json", str(mix_json)], capture_output=True)
            mix_row = json.loads(mix_json.read_text().splitlines()[0]) if mix_json.exists() else {}
            rows.append(dict(take=name, tempo_read=round(read, 1), stretched=abs(read - bpm) > 0.3,
                             score=score_row, mix=mix_row))
    (out / "gate.json").write_text(json.dumps(rows, indent=1, default=lambda o: o.item()))
    print(f"{'take':44s} {'tempo':>6s} {'key':>5s} {'mel':>5s} {'ctrl':>5s} {'score':>6s} {'mix':>5s}")
    for r in rows:
        s, m = r["score"], r["mix"]
        print(f"{r['take']:44s} {r['tempo_read']:6.1f} {s.get('key_fit', 0):5.2f} {s.get('melody_parent', 0):5.2f} "
              f"{s.get('melody_control', 0):5.2f} {'PASS' if s.get('pass') else 'FAIL':>6s} "
              f"{'PASS' if m.get('pass') else 'FAIL':>5s}")


if __name__ == "__main__":
    main(sys.argv[1:])
