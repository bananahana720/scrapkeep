# Scrapkeep sound bible

One page for how Scrapkeep sounds, written 2026-10-16 from Andrew's direction: **gritty steampunk and cyberpunk crossed with house, with jazz built into how the songs and notes are written.** It sits on top of [AUDIO-V3.md](AUDIO-V3.md) (the engine grammar), [SOUND-STORY.md](../SOUND-STORY.md) (registers and motifs) and the 2026-10-11 listening packet in `~/Music/Scrapkeep-sound-direction/`, whose mechanical swing track is the one Andrew approved ("huge 180"). Nothing here changes the game. The wiring notes at the end are for the wave coordinator.

## The one sentence

A house pulse you can't sit still to, played by a rusty machine band whose lead line phrases like a sax player: the kick and bass are the engine, the chords are jazz, the melody talks back.

## Tone: a game that loves having fun

Andrew, 2026-10-16: carefree, experimental and **melodramatic, like an anime opening**, with real swings into intensity, anger, despair or sadness. The sadness is self-aware and a little corny, and the whole game is trying to make you smile. This applies to every beat of the game, not just the music.

**Borrow the tropes, not the sound** (Andrew, 2026-10-16, after the first title C came out "way too Asian-inspired"). Take an anime opening's patterns and keep Scrapkeep's own genre mix: a one-bar cold open of the hook, a fanfare hit, a racing verse, a rising pre-chorus, one beat of silence before the chorus, an octave leap on the hook, a sudden ballad break, a key change up and a final unison hit. Never pentatonic or East Asian melodic colour, East Asian instruments or J-pop production. Never use the word "anime" in a render caption, because the model reads it as a sound. In practice:

- **Go big on contrast.** A track can drop from a full chorus to one lonely sax over soft Rhodes, then key-change up into a bigger finale. The dip earns the joy.
- **Sad moments wink.** A defeat sighs down a chromatic line on a hanging A7b9, then one bright bell answers: go again.
- **Treat the music like a playground.** Try odd timbres, sudden fanfares and dramatic stops. The house pulse keeps it danceable. Andrew's test on the first round: he couldn't stay seated.

## Title screens rotate

Andrew loves both title themes, so there is no single title. Each title theme pairs with its own alternate title screen, and the game picks one per launch: A (sax noir) and B (machine lead), chosen by the rotating opening (`TITLE-INTROS.md`). Never play the same one twice in a row. C (the show opening, built from opening-sequence tropes, at the band's 172 BPM; Andrew picked take 1, `title-c2-show-opening-s2301`, on 2026-10-16) is not a title screen: Andrew's 17 Oct ruling (project DECISIONS register) gives it to the won run's summary and the ending.

The themes also have jobs past the title screen, matching the tone bible (`tone/TONE-BIBLE.md` in the project library, draft of 2026-10-16), which wins on feel:

| Theme | Belongs to | Where its hook returns |
| --- | --- | --- |
| A, sax lead | the pilots and the worlds: the keepers | each world's sax lead quotes it, and the pilot answers in every boss duel |
| B, machine lead, sax answering | the bosses and the Furnace Fleet: the machine calls | each boss states it first, and the keepers answer |
| C, show opening | the swing itself | the run summary and the ending play its fanfare, sad break and key change |

Boss fights are call-and-response duels, the game's bass battle: the boss states B's phrase, the pilot's A motif answers, and the exchange tightens as phases fall.

## The swing, in music

The tone bible's five-beat swing map, scored. It fits in about 20 seconds and is used for intros, boss arrivals, the run summary and the ending.

| Beat | Music |
| --- | --- |
| Hype | Kick drum enters with a fanfare stab and the hook's first phrase |
| Collision | Everything drops except the bass. The rival's B phrase enters. |
| Crash | One sax line held a bar too long over a held chord: Bbmaj7 or the hanging A7b9 |
| Wink | A bell, a pipe clank or a drawn sound-effect word answers on the off-beat |
| Back up | Hard cut on the downbeat into the full band, a whole step up when the moment earned it |

Every crash resolves home: to D in menus, Spillway and the run summary, or to its own world's tonic, E in the Dig and G in the Highdraft. No silence during play lasts longer than a bar.

## Palette

| Layer | What it is | The rule |
| --- | --- | --- |
| Pulse | Four-on-the-floor kick, ghosted swung shuffle hats, off-beat open hat | The kick never swings. The hats, comping and lead do. |
| Bass | Sub or overdriven analog bass, walking ii-V and chromatic approach notes into each bar | The bass riff is tappable alone. It carries the world's identity when everything else drops. |
| Harmony | Rhodes and clavinet ninths, elevenths and thirteenths. ii-V-I is the cadence. Sus chords mean "in the air". | One comping voice at a time. |
| Lead | A sax family voice per world (alto, baritone, soprano), answered by muted trumpet, brass section or synth-brass | Call and response: one statement, one answer, then space. Melody first, because Andrew played sax: a hook he can hum after one hearing. |
| Machine | Pistons, steam valves, ratchets, pipe clanks, cables, pickaxe pings | Tuned and locked to the grid as percussion. Never a constant noise wash. Kept apart from danger cues. |
| Grit | Tape saturation, bitcrushed keys, driven bass | Grit lives in the low mids and the keys, not on the lead melody. |

Never: vocals, wobble or growl bass as the main texture, lounge-piano softness, long cinematic intros on retry.

## Tempo and key

Two grids, as the engine already has them: in-run roaming plays on the **172 BPM** band, and combat and boss fights pivot onto the **129 BPM** house grid. One 172 bar equals three 129 beats, so the pivot bar (AUDIO-V3 §1) lands. Titles A and B and the three world tracks in this pass are the 129 house layer, and title C is at 172. Worlds differ by feel rather than tempo: the Dig sits in a half-time feel over the same 129 kick, the Highdraft pushes with faster lead runs. Keys follow the in-game themes so the harmony system keeps working: title and Spillway in D (Dorian, home chord Dm9, dominant A7b9), the Dig in E, the Highdraft in G.

## The three worlds

| World | Mood | Lead voice | Groove | Machine percussion | Harmony colour |
| --- | --- | --- | --- | --- | --- |
| Spillway Works | Sunny, buoyant, confident. A green river canyon with rusty pumps. | Bright alto sax, brass-section answers | Swing house, bouncy, springy plucked bass, clavinet | Pump gurgles, valve hisses, sluice-gate clanks | Dorian: minor with a bright sixth |
| The Dig | Underground, tense, hypnotic. Heavy and close. | Muttering baritone sax, muted trumpet echo | Deep tech house, half-time feel, rubbery sub riff | Drill rattles, pickaxe pings, cave drips, rail-cart clatter | Minor elevenths, a Phrygian flat second for menace |
| The Highdraft | High, open, windswept, a little uneasy. The run's last world. | Soprano sax with quick improvised runs, synth-brass answers | Progressive house, rolling octave bass | Wind gusts, creaking rigging, propeller whir, cable pulleys | Major ninths and sharp elevens: Lydian lift over a minor floor |

## Boss themes

A boss plays a threatening version of its world's hook, then states its own B-family phrase. Phases follow the game's posture and stagger thresholds, never a soundtrack timer. Nobody is evil (tone bible), so each theme sounds like a person who is sincere and wrong, woken or lonely, not a villain.

- **Admiral Brindle, Spillway**: sincere arithmetic. B's machine lead plays dead-straight eighth notes that refuse to swing, while the pilot's alto answers swing harder each phase. His collapse is a brass fanfare that rounds up one note too many.
- **The Waking, the Dig**: something old, woken. The bass riff compresses into 3+3+2 accents, a stacked-fourths hum becomes the chord, and a Phrygian flat second takes over the cadence, floor by floor.
- **The Mind, the Highdraft**: lonely. The only boss built from the player's own hook, inverted and played back on sine. The last phase restates the title melody in the Mind's wrong chord, then the final drop resolves to G major, the Highdraft's home.

### Versus battles and combat hype

Andrew, 2026-10-16: boss and fight music in the spirit of the versus-battle duels in the Scott Pilgrim film, with Roboquest's driving production. It should be blood-pumping, so that rolling, stomping and bashing into walls and enemies feels unstoppable. Borrow the tropes, not the sound:

- **The announcer stinger.** Every boss fight opens on a one-bar brass or metal fanfare under the intro card's freeze frame.
- **The duel.** A boss fight is a musical fight: the boss's bass or machine lead states, the pilot's sax answers, and the exchanges shorten as phases fall.
- **Game inside the game.** Chiptune square-wave arpeggios flick between phrases, the comic-book layer in sound.
- **Phase escalation, Roboquest-style.** More percussion layers, a lower-register weight and a bigger hook each phase, with a tense break before the last one.
- **The knockout.** A final unison hit lands on the stagger that ends the fight, then the wink.

Ordinary fights use a combat hype loop: relentless kick, layered toms and claps, overdriven slap bass, the tenor sax hook with brass blasts, and no breakdown. The 2026-10-11 mechanical swing track Andrew approved is its reference, and one render conditions on it directly.

The Warden families in AUDIO-V3 (reactor, hive, Mind) keep their own per-state sounds under these themes. The 2026-10-11 boss previews remain comparison material.

The four boss previews from 2026-10-11 remain comparison material for this section.

## Event sounds

Short, a little whimsical and tied to their event, like a rice cooker's end-of-cycle tune. Every pitch is in D Dorian so events never clash with the band. Gameplay sound plays on the frame. Only the musical answer waits for the grid.

| Event | Length | What you hear | Why it fits |
| --- | --- | --- | --- |
| Scrap pickup | 0.24 s | Two rising metal tinks, A5 to D6 | A fifth landing on home: "got it". In game the pitch climbs the reward ladder with a pickup chain. |
| Harpoon hit | 0.55 s | A dull thunk, a dropping low boom, the cable twanging on D2 | Weight first, then the line tightening, so sight and sound share one record. |
| Run complete | 3.2 s | A tenor sax bebop pickup over Em9 to A13, landing on D major 6/9; bells climb out; a steam valve lets go | The ii-V-I cadence is the whole game's harmony arriving home. This is the rice-cooker melody. |
| Run failed | 2.8 s | The sax sighs down A, G#, G, F# over Bbmaj7 to A7b9, the last note droops, then one bright bell on D6 | Melodramatic, self-aware sadness: the bell is the wink that says go again. |
| Menu move | 0.09 s | A soft woody tick with a D5 Rhodes blip | Quiet enough to scroll through ten times. |
| Menu confirm | 0.36 s | A valve click, then a fourth up from A4 to D5 on Rhodes with a bell | A confirm that rises, so you know a choice was taken. |

The sounds come from code, [sound/event_sounds.py](sound/event_sounds.py), so pitch, key and length stay editable.

### Special enemies

Left 4 Dead's rule (Andrew, 2026-10-17): you hear which special is near before you see it. Each kill-first special owns one register and one texture that no other cue uses, and carries it through four cues. A presence loop plays from its position while it lives. A tell starts on the same frame as its visual tell. A break sound plays when it dies, with the tone bible's wink. A one-beat spawn answer from the band plays on the next beat after it arrives. Danger tells use the tritone, and breaks use the reward family, so killing a special always sounds like a win.

| Special | Register | Presence loop | Tell | Break | Spawn answer |
| --- | --- | --- | --- | --- | --- |
| Foreman | Low brass and steam, 70 to 150 Hz, with a punch-clock tick | A steam-horn drone, the clock ticking the beat, and a throat-clearing brass grunt | A factory horn on D and Ab on the beat before each wipe | SHIFT OVER: a punch-clock ka-chunk, a steam sigh, and a corny trombone wah-wah-wah-waaah down to F#3 | Two low brass notes, the shift whistle |
| Dispatcher | Pulse-wave pings and teleprinter clatter, 1.5 to 3 kHz | A radar beacon on every beat with clatter on the off-beats | A pneumatic tube sucks up, then a D and Ab double ding as the chaser drops | The printer jams, a spring boings, and the beacon falls down a chiptune scale | Morse on the beacon note: short, short, long |
| Splitter | Fuse hiss at 4 to 8 kHz over three hums that beat against each other | Three in one: hums a hair out of tune with each other, a sputtering fuse, and a lamp blink | Three voices slide up and meet in 0.4 s, matching the white seam flare | Two kills. Rammed: a pop and three chirps scattering in clashing keys (wrong). From above or range: one fat pop and a reward ding (right) | Three notes stacked fast |
| Linker | Mains buzz on a 120 Hz series and a bowed wire at A5 | The buzz under a singing wire that swells, with arc sparks | The cable twangs and tightens upward a tritone while the dish braces | A snap, the dish clangs down, then rolls off like a lost hubcap, each clank further apart | Two notes joined by a slide |

Code: [sound/specials.py](sound/specials.py). No East Asian instruments or scales, and every pitch sits in D Dorian or on its tritone.

## Variations: one theme, many twists

Andrew, 2026-10-17: the same themes should come back changed, so a champion, a boss phase, a secret room, a random event, a minigame, a buff or a surprise each sounds like a twist on something you already know. Rule: a variation keeps its parent's melody and changes tempo, instrumentation or treatment. It is rendered as a cover of the picked parent take at strength 0.55 to 0.6, or applied live by the engine. Each one is measured against its parent and against a different parent as a control ([sound/measure_variants.py](sound/measure_variants.py)).

- **Brindle's phases speed up and heat up.** Requisition at 138 is officious, with a marching snare. Furnace at 150 is overdriven, with furnace bellows. Scuttle at 172 sprints on the band's tempo, and his straight machine lead finally cracks into a swing. Each phase is its own track, swapped on the next downbeat under `boss_phase`.
- **Every boss gets a faster final phase.** The Waking and the Mind take their themes to about 142.
- **Champions get a golden version** of the combat hype loop: a steel gong hit each phrase and brass doubling the hook a third above.
- **Secret areas restate their world's roaming tune** on a new instrument at the same tempo. Spillway gets a music box underwater, the Dig an upright piano in a speakeasy, the Highdraft a vibraphone and harp in a cloud chamber.
- **Random events and minigames reuse a title hook.** Scrap Rush is title B as a game-show countdown. The minigame is title A as 8-bit chiptune.
- **Buffs are live effects** on whatever is playing: overdrive, slow-mo, low hull, shield and scrap streak (INTEGRATION section 6).
- **Switch-ups hand one loop to the next on a downbeat.** Out of nowhere: tape stop, record scratch, a beat of silence, a unison hit. Planned: a one-bar turnaround with a brass ii-V.

## The hype rule: every fight ends on the drop

Andrew, 2026-10-17: the boss music should feel like Eurodance and electro house, with harder 808s, a pumping bassline and the existing hooks made catchier, so you feel like a badass and want to retry after every death. This is a rule for every encounter, not a separate score.

- **Phase 2 to 3 drops into the hype version.** On every boss, mini-boss and champion fight, the last phase is the Eurodance cover of that fight's own theme: four-on-the-floor kick, 808 sub, an offbeat bassline, supersaw stabs and the same sax hook. The `hype_drop` stinger carries the handover: one bar of riser and snare roll, a beat of silence, then the drop. Only the last phase is Eurodance; earlier phases keep the current style, so the switch is the payoff (Andrew tapped "Last phase", 2026-10-17 01:45Z).
- **Flow, not frenzy.** Hype sections sit at 140 to 150 BPM. The kick, the hats and the bassline repeat without fills inside a phrase, so the groove locks in. The hook plays in call and response with space between phrases. At 172, the drums play a half-time break so the felt pulse stays at 86 and 172, never cluttered.
- **Warnings keep a lane.** While a telegraph or danger cue plays, the music bus dips 4 dB in the 2 to 4 kHz band, where the tritone warnings live. The groove keeps going and the warning still cuts through.
- **Dying feeds the hype.** Low hull turns the band muffled while an 808 heartbeat pumps on the track's own beat, so it races when a phase speeds up. Surviving on 1 hull lands `clutch_comeback`: a riser, then the band slams back a half step higher. Retrying lands `retry_kickin`: four climbing kicks, two sax notes and the drop, straight back into the groove.

## The four extras (Andrew's "All four", 2026-10-17)

| Extra | What you hear | When |
| --- | --- | --- |
| Pilot quotes | The band plays your pilot's own leitmotif on tenor sax, from the same cells as `Harmony.MOTIFS`, with a brass and kick hit on the last note | A big hit: a crit, a gauge release, a chain milestone |
| Clutch comeback | A riser out of the muffled band, a breath, then the band back a half step up with a bell wink | Surviving the low-hull state |
| Machine crowd | Steam whistles on a D chord, clanks on the beat, ratchet applause; three tiers, each bigger | Kill chains at 20, 35 and 50 |
| Sour honk | One tenor sax Ab3, the tritone off home, sagging a quarter tone | A whiffed smash, on the beat |

Code: [sound/extras.py](sound/extras.py).

In the game so far (9 November 2026): the pilot quote answers a long kill chain, six kills inside the chain window. The chain lands on the bar line under its crash, and a beat later the band plays the pilot's motif on the synth sax in eighths, with the brass an octave under the last note and a kick with it (`audio._quote_pilot`, `SfxBank.pilot_quote_score`). It is made for the sounding band's step and key, and it plays at most once every 16 seconds so it stays a treat. Kest's and Tarn's motifs go up an octave so the sax can sing them. The crit and gauge-release triggers and the other three extras are not built yet.

## Renders from this pass

ACE-Step 1.5 XL turbo on the RTX 4080, draft mode, two seeds each. Files sit in `~/Music/Scrapkeep-sound-direction/sound-bible-2026-10-16/`, outside the repo like every other music render. [sound/RENDERS.md](sound/RENDERS.md) lists them with checksums. They are linear previews. Seamless loops, stems and final bf16 renders come after Andrew picks by ear.

## Sound that answers play

The full event set (49 cues, named after the game's `sfx_bank.gd` keys) and the plan for wiring music to play live in [sound/INTEGRATION.md](sound/INTEGRATION.md). In short: gameplay sound on the frame, music on the beat, the drums follow rolling speed, the sax follows the combo, kill chains and scrap streaks play rising D Dorian phrases, and every boss fight is a duel that ends on a knockout hit. Two targets are checked by tools: every instant cue's onset is within 5 ms of its start, and every musical stinger starts on the next beat.

## Wiring notes for the wave coordinator

These touch files the coordinator owns, so they are notes, not edits.

1. Bring each title take Andrew keeps in as a new `music_ace/` theme source (calm, travel and cadence sections), using the same htdemucs stem split the current manifests use.
2. Title rotation: one title theme per launch from A, B and C, no immediate repeat, each paired with its alternate title screen. Keep the pick on the presentation random stream so it never rerolls gameplay.
3. Event sounds: register the six WAVs as sample cues beside the procedural `sfx_bank.gd` voices, keeping the per-cue limits and the priority-2 duck. Scrap pickup keeps its existing reward-ladder pitch shift.
4. Do not change the 129 and 172 tempo grid or the keys in `harmony.gd`. The renders asked for 129 BPM but measure 124 to 128, so time-stretch a picked take onto 129 before splitting stems (see RENDERS.md).
