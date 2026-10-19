"""Remake radio takes from a written brief: render candidates, split, master, measure.

    python radio_remake.py render <work> <remake.json> [--gpu 1]
    python radio_remake.py split <work> [take id ...] [--gpu 1]
    python radio_remake.py master <work> <master python> [take id ...]
    python radio_remake.py measure <work> [take id ...]
    python radio_remake.py pack <work> <take id>:<seed> [...]   (writes assets/music_ace/take_<id>/ and registers the remake)

remake.json is a list of rows {id, caption, strength, seeds, [src, bpm, key, seconds, note]}; the catalogue row
supplies whatever a row leaves out. Each row is an ACE-Step cover of the take's stretched parent pick
(radio_takes.py's source file), rendered once per seed on the chosen GPU, so a pick can always be
reproduced from the row, its seed and the model recorded in <work>/cands/<id>/s<seed>/meta.json.

Candidates land in <work>/cands/<id>/s<seed>/: raw.wav, stems/ (htdemucs drums, bass, other, vocals),
master.wav and mastered/ (tools/ace/radio_master.py: the stems EQ'd, compressed and levelled to -16 LUFS),
share.json (the drum stem's share of the loudness; percussion serves the song).

The render step leaves the 4080 alone: --gpu 1 (the RTX 3060) is the default, and the nvidia-smi shim
ace.py's VRAM check needs lives in <work>/shim.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
CATALOGUE = HERE.parent.parent / "assets" / "radio" / "catalogue.json"
SOUND_BIBLE = Path.home() / "Music" / "Scrapkeep-sound-direction" / "sound-bible-2026-10-16"
ACE = Path.home() / ".claude" / "skills" / "song-composer" / "scripts" / "ace.py"
DEMUCS = Path.home() / ".local" / "share" / "demucs-venv" / "bin" / "demucs"
MASTER = HERE.parent.parent / "tools" / "ace" / "radio_master.py"
MODEL = "ACE-Step 1.5 xl-turbo, cover, final mode"


def option(argv, name, default=None):
    return argv[argv.index(name) + 1] if name in argv else default


def gpu_env(work, gpu):
    shim = work / "shim"
    shim.mkdir(parents=True, exist_ok=True)
    (shim / "nvidia-smi").write_text(f'#!/bin/sh\nexec /usr/bin/nvidia-smi -i {gpu} "$@"\n')
    (shim / "nvidia-smi").chmod(0o755)
    env = dict(os.environ)
    env.update(PATH=f"{shim}:{env['PATH']}", CUDA_DEVICE_ORDER="PCI_BUS_ID", CUDA_VISIBLE_DEVICES=str(gpu), ACE_NO_WORKER="1")
    return env


def catalogue():
    return {t["id"]: t for t in json.loads(CATALOGUE.read_text())["takes"]}


def render(work, rows, gpu):
    import soundfile as sf
    cat = catalogue()
    base = json.loads((SOUND_BIBLE / "ace.json").read_text())
    base["experiments"] = {}
    variants, seeds = [], set()
    for row in rows:
        t = cat[row["id"]]
        if len(row["caption"]) > 512:
            raise SystemExit(f"{row['id']}: caption is {len(row['caption'])} characters; ACE-Step reads at most 512")
        bpm = row.get("bpm", t["bpm"])
        src = Path(row["src"]) if row.get("src") else SOUND_BIBLE / "radio" / "src" / f"{t['id']}-{t['bpm']}.wav"
        if not src.exists():
            raise SystemExit(f"{src}: the stretched parent is missing; run radio_takes.py's source step")
        variants.append(dict(name=t["id"], task_type="cover", src_audio=str(src), audio_cover_strength=row.get("strength", t["strength"]),
                             bpm=bpm, keyscale=row.get("key", t["key"]), duration=row.get("seconds", t["seconds"]), thinking=False,
                             lyrics="[Instrumental]", caption=row["caption"]))
        seeds.update(int(s) for s in row["seeds"])
    round_name = "remake"
    base["experiments"][round_name] = {"hypothesis": "Radio remake from written briefs.", "variants": variants}
    work.mkdir(parents=True, exist_ok=True)
    (work / "ace.json").write_text(json.dumps(base, indent=1))
    before = set((work / "renders").glob(f"lab-{round_name}-*"))
    subprocess.run([sys.executable, str(ACE), "lab", str(work), round_name, "--seeds", *map(str, sorted(seeds)), "--mode", "final"],
                   check=True, env=gpu_env(work, gpu))
    run = sorted(set((work / "renders").glob(f"lab-{round_name}-*")) - before)[-1]
    by_id = {r["id"]: r for r in rows}
    for job in json.loads((run / "manifest.json").read_text()):
        row = by_id.get(job["name"])
        if row is None or not job.get("success"):
            continue
        for audio in job["audios"]:
            if int(audio["seed"]) not in {int(s) for s in row["seeds"]}:
                continue
            out = work / "cands" / job["name"] / f"s{audio['seed']}"
            out.mkdir(parents=True, exist_ok=True)
            x, sr = sf.read(audio["path"])
            sf.write(out / "raw.wav", x, sr)
            (out / "meta.json").write_text(json.dumps(dict(
                id=job["name"], seed=int(audio["seed"]), model=MODEL, caption=row["caption"], strength=row.get("strength", cat[job["name"]]["strength"]),
                bpm=row.get("bpm", cat[job["name"]]["bpm"]), key=row.get("key", cat[job["name"]]["key"]), note=row.get("note", ""),
                source=str(run / "manifest.json")), indent=1))
            print("rendered", job["name"], audio["seed"], flush=True)


def candidates(work, ids):
    for take in sorted((work / "cands").glob("take-*")):
        if ids and take.name not in ids:
            continue
        for cand in sorted(take.glob("s*")):
            yield cand


def split(work, ids, gpu):
    env = dict(os.environ, CUDA_DEVICE_ORDER="PCI_BUS_ID", CUDA_VISIBLE_DEVICES=str(gpu))
    for cand in candidates(work, ids):
        if (cand / "stems" / "drums.wav").exists():
            continue
        tmp = cand / "demucs"
        subprocess.run(["nice", "-n", "10", str(DEMUCS), "-n", "htdemucs", "-d", "cuda", "-o", str(tmp), str(cand / "raw.wav")],
                       check=True, capture_output=True, env=env)
        (cand / "stems").mkdir(exist_ok=True)
        for f in (tmp / "htdemucs" / "raw").glob("*.wav"):
            f.rename(cand / "stems" / f.name)
        print("split", cand, flush=True)


def master(work, python, ids):
    import soundfile as sf
    for cand in candidates(work, ids):
        if (cand / "master.wav").exists():
            continue
        stems = cand / "stems"
        other, sr = sf.read(stems / "other.wav")
        vocals, _ = sf.read(stems / "vocals.wav")
        n = min(len(other), len(vocals))
        sf.write(cand / "other_voc.wav", other[:n] + vocals[:n], sr)
        meta = json.loads((cand / "meta.json").read_text())
        trim = [] if not meta.get("drum_db") else ["--drum-db", str(meta["drum_db"])]
        subprocess.run(["nice", "-n", "10", python, str(MASTER), str(stems / "drums.wav"), str(stems / "bass.wav"), str(cand / "other_voc.wav"),
                        str(cand / "master.wav"), "--stems-dir", str(cand / "mastered"), *trim], check=True, capture_output=True)
        print("mastered", cand, flush=True)


def measure(work, ids):
    import numpy as np
    import soundfile as sf
    for cand in candidates(work, ids):
        d = cand / "mastered"
        if not (d / "drums.wav").exists():
            continue
        st = {}
        for s in ("drums", "bass", "other"):
            x, sr = sf.read(d / f"{s}.wav", always_2d=True)
            st[s] = x.mean(axis=1)
        n = min(len(v) for v in st.values())
        k = n // sr
        e = {s: (v[:k * sr].reshape(k, sr) ** 2).mean(axis=1) + 1e-12 for s, v in st.items()}
        tot = sum(e.values())
        share = e["drums"] / tot
        live = tot > 1e-6
        (cand / "share.json").write_text(json.dumps(dict(
            median_share=float(np.median(share[live])), dom_frac=float((share[live] > 0.5).mean()),
            median_db=float(np.median(10 * np.log10(e["drums"] / (e["bass"] + e["other"]))[live])), seconds=int(k))))
        print("measured", cand, flush=True)


def pack(work, picks):
    """Pack the chosen candidates as whole-song packs: their mastered stems go where package_phase_tracks.py expects htdemucs stems."""
    import numpy as np
    import soundfile as sf
    cat = catalogue()
    registry_path = HERE / "radio_renders.json"
    registry = json.loads(registry_path.read_text())
    report = {}
    for spec in picks:
        tid, seed = spec.split(":")
        cand = work / "cands" / tid / f"s{seed}"
        meta = json.loads((cand / "meta.json").read_text())
        theme = tid.replace("-", "_")
        stem_dir = work / "pack" / "stems" / "htdemucs" / theme
        stem_dir.mkdir(parents=True, exist_ok=True)
        for s in ("drums", "bass", "other"):
            (stem_dir / f"{s}.wav").write_bytes((cand / "mastered" / f"{s}.wav").read_bytes())
        x, sr = sf.read(cand / "mastered" / "drums.wav", always_2d=True)
        sf.write(stem_dir / "vocals.wav", np.zeros_like(x), sr, subtype="PCM_24")
        t = cat[tid]
        report[tid] = dict(stretch="remade", source=str(cand / "master.wav"), bpm_target=meta["bpm"], bpm_before=meta["bpm"], bpm_after=meta["bpm"],
                           key=t["key"].split()[0], key_offset=0)
        for row in registry:
            if row["id"] == tid:
                row["remade"] = dict(seed=int(seed), model=meta["model"], caption=meta["caption"], strength=meta["strength"], note=meta.get("note", ""))
    (work / "pack").mkdir(exist_ok=True)
    (work / "pack" / "stretch.json").write_text(json.dumps(report, indent=1))
    subprocess.run([sys.executable, str(HERE.parent.parent / "tools" / "ace" / "package_phase_tracks.py"), "pack", str(work / "pack"), "--whole", "--ceiling", "-2.2"], check=True)
    registry_path.write_text(json.dumps(registry, indent=1) + "\n")


def main(argv):
    cmd, work = argv[0], Path(argv[1])
    gpu = option(argv, "--gpu", "1")
    ids = {a for a in argv[2:] if a.startswith("take-")}
    if cmd == "render":
        render(work, json.loads(Path(argv[2]).read_text()), gpu)
    elif cmd == "split":
        split(work, ids, gpu)
    elif cmd == "master":
        master(work, argv[2], ids)
    elif cmd == "measure":
        measure(work, ids)
    elif cmd == "pack":
        pack(work, [a for a in argv[2:] if ":" in a])
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
