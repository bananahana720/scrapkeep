"""Wave 19, unit 19 (PR #497): Score the six Brindle p2 and p3 cover takes: tempo, parent match to the p1 pick (s4202), the same
against a negative control (another family's pick), loudness, true peak, drum share, longest quiet."""
import json, sys
from pathlib import Path
import numpy as np, soundfile as sf
S = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(S))
import measure_variants as mv, cut_loops
sys.path.insert(0, str(S.parents[1] / "tools/ace")); from cut_stingers import lufs as _lufs, true_peak_db
R = Path("/home/andrew/Music/Scrapkeep-sound-direction/sound-bible-2026-10-16/gapfill")
parent = mv.chroma(mv.mono(R / "anthem-brindle-s4202.wav")[0])
control = mv.chroma(mv.mono(R / "anthem-waking-s4202.wav")[0])
rows = []
for ph, bpm in (("p2", 150), ("p3", 160)):
    for s in range(4401, 4407):
        name = f"anthem-brindle-{ph}-s{s}"
        x, full, sr = mv.mono(R / f"{name}.wav")
        c = mv.chroma(x)
        flux, rate = cut_loops.onset_envelope(full, sr)
        tempo = cut_loops.tempo(flux, rate, bpm * 0.85, bpm * 1.15)
        st, ssr = sf.read(R / f"{name}.wav")
        m = st.mean(axis=1) if st.ndim > 1 else st; lufs = float(_lufs(m))
        tp = float(true_peak_db(m))
        stems = R / "stems/htdemucs_6s" / f"{name}-raw"
        e = {k: float(np.mean(sf.read(stems / f"{k}.wav")[0] ** 2)) for k in ("drums", "bass", "other", "guitar", "piano", "vocals") if (stems / f"{k}.wav").exists()}
        rows.append(dict(take=name, bpm=bpm, tempo=round(float(tempo), 1), parent=round(mv.match(c, parent), 3),
                         control=round(mv.match(c, control), 3), lufs=round(lufs, 1), peak_db=round(tp, 2),
                         drum_share=round(e.get("drums", 0) / max(sum(e.values()), 1e-12), 2),
                         quiet=round(float(cut_loops.longest_quiet(full, sr)), 1)))
for r in rows:
    print(json.dumps(r))
Path(__file__).with_name("brindle-phase-covers-w19.json").write_text(json.dumps(rows, indent=1))
