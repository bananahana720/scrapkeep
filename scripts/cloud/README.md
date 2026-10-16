# Cloud sessions

`.claude/hooks/session-start.sh` runs at the start of every Claude Code cloud session (it exits at once anywhere else). It installs:

- Godot 4.7.2 editor at `/opt/scrapkeep-toolchain/`, checked against the hashes in `.github/workflows/native-smoke.yml`, and exported as `GODOT_BIN`.
- The Linux export templates under `~/.local/share/godot/export_templates/4.7.2.stable/`.
- Blender 5.2.2 LTS as the `bpy` wheel from PyPI (same build hash, `d13f752e3b9c`), with `scripts/cloud/blender` on `PATH` as the `blender` command. `download.blender.org` is outside the default network policy, so the full binary is not used.
- Locked npm dependencies.
- `sketches/core-loop/override.cfg` (git-excluded, cloud only) raising Godot's worker pool to 16 threads. With the default pool sized from 4 vCPUs, `audio_rescue_test` and `audio_achievement_test` hang at quit and `audio_bake_cancel_test` races.

The container has no GPU. What runs here:

| Work | Command | Notes |
| --- | --- | --- |
| Godot tests, lint and bot runs | `npm run sketch:gate`, `npm run sketch:smoke -- --sketch core-loop --test <name>` | 4 vCPU; set `SMOKE_SLOTS=4` to use them all. |
| Linux test build with win proofs | `node scripts/cloud/export-headless.mjs --win-proof` | Import, release gate, export, headless boots, three skipper wins. No ACE stems, no boss smoke, no tarball. |
| Blender recipes and Cycles stills | `blender -b --threads 2 --python-exit-code 1 -P <recipe> -- ...` | Recipe GLBs match the committed bytes. Cycles renders on the CPU. |

What still needs Andrew's machine: `npm run sketch:export` (ACE stems are gitignored, and the boss smoke needs Vulkan), Eevee and any Vulkan capture, ACE-Step music, and playtesting.
