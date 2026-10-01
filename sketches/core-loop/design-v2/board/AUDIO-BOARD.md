# Audio board, core-loop v2 primer

Fourteen short demos of how v2 will sound, for the primer's storyboard gate (TRACKING EV-0588). Every note comes from the sketch's own synth, band and cue bank, played on the game's timeline at the game's mix levels. Nothing is recorded or sampled. Each file is matched to -14 LUFS with peaks under -1 dBFS, so you can skip between them without touching the volume. Everything is in D, the band's home, unless a demo lifts the key.

The files are in `artifacts/local/v2-primer/audio/` at the repository root. To render them again:

```
godot --headless --path sketches/core-loop --script res://tools/audio_board.gd
```

Add `-- --only=08,09` to render a few, or `-- --out=/some/dir` to write elsewhere. Times below are from the start of each file.

## What to listen for

| File | Listen for | It should answer |
| --- | --- | --- |
| `01-sable-leitmotif.wav` (17 s) | Sable's arpeggio D F A C E in even sixteenths on mallet, twice bare (0.3 s, 1.7 s). At 3.1 s it resolves its open ninth onto a bright bell chord. Over the stage 1 groove from 5.2 s, the ready pulse (6.6 s, 11.2 s) is the first note an octave up. The release lands on the frame, not the beat (8.8 s, 12.8 s, 15.0 s). | Does it rise and launch like the fox? Q1, Q2 |
| `02-rivet-leitmotif.wav` (17 s) | Rivet's hammered A A A up a fourth to D, on clav over a closed-hat roll. The release doubles the roll's rate into an open-hat crash. Same timings as 01. | Does it hammer and never stop? Q1, Q2 |
| `03-kest-leitmotif.wav` (17 s) | Kest's D A F D falling in eighths on a tuned tom, the last thump doubled on an 808 an octave down: tick, tick, tick, boom. Same timings as 01. | Does it drop and land? Q1, Q2 |
| `04-fleet-motif.wav` (14 s) | The Fleet's stamp, stamp, decree: two anvil hits on the beat and a brass semitone lean, D to Eb and back. Alone at 0.3 s and 1.7 s. Then over the groove, a pack's callout chime (5.5 s, 8.3 s, 11.1 s) and the motif landing on the next beat as an announcement. | Q3, Q12 |
| `05-reactor-relic.wav` (12 s) | From 2.8 s the sub leaves the chord roots and sits on Ab, the tritone, under the unchanged bass line. Geiger clicks speed up for four bars as the vent charges. It blows on the downbeat at 8.4 s, and the sub goes back to the roots on that same downbeat. | Q4 |
| `06-swarm-remnant.wav` (10 s) | A thin buzz on one high G, pulsed in sixteenths (1.4 s). It snaps into stacked fourths D G C F when the formation locks (2.5 s), then falls apart into detuned single notes when scattered (4.2 s). Again from 5.6 s. The band underneath never changes. | Q5 |
| `07-mind-quote.wav` (12 s) | The player's release, then the Mind's hand answering it a bar later on a pure, long, slightly flat sine: every interval flipped and the last note a semitone wrong. Sable (1.3 s, answered at 2.6 s) comes back D B G E B. Rivet (4.5 s, 5.9 s) comes back A A A Eb. Kest (7.7 s, 9.1 s) comes back D G B C#. | Q6 |
| `08-stage-theme-escalation.wav` (34 s) | Spillway at mid pressure. Pressure rises at 5.6 s and the counter-line brings in Sable's arpeggio as a quiet bell layer under the sax (7.7 s, 10.5 s). The event passing half way plays a pickup bar on Bb7b9 (14.0 s), then everything lifts a half step to Eb with the sax up an octave (15.3 s). The arpeggio returns in the new key (30.0 s, 32.8 s). | Q7 |
| `09-moss-lounge-and-drop.wav` (23 s) | The full band, the plant clack as the ball banks (2.2 s), then from 2.8 s the same tune as a lounge. The sax plays the Spillway motif at half speed with a wider scoop and slower vibrato, over brushes, a half-time snare, the calm bass on a clean sub and keys on beats 1 and 3. A shop bell at 9.2 s. The exit slingshot (13.5 s) starts the launch build. It sits on A7b9 while you fly and resolves to D on the landing drop, the full band again (15.4 s). | Q8 |
| `10-threat-reel.wav` (11 s) | The four threat types after a second of groove each. Instant is ratchet clicks speeding up into a clang on Eb (1.0 s). Wave is a whoosh rising Eb to Bb (3.3 s). Projectile is a thunk and a whistle falling Bb to Eb (5.5 s). Lane is a hum on Ab that tears (7.8 s). The bass ducks under each. | Q9 |
| `11-cc-chain-break-free.wav` (12 s) | Two telegraphs at 1.4 s, then holds stack with the bass ducking deeper: a pit on D, a bola on Bb, a tether on Eb that strains upward, a net on Ab. The chord grows more wrong, and a rising sine means it is about to end (3.2 s). You break free at 3.9 s: the holds cut, a bright burst, Sable's first interval, the boost whoosh and the bass back from that frame. The second chain (7.0 s) is held until tenacity at 9.5 s: a cymbal choke, then the same interval and the bass back over a beat. | Q10 |
| `12-moss-babble.wav` (32 s) | Moss over the lounge. Each press is the pilot's nod (Sable's first note), then one beat of babble, one blip per letter. Beats 1 to 5 climb D E F G A, faster each time, and beat 6, the send-off, drops to C. A low grumble sits under the first word of beats 2, 4 and 6. The relent (last line) is slower, warmer and ends in a sigh down a fifth, then the shop bell. | Q11 |
| `13-ui-utility-reel.wav` (10 s) | Over the calm groove, so you can judge whether each cuts through. The ready pulses are Sable (0.8 s), Rivet (1.8 s) and Kest (2.8 s). Then the callout chime (3.8 s), the shop bell (5.0 s), Moss's bench clank (6.3 s) and the milestone stinger on the beat (7.3 s). | Q2, Q12 |
| `14-fleet-difficulty-ticks.wav` (17 s) | The difficulty clock ticks three times (the threat stinger at 3.5 s, 7.7 s and 11.9 s), and each tick adds a Fleet layer from the next bar. Tick 1 adds an anvil on beats 2 and 4 (4.2 s). Tick 2 adds a brass lean answering the sax in each bar's second half (8.4 s). Tick 3 puts the anvil on every beat (12.6 s). Nothing is taken away. | Q13 |

## Questions for you

Answer by number. Any of them can be "fine as is".

1. Can you tell Sable, Rivet and Kest apart with your eyes closed, and does each move like its character?
2. Does the ready pulse tell you "F is back" and whose it is, or is it too quiet or too alike across classes?
3. Does the Fleet motif read as Brindle's crew? Is it too comic, too heavy or right?
4. Is the reactor's Ab under the band dread without spoiling the groove, and are the speeding clicks a clock you can read?
5. Does the swarm's lock sound like "they locked", and its scatter like relief?
6. Does the Mind's quote sound like "it learned my habit", or just a wrong note? Are Rivet's and Kest's quotes as readable as Sable's?
7. In 08, is Sable's arpeggio in the counter-line too buried, too forward or right? Does the half-step lift feel like escalation?
8. Does the lounge feel like the same tune calmed down rather than a new track, and does the drop back in land with the old gusto?
9. Can you tell the four threat types apart without looking, and does each sound like danger rather than a reward?
10. In the crowd-control chain, does the stacking chord feel like danger building, and the bass returning like freedom? Is it too long or too loud?
11. Is Moss's babble charming or grating? Does the rising pitch read as exasperation, and the relent as a sigh?
12. The callout chime (two dry pings, A then D) is a stand-in, because no source defines it. Keep it, or should a pack callout carry its faction's motif instead? Is the shop bell rice-cooker enough?
13. Can you hear each difficulty tick add a Fleet layer? Does tick 3 get too clanky?

## Not on this board yet

- The vertical gorge's layers by height (the undercroft's reese, the sky's bells).
- An ancient's own arrival cue.
- The gauge-charge and charge-pip cues.
- The game wiring. The demos drive the band directly; nothing in play triggers these layers yet.
