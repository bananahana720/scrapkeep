# vfx kind

An agent writes `recipe.py` whose `build(params)` returns a plain data spec for one to four
`CPUParticles3D` emitters. The forge validates the spec, converts it to `effect.tscn`, previews
it as a strip and loads the scene in headless Godot. No model-written code ever runs in Godot,
and no GDScript or scene text comes from the agent.

```sh
python3 tools/asset-forge/forge.py make vfx --pack core-loop --name spark_burst "<prompt>"
python3 tools/asset-forge/forge.py run artifacts/local/forge/core-loop/spark_burst/v001   # rebuild + revalidate
python3 tools/asset-forge/forge.py promote spark_burst v001   # -> sketches/core-loop/assets/vfx/spark_burst/
```

## Files

| File | Role |
| --- | --- |
| `entry.py` | runs in the sandbox (Blender's interpreter, no Blender API used: the forge has one runner). Runs the recipe, checks the spec, writes `out/effect.json`, `preview/sheet.png`, `result.json`. |
| `vfxspec.py` | schema, defaults, ranges, budget (`normalize`, `validate`) |
| `vfxsim.py` | deterministic simulator, hash, bounds, strip renderer |
| `vfxtscn.py` | spec to `effect.tscn` and the expectations the Godot check uses |
| `vfx_check.gd` | headless load check |
| `validate.py`, `promote.py`, `brief.md`, `kind.toml` | kind interface |

## Spec schema (version 1)

Top level: `schema` (1), `seed` (int, 0 to 2^31-1), `emitters` (1 to 4; the pack's `draw_calls.vfx`).
Unknown fields fail. Required per emitter: `name`, `amount`, `lifetime`, `color_ramp`.

| Field | Default | Range |
| --- | --- | --- |
| `name` | | `[a-z][a-z0-9_]{0,23}`, unique |
| `amount` | | int >= 1; sum over emitters <= budget |
| `lifetime` | | 0.05 to 2.0 s |
| `one_shot` | true | bool |
| `explosiveness`, `randomness` | 1.0, 0.0 | 0 to 1 |
| `offset` | [0,0,0] | each within +-3 m |
| `shape`, `extents` | point, [0.1]*3 | point, sphere (radius = extents[0]), box (half extents); extents 0 to 2 |
| `direction`, `spread` | [0,1,0], 45 | non-zero vector; 0 to 180 degrees (half angle) |
| `velocity`, `damping` | [2,5], [0,0] | `[min, max]`, 0 to 20 |
| `gravity` | [0,-9.8,0] | each +-40 |
| `scale` | [1,1] | `[min, max]`, 0.05 to 4, multiplies `mesh_size` |
| `scale_curve` | [[0,1],[1,0]] | 2 to 6 `[t, value]`, t strictly rising in 0..1, value 0 to 2, linear |
| `color_ramp` | | 2 to 5 stops `{t, role, alpha}`; `role` is a palette role (palette.gd through the pack), alpha 0 to 1 (default 1) |
| `emissive` | 1.0 | 0 to 3, multiplies the unshaded albedo (HDR above 1) |
| `blend` | mix | mix, add |
| `mesh`, `mesh_size` | box, [0.12]*3 | quad, sphere, box, prism; each 0.02 to 1.0 m |
| `align_y` | false | bool |

Palette is enforced by construction: a ramp stop names a role; hex values and unknown roles fail
(`palette_roles`). The converter resolves the role to the hex parsed from `palette.gd`.

## Scene conventions

Matches `vfx.gd`'s pooled bursts: unshaded `StandardMaterial3D` with `vertex_color_use_as_albedo`,
`emitting = false`, `one_shot`, `explosiveness`, `direction`/`spread`, velocity min/max, `gravity`,
`scale_amount_min/max` with a `scale_amount_curve`, `particle_flag_align_y`, shadows off, one mesh per
emitter, spheres at 6 radial segments and 3 rings. Differences: a `color_ramp` Gradient sets colour (vfx.gd
sets `p.color` per burst), the seed is fixed (`use_fixed_seed`), and `quad` uses `BILLBOARD_PARTICLES`.
A pool would instance the scene and call `restart()` plus `emitting = true` on each child, as `burst()` does.
The root carries `metadata/forge_spec_sha256`, which the load check compares.

## Budget

48 particles per effect in total: twice the largest pooled burst in `vfx.gd` (`fountain`, max 24); a
test pins it to the source. Per-category bands in `packs/core-loop.toml` (`bands.vfx`): `prop` (the pack
default category, so it must exist) and `burst` 1 to 48, `ambient` 1 to 24. The cloud-radius cap is
8 m (`sizes.vfx`, warning above 6 m) and the emitter cap is 4 (3 for `ambient`). The budget is per
effect; the pooled ceiling a fight can hold still comes from `vfx.gd`'s `pool x max`.

## The hash

Particle state is a pure function of `(spec, emitter, slot, time)`. Randomness:

```
mix32(x):  x &= 0xFFFFFFFF; x ^= x>>16; x = (x*0x7FEB352D)&M; x ^= x>>15; x = (x*0x846CA68B)&M; x ^= x>>16   # lowbias32
rand(seed, emitter, slot, channel):
    x = mix32(seed + 0x9E3779B9)
    for v in (emitter, slot, channel): x = mix32(x ^ (((v+1) * 0x85EBCA6B) & M))
    return x / 2^32                                   # [0, 1)
```

Channels: 0 azimuth, 1 polar, 2 speed, 3 to 5 emission point, 6 scale, 7 damping, 8 birth jitter.
`test_hash_known_values` pins outputs so a GDScript port (64-bit ints, mask after every multiply) can be
checked against the same numbers. The port is not written. Looping emitters use `slot + amount * cycle`
as the slot. Birth time is `(1 - explosiveness) * lifetime * slot/amount` plus a `randomness`-scaled
jitter.

## Preview

`preview/sheet.png`: 6 frames of 160 px (960 x 160), t = 0.05 s to 95% of the longest lifetime, fixed
orthographic 3/4 camera (yaw 35, pitch 28), charcoal background, a 0.5 m ground ring and a 1 m scale bar per
frame. Particles are drawn back to front as discs (sphere, quad), squares (box) or triangles (prism),
alpha-blended or additive, sized `mesh_size * scale * curve`. The scale is fixed per effect from the whole
strip. Same spec and seed give identical bytes (a test hashes two renders; so does the recorded proof).

## Gaps

- The preview is a Python simulation, not an in-engine render. Motion is analytic: damping is a constant
  deceleration along the launch direction (Godot applies it to the whole velocity, gravity included), there
  is no ground collision, no real random-number match with Godot's emitter, no lighting, bloom or
  true additive HDR, and no perspective or camera shake. Frames are 6 samples, not motion.
- The Godot check proves the scene loads and its properties equal the spec (amount, lifetime, flags,
  vectors, gradient colours, curve samples, mesh class, material flags). It does not prove how the effect
  looks in the game, performance, or that it feels right.
- Emission is not wired to a game event: promotion places the scene under `assets/vfx/<asset>/`; hooking it
  to a signal and pooling it is a follow-up in `vfx.gd`.
- `forge.py` still says "triangle band" in the agent's task line; `brief.md` tells the agent to read it as
  the particle budget.
