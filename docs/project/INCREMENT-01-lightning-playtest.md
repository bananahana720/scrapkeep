# Increment 01: lightning caster playtest

Status: approved by Andrew for implementation in this conversation on 5 September 2026, Phoenix time. The explicit request was "PLEASE IMPLEMENT THIS PLAN" followed by the complete agreed plan. Implementation and verification are in progress. No remote publication is authorized.

## Goal

Make the orchard a readable, responsive third-person lightning caster encounter with double jumping, enemy rebounds, three dense waves, accurate attack previews, and a small usable equipment system.

## Requirements

R01-R04, R07-R10 and R15 are advanced by this increment. R05 preserves the original yard. R06 remains solo first. R11 remains a later full expedition; this increment uses one arena. R12 keeps run power temporary. R14 retains the installed free/local stack.

Andrew's first orchard playtest found decent movement but insufficient bounce, impact, and jumping; insufficient enemy volume; and an eye-straining, scattered interface. He wants automatic mouse look, right-mouse focused third-person aim, projectile/area previews, wave encounters, and a toggleable management dashboard. No playtest duration or measured performance was supplied.

Decisions made in conversation:

- Growth should feel powerful and playful. Do not add routine steering penalties or required scrap shedding.
- Rare optional items may replace core movement and attacks. Explain the replacement before acquisition.
- Shared modifiers affect compatible ball, device, and companion actions automatically.
- Exceptional builds may dominate ordinary encounters.
- Acquired parts can be reconfigured between fights. Unchosen rewards remain unacquired.
- One main modular companion is the foundation; item-created temporary helpers remain possible later.
- MMORPG describes combat and character systems. Solo expeditions remain the structure; co-op comes later.
- Primary fire, two combat abilities, mobility, and an ultimate form the compact hero kit.
- Double jump is baseline. Descending onto a small enemy damages it and produces a controlled rebound.
- Lightning anchors the first playtest. Hold an ability key to preview; release to cast.
- Include Ground Loop, Echo, and the existing priming companion in this increment.

## Exclusions

No full expedition, other class kits, permanent progression, multiplayer, friend invitations, full companion assembly catalogue, new engine, dependency upgrades, paid assets, remote publication, or deployment. The old mass-and-deflect experiment is superseded as the next increment. Final pilot names/species remain unruled; reuse the existing pilot with lightning equipment.

## Ownership

| Lane | Writable files |
| --- | --- |
| Simulation | src/orchard/simulation.js, tests/orchard.test.js |
| Presentation | src/orchard/scene.js, src/orchard/models.js, tests/orchard-renderer.test.js, tests/orchard-models.mjs |
| Input and UI | src/orchard/main.js, src/orchard/styles.css, orchard.html, tests/orchard-browser-runner.js |
| Coordinator | Documentation, integration corrections, verification artifacts and scripts; other files only when required by this scope |

Writers use separate worktrees. Admission is serial. All three lanes are required before browser acceptance. A lane-local syntax or unit result is not integrated acceptance.

## Acceptance

1. Real input: mouse look, WASD, RMB focused aim, held LMB repeat fire; hold/release Q strike and E conductor, Shift burst, Space double jump, R ultimate, Ctrl brake, I dashboard, Escape cancel/close/pause.
2. Simulation and browser: buffered jumps, air control, ground landing, one damage event per descending enemy contact, rebound restoring one air jump, and no queued action released after menu use. Side contact is a physical bump; deliberate rams still damage.
3. Geometry tests and visual inspection: preview and committed attack use the same 3D origin, path, target and area. Terrain, enemy height and obstacles block attacks correctly. Low enemy attacks can be jumped; tall attacks remain dangerous.
4. Simulation: waves contain 8 Snipcarts + 2 Spreadlegs; 14 + 4; 20 + 4 + Pruner. Admit groups with at most 14 live workers plus the boss. Telegraph safe entry locations. At most two worker windups alongside the boss. Clear all enemies to end each wave and all of wave three to win.
5. Browser: intermissions offer Ground Loop versus two Brace parts, then Echo versus two Shear parts. Require a reward choice and an explicit continue. Acquired items toggle only at intermission. Acquiring the first Shear equips the existing priming companion automatically; it can be disabled/re-enabled at intermission.
6. Combination tests: Ground Loop chains from body impacts; Echo repeats eligible player/device/companion attacks once at 50% strength after 0.22 seconds. No recursive echo. Disabling a modifier restores the base behavior. Baseline kit can win without special items.
7. UI inspection: stable, high-contrast reticle, health and ability bar; numeric cooldowns; concise wave/objective; selective enemy status and off-screen warnings. Dashboard has Character, Equipment, Companion, Map, Settings. Use >=16px explanatory text and >=14px secondary text at default scale. Settings expose sensitivity, sound, UI scale, impact shake. No unavailable social navigation.
8. Measured browser work: inspect at 1280x720 and 1920x1080; run 60 seconds at the active cap with both items, conductors and companion; save frame times and errors for this machine. Andrew's next playtest remains the enjoyment/readability acceptance.

## Gate

Run npm run verify and updated orchard DOM-input, fixture and input-expedition checks. Exercise actual pointer capture separately. Verify start, every ability, dashboard navigation, rewards/equipment, victory/loss/restart and resume with no accidental casts. Preserve original yard verification. Disposable evidence goes under artifacts/local/lightning/.

## Closeout

Update the requirements, backlog, decision register and decision trail; update the desk status; supersede the first-build interface contract with the current contract below without rewriting its historical evidence. Amend ADR 0002/0003 and add input/lifecycle decision details if needed. Record the final admitted SHA and executed evidence. No persistent memory/task/reminder is created by these records.

## Integration contract

The deterministic simulation remains DOM/Three-free, 120 Hz, Y-up. Models and rendering consume its state and events. Keep existing exports OrchardGame, groundHeight, ARENA, ENEMY_CONFIG, toolSegments, and add LIGHTNING_CONFIG and ITEM_CONFIG for UI data. Bounds and ground ramp remain those of the first proof.

### Simulation API

- update(dt, input): input has normalized world x/z, aim {origin:{x,y,z}, direction:{x,y,z}}, held fire/strike/conductor/dash/jump/ultimate/brake, and cancel. Action edges and release casts belong to the simulation. Retain aimYaw as a deterministic fallback for tests, not as the production aiming interface.
- Lifecycle methods reset/start/pause/resume/snapshot/drainEvents remain. mode adds intermission. Pausing remembers whether to resume playing or intermission. cancelActions() clears pending actions and targeting; callers also clear held UI state.
- previewAttack(kind, aim) is read-only and returns an attack descriptor. kind is bolt, strike or conductor. Both automatic targeting updates and actual casts use this method. game.targeting exposes the current descriptor; game.preparedAbility is null, strike or conductor.
- Descriptor shape: {kind, valid, origin:{x,y,z}, point:{x,y,z}, segments:[{from:{x,y,z},to:{x,y,z}}], radius, targetIds:[], blocked}. Camera aim selects a world point; weapon-origin geometry is authoritative and cannot shoot through intervening terrain. Ground casts require valid in-bounds terrain and weapon line of sight. Non-gameplay scenery outside bounds is not cover.
- player retains x/y/z/vx/vz/radius/yaw/hp/maxHp/scrap/shear/brace/dashCooldown/dashTime/hurtTime/shotCooldown. Add vy, grounded, airJumps, landingImpact, strikeCooldown, conductorCooldown, ultimateCharge (0..100), ultimateTime. Keep charge at zero until old presentation callers migrate; then it may be removed.
- wave: {index:1..3,total:3,remaining,queued,active,cleared,rewardChosen}. rewards is an array of {id,name,description}. chooseReward(id) returns boolean and applies once. continueWave() returns boolean and requires chosen reward and intermission.
- inventory: {acquired:[],equipped:[]}, IDs ground-loop and echo. setItemEnabled(id,enabled) returns boolean; only intermission permits changes. setCompanionEnabled(enabled) follows the same rule. companion retains existing state plus enabled. conductors: [{id,x,y,z,cooldown,flash}]. Two maximum; placing a third replaces the oldest. No scrap cost; clear conductors between waves.
- Enemy records retain their old pose/combat fields and add bodyHeight. Existing hazards retain segments/previewSegments and add yMin/yMax (absolute world limits), plus jumpable. These ranges must follow visible tool heights, with renderer tests protecting their agreement. Offcuts also use height-aware collision.
- Event type attack carries {attack:descriptor,source:player|conductor|companion,echo:boolean,amount}. Old hit/hurt/ram/collect/phase/companion/land/bounce/wave/spawn/win/lose events may carry text and coordinates for feedback. Echo captures the original eligible action and cannot enqueue another echo. snapshot() includes new state and remains detached/JSON-friendly.
- LIGHTNING_CONFIG contains bolt {damage,interval,range,chainRange,chainTargets}, strike {damage,radius,range,cooldown}, conductor {damage,radius,range,cooldown,interval,max}, ultimate {duration}, movement {jumpSpeed,airJumpSpeed,gravity}. Initial tuning belongs in the simulation and must stay visible through exported data, not copied UI literals. ITEM_CONFIG maps IDs to {id,name,description}.
- Primary is a quick aimed bolt with chaining, Q a circular strike, E autonomous connected conductors, Shift burst, R eight seconds of greater chain reach and faster conductors. Charge comes from actual multi-target lightning hits, not idle time; do not accumulate charge while the ultimate is active.

### Rendering API

- Preserve OrchardScene constructor, resize/orbit/resetCamera/update/event/clear/screenPoint as currently used. Add aimRay() -> {origin,direction} using the current camera center ray and setView({aiming,sensitivity,impactShake}). orbit consumes configured sensitivity. Pitch must support aiming upward and downward, unlike the old fixed-height targeting.
- The UI uses world.aimRay() as simulation input; rendering displays game.targeting and attack events exactly. Aim preview is drawn from weapon origin. Ground shapes are depth-aware and use contrasting outlines. RMB changes camera framing smoothly while preserving the intended target.
- Hero visuals follow actual y. Decorative landing compression and wobble cannot alter collision geometry or rotate the camera. Add lightweight lightning attachments and conductor models. Pool or dispose per-effect resources, including wave restarts.

### UI and QA

- Replace the old HUD/menu markup and styles. Prefer native dialog for pause/dashboard focus behavior, with explicit cancel handling and focus restoration. I toggles dashboard; Tab remains keyboard navigation inside menus. Escape cancels prepared casts before pausing. Pointer capture denial is visible and recoverable; a recapture click never fires.
- Update orchard.html controls description and existing QA runner. QA controls remain separate from normal play. Keep fixture, DOM-input and input-expedition results distinct. Add a labeled 60-second stress action with bounded active population, both modifiers, two conductors and companion; record frame-time samples and renderer counters while rendering normally.
- Settings are local preferences with validated defaults. They do not persist run power. Dashboard map renders current arena, player, enemies and pickups. Stats derive from LIGHTNING_CONFIG plus equipped effects. Reward UI offers the two actual choices, and continued waves require explicit user input.
- Keyboard/mouse is the live acceptance focus. Update controller mappings coherently (A jump, B burst, RT primary, LT focus, LB Q, RB E, Y ultimate, View dashboard, Start pause); do not claim hardware validation without a physical test. Unsupported touch can show a clear keyboard/mouse requirement for this playtest rather than broken controls.

## Execution checklist

- [x] Frame: approved scope, source inspection, baseline verification and ownership contract.
- [x] Fan out: three isolated Astra writers.
- [ ] Aggregate: serial admission, integrated verification, browser exercise and independent review.
- [ ] Report: evidence, remaining human playtest and one launch link.
