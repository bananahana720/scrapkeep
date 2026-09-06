# Scrapkeep build plan

The central test: rolling into scenery must visibly attach a working outward-facing turret, immediately increasing the ball's ability to defend a base against enemies following the maze.

## Definition of done

- Browser game with an actual orthographic 3D scene, keyboard and pointer controls, physically rolling ball, collectible scenery mounted as radial weapons, enemy path following, base damage and escalating waves.
- Three classes with distinct passives and active abilities; XP, upgrade choices and persistent best score based primarily on waves survived.
- Start, pause, resume, reset, instant restart and game-over flows.
- Feedback through particles, trails, recoil, audio, camera shake and readable HUD.
- Generated art concepts saved alongside prompts; compare them with actual browser captures and iterate on palette, geometry, composition and lighting.
- Deterministic simulation checks and real browser interaction checks. Measure frame intervals and render time against a 60fps target; distinguish local results from a guarantee on other hardware.

## Sequence

1. Generate a salvage-yard diorama art target. Scaffold the simulation and browser verification.
2. Build and check the collection/combat/wave loop.
3. Implement the 3D world, animation and polished interface.
4. Exercise full game flows; capture and compare art; tune readability, balance and frame cost.
5. Independent read-only review, repair material findings, save results and open the game.

No existing application or usable git repository was present at the start. This build creates a Vite/Three.js application in the requested folder. Local-only delivery.
