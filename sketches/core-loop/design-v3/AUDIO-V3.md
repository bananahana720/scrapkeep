# Audio v3: the Drop Loop as music

Design for music and sound in core-loop v3 (`design-v3/LOOP-REDESIGN.md`). It applies `SOUND-STORY.md` (registers, motifs, mix, Moss) and `src/presentation/MUSIC-GEMS.md` (G1 to G11, R1 and R2) to the fun lab's Drop Loop, and says what changes under Laps. Nothing here swaps a gem; every new element is a layer on a named game-state threshold, and every payoff lands on the gameplay moment (G11). The audio lead owns this file; the coordinator integrates.

Sources read: `SOUND-STORY.md` in full; `MUSIC-GEMS.md`; `music_engine.gd` (layer setters at 660 to 695, `escalate` 596 to 627, `_trigger_house` 1556 to 1612, `_trigger_break` 1613, `_retarget` 1309, `_mix` 2106, `_soft` 2251); `audio.gd` (25 to 60, 774 to 846); `harmony.gd` (1 to 60, 128 to 197); `sfx_bank.gd` (hold loops 878 onward); `DESIGN-NOTES.md` writer C, W5, W5b, W9; `LOOP-REDESIGN.md` §2, §6, §7, §8, §9; playtest entries 7 and 8. Receipts are in §9.

**The one sentence.** The stage is one song with a verse you lap and a chorus you drop into: the shelf is the verse in the level theme, the lip is the pivot bar, the Warden's telegraph is the build, the open window is the held breath, and the landing is a drop the player caused. Four landings are four choruses, each a step up the ladder, and the break is the biggest drop of the stage.

## 0. The grid, the numbers this design counts in

| Fact | Value | Source |
| --- | --- | --- |
| Band tempo and grid | 172 BPM; a sixteenth is 3846 samples (87 ms), a beat 349 ms, a bar 1.395 s | `harmony.gd:8-14` |
| Club tempo | 129 BPM; a 172 bar is exactly three 129 beats, so the pivot bar of half-note triplets lands on a 172 beat | `harmony.gd:25-28`, G3 |
| Telegraph | 2 s (1.5 s at 75%): 5.7 band beats, 4.3 club beats | LOOP-REDESIGN §2 |
| Open window | 2.5 s reactor, 4 s hive, 5 s Mind, +1 s per bonus core, +0.1 s per held-door weapon hit up to 2 s: 5.4 to 15 club beats | LOOP-REDESIGN §2 |
| Recover | 0.4 s, about one club beat | LOOP-REDESIGN §2 |
| Lap | 25 to 40 s, 18 to 29 band bars | LOOP-REDESIGN §1 |
| Drops to break | 3 to 5 at heft I, 2 at heft III; the badge counts segments | LOOP-REDESIGN §1, §2 |
| B arc thresholds | lift at 0.5, break at 0.75, payoff by the caller | `music_engine.gd:101-102`, G11 |
| Club floors | build 0.55, lift 0.7, break 0.85, drop 1.0 | `music_engine.gd:96` |
| Sidechain pump | 0.65 in the club's build, lift and drop; off in the break | `music_engine.gd:1327-1331` |
| Ducks | a priority 2 cue ducks the band to 0.55 for 0.35 s; a danger cue ducks the bass to 0.3 for 0.45 s, back over a beat | `audio.gd`, `tools/audio_board.gd:105-111`, `music_engine.gd:85` |
| Polyphony | 32 SFX voices; per-cue limits and gaps; band voices uncapped today | `audio.gd:27-36`, `music_engine.gd:913` |
| Soft clip | clean under 0.75, tanh knee above, never full scale | `music_engine.gd:2251-2255` |
| Master reference | -14 LUFS integrated, -1 dBFS sample peak (the board's mastering) | `tools/audio_board.gd:21-22` |

## 1. The Warden fight as music

### 1.1 The form of a lap

The Warden is in sight from the entry drop, so the fight is the whole stage, and the music cannot be "level, then boss". It is one arrangement with two rooms, read from where the ball is (`Features.BOWL_OUT`, r > 62 m, LOOP-REDESIGN §4) and what the Warden is doing (§2's five states). Every transition below already exists in `music_engine.gd`; v3 adds one section (`open`) and one harmonic hold (the drop-line sus).

| Lap beat | Ball | Warden state | Band | Engine call (existing unless marked new) |
| --- | --- | --- | --- | --- |
| The shelf | outside the bowl | closed | The stage theme at 172 (G1, G5), pressure from the director, the snowball layers of §3. The family's idle tick sits under it: Geiger once per 4 s, the quartal hum, the wrong motif fragment on sine, at -18 dB. | `set_theme`, `set_pressure`, `set_fleet_ticks`, `set_class_motif` |
| The lip (drop-line commit) | past the lip's approach lane | closed or telegraph | The pivot bar: a bar of half-note triplets whose pulse becomes the 129 quarter (G3), and the keys hold the dominant sus from this bar (§2.3). The lip is where the player commits, so the pivot is the player's. First lap only under the recommended policy (§1.4). | `begin_boss("warden")`; **new** `hold_dominant(true)` |
| The air (telegraph) | on the drop line, in the air | telegraph, 2 s | The club's build section, dark: four on the floor, the funk octave bass, dark filtered stabs, the pump. The ratchet clicks are the world's clock on the game frame (`threat_tick`); the band's snare roll tightens with the same clock, quarters to eighths to sixteenths, and the low-pass closes toward 700 Hz. The reactor's Ab pedal comes in under the bass. | `start_build(telegraph_seconds)`; `set_reactor_pedal(true)` (reactor only) |
| Open | arriving | open, 2.5 to 5 s | **The held breath.** The clang lands on the beat, the family chord snaps open (§1.3), and the band thins to the pump loop: kick off, the sub and the stabs pumping, hats in sixteenths at half level, the bass ducked to 0.3 and held (the same duck a hold loop uses, `duck_bass`), the filter open. Each held-door weapon hit adds one ready-pulse tick on the next sixteenth. The window is a suspended chord waiting for a downbeat. | **new** section `open` on the warden track; `duck_bass(0.3, window)`; **new** `door_tick()` |
| Landed | on the core, then off it | open, then recover | **The drop.** On the impact frame: the reward-ladder note one rung per segment cut (`boss_weak_hit` shifted by `pentatonic_step(segments_cut)`), the rebound spring snap pitched by impact speed, and the band's gap (`drop_now` cuts the band on the frame it is called, `music_engine.gd:735-736`), so the silence itself is the instant answer. On the next beat, at most 465 ms later at 129: the club's bright drop section for 4 bars, crash on bar 1. `free_bass()` on the impact frame so the low end comes back as the ball leaves the core. Landing in the window is the only way to hear the bright stabs before the break. | `drop_now(4, 1.0)`, `free_bass()` |
| Missed | on the floor inside the core ring, or in the air past the window | punish, then recover | No drop. The breath releases into the dark build: the roll dies, the filter closes, the pedal drops out with the vent (`reactor_erupt`), the family's punish sound in its timbre (§1.3). Dark means you missed; bright means you landed. The bass stays ducked until the pulse throws you clear (the crater ring is a hold in the reactor's timbre). | `cancel_build()`, `duck_bass` held by the crater |
| The bank and the lift | riding the bank into the return | closed | The club's build section, dark or bright by escalation (§1.2). The lift's fire is a launch: the build with the rice-cooker climb on A7b9 (G2), and the shelf landing is the drop back into the shelf's music. The return is a ride, and every ride in this game ends on a beat going faster. | `end_boss()` cadence, `start_build(1.6, true)`, `drop_now(4, 0.85, {}, theme)` on the shelf landing |

Every lap therefore has G3's transition (the lip), G9's build and drop (the telegraph and the landing) and the loved core underneath (the club is round 2's, `_trigger_house`, untouched). The shelf keeps the level theme, so G5's palettes are heard every lap, and Sluice's clav and Weir's organ ride the club as they already do (`music_engine.gd:1590-1600`).

### 1.2 The reward ladder is the escalation

`escalate(fraction)` is the one arc (G11). In v3 its fraction is **segments cut over segments total**, published by the Warden on each landed drop, never elapsed time or chip damage:

| Segments cut | Fraction (4 drops) | What the band does | Where the player hears it |
| --- | --- | --- | --- |
| 1 | 0.25 | The landing drop. The reward-ladder note at rung 1. | The first bright chorus |
| 2 | 0.5 | The lift: a pickup bar on the new key's dominant, the key up a half step, the lead an octave up, the arp in (G7). The shelf's theme lifts too, because `key` is the engine's. | The whole stage is in Eb from now on |
| 3 | 0.75 | The sinister break: half time, the bass walking the tritone, the flat second, the choir, and a build that tightens with every held-door hit (G7). | The third telegraph is the darkest |
| 4 | 1.0 | The payoff: the unseal drop, the heaviest drop of the stage, eight bars home in D, the clamp tearing loose, the bells climbing out, then the cadence to the level at 172 (G2, G9). | The break, on the beat of the landing |

At 3 or 5 drops the thresholds still hit at the same fractions (0.33 and 0.67 cross 0.5 and 0.75 at the second and third drops of three; at five, the third and fourth). Heft cutting the drop count makes the ladder climb faster, which is growth you hear (item 70).

Missed drops never move the fraction, so the ladder never chips (LOOP-REDESIGN §2, "I am getting somewhere"). The Warden's hits-in-window (`boss_weak_hit` climbing the pentatonic as integrity falls, item 71) become the held-door ticks; the ladder is the segments'.

### 1.3 Per family

Each family answers the same five states in its own timbre (SOUND-STORY §2: the ancients are hum, sub and sine; each has one harmony no other uses).

| State | Reactor (stage 1) | Hive (stage 2) | Mind (stage 3) |
| --- | --- | --- | --- |
| Closed, idle | One Geiger tick per 4 s | The quartal hum, D5 G5 C6 F6 stacked fourths at -20 dB, gated in sixteenths | Your motif's first two notes, inverted, on sine, once per 8 bars |
| Telegraph, the clock | Geiger ticks accelerating with the charge (exists: `vent_charging` carries the time), the Ab pedal under the bass (`set_reactor_pedal`) | The guard rack forming on the drop line: the unison buzz snapping into the quartal chord (`swarm_lock`); the chord is the rack | The read: the inverted quote once (`mind_quote`), then the lens opens on a sine drone of the quote's wrong last note |
| Open, the chord snaps | The pedal drops out with the vent (`reactor_erupt`'s boom and the floor falling away), the tritone resolving is the door opening | The rack scatters as the ball bowls through it (`swarm_scatter`, the chord breaking into detuned single notes on the frame) and the cell is open in the same motion: the army is the door | The brace: the drone bends 3 cents flat and holds; the lens is open for 5 s |
| Punish | The crater: a burning ring as a hold loop in the Geiger crackle on Ab, 5 s; the bass ducked while the ball is in it | The dive: the swarm chord on a falling glide, the sting on the frame | The lane down your last line: the lane hum on Ab, then the tear (`threat_hum`) |
| Recover, a segment cut | The reward note on the ladder; the pedal off | The reward note; a scattered guard re-forms in 10 s as the unison buzz creeping back (the timer is audible) | The reward note; the jaws sag as the drone falls a fourth |

Only the reactor colours the band (Andrew's ruling, SOUND-STORY §2 item 3, DESIGN-V2 §11). The hive's chord and the Mind's quote stay effects, and the drop's payoff is the same club drop in every family.

### 1.4 The pivot policy (question 1 for Andrew)

Two ways to place G3's pivot bar in a fight that laps.

- **Once per stage (recommended).** The first drop-line commit pivots to the club at 129, and the stage stays at 129 until the break: the shelf laps play the club's build section (dark before the lift, bright with the lead after it, the sinister break after three quarters), with the level's own voice on the club (clav, organ, the sax lead) and the level's calm bass figure under the funk bass (item 58). The shelf landing is still a drop (`drop_now` on the warden track). The level theme owns the entry drop's first 20 s and returns at the cadence after the break, as today. One big transition, the way Andrew heard it; no tempo flips.
- **Per lap.** The lip pivots every lap and the return lift's cadence brings 172 back every lap (`end_boss`). The level theme is the lap's music and the club is the bowl's. G3 is heard four times a stage, and the tempo flips every 25 to 40 s.

Recommend once per stage. A tempo flip every half minute reads as indecision, not as an event, and the club already carries the level's voice. Per lap is a one-line lab toggle (`warden_pivot: once | lap` in `tuning.gd`, read by `audio.gd`'s bowl listener) so Andrew can hear both in the sitting.

### 1.5 Under Laps

The Warden is dormant until the beacon is charged, so the club never starts before the wake. Each lap checkpoint adds a layer and never swaps one: the lap notch is `lap_checkpoint`'s tick on the pentatonic rung of the lap count, `threat_rose` per lap adds a Fleet layer (`set_fleet_ticks`), and the beacon's charge climbs the reward ladder as it does today (`_on_beacon`). The bell's third strike is the pivot bar, and the fight is the v2 arc unchanged (`warden_charge` on integrity). Laps is the control for whether "the drop I caused" beats "the drop the boss caused".

## 2. The loop as music

### 2.1 Anticipation as harmony

The band's home is Dm9, and the one chord that wants it most is its dominant. The launch build already holds A7b9 and the landing resolves it to D (G2 restored, item 61). v3 makes that the grammar for every ride and every drop line:

| Where | Harmony | Why it wants the landing |
| --- | --- | --- |
| On a drop line, from the lip's approach lane to the landing | The keys hold **A7sus4** (A D E G over A): the suspension is the ball in the air, and the 4 (D, home) is already in the chord, waiting to become the root | A sus chord has no third, so it cannot rest; the ear leans on the resolution the way the ball leans on gravity |
| The last beat before the window opens | The sus gains its b9 (Bb): A7b9sus, the launch build's own chord (G2) | The flat ninth is the sinister degree in the reward's own chord: danger inside the promise |
| The landing in the window | Dm9 on the drop's downbeat, bright stabs (G3's drop) | Resolution, on the beat |
| The miss | The sus does not resolve; the dark build's Dm9 arrives under a closed filter with no crash | Same home, no light: the chord was answered by the wrong room |
| The return lift's flight | A7b9 with the rice-cooker climb (G2, unchanged) | Every ride in this game ends dominant to tonic |
| Moss's exit pad | A7b9 over the lounge, the landing drop in the next stage (G2, unchanged) | |

The hold is one engine flag (`hold_dominant`, §8 AU1): while it is on, `_chord(bar)` returns `Harmony.DOMINANT` with the third removed for the keys and the sus tones for the lead, and the bass keeps the level's figure on A. It is a harmonic mask like the lounge (`LOUNGE_GAINS`), so no gem moves.

### 2.2 The lap's dynamics

The lap is 18 to 29 bars, long enough for the Pyramids re-voicing to turn over four to seven times (`ROTATIONS`, every four bars, G10). The lap's shape in the band:

1. **The shelf landing** (bar 0): the drop into the shelf's music, every layer in, a crash. Loud, bright, the ball fast.
2. **The choice** (bars 1 to 4): the east landing's sightline. The band settles to the director's pressure; the tone filter eases toward its calm colour if the pack is far.
3. **The line** (bars 5 to 12): scrap ticks climb the ladder, the fabricator hoop's chime, a pack bowled through on the lip (kill chain rising). Pressure and the snowball layers carry it.
4. **The lip** (bar 13 or so): the sus holds, the arp switches to its ascending shape (`ARP_SHAPES[0]` pinned while `hold_dominant` is on), the riser starts with the telegraph.
5. **The air and the landing**: §1.1.

"You're on a drop line, the window's coming" is therefore three things with no words: the chord changed to one that cannot rest (harmony), the arp turned into a run upward (line), and the ratchet started counting (the world). Any one is enough with eyes closed; together they are the same fact in three layers, read from one flag.

### 2.3 The bowl rebound and the bank

The rebound off the core is the player's own contact: the spring snap pitched by the enemy's weight over heft (SOUND-STORY player table) on the frame, and `free_bass()` on the same frame, so the low end returns as the ball leaves the core. The bank ride is the pump: the club's sidechain (0.65) is the ball breathing up the 24° bank. A deflector rebound on the bank (the ×1.8 vault) is the snap plus the octave leap in the class instrument, as ruled.

### 2.4 The return contraption

A ride that does not feel like a ride is a stop (LOOP-REDESIGN §7). The lift is the launch grammar in full: the plant clack on arming (roll-through E), the bone gauge's rising pressure hiss through the cycle, the chuff and clank at fire (`steam_lift_fired`, the lab branch's row; its `sound_next` is `return_launch_arpeggio`), the launch build over A7b9 with the rice-cooker climb, and the shelf landing's drop. The geyser (stage 2) and the cannon (stage 3) take the same grammar with their own ride-family voice (rising steam whistle; a bang and the rail whoosh). The launch arpeggio is pitched by throw speed (85% of arrival speed), so a fast lap sounds faster on the way back up.

### 2.5 What the research gave this design

`design-v3/research/R3-adaptive-music.md` (Haiku web scout, this session, 104 lines; web summaries, leads not facts). Taken, adapted or refused:

| Lead (R3 section) | Verdict | Where it lands |
| --- | --- | --- |
| Sound on input, music on the grid: an immediate SFX over a quantized musical hit (Thumper, Tetris Effect, Rez, §4 and §5) | Taken; it is already the director's rule (writer C item 1) | §1.1 Landed: the contact and the band's gap on the frame, the drop on the next beat |
| NecroDancer's ±250 ms window "felt best" (§3, documented) | Taken as a bound: our quantized drop waits up to 349 ms at 172 and 465 ms at 129, past that feel threshold, so the frame must carry an answer of its own | The gap, the reward note and the snap are that answer; measured in §7's grid check as "now" cues within one frame |
| The ratchet as a separate high-priority percussion layer, HDR-style, ducking others by about 4 dB (§6) | Taken; SOUND-STORY §4 already reserves 8 threat voices, and the priority 2 duck to 0.55 is about -5 dB | §3.3: the duck scales with intensity, threats never stolen |
| Pre-entry pickup bars and post-exit tails (§7, Wwise and FMOD) | Already ours: every key change passes through a pickup bar (`_queue` with a transition), every boss end through the cadence | §1.1, §1.2 |
| Stems by boss phase, all committed at the climax (Hades, §1) | Already the B arc's shape; refused as stem swapping: layers add, never swap (G11) | §1.2 |
| Autocalibrating the beat to the player's drift (NecroDancer, §3) | Refused: the window is the judge, not the beat; the player is never graded against the grid | none |
| A virtual drummer varying with intensity (Ape Out, §5) | Refused as new voices; the rotation table already turns the texture over every four bars, and evolutions pin it | §3.2 |
| Environmental hazards as percussion voices (Thumper, §4) | Taken in one place: the Geiger, the quartal gate and the Mind's drone are the families' idle percussion and hum | §1.3 |

## 3. The snowball as music

### 3.1 What already stacks

The band has fifteen layers (`LAYER_NAMES`), of which six melodic ones enter one by one with pressure (pad 0.1, arp 0.3, choir 0.45, lead 0.55, echo 0.7, counter 0.8; item 51), the warm pad enters per bonus core (item 24), heft brightens the intensity 0.12 per class (item 70), the Fleet adds per difficulty tick (W5 note 6), the class motif seeds the counter on rotation 2 (W5 note 5), and the reactor pedal colours the sub (W5 note 7). That is eleven real thresholds already. The v3 snowball must not add a sixteenth layer for every new power; it adds **texture** on new thresholds and keeps the voice count flat.

### 3.2 One layer per power tier, never mud

| Threshold (real game state) | What it adds | Where | Voices added |
| --- | --- | --- | --- |
| **Power tier** (Systems' one integer: picks taken this stage, 0 to 8) | Reads as pressure: `set_pressure(director + 0.05 × tier)`, clamped. Tier 4 brings the lead in on a calm director; tier 8 is the full stack. | `audio.gd` pressure source | 0 (the six layers already exist) |
| **Evolution armed** (a part at cap with its pair on offer) | The evolution's socket glows; the band pins one re-voicing slot to the pair's shape for the next rotation only, as a tease: the arp takes the pair's shape for four bars, then the cycle resumes | `ROTATIONS`, one pinned slot | 0 |
| **Evolution landed** (at the break) | The pinned slot stays for the run: Spiral Wave + Double Feed pins the arp to its spiral shape (`ARP_SHAPES[2]`, up an octave); Chain Arc + Tesla Pylon pins the echo to bell at the fifth; Wrecking Ball + Ballast Drum pins the counter to the class motif in the tom and 808 register. Three evolutions, three slots, and the fourth rotation slot (the choir) stays free so the texture still turns over | `ROTATIONS` pins in `_revoice` | 0 |
| **Rule part taken** (Moss's hook, up to 3 per run) | A drum-grammar change, one per rule: "every rebound is a pin" doubles the clap; "drops open windows for everyone" deepens the pump to 0.8 in the club; "the clock's packs drop cores" gives the Fleet layer a brass answer on beat 4 | `_trigger_*` reads a `rules` bitfield | +1 hit per bar at most |
| **Difficulty tick per lap** | The Fleet layer, as today, 1 to 3 | `set_fleet_ticks` | +1 anvil hit per beat at most |
| **Bonus core socketed** | The warm pad, as today; and the window's +1 s is heard as the open loop lasting a beat longer | `set_overcharge` | 0 |
| **Heft class** | Intensity +0.12, as today | `set_heft_lift` | 0 |

Full-screen power at stage 3 is therefore the same fifteen layers at full gain with three re-voicing slots pinned to the build's evolutions and up to three drum accents. Nothing new is stacked; the band is remixed by the build, which is Pyramids' idea (G10) applied to progression.

### 3.3 Headroom, ducking and voice limits in a dense fight

Targets, to be set against the density spike's measurements (§9.2) rather than guessed:

| Rule | Value | Enforced where |
| --- | --- | --- |
| Band alone at full snowball | -16 LUFS integrated, so the cues' +2 LU lands the sum at -14; the drop's crash bar may reach -12 momentary | `tests/presentation_v3_test.gd` renders the densest state through the board's `lufs()` |
| Band voices | Cap at the densest measured state plus 25%; a new note past the cap steals the oldest note of its own layer, never a bass layer | `_start` in `music_engine.gd`, one check |
| SFX voices | 32, with the SOUND-STORY §4 budgets made real: 8 threat and hold (never stolen), 12 player, 8 reward and world, 4 UI; a class over budget steals the oldest of its own class | `audio.gd` `_admit`, replacing the per-cue-only limit |
| Threat margin | Every threat cue at least 6 LU over the band in the 400 ms after its start, at every state | measured per cue in the test |
| Duck scales with intensity | The priority 2 duck is 0.55 at intensity 1.0 and 0.7 at 0.3; a danger cue's bass duck stays 0.3 | `duck()` reads `_intensity` |
| Rewards never duck | A kill chain at any rung, a pickup at any combo, the ladder note on a landing: none calls `duck()`; they sit in the reward register above the band's filter | rows' priority 1 |
| Tails | At most two ringing tails of one family; threat tails never cut (SOUND-STORY §4) | `audio.gd` per-family tail count |
| Bass share | The sum's energy under 120 Hz stays between 30 and 45% with the duck on; a hold or the open loop takes it under 20% on purpose | measured per state |
| The filter is the ceiling | The tone low-pass (2.8 kHz calm to 16 kHz open) is the one thing that makes room: a dense reward burst at full pressure pulls it 20% toward calm for a beat, so the band steps back an inch instead of the cues getting louder | `_mix` |

## 4. Interactables' sound families

One register, one melodic idea and one prompt per family (LOOP-REDESIGN §9), so the player learns five things by ear. Every pitched cue is in the live key (`KEYED_SOUNDS`), every arm sounds on the frame, every payoff lands on the beat unless it is the player's own contact.

| Family | Register and instrument | Melodic idea (D home) | Arm / roll-through | Fire or payoff | Refusal or miss | Priority | Without looking |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **Travel** (lift, geyser, cannon, cable, the return) | The ride family: steam, rail hum, the launch arpeggio on mallet. Never a class instrument (a transition belongs to the world) | The rice-cooker climb up A7 (`LAUNCH_TUNE`), pitched by throw speed | Plant clack on E in the lane; the gauge's hiss rising through the cycle | The fire (chuff, bang, whoosh) on the frame; the launch build; the landing drop | Silence: missing the mouth costs nothing and says nothing | 1 | A ride armed, fired, and how fast |
| **Opt-in fights** (ambush altar, challenge post, call the Warden) | Brass and anvil, the Fleet's register: the arm is a stamp | The Fleet motif head, D Eb D: stamp, stamp, decree | The 0.35 s hold fills the class ring with a snare roll rising in gain; the arm is one anvil stamp on the beat | The pack arrives on `pack_arrived`; the miniboss riser for a challenge post; the Warden call is the tritone pickup bar (the sinister colour arriving early) | A tap does nothing and sounds nothing | 2 (arm), 3 (Warden call) | I started a fight, and how big |
| **Secrets and treasure** (cracked walls, buried caches, marble-maze vaults, codex fragments) | The sunken bell: the reward bell an octave down through a 900 Hz low-pass with a 2 s tail, panned toward the secret, one ping on bar 1 every 2 bars within 30 m, 4 dB louder per 8 m closer | A falling fourth, A to D, on the find (the reward ladder's first interval reversed: something old, not something earned) | E on a wall or plate; a smash or sprint at speed | The crumble on the frame, then the sunken bell's fourth, then `found_chime`; a codex fragment takes the fragment cue (three notes of the level motif at half speed, 6 dB under) | none | 1 (ping, priority 0), 2 (find) | There is a secret near, which way, and I found it |
| **Temporary allies** (pin-carrier drone, turret housing, lift drone) | The class motif on the Mind's pure sine, straight: the Mind quotes you wrong, the ally quotes you right. Kinship in one interval | The class motif's head, once every 2 bars while it runs, at -14 dB, an octave up | The 0.35 s hold; the wake is a Cherenkov flicker on bell (D6 A5 D6, 40 ms apart) and the scrap cost's dry ladder-down tick | The motif hum while it runs; its action is a small class-instrument cue (the pin-carrier's ram is a thwack a fourth up) | Can't afford: Moss's dry refusal bone, one interruption | 1 | Something is on my side and singing my tune; it just stopped |
| **Risk bets** (double-or-nothing crate, cursed cache, timed drop trial) | A drum roll, a slot-machine clunk, then a crack or a refusal: percussion first, so a bet sounds like a bet before its answer | The question is a tritone, D to Ab on the clunk's fbass; the win lifts it a semitone to A (the fifth, home's dominant); the loss drops it a semitone to G and stops | The 0.35 s hold is the snare roll accelerating eighths to thirty-seconds on the grid (`bet_roll`) | The clunk on the next sixteenth (an anvil at -6 dB plus the fbass on D2); the crack on the roll's answer: a snare crack and the rice cooker's two "done" beeps up a fifth (A5 D6) | The refusal bone: a dry 40 ms click and the fbass falling to G | 2 | I bet, the dice landed, I won or lost |

The timed drop trial is the bet grammar over the Warden's own clock: the roll is the trial's 20 s as a slow ratchet under the band (one click per beat, not accelerating), the crack is the landing's reward note up a rung, and the refusal is the trial expiring on a bar line with the click stopping.

## 5. Juice in the key: rules for W11

W11 owns hit-stop, camera kick, kill chains, pickup magnetism and pitch climbs, near-miss cues and damage-taken reads. Its sounds sit in this system under ten rules, all of which existing cues already obey (items 5, 17, 47, 71):

1. **Now or on the beat, by cause.** The player's own contact (hit, kill, pickup, near-miss, rebound, landing) sounds on its frame. A banner, milestone or chain-tier announcement waits for the next sixteenth at most (87 ms) and the next beat if it is a flow fact (`on_beat`). Nothing the player caused waits for a beat.
2. **Keyed, always.** Every pitched juice cue is in `KEYED_SOUNDS` and baked through `samples_at(id, step, shift)`, so after the lift it is in Eb like the band.
3. **Good news climbs the pentatonic, one rung per event.** The kill chain uses `_kill_combo`'s ladder (rung per kill within 1.5 s, cap 7); pickups use `_scrap_combo` (700 ms, cap 9). A chain never climbs by semitones and never past two octaves; the rung is the count, so the pitch is the number.
4. **Threats stay on the sinister degrees.** Damage taken is the falling F to D `hurt`; a near-miss is not a threat cue: it is a reward, the class-colour whip (a rising noise sweep plus the class motif's first interval an octave up, keyed), and it ducks nothing.
5. **Chains resolve on the bar.** A kill chain that reaches rung 5 or more ends with its last note held to the next bar line and the crash on the downbeat (the payoff lands on the grid); below 5 it just stops.
6. **Weight is length and register, not loudness.** A heavier hit is lower and longer (the thwack ladder, the womp scaled by strength); the trims stay at the row's priority dB. Nothing in juice exceeds priority 2.
7. **Hit-stop and the grid.** The drop landing's 70 ms stop ends before the next sixteenth begins, so the crash on the drop beat is never inside a stop; the reward note plays on the frame the stop starts.
8. **Voice limits per cue, budgets per class.** A new juice cue gets a `VOICE_LIMIT` and a `MIN_GAP_MS` row, and it charges the player or reward budget of §3.3.
9. **One source for the fact.** A kill-chain tier, a near-miss and a pickup combo each read the same counter the HUD reads; the banner's tier and the pitch's rung are one integer.
10. **Named, not invented.** Every juice sound is an event row's `sound_next` resolved by `Rows.sound` (W9 note 1); a cue with no row plays nothing rather than a blip.

Cues W11 needs baked (the bank recipes are AU2's, §8): `near_miss_whip` (class-resolved), `kill_chain_tier` (a two-note ladder stab per tier, resolved by rung), `pickup_fountain` (the scrap tick's tail lengthened while magnetism runs), `drop_landing` (the reward note plus the spring snap, resolved by segments cut), `door_tick`.

## 6. Moss and the lounge after the Warden

The bay opens off the launch after each break as today, and the lounge is untouched: a layer mask over the stage theme in the live key (SOUND-STORY §8, W5 note 8). Three v3 changes, all additive:

1. **The gate on the bank after a landed drop is not the bay.** It plays the gates stinger with one note per rarity present (SOUND-STORY pickups table) and no lounge; the lap does not stop. Only the break's gates open the cradle.
2. **The rule part on the hook previews its remix.** Focusing the hook's rule part plays one bar of the lounge with that rule's drum accent (§3.2) at the lounge's level, then the lounge resumes: the tease before the reward (LOOP-REDESIGN §8, anticipation). Buying it rings the shop bell (the counter bell and the two "done" beeps) and the accent stays for the run.
3. **An evolution that landed at the break is heard in the lounge.** The sax's self-answer (inversion or retrograde) takes the pinned rotation slot's shape for the visit, so the bay is where the player hears what the build became, slowed to half speed.

Moss's babble, roots and lines are the vision keeper's (SOUND-STORY §8) and unchanged. Two remembers-you keys would fit v3's facts (`drops_missed >= 3`, `laps_run >= 5`); the lines are the coordinator's call, not this file's (question 6).

## 7. Measures: checking it headlessly

Everything below runs on the dummy driver with `MusicEngine.render` and the board's BS.1770 `lufs()`; how it sounds stays Andrew's.

| Check | Method | Pass band |
| --- | --- | --- |
| **Events on the grid** | From `audio.cue_log` and `engine.events_log` over a scripted lap (commit, telegraph, open, landing, lift, shelf landing): every `"beat"` cue's `start_sample` is a multiple of the live beat from `grid_origin`; every `"now"` cue starts within one physics frame (11 ms at 90 Hz) of its fact's tick; every drop starts on a bar line; the pivot starts on a 172 beat | 0 misses |
| **The five states** | The warden track visits `build`, `open`, `drop` in that order on a landed lap, and `build` then `build` (no `open` to `drop`) on a miss; `hold_dominant` is on from the lip to the landing and off after; `escalate` fires `lift_queued` at the second of four landings and `break_queued` at the third; the unseal drop's cadence returns the track to `level` at `Harmony.STEP` | exact |
| **Voice counts** | `voice_count()` sampled per render block at the four density states of the spike; SFX voices per class from the admission log | band under the cap; threat budget never stolen |
| **Loudness per state** | Integrated LUFS of band-only, cues-only and the sum, per state: shelf (calm), shelf (full snowball), telegraph, open, drop, break, lounge | shelf calm -18 ± 2; full snowball -16 ± 1; drop -14 ± 1; break -13 ± 1; open -17 ± 2; lounge -21 ± 2; the sum never louder than -12 momentary |
| **Threat margin** | Per threat cue start, the cues-only take minus the band-only take over 400 ms | ≥ 6 LU at every state |
| **Bass share** | Energy under 120 Hz over the sum, per state | 30 to 45% normally; under 20% inside the open loop and a hold |
| **Gem regression** | `tests/presentation_gems_test.gd` unchanged and green on every audio commit; a new `tests/presentation_v3_test.gd` holds the checks above and never edits the gems test | PASS (receipt §9.1) |
| **Keyed cues** | Every new pitched id in `KEYED_SOUNDS` and resolvable through `Rows.sound`; `audio_cue_resolution_test` extended with the five interactable families and W11's cues | all resolve |
| **Listening receipt** | The audition WAVs of §9.2, re-rendered by `tools/audio_v3_board.gd` on each wave, mastered at -14 LUFS, listed with duration and loudness in the hand-back | files exist, -14 ± 0.5 LUFS, peak ≤ -1 dBFS |

## 8. Build waves proposed

`music_engine.gd` is clean on W11's branch; `audio.gd`, `sfx_bank.gd`, `event_kinds.gd` and `juice.gd` are dirty there (observed 2026-09-28, `git status` on `core-loop-v3-juice`). So the engine wave starts now and the bank and wiring waves follow W11's admission.

| Wave | Files and seams | Depends on | Writer |
| --- | --- | --- | --- |
| **AU1 engine** | `music_engine.gd`: section `open` on the warden track (kick off, sub and stabs pumping, hats half); `hold_dominant(on)` as a harmonic mask in `_chord`/`_voicing` and the pinned arp shape; `door_tick()` on the next sixteenth; `segments_cut(n, total)` calling `escalate(n / total)`; rotation pins (`pin_rotation(slot, shape)`) for evolutions; a `rules` bitfield read by `_trigger_house` and `_trigger_dnb`; a band voice cap in `_start`; `duck()` scaled by `_intensity`. Tests: `tests/presentation_v3_test.gd` (the §7 state and grid checks); `presentation_gems_test` untouched | none | Opus (judgement in the engine) |
| **AU2 bank** | `sfx_bank.gd` additive block: `bet_roll`, `bet_clunk`, `bet_crack`, `bet_refusal`, `sunken_bell`, `ally_hum` (class-resolved), `ally_wake`, `fight_arm_stamp`, `near_miss_whip`, `kill_chain_tier`, `drop_landing`, `door_tick`, `return_launch_arpeggio`, `lift_hiss`, `crater_hold` (a `hold()` kind); `harmony.gd` nothing; `audio.gd` `KEYED_SOUNDS` additions; `event_kinds.gd` `sound_next` on L3's interactable rows and the lab's `steam_lift_fired`. Tests: `audio_cue_resolution_test` extended | W11 admitted (its `sfx_bank.gd` and `audio.gd` blocks) | Sonnet (every recipe named) |
| **AU3 wiring** | `audio.gd` listeners for L1's `drop_line_committed`, `bowl_entered/left`, `warden_window_opened/held/closed`, `warden_drop_landed`, `warden_punished`, L2's lap rows, L3's interactable rows, Systems' `power_tier`, `evolution_armed/landed`, `rule_part_taken`, bets; the `warden_pivot` lab toggle. Tests: `presentation_sfx_test` ("every signal heard") | AU1, AU2, L1 and L3 events on the bus | Opus |
| **AU4 measures** | `tools/audio_v3_board.gd` promoted from the spike (the lap cycle, the miss, the bet, the ally, the secret, the density states); `presentation_v3_test.gd` loudness, margin and bass-share bands; the density sim as the test's fixture | AU1 to AU3 | Sonnet |

## 9. Receipts

### 9.1 Gem regression at the base

`presentation_gems_test.gd` at 43eeeea, headless: `PASS`, exit 0 (this session, `godot --headless --path sketches/core-loop --script res://tests/presentation_gems_test.gd`, log in the session scratchpad). Gems checked against this design by hand: G1 (the band is the shelf's music, untouched), G2 (the launch build and landing drop are the return's grammar, and the sus is a cousin of A7b9, never a replacement), G3 and G4 (the club is the bowl's music, the pivot bar is the lip, `_trigger_house` untouched), G5 (the shelf keeps the level palette; the club keeps the level's voice), G6 (Brindle untouched), G7 (the escalation drives from segments cut, same thresholds), G8 (the bass figure never leaves; the open loop ducks it and the landing frees it), G9 (every lap has a built drop, the break is the heaviest), G10 (evolutions pin rotation slots, the texture still turns over), G11 (one `escalate`, thresholds from real state, layers added never swapped, the payoff on the landing). R1 and R2: no growl, no wobble anywhere in this design; the bet's roll and the ratchet are drums, not LFOs.

### 9.2 Spike results

Filled in from the workers' reports (audition WAVs, the density simulation, the adaptive-music research) at the end of this session; see the section appended below.

## 10. Needs from the other leads

**Systems and Chaos.** One integer `power_tier` (0 to 8) on the bus per stage; `evolution_armed(part, pair)` and `evolution_landed(id)` with the pair's family glyph id (the band maps three known pairs, and any other pair pins the choir slot); `rule_part_taken(id)` with a stable id per rule; the bet rows `bet_armed`, `bet_rolled`, `bet_won`, `bet_lost` with the bet kind; the cadence's `pick_offered` per lap so the fabricator hoop's chime and the bank gate's stinger can read rarity. The interactables' rows carry a `sound_next` slot I fill (AU2).

**Feel and Readability.** The near-miss event with the class in context and the drawn threat's family (the whip is class-resolved); the drop landing's hit-stop length (70 ms assumed) so the crash never sits inside it; the window beam's remaining fraction on the bus (the open loop's hats thin as it runs out); the badge's segment-cut pop as an event I can sound; the ready pulse's hook for the held-door tick (W9 note 9's path).

**L1 and L3 (lab, in flight).** The events listed in AU3 with these shapes: `drop_line_committed(line_id, lip_speed)`, `bowl_entered()`, `bowl_left()`, `warden_window_opened(family, seconds)`, `warden_window_held(seconds_added)`, `warden_window_closed(landed)`, `warden_drop_landed(impact_speed, segments_left, segments_total)`, `warden_punished(kind)`; `steam_lift_fired` exists on the lab branch (`event_kinds.gd` WORLD_ROWS, `sound_next: return_launch_arpeggio`).

## 11. Open questions for Andrew (recommendation first)

1. **The pivot.** (a) Once per stage: the first lip pivots to the club and the stage stays at 129 until the break. (b) Per lap: 172 on the shelf, 129 in the bowl, G3 every lap. Recommend (a); (b) is a lab toggle either way.
2. **The open window.** (a) The held breath: the band thins to the pump and the landing is the drop. (b) The window itself is the drop and the landing is a hit inside it. Recommend (a): the drop must be the player's.
3. **The escalation's clock.** (a) Segments cut over total. (b) Time in the fight. Recommend (a): missed drops never move the ladder.
4. **The ally's voice.** (a) Your class motif straight on the Mind's sine, so the Mind and the ally are one interval apart. (b) An ally tune of its own. Recommend (a): one more thing the player already knows.
5. **The bet's question.** (a) The tritone D to Ab on the clunk, lifted to A on a win. (b) No pitch on the bet; drums only. Recommend (a): the win is a semitone, the same lean the Fleet makes, resolved the right way.
6. **Two Moss keys** (`drops_missed >= 3`, `laps_run >= 5`) for the vision keeper to write lines for, or leave his table as it is. Recommend adding them after the sitting, not before.

## 12. The roadmap's definition of done

`design-v3/ROADMAP.md` (branch `proto/core-loop-v3-design`, 1589f4f) names row 8 as Sound and its measure as this file's. Each measure of §7 maps to a row; the contributions to other rows are the ear column of that row's read.

| Row | This design's part | Measure (§7) |
| --- | --- | --- |
| 8 Sound (owned) | The Warden fight, laps, drops and snowball scored in the spill-B grammar; the music adaptive in theme; no gem lost; SFX in key | Events on the grid; the five states; voice counts; loudness per state; threat margin; bass share; gem regression; keyed cues; listening receipt |
| 2 The Warden (contributes) | The ear column of closed, telegraph, open, punish and recover per family; the dodge as the whip on the clang; "it is open now" as the chord snapping and the band thinning; progress as the ladder | The five states; events on the grid (the clang on the beat, the ratchet on the frame) |
| 3 The snowball (contributes) | One texture change per power tier, evolution and rule part; never mud | Voice counts; loudness at full snowball; bass share |
| 4 Discovery (contributes) | Five sound families, each learnable by ear; the sunken bell finds secrets before they are seen | Keyed cues (the five families resolve); the listening receipt's bet, ally and secret takes |
| 5 Feel (contributes) | The sound layer of every hit, kill, pickup, drop and dodge, on the frame and in key (§5's ten rules for W11) | Events on the grid ("now" cues within a frame); keyed cues |
| 6 Readability (contributes) | Threats audible in the densest late-run scene: the threat margin and the reserved threat voices | Threat margin ≥ 6 LU at every density state; voice budgets |
| 7 Selling the pilot (contributes) | The class card plays the motif whole on select (SOUND-STORY UI table), and the ally hums it back straight | Keyed cues (`class_motif` resolves per class) |
