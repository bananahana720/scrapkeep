# R3: Tools, add-ons, asset generation and design expertise

Haiku web scout, 2026-09-28. These are leads from search results; claims the scout marked unverified are flagged. The coordinator's decisions are in ROADMAP.md, "Tool stack".

## Engine
- Godot 4.6 (January 2026) made Jolt the default physics for new 3D projects; existing projects keep their setting. https://godotengine.org/releases/4.6/
- Godot 4.8 is in development (dev2, July 2026: editor quality-of-life, Jolt 5.6). Its release date is unverified.
- The scout's verdict was to stay on Godot rather than Unreal or Unity for a solo, Linux, headless-tested 3D roguelite. The coordinator agrees; the reason is sunk tooling, not just engine merit.

## Add-ons
- Phantom Camera: follow and framing with damping, in the style of Cinemachine. MIT licence. https://phantom-camera.dev/
- gdUnit4: a test framework with scene testing and JUnit output. https://godotengine.org/asset-library/asset/4390
- GODOT-VFX-LIBRARY: combat effects, shake and damage numbers. https://github.com/haowg/GODOT-VFX-LIBRARY
- Debug Draw 3D: runtime debug lines, shapes and text. Maturity unverified.
- Signal Lens: a visual debugger for signals.
- Addon Save: saving with encryption. https://godotengine.org/asset-library/asset/4305

## Local 3D asset generation (16 GB)
- TRELLIS.2: image or text to 3D, exporting GLB or OBJ. MIT licence. https://trellis2.app
- Hunyuan3D v3.1: quad topology and PBR textures. Tencent licence; read it before any commercial use.
- image-to-3dlab: a local command-line tool and viewer for both models. https://github.com/Bingeljell/image-to-3dlab/
- Blender cleanup: automatic retopology (QuadriFlow, or Hunyuan's tool), a Data Transfer modifier for custom normals, and Cycles or EEVEE bakes.

## Design expertise
- MDA framework (Hunicke, LeBlanc, Zubek). https://users.cs.northwestern.edu/~hunicke/MDA.pdf
- Schell, *The Art of Game Design* (lenses), and Swink, *Game Feel* (response curves, momentum).
- GDC: the Rogue Legacy design postmortem (https://www.gdcvault.com/play/1020541/) and Riot's roguelike talk (https://www.gdcvault.com/play/1022119/).
- A five-question playtest sheet. The canonical source is unverified.

## Playtest and analytics
- playtest-telemetry-godot (https://github.com/etodd/playtest-telemetry-godot), Talo (https://trytalo.com), and Framedash (https://framedash.dev) for heatmaps.
- A starter set of about 10 events: sessions, loop completion, boss attempts, pickups, death positions, upgrades, quit reason.
