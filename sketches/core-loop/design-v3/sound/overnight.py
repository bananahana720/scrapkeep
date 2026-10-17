"""Evolve every standing pick onto its written theme, one cue after another, overnight.

    python overnight.py <render folder> <score dir> [cue ...]

Per cue (SCORE.md "Evolve the current tracks"): stretch the standing pick onto the cue's grid,
split it with htdemucs_6s, read its key offset with check_score.py, master the standing pick through
the mix chain, build the hybrid (kept drums and bass shifted onto the cue's key, plus the theme's
lead), cover the hybrid with ACE-Step XL in final mode at strengths 0.55 and 0.65 with two seeds,
and gate every take with gate_cue.py. One cue failing never stops the run: its error goes in
<render folder>/score/overnight.json and the next cue starts. Cues already in overnight.json with
a gate are skipped, so a restarted run resumes.
"""

import json
import subprocess
import sys
import time
import traceback
from pathlib import Path

import soundfile as sf

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import cut_loops  # noqa: E402

PY = sys.executable
DEMUCS = Path.home() / ".local/share/demucs-venv/bin/demucs"
SEEDS = ["3101", "3102"]
STRENGTHS = (0.55, 0.65)
NO = " No vocals. No pentatonic or East Asian melody or instruments."

# cue: (standing pick relative to the render folder, parent caption job, room, loops in game)
PICKS = {
    "roam-spillway": ("renders/lab-round5-1/grid172/roam-spillway-s2501-172bpm.wav", "round5:roam-spillway", "spillway", True),
    "title-a": ("renders/sketch-1/title-a-sax-noir/f91247ea-1d1c-c226-cecc-5635e9a422e4.wav", "sketch:title-a-sax-noir", "neutral", False),
    "title-b": ("renders/sketch-1/title-b-machine-lead/c955043f-d642-ce30-90b2-116687ac3989.wav", "sketch:title-b-machine-lead", "neutral", False),
    "title-c": ("renders/lab-round3-1/title-c2-show-opening/1132a7ef-e5bf-63ca-6a7e-2635f35641ca.wav", "round3:title-c2-show-opening", "neutral", False),
    "spillway-loop": ("loops/spillway-loop-s2101-16bar-loop.wav", "sketch:spillway-loop", "spillway", True),
    "dig-loop": ("loops/dig-loop-s2102-16bar-loop.wav", "sketch:dig-loop", "dig", True),
    "roam-dig": ("renders/lab-round5-1/grid172/roam-dig-s2501-172bpm.wav", "round5:roam-dig", "dig", True),
    "highdraft-loop": ("loops/highdraft-loop-s2101-16bar-loop.wav", "sketch:highdraft-loop", "highdraft", True),
    "roam-highdraft": ("renders/lab-round5-1/grid172/roam-highdraft-s2501-172bpm.wav", "round5:roam-highdraft", "highdraft", True),
    "boss-brindle": ("renders/lab-round4-1/grid129/boss-brindle-s2402-129bpm.wav", "round4:boss-brindle", "boss", True),
    "boss-waking": ("renders/lab-round4-1/grid129/boss-waking-s2401-129bpm.wav", "round4:boss-waking", "boss", True),
    "boss-mind": ("renders/lab-round4-1/grid129/boss-mind-s2402-129bpm.wav", "round4:boss-mind", "boss", True),
    "camp": ("renders/lab-round5-1/grid129/camp-s2502-129bpm.wav", "round5:camp", "neutral", True),
    "summary-win": ("renders/lab-round5-1/grid129/summary-win-s2501-129bpm.wav", "round5:summary-win", "neutral", False),
    "summary-loss": ("renders/lab-round5-1/grid129/summary-loss-s2502-129bpm.wav", "round5:summary-loss", "neutral", False),
    "ending": ("renders/lab-round5-1/grid172/ending-s2501-172bpm.wav", "round5:ending", "neutral", False),
}
KEYSCALE = {"dorian": "minor", "aeolian": "minor", "phrygian": "minor", "lydian_minor": "minor", "major": "major"}
MODE_WORDS = {"dorian": "Dorian", "aeolian": "minor", "phrygian": "Phrygian", "lydian_minor": "minor with a raised fourth",
              "major": "major"}


def log(msg):
    print(time.strftime("%H:%M:%S"), msg, flush=True)


def run(cmd, **kw):
    return subprocess.run([str(c) for c in cmd], check=True, capture_output=True, text=True, **kw)


def caption(ace, ref, cue, themes):
    block, name = ref.split(":")
    variants = ace["sketch"]["variants"] if block == "sketch" else ace["experiments"][block]["variants"]
    base = next(v for v in variants if v["name"] == name).get("caption") or ace["caption"]
    row = themes.CUES[cue]
    key = f" In {row['tonic']} {MODE_WORDS[row['mode']]}. The lead plays this exact melody: {row['lead']}."
    text = base.replace(" No vocals.", "").rstrip(". ") + "." + key + NO
    return text[:512]


def one(cue, root, score, ace, themes):
    rel, ref, room, loop = PICKS[cue]
    row = themes.CUES[cue]
    bpm = row["bpm"]
    work = root / "score" / cue
    work.mkdir(parents=True, exist_ok=True)

    src = root / rel
    x, sr = sf.read(src)
    mono = x.mean(axis=1) if x.ndim > 1 else x
    flux, rate = cut_loops.onset_envelope(mono, sr)
    read = float(cut_loops.tempo(flux, rate, bpm * 0.85, bpm * 1.15))
    seconds = min(len(mono) / sr * bpm / read, 96.0)
    standing = work / f"{cue}-standing.wav"
    stretched = work / "stretched.wav"
    run(["rubberband", "-q", "--fine", "-T", f"{bpm / read:.5f}", src, stretched])
    run(["ffmpeg", "-v", "error", "-y", "-i", stretched, "-t", f"{seconds:.2f}", "-ar", "48000", standing])
    stretched.unlink()
    log(f"{cue}: standing read {read:.1f}, stretched to {bpm}, {seconds:.0f} s")

    run(["nice", "-n", "10", DEMUCS, "-n", "htdemucs_6s", "-d", "cuda", "-o", work / "stems", standing])
    stems = work / "stems" / "htdemucs_6s" / standing.stem
    key = _score(score, stems / "other.wav", cue)
    offset = int(key.get("key_offset", 0))
    shift = -((offset + 6) % 12 - 6)
    log(f"{cue}: key offset {offset}, shifting stems {shift}")

    master = work / f"{cue}-standing-master.wav"
    run([PY, "-I", HERE / "evolve.py", "master", stems, master, "--room", room] + (["--loop", "--bpm", bpm] if loop else []))
    mix = _mix(score, master, work / "standing-mix.json", loop)

    hybrid = work / "hybrid.wav"
    run([PY, "-I", HERE / "evolve.py", "hybrid", score, cue, stems, hybrid, "--shift", shift])
    hybrid_score = _score(score, hybrid, cue)
    log(f"{cue}: hybrid melody {hybrid_score.get('melody_parent')} vs {hybrid_score.get('melody_control')}")

    rnd = f"score-{cue}"
    cap = caption(ace, ref, cue, themes)
    base = dict(task_type="cover", src_audio=str(hybrid), bpm=bpm, duration=int(round(seconds)), thinking=False,
                lyrics="[Instrumental]", caption=cap, keyscale=f"{row['tonic']} {KEYSCALE[row['mode']]}")
    ace_path = root / "ace.json"
    fresh = json.loads(ace_path.read_text())
    fresh["experiments"][rnd] = {"hypothesis": f"Score pass: {cue} hybrid covered onto theme {row['theme']}.",
                                 "variants": [dict(base, name=f"{cue}-c{int(s * 100)}", audio_cover_strength=s)
                                              for s in STRENGTHS]}
    ace_path.write_text(json.dumps(fresh, indent=1))
    before = set((root / "renders").glob(f"lab-{rnd}-*"))
    run([HERE / "ace_lab.sh", root, rnd, *SEEDS, "--mode", "final"])
    rundir = sorted(set((root / "renders").glob(f"lab-{rnd}-*")) - before)[-1]
    log(f"{cue}: rendered into {rundir.name}")

    run([PY, "-I", HERE / "gate_cue.py", score, cue, rundir, cue, work / "takes", "--room", room]
        + (["--loop"] if loop else []))
    gate = json.loads((work / "takes" / "gate.json").read_text())
    return dict(cue=cue, standing=rel, tempo_read=round(read, 1), key_offset=offset, shift=shift,
                standing_mix=mix, standing_score=key, hybrid_score=hybrid_score, run=rundir.name, gate=gate)


def _score(score, path, cue):
    out = subprocess.run([PY, "-I", str(score / "check_score.py"), str(path), cue], capture_output=True, text=True)
    lines = [ln for ln in out.stdout.splitlines() if ln.startswith("{")]
    return json.loads(lines[-1]) if lines else {"error": out.stderr[-300:]}


def _mix(score, path, out, loop):
    subprocess.run([PY, "-I", str(score / "check_mix.py"), "--cues"] + (["--loops"] if loop else [])
                   + [str(path), "--json", str(out)], capture_output=True)
    return json.loads(out.read_text().splitlines()[0]) if out.exists() else {}


def main(argv):
    root, score = Path(argv[0]), Path(argv[1])
    sys.path.insert(0, str(score))
    import themes
    cues = argv[2:] or list(PICKS)
    ledger_path = root / "score" / "overnight.json"
    ledger = json.loads(ledger_path.read_text()) if ledger_path.exists() else {}
    for cue in cues:
        if "gate" in ledger.get(cue, {}):
            log(f"{cue}: already gated, skipping")
            continue
        log(f"{cue}: start")
        try:
            ledger[cue] = one(cue, root, score, json.loads((root / "ace.json").read_text()), themes)
            passed = sum(1 for g in ledger[cue]["gate"] if g["score"].get("pass") and g["mix"].get("pass"))
            log(f"{cue}: done, {passed} of {len(ledger[cue]['gate'])} takes pass both checks")
        except Exception as e:  # one cue never stops the night
            detail = e.stderr[-600:] if isinstance(e, subprocess.CalledProcessError) else traceback.format_exc()[-600:]
            ledger[cue] = dict(cue=cue, error=detail)
            log(f"{cue}: FAILED {detail.splitlines()[-1] if detail else e}")
        ledger_path.write_text(json.dumps(ledger, indent=1, default=lambda o: o.item()))


if __name__ == "__main__":
    main(sys.argv[1:])
