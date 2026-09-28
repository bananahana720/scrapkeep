# Perf lab ledger: core-loop dense fight

This ledger is append-only. Entries follow the perf-lab format: goal, layer map, assumptions, then H and E entries.

## Goal (2026-09-28)

The metric is the main-thread frame time in the densest fight (scene s3) at 1920x1080, Godot 4.7.2 Forward+ Vulkan, on the dev box (Ryzen 9 5950X, RTX 4080). The target is CPU main thread p99 at or under 10 ms and GPU p99 at or under 7 ms. That leaves headroom for a 6-core Zen 2 or 3 CPU and an RTX 3060 to hold 60 FPS. The E0 value is native s3 frame p99 31.9 ms and p50 21.9 ms (median of 3 runs). The budget is steps 2 to 4 of perf-lab for this entry (benchmark, assumptions, baseline); hypotheses and experiments follow in later entries.

## Layer map

1. **Hardware.** Ryzen 9 5950X (16 cores, 32 threads, governor performance, 4.35 GHz average and 3.63 GHz minimum at snapshot, k10temp 81 C), RTX 4080 (16 GB, 2505 MHz, no throttle), 64 GB RAM with 11 GB of swap in use. Assumes the CPU is not thermally throttled during a run.
2. **OS and neighbours.** Omarchy (Arch, kernel 7.2.5), Hyprland, and Godot on X11 through XWayland, launched on workspace 10. Other agents shared the machine. Two Blender processes used about 2 cores each, and Godot labs and `sketch:smoke` suites ran from worktrees `core-loop-v3-f1a` and `core-loop-v3-m0`. Load average was 5.2 to 16.8 on 32 threads across the matrix (median 7.6). Assumes the neighbours leave the main-thread core and the GPU alone, and they did not always (see A6 and A9).
3. **Godot process.** 4.7.2.stable.official.ed1daf0bf, Forward+ Vulkan, MSAA 3D 2x, Jolt Physics at 90 ticks per second, vsync off and `max_fps` 0 in the bench. Headless runs use the dummy renderer and the dummy audio driver. The audio bank and band bake on the WorkerThreadPool and are ready about 8 s after launch. The render thread model is the project default, which puts draw submission on the main thread (`ASSERTED (unverified)`, not checked in this session).
4. **Script subsystems.** `game.gd` modules: world, combat (bolts and sticky charges in combat's `_physics_process`, one `_physics_process` per enemy node), build, boss, and presentation (`audio.gd` plus the GDScript synth `music_engine.gd`, `juice.gd`, `vfx.gd`, `hero_assets.gd`). Around them sit the HUD and UI CanvasLayers and each telegraph's `Painter`, which rebuilds its ArrayMesh on every `set_progress()`.
5. **Scene content.** Stage 1 as Rivet with 33 granted parts. s1, s2 and s3 put 1, 3 and 6 packs (4 enemies each) in front of the ball, with 0, 16 and 32 synthetic telegraphs recycled every frame. s3 adds the stage's Warden 16 m ahead with its pulse charge started. Node count is about 1,410, 1,570 and 1,820. Native s3 issues 653 draws at p50 and 1,611 at p99.

## Assumptions

| # | Assumption | How checked | Result |
| --- | --- | --- | --- |
| A1 | Headless frame time measures CPU cost | s1 baseline, same build, before and after zeroing `OS.low_processor_usage_mode_sleep_usec` | **Broken.** Headless sleeps 6.9 ms per frame by default. Frame p50 went from 6.71 ms (mean 6.995) to 0.74 ms. The bench now zeroes it. |
| A2 | The audio runs during the measured window | Debug print of `audio.sound_ready` at window start and end, s1 | **Broken.** The bake finished after the window in s1, so audio was absent from some runs. The bench now waits for `sound_ready`, recorded as `sound_ready_at_s` (7.7 to 9.3 s across all 81 E0 runs). The same race can affect `stress_capture.gd`, which samples about 7.5 s after launch. |
| A3 | Performance `TIME_PROCESS` and `TIME_PHYSICS_PROCESS` are per-frame values | Count of value changes in the window against the window's wall time | **Broken.** They change about once per second: 9 to 15 changes in s3 windows of 8.6 to 14.1 s, and 1 or 2 in s1 windows of 0.3 to 0.9 s. Their s3 median of 36.6 ms sits above the frame p50 of 17.1 ms, so they read as a per-second maximum of a wider span (`ASSERTED (unverified)` beyond the update rate). The bench records them but reports per-frame probe timings instead. This likely explains STRESS-CAPTURE-1's constant 51 ms s1 CPU sample. |
| A4 | The stress harness's own per-frame work is negligible | `harness_ms`, the bench's SceneTree `_process` step | **Broken.** Recycling the synthetic telegraphs costs 11.2 ms p50 in s3 and 5.8 ms in s2, because each `set_progress()` rebuilds the telegraph's meshes. This is the telegraph draw cost itself. In play it is driven by enemy attacks rather than the harness, so it is counted in the frame and ablated by `--no-telegraph-draw`. |
| A5 | An uncapped frame is comparable to a 60 FPS frame | `ticks` per frame | **Broken.** With 90 Hz physics, a slow uncapped frame carries 1.6 (headless s3) to 2.0 (native s3) ticks, and a fast one carries about 0.1. The ledger adds `est60`, frame p50 at 0 ticks plus 1.5 times the per-tick cost (from the 1-tick and 0-tick p50s), as the 60 FPS equivalent. It is derived, not measured. |
| A6 | The machine is quiet enough for p99 | Load before each run, spread across 3 repeats | **Partly held.** No run hit the load-20 gate, so no result is marked noisy. Repeat 3 of headless s3 ran at load 10.8 to 16.8 and its p99s rose (baseline p99 29.1, 43.5 and 66.7 ms). Frame p99 is noise-dominated. Use the median and read the spread. |
| A7 | The GPU is not the binding constraint | Native `gpu_ms` | **Held.** In the clean repeat 3, s3 GPU p99 was 0.85 ms (baseline), 0.81 ms (no-music) and 0.75 ms (no-vfx). Repeats 1 and 2 read 6.0 to 11.3 ms, most likely from GPU neighbours. |
| A8 | Each ablation really stops its subsystem | The bench's `checks` block, which compares readings at window start and end | **Held**, per switch. See the evidence under E0. |
| A9 | Runs are deterministic | Fixed seed 1, fixed scene layout | **Partly held.** The layout, granted parts and telegraph set are fixed. The simulation steps with real frame time, so kills, respawns and cue counts differ between runs. |

## E0 2026-09-28 07:56 to 08:19  baseline and single-subsystem ablations

Tool: `tools/perf_bench.gd` at commit 0cd689c (sha256 4172d253... for the bench, 88e5550c... for `vfx.gd`). Every result JSON carries both hashes.

Method: one scene per Godot process. The bench waits for the audio bake, builds the scene, warms 120 frames and records 600. Each configuration ran 3 times, one run at a time and repeat-major (every configuration once, then again), so drift lands on all of them. Load was recorded before each run with a load-20 gate (wait 60 s, up to 5 tries). The gate never fired. The raw JSON, logs, `summary.tsv`, `aggregate.json`, the runner and the aggregator are in `artifacts/local/perf-bench-e0/` (git-ignored).

Commands:

- Headless: `Godot_v4.7.2-stable_linux.x86_64 --headless --path sketches/core-loop --script res://tools/perf_bench.gd -- --scene=<s> --out=<json> [switch]`
- Native: `claude-open bash -c 'echo $$ > <pidfile>; exec "$@"' <pidfile> Godot... --path sketches/core-loop --resolution 1920x1080 --script res://tools/perf_bench.gd -- --scene=s3 --out=<json> [switch]`. The runner waits on that PID with `tail --pid`.

Columns: frame is wall time between frames. Proc is every node's `_process`. Phys is node `_physics_process` summed over the frame's ticks, excluding the Jolt step. Harness is the bench's own step, mostly telegraph repaint. Every value is the median over 3 runs of that run's p50 or p99, in ms. Delta is the change in frame p50 against the scene's baseline.

### Headless s1 (1 pack, 0 telegraphs)

| Config | Frame p50 | Frame p99 | Proc p50 | Proc p99 | Phys p50 | Phys p99 | Harness p50 | Ticks/frame | est60 | Delta frame p50 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | 0.87 | 3.96 | 0.63 | 1.15 | 0.00 | 1.44 | 0.01 | 0.10 | 3.42 | 0 |
| no-music | 0.79 | 3.51 | 0.56 | 0.92 | 0.00 | 1.45 | 0.01 | 0.09 | 3.21 | -0.08 |
| no-audio | 0.78 | 3.70 | 0.55 | 0.84 | 0.00 | 1.32 | 0.01 | 0.09 | 3.06 | -0.09 |
| no-vfx | 0.58 | 2.26 | 0.36 | 0.62 | 0.00 | 0.99 | 0.01 | 0.06 | 2.62 | -0.29 |
| no-telegraph-draw | 0.87 | 4.22 | 0.63 | 1.01 | 0.00 | 1.45 | 0.01 | 0.10 | 3.19 | 0.00 |
| no-hud | 0.49 | 2.77 | 0.46 | 0.79 | 0.00 | 1.23 | 0.01 | 0.05 | 2.79 | -0.38 |
| no-enemy-ai | 0.82 | 4.01 | 0.59 | 1.03 | 0.00 | 1.30 | 0.01 | 0.09 | 3.19 | -0.05 |
| no-trails | 0.87 | 4.96 | 0.63 | 1.09 | 0.00 | 1.59 | 0.01 | 0.10 | 3.53 | 0.00 |

### Headless s2 (3 packs, 16 telegraphs)

| Config | Frame p50 | Frame p99 | Proc p50 | Proc p99 | Phys p50 | Phys p99 | Harness p50 | Ticks/frame | est60 | Delta frame p50 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | 8.96 | 32.55 | 1.11 | 24.81 | 1.33 | 4.25 | 5.84 | 0.85 | 10.47 | 0 |
| no-music | 8.12 | 27.50 | 0.56 | 19.47 | 1.18 | 3.73 | 5.72 | 0.76 | 9.26 | -0.84 |
| no-audio | 8.41 | 13.31 | 0.66 | 1.21 | 1.28 | 2.49 | 5.73 | 0.75 | 9.94 | -0.55 |
| no-vfx | 9.05 | 34.46 | 0.95 | 25.44 | 1.38 | 5.83 | 5.95 | 0.90 | 10.51 | +0.09 |
| no-telegraph-draw | 0.90 | 5.28 | 0.65 | 1.18 | 0.00 | 2.03 | 0.03 | 0.11 | 4.09 | -8.06 |
| no-hud | 8.56 | 29.94 | 0.94 | 21.04 | 1.30 | 4.31 | 5.81 | 0.83 | 9.95 | -0.40 |
| no-enemy-ai | 7.93 | 29.64 | 0.92 | 22.21 | 0.57 | 2.57 | 5.78 | 0.77 | 8.96 | -1.03 |
| no-trails | 8.86 | 29.22 | 1.05 | 20.83 | 1.25 | 4.28 | 5.80 | 0.84 | 10.12 | -0.10 |

### Headless s3 (6 packs, 32 telegraphs, the Warden)

| Config | Frame p50 | Frame p99 | Proc p50 | Proc p99 | Phys p50 | Phys p99 | Harness p50 | Ticks/frame | est60 | Delta frame p50 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | 17.08 | 43.51 | 1.44 | 9.66 | 3.37 | 9.80 | 11.15 | 1.60 | 16.62 | 0 |
| no-music | 16.02 | 38.88 | 0.72 | 24.45 | 2.69 | 8.39 | 11.22 | 1.51 | 16.23 | -1.06 |
| no-audio | 16.63 | 24.75 | 0.69 | 1.44 | 3.21 | 8.03 | 11.61 | 1.52 | 16.54 | -0.45 |
| no-vfx | 17.19 | 35.48 | 1.09 | 9.28 | 3.42 | 8.38 | 11.54 | 1.61 | 16.85 | +0.11 |
| no-telegraph-draw | 0.96 | 5.72 | 0.68 | 1.36 | 0.00 | 3.02 | 0.05 | 0.12 | 5.47 | -16.13 |
| no-hud | 16.11 | 52.28 | 0.90 | 11.03 | 3.03 | 14.13 | 11.32 | 1.59 | 16.29 | -0.97 |
| no-enemy-ai | 14.67 | 37.57 | 0.92 | 24.75 | 1.10 | 3.85 | 11.54 | 1.38 | 15.01 | -2.41 |
| no-trails | 17.42 | 40.33 | 1.23 | 10.24 | 3.47 | 8.36 | 11.33 | 1.60 | 16.75 | +0.34 |

### Native s3, 1920x1080, RTX 4080

| Config | Frame p50 | Frame p99 | Proc p50 | Proc p99 | Phys p50 | Phys p99 | Harness p50 | Ticks/frame | est60 | Draws p50 / p99 | GPU p99 (median; clean repeat 3) | Delta frame p50 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | 21.90 | 31.91 | 1.53 | 3.24 | 4.27 | 9.28 | 12.15 | 1.99 | 19.72 | 653 / 1611 | 8.94; 0.85 | 0 |
| no-music | 21.52 | 31.77 | 0.88 | 1.52 | 4.42 | 11.98 | 12.02 | 1.97 | 19.34 | 673 / 1622 | 6.01; 0.81 | -0.38 |
| no-vfx | 20.39 | 28.37 | 1.30 | 2.56 | 4.14 | 7.51 | 11.82 | 1.85 | 18.81 | 700 / 1549 | 0.95; 0.75 | -1.51 |

Native render CPU p99 was 1.4 to 2.3 ms across runs. Native s3 node count was 1,808 to 1,822 (median p50 per configuration).

### Performance monitors (median over 3 runs, ms; per-second values, see A3)

| Scene / config | TIME_PROCESS p50 / p99 | TIME_PHYSICS_PROCESS p50 / p99 |
| --- | --- | --- |
| headless s1 baseline | 1.42 / 8.06 | 2.71 / 2.71 |
| headless s2 baseline | 38.71 / 49.77 | 3.59 / 8.88 |
| headless s2 no-telegraph-draw | 2.50 / 27.32 | 2.73 / 3.89 |
| headless s3 baseline | 36.63 / 82.27 | 5.18 / 11.52 |
| headless s3 no-audio | 16.37 / 22.11 | 4.52 / 10.07 |
| headless s3 no-telegraph-draw | 1.65 / 48.70 | 1.95 / 5.53 |
| native s3 baseline | 21.66 / 48.87 | 5.27 / 11.36 |
| native s3 no-music | 20.14 / 47.50 | 5.84 / 10.03 |
| native s3 no-vfx | 19.41 / 47.38 | 4.95 / 9.66 |

Every other row is in `artifacts/local/perf-bench-e0/e0/aggregate.json`.

### Noise (spread across the 3 repeats)

- Headless s3 baseline: frame p50 15.96, 17.08 and 19.61 (spread 3.66 ms, 21% of the median). Frame p99 29.1, 43.5 and 66.7. Proc p50 1.11, 1.44 and 1.54. The third repeat ran at load 13.3.
- Headless s3 no-telegraph-draw: frame p50 0.99, 0.96 and 0.94 (spread 0.05). Frame p99 6.0, 5.7 and 5.3.
- Headless s3 no-enemy-ai: frame p50 14.67, 13.63 and 14.69. Phys p50 1.11, 0.88 and 1.10 against a baseline of 2.43, 3.37 and 4.51.
- Headless s1 baseline: frame p50 0.89, 0.86 and 0.87 (spread 0.03). Frame p99 13.6, 3.5 and 4.0.
- Native s3 baseline: frame p50 21.90, 21.16 and 22.07 (spread 0.91). Frame p99 32.7, 30.6 and 31.9 (spread 2.1). est60 19.72, 19.23 and 19.73.
- Native s3 no-music: proc p50 0.88, 0.89 and 0.73 against a baseline of 1.79, 1.53 and 1.52.
- Native GPU p99 in the baseline was 8.94, 10.41 and 0.85. Repeats 1 and 2 are contaminated.

Only the telegraph-draw ablation clears the s3 frame p50 noise band by a wide margin. The enemy-AI result clears it on physics time, with no overlap across repeats. The music and audio effects are visible in proc p50, which is stable across repeats, but not in frame p50.

### Ablation evidence (from each run's `checks` block)

Ranges are over every E0 run of the configuration.

- `--no-music`: the engine is SilentBand. The band clock still advanced (sequencer running) while 606 to 762 mixes (headless) and 685 to 732 mixes (native) were skipped in the window, and the output peak was 0.0 in every run. The baseline output peak was 0.057 to 0.188 headless and 0.113 to 0.243 native.
- `--no-audio`: the band clock advanced by 0 samples in every run, the audio node reports `can_process` false, and 91 GameEvents listeners were cut, leaving 0. The baseline advanced 27,277 to 596,326 samples headless and 567,296 to 598,528 native.
- `--no-vfx`: the vfx clock advanced 0.0, 0 glyphs were spawned in the window, 0 particles were emitting headless (1 frozen emitter native), 32 listeners were cut, `juice.vfx` was null, and CombatEffects was not processing. The trail and speed-line arrays stayed frozen at their pre-ablation contents (234 to 280 points headless) and were hidden. The baseline spawned 333 to 2,224 glyphs headless and 1,798 to 1,942 native.
- `--no-telegraph-draw`: 224 to 238 painters were detached in s2 and s3, 0 of them were repainted across the window, and 0 were visible.
- `--no-hud`: `can_process` false, hidden, and 23 listeners cut, leaving 0.
- `--no-enemy-ai`: 0 enemies were processing in every run (the baseline had 7, 15 to 16, and 26 to 27). Enemy movement is not evidence here. Idle enemies still moved up to 972 m, because the bench re-places any enemy more than 35 m from the ball and respawns kills, and strikes knock bodies back.
- `--no-trails`: 0 trail points and 0 speed lines at the window's end in all 9 runs. The baseline had 2 to 75 trail points and 0 to 10 speed lines. Headless trail length grows with frame rate, because the trail keeps a fixed number of seconds of points, so fast headless frames carry hundreds of points where a 60 FPS frame carries about 20.

### Result

Native s3 runs at 21.9 ms frame p50, 31.9 ms p99 and about 19.7 ms per 60 FPS equivalent, against the 10 ms p99 target. The GPU is not the limit (0.85 ms p99 when uncontended).

Telegraph drawing removes the most time. `--no-telegraph-draw` takes headless s3 from 17.08 to 0.96 ms p50 (94% of the frame) and from 43.5 to 5.7 ms p99. It takes s2 from 8.96 to 0.90 ms. The harness step, which repaints only the 32 synthetic telegraphs, costs 11.2 ms, about 0.35 ms per telegraph per frame. Enemy-owned telegraphs (5 to 9 more in s3) repaint inside process and physics. The time is spent in `Telegraph.set_progress()`, then `_repaint()`, `Threat.marks()` and `Painter.paint()`. That path rebuilds an ArrayMesh with a terrain height lookup per vertex every frame. Fewer frames per second also means more physics ticks per frame, so removing it also takes the physics column to 0 at p50.

Enemy AI is second, at -2.4 ms p50 in s3 (physics p50 3.37 to 1.10 ms). The music engine is third, at about 0.7 ms of process time per frame in s3, headless and native alike. That confirms it as a real but small cost (about 7% of the 10 ms budget) that pre-rendered music removes. VFX, HUD and trails are each under about 1 ms in s3 and inside the noise.

Headless has a spike source that native does not. Headless proc p99 is 20 to 25 ms whenever audio is on (s2 baseline 24.8, s3 no-music 24.5) and 1.2 to 1.4 ms with `--no-audio`. Native proc p99 is 3.2 ms. The spikes survive `--no-music`, so they come from the audio director or the SFX side, not the band's mixing. `audio.gd` renders the other themes on demand in headless instead of on a worker, which is a likely source (`ASSERTED (unverified)`).

Learned: the CPU bound is almost entirely per-frame telegraph mesh rebuilding. Without it, s3 is 0.96 ms p50, 5.7 ms p99 and 5.5 ms est60 headless, inside the budget before render submission. Five of the nine assumptions were broken by the measurement setup itself (A1 to A5), and STRESS-CAPTURE-1's numbers carry A2, A3 and A4.

## H1  telegraph repaint is the binding CPU cost

If rebuilding each telegraph's ArrayMesh every frame (with a terrain height lookup per vertex) is binding, then drawing the static geometry once and driving progress through a material parameter or a scaled child cuts native s3 frame p50 by at least 8 ms with identical committed geometry and `contains()` results. Wrong if the cut is under 3 ms. Next experiment: E1, against this E0.
