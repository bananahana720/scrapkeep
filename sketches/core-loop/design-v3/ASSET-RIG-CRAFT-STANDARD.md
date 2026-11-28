# Scrapkeep Asset & Rig Craft Standard (T-Pose / Rest-Pose, Watertight Topology & Liveliness)

This standard defines the binding craft bar for Scrapkeep's character rigs, hero assemblies, wearables, weapons, enemies, and props. Every measurement below was taken directly from the repository GLBs and GDScript sources at base commit `e91e8837b` using [`tools/asset_rig_craft_audit.gd`](../tools/asset_rig_craft_audit.gd).

It applies [`VISUAL-LANGUAGE.md`](../VISUAL-LANGUAGE.md) and [`SIGHT-PERSONA.md`](SIGHT-PERSONA.md) (Dot Marrow, 2010 satin custom-vinyl & real brass/copper finish) without amending any Bible ruling.

---

## 1. Canonical Coordinate, Scale & T-Pose / Rest-Pose Standard

### 1.1 World & Cockpit Space
- **Coordinate system:** Right-handed Y-up (`+Y` up, `-Z` forward, `+X` right), `1.0 unit = 1.0 metre`.
- **Scale anchor:** The player gyrosphere has radius `1.0 m` (`2.0 m` diameter). Every hero structure or cockpit carries at least one hand-sized scale cue (`0.35–0.75 m` valve wheel, rung, handle, yoke grip, or dial bezel; `SIGHT-PERSONA.md` habit 7).
- **Grounded origin:** Static/architectural props rest cleanly with `AABB.position.y == 0.0` (`±0.02 m`). Seated pilots share a canonical cockpit seat origin where `pelvis` sits at `(0.000, -0.300, 0.000)` and both hands rest at `(±0.320, +0.050, -0.400)`.

### 1.2 Dual-Pose Authoring Standard (Authoring T-Pose -> Shipped Seated Rest Pose)
All bipedal/piloted characters follow a strict two-stage pose discipline:
1. **Authoring T-Pose (Rigging, Weighting & Gear Calibration):**
   - Arms extended horizontally along `±X` (`upper_arm` within `0° ± 5°` of horizontal, palms down `-Y`), spine vertical along `+Y`, head facing `-Z`.
   - Left/right bilateral bone symmetry error `<= 0.005 m`; centerline bones (`root`, `pelvis`, `spine_01`, `spine_02`, `neck`, `head`) centered at `x = 0.000 m ± 0.005 m`.
   - Skin weights normalized per vertex (`sum == 1.0`, max 4 influences) and verified watertight before transferring to cockpit rest.
2. **Shipped Cockpit Rest Pose (Runtime Bind & Gear Mount Pose):**
   - All 6 pilots share the exact 25-bone canonical hierarchy so procedural wearables (`PilotGearKit`), reactions (`PilotReactions`), camera glances (`PilotGlance`), and layered liveliness (`PilotLiveliness`) work identically across the entire roster:
     - **Spine chain (6):** `root`, `pelvis`, `spine_01`, `spine_02`, `neck`, `head`
     - **Arm & control chain (9):** `shoulder.L`, `shoulder.R`, `upper_arm.L`, `upper_arm.R`, `lower_arm.L`, `lower_arm.R`, `hand.L`, `hand.R`, `tool.R`
     - **Species & expressive secondary bones (10):** `ear.L`, `ear.R`, `crest`, `curl.L`, `curl.R`, `goggles`, `jaw`, `snout`, `tail.01`, `tail.02`
   - Canonical rest grip anchors: `hand.L = (-0.320, 0.050, -0.400)`, `hand.R = (+0.320, 0.050, -0.400)`, `shoulder.L/R = (±0.130, -0.060, -0.005)`, `upper_arm` angle `62.2°` below horizontal, L/R symmetry error `0.0000 m`.

---

## 2. Watertight Manifold Topology & Surface Craft Standard

Every newly authored procedural `ArrayMesh` or Blender GLB hero/wearable/weapon/prop MUST satisfy:
1. **Zero raw primitive silhouettes:** No bare `BoxMesh`, `CylinderMesh`, `SphereMesh`, `CapsuleMesh`, or `PrismMesh` on player-facing hero geometry. Every structural edge carries chamfered bevels, recessed seams, fasteners (bolts/rivets/straps on Keeper/Fleet gear; cast notched grooves on Old Works), and three-tier scale hierarchy (primary mass -> medium mechanical sub-assemblies -> fine micro-details).
2. **Watertight manifold topology:**
   - Every edge shared by exactly 2 triangles (`boundary_edges == 0`, `non_manifold_edges == 0`, `manifold_edge_ratio == 1.0000`).
   - Zero degenerate triangles (`area > 1e-12`).
   - Strict clockwise front-face winding aligned with outward unit vertex normals (`outward_ratio >= 0.995`).
   - Finite non-degenerate metric UVs and tangents (`ARRAY_TANGENT`) on every surface.
3. **Vertex-color PBR weathering mask contract (shared with `craft_master_weathering.gdshader`):**
   - `COLOR.r` — **Edge wear:** `0.75–1.0` on bevels, outer edges, bolt crowns, and hand grips; `0.00–0.15` on flat panel interiors.
   - `COLOR.g` — **Cavity grime / AO:** `0.70–1.0` in recessed seams, louver pans, rivet washers, under straps/buckles, and near ground footing; `0.00–0.15` on exposed faces.
   - `COLOR.b` — **Emissive mask:** `1.0` strictly on working active parts (gauge faces, hot vents, plasma conduits, working coils); `0.0` everywhere else (`SIGHT-PERSONA.md` habit 5).
   - `COLOR.a` — `1.0` (material blend weight).

---

## 3. Measured Repository Audit (Base `e91e8837b`)

Measured directly by `res://tools/asset_rig_craft_audit.gd` in headless Godot 4.7.2:

### 3.1 Pilot Rigs (`pilot_*_anim.glb`) — 6 / 6 Audited (Raw GLB Skin Weights, Normals, Manifold & Loop Seam)

| Pilot Class | GLB | Tris | Degen / InvN | Bones | Manifold Ratio | Open / Non-Manifold Edges | Raw Skin Weight Sum (`outTol`/`zeroW`/`badIdx`) | L/R Symmetry | Rest Pose | `idle_loop` Seam (rot / pos) | Status |
| --- | --- | ---: | --- | ---: | ---: | --- | --- | ---: | --- | --- | --- |
| `pylon_engineer` (Sable) | `pilot_sable_anim.glb` | 9,812 | `0 / 0` | 25/25 | `1.0000` | `0 / 0` | `[1.00000..1.00000]` (`0/0/0`) | `0.0000 m` | `seated_cockpit_rest` (`62.2°`) | `0.00° / 0.0000 m` | Watertight PASS |
| `demolitions_caster` (Kest) | `pilot_kest_anim.glb` | 10,828 | `0 / 0` | 25/25 | `1.0000` | `0 / 0` | `[1.00000..1.00000]` (`0/0/0`) | `0.0000 m` | `seated_cockpit_rest` (`62.2°`) | `0.00° / 0.0000 m` | Watertight PASS |
| `runner_gunner` (Rivet) | `pilot_rivet_anim.glb` | 10,456 | `16 / 0` | 25/25 | `0.9969` | `48 / 0` | `[1.00000..1.00000]` (`0/0/0`) | `0.0000 m` | `seated_cockpit_rest` (`62.2°`) | `0.00° / 0.0000 m` | Minor visor-rim open loop (48) |
| `tarn` (Tarn) | `pilot_tarn_anim.glb` | 10,568 | `52 / 8` | 25/25 | `0.9962` | `60 / 0` | `[1.00000..1.00000]` (`0/0/0`) | `0.0000 m` | `seated_cockpit_rest` (`62.2°`) | `0.00° / 0.0000 m` | Minor collar open loop (60); 8 invN tris |
| `tally` (Tally) | `pilot_tally_anim.glb` | 10,121 | `28 / 0` | 25/25 | `0.9928` | `89 / 20` | `[1.00000..1.00000]` (`0/0/0`) | `0.0000 m` | `seated_cockpit_rest` (`62.2°`) | `0.00° / 0.0000 m` | Action item: seal 20 non-manifold edges on next GLB rebuild |
| `remembered_cannon` (Cannon) | `pilot_cannon_anim.glb` | 4,720 | `2 / 0` | 25/25 | `0.9890` | `78 / 0` | `[1.00000..1.00000]` (`0/0/0`) | `0.0000 m` | `seated_cockpit_rest` (`62.2°`) | `0.04° / 0.0000 m` | Minor cuff open loop (78) |

**Key pilot findings:**
- **Rig, Skin-Weight & Loop Continuity:** 6/6 pilots have the exact 25-bone canonical skeleton, `0.0000 m` bilateral rest symmetry, 100% normalized raw `.glb` skin weights (`sum == 1.00000 ± 1e-4`, `0` zero-weight vertices, `0` out-of-range bone indices), and seamless `idle_loop` continuity (`<= 0.04°`, well below the `0.50°` limit).
- **Blender-to-Godot Bone Rest Basis:** Imported `head`, `spine_02`, and `pelvis` bones carry a `90°` X-rotated rest basis (`local +Y = -Z forward`, `local +Z = +Y up`). `PilotGearKit.mount_pilot_wearables()` converts canonical skeleton-space offsets and orientations through `get_bone_global_rest(bi).basis.orthonormalized().inverse()` so wearables mount upright with zero drift.
- **Liveliness Gap (Closed by `PilotLiveliness`):** Previously, pilots played only static `idle_loop` + discrete reaction clips + idle camera glances, with zero continuous breathing layering, turn-bank G-force lean, landing compression, species ear/crest/visor follow-through, recoil settle, or cockpit yoke coupling.

### 3.1b Procedural `PilotGearKit` Watertight Topology & 60 Hz Motion Telemetry

All 6 procedural `PilotGearKit` meshes (`riveted_goggles`, `shoulder_harness`, `utility_belt`, `cockpit_yoke`, `gauge_cluster`, `cockpit_pedal`) verify **100% watertight manifold** (`boundary_edges = 0`, `non_manifold_edges = 0`, `degenerate_tris = 0`, `inverted_normals = 0`, `outward_ratio = 1.0000`), with localized `COLOR.b = 1.0` emissive strictly on goggle optical lenses and gauge dial faces.

Measured across a live **60 Hz 17-frame (`t = 0..16`) dynamic combat maneuver** (High-G bank + weapon recoil + hard land recovery) with 2-bone analytic arm-to-yoke IK (`upper_arm` + `lower_arm`):

| Pilot Class | Max Bone Angular Vel (`<= 25°/f`) | Peak Bone | Snaps `> 25°/f` | Max Hand-to-Yoke Error | Mean Hand-to-Yoke Error | Min Head-to-Dash Clearance | Status |
| --- | ---: | --- | ---: | ---: | ---: | ---: | --- |
| `pylon_engineer` (Sable) | `4.86°/f` | `upper_arm.R` | `0` | `0.0025 m` (`2.5 mm`) | `0.0010 m` | `0.524 m` | PASS |
| `runner_gunner` (Rivet) | `4.84°/f` | `upper_arm.R` | `0` | `0.0025 m` (`2.5 mm`) | `0.0010 m` | `0.536 m` | PASS |
| `demolitions_caster` (Kest) | `4.87°/f` | `upper_arm.R` | `0` | `0.0025 m` (`2.5 mm`) | `0.0010 m` | `0.537 m` | PASS |
| `tarn` (Tarn) | `4.82°/f` | `upper_arm.R` | `0` | `0.0025 m` (`2.5 mm`) | `0.0010 m` | `0.534 m` | PASS |
| `tally` (Tally) | `4.85°/f` | `upper_arm.R` | `0` | `0.0025 m` (`2.5 mm`) | `0.0010 m` | `0.535 m` | PASS |
| `remembered_cannon` (Cannon) | `4.83°/f` | `upper_arm.R` | `0` | `0.0025 m` (`2.5 mm`) | `0.0010 m` | `0.507 m` | PASS |

### 3.2 Shells & Shipped Weapons — 8 / 8 Audited

| Asset | Tris | Bones | Manifold Ratio | Open Edges | Cockpit Controls Found |
| --- | ---: | ---: | ---: | ---: | --- |
| `shell_sable.glb` | 5,704 | 0 | `0.9796` | 176 | `Pod`, `Core`, `WeaponRing` |
| `shell_rivet.glb` | 6,946 | 0 | `1.0000` | 0 | `Pod`, `Core`, `WeaponRing` |
| `shell_kest.glb` | 7,708 | 0 | `1.0000` | 0 | `Pod`, `Core`, `WeaponRing` |
| `shell_tarn.glb` | 7,376 | 0 | `0.9995` | 6 | `Pod`, `Core`, `WeaponRing` |
| `shell_tally.glb` | 5,632 | 0 | `1.0000` | 0 | `Pod`, `Core`, `WeaponRing` |
| `shell_cannon.glb` | 7,616 | 0 | `0.9833` | 192 | `Pod`, `Core`, `WeaponRing` |
| `rivet_revolvers.glb` | 3,816 | 9 | `0.9834` | 96 | WeaponRing rigged |
| `kest_clacker.glb` | 232 | 2 | `1.0000` | 0 | Cockpit rigged |

### 3.3 World 1 Enemies, Warden & Boss GLBs — 18 / 18 Audited

- **13 / 18 GLBs measure `1.0000` watertight** (`0` boundary, `0` non-manifold): `enemy_chaser`, `enemy_lobber`, `enemy_dispatcher`, `enemy_hooker`, `enemy_mag_trapper`, `enemy_netcaster`, `enemy_linker`, `enemy_jolt_layer`, `enemy_catch_trap`, `enemy_deflector`, `enemy_bola_thrower`, `enemy_swarm_remnant`.
- **5 / 18 GLBs have minor open or non-manifold seam edges to seal in future Blender rebuilds:**
  - `enemy_foreman.glb` (`0.9987`, `16` open, `0` non-manifold, 9 bones)
  - `enemy_boom_tender.glb` (`0.9992`, `0` open, `9` non-manifold)
  - `enemy_plated_brute.glb` (`0.9970`, `12` open, `12` non-manifold, 4 bones)
  - `enemy_splitter.glb` (`0.9957`, `48` open, `0` non-manifold, 13 bones)
  - `warden_reactor.glb` (`0.9923`, `132` open, `0` non-manifold, 4 bones)
  - `boss_brindle.glb` (`0.9895`, `246` open, `12` non-manifold)

### 3.4 Code-Level Greybox Primitive Census (`res://src/`)

`asset_rig_craft_audit.gd` measured **287 code-built primitive mesh sites across 94 `src/` files**:
- **High-priority hero & combat silhouettes:** `src/build/accretion.gd` (6), `src/combat/bolts.gd` (1), `src/presentation/line_view.gd` (1), `src/world/contraptions.gd` (23), `src/world/bay.gd` (18), `src/world/activities.gd` (7), `src/world/radio_cache.gd` (3), `src/boss/arena.gd` (4).
- **UI & preview scaffolding:** `src/ui/class_preview.gd` (12), `src/presentation/vfx.gd` (8), `src/presentation/player_fx.gd` (7).

---

## 4. Layered Skeletal Liveliness & Cockpit Coupling Architecture

Live pilot motion is composed cleanly in layers without mutating imported `AnimationPlayer` tracks:
1. **Base Clip Layer (`AnimationPlayer` + `PilotReactions`):** Plays seamless `idle_loop`, `ult_ride_loop`, and priority-gated reaction clips (`brace`, `heave`, `wince`, `big_cheer`, `smash`, `drop_land`, `slump`).
2. **Procedural Liveliness Layer (`PilotLiveliness`, `SkeletonModifier3D`):**
   - Continuous dual-harmonic breathing (`spine_01`, `spine_02`, `neck`, `head`, `shoulder.L/R`).
   - Velocity/aim head look-ahead (`neck`, `head`) yielding smoothly to `PilotGlance`.
   - Spring-damped lateral G-force turn-bank & vertical jump/land inertial compression (`spine_01`, `spine_02`, `neck`, `head`, `upper_arm.L/R`).
   - Species-specific secondary spring motion on `ear.L/R`, `crest`, `curl.L/R`, `goggles`, `snout`, and `tail.01/02`.
   - Weapon-fire recoil & reaction impulses driven from `PilotReactions.REACTION_IMPULSES`.
   - Direct cockpit control coupling (`YokeRig` roll/pitch, `ThrottleLever` throw, `PedalL`/`PedalR` pump).
3. **Camera Glance Layer (`PilotGlance`, `SkeletonModifier3D`):** Turns chest/neck/head over the shoulder toward the chase camera when stationary, forwarding frame kinematics to `PilotLiveliness` every tick.
4. **Accessibility (`Comfort.reduced_motion`):** When reduced motion is enabled, `PilotLiveliness` decays all cosmetic springs to zero and leaves rest/clip poses undisturbed.

---

## 5. Verification Gate Commands

Run in the foreground with scratch `HOME`:
```sh
HOME="$PWD/artifacts/local/sculptor-home" "$GODOT_BIN" --headless --path sketches/core-loop --script res://tools/asset_rig_craft_audit.gd
HOME="$PWD/artifacts/local/sculptor-home" "$GODOT_BIN" --headless --path sketches/core-loop --script res://tests/pilot_rig_liveliness_test.gd
npm run sketch:lint
HOME="$PWD/artifacts/local/sculptor-home" npm run sketch:fast -- --base e91e8837b --shuffle
```
