# Score architecture

How every piece of Scrapkeep's music comes from three written themes, so the soundtrack plays as one score instead of a playlist. Written 2026-10-17 from Andrew's ask: approach the melodies the way a professional composer would, so they harmonize with each other and carry the story, the fun and the player's journey.

It sits under the tone bible (PR #20) for feel and beside the sound bible and integration notes on the music PR (#12), which own the sound palette, the event set and the wiring. It changes no game code and no file the music thread owns. The music thread applies the hand-over at the end once Andrew has picked.

## Why it sounds like a mishmash today

Every parent track was rendered from its own text caption. Rounds 1 to 6 in `sound/RENDERS.md` (PR #12) are text-to-music, one caption per cue, so ACE-Step wrote a new melody for each title, world, roam, boss, camp and ending. Only the round 7 to 9 variations are covers, and each covers one of those unrelated parents. Nothing ties Title A's tune to the Spillway's, or Brindle's to the ending's. The written leitmotifs that do tie things together (Sable's rising arpeggio, the Fleet's stamp, the Mind's inverted quote, in `harmony.gd` `MOTIFS`) live only in the procedural band and the event sounds. The rendered soundtrack never states them.

Measured on the library mirror, 2026-10-17, with [check_score.py](check_score.py) (full mixes, first 64 s):

| Take | Cue | Scale fit at the cue's key | Best fit | Reading |
| --- | --- | --- | --- | --- |
| combat-hype-cover-mechswing-s2601 | combat | 0.31 | 0.87 at +3 semitones | Off key. Centred on F with Eb, E and F# heavy, while every kill-chain, pickup and crowd answer plays in D Dorian over it. |
| combat-hype-loop-s2402 | combat | 0.38 | 0.56 at +3 | Same drift. |
| roam-highdraft-s2501, highdraft-loop-s2101 | Highdraft | 0.69 to 0.73 | | G minor with Bb strong (librosa key 0.94). The sound bible's Lydian lift (a raised fourth, C#) is not audible in the pitch content. |
| title A, Spillway, camp, Brindle, title C | D cues | 0.72 to 0.84 | within 0.05 | In the D scale family. |

The melody check cannot yet separate today's takes: on full mixes each scores 0.41 to 0.52 against the written themes and the same against a control, and a transposition-searching cross match of ten picks against each other is flat at 0.78 to 0.87. That is the expected result for unrelated melodies, but it is also the floor of a blunt instrument, so read it with the "other" stem once the music thread runs it (limits below).

## The method

This is how film and game composers keep a large score coherent: approve a small theme suite first, spot every cue against the story, derive each cue from a theme with a named device, mock it up, then produce it. Undertale is the game reference: a handful of leitmotifs turn up in almost every track, and the player hears the story in which tune comes back. Journey is the other: its main theme is only heard complete at the summit.

1. **Theme suite.** Three themes plus the pilot motifs already in `harmony.gd`. Nothing else gets its own tune.
2. **Cue sheet.** Every cue names its parent theme, which bars, the key and mode, the tempo, the devices that transform it and the story beat it carries ([themes.py](themes.py) `CUES`, `python themes.py list`).
3. **Guide.** `python themes.py guide <cue> <dir>` writes a plain mock-up of the derived cue (lead, the `harmony.gd` chords, bass, four-on-the-floor kick), a lead-only file and a MIDI file.
4. **Evolve.** The current picked take stays the production reference and the standing version (Andrew, 03:26Z: keep the progress, make it cohesive). Its drums and bass stems are kept, moved onto the cue's key and grid, and the theme's lead line goes on top; ACE-Step re-renders that hybrid as one production. "Evolve the current tracks" below has the steps.
5. **Check.** `python check_score.py <take> <cue>`: the take is in the cue's scale, and its lead line beats a control theme by 0.1, the margin `measure_variants.py` already uses.
6. **Mix and master.** Every kept and new track goes through one mix chain and `check_mix.py` (loudness, peaks, frequency and stereo slots, loop seams, key).
7. **Ear.** Andrew picks by ear among the takes that pass. A new take replaces a standing pick only when he picks it.

## The theme suite

All three are written over chords `harmony.gd` already plays, so the rendered score and the procedural band share their changes. Notes are in [themes.py](themes.py); a MIDI file of each comes out of `guide`.

| Theme | Plays as | Built from | Shape | Story job |
| --- | --- | --- | --- | --- |
| **K, the Keepers' theme** | Title A; the pilots and the worlds | Sable's motif (D F A C E) as the opening call, over `PROGRESSION` (Dm9 G13 Dm9 Cmaj9 Bbmaj9 G13 Em7b5 A7b9). Swung, alto sax. | 8 bars. Call (rising arpeggio), answer (falling bebop line), call again with the octave leap, answer. Bars 5 to 8 dip through Bb, the crash colour, and hang on the A7b9. | Us. It is never resolved until the ending. |
| **M, the Machine theme** | Title B; the Furnace Fleet and every boss | The Fleet motif (stamp, stamp, lean, stamp: D D Eb D) opening each bar, over `BRINDLE` (Dm(add9) Bbmaj7#11 Ebmaj9 A7b9). Straight eighths, machine lead. | 4 bars. Each bar stamps, then decrees. Bar 3 stamps a semitone higher on the Neapolitan Eb: the Fleet grown into Brindle. The lean always falls back down. | Them. Sincere, stuck, never evil. |
| **S, the Show theme** | Title C; world clears, the run summary, the ending | `VICTORY` (Bbmaj9 C13 A7b9 Dmaj9), D major. | 4-bar chorus hook. Opens on the octave leap. Bar 3 is M's lean resolved upward (D Eb E) instead of falling back. Lands on F# over Dmaj9. | The swing's back-up beat. The one place the machine lets go. |

The six pilot motifs stay as written. Sable's is K's first bar, so the hero's theme and the first pilot are one tune. The others are short enough to answer K's call or M's stamp, which is how the duels use them.

## Devices

Each cue is a theme plus named devices, all in `themes.py`:

| Device | What it does | Used for |
| --- | --- | --- |
| Bars | Takes part of a theme | The journey arc below |
| Mode and key | Moves each note to the same scale degree in another mode and tonic; chromatic notes keep their colour | The Dig (E Phrygian), the Highdraft (G with a minor third and raised fourth) |
| Invert | Flips every interval around the first note, last note a semitone flat (`harmony.gd` `mind_quote`, extended from motifs to the whole theme) | The Mind |
| Regroup 3+3+2 | Moves each bar's onsets onto a 3+3+2 grid | The Waking |
| Half time, octave | Doubles durations; moves a register | Camp, the Dig, the loss summary |
| Unresolved | Cuts the last note short so the phrase hangs | The Highdraft |
| Answer | Appends K's call after M's statement | Every boss duel |
| Against | Plays the other theme underneath at once | Combat, champion, the ending |

## The journey arc

K is heard more completely as the run goes on, so finishing the run finishes the tune:

| Where | What of K you hear | Feel |
| --- | --- | --- |
| Title A, first launch | All 8 bars, once | The promise |
| Camp | Bars 1 to 4, half time, ballad | Home, not finished |
| Spillway (D Dorian) | Bars 1 to 2: the call only | Sunny, buoyant, a question |
| The Dig (E Phrygian) | Bars 1 to 4: call and answer, an octave down | The same tune in the dark |
| The Highdraft (G, raised fourth) | All 8 bars, but the last note is cut off | So close |
| The Mind | All 8 bars inverted: your own song backwards | Lonely, wrong |
| The Mind's final phase | All 8 bars the right way up in G major | It learns your song |
| Ending | S's chorus with K underneath, then the key change up | Resolved; the machine lets go |

The machine side has its own arc. M's lean always falls back down through the run (Brindle states it dead straight; the Waking compresses it into 3+3+2; in combat it is the stamp under your call). In S, and finally in the ending, the same three notes rise instead.

## Every cue, by moment

| Moment | Cue | Parent | Devices and why |
| --- | --- | --- | --- |
| Launch | title-a, title-b, title-c | K, M, S | The three themes, stated plainly, in rotation |
| Every fight | combat-hype | K bars 1 to 2 against M | Your call over their stamp: every fight is the two themes colliding. Fixes the off-key loop. |
| Champion | champion | as combat, up an octave | The golden version, same tune |
| Brindle | boss-brindle, p3, euro | M, answered by K | The duel: he states, you answer. Phase 3 at 172 swings, his arithmetic breaking. |
| The Waking | boss-waking, euro | M in E Phrygian, 3+3+2 | The Fleet's own stamp, woken into something older |
| The Mind | boss-mind, final, euro | K inverted, then upright in G major | The only boss built from your theme. Answers the ear-check flag on the Mind's final: its parent is now written, not guessed. |
| Secret areas | secret-* | that world's K, new instrument | Same tune, new room. Answers the secret Spillway ear-check flag the same way. |
| Scrap Rush, minigame | scrap-rush, minigame | M as a countdown, K as chiptune | Game inside the game |
| Run won, lost | summary-win, summary-loss | S; K bars 5 to 8 at half time | The back-up beat; the crash phrase alone, then the bell |
| Ending | ending | S against K, then the key change | Both themes together for the first time |

## What stays

Tempos (172 roaming, 129 combat, 138 to 150 boss phases, 140 to 150 for the hype drop), the keys in `harmony.gd`, the event set, the specials, the buffs, the switch-ups, the hype rule and its last-phase drop, and the call-and-response duel are unchanged. The variations system keeps working: each variation now covers a theme-derived parent, so it inherits the written tune.

## Evolve the current tracks

Andrew, 2026-10-17 03:25 to 03:27Z: keep the progress (the current soundtrack sounded awesome in game), use the full production tools for higher quality, more complexity and a bigger sound stage, and bake the production in with everything in its spot. So nothing is thrown away. Each current pick is the standing version and the sound reference until Andrew picks a replacement by ear.

| Tool | Where | Job |
| --- | --- | --- |
| `themes.py` | anywhere | The melodic spine: the cue's notes, chords, MIDI, a plain guide and a fuller stereo `preview` |
| htdemucs (6-stem model where installed) | the 4080 | Split the standing pick into drums, bass, other (and piano, guitar) |
| Rubber Band (`grid_stretch.py`) | the 4080 | Move kept stems onto the cue's key and grid: the combat loops down 3 semitones from F to D, tempo onto 129 or 172 |
| ACE-Step 1.5 XL, final quality | the 4080 | Re-render the hybrid as one production. Final quality, not the draft int8 turbo used for auditions. If the installed build has the lego or complete task, use it to add the lead over the kept stems instead of re-rendering everything. |
| The music thread's mix chain | the 4080 | EQ slots, bus compression, stereo placement, room, limiter, loudness (below). Use what is installed (the existing Python audio scripts; pedalboard or a DAW if present). |
| `check_score.py`, `check_mix.py` | cloud or the 4080 | Gate every take: key, melody, loudness, peaks, slots, seams |

Per cue:

1. Split the standing pick into stems. If `check_mix.py --cues` reports a key offset, shift the stems by that many semitones.
2. Build the hybrid source: the kept drums and bass, plus the cue's lead line. For the lead, use `python themes.py preview <cue>`'s sax, or better, an ACE-Step solo render of the guide with a sax-only caption. Add the counter line where the cue has one.
3. Cover the hybrid with ACE-Step at strength 0.45 to 0.65, using the cue's sound-bible caption, so groove, timbre and production carry over and the melody becomes the theme. Render two to four seeds.
4. Run `check_score.py` on the new take's "other" stem and `check_mix.py` on the mastered file. Put the passing takes on the soundtrack page beside the standing pick.

Order: `combat-hype` first, because it is the most-heard track and the most off key. Then roam-spillway, the titles, the worlds and roams, the bosses, camp, summaries and ending, and last the variations (re-covered from whichever parent Andrew keeps).

## Mix and master

One chain for every kept and new track, so switches, stingers and the hype drop never jump in level and every element has its own place.

| Element | Frequency slot | Stereo slot | Rule |
| --- | --- | --- | --- |
| Kick | 45 to 100 Hz fundamental, click at 3 to 5 kHz | Centre, mono | The bass ducks under it by 3 to 6 dB (sidechain) |
| Bass, 808, sub | 30 to 250 Hz | Centre, mono below 150 Hz | High-pass everything else below 120 Hz so the lows have one owner |
| Rhodes, clav, pads | 250 Hz to 2 kHz, dipped 2 to 4 kHz | Wide, left-leaning comping | Cut 2 dB at 2 to 4 kHz to leave the lead's slot |
| Sax lead | 300 Hz to 5 kHz, presence at 2 to 4 kHz | Centre, slightly left | Loudest melodic element. Nothing else boosts 2 to 4 kHz while it plays. |
| Brass, counter line | 500 Hz to 3 kHz | Opposite the comping | Answers in the gaps, never doubles the lead's octave |
| Machine percussion | 3 to 10 kHz | Spread, moving | Tuned and on the grid, as the sound bible says |
| Room | Return high-passed at 200 Hz | Full width | One shared room per world, so a cue sounds like a place |

Targets, checked by [check_mix.py](check_mix.py):

| Check | Target |
| --- | --- |
| Integrated loudness | -16 LUFS ±0.5 on every music cue (the convention RENDERS.md already uses) |
| True peak | -1 dBTP or lower |
| Low end below 150 Hz | Mono: L/R correlation at least 0.9 |
| Stereo width | Side/mid energy 0.08 to 0.6: wide, and never collapsing in mono |
| Band balance | Each band's share inside the window in `BANDS` (catches a swamping sub or an empty lead register) |
| Lead space | 2 to 5 kHz energy at least 0.06 of the 250 Hz to 2 kHz energy |
| Loop seam | For loops: last and first 50 ms within 3 dB and spectrally close |
| Clipping | No run of three full-scale samples |
| Key, with `--cues` | The cue's scale |

Stems sum back to the master within 1 dB, so the engine's stem faders (INTEGRATION section 2) play the same mix. Transitions get checked as pairs: the end of the outgoing loop against the start of the incoming one at the switch point, within 1.5 LU.

## Hand-over to the music thread

1. Spike `combat-hype` with the evolve steps above. Report back through the project coordinator with the scores from both checks for every take. If no take keeps the theme, report that too; the fallback is to keep the standing pick and lay a sax lead stem over it.
2. Work through the order above overnight. The 4080 does ACE-Step, htdemucs and Rubber Band. The cloud threads can run `check_mix.py` and `check_score.py` on anything you send to the project library.
3. Master every standing pick through the mix chain too, so tracks Andrew keeps as they are still meet the targets.
4. Record the scores from both checks beside the `measure_variants.py` table in RENDERS.md.
5. Sound bible edits (the music thread owns the file): add a "Score architecture" pointer to this page under "Title screens rotate". In the Highdraft row, keep "Lydian lift" and note that the current takes read G minor. In "Boss themes", the Mind's main theme is K inverted and its final is K upright in G major. Add the journey arc that Andrew chose with "Build to ending".

## Limits

- The guides are mock-ups. They prove the notes, not the sound, and nobody has listened to them yet.
- Whether an ACE-Step cover of a hybrid source keeps both the kept groove and the theme's melody is unproven; the round 7 to 9 covers kept real-audio parents (margins 0.05 to 0.17+). The spike in step 1 is the test.
- The scale check proves the note collection, not the tonic: D Dorian and E Phrygian share notes. The melody check is what tells the Dig from the Spillway, and on full mixes it sits close to its control; use the "other" stem.
- The mix targets are standard starting values (EBU R128 loudness, mono lows, a protected lead band), not tuned to Andrew's taste; the band windows are wide on purpose.
- Automated checks never stand in for Andrew's ear.
