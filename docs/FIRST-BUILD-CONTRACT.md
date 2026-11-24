# First orchard build contract

Historical contract for the completed first proof. Increment 01 (`docs/project/INCREMENT-01-lightning-playtest.md`, archived in git history) owned the replacement interfaces, vertical movement, waves and caster controls. The original verification receipts retain their original scope.

Goal authorized 5 September 2026. New playable entry `/orchard.html`, preserving the original `/` demo. Three.js 0.180 and existing Vite/Node tools; no engine migration or external assets.

## Integration conventions
- World is Y-up. Forward at yaw 0 is -Z. Direction is (sin(yaw), -cos(yaw)); model local forward is -Z.
- Arena center play limits x [-19,19], z [-37,27]. Player begins (0,21). Orchard trees/props sit outside these bounds.
- Ground height: 0 for z >= -14, rises linearly to 2.5 from z -14 to -23, then 2.5. Export `groundHeight(x,z)` from simulation; renderer uses it.
- Player movement is camera-relative acceleration with braking, a low cooldown forward ram burst, bounded growth radius 1 to 1.65, ground-following Y and visual wobble independent of collision envelope. Spatial evasion, no mandatory parry.
- Introduction places one Snipcart near (-4,8), one Spreadleg near (6,-4), an optional worker pair near (-8,-12)/(8,-14), and a single Grand Pruner arm near (0,-29). Enemies can activate by proximity; the player can approach the boss without killing every worker. Win when the arm is dismantled. Defeat on player HP zero; restart resets.
- Source/pose intent: docs/ORCHARD-ENCOUNTER-STUDY.md. First build may simplify full boss greenhouse to a backdrop plus one moving arm. New module exports below are the agreement between writers.

## Simulation module: src/orchard/simulation.js
Export `OrchardGame`, `groundHeight(x,z)`, `ARENA`, `ENEMY_CONFIG`. No DOM or Three dependency.
Class:
- `new OrchardGame({seed=42}={})`, `reset()`, `start()`, `pause()`, `resume()`
- `update(dt,input={})`; input fields `x,z` normalized world movement, `aimYaw`, `fire` held (charge shot releases on falling edge), `dash` edge, `brake` held, `deploy` edge.
- Public `mode`: ready/playing/paused/won/lost; `time`; `player`: x,y,z,vx,vz,radius,yaw,hp,maxHp,dashCooldown,dashTime,charge,scrap,shear,brace; numeric shear/brace counts.
- `enemies[]`: id,kind (snipcart/spreadleg/pruner),x,y,z,yaw,radius,hp,maxHp,state (idle/approach/windup/active/recovery/dead),phase 0..1 in current state,active boolean indicating awake,weakX,weakZ,hitFlash,attackId. State is authoritative for poses.
- `pickups[]`: id,x,y,z,kind (scrap/shear/brace/heart),collected boolean.
- `hazards[]`: id,kind (cut/spread/sweep/offcut),x,z,yaw,range,width,phase,state (windup/active). `segments` gives damaging capsules {x1,z1,x2,z2,radius}; `previewSegments` samples the complete committed stroke during preparation. Both use world XZ, with the ground-height function for display. An offcut supplies bodyRadius and moves independently after release. Renderer uses these exact data.
- `companion`: null or {x,y,z,yaw,active,cooldown,flash}; one optional deployable shearing buddy after a Shear Linkage is collected, useful autonomous attacks/priming, ordinary counters remain sufficient without it.
- `stats`: shots,hits,counters,collected,damageTaken; add fields if useful.
- `drainEvents()` clears and returns events with type (shoot/hit/hurt/ram/collect/phase/deploy/companion/win/lose), x,y,z, optional targetX,targetY,targetZ,kind,amount,text. Renderer/audio consumes them once.
- `snapshot()` returns JSON-friendly state for read-only QA. QA can use the game directly in automated fixtures; production UI does not expose cheat controls.
- Aim: charge-release pulse with useful ordinary damage and bonus at exposed housings. Direct baseline attacks and ram damage work on all enemies; no full immunity or mandatory loot. Enemy damaging actions use committed geometry once per attack plus player hit recovery. Mere body contact bumps, not continuous damage.
- Shear part increases ram impact and unlocks one deployable support; Brace part improves burst recovery/handling or protection with a visible attachment. At least two collected mechanisms produce demonstrated gameplay effects, and growth is bounded.
- Sim tests owned by simulation worker in tests/orchard.test.js. The proposed human playtest duration is 2–4 minutes; this remains unmeasured. A precise DOM-input script completed all five enemies in 37.05 simulation seconds without damage, exposing ranged pressure and pacing as tuning work. This proof does not implement a full 30–45 minute run.

## Model module: src/orchard/models.js
Import only Three.js and its bundled addons if needed. Export:
- `createHero()` → THREE.Group. `updateHero(group,player,dt,time)` sets position, articulated roll, scale from radius, attachments from shear/brace, stabilized enclosed hamster cockpit. Hero body is accumulated lumpy salvage, not a walking humanoid.
- `createEnemy(kind)` → THREE.Group. `updateEnemy(group,enemy,time)` sets world position/rotation and poses from state/phase. Shared fork/circular pivot/cream brace; shears horizontal and closing, Spreadleg only two outward-sweeping legs, giant Pruner repeats Snipcart grammar.
- `createPickup(kind)` → THREE.Group, roughly 0.5 units. Caller positions/spins.
- `createCompanion()` → THREE.Group; caller positions and rotates, optional userData.shears for motion.
- `createGreenhouse()` → THREE.Group, static backdrop approx 22 wide × 13 high × 12 deep, caller places at (0,2.5,-39). Nursery detail and healthy orchard theme.
- All models should be low-poly but finished with ivory/sage enamel, warm ochre repairs, black rubber, copper, dark steel. Use efficient shared geometry/materials and consolidate static subparts where practical. Aim hero <70 draw calls, worker <35, arm <65, greenhouse <80; don't trade readability for tiny greebles.
- Groups own dynamic materials if update changes emissive/opacity; don't accidentally flash all enemies. No scene-wide lights, camera, animation loop or global DOM.

## Parent scope
src/orchard/main.js, scene.js, styles.css, orchard.html, Vite multipage config, navigation link, audio/input integration, environment, HUD, build/browser tests, docs/receipts. Parent serializes worker file admission.

## Verification
Node tests must cover attack commitment vs movement after windup, one-hit-per-stroke, recovery counter reward, generic damage on armored phases, max-growth clear routes, pause/restart, pickup effects, companion, and victory/loss. Browser checks must operate real input and inspect rendered state/captures; fixture checks are labeled. No scripted victory is called a human playthrough.
