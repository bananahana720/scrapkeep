# Core-loop v2 design

> Pilot kits, ultimates and bodies are superseded by [design-v3/PILOTS.md](design-v3/PILOTS.md) (2026-10-10); this file's pilot text is history.

This is the accepted spec for the v2 round (TRACKING EV-0588). It answers playtest entry 7.

- The historical approved plan was `synchronous-weaving-crystal.md` (local session plan archive).
- The inputs are under `artifacts/local/v2-research/` (R1 to R4 research, I1 to I3 ideation). They are suggestions; this file decides.
- The principles are in `DESIGN-NOTES.md` and the project memory. Momentum is sacred, readability comes first, and form mirrors function.

Names are candidates taken from the Bible's class vocabulary (§5.1), not a locked roster.

## 1. One input grammar for every class

Every class uses the same keys, so the ability bar always reads LMB, RMB, F and Ctrl.

| Key | Meaning for every class |
| --- | --- |
| LMB | the class weapon |
| RMB | the class movement ability |
| F (hold, release) | the class special, as a hold-gauge-release skill shot |
| Ctrl | the smash (a slam in the air, a class flavour on landing) |
| Space | jump and double jump. At a steep face in the air it becomes the **vault kick** (engineer only). The caster holds it to glide. |
| Shift | boost (shared) |
| E, Q, wheel | engineer only: mount a pylon, winch, rope length |

- The shared air dash is gone. What it did now lives in each class's movement ability.
- A stomp or rebound refreshes one air jump and one charge of the class movement ability. That's the same single refresh the stomp gives today.

## 2. The three characters

| | **Sable**, Pylon engineer | **Rivet**, Runner-gunner | **Kest**, Demolitions caster |
| --- | --- | --- | --- |
| Fantasy | Plant a beachhead, then launch off it like a cannonball | An unstoppable laser sprinter who turns crowd control into fuel | Vanish in your own smoke, then drop a line of fire where they least expect it |
| LMB | Arc caster, unchanged; a pylon turret while mounted | Rapid laser, **unchanged** (Andrew: "the gunning feels great") | **Sticky charges.** Hold shows a lobbed arc (the projectile grammar); release throws. 16 dmg, 3.0 m radius. The fuse is 1.2 s or contact. 0.6 s between throws, at most 3 live. |
| RMB | Grapple and winch, unchanged, with a clearer reticle and its own sound | **Overdrive sprint** (hold). Immune to crowd control, +25% cruise, crush threshold −20% while active. 2.0 s per charge, 5 s cooldown. | **Smoke blink.** An 8 m dash that leaves a dust cloud and grants the cloak. 4 s cooldown. |
| F | **Detonation gauge.** A hold-release arc discharge: radius 12 to 30 m, damage scaled by the gauge, 5 s cooldown. Planting a pylon still fires a free discharge from the banked speed. | **Overdrive blast.** Hold-release: radius, damage and knock scale with the gauge, then a 3 s fire-rate boost. 6 s cooldown. | **Detonation line.** Hold draws a 6 to 14 m line (the lane grammar). Release detonates every live sticky charge in the line early, plus line damage, with +25% per charge caught (up to 3). 6 s cooldown. |
| Space extra | **Vault kick** at a steep face in the air: exit speed = incoming × 1.8, capped at 45 m/s, 1.5 s cooldown per face. An aim cone shows while a vault is available. | – | **Glide** (hold while falling). A rocket jump off its own blast: 22 to 30 m/s by proximity, 1.0 s cooldown. |
| E | Mount; the slingshot is a hold-gauge-release on Space while mounted (aim cone and gauge) | – | – |
| Smash (Ctrl) | **Arc slam**: a mint shock ring that highlights steep faces within 12 m for 2 s | **Shockwave skid**: a forward slide-smash. Each enemy hit refunds 0.5 s of sprint cooldown. | **Demo slam**: 3 mini-charges spread on landing, 5.3 dmg, 1.5 m, arming after 0.3 s |
| Passive | – | – | **Dust cloak**, 1.5 s after any own detonation or blink. Enemy acquisition range −40%. The first shot from cloak crits (+100%) and breaks the cloak. |
| Colour | Field mint | Copper | Safety amber |
| Shape | Ring | Chevron | Starburst |
| Sound | A rising arpeggio | Hi-hat rolls | Low thumps |
| Synergy hooks | `on_vault_kick`, `on_pylon_discharge`, `on_mount_planted` | `on_sprint_start`, `on_blast_release`, `on_cc_ignored` | `on_cloak_crit`, `on_rocket_jump`, `on_chain_detonation` |

**Colour, shape and sound come from one source.** Each class row in `class_def.gd` carries them. The HUD, VFX, audio and icons all read that row.

**How each class keeps momentum:**
- **Sable** banks speed rather than stopping.
- **Rivet's** sprint removes the one stop the player didn't cause, crowd control. It never removes damage.
- **Kest** hides by moving: blink, blast, glide. It never hides by standing still.

## 3. Shared: bowling-ball contact

The contact rule lives in `player_ball._on_enemy_touched`, beside the stomp and crush branches.

- **Rebound.** Applies when `enemy.weight >= heft × 1.15`, or `× 1.0` while Rivet sprints.
  - Reflect the incoming velocity across the contact normal with restitution 0.65.
  - Cap the vertical part at `jump_speed × 1.4`.
  - The refresh is the same single refresh a stomp gives.
- **Smash-through.** Applies when the enemy is lighter; this is the existing crush.
- **Pins.**
  - A knocked enemy moving faster than 6 m/s that hits another within 1.2 m deals `8 + 0.5 × speed` damage (cap 40).
  - It hits once per knock event, keyed by the carrier's instance id.

## 4. Shared: hold-gauge-release skill shots

Every F special, the caster's LMB and the slingshot follow one spec.

- **The indicator.** A sector, line or arc drawn as exactly the committed hit geometry (RR-01), in the class colour, never the hazard colour.
- **Forgiveness is in the hit test, not the drawing.** Enemies whose hull falls within 15 to 20% beyond the drawn edge still count as hit. V1 caught this: the first version drew the indicator larger, which would have made players miss at the edge of what they were shown.
- **The gauge.** A radial ring around the reticle, filling linearly over `charge_max`, which is 0.6 to 1.4 s depending on the ability.
- **Release.** The hold fraction scales damage and size from a floor, so a tap still works. At full charge it auto-fires after a 0.5 s grace.
- **Cancel.** Pressing the special again cancels, with no cooldown spent. Knock or crowd control mid-charge force-cancels the same way. Nothing is ever left stuck in a charging state.

## 5. Shared: cooldowns and charges

- Base cooldowns are 2 to 6 s.
- Every ability has `max_charges`, 1 by default. Items raise it.
- Charges recharge one at a time and stockpile. They show as pips under the slot (W1's ability-slot contract).

## 6. Risks each writer must test

1. **Vault ping-pong** between two faces. Covered by the cap and the per-face cooldown.
2. **Sprint used as a tank.** Damage still applies at the normal rate while sprinting.
3. **Detonation-line burst** against boss plating. The charge count is capped at 3.
4. **Rocket-jump flight chaining.** Neither cooldown can be driven to 0 by items. The floor is 0.4 s.
5. **Charge interrupt leak.** A crowd-control hit mid-charge clears the gauge, starts no cooldown and fires nothing.
6. **Traversal chaining past gating.** The air refresh stays at one per contact.

## 7. Loot and growth

`design-v2/I2-item-generator.md` (archived in git history) is accepted as the loot spec, with the changes below.

**Items**

- Items stay `PartDef` Resources. The new typed fields are `trigger`, `proc_coeff`, `stack_rule`, `stack_cap` and `icon_category`.
- The trigger vocabulary is closed, at 12 kinds, in `src/build/triggers.gd`. Adding a trigger kind is a code change, not data.
- **Chains end by construction.** A trigger kind can't re-post itself within one commitment pass, and `chain_depth` is at most 1.
- The generator is base × affix × element × trigger. It reuses the existing tier bands and rarity weights: common 60, uncommon 27, rare 10, rare_plus 3.
- **Stacking.** Stats that could reach 100% use the hyperbolic rule. Charges and procs use the capped rule.
- **The pool.** The 61-item table is the starting pool. The class-specific items (`glide_vane`, `anchor_spring`, `jet_vent`) only offer themselves to their own class. Item names follow §2: the engineer is Sable, the runner is Rivet, the caster is Kest.

**Changes to I2**

- **The fuzzer is a tool, not a test.** The full `item_fuzz` (200 seeds × 90 s) is `tools/item_fuzz.gd`. `tests/item_fuzz_smoke_test.gd` runs 8 seeds × 20 s, so `sketch:smoke` stays under its 120 s per-test timeout.
- **Happy accidents.** Anomalies go to `HAPPY-ACCIDENTS.md` for Andrew to mark KEEP or KILL. The five designed happy accidents ship.

**Legibility**

- A gate reads as a family shape, a rarity topper, a trigger glyph and an element glyph, with no added text.
- A pickup's colour is its element and its shape is its family. A pulse means it completes a synergy.
- A Risk of Rain-style clock with a difficulty bar sits in the HUD (from W1's timer).
- Two opt-in challenge modifiers are on the class-select screen: **Scrapless** and a **par timer**. Each is tagged in the run log.

## 8. The vertical stage

`design-v2/I3-vertical-stage.md` (archived in git history) is accepted as the stage 2 replacement: one gorge with three shelf heights.

**Layers**

- **Undercroft.** A heightmap shelf holding the Warden bowl and the rapids canal.
- **Ground shelf.**
- **Sky layer.** Props over a void: cable towers and hover barges on `AnimatableBody3D` with `sync_to_physics`. Barge motion and tilt are scripted.

**Getting between layers**

- Five speed-preserving transitions, with no stop anywhere: a grapple line, a glide drop, a skylight halfpipe, a geyser vent that reuses the rail maths, and chutes.
- Each class has a best route: Sable goes by the towers and a vault, Kest drops through a skylight and rocket-jumps back up, and Rivet sprints the shelf and the rapids.

**Blockers before it ships**

- The DESIGN-NOTES #39 gate-approach sweep must also cover towers, barges and tunnel roofs.
- If the ball slides on the barges, the fallback named in I3 applies.

## 9. Contraptions, focal points and events that change the terrain

Andrew added these on 2026-09-27, mid-round, in his words:

- "more steampunk and contraptions like um, steam, like lifts or launchers"
- "post-apocalyptic like futurism"
- "maps that are designed around a cluster buildings or a yeah focal point"
- events that "change the environment and cause like rocks to cave in or something to land and create a crater or um, a building being like you know kind of like destroyed and a portion of it or uh, changed or morphed into something"

The Wave 3 stage and event writers work these in:

- **Contraptions.** Momentum tools you ride, never stops:
  - steam lifts: an `AnimatableBody3D` piston platform that fires on a cycle you can read
  - steam launchers: a vent or catapult reusing the rail maths
  - pressure valves the player smashes to open a route
  - Each shows its cycle with steam and a gauge you can read at a glance, and has its own sound.
- **A focal point.** The vertical stage is built around one landmark: a ruined dam-works tower cluster. The undercroft, shelf and sky layers orbit it. It is the orientation anchor from every layer.
- **Events that change the terrain.** These come from the event director (TADR-010), always announced first (a telegraph plus a stinger on the beat). They change the committed geometry, and the new collider is exactly the drawn change.
  - **Cave-in.** Rocks seal one route and open another. A crumble telegraph runs 3 s ahead.
  - **Impact.** Something lands and leaves a crater bowl, a new halfpipe the ball can ride. A projectile-type telegraph marks the landing.
  - **Structural collapse.** Part of a tower shears off and becomes a ramp or bridge, or sheds a bonus vault.
  - Rules:
    - Momentum is sacred: a change never traps the ball inside new geometry.
    - The spawn-clear check holds the change until the ball is outside the footprint.
    - Participating (standing your ground, riding the new feature) pays a milestone reward.
    - Performance: a terrain swap pre-builds the post-change collider and swaps it in, per the ~34 ms trimesh note. It never rebuilds mid-frame.

## 10. Enemy origin, reinforcements and chained crowd control

Andrew added these on 2026-09-27, in his words:

- **Origin.** The enemies are "either uh, awaken ancient beings or an alien race or robots that came from the advent of an apocalypse, which is why it would be post-apocalyptic". Which origin is still open; see the question at the end.
- **Reinforcements.** The longer you stay, the more "special like reinforcements would come". They carry "fun anti like roly ball like uh, mechanisms":
  - "magnetic uh like uh traps that will act as like uh pits to slow you down"
  - a hook that can "hook you to a specific Uh, point and lock you in place"
  - "electrical fields that will pop up and try to nab you in the air"
  - "bolas that will try to nab you in the air"
  - armoured units that "can take an additional hit ... similar to the warden, but in a lesser extent"
  - units that "reflect you or, or pull you"
- **Enemy synergies.** "if you're unfortunately coming up to a combination of people, then you'll just get napped and and uh, um, just like skill chained".

**How this fits momentum is sacred.** The principle allows stops the player could foresee and that come from their own performance. So:

1. **Every counter is telegraphed** with W2's threat grammar before it can take hold: a projectile trace for bolas, a lane for the hook line, and an instant AOE fill for a mag pit or air-net field. Each has its own warn sound, and each is dodgeable by reading it.
2. **Every hold can be broken by the player.**
   - A smash or jump breaks a mag-pit slow.
   - Enough speed snaps a hook tether: if you're above the tether's heft rating it breaks, which rewards growth.
   - A double jump or glide escapes an air net.
   - Rivet's sprint ignores all of them. That's his identity paying off.
3. **Chains are real but bounded (tenacity).**
   - Crowd control can chain across a combination of enemies. Getting "skill chained" is a legitimate punishment for rolling into a bad combination.
   - After 1.8 s of accumulated hold within 4 s, the ball gets 2.5 s of immunity to crowd control, shown as a broken-bracket flicker in the class colour (VISUAL-LANGUAGE §11).
   - Breaking free by your own action (smash, jump, speed) gives a small boost refund. Escaping is a momentum moment, not only relief.
4. **Reinforcement roster.**
   - Mag trapper: throws a magnetic pit disc (slow, heft-gated).
   - Hooker: fires a tether lane that pins you to its anchor post.
   - Netcaster: raises an electric field that grabs airborne balls.
   - Bola thrower: a slow arcing throw that wraps you mid-air.
   - Plated brute: a mini-Warden with plating that takes one extra breaking hit.
   - Deflector: a reflect shield that bounces you back at restitution 0.9.
   - Winch drone: pulls you toward the pack.
5. **When they arrive.** The Risk of Rain stay-longer clock gates them. Each difficulty tick past the Warden break adds reinforcement weight. The director (TADR-010) composes packs that deliberately pair a controller with a punisher. For example, a mag trapper plus a bola thrower: the tagged combinations are the enemy synergies.
6. **The counterplay is learnable.** Each counter also becomes an opportunity:
   - A rebound off a deflector's shield gives any class the vault kick's ×1.8 (the one vault that is not Sable-only).
   - A snapped tether slings you forward.
   - An air net can be baited.

These are the hooks for loot items ("tenacity", "tether snap", "net cutter").

Wave 3 gets a W7 enemies writer (combat enemies plus the director's pack composition). It starts after W2 and W3 merge, since it needs the threat grammar and the contact rules.

**No reskins (Andrew's pet peeve, 2026-09-27).** In his words: "I want creativity with the enemies ... another pet peeve of mine is just having skins of the same enemy that uh, does the same mechanic." The rules:

- Every enemy type owns a mechanic no other type has.
- A variant counts as a new enemy only if it changes what the player must do.
- The W7 writer and its reviewer check each roster entry against this. Two entries that differ only in numbers or colour fail.

**Enemy origin, chosen by Andrew through AskUserQuestion on 2026-09-27: the Fleet digs up ancient machines.** The Furnace Fleet's excavations woke pre-apocalypse war machines under the Southwest, and that waking caused the collapse. This gives two factions whose mechanics must differ:

- **Fleet crews** are the reinforcements, with engineered anti-ball gear: the mag trappers, hookers, netcasters, bola throwers, deflectors and winch drones.
- **Awakened ancients** are the wild threats and the Wardens: strange, ritual and geological.

Brindle and the Bible's antagonist stay. The Bible amendment for the post-apocalyptic layer is a heavy-lane card after v2 play.

**The ancients are us (Andrew, 2026-09-27).** In his words: "the uh, ancient machines were made by humans and um, like we can kind of have a mixture of things of what caused the ancient beings, aka us, to have uh, been lost, like whether it would be nuclear war or drone technology or uh, you know advanced super intelligence um, or a combination of all of those." Each cause becomes one ancient family with a mechanic no other family has (the no-reskins rule):

| Cause | Family | Signature mechanic |
| --- | --- | --- |
| Nuclear war | Reactor relics | Terrain-changing hazard zones: fallout craters and meltdown vents. They reuse §9's events. |
| Drone technology | Swarm remnants | Flocking formations: weak alone, dangerous in formation. Bowling through a formation scatters it. |
| Superintelligence | The Mind's hands | Adapts to the player's habits. Frequent rebounds make it brace; frequent vaults make it guard the walls. It reads and counters the player's last pattern, bounded and telegraphed. |

The codex's world category holds lore fragments found in vaults and secrets. The true cause, or the mix of causes, stays ambiguous and is pieced together across runs. For the W7 roster in this sketch, one ancient per family is enough, beside the Fleet reinforcements.

**Who the characters are (Andrew, 2026-09-27).** In his words: "since life finds a way that there will be other intelligent beings or I guess it could be like animal, like amorphous, like animus type like characters", "tying into the history of you know, where the characters come from and um, like the history of the the current reigning intelligent species."

- **The premise.** After humans were lost, animals became the reigning intelligent species. They grew up among our buried machines.
- **It matches the Bible's candidate cast:**
  - Sable, a fox from the Switchback Enclaves: grapple traversal.
  - Kest, a bird from the Highdraft Roosts: a hovering mortar.
  - Rivet, a mole machinist with cyborg instrumentation.
  - Brindle, a badger commanding the Fleet.
- **How they became intelligent stays ambiguous.** Evolution, or uplift by something humans left behind (a lab, the Mind, a caretaker drone network). The codex hints at it and never settles it.
- **The theme.** Salvagers repair and repurpose the tech that ended us. The Fleet digs up what should have stayed buried.

The Bible marks an animal-only cast as open and never makes the exploratory examples canon. This premise goes to the same heavy-lane Bible card as the enemy origin, after v2 play. In this sketch, the class screen and codex may use the species and culture names.

## 11. Andrew's rulings on V1's questions (AskUserQuestion, 2026-09-27)

- **Wardens, one ancient family per stage.**
  - Stage 1 is a reactor-relic Warden.
  - Stage 2 is a swarm-remnant hive Warden.
  - Stage 3 is one of the Mind's hands.
  - Each fight plays differently, and one run meets all three causes of the collapse. The clamp is a shared base with a family-specific core.
- **The rarest tier (rare_plus)** is amber with a mint heart and a notched frame. Red is only for things that hurt you.
- **The ancients' light** is **Cherenkov blue `#3d8bff`**, the glow of a human reactor pool: the light of the age that ended. Andrew chose it by AskUserQuestion after rejecting violet as "a bit overused". It keeps ΔE ≥ 31 against every palette colour under every vision type. Ancient seams are cut as charcoal grooves so they also read on petrol enamel.
- **Audio rulings (the vision keeper's three questions).** Each confirms SOUND-STORY.md's default.
  1. Only the reactor relic colours the band: a tritone pedal under the sub while a vent charges. Swarms and the Mind stay effects only.
  2. Fleet reinforcements borrow Brindle's anvil and brass in the level theme, adding one layer per difficulty tick.
  3. The Mind's hands quote the player's class motif, inverted with the last note a semitone flat. It's the one sanctioned hostile use of a class motif, and it doubles as their telegraph.
- **Render treatment: Style A, painted workshop miniature** (Andrew, in the Codex visual-development track, 2026-09-27: "I really like style A"). Broad painted wear, rounded cast machinery and soft material transitions. The choice covers the rendering treatment only. Geometry, danger marking, the Warden's form and the ring and growth proposals still answer to this spec and VISUAL-LANGUAGE. The package lives in the Codex clone under `design-v2/visual-development/` (ATLAS, ITERATION, REVIEW).
- **Kest's movement is not a seam.** RMB is `smoke_blink` (the class movement in `class_def.gd`), and Space held while falling is glide (§2). Both ship. An image must not trade one for the other.
- **The fourth pilot, Tally, is an unlock** (Andrew, 2026-09-27): a quirky, glitchy, friendly ancient robot for comic relief, who transmogs to match the parts and tree picks it holds. The demo keeps Tally as a presence (a dormant housing on Moss's shelf, one codex fragment, the summary flicker). The playable class, its transmog rule and its story-beat unlock are post-alpha, and need a design pass first. Detail and constraints: `design-v2/HERO-SPHERE.md` §5 and §11 on the herodesign branch.
- **Who owns what between the two tracks** (from the Codex hand-off note, 2026-09-27):
  - The Codex Style A playable pass owns the sphere hull, the seated pilot, gyro motion, materials and lighting. Its first scene uses the existing Spillway stage.
  - This branch owns gameplay, UI, audio, the stages and integration.
  - The parked V3 shell animator (`proto/core-loop-v2-assets` 29333e8) and the hero and Warden proposals (herodesign 56a1970, bossdesign 30977c3) are inputs to that pass, not merges.
  - Pinball-style layered routes (the Codex `LAYERED-SPILLWAY.md` study) are a concept study only. A playable map experiment needs its own authorization. Its acceptance questions (every class completes the loop without upgrades, both alternatives visible before commitment, a missed upper line yields a useful lower one, elevation-true warnings, dense p99 ≤ 16.7 ms at 1080p) are also the review lens for the Cable Reach gorge.

## 12. Moss's workshop: the lull between stages (Andrew, 2026-09-27)

In his words: "I actually want to have a maybe a shopkeeper uh, and maybe some lull in between phases. I do like the calm, you know, before the, sto the storm and the ability to maybe settle. And it could be also a time to like make upgrades as well and have some player decision be made instead of just being all procedural." He also asked for a meme interaction: the "Potion Seller" sketch (Justin Kuritzkes, https://www.youtube.com/watch?v=R_FQU4KzN7A), where the shopkeeper refuses to sell his strongest potions because they are too strong for the traveller.

**Who and where**

- **The keeper is Moss**, the Bible's proposed workshop keeper, who "remembers what each pilot neglects" (BIBLE.md:384).
- **The workshop is a side bay**, and entering it is the player's choice. It opens off the launch after each Warden break, beside the reward gates. Rolling past it goes straight into the launch.

**Momentum**

- Entering the bay banks the ball's speed, like the pylon mount.
- The exit launch pad slingshots the banked speed back into the stage launch.
- The calm costs no momentum. The player chooses it, so nothing stops them unforeseen.

**Calm**

- The music drops to a sax-led lounge arrangement of the current stage theme, in the live key. It's the stage's loved core re-voiced, never replaced (warden spill B grammar).
- The launch drops back into the full band.
- The difficulty clock pauses inside, so the calm is real. The par timer keeps running, so speedrunners can skip it at a cost.

**Player decisions (deterministic, not rolled on entry)**

- **A shelf of 3 visible parts** at scrap prices: buy exactly what you want.
- **One reroll** of the shelf per visit, at a rising price.
- **Charge upgrades.** Pay to raise one ability's `max_charges` by 1, up to a cap. This is the stockpile path.
- **Sell a part back** for half its price. This lowers heft, and the wording says so ("lighter, but faster to the next part").

**The Potion Seller nod (a homage, never the sketch's script)**

- Moss keeps one **top-shelf part**, always rare_plus, on a locked hook.
- He refuses to sell it until the ball's heft class reaches the next band. His refusal lines are original and in character, riffing on "too strong for you, salvager".
- The lock shows the heft needed as the pressure-dial icon with a notch, so the joke doubles as a growth goal you can read. Come back heavier and he relents with a grudging line.
- This mechanic is the only place the gag appears. It never blocks progress, since the part is optional.

**Owners**

- W4: the shop economy (shelf, prices, reroll, charge upgrades, the heft lock).
- W6: the workshop bay geometry and its launch pad.
- W5: the lounge arrangement and Moss's voice-free sound set (a workbench clank, a shop bell, a grumble when he refuses).
- W1: the shop UI, with icons first and at most 5 words per line.
- Vision keeper: Moss's wording.

**The conversation loop (Andrew, 2026-09-27).** In his words: "a conversational loop where the player can initiate and get maybe the flavors of the conversation or of the sketch". He accepted "a different flavor of it" if needed.

- **Copyright.** The sketch's script is its creator's work; being on YouTube doesn't license it. The game copies no lines. It borrows only the comic structure: an escalating ask, a stubborn refusal repeated with rising exasperation, and a dismissal to a weaker seller. Everything is in Moss's own voice. The vision keeper writes the lines, and the integration reviewer checks that no line reproduces the sketch.
- **How the player starts it.** A key glyph appears by Moss inside the bay. Each press plays one beat.
- **The beats.** The loop runs 5 to 6 beats: ask, refuse, insist, double down, plead, send off (for example, to "a scrapper who sells lighter parts"). Pressing again restarts the loop with a new variation. There are at least 3 variations per beat, so repeat visits stay fresh.
- **The pay-off.** Once the ball reaches the heft class the top shelf needs, the loop ends in a grudging relent line and the hook unlocks. The gag and the growth goal are the same thing.
- **Moss's voice.** Synthesized babble, one syllable blip per letter, pitched in the live key, with each beat rising in pitch as he gets exasperated. No recorded voice.
- **Fit.** It never blocks the exit, and each line is a speech bubble of at most 12 words, well away from the reticle. Seeing the loop through adds a codex entry ("Too heavy for you").

## 13. Standing rule: when a callback lines up with a mechanic, build it

Andrew, 2026-09-27, after the Moss heft-lock: "that's like a callback with a game mechanic ... If you come into other instances where things align like that, uh, go for it. And take the initiative and just, just build it. And just, yeah, make it a way for me or a player to just discover it naturally or uh, with some digging ... with uh, game design in mind and to have things make sense from a video gameplay."

**The rule for every unit.** When a reference, joke, lore fact or motif lines up with a mechanic, build the alignment without asking. It must pass three tests:

1. **It makes gameplay sense on its own.** A player who misses the reference still gets a fair, readable mechanic.
2. **It's discovered, not announced.** It's found naturally in play or by digging (the codex, secrets, repeated interaction, an odd combination). It's never a tutorial.
3. **It serves the principles.** It never costs momentum unforeseen, never hides a threat, and stays inside the visual caps.

Log each one in DESIGN-NOTES as "Callback:", naming the mechanic it rides on, and add it to the unit's vision delta. The vision keeper keeps a running list in SOUND-STORY.md so callbacks never collide.

## 14. Session goal: an early-access demo (Andrew, 2026-09-27)

In his words: "run until we kind of get to a like a early access demo version of the game, and let it have some some visual appeal and coherence, and gameplay appeal and coherence with uh, audio and music orchestration ... fully built ... an early access level version of the game."

**Lane.** This stays the light play lane. It's a Godot sketch under `sketches/core-loop/` and not a production promotion into `native/`, which is a heavy-lane decision. Andrew's play is the acceptance.

**Definition of done.** Every line must hold.

1. **The run.**
   - Title, character select (3), then three stages, each with a family Warden. Moss's workshop after each break, then Brindle's arena, then victory or death, then the summary.
   - Settings and pause menus, all usable with the mouse and the keyboard.
   - One-key restart from anywhere.
2. **The characters.** Sable, Rivet and Kest play differently. Each has its own movement, a hold-gauge-release special, a smash flavour and a leitmotif.
3. **Enemies.**
   - The Fleet reinforcements (at least 5 with unique mechanics).
   - One ancient per family, plus the three family Wardens and Brindle.
   - Every counter is telegraphed and breakable. No reskins.
4. **Growth.**
   - The procedural item pool (60+ items, 12 triggers).
   - Moss's shop, with the heft-locked top shelf and the conversation loop.
   - Stockpiled charges.
   - Synergies you can discover through the codex.
5. **World.**
   - The vertical gorge stage with its focal landmark.
   - Contraptions (lifts, launchers, valves).
   - At least 2 terrain-changing events.
   - The callbacks from §13.
6. **Readability.**
   - At most 25 words on screen in a fight.
   - The icon-first HUD, with the 70 icons in use.
   - Four threat types you can tell apart by look and sound.
   - Contextual key glyphs, and first-run callouts that retire.
7. **Look.**
   - Blender hero assets in the build: the three shells with a visible pilot, accretion chunks, the reward gate and the Warden clamp with its family kits.
   - Every surface follows VISUAL-LANGUAGE.md.
   - Transitions between every screen.
8. **Audio.**
   - Every event row has its designed sound (SOUND-STORY.md grammar).
   - Adaptive stage themes with the leitmotifs woven in, and Brindle's foreshadowing.
   - The lounge arrangement in the workshop.
   - No MUSIC-GEMS entry lost.
9. **Robustness.**
   - `sketch:smoke` is green.
   - The bot completes full runs with all three classes.
   - `item_fuzz` passes 200 seeds, with anomalies triaged in HAPPY-ACCIDENTS.md.
   - p99 frame time is ≤ 16.7 ms in a dense fight on this machine.
   - No softlock, no NaN.
10. **Handoff.**
    - A Linux export build under `artifacts/local/` alongside the launcher entry.
    - A one-page "how to play" on the title screen's help button.
    - Andrew plays it, and his verdict becomes a playtest log entry.

**Checkpoint.** After Wave 3 merges, Andrew gets an **alpha** to play, so he can redirect while polish continues. The later waves take his notes.

## 15. The ball is the culture (Andrew, 2026-09-27)

These are Andrew's answers to the primer questions, recorded before the remaining ones are asked.

- **Sidegrades.** Counters now, variants after the alpha.
- **Moss.** Unseen: a voice and hands. His babble stays as demoed. Andrew: "I love the old school babbl ... I love the jazzy vib It kind of feels like a club ... a really fun place just to hang out or afk". He asked for "fun little interactions, mini-games, things you could do to just like fidget or past the time ... or a way to move around and interact with practice movement or an area to like spam abilities".
- **The kit.** Instead of "full kit or unlock in world one", he wants "more upgrades to it that could be done at checkpoints in between world stages ... a branch of always two ... first decision would be two and then ... four and then eight and then sixteen as the final level ... sixteen variations of maybe key skills ... for mobility, it could be for everything pretty much and I think the enemies should also kind of accommodate for that as well." The shape of the tree is still to confirm. The checkpoints are Moss's workshop visits, and it matches the Bible's "four slot trees".

**Map and world premise.** In his words:

- "map design should cater towards you know being in a bowl [ball] as the primary mode of it of uh, mobility"
- "a society or a series of societies based off of the characters that um, all cater to just moving fast, being on the go, momentum-based ... hunter-gatherer, like nomadic type of uh, tribes and build up and tear down"
- "explain why they chose to be in uh, gyroscopic balls"
- enemies' "defenses uh, to kind of uh, you know circumvent and overcome ... these ball based uh, mechas", which "the ancient ... robotic or alien robotic transhuman type of civilization is able to like develop quickly as you progress"
- "traps like uh you can throw off your gyroscope inside your ball uh and cause you to kind of like lose um, or be, be uh, disoriented", "get trapped in certain mechanisms", "swatted away or uh, uh, sent off a ramp"
- "launch off of cannons at a cannonball ... trebuchets", "a sort of like um, racetrack ... like a marble maze like uh like building our society"
- "it could lend itself into every aspect of the story and world building and characters and everything enemy design or uh attacks"

**How it lands in the design** (for the vision keeper, W6, W7 and V1/V3):

1. **Why balls.** After the collapse the ground itself is hostile: fallout pockets, swarm-infested ruins, and the Mind's traps. A rolling, sealed, gyroscopically stabilized shell is the survival form. The gyros were salvaged from ancient machines (reactor gyros, drone cores), so the tech that ended humanity keeps the animals alive. The codex tells this; nothing states it outright.
2. **Nomadic momentum tribes.** The Bible's cultures (the Switchback Enclaves, the Highdraft Roosts, the Redjaw Workshops) become rolling nomads. They build camps up and tear them down, and every settlement is architecture for balls:
   - banked streets, marble-maze ramps and halfpipe plazas
   - chutes between tiers, and cannons and trebuchets as public transport
   - Moss's workshop is a pit stop on the marble run
3. **Maps are built for the ball first.** Bowls, banks, loops, rails, launchers and marble-run structures come first. Flat rooms are the exception. Every stage has at least one piece of ball infrastructure (a marble-run section, a cannon or trebuchet launch, a racetrack loop) as its signature traversal.
4. **Enemies evolved to beat balls, and they adapt as the clock climbs.**
   - **Gyro jammers.** A telegraphed field that throws off your gyroscope: steering drifts or wobbles briefly (screen-stable, never nauseating). You break out by moving: jump, smash or boost.
   - **Swatters.** Paddle arms that bat you away, a knock you can ride.
   - **Ramp-flippers.** Tiles that tilt to fling you off course, shown before they tilt.
   - **Catch-traps.** Mechanisms that cup and hold the ball. Breakable, and bounded by tenacity.
   - These join §10's Fleet gear. Every counter is telegraphed, breakable and bounded by tenacity (1.8 s of hold, then 2.5 s of immunity). Rivet's sprint ignores all of them.
   - The ancient transhuman side develops new anti-ball counters as difficulty ticks rise: new counters appear with the clock, and the Mind's hands adapt within a run.
5. **The tree has an answer in the enemies.** As the player's branch choices build up, the director weights reinforcement packs to test that build. Tests are fair and telegraphed; a build is never hard-countered.
6. **Moss's bay is a hangout.**
   - A practice yard for movement and for spamming abilities, with no cooldown cost inside it.
   - A few fidget toys: a marble-run toy, a bell, a jukebox that flips the lounge arrangement, and Moss's babble.
   - A small optional mini-game, such as a timed marble-run lap with a codex callback.
   - The difficulty clock stays paused. Leaving is always one roll away.

**The primer gate is passed (the rest of Andrew's AskUserQuestion answers, 2026-09-27).**

- **The upgrade tree** is one binary tree per character. There are four picks: at the start, then at Moss's workshop after stages 1, 2 and 3. Four picks end on one of 16 distinct builds, and nodes can change any key. Enemy packs read the branch and test it fairly.
- **Mastery unlocks** apply from the next run and open alternate branches in the tree: more options, never more raw power.
- **The Mind's hands** adapt within a run only for the demo. Memory across runs stays a hook, switched off.
- **The arena** ends with Brindle routed, then a single Cherenkov flicker across the dug-up housings on the summary.
