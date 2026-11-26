# World-one build systems

Design proposal, 2026-09-28. Scope ends at Brindle. Static inspection at `f86f24a75cf9357f12b98d2de61548e93d5e1c65`; no gameplay or fun claims have been verified. Code paths below are relative to `sketches/core-loop/`. Numbers are first-playtest settings, not accepted balance.

## Purpose and boundary

The tree chooses how you drive a pilot. Parts give that driving style opportunities and complications. Scrap supplies size, temporary armour and force; cogs buy choice. A tree path must be worth playing with ordinary loot and without a hot-wired part. This follows the useful-starting-kit test in `BIBLE.md:50–69` and the separation recommended in `design-v3/research/PURPOSE-AUDIT-1.md` (archived in git history), entries 6, 13, 14 and 27.

The latest rulings govern this sketch: `design-v3/ROADMAP.md:5–11,143–191`. Keep armour over hull, slow rolling wear, class hysteresis, recoverable spills and size-neutral handling. The audit's no-wallet recommendation predates the cog ruling and is superseded. No currency objection here; prices and drop cadence remain the economy design's responsibility.

World one reaches **depth 1, two nodes, and depth 2, four nodes, per pilot**. Pick once at class selection and once after Warden I, before entering stage 2. Each run owns one connected two-node path; all six offered nodes per pilot are specified below. Stages 2 and 3 and Brindle develop it through parts and execution. They grant no further tree depth. A skipped bay queues the second pick for the next calm opportunity before stage 2; it never interrupts airborne movement.

This deliberately changes the sketch's four-pick schedule: `src/core/upgrade_tree.gd:12–29,230–268` supports 2/4/8/16 nodes, while `src/world/world.gd:651–658` opens later picks even if the bay is skipped. Gate both offers and checkpoint allowance at two under the proposed flag, including repeated bay entry and retries; merely hiding the deeper UI is insufficient. The fixed 30-node validator needs a world-one profile too, `src/core/upgrade_tree.gd:139–150`. Do not implement or rebalance depths 3 and 4 for this milestone.

The Bible's four separate slot trees are the broader product design, `BIBLE.md:528–548`. This proposal follows the requested existing one-tree-per-pilot sketch, not a silent rewrite of that product contract. Consolidation must retain that distinction. No world-two content, endpoint recipes, permanent unlocks or new respec system are proposed.

## Mass becomes the pilot's action

Both depth-1 choices grant their pilot's mass verb. No special drop or branch is required to enjoy being large. Sampling mass does not spend it; wear and damage remain its costs. Define `q = clamp(mass / 990, 0, 1)` for the first trial. The 990 is a proposed saturation point, corresponding to raw heft IV under the current armour formula and thresholds, `src/core/run_state.gd:13–15,161–165`. It is not a new resource, UI meter or growth cap.

| Pilot | World-one verb and first trial | Existing implementation and required delta |
| --- | --- | --- |
| Sable | Bank size in the rope and wall: slingshot, vault and Coil Hook release add up to 8 m/s with q. Grant the mass bonus at most once per second; preserve incoming speed. | Vault currently uses incoming speed × gain with a 45 m/s cap, `src/movement/augments.gd:109–147`; slingshot uses banked speed and gauge, `:383–451`; Coil Hook adds its fixed fling, `src/movement/player_ball.gd:459–466`. Mass sampling and shared bonus budget are new. |
| Rivet | Carry weight through sprint rams and ground smashes. Retain the existing heft-scaled contact punch; the tree changes whether you strafe, punch through or chain repositioning. | Contact punch already multiplies by heft and the sprint knob, `src/combat/combat.gd:583–602`. Sprint raises cruise while held, `src/movement/augments.gd:154–181`; skid converts descent to forward motion without a plant, `:342–355`. Do not multiply mass into damage again. |
| Kest | Pack size into payload geometry: thrown sticky and demo-slam charge radii × `1 + 0.25q`, committed at throw or slam. Blast damage, blink distance and glide physics do not change with size. | Throws and slam charges construct their radius here, `src/combat/combat.gd:1300–1322,1383–1398`; those calculations currently lack mass scaling. Blink preserves planar speed and catches descent, `src/movement/augments.gd:184–212`; glide trades descent into forward travel, `:271–283`. |

Sable's proposed bonus ceiling is 45 m/s for generated launch speed, not a velocity clamp: if incoming speed exceeds it, retain that speed and add nothing. Resolve Pylon Capacitor, Long Lane and Spring Hull with the launch once, rather than capping then adding again. Their current modifiers are `src/build/parts.gd:82–84` and `src/build/items.gd:52–57`; item surges already decline to add above their cap, `src/build/item_effects.gd:477–485`. No mass-dependent steering, friction, collider, gravity or air-control change belongs in these verbs.

## Reachable kit nodes

Status: **E** = existing node/effect retained; **E+** = existing node with the explicitly new addition stated; **P+** = existing deeper effect moved into world one and extended. Every depth-1 row also gains the mass contract above. A node's short effect below is its card copy; following text fixes its behavior. Paths are exclusive, with two children per parent.

### Sable

| ID / tier / parent | Node and one-line effect | Status and source |
| --- | --- | --- |
| S1 / 1 / root | Cannonball: **Vault kicks zap what's near. A heavier ball launches farther.** Keep the small vault discharge. | E+; `s_cannonball`, `src/core/trees/sable.gd:9–10`; mass launch new. |
| S2 / 1 / root | Beachhead: **Mount walls from twice as far. A heavier ball launches farther.** Keep double mount reach; mount, take a firing opportunity, then launch toward the next collection line. | E+; `s_beachhead`, `src/core/trees/sable.gd:11–12`; mass launch new. |
| S3 / 2 / S1 | Coil Hook: **Release the rope into a cannonball.** Keep the +10 m/s fling, adding the shared mass bonus only once under the launch ceiling. | E+; `s_coil_hook`, `src/core/trees/sable.gd:14–15`; cap composition new. |
| S4 / 2 / S1 | Face Runner: **Vaults restore jumps. Heavy fins steer harder.** Each valid vault restores one air jump; same-face lock remains 1.5 s. For 2 s after a vault, Riveted Shell's air-control penalty flips to +25%. | P+; existing `s_face_runner` restores air and sets a 1 s lock at depth 3, `src/core/trees/sable.gd:29–30`; replaces world-one Live Wire at `:16–17`. Placement, lock choice and inversion new. |
| S5 / 2 / S2 | Arc Nest: **Mounted bolts chain to another target.** Keep one additional turret chain jump; launch to find the next useful firing face. | E; `s_arc_nest`, `src/core/trees/sable.gd:18–19`. |
| S6 / 2 / S2 | Bulwark: **Mounted, shrug off crowd control.** Keep mounted CC immunity; it grants neither damage immunity nor a stationary Warden bypass. | E; `s_bulwark`, `src/core/trees/sable.gd:20–21`. |

Identities: **wall cannonball**, S1→S3, turns an approach into a huge release; **ninja platformer**, S1→S4, links walls and air jumps; **mobile siege**, S2→S5 or S6, banks a fast arrival, fights from a chosen face and launches again. No route depends on extra loot. Beachhead fails if waiting on one face is better than moving between opportunities; do not solve that by imposing a new mounting timer.

### Rivet

| ID / tier / parent | Node and one-line effect | Status and source |
| --- | --- | --- |
| R1 / 1 / root | Gunline: **Your laser fires twin bolts.** Keep two bolts at 0.6 damage each and at least 3° spread. | E; `r_gunline`, `src/core/trees/rivet.gd:7–9`; retain mass contact verb. |
| R2 / 1 / root | Juggernaut: **Starting a sprint blasts enemies back.** Keep the half-scale start blast and its 1 s proc gap. | E; `r_juggernaut`, `src/core/trees/rivet.gd:10–11`; retain mass contact verb. |
| R3 / 2 / R1 | Tracer Rounds: **Running fire jumps to a neighbour.** Keep one 6 m chain and 0.9 damage multiplier. | E; `r_tracer`, `src/core/trees/rivet.gd:13–15`. |
| R4 / 2 / R1 | Run and Gun: **Sustain fire. Worn scrap sparks behind you.** Keep half sprint drain while firing; each actual unit of rolling wear leaves one short arc patch, including Spark Tread's extra wear. | E+; drain exists at `src/core/trees/rivet.gd:16–17`; wear trail is new. |
| R5 / 2 / R2 | Ram Fins: **Sprint through bodies instead of rebounding.** Keep sprint punch 1.5 and no enemy rebound; walls still collide normally. | E; `r_ram_fins`, `src/core/trees/rivet.gd:18–19`. |
| R6 / 2 / R2 | Second Wind: **Bank two sprints. Heavy fins open during sprint.** Keep one extra sprint charge; while sprinting, cancel Riveted Shell's air-control penalty. | E+; charge exists at `src/core/trees/rivet.gd:20–21`; cancellation new. |

Identities: **running gunner**, R1→R3 or R4, uses broad passes and keeps pressure while repositioning; **bowling bruiser**, R2→R5, picks an entry through a pack; **hit-and-run bruiser**, R2→R6, spends separate charges on entry and escape. Run and Gun's new inversion also works with ordinary wear, so it is not a hot-wired-item tax.

Run and Gun's trail starts with 14 damage per patch, 1 m radius, 2 s life, at most six live patches, and at most one hit per enemy per 0.5 s across all patches. Place only on traversed ground. Its strikes cannot proc items, spawn patches or electrify water. Use a short visible contact arc, not a carpet of opaque particles. Wear remains quiet; one soft keyed sputter per patch is enough.

### Kest

| ID / tier / parent | Node and one-line effect | Status and source |
| --- | --- | --- |
| K1 / 1 / root | Trapper: **Charges wait longer. Five can wait at once.** Keep 2.5 s fuses and five live charges. | E+; `k_trapper`, `src/core/trees/kest.gd:7–8`; mass radius new. |
| K2 / 1 / root | Ghost: **Cloaked, enemies spot you only up close.** Keep cloaked sight factor 0.3. | E+; `k_ghost`, `src/core/trees/kest.gd:9–10`; mass radius new. |
| K3 / 2 / K1 | Tripwire: **Charges spring when enemies approach.** Keep the 2 m contact trigger, distinct from mass-scaled blast radius. | E; `k_tripwire`, `src/core/trees/kest.gd:12–13`. |
| K4 / 2 / K1 | Demo Expert: **Smash scatters five payloads.** Keep five demo charges; mass widens each committed blast, never the trigger radius or scatter count. | E; `k_demo_expert`, `src/core/trees/kest.gd:14–15`; inherits new mass verb. |
| K5 / 2 / K2 | Smoke Trail: **Glide cloaked. Heavy fins steer harder.** Keep cloak while gliding; Riveted Shell's air-control penalty becomes +25% during a glide. | E+; `k_smoke_trail`, `src/core/trees/kest.gd:16–17`; inversion new. |
| K6 / 2 / K2 | Ambush: **Throw payloads without breaking cloak.** Keep throwing from cloak; this path cannot also take Smoke Trail. | E; `k_ambush`, `src/core/trees/kest.gd:18–19`. |

Identities: **route trapper**, K1→K3, lays a moving enemy's future path; **dive bomber**, K1→K4, commits to a landing then blinks out; **gliding infiltrator**, K2→K5, approaches from above; **ambusher**, K2→K6, chooses a short concealed firing line. Preserve low-mass usefulness by making mass improve coverage, not permission to damage plating.

## Two hot-wired parts

Both are NEW designs, one copy each, at most one hot-wired part equipped in world one. Replacing it happens only in calm and removes both effects atomically. They use explicit Fit / Recycle choices, never auto-equip on collision. First offer after Warden I; second in a stage-2 calm discovery before the final approach. No extra offer before Brindle. Show both consequences before commitment; the later discovery celebration may still explain the first actual use.

### H1. Riveted Shell

- Upside: twice the armour per scrap. Start at 5 scrap consumed per absorbed HP instead of 10; size and mass-powered attacks still use actual mass. No free mass or hull healing on fitting.
- Downside: air-control acceleration ×0.75 whenever airborne. No change to ground steering, launch direction, jump height, glide lift, speed or collider. This is an explicit equipped-part penalty, never a consequence of growing large.
- Look before choosing: a hinged plate stops a hammer in the looping preview, then catches a crosswind and widens a turn; label **“Double armour. Air steering −25%.”** Actual preview turn and armour values read the resolved build, including a selected inversion.
- Sound before choosing: one deep protective clang answers the hammer, followed by a stiff hinge creak on the wide turn; inversion replaces the creak with a released-spring note. Replay on focus, never a continuous shop alarm.
- Tree inversion: S4 flips the penalty for 2 s after a vault; K5 flips it while gliding; R6 cancels it during sprint. Outside those conditions it returns. No inversion means the full tradeoff remains visible and playable.
- Recycle: provisional payout **two common-part recycle values in cogs**, shown as an exact number supplied by the economy table. No scrap, mass or cores. Use the same payout for a duplicate; resale must remain below discounted acquisition cost.
- Implementation basis: current armour spends `SCRAP_PER_HP = 10` and spills 75%, `src/core/run_state.gd:18–27,290–326`; air acceleration reads `air_control`, `src/movement/ball_rules.gd:74–83`. Both resolved modifiers are new. Apply efficiency inside the one damage order; spill 75% of mass actually removed, not of the unmodified hit.

### H2. Spark Tread

- Upside: while rolling at least half cruise with mass remaining, the first eligible attack after each 3 s recovery deals +75% direct damage. Eligible: Sable's vault discharge or first direct weapon hit within 2 s of a slingshot, Rivet's sprint ram or skid smash, Kest's throw or demo-slam batch. One activation per attack, even against several targets. Check rolling speed at launch for Sable and at smash commitment for airborne smashes; check current speed for a ram or throw. Other weapons are unchanged.
- Downside: doubles ordinary active rolling wear. The bonus switches off at zero mass, but the starting kit still works. No added loss on a hit, no hull drain, and no wear while paused, in the bay or in authored flights/transfers.
- Look before choosing: copper brushes brighten the signature strike while visible scrap flakes away; label **“Big signature hits. Double rolling wear.”** Preview also shows the strike going plain at zero scrap; a tiny brush glow conveys readiness without another meter.
- Sound before choosing: a winding two-note rise resolves into a bright impact; a short dry brush rasp accompanies the visibly lost layer. Threat sounds keep priority; no damage alarm for wear.
- Tree inversion: R4 turns the extra wear into extra damaging ground patches. The cost persists, but now the chase line hurts pursuers. H2 remains useful to the other pilots without this inversion.
- Recycle: provisional payout **three common-part recycle values in cogs**. A high payout makes walking away consequential; it must not buy a repeatable take/recycle profit. Exact price belongs to economy design.
- Implementation basis: wear currently caps at 30 scrap/minute at cruise and removes whole accumulated units without emitting an event, `src/core/run_state.gd:344–364`. H2 doubles that to 60/minute; R4 needs a new committed wear amount. It must never infer wear from mass loss, which also includes damage and theft.

The first-taste **forced skip** is an exclusive reward, not a scripted bad purchase. At the stage-2 offer, present H2 beside one known ordinary part that supports the chosen path, with both choices and the ahead-route preview visible. In the test fixture, S1→S4 enters low on armour and chooses between H2's desired discharge boost and Vault Battery's extra vault, an existing seam-gated item row at `src/build/items.gd:29–31`. Exactly one can be fitted from that offer; the unchosen part recycles once into its stated cogs. Hold/reroll cannot grant the unchosen item from this offer later. Ordinary economy choices elsewhere remain available.

The part is wanted because its burst was demonstrated earlier; it is skipped because the next route rewards another capability or conserving armour. Do not hide H2's zero-mass shutoff. If Andrew always takes H2, or chooses the battery without regretting the lost burst, this fixture has not produced the requested tension. The production offer should be authored by branch, not require a new classifier or secretly manipulate drop odds.

## Interactions and ways this can break

Proposed tags: H1 `mass`; H2 `kinetic, arc`. Tree tags never impersonate held parts. Current named matching requires the exact shown part plus a different held part with the partner tag, `src/build/synergies.gd:100–109`; this prevents “my tree says air” from silently completing a part recipe.

| Interaction | What it adds, and existing-code basis | Falsifiable check |
| --- | --- | --- |
| H1 + Arc Coil | Lightning Rod rewards fresh collection on the bulky route; the exact recipe is Arc Coil + mass, `src/build/synergies.gd:47–51`. | Run a fresh-scrap line and a recovery-spill line: fresh pickups spark, recovery never does; Andrew deliberately chooses a collection pass to attack once. |
| H2 + Double Feed; S3 or R5 | Wrecking Ball adds ram shockwaves, `src/build/synergies.gd:57–61`; H2 supplies kinetic, Double Feed is the required shown part. Sable must actually ram after launch. | Three pack entries: at least two readable shockwaves, no wave from a vault alone or from its own secondary hit; Andrew retries a better entry angle. |
| H2 + Frost Vane or Focus Lens | Thermal Shock supports smash routes; Tesla Pylon supports Sable's temporary firing perches, `src/build/synergies.gd:42–55`. H2 supplies arc for either exact shown part. | Three passes per pairing: Andrew identifies which action caused the effect twice, and a perch never completes the route objective without leaving it. |
| H2 + Cross Split | Shrapnel Bloom adds a kill payoff, `src/build/synergies.gd:62–66`; it works with Kest's area coverage without giving every fragment another mass bonus. | In a dense pack, one player strike causes one bounded generation of bloom; Andrew can point to the initiating payload and wants another attempt. |
| S3 + Pylon Capacitor / Long Lane / Spring Hull | Existing launch and surge modifiers, `src/build/parts.gd:82–84`, `src/build/items.gd:52–57`, support the same wall route. These are mechanical combinations, not newly named synergies. | Ten alternating-wall launches saturate without runaway speed; no launch reduces higher incoming speed. Andrew can still choose a landing line at maximum mass. |
| R4 or R5 + Spiral Wave + Double Feed + H2 | Double Feed supplies Pinwheel's speed tag, `src/build/parts.gd:57–59`; Pinwheel needs Spiral Wave plus speed, `src/build/synergies.gd:72–76`. H2 also completes Wrecking Ball with Double Feed. | Remove Double Feed in the comparison: neither recipe remains active. With it, Andrew reads a hostile wind-up through ring and trail on 4/5 pauses. |

Potential loops and required limits: repeated wall boosts use the shared bonus ceiling and face lock; equipping H1 never refills mass; H2 never amplifies its own secondary strikes; R4 patches have zero proc eligibility. Clamp Kest's mass radius once at creation and reuse it for preview, collision and effects, including after mass is stolen. Do not expand a live bomb when scrap is recovered.

Fresh-kill loot can fuel further attacks; that snowball is desirable while movement earns it. Self-spill farming is not: recovered mass already bypasses wallet and fresh pickup events, `src/core/run_state.gd:329–336`, and must retain that behavior after the cog split. The current wallet still grows with fresh mass and spending only removes the wallet, `:133–140,243–248`; H1/H2 recycle cannot ship on that old path.

K6's retained cloak currently makes every shot in cloak crit, `src/combat/combat.gd:1452–1461`; combining that with H2 is a deliberate burst risk to measure. Do not let item effects imitate player throws, refresh cloak or reset H2 recovery. K5 and K6 stay mutually exclusive. Existing tree proc-cycle checking only follows tree action facts, `src/core/upgrade_tree.gd:199–219`; it does not prove new item/wear chains terminate.

## Play verdicts and smallest build slices

Every row below is a proposed unit, not authorization to code. New master flag `world_one_builds`, default off, plus independently selectable `hotwire_shell` and `hotwire_tread`, allows paired trials. Prototype ordinary wear remains separately selectable. Run H2/R4 only with armour and wear enabled; if wear is rejected, redesign their cost rather than ship a free upside. All paths must pass with zero hot-wired parts.

Use a fixed three-minute route, same seed, pilot, ordinary parts and enemy placements; alternate baseline/candidate order and repeat each three times. Each node must produce its named behavior at least twice and Andrew must prefer its intended route on two of three comparisons, then willingly choose one extra attempt. Failure of either behavior or preference sends that node back. These are proposed falsifiable human gates, not a claim that a score proves fun. Record his words as well as route, hits, mass, damage, activations and reversals.

Ownership abbreviations below expand to exact proposed paths. New files are marked NEW. Serialize units sharing a path. Each unit owns its row's files plus `tests/world_one_<ID>_test.gd` NEW; it gets the accepted formulas above and adds only the named behavior behind the flag. No unit invents a new combat or economy contract.

- **G**: `src/movement/tuning.gd`, `src/core/upgrade_tree.gd`, `src/world/world.gd`, `src/ui/workshop.gd`, `src/ui/tree_pick.gd`. Add flags and two-depth profile; calm delivery, stable parent choices and retry allowance. Keep old behavior with flag off.
- **S**: `src/core/trees/sable.gd`; **R**: `src/core/trees/rivet.gd`; **K**: `src/core/trees/kest.gd`.
- **M**: `src/movement/player_ball.gd`, `src/movement/augment_kit.gd`, `src/movement/augments.gd`. Resolve Sable's mass launch and its identical aim preview.
- **C**: `src/combat/combat.gd`, `src/combat/sticky.gd`. Commit Kest's radius and H2's direct attack origin once; retain existing Rivet mass punch.
- **H**: `src/build/hotwire_rules.gd` NEW, `src/build/build.gd`, `src/core/run_state.gd`. Resolve equipped effects and actual wear once; H rules are a small pure modifier/activation table, not another resource manager. A separate catalogue unit owns `src/build/items.gd`, `src/build/item_effects.gd`, `src/build/parts.gd`; early play fixtures inject the selected prototype effect instead of enabling random loot.
- **V**: `src/ui/hotwire_choice.gd` NEW, `src/build/reward_gates.gd`, `src/build/build.gd`, `src/presentation/audio.gd`, `src/presentation/vfx.gd`. One reusable choice preview and its paired look/sound, Fit/Recycle transaction, first-use cue. Depends on the accepted cog transaction seam; fixture may inject a fixed payout, production may not credit old scrap.

Build G first. Next implement the three mass verbs separately, then one node at a time, then each hot-wired part and its inversions. Presentation follows playable rules: V is two serial units, choice/preview/transaction owning its UI and build files, then cues owning its audio/VFX files. Build owns recomputed tuning modifiers today, `src/build/SEAMS.md:25–27`; all H1 air-control states must survive recompute and removal. A writer using M cannot set a competing permanent tuning mod.

| ID | Smallest slice and files owned | Specific play test in addition to the common gate |
| --- | --- | --- |
| G | Two picks only; G. | Play through Brindle, including bay skips and retries: exactly two picks, no mid-jump pause; Andrew can name the path he chose without needing the deeper tree. |
| Mass-S | Add q and one shared launch bonus budget; M, S, `src/core/upgrade_tree.gd`. | At mass 0/450/990, same input and approach: launches get stronger, steering does not; Andrew prefers the large launch without losing landing control. |
| Mass-R | Expose existing heft contribution in the fixed fixture, no second damage multiplier; R, `tests/world_one_mass_route.gd` NEW. | Same speed and ram/smash at mass 0/450/990: damage rises once, turning stays equal; Andrew chooses a heavier pack-entry route. |
| Mass-K | One mass radius calculation at payload commitment and preview; C, K. | Same aim at mass 0/450/990 reaches more of a spaced pack; no extra blink/glide effect. Andrew chooses a different placement for the wider blast. |
| S1 | Retain discharge with world-one selection; S. | Vault through two packs with no special items; Andrew uses a wall as an attack twice rather than treating it as decoration. |
| S2 | Retain distant catch plus Mass-S; S. | Three firing faces around a pickup route; Andrew relocates twice and prefers that rhythm to sitting on one face. |
| S3 | Compose fixed fling, mass and all speed additions once; S, M. | Release early versus late on one swing: Andrew intentionally changes the landing, with no wall ping-pong acceleration exploit. |
| S4 | Move Face Runner into Live Wire's slot, air refresh and 1.5 s face lock; S, M, `src/core/upgrade_tree.gd`. H1 follow-up also owns H and `src/movement/ball_rules.gd`. | Cross a three-face route using restored jumps, without H1 first; with H1, Andrew predicts and uses the 2 s steering benefit twice. |
| S5 | Retain one turret chain; S. | Two staggered pairs of enemies on different faces: Andrew changes perch to reach the second pair rather than waiting for them. |
| S6 | Retain CC immunity; S. | A clearly wound-up shove interrupts baseline mount; with Bulwark it does not, damage still applies, and Andrew chooses when to launch. |
| R1 | Retain twin pattern; R. | Strafe two target columns without rare parts; Andrew changes aim to sweep both rather than parking for damage. |
| R2 | Retain start blast; R. | Enter three crowds: Andrew deliberately times two sprint starts to make an escape lane and prefers that to firing from outside. |
| R3 | Retain chained pattern; R. | A near pair and an isolated target force different approaches; Andrew chooses two passes that exploit the neighbour chain. |
| R4 | First emit actual wear amounts with H; then a serial unit owns R, `src/build/build.gd`, `src/core/upgrade_tree.gd` for bounded patches drawn with the existing field ring. Audio/VFX polish is a later V cue unit. | Three pursuer passes with ordinary wear, then H2: Andrew curves to lay the trail, wants another pass, and does not stop to conserve mass. |
| R5 | Retain no-rebound/punch; R. | Sprint through three bodies toward a visible wall; bodies yield, wall does not. Andrew chooses the line and can explain that boundary. |
| R6 | Retain charge first; R. H1 follow-up owns H and `src/movement/ball_rules.gd` too. | Spend one sprint entering and another escaping; with H1, airborne sprint restores ordinary control only while active. Andrew uses both charges deliberately. |
| K1 | Retain five-charge setup plus Mass-K; K. | Lay charges ahead of a moving pack without stopping; Andrew prefers the planned crossing to chasing the pack with throws. |
| K2 | Retain closer cloak detection plus Mass-K; K. | Blink between two exposed approaches, then place a blast; Andrew uses concealment to choose an angle instead of waiting out the fight. |
| K3 | Retain 2 m trigger; K. | Armed trap before fuse expiry: enemy hull within 2 m triggers, hull 2.1 m away does not, matching `src/combat/sticky.gd:130–138`. Andrew predicts two successful ambushes. |
| K4 | Retain five slam charges; K. | Three dive-and-blink exits: Andrew chooses a landing to catch a spread pack, can see the escape, and requests another dive. |
| K5 | Keep glide cloak; K. H1 follow-up owns H and `src/movement/ball_rules.gd` too. | Approach through an overhead threat gap without H1; repeat with H1 and deliberately use improved glide steering, not indefinite safe hovering. |
| K6 | Retain cloak-preserving throw; K. | Throw twice then reposition within cloak; repeat with H2. Fail if a stationary concealed barrage replaces the route or erases Brindle's readable phases. |
| H1 | Smallest playable slice is injected armour/air tradeoff; H, `src/movement/ball_rules.gd`. Catalogue and V follow separately, then S4/R6/K5 inversions serially. | At 200 mass, a 12 HP post-mitigation hit costs 60 mass, not 120; no hull loss. Andrew reads both effects before fitting, can finish the jump route without inversion, and prefers fitting only on some routes. |
| H2 | Smallest playable slice is wear multiplier plus Rivet ram bonus; H, `src/combat/combat.gd`. Separate units add Sable's launch-origin attack, then Kest's batch snapshot using C. Catalogue and V follow. | Same route loses 60 versus 30 mass/minute at cruise; zero mass restores plain attacks, never hurts hull. Andrew takes H2 on a stocked attack route but skips it in the low-armour fixture. |
| Skip | One branch-authored exclusive pair and one-time recycle; V, `src/build/parts.gd`. | S1→S4 fixture: Andrew first wants H2, sees the route, picks Vault Battery, misses H2's burst and uses the extra vault. Retry must not duplicate payout or restore the rejected offer. |
| Synergies | Reuse existing recipes; `src/build/synergies.gd`, `src/build/build.gd`, `tests/world_one_synergies_test.gd` NEW. Change execution only for origin/budget guards. | Run each interaction-table fixture. A failed recognition, runaway chain or obscured threat rejects that combination even if total damage looks good. |

Verification for future slices: flag-off parity; valid parent paths; preview equals committed geometry; no mass change from equipping/removing; no duplicate payout on retry; no wear or secondary-damage recursion. Human trials follow the project sketch smoke when implementation is authorized. This document ran no Godot build, simulation or playtest.

The first useful implementation is G plus Mass-S and S1→S3 on one fixed route. That answers whether carrying scrap makes the wall release worth pursuing before spending a wave on the full matrix. The full world-one design remains all eighteen nodes and both hot-wired parts above.
