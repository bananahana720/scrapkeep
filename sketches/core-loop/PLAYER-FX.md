# Player effects

**Status: built on `claude/vfx-player-7nzoed`, 17 Oct 2026. Feel and Forward+ look need Andrew's machine.** Code: `src/presentation/player_fx.gd`, wired from `presentation.gd`. Test: `tests/player_fx_test.gd`. Stills: `tools/player_fx_capture.gd`.

This layer adds the player-side effects the tone bible (TONE-BIBLE.md, project files) asks for that `vfx.gd` did not draw. It reads committed facts and the ball's motion only. It never decides an outcome (TADR-008). It does not change the existing trails, speed lines, hit sparks, kill pops, synergy rings or the cosmetic trails such as Cable Stitch. It adds to them.

## What it adds

| Layer | What you see | When | Colour means |
| --- | --- | --- | --- |
| Might | Every layer below scales with one 0 to 1 value built from heft class, parts, tree picks, synergies and fusions | Always | n/a |
| Aura | One mote per part orbits the ball (12 at most). Motes flare white on each hit. From "grown" they stretch into streamers at speed. A new part drops in from above and settles into the ring | Parts held | The part's element: frost green, arc cyan, kinetic sand; rare and relic parts are lighter. Runs toward heat orange as the build grows |
| Boon burst | A second spark burst on each hit, up to 40 particles at their base size and reach | Might 0.25 and up | The build's most common element, run toward heat orange |
| Hit glyphs | `vfx.gd` hit and kill glyphs grow by 15% at most with might. The slam ring stays at the slam's real reach | Always | Run toward heat orange as the build grows |
| Sound words | Comic words stamped beside big moments: KLANG, WHUMP, KRUNCH, FWOOSH, KA-BOOM, BOING, VRAAAM, KACHUNK, FUSED, KRA-KOOM, WHAM, STRIKE, PAID | Big moments only, never ordinary hits | Pilot colour for your moves; brass for growth; heat orange for overdrive |
| Overdrive | White-hot rim on the ball, flame flecks and a hanging ember trail behind it, an ignition ring, VRAAAM and an impact frame | Speed at or above 60 m/s, off below 54 m/s | Heat ramp: white, orange, deep red, smoke |
| Carve sparks | A grinding spark spray from the contact point | Grounded on banked ground (normal up share under 0.82) at fast tier or above | Hot brass |
| Dunk charge | A thick coil with a dark ink rim glows on the collar's rear arc, level with the ball and behind its line of travel. Three studs ride on top of it and burn; they go to ink one by one as the 3 s window runs down, so the count reads at play distance. The coil pulses faster near the end. It clears when a reel impact spends the charge or the window ends | An air slam has stored a dunk charge (`dunk.gd`) | The pilot's class colour, emissive on a dark base so the hue holds; never mint for every pilot, no chevron |
| Power column | Streaks rise from a ring round the ball | Heft class up, a fusion | Brass, or the fused part's colour |
| Impact frame | Ink focus lines in the outer fifth of the screen, aimed at the hit, for 3 rendered frames. A hot build adds an edge wash: dark at the screen edge, heat orange further in, gone before the middle | Smash at 32 m/s (18 m/s when mighty), blazing ram, every contact hit and slam from "grown", ultimate landing, bowled rack, overdrive ignition | Ink with a few white lines; a hot build burns every third line orange |

### On the beat

Andrew, Q10 "Sound only" (17 Oct 22:12Z): a hit within 80 ms of a beat the player hears pays in sound and look only. `audio.gd` adds a clap, `onbeat_clap`, over the hit, at most once a beat, about at a ranged hit's level, 8 dB under where the sax stab sat. It was a sax stab until 13 November 2026, when Andrew heard the feedback fighting the melody; the clap joins the band's drums and carries no pitch (SOUND-BIBLE rule 7). The render is at `res://assets/audio/sfx/onbeat_clap.wav`, made by `design-v3/sound/feedback_set.py`. If the file is ever missing, the cue log says "absent". The hit's own sound plays first, on the hit's frame. `player_fx.gd` then makes that hit's word 1.4x bigger, or stamps BWAP when the hit earned no word. BWAP keeps the same placement rules as every sound word (see Readability rules). Damage never reads the beat. Test: `tests/on_beat_hit_test.gd`.

### Pilot voices

| Pilot | Their words |
| --- | --- |
| Sable | ZWOOSH on a launch |
| Rivet | PING on a smash: precise, never misses |
| Kest | BOOM on a slam or rocket jump: commits all at once |
| Tarn | GRRAK on a smash, KRASH on a slam: the machine snarls |
| Tally | KA-CHING on a smash; PAID stamped when two go down together |
| Cannon | KA-THOOM on a launch, THOOM on a smash |

### Knockback moments (with the Knockback thread)

- **Bump** (a ram at cruise): no word, no frame. It should feel small.
- **Launch** (a ram or slam at blazing tier): WHAM and an impact frame.
- **Hulk bowl**: the third `enemy_pinned` inside 0.6 s stamps STRIKE in brass, with an impact frame.
- **Keystone landing**: a landing at 24 m/s or more says KRUNCH.

Hit-stop and shake stay in `juice.gd`, owned by the Knockback thread.

## Growth rule

Andrew tapped "Presence, centre clear" (17 Oct 17:28Z): a grown hit reads mightier through colour heat, bigger words, edge ink and the part aura. The middle of the screen grows 1.25x at most, so the crowd behind a hit stays visible.

- **Colour heat** is the main lever. `heat_k` runs from 0 at might 0.1 to 1 at might 0.7 (a heft IV, four-part, four-pick build is about 0.8). Boon sparks, aura motes, words, `vfx.gd` hit and kill glyphs and the impact frame's accent lines all run up to 85% of the way to saturated heat orange, never to white.
- **Edge ink**: from "grown", every contact hit and slam earns the impact frame, with bolder ink and an edge wash that dips dark at the edge and glows orange further in.
- **Brighter cores**: hot hit glyphs carry up to 1.6x the light and boon sparks up to 1.8x, at the same size.
- **Nothing grows in the middle**: the boon burst keeps its base size and reach, the column no longer rises on a slam, and hit glyphs grow 15% at most.
- Cannon grows the same way, since its slam already fills the screen.

## Readability rules

- **Warnings draw on top** (Andrew, 17 Oct 16:36Z). Every material here sorts at render priority -4, below the threat marks (39 to 42). Words are transparent and write no depth. The test checks this.
- **The lane ahead stays clear.** A word placed within 2.5 m of the ball's path, up to 30 m ahead, is pushed sideways. Words run away from the ball and stay inside the middle 78% x 70% of the screen. The impact frame draws only in the outer 20% band.
- **The fight stays visible** (PF-26). A sound word, BWAP included, keeps off every foe on screen, the marks over a foe while it shows one, the damage numbers rising now and every hostile warning, or goes unsaid. Where a word stands: the asked spot, its mirror across the ball, the spot above a named foe, then four fixed spots beside the ball (at the ball's height out to the side the word was asked on, then the other side, then the same two lower), each pushed out of the lane ahead of the ball and inside the safe area; the first clear one wins, so the same frame gives the same answer. A word that finds none is held, and `spawned` counts why: `held_warning`, `held_foe`, `held_marks`, `held_number`, `held_safe` (the asked spot's first blocker).
  - **Foes.** A foe answers for its own silhouette. Brindle's hull piece reports the ship through `screen_bound_boxes()`: oriented boxes in each part's own frame, so a turned ship stays tight. They are the model's hull, bow ram, cockpit shield, crane masts and elbows, deck dressing, armour panels (while shown), one box for the drums and hatches on the hull's sides, and the crane cables. Not inside them: the magnets, caps and sockets (strike pieces of their own, listed as foes themselves), the name plate and the posture ring. Any other foe is measured from its meshes.
  - **Marks.** The 3.6 x 2 m rectangle over a foe is reserved only while its owner says a mark is showing (`marked(foe)`: status_marks.gd for the interrupted star, machine_fx.gd for the stagger window). The class icon is a mesh under the foe, so its body already holds it.
  - **What is on screen.** Every foe rect is cut to the viewport (convex hull of the projected box, cut to the screen), so a box that only passes beside or behind the camera adds nothing. A foe counts when any part is on screen, even with its origin behind the camera; one under 24 px with no mark is skipped. Hostile-warning rects are unchanged (see the receipt below).
  - **Not covered.** The read words (DENT, ZZAP!) avoid only warnings and their own foe's body and stack: they stand beside that foe by design. Also machine_fx's foe-side words, world label text, HUD tags, enemy shots, weak parts of the world 2 and 3 bosses.
  - **Measured** (skipper bot, `--table=park --final-world=1 --until=2`, seeds 1 and 2): words stamped over the whole run, base against this change: seed 1 51 against 45, seed 2 44 against 36; in the Brindle fight, seed 1 27 against 24, seed 2 10 against 8 (the base figures are the verifier's, d61791ec1). Held attempts on this change, by the asked spot's first blocker: seed 1 warning 120, foe 62, safe 15; seed 2 warning 92, foe 48, safe 18; marks and numbers 0. A held attempt is asked again on the next hit, so held counts overstate. Whole-screen hostile warnings were most of the warning blocks (161 of 253 and 138 of 219 warning rects read were 90% of the screen or more) and only 1 and 8 of those were near-plane clip artefacts, so they are real and warnings were left alone
  Tests: `tests/player_fx_test.gd`, `tests/player_fx_brindle_test.gd`.
- **Caps.** At most 2 words alive, 0.35 s between words, 1.2 s before the same word repeats, and no words or boon bursts in the densest density band. Impact frames are at least 0.6 s apart.
- **The edge wash** dips the screen edge dark (80% at most), glows orange further in (40% at most) and is gone before the middle, for the same 3 frames as the ink.
- **Reduced motion** turns off impact frames and the stamp overshoot and slide of the words.
- Word size is a share of the screen height (7.5% at size 1.0), so a word near the camera never swallows the ball.

## Cost

| Effect | Particles, most alive | Draw calls | Notes |
| --- | --- | --- | --- |
| Overdrive flecks | 96 | 1 | Ball attached, only while burning |
| Overdrive embers | 64 | 1 | Same |
| Overdrive rim | n/a | 1 | 24 x 12 sphere, additive fresnel |
| Carve sparks | 64 | 1 | Only while carving |
| Power column | 2 x 48 | 2 | One-shot |
| Boon burst | 3 x 40 | 3 | One-shot, 60 ms between bursts |
| Aura | n/a | 1 | One MultiMesh, 12 instances |
| Words | n/a | up to 2 | Label3D |
| Impact frame | n/a | 1 canvas item | 3 frames |

The particle ceiling is 440, beside `vfx.gd`'s 752. No lights. Script cost measured headless with every layer live: about 20 µs a frame. GPU cost is not measured yet: the cloud has no GPU. The frame-time check on the RTX 4080 belongs to the machine gate.

## Checks

- `tests/player_fx_test.gd` (114 checks): might, the word caps and lane rule, the pilot voices, the knockback moments, overdrive hysteresis, carving, render order and the particle ceiling.
- `xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path sketches/core-loop -s tools/player_fx_capture.gd -- --out=DIR [--pilot=N]` writes the stills. They use the Compatibility renderer on llvmpipe, a slowed clock and a frozen ball posed through `PlayerFx.pose`, so they show shape, colour and placement, not Forward+ glow.

## Open

- The overdrive look reads speed itself. When the wave 17 soft-cap gameplay lands, it should switch on the same fact.
- Sounds for the words come from the music thread. Each word names its event, so a cue can pair with it.
- The companion thread's assist words (SPIL-9) should go through `word()` so they share the caps.
