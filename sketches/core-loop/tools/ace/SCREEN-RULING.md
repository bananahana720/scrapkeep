# Screen ruling, 2026-09-28

The coordinator's ruling on the AU-BED sweep (36 takes, committed at 047b5db):

- **The lock screen's bass-grid-deviation half is withdrawn.** It fails its positive control. The engine's own locked guide, run through the same Demucs path, reads 17.3 ms against a 12 ms bar; the clean synth bass reads 5.2 ms and random placement 21.8 ms. On separated stems it measures Demucs onset smearing, not lock. This is a validity correction proven by a control, not a relaxation to admit takes.
- **The bass-to-kick envelope-lag half stays** (within ±12 ms). It passes its control.
- **Takes that pass every remaining screen:** c-085-s7 (kick 3.63 ms, lag 9.43 ms), a-080-s1001 (4.35 ms, 2.18 ms; carries a faint vocal-like residue at -43 dB RMS) and c-090-s7 (5.8 ms, 10.88 ms). All three are finished and blind-packed with B in `/home/andrew/Projects/scrapkeep/artifacts/local/music-ab-2/`, as X1 to X4 in random order. The key is in `.key-do-not-peek`.
- **Still open:**
  - ACE-Step cover mode isn't reproducible run to run here (-8.6 dB relative RMS at a fixed seed). Until that's pinned down, keep the finished files, not the seeds.
  - A bass-onset lock measure that survives Demucs.
