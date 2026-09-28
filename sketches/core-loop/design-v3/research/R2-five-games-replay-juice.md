# R2: five games, replay drivers, juice, fast iteration

Haiku web scout, 2026-09-28, for the loop redesign. Evidence level: wiki and web summaries, and some claims are the scout's inference. Coordinator corrections are marked **[coordinator]**.

## Comparison

| Game | Core loop | Replay hook | How builds snowball | Run variety | Meta-progression | Difficulty against power |
| --- | --- | --- | --- | --- | --- | --- |
| The Binding of Isaac | Room, clear, item pedestal, floor boss | Every drop can make or break the run | 700-odd items with emergent, often accidental synergies | Procedural floors, item pools, deals | Unlocks through achievements and secrets | Floors get harder; power is item luck plus skill |
| Gunfire Reborn | Hero and weapon, rooms by act, stack scrolls, fuse elements | Scroll combinations make each run's build unique | Elemental status fusions chain and scale | Weapon drops, scroll pools, act bosses | Reincarnation ranks; unlock heroes and weapons | Difficulty tiers multiply enemies |
| Risk of Rain 2 | Stage: loot chests with money, charge the teleporter, boss, next stage; loop | "Stay longer for more items, but the clock hardens everything" | Item stacking and proc chains; many sources beat one stacked item | Procedural spawns, random bosses, stage variants | **[coordinator]** Yes: challenges unlock characters, items and skills. The scout said none, which is wrong. | The time-based clock is the enemy. **[coordinator]** Looping carries items into a second cycle; the scout called it a restart at harder difficulty, which is wrong. |
| Hades | Chamber, clear, choose a boon, repeat, boss | Heat (Pact of Punishment) and weapon aspects after the first win | Boon combinations and duo boons chain | Weapon aspects, boon pools, chamber order | Mirror upgrades, keepsakes, aspects | Heat ramps difficulty indefinitely, chosen by the player |
| Vampire Survivors | Move only; weapons auto-fire; XP; level-up pick; survive 30 min | Unlocks, arcana chests, extreme power fantasy | Weapon evolutions (a max-level weapon plus its paired passive, from a chest) | Stages, passive pairing, evolution order | Unlock characters, weapons and arcanas through conditions | Builds outscale enemies; by minute 20 the map is a destruction sandbox |

## Vampire Survivors mechanics

- **Evolution.** Max a weapon to level 8, hold its paired passive, then open a boss chest: the weapon becomes its evolved form (Knife plus Bracer is Thousand Edge). Evolutions are the power spikes. https://vampire-survivors.fandom.com/wiki/Evolution
- **Level-up cadence.** A choice from a few random options every 10 to 15 s early on: micro-decisions mid-chaos.
- **Escalation.** Move-only control leaves attention for navigation; by minute 20 the screen is saturated. https://platinumparagon.info/psychology-of-vampire-survivors/
- **Surprise.** Bosses at set minutes drop arcana chests, each a hidden multiplier or rule change; treasure chests roll a slot machine. https://vampire-survivors.fandom.com/wiki/Arcanas and https://vampire-survivors.fandom.com/wiki/Treasure_Chest

## Juice

- **Vlambeer, "The Art of Screenshake" (Jan Willem Nijman).** Layer muzzle flash, hit-stop of a few frames, camera kick and knockback on every violent action. https://www.youtube.com/watch?v=SkgkIXZ_13Y
- **Dead Cells.** A crit bundles a specific sound, brief shake and damage pop at once. Its audio builds a catalogue the player times to. https://teemo.dev/game-design/dead-cells/systems/audio-design/
- **Pickup magnetism.** Vampire Survivors pulls items within a base radius; grouped pickups sliding in read as a fountain, not a chore. https://vampire-survivors.fandom.com/wiki/Magnet
- **"Juice it or lose it" (Jonasson and Purho).** Squash, trails, particles and sound piled on simple actions turn flat into alive. https://roblog.co.uk/2024/03/juicy-games/
- **Fairness tricks.** Dead Cells has many small forgiveness techniques, which make near-misses feel earned. https://80.lv/articles/dead-cells-hidden-tricks-that-make-the-game-feel-fair/

## Fast iteration

- **Risk of Rain 2.** Prototyped by shifting dimension step by step. Level design was the hardest part to prototype in 3D ("you feel like you have one shot"). https://www.gamedeveloper.com/design/how-moving-from-2d-to-3d-shaped-the-design-of-i-risk-of-rain-2-i-/
- **Hades.** Planned as early access from the start; iterated with the community. https://www.supergiantgames.com/blog/hades-now-out-of-early-access/
- **Vampire Survivors.** A free browser game first to test the loop, then early access. https://en.wikipedia.org/wiki/Vampire_Survivors

## Scout's top 7 for a rolling-ball mech

1. Items with clear effects whose combinations break things. Ball properties (speed, bounce, friction) times weapons (spread, charge, ricochet) times procs.
2. Few verbs, rich positioning: steering and terrain carry the complexity.
3. Visible stacking: the ball and its rigging visibly bulk up with power.
4. Pace difficulty against power deliberately: a clock, a heat dial, or a cap.
5. Surprise moments (arcana-style chests, rule-changing drops) and unlocks for one more run.
6. Layer four feedback types on every violent action.
7. Iterate the loop in greybox with fast playtest cycles before art.
