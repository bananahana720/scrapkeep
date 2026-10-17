"""Render the radio's collectible takes: wild covers of the current picks, one station at a time.

    python radio_takes.py <render folder> [take id ...] [--seeds a,b] [--tier legend] [--station furnace]
                          [--first] [--wordless]
    python radio_takes.py --list [same filters]

Andrew (2026-10-17): the radio is a core reason the game is special. Every take is an ACE-Step cover of
one of his current picks (overnight.PICKS, plus gapfill's combat-hype), kept recognisable by its melody
and beat but played however the station feels that night: cover strength 0.30 to 0.60 from
assets/radio/catalogue.json (lower is wilder; legends sit lowest). The mechanics are gapfill.py's:
stretch the parent pick to the take's tempo with Rubber Band, cover it in final mode with two seeds,
split each take with htdemucs_6s and master it through evolve.py (--light for b-sides, --spice
otherwise). Takes run their own length ("seconds" in the catalogue), not gapfill's 64 s.

--first renders one take per content station (the first row of each), so every station plays before
the rest. Rows marked "wordless-vocal-texture" are skipped unless --wordless: the sound bible still
says no vocals, and that is Andrew's call.

Writes <render folder>/radio/<take id>-s<seed>.wav, the stems under <render folder>/radio/stems/, and
radio_renders.json beside this file: one row per take with its id, station, tier, parent pick and takes.
"""

import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
CATALOGUE = HERE.parent.parent / "assets" / "radio" / "catalogue.json"
REGISTRY = HERE / "radio_renders.json"
PY = sys.executable
ROUND = "radio"
WORDLESS = "wordless-vocal-texture"


def option(argv, name, default=None):
    return argv[argv.index(name) + 1] if name in argv else default


def plan(argv):
    takes = json.loads(CATALOGUE.read_text())["takes"]
    flags = {"--seeds", "--tier", "--station"}
    values = {argv[i + 1] for i, a in enumerate(argv[:-1]) if a in flags}
    wanted = {a for a in argv if a.startswith("take-") and a not in values}
    tier = option(argv, "--tier")
    station = option(argv, "--station")
    rows = [t for t in takes if (not wanted or t["id"] in wanted)
            and (tier is None or t["tier"] == tier)
            and (station is None or t["station"] == station)
            and ("--wordless" in argv or WORDLESS not in t["references"])]
    if "--first" in argv:
        seen, first = set(), []
        for t in rows:
            if t["station"] not in seen:
                seen.add(t["station"])
                first.append(t)
        rows = first
    return rows


def parents():
    # Imported here so --list runs without soundfile, demucs or a GPU.
    sys.path.insert(0, str(HERE))
    from overnight import PICKS  # noqa: E402
    out = {cue: rel for cue, (rel, _, _, _) in PICKS.items()}
    out["combat-hype"] = "renders/lab-round6-1/grid129/combat-hype-cover-mechswing-s2601-129bpm.wav"
    return out


def source(root, take, parent_of):
    """The parent pick stretched to the take's tempo with Rubber Band and cut to the take's length."""
    out = root / ROUND / "src" / f"{take['id']}-{take['bpm']}.wav"
    if out.exists():
        return out
    out.parent.mkdir(parents=True, exist_ok=True)
    sys.path.insert(0, str(HERE))
    from gapfill import tempo_of  # noqa: E402
    src = root / parent_of[take["pick"]]
    read = tempo_of(src) or float(subprocess.run([PY, "-I", "-c", (
        "import sys; sys.path.insert(0, %r); import cut_loops, soundfile as sf; x, sr = sf.read(%r); "
        "m = x.mean(axis=1) if x.ndim > 1 else x; f, r = cut_loops.onset_envelope(m, sr); "
        "print(cut_loops.tempo(f, r, 70, 190))") % (str(HERE), str(src))], capture_output=True, text=True, check=True).stdout)
    tmp = out.with_suffix(".tmp.wav")
    subprocess.run(["rubberband", "-q", "--fine", "-T", f"{take['bpm'] / read:.5f}", str(src), str(tmp)], check=True, capture_output=True)
    # A parent shorter than the take loops under ffmpeg so the cover has the whole length to work over.
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-stream_loop", "-1", "-i", str(tmp), "-t", str(take["seconds"]),
                    "-ar", "48000", str(out)], check=True)
    tmp.unlink()
    return out


def main(argv):
    rows = plan(argv)
    if "--list" in argv:
        for t in rows:
            print(f"{t['id']:34} {t['station']:9} {t['tier']:7} {t['pick']:15} {t['bpm']:>3} {t['key']:8} "
                  f"s{t['strength']:.2f} {t['seconds']}s")
        print(f"{len(rows)} takes")
        return
    import soundfile as sf
    root = Path(argv[0])
    seeds = option(argv, "--seeds", "5101,5102").split(",")
    parent_of = parents()
    from overnight import DEMUCS  # noqa: E402
    ace_path = root / "ace.json"
    ace = json.loads(ace_path.read_text())
    ace["experiments"][ROUND] = {
        "hypothesis": "Radio takes: wild covers of the current picks, one lane per station, bigger takes for harder finds.",
        "variants": [dict(name=t["id"], task_type="cover", src_audio=str(source(root, t, parent_of)),
                          audio_cover_strength=t["strength"], bpm=t["bpm"], keyscale=t["key"], duration=t["seconds"],
                          thinking=False, lyrics="[Instrumental]", caption=t["caption"]) for t in rows]}
    ace_path.write_text(json.dumps(ace, indent=1))
    before = set((root / "renders").glob(f"lab-{ROUND}-*"))
    subprocess.run([str(HERE / "ace_lab.sh"), str(root), ROUND, *seeds, "--mode", "final"], check=True)
    run = sorted(set((root / "renders").glob(f"lab-{ROUND}-*")) - before)[-1]
    out = root / ROUND
    registry = {r["id"]: r for r in json.loads(REGISTRY.read_text())} if REGISTRY.exists() else {}
    for job in json.loads((run / "manifest.json").read_text()):
        take = next((t for t in rows if t["id"] == job["name"]), None)
        if take is None or not job.get("success"):
            continue
        files = []
        for audio in job["audios"]:
            name = f"{take['id']}-s{audio['seed']}"
            raw = out / f"{name}-raw.wav"
            x, sr = sf.read(audio["path"])
            sf.write(raw, x, sr)
            subprocess.run(["nice", "-n", "10", str(DEMUCS), "-n", "htdemucs_6s", "-d", "cuda", "-o", str(out / "stems"), str(raw)],
                           check=True, capture_output=True)
            stems = out / "stems" / "htdemucs_6s" / raw.stem
            subprocess.run([PY, "-I", str(HERE / "evolve.py"), "master", str(stems), str(out / f"{name}.wav"),
                            "--light" if take["tier"] == "b-side" else "--spice"], check=True)
            files.append(f"{name}.wav")
        registry[take["id"]] = dict(id=take["id"], display_name=take["name"], station=take["station"], tier=take["tier"],
                                    parent=take["parent"], pick=take["pick"], bpm=take["bpm"], key=take["key"],
                                    takes=files, pick=None)
        print(take["id"], len(files), flush=True)
    order = [t["id"] for t in json.loads(CATALOGUE.read_text())["takes"]]
    REGISTRY.write_text(json.dumps([registry[i] for i in order if i in registry], indent=1) + "\n")


if __name__ == "__main__":
    main(sys.argv[1:])
