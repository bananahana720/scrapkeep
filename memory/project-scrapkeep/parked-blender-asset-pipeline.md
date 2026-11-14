---
name: parked-blender-asset-pipeline
description: Andrew wants custom Scrapkeep assets, animations and dynamic menus built with Blender (CLI installed, MCP not yet) — unparked 2026-09-27 for the core-loop v2 look track (plan synchronous-weaving-crystal.md)
metadata:
  type: project
---

On 2026-09-26, during the core-loop demo build, Andrew suggested using Blender for custom assets, animations and dynamic menus: a home screen, level select and settings. The details are parked in the session plan `/home/andrew/.claude/plans/uh-as-feedback-i-cuddly-steele.md`, under "Parked for after the demo".

**Why:** the demo keeps greybox art so it ships fast. Andrew still wants a way to make richer visuals himself later.

**How to apply:** unparked 2026-09-27: the core-loop v2 plan (`/home/andrew/.claude/plans/synchronous-weaving-crystal.md`, Wave 3 V3) builds hero assets headless with the Blender CLI under a MemoryMax=20G scope, stored in `sketches/core-loop/assets/` with a recipe script per asset.
- Blender 5.2.2 LTS CLI is installed. Author and export glTF headless.
- Add a Blender MCP only after reviewing its source.
- Run every Blender job in a memory-capped systemd scope; a runaway CAD job crashed the whole desktop app on 2026-09-26.
- Research the current tools first, because they change fast.

Related: [[scrapkeep-design-principles]].
