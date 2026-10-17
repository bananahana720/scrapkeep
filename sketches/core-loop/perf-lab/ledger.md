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

## Synthesis 2026-09-28, after E0 and five subsystem reads

### 1. Binding constraint

Telegraph mesh repaint. `--no-telegraph-draw` takes headless s3 from 17.08 to 0.96 ms p50 and 43.5 to 5.7 ms p99. The harness column, 32 synthetic telegraphs all repainting, is 11.15 ms headless and 12.15 ms native: 0.35 ms per telegraph per frame. Every `set_progress()` runs `_repaint()` then `Threat.marks()` then `Painter.paint()`, which rebuilds one ArrayMesh per motion layer with a terrain lookup per vertex (`src/combat/telegraph.gd:187`, `:246-250`; `src/combat/threat_grammar.gd:682-722`).

The combat and threats readers both named this path, but their 0.5 to 4 ms estimates were 3 to 10 times low because they assumed 6 to 15 telegraphs warn at once. The bench drives all 32 (`tools/perf_bench.gd:372`), so E0 is the ceiling; in play the count is however many enemies are in WARN. The audio reader's "low single-digit ms" for music measured 0.7 ms proc p50. The UI reader's WordBudget confound is real for `stress_capture.gd:495` but `perf_bench.gd` never calls it, so it retires STRESS-CAPTURE-1 rather than correcting E0. The world_physics reader's negative result holds: enemy AI (-2.4 ms, phys 3.37 to 1.10) is the only other per-tick scaler. Where readers and E0 disagree, E0 wins: the telegraph ablation clears the 3.66 ms noise band four times over, and every reader number is code-shape inference.

### 2. Physics floor (inference anchored on E0)

Native est60 minus harness is 7.6 ms with today's code; headless s3 without repaint is 5.47 est60 and 5.7 p99 with everything else on. A sensible floor: 27 enemy ticks at 20 us times 1.5 ticks (0.8 ms), Jolt step (0.6), 32 progress uniforms (0.2), 64 bolt raycasts (0.5), HUD and VFX (0.8), submission of about 650 draws (1.5 to 2), engine (0.5): about 5 ms p50 and 7 to 8 ms p99 native. Prize: about 14 ms p50, about 23 ms p99.

### 3. Hypotheses (native s3, ranked by gain over cost plus blast radius)

- **H1 telegraph repaint.** Paint the footprint once; drive INSTANT and LANE fill through a shader uniform (inner radius or half-width, `threat_grammar.gd:203-212`); rebuild WAVE marks only when the front moves a quantum. Cuts about 10 ms p50, 15 ms p99; wrong if under 3. Look holds only if the shader draws the same inner-radius ramp; stills decide. Not moot.
- **H2 enemy group scans.** One valid-checked enemy snapshot per tick in `combat.gd` (11 `get_nodes_in_group("enemy")` calls, `:497` to `:1525`) shared with bolts, near_miss, swarm_remnant, winch_drone and `world.gd:428`. Cuts 0.8 to 1.5 ms p50 (ceiling 2.3); wrong if under 0.4. Gameplay unchanged.
- **H3 music engine on the main thread.** 0.7 ms proc p50 plus the 20 to 25 ms headless proc p99 spike. **Moot**: ACE removes it. No experiment; re-baseline after the pivot.
- **H4 HUD shaping every frame** (`hud.gd:494-504`, gauge and objective `extent()`, unconditional `queue_redraw()` in ability_bar, key_glyphs, edge_markers). Value-changed gating cuts 0.3 to 0.6 ms (ceiling 1.0); wrong if under 0.2. Look unchanged.
- **H5 draw count.** About 230 painter mesh instances (6 per telegraph) and 1,611 draws at p99; merge static layers after H1. Cuts 0.5 to 1 ms render CPU; wrong if under 0.3.
- **H6 repaint throttle to 20 Hz.** Fallback if H1 slips: about 8 ms, but the fill edge steps 5% per update. **Changes the look**; forbidden unless a side-by-side holds.
- **H7 SFX `play()` filter allocation** (`audio.gd:391-402`). No-audio against no-music differs by 0.6 ms headless p50, inside noise. Parked until H1 and H2 land. Not moot.
- VFX and trails: inside noise, no hypothesis.

### 4. Experiment order

1. E1, H1: `src/combat/threat_grammar.gd` (Painter, `_instant`, `_lane`, `_wave`) and `src/combat/telegraph.gd` (`_repaint`, `set_progress`). Guardrails: `contains()` tests, `npm run sketch:smoke`, stills at progress 0.25, 0.5 and 0.95 per shape, bench s2 and s3 headless plus native s3, 3 repeats each.
2. E2, H2: `src/combat/combat.gd`, `bolts.gd`, `near_miss.gd`, `swarm_remnant.gd`, `winch_drone.gd`, `src/world/world.gd`.
3. E3, H4: `src/ui/hud.gd`, `gauge.gd`, `objective_view.gd`, `ability_bar.gd`, `key_glyphs.gd`, `edge_markers.gd`.
4. E4, H5, only if E1 leaves draws p99 above about 1,000.
5. Re-run the baseline once ACE music lands.

### 5. Reachability

Reachable at p50, marginal at p99. After H1, H2 and H4, native est60 is about 6 ms p50 (19.7 minus 12, 1 and 0.5) and p99 about 9 to 12 ms, left in physics ticks (2 to 3), render submission (about 2), draw spikes and machine noise (E0 ran at load 5 to 17). The deciding measurement is native s3 p99 on a quiet box after E1. A 6-core Zen 2 at roughly 0.7 times this single-thread speed lands near 9 to 13 ms, so the 10 ms dev-box p99 is the right gate.

## E1 2026-09-28 13:00 to 13:08  H1 static telegraphs, GPU fill union, kill-pop gate

Tool: `tools/perf_bench.gd` unchanged (sha256 4172d253...). Candidate: branch proto/core-loop-v3-e1 at 6fac7e7. Baseline (E0′): the same bench on 164a102, which is b980ff5 plus the bench and docs only, extracted with `git archive` into `artifacts/local/e1/tree-base/`. Each baseline run was followed by its candidate run, repeat-major, so both saw the same load. Other agents ran headless tests and `sketch:smoke` in sibling worktrees throughout, at load 3.6 to 4.7 (headless) and 4.7 to 8.5 (native) on 32 threads. Native runs waited while any GPU process held more than 3 GB (none did), held `/tmp/scrapkeep-gpu.lock`, and launched through `claude-open` on workspace 10. The raw JSON, logs, `summary.tsv` and `aggregate.json` are in `artifacts/local/e1/bench/m1` (headless) and `bench/n1` (native), git-ignored.

Values are medians over 3 runs of each run's p50 or p99, in ms.

| Scene | Tree | Frame p50 | Frame p99 | Proc p50 | Proc p99 | Harness p50 | Draws p50 / p99 | GPU p99 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| headless s2 | E0′ | 8.71 | 38.41 | 1.09 | 30.99 | 5.68 | | |
| headless s2 | E1 | 1.15 | 4.45 | 0.68 | 1.12 | 0.15 | | |
| headless s3 | E0′ | 16.23 | 44.10 | 1.58 | 30.51 | 11.02 | | |
| headless s3 | E1 | 1.31 | 6.87 | 0.72 | 1.52 | 0.28 | | |
| headless s3 `--no-telegraph-draw` (1 run) | E0′ | 1.08 | 5.91 | 0.71 | 1.21 | 0.05 | | |
| headless s3 `--no-telegraph-draw` (1 run) | E1 | 1.10 | 5.85 | 0.73 | 1.40 | 0.05 | | |
| native s3 | E0′ | 22.14 | 32.49 | 1.58 | 3.21 | 12.29 | 657 / 1639 | 0.80 |
| native s3 | E1 | 4.29 | 12.49 | 0.71 | 2.54 | 0.34 | 737 / 1080 | 1.63 |

Per-run native frame p50 / p99: E0′ 27.42 / 53.08, 22.07 / 32.49, 22.14 / 30.16; E1 4.48 / 26.59, 3.67 / 12.03, 4.29 / 12.49. Repeat 1 of both trees carries a proc p99 of 22 to 25 ms that repeats 2 and 3 do not (2.2 to 3.2), so repeat 1 is load- or first-launch-affected and its p99 is not read. The coordinator re-measures native p99 on a quiet machine.

Result. H1 holds. Headless s3 frame p50 fell 14.9 ms (bar: at least 8), native s3 p50 fell 17.9 ms and p99 fell 20.0 ms (bar: p99 at least 10; H1 wrong under 3). The remaining telegraph cost is about 0.2 ms headless s3 (1.31 against 1.10 with the draw ablated); the harness step that recycles 32 telegraphs is 0.28 ms, down from 11.02. GPU p99 rose from about 0.8 to 1.6 ms: every driven layer now draws at full extent and discards outside its clip, and hostile fills test stencil. It stays far inside the 7 ms budget. Draws p50 rose by 80 because motion layers that used to be empty (an arming wave's swept ground, an eaten trace, a run at progress 0) now always draw, and p99 fell by 559.

Native s3 frame p99 of about 12 ms still misses the 10 ms CPU target on this loaded machine; proc p99 2.2 to 2.5 and physics p99 3.2 to 4.3 in the clean repeats, so the remainder is render submission, physics ticks and neighbours. H2 (enemy group scans) and H4 (HUD) are next in the ledger's order.

Look budget calibration (`tools/still_diff.gd`, 1920x1080, MSAA 2x, fixed SubViewport): the known-bad control (INSTANT ring at 0.5 with `stripe_motion` hidden) differs on 3.33% of pixels by more than 12/255 with a mean of 0.719/255. It fails on the share rule (budget 0.3%) and would pass the mean rule (0.75/255) alone, so the share rule is the one that discriminates. The worst candidate still is `lane-wedge-50` at 0.167% and `wave-ring-95` at a mean of 0.043/255.

## E1 fix round 2026-09-28 14:19 to 14:32  review findings, re-measured

Candidate: the fix round on top of 154b5f2. Its changes: 10 Hz density sampling, a `run` stencil class, per-layer governance from the roles and non-hostile waves back on `marks()`. Same bench, plans, gate and lock as the E1 entry. The baseline tree is the same `tree-base`. Load was higher than in the first E1 run: 5.7 to 8.5 headless and 7.4 to 9.2 native on 32 threads. Raw data is in `artifacts/local/e1/bench/fix-h` and `bench/fix-n`.

| Scene | Tree | Frame p50 | Frame p99 | Proc p50 | Proc p99 | Harness p50 | Draws p50 / p99 | GPU p99 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| headless s2 | E0′ | 9.63 | 40.91 | 1.23 | 31.51 | 5.99 | | |
| headless s2 | E1 fix | 1.15 | 4.83 | 0.67 | 1.14 | 0.16 | | |
| headless s3 | E0′ | 18.69 | 48.14 | 1.87 | 33.11 | 11.98 | | |
| headless s3 | E1 fix | 1.31 | 6.98 | 0.71 | 1.59 | 0.29 | | |
| headless s3 `--no-telegraph-draw` (1 run) | E0′ | 1.14 | 5.83 | 0.74 | 1.36 | 0.05 | | |
| headless s3 `--no-telegraph-draw` (1 run) | E1 fix | 1.12 | 6.79 | 0.72 | 1.69 | 0.05 | | |
| native s3 | E0′ | 25.31 | 48.51 | 2.76 | 25.61 | 12.68 | 663 / 1671 | 0.80 |
| native s3 | E1 fix | 4.75 | 28.65 | 0.70 | 23.28 | 0.35 | 667 / 1148 | 1.39 |

Per-run native frame p99 / proc p99: E0′ 51.84 / 26.34, 48.51 / 25.61, 31.27 / 3.01; E1 fix 33.21 / 25.44, 13.28 / 2.36, 28.64 / 23.28. Two of the three runs of each tree carry a proc p99 of 23 to 26 ms, and the other run shows 2.4 to 3.0. The spike hit both trees at the same load, so it comes from the machine, not the build. The native p99 median is not a quiet-machine number. The clean E1 fix run (13.28 frame p99, 2.36 proc p99) matches the E1 entry's clean runs (12.03, 12.49).

Result. The fix round keeps H1's saving: headless s3 frame p50 1.31 (E1 1.31), with the telegraph draw ablated 1.12. Native p50 is 4.75 against 4.29 for E1, at load 8 to 9 instead of 4.7 to 8.5. The `run` class adds one batch, and GPU p99 is 1.39 against 1.63 for E1.

Look budget, recalibrated (DESIGN-NOTES, E1 section). Each still is also judged inside its telegraph's box, found from an `empty` ground still, with a box budget of 0.5% share and 0.3/255 mean. Controls: the hidden fill fails at 25.3% of the box, the hidden static keyline at 23.6%, and a 0.4 m band cut from the fill at 2.57%. On the whole frame that band differs on only 0.34% of pixels, at the old 0.3% line. The one-pixel seams reach at most 0.33% of the box. The LANE draw-order change reaches 2.39% (`lane-wedge-50`). It is listed as an expected change, not passed.

## E1 fix round 2, 2026-09-28  the proc-max spike

Symptom: every E1 headless run had one proc max of 69 to 86 ms against the base's 45 to 48. Method: `perf_bench --series=<tsv>` writes every recorded frame; the worst frame's process time was inside `Audio._process` (timed with temporary probes, since removed): `engine.render()` of 189 to 1549 samples took 35 to 86 ms, different frame indexes per run (535, 329, 239 in three runs), physics 0, harness 0.3 ms. Ablations, one run each: `--no-audio` max 2.2 ms; `--no-telegraph-draw`, `--no-vfx`, `--no-hud`, `--no-music` (SilentBand still schedules and synthesises) all kept a 73 to 86 ms frame. The cause is `Audio._on_ready` skipping `prepare_rest()` without an audio device: the instruments bake on the main thread the first time a bar asks, and E1's fast warm phase (120 frames, under a second) ends before those bars. The base has the same spike when its warm phase is as short (base, `--warm-frames=5`: max 71.2 and 72.3 ms). With `--warm-seconds=15` the E1 tree's proc max is 1.65 ms. Not compilation: a headless run compiles no shaders, and pipeline compilation runs on the render thread, outside the proc probe. Native shows the same shape (proc max 35 against 26), probably the worker's bake not yet done when the shorter warm ends; not re-measured, per the brief.

Fix in the bench, not the game: `perf_bench` finishes the band bake before the warm phase (`MusicEngine.prepare_rest()` headless, the worker's task natively; since S1-HITCH, 2026-10-17, `prepare_opening()` too, which now holds stage 1's band), with `--cold-band` to reproduce, plus `--series`, `--warm-frames` and `--warm-seconds`.

Headless s3, three paired runs each, the same bench on both trees (band prebaked), load 10 to 30 on 32 threads. Raw: `artifacts/local/e1fix2/f{a,b}{1,2,3}.{json,tsv}`.

| Tree | Frame p50 | Frame p99 | Proc p99 | Proc max |
| --- | --- | --- | --- | --- |
| E0' base | 19.1, 21.2, 18.4 | 26.0, 32.1, 27.4 | 3.0, 4.1, 3.1 | 35.4, 33.9, 31.7 |
| E1 fix 2 | 1.45, 1.43, 1.42 | 7.7, 7.6, 7.2 | 2.0, 1.6, 1.7 | 18.2, 16.7, 18.3 |

Before the bench fix, the E1 tree's proc max in three runs was 74.4, 80.0 and 84.0 ms. A residual 17 to 19 ms frame remains in the E1 runs (the base's is 32 to 35), with physics 0, in `Audio._process`: a first-use bake `prepare_rest` does not cover. It is not a telegraph cost, and it is the audio owner's to trace.

## Coordinator, 2026-09-28: after E1, H2's verdict, and the s1 gap

- **Quiet native s3 after E1** (v3 88ca24d with E1 at 9532a27, load 2.3 to 2.7, 3 runs): frame p50 3.4 to 3.8 ms, frame p99 10.4 to 13.8 (median 10.9), proc p99 3.0 to 3.6, physics p99 3.0 to 3.2, GPU p99 1.5 to 1.6, draws p99 1040 to 1392, 0 mark materials built in the window. The 18 ms proc max is the audio first-bar bake, not telegraphs. Data: `core-loop-v3-e1/artifacts/local/e1/bench/quiet-native/`.
- **H2 is unproven and not merged.** The E2 unit (branch `proto/core-loop-v3-e2`, 8413f8f) measured 0.29 ms physics p50 in s3 before its stale-list fix, under the 0.4 ms bar, and the final verifier rerun had the change slower (3.92 against 3.66 ms on ticks=2 frames). Its cache already produced one stale-list bug. With proc and physics p99 near 3 ms after E1, the group scans are not the constraint. The branch is parked for reference.
- **Closed the same day: s1 is not a game cost.** Native `perf_bench` on v3 at load 0.1 to 1.2 (a244b21, 2 runs each, `artifacts/local/perf-s1/`): s1 frame p50 1.8 ms, p99 5.5 to 5.8, proc p99 2.5, GPU p99 0.7; s3 frame p50 2.5 to 2.8, p99 8.9 to 10.1, proc p99 2.9, physics p99 2.8 to 3.0, GPU p99 1.5 to 1.6. So s3 meets the 10 ms dev-box gate on a quiet box. The clone's 23 to 32 ms came from `stress_capture`, which takes stills and word counts inside its window; perf questions use `perf_bench`. The original note follows.
- **Opened: s1's frame p99 misses the budget in the visual clone.** Look pass 3's native stress runs show s1 at 23 to 32 ms frame p99 with GPU p99 1 to 2 ms and CPU p99 22 to 35 ms, and the base tree shows 31 ms too, so it predates the look work. s1 is the light scene, so a startup, stage-entry or first-use cost is the leading guess. Measure it on v3 with `perf_bench --scene=s1 --series=<tsv>` before guessing further.
