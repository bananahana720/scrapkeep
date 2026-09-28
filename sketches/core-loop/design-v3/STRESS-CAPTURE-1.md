# Stress capture 1 (2026-09-28)

This is a run of `tools/stress_capture.gd` at 1920x1080 on the RTX 4080 (Godot 4.7.2, X11), launched off-screen on workspace 10. The CPU was contended (load average about 8, with four lab writers running headless suites), so the frame times are a lead, not a qualification. The stills and `stress.json` are in `artifacts/local/stress-v3/`.

| Scene | Packs | Telegraphs | Threat screen cover | P1 edge contrast lost | Frame dt p50 / p99 | CPU p50 | GPU p99 | Draws p99 | HUD words |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| s1 | 1 | 0 | 0% | n/a | 3.5 / 27.9 ms | 51 ms* | 0.6 ms | 927 | 30 |
| s2 | 3 | 16 | 9.9% | 3.9% | 15.2 / 21.9 ms | 17.8 ms | 0.8 ms | 1221 | 36 |
| s3 | 6, plus the Warden | 32 | 20.5% | 2.9% | 26.1 / 53.6 ms | 26.5 ms | 1.5 ms | 1646 | 29 |

\* s1's CPU sample is a single constant value, so it's probably a sampling artifact.

## What it says

1. **Dense fights are CPU-bound, not GPU-bound.** The GPU never exceeds 1.6 ms; s3 spends about 26 ms per frame on the CPU at p50. Work should start with perf-lab on the CPU side: the script cost of enemies and telegraphs, draw submission (1,600 draws), and physics. Materials and shaders aren't the lever. Rerun on a quiet machine before trusting the absolute numbers.
2. **Threat readability holds.** P1 edges lose 3 to 4% contrast, far inside the 15% band, even at 20% threat cover.
3. **A full build turns the ball into a tangle.** With 33 parts granted, the accretion rings and pieces fill the hull silhouette and compete with the pilot and the threats. That's a feel and appearance problem for the density governor (F1) and the Codex track. Cap or merge the visual accretion at high part counts.
4. **The synergy toast is a word block.** "New synergy" cards persist beside play and push the HUD past the 25-word fight budget (29 to 36 words). F2 should turn the toast into a glyph plus the name only, with the text on hold or in the codex.
