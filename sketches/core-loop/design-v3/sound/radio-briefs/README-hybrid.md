# Hybrid cover sources (Furnace FM quality pass)

Built 2026-10-18 by `~/scratch/w17/qp/hybrid-work/build_hybrid.py`, following SCORE.md 'Per cue' steps 1-3.
Each file = the parent pick's htdemucs (4-stem) bass at 0 dB + drums at -9 dB + other at -12 dB + the motif lead
(themes.py `sax` FM reed voice, notes from themes.py `derive()`), on the stretched source's bpm grid, phase-aligned to
the drums stem's beat. Lead level: its voiced RMS set equal to the parent full mix's RMS. A counter line (themes.py
`mute_brass`, 6 dB under the lead) plays where the brief names one. If the sum peaked above -1.5 dBFS, the whole mix
was trimmed together (relative gains unchanged). Same sample count as the source, 48 kHz stereo, 24-bit.
Lead-only renders and per-take metadata (every lead note's time, pitch, length) are in `~/scratch/w17/qp/hybrid-work/`.

Not done on purpose (kept simple; the cover re-voices it): no tempo changes inside a take (the parent stems are at one
tempo, so Brindle's 150 finale and Round Arena's 140 final round stay at 148 and 129), no textures, no filter moves.
Section lengths follow each brief's (d) table from bar 1 of the detected beat grid; the parent's own section edges are
not aligned to them.

## take-brindle-afterburner-148-hybrid.wav

- Source: `/home/andrew/Music/Scrapkeep-sound-direction/sound-bible-2026-10-16/radio/src/take-brindle-afterburner-148.wav` (148 BPM). Cue: `boss-brindle`. Key: D minor (Aeolian).
- Mapping: Brief 1 (c): the Stamp answered by the Call is the duel, themes.py:186 boss-brindle (M bars 1-4, answer K). Notes used: boss-brindle (M bars 1-4, D Aeolian, answered by K bars 1-2); Let-Go = S bars 3-4.
- Stems and gains: bass +0 dB, drums -9 dB, other -12 dB, lead at full level (x0.282), counter -6 dB under the lead; master trim 0.0 dB. Beat grid offset 0.0 s.
- Lead sections (bars: what plays): 8: Hook: Stamp + decree (M 1-4) twice; 16: Duel: M 1-4 answered by K 1-2; 8: Build: M 1-4; 16: Chorus: M and K trade; 7: Turn: K call; 8: Bass only: Stamp; 16: Rebuild: Call alone; 1: Count-in: held D4; 32: Finale: Stamp unison (kept at 148, the source tempo); 16: Final return: Call, last 2 bars Let-Go; 1: Button: D hit.

## take-champion-club-mix-140-hybrid.wav

- Source: `/home/andrew/scratch/w17/qp/remake/src/take-champion-club-mix-140-down3.wav` (140 BPM). Cue: `champion`. Key: D Dorian (D minor family).
- Mapping: Brief 5 (c): Call up an octave, brass a third above, Stamp under (themes.py:185, against M). Notes used: champion (K bars 1-2 up an octave, D Dorian, against M); brass third = diatonic third above at the original octave.
- Stems and gains: bass +0 dB, drums -9 dB, other -12 dB, lead at full level (x0.192), counter -6 dB under the lead; master trim 0.0 dB. Beat grid offset 0.275 s.
- Lead sections (bars: what plays): 8: Hook: Call up an octave; 16: Verse: hook, brass a third above; 8: Build; 16: Drop 1: hook, Stamp under; 8: Breakdown: E5 held; 4: Build 2; 16: Final drop: hook and brass third; 3: Tail: Let-Go.

## take-heavyweight-big-room-132-hybrid.wav

- Source: `/home/andrew/scratch/w17/qp/remake/src/take-heavyweight-big-room-132-down3.wav` (132 BPM). Cue: `combat-hype (+ boss-brindle Stamp)`. Key: D Dorian over D Aeolian Stamp.
- Mapping: Brief 7 (c): Stamp as the riff, Call on sax over it; combat-hype pairs exactly these two (themes.py:184). Notes used: combat-hype (K bars 1-2 D Dorian over M bars 1-2); Stamp from boss-brindle bars 1-2, an octave down.
- Stems and gains: bass +0 dB, drums -9 dB, other -12 dB, lead at full level (x0.195), counter -6 dB under the lead; master trim 0.0 dB. Beat grid offset 0.445 s.
- Lead sections (bars: what plays): 8: Riff: Stamp, low; 16: Build A: Call over the Stamp; 4: Anvil roll; 16: Drop 1; 8: Half-time sax; 4: Re-build: riff; 16: Double drop; 2: Tail: Let-Go.

## take-highdraft-hands-up-145-hybrid.wav

- Source: `/home/andrew/Music/Scrapkeep-sound-direction/sound-bible-2026-10-16/radio/src/take-highdraft-hands-up-145.wav` (145 BPM). Cue: `roam-highdraft`. Key: G, minor third, raised fourth.
- Mapping: Brief 3 (c) names roam-highdraft: all 8 bars of K, last note cut (themes.py:183). Notes used: roam-highdraft (K 1-8, G with minor third and raised fourth, last note cut short).
- Stems and gains: bass +0 dB, drums -9 dB, other -12 dB, lead at full level (x0.216), counter -6 dB under the lead; master trim 0.0 dB. Beat grid offset 0.325 s.
- Lead sections (bars: what plays): 8: Hook: call bars 1-2; 16: Verse: K 1-4; 8: Riser: K 1-4; 16: Drop 1: K 1-4; 8: Breath: K 5-8, last note short; 4: Riser 2: K 1-4; 16: Drop 2: all 8 bars; 5.5: Final return: call, last note withheld.

## take-mind-overclock-150-hybrid.wav

- Source: `/home/andrew/Music/Scrapkeep-sound-direction/sound-bible-2026-10-16/radio/src/take-mind-overclock-150.wav` (150 BPM). Cue: `boss-mind, boss-mind-final`. Key: G (minor, raised 4th) to G major.
- Mapping: Brief 2 (c): Call inverted (boss-mind, themes.py:189, invert) then upright in G major (boss-mind-final, themes.py:190); Cannon cell from heat.md motif 4. Notes used: boss-mind (K 1-8 inverted in G) then boss-mind-final (K 1-8 G major); Cannon cell from heat.md motif 4; Let-Go in G.
- Stems and gains: bass +0 dB, drums -9 dB, other -12 dB, lead at full level (x0.176), counter -6 dB under the lead; master trim 0.0 dB. Beat grid offset 0.24 s.
- Lead sections (bars: what plays): 4: Cold open: inverted call twice; 16: Hard house A: inverted K; 16: Answer: K upright, G; 16: Glitch build: inverted K; 16: Peak: upright above, inverted below; 6: Wind-down; 4: Fake ending: Cannon cell, held D5; 1: Count-in: held G4; 32: Eurodance finale: K in G major; 16: Final return: K G major, Let-Go in G; 4: Button: G rings.

## take-round-arena-main-event-129-hybrid.wav

- Source: `/home/andrew/scratch/w17/qp/remake/src/take-round-arena-main-event-129-down3.wav` (129 BPM). Cue: `combat-hype`. Key: D Dorian (D minor family).
- Mapping: Brief 6 (c): Call as fanfare and on sax, Stamp under in the drop: combat-hype's K-against-M (themes.py:184). Notes used: combat-hype (K bars 1-2, D Dorian, against M bars 1-2).
- Stems and gains: bass +0 dB, drums -9 dB, other -12 dB, lead at full level (x0.195), counter -6 dB under the lead; master trim 0.0 dB. Beat grid offset 0.285 s.
- Lead sections (bars: what plays): 4: Stomp intro: lead silent; 8: Fanfare: Call bar 1, then a bar of space; 16: Verse: Call and answer; 8: Build; 16: Big-room drop: hook, Stamp under; 1: Ring bell; 20: Final round (kept at 129, the source tempo); 1: Button.

## take-stampede-encore-150-hybrid.wav

- Source: `/home/andrew/scratch/w17/qp/remake/src/take-stampede-encore-150-down3.wav` (150 BPM). Cue: `combat-hype call, down an octave`. Key: D Dorian (D minor family).
- Mapping: Brief 8 (c): Call down an octave (D3 F3 A3 C4 E4) with the Stamp in brass stabs. Notes used: combat-hype call (K bars 1-2 D Dorian) down an octave; Stamp (boss-brindle bars 1-2) as brass counter.
- Stems and gains: bass +0 dB, drums -9 dB, other -12 dB, lead at full level (x0.189), counter -6 dB under the lead; master trim 0.0 dB. Beat grid offset 0.38 s.
- Lead sections (bars: what plays): 4: Hook: Call down an octave; 16: A: Call, Stamp between phrases; 4: Turn; 8: Bari break; 2: Breath; 16: Final A: Call and Stamp together; 3: Bow: Let-Go.

## take-top-shelf-overdrive-150-hybrid.wav

- Source: `/home/andrew/Music/Scrapkeep-sound-direction/sound-bible-2026-10-16/radio/src/take-top-shelf-overdrive-150.wav` (150 BPM). Cue: `roam-spillway`. Key: D Dorian, then E Dorian.
- Mapping: Brief 4 (c): the Call in D Dorian, the Spillway roam cue bars 1-2 (themes.py:179); E Dorian via to_mode for the key change. Notes used: roam-spillway (K bars 1-2, D Dorian); E Dorian for the key change (to_mode).
- Stems and gains: bass +0 dB, drums -9 dB, other -12 dB, lead at full level (x0.223), counter -6 dB under the lead; master trim 0.0 dB. Beat grid offset 0.24 s.
- Lead sections (bars: what plays): 8: Hook: Call; 16: Groove: Call; 13: Filter build: bar 1 repeated; 16: 808 drop: Call up an octave, answer at pitch; 4: Breath: Call; 8: Re-entry: Call; 17.5: Key change: Call in E Dorian; 1.25: Button: E hit.

## Check

```
== ffprobe
48000,2 210.000000  take-brindle-afterburner-148-hybrid.wav
48000,2 135.000000  take-champion-club-mix-140-hybrid.wav
48000,2 135.000000  take-heavyweight-big-room-132-hybrid.wav
48000,2 135.000000  take-highdraft-hands-up-145-hybrid.wav
48000,2 210.000000  take-mind-overclock-150-hybrid.wav
48000,2 135.000000  take-round-arena-main-event-129-hybrid.wav
48000,2 85.000000  take-stampede-encore-150-hybrid.wav
48000,2 135.000000  take-top-shelf-overdrive-150-hybrid.wav
== source durations
210.000000 take-brindle-afterburner-148.wav
135.000000 take-highdraft-hands-up-145.wav
135.000000 take-top-shelf-overdrive-150.wav
210.000000 take-mind-overclock-150.wav
135.000000 take-champion-club-mix-140-down3.wav
135.000000 take-heavyweight-big-room-132-down3.wav
135.000000 take-round-arena-main-event-129-down3.wav
85.000000 take-stampede-encore-150-down3.wav
== pitch check
take                                  frames       src     sr ch peak dB   nfr  lead lead8va   mix mix8va   ctl
take-brindle-afterburner            10080000  10080000  48000  2   -3.13   784  1.00    1.00  0.89   0.99  0.00
take-highdraft-hands-up              6480000   6480000  48000  2   -4.30   735  0.98    0.98  0.91   0.98  0.00
take-top-shelf-overdrive             6480000   6480000  48000  2   -3.76   687  0.98    0.98  0.51   0.78  0.00
take-mind-overclock                 10080000  10080000  48000  2   -7.95   686  0.97    0.97  0.97   0.97  0.00
take-champion-club-mix               6480000   6480000  48000  2   -5.97   774  0.97    0.97  0.95   0.95  0.00
take-round-arena-main-event          6480000   6480000  48000  2   -5.96   204  0.97    0.97  0.92   0.94  0.00
take-heavyweight-big-room            6480000   6480000  48000  2   -6.24   854  1.00    1.00  0.95   0.99  0.00
take-stampede-encore                 4080000   4080000  48000  2   -6.87   519  0.98    0.98  0.98   0.98  0.00
format failures: none

receipt: hybrid-work/.astack/receipts/cap-c5872c98c3f2dbd7.json (exit 0)
```

lead / mix = share of note frames in the first 8 bars where pyin pitch is within 0.5 semitone of the written note,
on the lead-only render and on the hybrid mix; 8va columns forgive an octave error.
