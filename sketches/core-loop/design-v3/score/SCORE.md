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
4. **Render.** ACE-Step covers the guide, the same mechanism as the round 7 variations, with the sound bible's caption for the cue. The model dresses the written melody instead of inventing one.
5. **Check.** `python check_score.py <take> <cue>`: the take is in the cue's scale, and its lead line beats a control theme by 0.1, the margin `measure_variants.py` already uses.
6. **Ear.** Andrew picks by ear among the takes that pass, as now.

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

## Hand-over to the music thread

1. **One-cue spike first.** Render `roam-spillway` as a cover of `guide-roam-spillway.wav` with its current caption, seeds 2 to 4, strengths 0.45, 0.55 and 0.7. Run `check_score.py` on each take's htdemucs "other" stem. Go on only if at least one take passes and sounds like Scrapkeep to Andrew. If none passes, report the scores; the fallback is a melody-conditioned model or a played sax line over the render.
2. **Re-render the parents** from their guides: the three titles, the three worlds and roams, camp, combat and champion, the three bosses, the summaries and the ending. Keep each cue's sound-bible caption; replace any melody wording in it with the cue's lead voice from `CUES`.
3. **Re-cover the variations** from the new parents, as round 7 did.
4. **Gate every pick** on `check_score.py`; record the scores beside the `measure_variants.py` table in RENDERS.md.
5. **Sound bible edits** (the music thread owns the file): add a "Score architecture" pointer to this page under "Title screens rotate"; in the Highdraft row, keep "Lydian lift" and note that the current takes read G minor; in "Boss themes", the Mind's final is K upright in G major.

## Limits

- The guides are mock-ups. They prove the notes, not the sound, and nobody has listened to them yet.
- Whether an ACE-Step cover keeps a plain synth guide's melody is unproven; the round 7 to 9 covers kept real-audio parents (margins 0.05 to 0.17+). The spike in step 1 is the test.
- The scale check proves the note collection, not the tonic: D Dorian and E Phrygian share notes. The melody check is what tells the Dig from the Spillway, and on full mixes it sits close to its control; use the "other" stem.
- Automated checks never stand in for Andrew's ear.
