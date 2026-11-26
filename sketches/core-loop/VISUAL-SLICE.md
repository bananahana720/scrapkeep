# VD-01 playable visual slice

> **Historical / Superseded receipt:** Clear glass shell superseded by the Hoberman mecha and picked cutaway ball look in [ROSTER-LOOK.md](design-v3/ROSTER-LOOK.md) (ruling `dm`).

Andrew selected Style A, painted workshop miniature, and asked for a clear spherical hull with the pilot inside. This slice replaces the previous opaque rolling core and rooftop bust with that arrangement. The existing collision sphere, movement, chase camera, combat, growth, parts and theft logic remain unchanged.

## What is implemented

Each class has a full radius-0.98 glass hull under the rolling Core. The enlarged seated pilot and class equipment remain upright under Pod. A separate Gyro turns from actual player velocity and stops at rest. The ring is an implementation prototype; it does not settle a final ring count or change growth rules. Sable retains fox ears, cream muzzle, cap and rope spool; Rivet has a mole nose, paired machinist goggles, copper fins and optical rail; Kest has a beak, crest, goggles, satchels, mortar and hinged glide vanes.

Glass uses a low-opacity centre and stronger edge reflection. Neutral painted variation multiplies the existing palette materials and surface-role vertex colours. Broad rough ground replaces the checker; the terrain mesh, indices, collision and samples are unchanged. Cooler sky fill balances the warm ground. Presentation-only chunk tucking keeps the upper cockpit clear while retaining every chunk and the existing scale and theft behavior.

The procedural budget is now at most 6500 shell triangles and 4800 pilot triangles. The actual shell/pilot counts are Sable 6456/4344, Rivet 5956/4128 and Kest 6120/4172. The pilot-only increase permits rounded heads, cheeks, torsos and shoulders; no other asset budget changes. Heads are 85% of the first slice’s size, seats have chamfered backs, and overlapping forms connect the body. This is not performance evidence.

## Verify and capture

Run `npm run sketch:smoke` from the repository root. The focused check is the pinned Godot binary with `--headless --path sketches/core-loop --script res://tests/hero_assets_test.gd`. Give `XDG_DATA_HOME` a writable temporary directory when the host blocks Godot's normal user-data directory.

The rendered tool uses the real game and a seeded synthetic encounter. Run from the repository root on the target GPU:

```sh
"$GODOT_BIN" \
  --path sketches/core-loop --script res://tools/visual_capture.gd \
  -- --out=artifacts/local/scrapkeep-vd-dense --class=0 --mode=dense --samples=1800
```

The render target is fixed at 1920×1080 using Window viewport scaling; the preview window starts at 1280×720. `capture.json` records final render texture, PNG, root and physical window dimensions separately. Both texture and PNG must actually be 1920×1080 to qualify. Vsync is disabled. The tool waits at least 180 rendered frames and 450 physics ticks, plus an active attack in dense/boss mode, before saving `scene.png`. Readback, encoding and the following interval are excluded from timing.

Use `--seconds=120` for each of `--mode=traversal`, `--mode=dense --growth=600` and `--mode=boss --growth=600`. Duration mode ignores the sample-count stop and records every interval until the requested post-warmup wall duration (bounded at 120 seconds). Without `--seconds`, `--samples` is a capacity probe capped at 18000; it cannot qualify the 120-second scenario gate. A wall deadline of 60 seconds plus the larger of 90 seconds or the requested duration retains partial evidence. Qualification also requires a hardware adapter, verified resolution and scenario evidence: at least 30 enemies for every measured dense frame; over 100 metres travelled for traversal; boss attack and active-hazard evidence for boss. `target_met` further requires p99 ≤16.7 ms. These wall-clock intervals include scheduling and presentation, not just GPU execution. Physics and wall durations are reported separately.

`--growth=600` calls the real run scrap-addition path. Metadata records added scrap and the actual screenshot mass, heft class, chunks and shell scale. Requested growth must produce a heft class above one, chunks and a shell scale above one to qualify; `grown_build_verified` reports that check. It does not create collected parts. Screenshot and final monitor snapshots include visible primitives, draw calls, static memory and video/texture/buffer memory; renderer support may yield zero for unavailable GPU memory counters. Pilot, traversal and dense scenarios start inside the existing Spillway beacon bowl’s flat floor, ten metres east and eight metres north of the beacon. Dense replenishes 48 chasers/lobbers with firing and braking input. Traversal uses circular movement input. Both use calm mode to suppress ambient arrivals and shove. Boss uses the existing `flow.enter_boss` seam and phase-3 dev hook, real spawner and hazards, with calm mode off. All scenarios inflate player HP; these staged workloads do not establish a complete natural run.

For pilot inspection, use `--mode=pilots --growth=600 --samples=60` with each of `--class=0`, `1` and `2`. The real body must be grounded and moving below 0.1 m/s for 30 consecutive ticks before freezing. Metadata records the settled tick and ground clearance. The camera follows Pod orientation: `--azimuth=0` is front, default `35` front three-quarter and `180` back. The gameplay chase camera is unchanged.

## Acceptance still needed

The models are procedural playable prototypes. Their surfaces and simplified anatomy do not yet match the atlas's sculpted detail, material depth or expression. Inspect all three pilots in the actual renderer, at chase distance, with a heavy build and during a fight. Large collected parts can still cross the cockpit. The parent owns native screenshot review, real RTX qualification, final integration and Andrew's visual/feel verdict. Blender previews and headless checks cannot settle those questions.

The first native capture exposed fine ground mottling and a rear-facing inspection view. The follow-up removes brush/grain detail from the ground texture, uses one low-frequency octave, restores the prior warm sunlight, and makes the inspection camera follow Pod orientation. The subsequent anatomy pass reduces head size and connects the seated body; native review remains required.
