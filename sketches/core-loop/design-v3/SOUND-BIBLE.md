# Scrapkeep sound bible

One page for how Scrapkeep sounds, written 2026-10-16 from Andrew's direction: **gritty steampunk and cyberpunk crossed with house, with jazz built into how the songs and notes are written.** It sits on top of [AUDIO-V3.md](AUDIO-V3.md) (the engine grammar), [SOUND-STORY.md](../SOUND-STORY.md) (registers and motifs) and the 2026-10-11 listening packet in `~/Music/Scrapkeep-sound-direction/`, whose mechanical swing track is the one Andrew approved ("huge 180"). Nothing here changes the game. The wiring notes at the end are for the wave coordinator.

## The one sentence

A house pulse you can't sit still to, played by a rusty machine band whose lead line phrases like a sax player: the kick and bass are the engine, the chords are jazz, the melody talks back.

## Tone: a game that loves having fun

Andrew, 2026-10-16: carefree, experimental and **melodramatic, like an anime opening**, with real swings into intensity, anger, despair or sadness. The sadness is self-aware and a little corny, and the whole game is trying to make you smile. This applies to every beat of the game, not just the music. In practice:

- **Go big on contrast.** A track can drop from a full chorus to one lonely sax over soft Rhodes, then key-change up into a bigger finale. The dip earns the joy.
- **Sad moments wink.** A defeat sighs down a chromatic line on a hanging A7b9, then one bright bell answers: go again.
- **Treat the music like a playground.** Try odd timbres, sudden fanfares and dramatic stops. The house pulse keeps it danceable. Andrew's test on the first round: he couldn't stay seated.

## Title screens rotate

Andrew loves both title themes, so there is no single title. Each title theme pairs with its own alternate title screen, and the game picks one per launch: A (sax noir), B (machine lead), and C (anime opening, the melodramatic one, at the band's 172 BPM). Never play the same one twice in a row.

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

All house music runs at **129 BPM**, the game's club tempo: one 172 BPM band bar equals three 129 beats, so the engine's pivot bar (AUDIO-V3 §1) still lands. Worlds differ by feel rather than tempo: the Dig sits in a half-time feel over the same 129 kick, the Highdraft pushes with faster lead runs. Keys follow the in-game themes so the harmony system keeps working: title and Spillway in D (Dorian, home chord Dm9, dominant A7b9), the Dig in E, the Highdraft in G.

## The three worlds

| World | Mood | Lead voice | Groove | Machine percussion | Harmony colour |
| --- | --- | --- | --- | --- | --- |
| Spillway Works | Sunny, buoyant, confident. A green river canyon with rusty pumps. | Bright alto sax, brass-section answers | Swing house, bouncy, springy plucked bass, clavinet | Pump gurgles, valve hisses, sluice-gate clanks | Dorian: minor with a bright sixth |
| The Dig | Underground, tense, hypnotic. Heavy and close. | Muttering baritone sax, muted trumpet echo | Deep tech house, half-time feel, rubbery sub riff | Drill rattles, pickaxe pings, cave drips, rail-cart clatter | Minor elevenths, a Phrygian flat second for menace |
| The Highdraft | High, open, windswept, a little uneasy. The run's last world. | Soprano sax with quick improvised runs, synth-brass answers | Progressive house, rolling octave bass | Wind gusts, creaking rigging, propeller whir, cable pulleys | Major ninths and sharp elevens: Lydian lift over a minor floor |

## Boss themes

A boss plays a threatening version of its world's hook, then states a contrasting boss phrase. Phases follow the game's posture and stagger thresholds, never a soundtrack timer.

- **Spillway's boss** (the reactor family): the alto hook moves to baritone, the Ab pedal from AUDIO-V3 goes under the bass, and the brass answers arrive early, interrupting the call.
- **The Dig's boss** (the hive family): the bass riff compresses into 3+3+2 accents, the stacked-fourths hum becomes the chord, and the flat second takes over the cadence.
- **The Mind**: the only boss whose theme is built from the player's own hook, inverted and played back on sine. The last phase restates the title melody, now harmonised in the Mind's wrong chord, before the final drop resolves to D major.

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

## Renders from this pass

ACE-Step 1.5 XL turbo on the RTX 4080, draft mode, two seeds each. Files sit in `~/Music/Scrapkeep-sound-direction/sound-bible-2026-10-16/`, outside the repo like every other music render. [sound/RENDERS.md](sound/RENDERS.md) lists them with checksums. They are linear previews. Seamless loops, stems and final bf16 renders come after Andrew picks by ear.

## Wiring notes for the wave coordinator

These touch files the coordinator owns, so they are notes, not edits.

1. Bring each title take Andrew keeps in as a new `music_ace/` theme source (calm, travel and cadence sections), using the same htdemucs stem split the current manifests use.
2. Title rotation: one title theme per launch from A, B and C, no immediate repeat, each paired with its alternate title screen. Keep the pick on the presentation random stream so it never rerolls gameplay.
3. Event sounds: register the six WAVs as sample cues beside the procedural `sfx_bank.gd` voices, keeping the per-cue limits and the priority-2 duck. Scrap pickup keeps its existing reward-ladder pitch shift.
4. Do not change the 129 and 172 tempo grid or the keys in `harmony.gd`. The renders asked for 129 BPM but measure 124 to 128, so time-stretch a picked take onto 129 before splitting stems (see RENDERS.md).
