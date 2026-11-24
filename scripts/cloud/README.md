# Cloud sessions

`.claude/hooks/session-start.sh` runs at the start of every Claude Code cloud session (it exits at once anywhere else). It runs [`tools/cloud/setup.sh`](../../tools/cloud/setup.sh), which the cloud environment's setup script can also run so the toolchain is cached; [CLOUD-SETUP.md](../../tools/cloud/CLOUD-SETUP.md) lists the environment settings. It installs:

- Godot 4.7.2 editor at `/opt/scrapkeep-toolchain/`, checked against the pinned Godot 4.7.2 release hashes in `tools/cloud/setup.sh`, and exported as `GODOT_BIN`.
- The Linux export templates under `~/.local/share/godot/export_templates/4.7.2.stable/`.
- Blender 5.2.2 LTS as the `bpy` wheel from PyPI (same build hash, `d13f752e3b9c`), with `scripts/cloud/blender` on `PATH` as the `blender` command. `download.blender.org` is outside the default network policy, so the full binary is not used.
- Locked npm dependencies.

The container has no GPU. What runs here:

| Work | Command | Notes |
| --- | --- | --- |
| Godot tests, lint and bot runs | `npm run sketch:gate`, `npm run sketch:smoke -- --sketch core-loop --test <name>` | 4 vCPU; set `SMOKE_SLOTS=4` to use them all. |
| Linux test build with win proofs | `node scripts/cloud/export-headless.mjs --win-proof` | Import, release gate, export, headless boots, three skipper wins. No ACE stems, no boss smoke, no tarball. |
| Red-team pass on a wave build | `npm run redteam -- --wave=<n>` | Rotating bot personas, item fuzz, build sweep, dense-fight bench, placeholders; one ranked findings page. See [the red team](../redteam/README.md). About an hour. |
| Blender recipes and Cycles stills | `blender -b --threads 2 --python-exit-code 1 -P <recipe> -- ...` | Recipe GLBs match the committed bytes. Cycles renders on the CPU. |

What still needs Andrew's machine: `npm run sketch:export` (ACE stems are gitignored, and the boss smoke needs Vulkan), Eevee and any Vulkan capture, ACE-Step music, and playtesting.
