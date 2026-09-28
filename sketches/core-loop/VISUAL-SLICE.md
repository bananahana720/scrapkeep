# VD-01 playable visual slice

Andrew selected Style A, painted workshop miniature, and asked for a clear spherical hull with the pilot inside. This slice replaces the previous opaque rolling core and rooftop bust with that arrangement. The existing collision sphere, movement, chase camera, combat, growth, parts and theft logic remain unchanged.

## What is implemented

Each class has a full radius-0.98 glass hull under the rolling Core. The enlarged seated pilot and class equipment remain upright under Pod. A separate Gyro turns from actual player velocity and stops at rest. The ring is an implementation prototype; it does not settle a final ring count or change growth rules. Sable retains fox ears, cream muzzle, cap and rope spool; Rivet has a mole nose, paired machinist goggles, copper fins and optical rail; Kest has a beak, crest, goggles, satchels, mortar and hinged glide vanes.

Glass uses a low-opacity centre and stronger edge reflection. Neutral painted variation multiplies the existing palette materials and surface-role vertex colours. Broad rough ground replaces the checker; the terrain mesh, indices, collision and samples are unchanged. Cooler sky fill balances the warm ground. Presentation-only chunk tucking keeps the upper cockpit clear while retaining every chunk and the existing scale and theft behavior.

The procedural budget is now at most 6500 shell triangles and 2200 pilot triangles. The actual shell/pilot counts are Sable 6284/1712, Rivet 5784/1644 and Kest 5948/1472. This budget permits smoother faces and the complete sphere; it is not performance evidence.

## Verify and capture

Run `npm run sketch:smoke` from the repository root. The focused check is the pinned Godot binary with `--headless --path sketches/core-loop --script res://tests/hero_assets_test.gd`. Give `XDG_DATA_HOME` a writable temporary directory when the host blocks Godot's normal user-data directory.

The rendered tool uses the real game and a seeded synthetic encounter. Run from the repository root on the target GPU:

```sh
/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 \
  --path sketches/core-loop --script res://tools/visual_capture.gd \
  -- --out=/tmp/scrapkeep-vd-dense --class=0 --mode=dense --samples=1800
```

It requests 1920×1080, disables vsync, warms 180 rendered frames, saves `scene.png`, and excludes screenshot readback from the measured interval. `capture.json` includes every wall-clock interval between rendered frames, enemy counts, source hashes, Git identity, engine and adapter identity, and p99. A 90-second wall deadline retains partial measurements. It refuses headless execution. Software rendering and samples with fewer than 1800 frames or 30 enemies cannot meet its hardware qualification gate. The target is DESIGN-V2 §14's p99 ≤16.7 ms. These timings include scheduling and presentation; they are not GPU execution timings.

Repeat with `--class=1` and `--class=2`. For pilot inspection, use `--mode=pilots --samples=60`; that mode freezes the body and adds a close inspection camera. It does not modify the gameplay chase camera. Dense mode uses ordinary chase presentation, scripted movement and firing, inflated player HP, and calm mode to suppress ambient arrivals and hit shove. It replenishes 48 chasers/lobbers. This staged workload does not establish full-run performance.

## Acceptance still needed

The models are procedural playable prototypes. Their surfaces and simplified anatomy do not yet match the atlas's sculpted detail, material depth or expression. Inspect all three pilots in the actual renderer, at chase distance, with a heavy build and during a fight. Large collected parts can still cross the cockpit. The parent owns native screenshot review, real RTX qualification, final integration and Andrew's visual/feel verdict. Blender previews and headless checks cannot settle those questions.
