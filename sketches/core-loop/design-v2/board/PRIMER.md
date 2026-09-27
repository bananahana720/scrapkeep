# Core-loop v2 primer: the meeting of the minds

This is the one page to read before the alpha. Four boards were built in parallel (look, audio, progression, story) and three leads wrote notes on each other's work. This page says what they agree on, settles where they disagreed, and asks you the eight questions only you can answer. Everything else has a default and is already moving.

The boards themselves: `VISUAL-BOARD.md` (with the rendered frames), the audio board with fourteen WAVs under `artifacts/local/v2-primer/audio/`, `PROGRESSION.md`, and `STORY-THREADS.md`. The rules they share are in `DESIGN-V2.md`, `VISUAL-LANGUAGE.md` and `SOUND-STORY.md`.

## The game, as the four boards now agree on it

You pilot a rolling ball of salvage with a fox, a mole or a bird visible in the cockpit, through a gorge built around a ruined dam-works tower, and the whole point is momentum: roll scrap into mass, get heavy, hit harder, and take the thing the clock is trying to stop you taking. Three characters play three different games on the same four keys: Sable banks speed and launches, Rivet sprints through anything that tries to hold him, Kest hides in her own smoke and drops fire where it hurts. Everything hostile is either the Furnace Fleet's bolted rust-red crews with brass tags, sent to hold you still with pits, tethers, nets and bolas, or the ancient human war machines the Fleet dug up: seamless, cast, blue-seamed, and each family a different cause of the collapse. Every threat sounds before it can hurt, every class has its own tune, and the loved 172 BPM band never stops: it gets layers when the game state earns them. Between stages, Moss's workshop bay is the calm you choose, where a grumpy keeper you never see refuses to sell you his best part until you are heavy enough. Nothing that carries across runs makes you stronger; it makes you wider: knowledge, options, a shopkeeper who remembers you, and the pressure you pick.

## The four boards

### Look (VISUAL-BOARD)

**What it establishes.** The class silhouettes survive a strong image model: fox with a mint collar and rope spool, mole with copper fins and a straight rail, bird with an open truss and satchels. The two material eras separate at a glance (bolted steampunk against cast blue-seamed ancients), and every enemy on the sheets is tool-shaped and distinct at thumbnail size.

**Strongest ideas.** The pilots visible behind glass in every frame. The dam-works landmark as both eras grown together. Moss's bay as a closed shutter, a hatch, a locked hook, a chipped mug and a plant in a tin.

**What the lead flagged.** The model drifts toward realism; the Godot build takes shapes from these frames, never surface detail. Ancient enamel came out turquoise, too close to mint, so it needs a value and saturation cap. Kest's satchel stripes read as hazard tape, so they become horizontal bands. Two off-lore slips: a human crew member on the Fleet sheet and a badger pilot in the arena frame.

### Audio (AUDIO-BOARD)

**What it establishes.** Fourteen demos from the game's own synth on the game's timeline: three class leitmotifs, the Fleet's stamp-stamp-decree, three ancient sounds, a stage theme escalating with Sable's arpeggio woven in, the lounge in Moss's bay and the drop back out, the four threat types, a crowd-control chain breaking free, Moss's babble, and difficulty ticks adding Fleet layers one at a time.

**Strongest ideas.** The reactor relic's tritone pedal under an unchanged bass line with Geiger clicks speeding up as the vent charges. The Mind's hand answering your own tune a bar later, upside down, one note wrong. The lounge as the same tune calmed down, and the exit slingshot resolving into the full band.

**What the lead flagged.** A mastery milestone would sound like one more ability release. The relent had no unlock sound and borrowed the shop bell. The gorge is silent by height. The pack callout chime is a stand-in with no source (ruled below). The landmark has no sound.

### Progression (PROGRESSION.md)

**What it establishes.** Three horizons. In-run: heft, parts, charges, cores and the top shelf, with the difficulty clock as the counter-pressure. Character mastery: nine play milestones (three per pilot) that unlock sidegrades, never stats. Account: the codex as the spine, Moss's memory, workshop upgrades that widen the shelf, and Pressure levels as valves on the bay's exit wall. Ten anti-grind rules, the strongest being "nothing persistent adds a stat" and "time never gates progression".

**Strongest ideas.** The heft dial's notch as the growth goal made literal. Bowling scores (Strike, Spare, Turkey) as codex entries for pin chains. Pressure as steam valves you smash open on the way out.

**What the lead flagged.** The built characters branch on literal ability ids in fourteen places, so a loadout swap does nothing today; sidegrades need a dispatch table first. Two Moss key lists existed (fixed below). Three story callbacks rode the same mechanics as three milestones (fixed below).

### Story threads (STORY-THREADS.md)

**What it establishes.** Seven threads, each riding a mechanic: the collapse's cause (three family Wardens, one run meets all three), the uplift, Moss remembering you, Brindle's arc toward the arena, the Mind learning, the reigning animals, and salvage as repurposing what ended us. Beats per run and across runs, a list of what is never resolved on purpose, and a callback index.

**Strongest ideas.** One run meets all three causes and settles none. Moss's lines keyed to what you actually did. The Requisition running on a dug-up core, seen only as a blue seam behind a cracked plate.

**What the leads flagged.** The title frame lights the landmark beacon where the story says the blue "glows nowhere yet". C11's scattered drones following the ball could read as allies.

## Where the boards meet

Each conflict between the notes, resolved with the reason, or handed to you.

1. **The callout chime.** W1 built four first-run teaching callouts ("Scrap = heft", "Break it", "Roll through", "Hold Tab: notes"), each once per profile, and named their sound `callout_chime`. The audio board read that as a pack callout. They are two different events. Ruling: W5's stand-in (two dry mallet pings, A then D, 70 ms apart) is adopted as the teaching callout's chime, because it climbs a fourth to home on the reward ladder and retires with the callout. A pack arriving is a new event row, `pack_arrived`, whose sound is the faction's motif head (the Fleet stamp, or a sine swell on the ancient family's harmony) with the faction's icon at the screen edge in hazard colour. That also closes the missing ancient arrival cue in one move.
2. **A milestone versus a release.** A mastery milestone plays the class motif whole on the beat, then its bright resolution an octave up and the rice cooker's two "done" beeps. An ability release stays on the frame with no answer. Reason: a milestone is the world noticing you; a release is your hand.
3. **The relent has its own sound.** Moss's sigh, a padlock clunk, then the hook's chain rising D to A on mallet. The shop bell means purchases only. The codex entry "Too heavy for you" takes the quiet fragment cue. Reason: one sound, one meaning.
4. **One Moss memory table.** The story's key names win; the progression board's facts join them (`sold_back`, `fragment_carried`, `refused_before`, `neglected_ability`, `pressure`). Facts live in `profile.json`; lines are the vision keeper's. `neglected` stays "died holding scrap"; `neglected_ability` is the ability you used least.
5. **The pilot barks are the milestones.** "Give it a moment" is Kest's triple catch, "Measured twice. Firing once." is Rivet's full blast, "Quiet part's over." is Sable's vault chain. Completing the milestone is the codex discovery. Reason: one rider per mechanic, and story and unlock land in the same moment.
6. **"Not yet" versus "now" on plated enemies.** The amber-and-slate tint goes. "Breaks now" is a class-colour rim and an open-crack glyph; "not yet" is closed plates with no rim, plus the clank that already tells you how close you were. Reason: amber is Kest's and the rare rarity, and slate vanishes on ancient petrol.
7. **C11, the following drones.** While scattered drones follow the ball for 2 s they lose their blue seams, keep their hostile edge, and hold one loose unison buzz panned to the ball, then go silent. Reason: hue alone never flips a hostile into an ally, and a state the player can use must have a sound.
8. **Pressure sounds like a valve.** `pressure_opened` is the contraption valve's smash womp and long hiss. The danger tick never sounds in the calm bay. Pressure does not change the music; the Fleet layers already arrive a tick sooner.
9. **Brindle's dug-up core does not colour his music.** His arc stays as it is; the cracked plate gets only a Geiger tick.
10. **The title's beacon.** Dark on a fresh profile, so the first Cherenkov blue belongs to stage 1's Warden. After your first win the title's beacon lights, because the world remembers too. V1 re-renders the frame when next touched.
11. **Break-free plays your class.** The demo hardcoded Sable's interval; the rule was always the current class row.
12. **Progression's glyphs join the visual language.** A variant notch on ability icons, class-shape milestone pips under the emblems, an unearned-variant silhouette in dull petrol at 40% (not slate), and Pressure's pre-filled notches on the difficulty bar. V1 specifies, V2 draws.
13. **Every Fleet crew figure is an animal, and no pilot shares Brindle's badger.** V3 must not copy the sheets where they slipped.
14. **The gorge sounds by height.** Undercroft adds the reese and sub, the shelf is the theme, the sky adds bells and the arp, and each of the five transitions gets one ride-family sound. The landmark hums home: a sub pulse on bar 1 of each phrase, panned toward the tower.

Handed to you: sidegrades in the demo, the full kit at the start, unlock timing, the Mind across runs, Pressure gating, what Moss is, the arena's ending, and Moss's voice (below).

## Callbacks found

The running list lives in `STORY-THREADS.md` §5; one line each here.

- C1 The rice cooker: the stage clear cadences with two "done" beeps. Built.
- C2 Brindle quotes the three stages in reverse. Built.
- C3 "Too heavy for you": Moss's heft-locked top shelf, the Potion Seller homage. Spec.
- C4 The vault's octave leap: speed ×1.8, pitch ×2. Spec.
- C5 The Fleet motif is Brindle's brass lean, one layer per difficulty tick. Spec, demoed.
- C6 The Mind plays your tune back upside down, one note wrong. Spec, demoed.
- C7 Tenacity's cymbal choke is Rivet's ignored-hit choke. Spec, demoed.
- C8 "Inventory does not wake": the codex line for breaking a Warden before the stage's first tick. Spec (merged with the progression board's version).
- C9 The shop bell is the rice cooker's "done" beeps. Proposed, demoed.
- C10 The Requisition's cracked plate shows a blue seam: it runs on a dug-up core. Proposed, in the arena frame.
- C11 Scattered drones follow the ball, seamless and buzzing, and can be led into pins. Proposed.
- C12 "Do not open until clear": a valve beside a reactor vent blows it early from outside the footprint. Proposed.
- C13 The Mind's codex page lists the three triggers you fired most. Proposed.
- C14 Moss notices you died holding scrap. Proposed.
- C15 to C17 The three pilot barks are the three special milestones. Spec (progression).
- C18 The landmark hums home. Proposed, now Wave 3.
- C19 Strike, Spare, Turkey: bowling scores for pin chains. Spec (progression).
- C20 "Everything that flies was taught by something that fell": Kest's rocket jump off a 20 m drop. Spec (progression).
- C21 Pressure valves on the bay's exit wall, smashed open on the way out. Spec (progression, later).

## Questions for Andrew

Eight, ranked by how much each changes what gets built. The first option is the default in force.

1. **Should any sidegrade ship in the demo?** The built characters branch on literal ability ids, so variants need a dispatch refactor before the alpha.
   - A. Ship the nine milestone counters, the summary pips and the codex bark entries; alternate smashes land after your alpha notes, once the dispatch table exists.
   - B. Do the refactor now and ship the alternate smash flavour for each pilot in the demo.
   - C. No mastery in the demo; counters only, nothing shown.
2. **Full kit from the drop, or the Bible's unlock during world one?** DESIGN-V2 gives LMB, RMB, F and Ctrl from the start; the Bible unlocks the main skill and ultimate in world one.
   - A. Full kit for the sketch; the bar always reads four keys. A later Bible card decides production.
   - B. F unlocks mid-stage-1 (a first-run lesson), Ctrl from the drop.
   - C. Both F and Ctrl unlock in stage 1.
3. **Moss's voice, after listening to demo 12.** Is the babble charming or grating?
   - A. Babble as demoed: one blip per letter, pitch climbing with exasperation, a sigh on the relent.
   - B. Babble, but calmer: no pitch climb, shorter lines.
   - C. No voice; speech bubbles and the bench clank only.
4. **What is Moss?** The Bible leaves the species open; the workshop frame shows a closed shutter.
   - A. Unseen: a voice and a pair of hands behind the shutter, with a hatch at ball height.
   - B. Seen once, late: a silhouette in the hatch after the first relent.
   - C. A visible animal keeper from the start (name the species, or leave it to the look lead).
5. **When do mastery unlocks apply?**
   - A. Shown at the summary, applied from the next run; a run never changes shape halfway.
   - B. Applied at the next Moss visit in the same run.
6. **Does the Mind's hand learn across runs?**
   - A. Within a run only for the demo; the across-runs seed (last run's rebound-to-vault ratio sets the stage-3 Warden's opening brace) stays a hook, off.
   - B. On from the demo: one fact per pilot, telegraphed like any brace.
7. **How does Pressure open?** (Later than the demo either way.)
   - A. Each valve opens after a win at the level below; Scrapless and the par timer are free from run 1.
   - B. All five valves open at the first win.
   - C. All valves open from the start.
8. **How does the arena end?**
   - A. Brindle routed, then one Cherenkov flicker across the dug-up housings on the summary: the second act felt, never stated.
   - B. A clean victory; nothing wakes.

**Defaults for everything not asked.** Rivet's sprint ignores the Warden's magnet pull for up to 2 s, judged at the alpha. The audio board's other listening questions (1 to 10, 12, 13) are answered by listening: anything you do not flag is kept. The title beacon, the plating tint, the callout chime and the relent sound are ruled above. Brindle's core does not colour his music. Pressure does not change the music.

## What gets built next

Wave 3, with each unit's must-notes from this reconciliation. The full routing is in `SOUND-STORY.md` §7 so packets can quote it.

**W6 stage.** The gorge with its three heights and five speed-preserving transitions, the contraptions (lifts, launchers, valves) and at least two terrain events. Must: layers by height on the stage theme's core with W5; a ride-family sound per transition; the launcher's whistle rises and is steam, the projectile's falls and is pure; telegraphs on the game frame, the stinger on the beat, the collider-swap sound on the swap; the landmark's sub pulse (C18); C12's valve beside a reactor vent.

**W7 enemies.** Five or more Fleet units with unique mechanics, one ancient per family, the three family Wardens, pack composition. Must: two timbre families, one mechanic tag per entry; `pack_arrived` with the faction motif and the faction icon at the screen edge; the plating dress (class-colour rim and crack glyph for "now", closed plates for "not yet"); every crew figure an animal; the Mind's quote as its telegraph, within a run only; C11's follow state seamless and buzzing; C10's blue seam behind the cracked plate.

**V3 Blender hero assets.** The three shells with visible pilots, accretion chunks, the reward gate, the Warden clamp with family kits. Must: shapes from the sheets, not their surface; ancient enamel capped at dull petrol with charcoal-grooved blue seams; Kest's satchels in horizontal amber bands; no badger pilot; the variant notch, milestone pips and Pressure notches specified in VISUAL-LANGUAGE §5 before V2 draws them.

**W5 audio, the rest.** Must: `mastery_earned` distinct from the release; the relent's sigh, clunk and chain; the shop bell for purchases only; `pack_arrived` and the ancient arrival; break-free on the current class; `pressure_opened` as a valve; the gorge by height and the transitions with W6; the gauge-charge and charge-pip cues; game wiring so play drives every layer the demos drove by hand; the Moss memory lines keyed to the unified table; no MUSIC-GEMS entry lost.

After Wave 3 merges you get the alpha, and your notes steer the polish waves.
