# Sound that answers play

How the soundtrack and the event set plug into the running game, written 2026-10-16 for the wave coordinator, who owns `src/`. The target is Andrew's own test: during real play, he can't stay seated. Music is not a playlist here. It is a second controller output: every thing the player does that matters gets an answer the ear can read with the eyes closed.

Everything below maps onto calls the engine already has (`music_engine.gd`, `audio.gd`, `sfx_bank.gd`). Nothing here asks for a new engine.

## 1. Two hard targets, checked by a tool

| Target | Value | How it is checked |
| --- | --- | --- |
| Gameplay sound latency | A hit, stomp, wall bash, hurt or telegraph sounds on the frame it happens: at most one frame (16.7 ms at 60 fps) from the event to `AudioStreamPlayer.play()` | The assets: [check_events.py](check_events.py) fails any impact, danger or boss cue whose onset is later than 5 ms into the file. It passed 49 of 49 cues on 2026-10-16, and its planted late cue fails as it should. The engine side is `tests/audio_event_latency_test.gd`: frames from the event on the real bus to the play call, with a planted late event that must fail. |
| Musical answers land on the grid | Every musical stinger (boss phase, knockout, kill-chain tier, world clear) starts on the next beat, never later than one beat: 349 ms at 172 BPM and 465 ms at 129 BPM | The existing `drop_now` and `_queue` scheduling already quantize. `tests/audio_stinger_beat_test.gd` asserts it on the rendered stinger lane (silent before the beat, sounding from it), with a planted off-beat start that must fail; since wave 35 it also pins the three drop calls. |

Sound on the frame, music on the grid (AUDIO-V3 §2.5). A musical answer never delays a gameplay sound, and the player is never graded against the beat.

## 2. Music follows the player's momentum

The three music stems the manifests already split (drums, bass, other) become the momentum meter. Each layer reads one game fact:

| Stem | Reads | Behaviour |
| --- | --- | --- |
| Bass | always on in a stage | The world's identity; ducks under danger cues as today (`duck_bass`) |
| Drums | rolling speed | Fades in from a quarter of top speed, full at half speed. Standing still leaves bass and keys: the world breathes. |
| Other (sax lead, brass) | a floor on the shelf, lifted by threat, the approach and the chain | The tune is always there while the ball rolls a level: the lead never falls below about half level (`LEAD_FLOOR`, -6 dB; ruling bt, 9 November 2026). Threat, the approach to the landmark (full once the landmark is in reach) and the chain lift it from there to full: a third of the way at chain 2 (the sax hook), full at chain 4. A broken chain lets the lead finish its phrase, never cutting mid-note. A Warden break strips it through the break's held breath only; the kill cadence brings it back whole and the release stops reaching the recorded band from there, so the lead stays back on the shelf after it, whatever restarts the band there. The landmark hum and the synth band keep the release to the next stage, as before, and so does a recorded pack that plays no cadence (a flat pack). Low armour (under 30%) still strips it, and inside a fight its level is the fight floor's, not the shelf's. The Warden fight's held breath and its drop are the exception: they carry the lead whole whatever the feed says (`LEAD_WHOLE`), because the breath is the lead alone and a lead at nothing is silence. |

This is `set_pressure` with a new parameter source (`set_parameter_source` already exists), so the three faders are one call fed by speed and chain. Smoothing: a fader rises over one beat and falls over two bars, so a single bump never makes the band stutter.

## 3. Moves that land on the music

| Player action | Sound on the frame | Musical answer on the next beat |
| --- | --- | --- |
| Stomp (landing on an enemy) | `slam_boom` | A one-beat band gap, then the downbeat hits harder: `drop_now(1, 0.6)` |
| Wall bash | `smash_crack` | A brass stab from the world's lead family when the bash is above three quarters of top speed |
| Kill chain | `kill_pop`, then `kill_chain_tier_1` to `_5` | Each tier racks one more click and a higher air rise, heavier and never a note (SOUND-BIBLE rule 7, [feedback_set.py](feedback_set.py)). Tier 5 triggers the lead stem's hook. |
| Scrap pickup run | `scrap_tick_1` to `_5` by pickup streak | Same ladder, so collecting sounds like playing scales |
| Boost and dash | `boost_whoosh`, `dash_whoosh` | None. Movement is never quantized. |
| Getting hurt | `hurt` (the tritone rasp) | Bass ducks for half a second |

## 4. Boss fights are duels

A boss arrival freezes on the intro card under `boss_arena_in`, the versus stinger, then `begin_boss`. Each posture phase change plays `boss_phase` and moves the boss track to its next section with `set_boss_state`. The stagger that ends the fight plays `stinger_boss_defeated`, the knockout: one unison hit, a beat of silence, then the cadence home. The boss tracks' B-family phrase states and the pilot's A motif answers; the exchange shortens as phases fall (sound bible, "Boss themes").

## 5. The run, start to finish

| Moment | Cue |
| --- | --- |
| Launch | the opening's theme: the title intro (`title_intros.gd`, `theme`) calls `audio.title_theme`, and title A (sax lead) or B (machine lead) starts on its first bar; with no opening, title A; with no pack for the theme, the plain title |
| Camp | `camp`, 129 BPM, warm, while the camp page is open (`audio.camp_theme`); the title theme returns when it closes |
| Stage roaming | the world's roaming take at 172, cut into the shelf (calm, travel) of every zone pack in that world (RENDERS.md, core packs); the Warden's pivot, build, telegraph and drop are the world loop at 129, so no roaming bed plays inside an arena. The shelf and the loop need not share a key, so at the pivot the shelf's bass and lead fade out over the last beat and only the drums cross the downbeat |
| First fight in a stage | the pivot bar into the 129 combat layer: the world track, or the combat hype loop for ordinary fights |
| Warden and world boss | the Warden: the zone pack's combat layer. The world boss: its picked theme (`boss-brindle`, `boss-waking`, `boss-mind`) opens the fight, Brindle's p2 and p3 tracks follow, and the final phase plays its euro track |
| World cleared | `stinger_world`, then the next world's roam |
| Run won | theme C, the show opening, on the summary and on the final win's ending: the `summary` pack's return section (`audio.WON_SUMMARY_ROW`) plays two bars of theme C in D, then its loop lifted a whole step to E |
| Run lost | the `summary` pack's travel loop, the jazz-club summary-loss, with its wink |

Every pick whose Oggs are not on disk falls back to the pack it replaced: the older boss theme, the plain title or the summary pack.

## 6. Variations: phases, champions, areas, buffs, switch-ups

This builds on section 4. Today `set_boss_state` moves one boss track to its next section. Brindle's phases are now three tracks at three tempos (138, 150, 172), so a phase change is a track swap, not a section jump.

| Trigger | Music does | Where it plugs in |
| --- | --- | --- |
| Boss posture phase falls | `boss_phase` stinger now; the next phase track starts on the next downbeat of the stinger's tempo | `set_boss_state`: map phase index to track (Brindle 1 to 3, the Waking and the Mind: final phase on the last posture) |
| Elite or champion joins a fight | Combat loop crossfades to `champion-hype` over one bar; back when it dies | Director, when an elite affix spawns |
| Player enters a secret area | World roam crossfades to its `secret-<world>` version, same tempo and bar position | Area trigger volume, keep the playhead |
| Random event starts | `switch-hit` stinger, then the event track | Event start, ended by its timer |
| Minigame | `minigame-chiptune` | Minigame scene |
| Buff active | A bus effect on the music bus for its duration, faded in and out over one beat | Status-effect start and end |
| Surprise spawn (ambush, out-of-nowhere boss) | Tape stop over 2 beats, `switch-hit-<bpm>`, new track on the hit | Spawn director |
| Planned change (roam to fight) | `turnaround-<bpm>` over the last bar, new track on the next downbeat | The existing 172 to 129 pivot bar |

Buffs, as stock Godot effects on the music bus:

| Buff | Effects |
| --- | --- |
| Overdrive | `AudioEffectDistortion` (mode tan, drive about 0.5, 60% wet), plus a 16th-note hat layer and a brass stab per bar as one-shots |
| Slow-mo or stun | Music player `pitch_scale` 0.75, `AudioEffectLowPassFilter` at 2.5 kHz |
| Low hull | `AudioEffectLowPassFilter` at 700 Hz, heartbeat one-shots on each beat |
| Shield | `AudioEffectHighPassFilter` at 300 Hz, `AudioEffectChorus`, a bell one-shot per bar |
| Scrap streak | A beat-synced volume duck (sidechain pump), plus a chiptune arpeggio per bar |

Hype rule and extras (sound bible, "The hype rule" and "The four extras"). Decided 2026-10-17: the `euro-*` tracks play only in the final phase; earlier phases keep their current tracks.

| Trigger | Music does | Where it plugs in |
| --- | --- | --- |
| Boss, mini-boss or champion enters its last phase | `hype_drop` starts one bar before the next downbeat, then the fight's `euro-*` track starts on the drop | `set_boss_state`: the last posture phase; elites use their final health third |
| Telegraph or danger cue plays | Music bus band dip: 4 dB at 2 to 4 kHz for the cue's length | An `AudioEffectEQ` on the music bus, gain driven from the cue log |
| Low hull | The low-hull buff: low-pass 700 Hz, heartbeat one-shots on each beat of the current track, band ducked 55% under each thump | Read the beat length from the playing track, so the heartbeat follows phase tempo |
| Survive low hull | `clutch_comeback` quantized to the next bar; the current track restarts pitched up a semitone (`pitch_scale` 1.0595) until the phase ends | Low-hull exit with hull above 1 |
| Retry after death | `retry_kickin` on the first frame of the new run, then the combat or roam track on its downbeat | Restart flow |
| Big hit (crit, gauge release, chain milestone) | `pilot_quote_<class motif>` on the next beat, at most once per 8 bars | `class_def.motif` already names the row. Built for the chain milestone (9 November 2026): a chain of six lands on the bar line and the quote starts on the beat after it (`audio._quote_pilot`). The crit and the gauge release are not wired yet |
| Kill chain reaches 20, 35, 50 | `crowd_cheer_1`, `_2`, `_3` on the next beat | The existing chain ladder |
| Smash misses | `whiff_honk` on the next beat | The smash resolver's miss branch |

Only one buff colours the music at a time. Low hull wins over every other buff, because danger outranks reward.

## 7. Conductor and band

The contract between the level conductor and the music, agreed by the systems thread and the sound thread on 10 November 2026. Andrew, the same day: "allign this with the dungeon master level/map conductor and integrate game events, states, character and build progress as a system that feeds from and into the sound design and orchestration." This section is its one home; the systems side links here.

**Who is who.** The conductor is two schedulers stepped by `src/world/world.gd`: the spawn director (`src/world/director.gd`: crowd, packs, the elite, the clock) and the event director (`src/world/event_director.gd`: offers, weather, park set pieces). Fights publish for themselves (`warden.gd`, `boss/boss.gd`, `fight_phases.gd`). The band is `src/presentation/audio.gd` with its two players, the recorded band (`ace_sequencer.gd`) and the synth band (`music_engine.gd`).

**The rules.**

1. Each side reads only the names in the tables below, through the event bus or one small call. Neither reaches into the other.
2. Game time never waits on music, except by slack the conductor offers. Before the world 1 sitting it offers none.
3. The game never shortens a warning and never moves a hit the player is timing a dodge against. The band lands on those; it has the lead time to do it.
4. Sound on the frame, music on the grid (section 1) is unchanged.
5. In bot runs the music clock counts physics ticks, so anything the conductor reads from the band is deterministic. Anything new must keep to that.

### What the conductor publishes

| The band wants | Name today | Value | After the sitting |
| --- | --- | --- | --- |
| Tension: how hard the stage presses | `GameEvents.pressure_changed(pressure)` | 0 to 1, sent on a move of 0.05 or more, 0 on bay entry and stage clear | The set's energy level. The band's own `run_threat` (enemies near and ahead within 48 m) stays as well: it moves the layers inside that level. |
| Phase of the stage | `StageBeats.classify()` (`src/core/stage_beats.gd`): arrive, loot, find, hold, fight, leave. Only the bot recorder calls it. | No live read yet | A live read mapped to four words: lull (arrive, loot, find), build (a send inside its lead, or a Warden's guard under half), peak (pressure at or over 0.4, or the guard over half), release (a stagger, and leave). |
| What is coming, and when | Separate signals, each with its seconds (table below) | 1.4 to 10 s of sure warning for a set piece or an attack | One read: a short list of `{kind, in_s, sure, slack_s}`. First addition: `pack_inbound(faction, at, kinds, seconds)` when a pack's ring is placed, so the band hears the crowd 1 s ahead. |
| Fight state | `warden_engaged`, `posture_changed(enemy, posture, staggered)`, `weak_point_opened(id, at, seconds)`, `vent_charging(at, seconds)`, `vent_erupted(at)`, `attack_cued`, `fight_phase_changed`, `beacon_unsealed`; Brindle: `boss_arena_entered`, `boss_phase_changed`, `boss_attack_telegraphed`, `boss_defeated` | Every state can be read today from these | One signal, `fight_state_changed(fight_id, state, seconds)`, with the six fight words below, so a new world's fights need no code in the band. |
| Build and pilot | `run_started(class_id)`, `heft_class_changed`; `director.build_axes()` (heft, speed, air, contact, weapon, steer, each 0 to 1) is a pull the band cannot reach cleanly | Pilot and heft reach the band | `build_changed(axes, class_id)` on the bus. |

**The six fight words.** A fight has two clocks, and the band follows both: the guard (the player's progress) and the attack (the enemy's).

| Word | Meaning | Read today from | What the band plays |
| --- | --- | --- | --- |
| closed | The guard holds | engaged, not staggered, posture under the line | The build |
| cracking | The guard is near breaking: in at posture 75, out under 50 | `posture_changed` | The tight build (the pack section named `telegraph`) |
| telegraph | An attack is charging, with its seconds | `vent_charging` (the Warden's pulse, 2.0 s, and its counter, 0.8 s inside the stagger: read the seconds), `attack_cued`, `boss_attack_telegraphed` | The attack's own cue and pedal; never a section change (a pulse comes every 6 s and would chop the track) |
| open | The stagger | `posture_changed` staggered, `weak_point_opened` | The held breath |
| recover | A step came off the guard and the Warden still stands, or the stagger ended | a fall in `phase_chunks_left()` that leaves it above 0; staggered back to false | The drop on the next beat, for the step; the build on the next bar, for a stagger nobody landed |
| down | The fight is won | `beacon_unsealed`, `boss_defeated` | The break, the kill cadence, home |

**A step off the guard, and the dam.** The drop answers a step off the guard, counted as the fight's phases count it (`warden.gd` `phase_chunks_left`). On most Wardens that is a real chunk shattered inside a stagger. The dam's rule breaks all four chunks on the last ram and opens no stagger on that path, so its real count goes from four to none in one step; there the count is the bar's quarters, and each paid ram that takes a quarter lands the drop: two or three a fight. The ball the bots bring pays about 30 a ram (31, 62, 93, break), so a clean fight is build, drop, drop, drop, tight build, break: AUDIO-V3's four landings. A grown ball pays a full third (33, 67, break) and lands two; a small one (about 14 a ram) lands three, one every other ram. The dam has no held breath on that path: its sheet opens every 6 s whether or not the player rams, and a breath on it would chop the track for a player who hangs back. A hit off the water can still open a stagger there, which is the held breath (also when the same hit passes a quarter on its way to a full bar: the breath answers it, not a drop), and when it ends the bar is wiped: the count starts again from that reading, so the climb after it lands its drops again. A smash that lands inside that stagger takes a real chunk and lands the drop, as on any Warden; the phases' count then reads three at a wiped bar, so the next ram to a quarter lands no drop and the one after it does. The world's `chunk_N` pulses are the fight's progress and fire once a fight, so they do not start again after a stagger: from there the drops and the pulses stop lining up, by design (the drops answer hits, so they may repeat). Otherwise the lowest count seen is kept, so a bar that drains while the ball is away lands no drop twice. The shatter sound stays on real chunks. Agreed with the systems thread on 10 November 2026 from its dam traces; the rule is `audio.gd` `_guard_step_fell`.

On the recorded band the Warden's fight plays this form: `ace_sequencer.gd` `follow_guard`, fed by `audio.gd` (launch switch `--warden-form=loop` restores the looping build). The synth band and Brindle's fight do not yet. The shattering hit asks for the drop only (the build comes back as the drop's follower), so the hit's frame opens one section's recordings, and the reading that breaks the Warden opens none (the break is a frame away); the sequencer counts every recording it opens and the time it took (`opened`, `open_usec`) for a frame-cost measurement. An ultimate in the fight takes the music for its flight and drop, and the band then comes back to the fight's build (SKILL-BAR section 4, Music). The Warden's entrance takes the band from whatever is playing: a landmark's tune, a tune on its one pass, an event's tune still running (it used to play through the whole fight, because its recording has no fight sections; an event that begins inside the fight does not start its tune either, `TuneMoments.NOT_IN_A_FIGHT`), and an ultimate's or a landing's drop that still holds the recorded band. Each way in enters on the pivot and opens the pivot and the build, never the roaming take first (`audio.gd` `warden_took_band`, `AceSequencer.start_level` with `fight`).

### How far ahead the conductor knows

Lead times as the systems thread read them on stage 14709f17 and checked again on d45adc8e.

| Send | Signal | Lead | Sure |
| --- | --- | --- | --- |
| Crowd and pack bodies | none yet (`pack_arrived` fires as they land) | every body shows a ground ring for 1.0 s | yes |
| The next spawn slot | private | 1.5 to 6.5 s | no: it can be skipped, and its contents are drawn when it fires |
| Clock tier rise | `threat_rose(tier)` | stage second 45 and 90, known from stage entry | yes |
| Offers | `event_announced(id, seconds_until, at)` | 4.0 s | yes |
| Squall, flood | `event_announced` | 6.0 s | yes |
| Park set pieces | `event_announced` | 5 to 10 s; rows marked `on_bar` already wait for the band's next bar | yes |
| Warden pulse | `vent_charging(at, seconds)` | 2.0 s, every 6.0 s | yes |
| Warden counter (reactor family) | `vent_charging(at, seconds)` | 0.8 s, never under 0.6; it fires inside the stagger, 1.0 s after the stagger starts | yes |
| Rogues, the mini-boss, generic fight phases | `attack_cued` | 1.1 s | yes |
| Brindle | `boss_attack_telegraphed` | crane and charge 1.4 s, slag 2.5 s (his eject flies for 2.5 s; whether it is sent on this signal is not checked) | yes |
| Fight phase change | `fight_phase_changed` | 2.0 s | yes |

### What the band publishes

| The conductor wants | Name today | After the sitting |
| --- | --- | --- |
| Transport | `audio.park_transport(stage_s)`: `{bar_s, bar_origin_s}` in stage seconds | The same shape with beat and phrase added; no second call |
| Section | none | The section playing (build, breath, drop, break), so an optional send waits for a build or a drop and never lands in a break |
| Key | never | The conductor has no use for it |

### Slack

Before the sitting: zero. Moving a spawn slot by any amount changes later random draws, so every bot band redraws.

After, each behind a switch and read on bot bands with the switch off and on, on a probe branch first:

- Attacks and pulses: none. The band lands on them.
- A crowd body may land up to one beat later than its ring second (0.35 s at 172, 0.47 s at 129), never earlier.
- An offer, the elite's arrival or a clock rise may wait for the phrase, up to one bar, as `on_bar` park rows do today.

**What one beat of slack costs, measured (systems thread, 10 November 2026).** A probe branch that never stacks (local commit cf492836, from stage d45adc8e) stretched each crowd body's 1.0 s ground ring so the body landed on the next 172 beat, later only: up to 0.349 s late, 0.17 s on average, behind a switch. The dam Warden, Novice band, seeds 40300 to 40347, the same tree each way:

| Switch | Wins of 48 | Died | Hit the fight cap |
| --- | --- | --- | --- |
| Off | 20 (42%) | 13 | 15 |
| On | 16 (33%) | 12 | 20 |

- Seed by seed, 23 of 48 runs end the same way; 8 wins were lost and 4 gained. An exact paired test gives p = 0.39, so the two arms are not told apart. Deaths did not move: the lean is toward slower fights, not deadlier ones.
- The runs are deterministic (17 off seeds run twice, once under heavy load, gave identical results), so the difference between the arms is the switch.
- It does not show the slack is free: calling a 9 point gap either way needs about four times the seeds. So landing on the grid is read on 96 seeds an arm against the Novice ceiling before it is turned on.
- It confirms why the conductor's timing does not move before the sitting: any timing change redraws about half the Novice seeds (25 of 48 here).
- The probe counted beats from the stage's start, not from the band's transport. It measures what the delay costs the game, not whether the body lands on the band's beat; the real change asks `park_transport` for the grid.

### Before and after the world 1 sitting

Before: the conductor's timing does not change, and the band reads only the names above. The band's one change is the Warden form on the recorded band, behind its switch. The set director (ruling di, SOUND-BIBLE "The DJ at the decks") reads only names already listed here (pressure, the faders, `event_announced`, the fight word) plus the Heat band and the Overtime facts the band already hears, and changes only what the band plays, behind `--set-director=on`.

After, in order:

1. `pack_inbound`, and a fill into the arrival.
2. The conductor's one read (tension, phase, next, fight, build), `fight_state_changed` with the six words, `build_changed`.
3. The band publishes beat, phrase and section.
4. Arrivals on the grid behind a switch: bodies one beat late at most; the elite, offers and clock rises on the phrase.
5. The Warden form on the synth band and on Brindle's fight.

## 8. Hand-over list for the coordinator

1. Import the picked takes as `music_ace/` theme sources with htdemucs stems, using the grid-stretched WAVs from RENDERS.md.
2. Register the 49 event WAVs in `sfx_bank.gd` under their existing keys. Cues with tiers (`kill_chain_tier_1` to `_5`, `scrap_tick_1` to `_5`, `rarity_bell_common`, `_rare`, `_epic`) map to the existing tier and rarity arguments. Keep per-cue voice limits.
3. Feed `set_parameter_source` with rolling speed and chain length for the stem faders in section 2.
4. Add the two section 1 checks to the test suite.
5. Special enemies, from `specials.py` (17 WAVs). Play `<name>_presence` as a looping `AudioStreamPlayer3D` on the enemy, with its own voice so it never steals a combat voice, and stop it on death. Fire `<name>_tell` on the same frame as the visual tell: the Foreman's horn on the beat before the shred wipe, the Dispatcher's on each drop, the Splitter's on the seam flare, the Linker's when the cable goes taut. Fire `<name>_break` on death. The Splitter picks `splitter_break_split` when rammed at ground level and `splitter_break_clean` otherwise. Queue `<name>_spawn` on the next beat through the same quantizer as the stomp downbeats in section 3. Cap presence loops at two specials heard at once, nearest first.
6. Variations: import the picked round-7 takes (RENDERS.md) as tracks and wire the section 6 table.
7. Hype rule and extras: import the final-phase Eurodance picks only (`euro-brindle-p3-s2801`, `euro-waking-final-s2801`, `euro-mind-final-s2801`, `euro-champion-s2901`) and the 13 `extras.py` WAVs, and wire the second section 6 table. The other round-8 takes stay as comparison material.

Not covered here: the in-game mix under real combat noise, and whether the stem faders feel right. Both need Andrew playing.
