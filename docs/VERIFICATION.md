# Scrapkeep verification

Completed locally on 5 September 2026 UTC.

## Result

The game builds and runs as an actual 3D browser game. The production build was also opened at http://127.0.0.1:4173 and smoke-tested for start, collection, wave launch and pause. The simulation suite passes 14 checks. A real-browser replay passes 16 control and game-flow checks. The source, generated concepts, screenshots and repeatable checks are saved in this project.

## Browser and performance

Tested in the Codex Chromium browser at 1440 × 900, device pixel ratio 1. WebGL identified an NVIDIA GeForce RTX 4080 through ANGLE / OpenGL ES 3.2.

A sustained stress fixture keeps 45 durable enemies and 24 turrets in the scene, automatically moving the ball to keep weapons charged. It uses the ordinary simulation, rendering and input handlers. The inflated enemy/core health is explicitly a benchmark fixture, not an achieved run.

| Measurement                                    | Result                          |
| ---------------------------------------------- | ------------------------------- |
| Frame samples                                  | 1,200, approximately 20 seconds |
| Median frame interval                          | 16.7 ms, approximately 60 FPS   |
| 95th-percentile frame interval                 | 16.8 ms                         |
| Median CPU update / render submission          | 1.8 ms                          |
| 95th-percentile CPU update / render submission | 2.3 ms                          |
| Draw calls in captured frame                   | 784                             |
| Triangles in captured frame                    | 1,514,298                         |

Evidence: `artifacts/performance-stress-final.json` and `artifacts/stress-scene-final.png`. CPU timing covers update, event processing and the renderer submission call. It is not a GPU timer query. Draw calls and triangles now count all color, shadow, normal and postprocessing passes; they are not unique visible geometry counts. This establishes the 60 FPS target on the tested setup, not on every browser or device.

Desktop gameplay also displayed 60 FPS during normal collection and wave defense. Portrait 390 × 844 and landscape 844 × 390 layouts were visually checked. Touch joystick release ownership was checked in a separate handler probe; physical phone multi-touch was not tested.

## Gameplay checks

`artifacts/simulation-tests.txt` records the 14 passing Node tests:

- Scenery absorption produces a weapon, growth, score and collection feedback.
- Outward turrets kill actual marching enemies and award XP.
- Pause freezes simulation; restart clears the run and keeps the class.
- Enemies reaching the core deal damage; fatal damage reaches game over.
- Surviving a wave grants the score and upgrade choices; choosing resumes the next wave.
- Diagonal movement is normalized; dashes do not pass through maze walls.
- Classes have different active abilities and cooldowns.
- Valid entrance targets with negative priority values still receive shots.
- Turret count and scenery remain bounded; surplus scrap strengthens mounted turrets.
- Rolling charges weapons, stopping discharges them, and pushing a wall does not build charge.
- The wave-three flank entrance joins the intended path corner; bosses still take the full maze.

`artifacts/browser-tests.json` records all 16 passing browser checks. It exercises class selection, held movement keys, dash, Engineer overclock, pause, help preserving pause, resume, instant restart, Scavenger collection, real combat, breaches, game over, restart, wave score, keyboard upgrades and return to the title screen. Late-wave and defeat checks use explicit fixtures to reach those conditions, then the normal update and interface code resolve them.

The regression replay initially assumed a fixed number of objects inside the Scavenger ability. When the pickup radius was tuned, that assertion failed. It was replaced with the actual invariant: the ability increases collection and every collected object adds a mounted turret below the cap. The final replay passes.

## Balance

`tests/balance.mjs` runs one reproducible seed with abilities used on cooldown and the first offered upgrade selected. A stationary policy is compared with a patrol policy that follows the actual maze waypoints and uses dash between corners.

| Class     | Stationary outcome     | Patrol outcome             |
| --------- | ---------------------- | -------------------------- |
| Scavenger | Defeated during wave 5 | 8 waves survived, core 100 |
| Engineer  | Defeated during wave 4 | 8 waves survived, core 92  |
| Warden    | Defeated during wave 6 | 8 waves survived, core 101 |

Evidence: `artifacts/balance.json`. This demonstrates a useful difference between parking and collecting while moving. It is a deterministic balance probe, not a claim about human difficulty or long-term balance. Some shots can reach across low walls; turrets check range and outward arc, not lane membership.

## Visual evidence

- `public/art/01-yard-concept.png`: generated overview target.
- `public/art/02-arsenal-concept.png`: generated rolling-arsenal target.
- `artifacts/01-title-screen.png`: finished desktop title and class selection.
- `artifacts/02-gameplay.png`: normal gameplay, without benchmark fixtures.
- `artifacts/03-pause.png`: pause interface.
- `artifacts/04-mobile-title.png`: portrait title screen.
- `artifacts/05-mobile-gameplay.png`: portrait gameplay and touch controls.
- `artifacts/06-landscape-title.png`: compact landscape title.

The real-time scene reproduces the concept palette, low-poly machinery, radial turret ball, orange-edged maze, tiered crystal reactor, conifers and exposed stone/pipes along the island. The second visual pass adds GTAO contact shading, softer filtered shadows, bloom, and four-sample antialiasing. The concepts retain finer authored surface irregularity. This is an iterated art-direction match, not pixel-level parity.

The final concept comparison overview and close view are `artifacts/visual-iterations/04-final-overview.png` and `05-final-arsenal.png`. These deliberately stage the real game assets for comparison. Earlier passes and the original screenshot remain alongside them.

## Independent review

Reviewed by gpt-6-astra at high reasoning effort. Final verdict: PASS+NOTES, with no blocking bug in the reviewed changes.

The review reproduced and helped repair the initial target-priority threshold, pause/help restoration, restart score persistence and multi-touch release ownership. The reviewer reran the 14 simulation checks and independently reproduced all six balance-probe results. It inspected the earlier saved browser evidence but did not independently operate the browser or measure GPU performance.

The remaining notes were about evidence precision: cite actual performance artifacts, distinguish policy simulation from human play, and describe shorter weapon ranges without claiming shots are confined to a lane. This report applies those corrections.


### Second visual pass recheck

The larger ball exposed two regressions during independent review. The collision radius had allowed masonry to pass through the visible sphere; the final version uses 98 percent of the visible radius and gives the raised courts enough clearance. The reviewer repeated an actual geometry probe at the reported failure position and found zero wall vertices inside the sphere, down from 372. A new path-clearance test covers the mature ball along the route.

Elevated spherical mounts also exposed a horizontal-only projectile arrival check. The final projectiles home in three dimensions to the enemy center, and the renderer aligns their tracers to that trajectory. A dedicated descent test and the reviewer's original reproduction now pass. The final bounded recheck found no remaining issue; the reviewer independently reproduced all 14 tests and all six saved balance results.

The browser movement assertion projects both positions through the same camera, so the title-to-game camera transition cannot cancel the measured input displacement. The final 16-check replay passes after this change.
