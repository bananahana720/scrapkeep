# Furnace FM (HEAT 101.3): creative briefs for the quality pass

Working document for the render run. 8 full briefs for the takes the drum-share check failed, 4 cards for the takes that only get a mix and master pass. Sources are named with each claim; `catalogue` is `sketches/core-loop/assets/radio/catalogue.json`.

## Read this first: where the melodies come from

- **The parents' actual melodies are not in text.** Every Heat take covers a parent *pick* audio file (`radio_takes.py:61-67`, `overnight.py:37-49`): rounds 4 to 6 text-to-music renders (`boss-brindle-s2402`, `boss-mind-s2402`, `roam-spillway-s2501`, `roam-highdraft-s2501`, `roam-dig-s2501`, `boss-waking-s2401`), a sketch-1 render for `title-b`, and `combat-hype-cover-mechswing-s2601` (itself a round 6 cover, `gapfill.py:31`) for every combat-hype child. SCORE.md:9 says these picks were rendered from captions, so "ACE-Step wrote a new melody for each" and "the rendered soundtrack never states" the written leitmotifs. Nothing here claims to know those notes.
- **The motifs below are the written score**, from `design-v3/score/themes.py` (themes K, M, S, lines 59-102) and `src/presentation/harmony.gd:131-142` (pilot motifs). Each is the take's hook family. Note names come from `themes.py` `derive()` for the matching cue (run this session with a NumPy stub, read-only).
- **Consequence for the render.** A cover keeps the pick's melody, not these motifs. A caption alone will not put these notes in. For a brief to be audible as written, the cover source needs the motif in it: the SCORE.md "evolve" hybrid (pick stems plus the `themes.py` guide lead, SCORE.md:110-115). Open question for the owner, listed in the report.
- **Combat-hype children cover an off-key source.** SCORE.md:15 measures `combat-hype-cover-mechswing-s2601` as centred on F (best fit +3 semitones). `radio_takes.py:84` stretches tempo only (`rubberband -T`), no pitch shift. Champion, Round Arena, Stampede and Heavyweight therefore cover an F-centred source with a D minor caption. Shift the source down 3 semitones before the cover (SCORE.md:105 names that move).

## Station rules (every take)

- Sax is the house voice. The hook is stated in the first 15 seconds and returns at the end.
- Percussion is the band's drummer: kick and bass lock, hats steady, fills only at section edges, no drum-only passage over 8 bars, at most 2 machine textures from the row. No Heat take is a drum-forward genre piece.
- Mix slots: kick and bass mono, bass 50 to 120 Hz, lead 800 Hz to 3 kHz with nothing else boosted there, 200 to 500 Hz kept clean (cut pads and found sounds there), pads and brass counter wide, machine percussion 3 to 10 kHz and spread.
- Caption shape: lead instrument and hook shape first, then harmony, then groove, percussion last as "tight supporting groove". Always: instrumental, no vocals, no pentatonic or East Asian melody or instruments. Never the word anime.

## Station motif set

Bars in 4/4, beats numbered 1 to 4, "1&" is the off-beat eighth. q = quarter, h = half, dq = dotted quarter, e = eighth. Degrees are relative to the key's tonic.

### Motif 1, "The Stamp" (them: the Furnace Fleet). Theme M bar 1, `themes.py:84`. Straight eighths, never swung.

Home key D minor (Aeolian):

| Beat | 1 | 1& | 2 | 2& | 3 | 4 | 4& |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Note | D4 e | D4 e | Eb4 e | D4 e | A4 q | F4 e | D4 e |
| Degree | 1 | 1 | b2 | 1 | 5 | b3 | 1 |

Decree bar (M bar 2, `themes.py:85`): D4 D4 Eb4 D4 (1, 1&, 2, 2&), E5 q (3), D5 q (4). The Eb lean always falls back to D. The Fleet motif in `harmony.gd:138` is the same stamp (D3 D3 Eb3 D3). Tarn's motif (`harmony.gd:135`: D3, D3, Eb3, A3) has the same shape.

Re-keys: E Phrygian 3+3+2 (the Waking, `themes.py:145-154`): E3 dq (1), E3 dq (2&), F3 q (4). G minor: G3 G3 Ab3 G3 D4 Bb3 G3.

### Motif 2, "The Call" (us: the keepers). Theme K bars 1-2, Sable's arpeggio (`themes.py:66-67`, `harmony.gd:132`). Swung eighths.

Home key D minor (Dorian, B natural):

| Bar | Beat 1 | 1& | 2 | 2& | 3 | 3& | 4 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | D4 e | F4 e | A4 e | C5 e | E5 dq (beats 3 to 4&) | | |
| Degree | 1 | b3 | 5 | b7 | 9 | | |
| 2 | D5 e | C5 e | B4 q | | A4 e | G4 e | F4 q |
| Degree | 8 | b7 | 6 | | 5 | 4 | b3 |

Re-keys (from `derive()` this session):
- G, Highdraft (`roam-highdraft`, minor third, raised fourth): G4 Bb4 D5 F5 A5 / G5 F5 E5 D5 C#5 Bb4.
- G major, the Mind's final (`euro-mind-final`): G4 B4 D5 F#5 A5 / G5 F#5 E5 D5 C5 B4.
- G, the Mind inverted (`invert()`, `themes.py:135-142`, applied to the Highdraft bar 1): G4 E4 C4 A3 e, F3 dq. A falling arpeggio: your song upside down.
- E Phrygian, the Dig, an octave down (`roam-dig`): E3 G3 B3 D4 F4 / E4 D4 C4 B3 A3 G3.
- Whole step up, E Dorian (key-change finales): E4 G4 B4 D5 F#5 / E5 D5 C#5 B4 A4 G4.
- Champion: up an octave (D5 F5 A5 C6 E6), brass a third above (`themes.py:185`, SOUND-BIBLE.md:130).

### Motif 3, "The Let-Go" (the machine lets go). Theme S bars 3-4, `themes.py:99-100`. Swung. D major.

| Bar | Beat 1 | 1& | 2 | 3 | 3& | 4 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | D5 e | Eb5 e | E5 q | C#5 e | A4 e | G4 q |
| Degree | 1 | b2 | 2 | 7 | 5 | 4 |
| 2 | F#5 h (beats 1-2) | | | E5 q | | D5 q |
| Degree | 3 | | | 2 | | 1 |

The Stamp's lean (D Eb) rising to E instead of falling back (SCORE.md:42). Use it only as a landing: the last phrase of a take. In G: G5 Ab5 A5 F#5 D5 C5 / B5 h A5 G5.

### Motif 4, "The Cannon cell" (the Mind's gun that remembered the fox). `harmony.gd:137`: B3, E4, G4, D5 with cell lengths 2, 1, 1, 4.

Rhythm reading (inference: the cell unit read as an eighth, matching how Sable's cells line up with K bar 1): B3 q (1), E4 e (2), G4 e (2&), D5 h (3-4). In G: degrees 3, 6, 1, 5. Used only in The Mind, Overclock.

### Who plays what on the station

| Take | Motif | Key | Variation | Lead |
| --- | --- | --- | --- | --- |
| Brindle, Afterburner | Stamp, answered by Call | D minor | duel, then unison, ends on Let-Go | screaming synth vs alto sax |
| The Mind, Overclock | Call inverted, then upright; Cannon cell | G | inversion to upright, G major finale | sine-chime synth, soprano sax |
| Highdraft, Hands Up | Call, all 8 bars of K | G (raised 4th) | last note withheld | soprano sax, supersaw |
| Top Shelf, Overdrive | Call | D, then E | octave lift on the drop, whole step up | alto sax |
| Champion, Club Mix | Call up an octave, Stamp under | D minor | brass a third above | synth-brass, piano |
| Round Arena, Main Event | Call as fanfare, Stamp under | D minor | tempo lift 129 to 140 | brass, alto sax |
| Heavyweight, Big Room | Stamp as bass riff, Call on sax | D minor | half-time sax | electro bass, tenor sax |
| Stampede, Encore | Call down an octave, Stamp in brass | D minor | honked, swung | baritone sax |
| Fabricator, Overclocked | Stamp | D minor | robot states, sax answers | machine lead, alto |
| Upper Bench, Live Wire | Call | E Phrygian | octave down | baritone sax |
| The Waking, 808 Edition | Stamp 3+3+2 | E, then F# | key change up | baritone sax |
| The Dam Breaks | Call | D, then E | whole step up at the break | alto sax |

---

## 1. Brindle, Afterburner (`take-brindle-afterburner`, legend, 210 s, 148 then 150 BPM, D minor)

Measured: drum median share 0.92, dominant 0.91 (`~/scratch/w17/drum-share.json`). The partner seed reads 0.38 and 0.17 (`perc/partner-share.json`), so the same caption can land well; the caption's percussion-first wording is the likely cause (inference).

- **(a) Story moment.** You have broken 150 of his machines and Brindle still thanks the region for volunteering. Anchor: "Brindle: A boiling flume. Twelve hundred tons of steam. Thank you." (LORE-ALPHA-DRAFT.md:160). Also "Brindle never raises his voice; the camera does it for him." (TONE-BIBLE.md:18).
- **(b) Feeling.** A polite admiral in a burning ship who is proud of the numbers, and you outrunning his arithmetic.
- **(c) Motif.** Stamp (his) in D minor on the synth, answered by the Call (yours) on alto sax: the duel (`themes.py:186`). Variation: in the 150 BPM finale everyone plays the Stamp in unison; the last phrase lifts into the Let-Go (D Eb E): he rounds up one last time.
- **(d) Arrangement.** Bar = 1.62 s at 148, 1.60 s at 150.

| Section | Bars | Time | Sec | What happens |
| --- | --- | --- | --- | --- |
| Hook | 8 | 0:00-0:13 | 13 | Synth lead states the Stamp twice over Dm(add9) Bbmaj7#11; bass and kick only |
| Duel | 16 | 0:13-0:39 | 26 | Sax answers each Stamp with the Call; Ebmaj9 A7b9 turnaround |
| Build | 8 | 0:39-0:52 | 13 | Brass section climbs the decree bar; filter opens |
| Chorus | 16 | 0:52-1:18 | 26 | Payoff: sax and synth trade whole bars, brass stabs on 2 and 4 |
| Turn | 7 | 1:18-1:30 | 12 | Band thins to keys and bass; one-beat fill at the edge |
| Bass only | 8 | 1:30-1:43 | 13 | The breath: bass plays the Stamp alone, a held low D on bar 1 only |
| Rebuild | 16 | 1:43-2:09 | 26 | Sax plays the Call alone over the bass, band returns at bar 9 |
| Count-in | 1 | 2:09-2:11 | 2 | Cannon volley on the four beats, bass holds D (form's hard switch) |
| Finale, 150 BPM | 32 | 2:11-3:02 | 51 | Hands-up: sax, synth, brass and bass play the Stamp in unison |
| Final return | 16 | 3:02-3:28 | 26 | The Call returns on top of the unison; last 2 bars rise into the Let-Go |
| Button | 1 | 3:28-3:30 | 2 | One unison D hit, then silence (the wink) |

- **(e) Lead and bass.** Synth lead (screaming saw, centre) states, alto sax answers left of centre. The bass doubles the Stamp's first four notes an octave or two down; the lead owns the decree.
- **(f) Percussion.** Kick four on the floor, locked to the bass's eighths. Textures (two): cannon volley (count-in and section edges only), piston kick. Steam release and ship's bell are cut as percussion parts; the ship's bell moments in the arrangement are one held bass note and the final button's unison hit instead. No passage without bass or lead.
- **(g) Mix.** Bass and kick mono 50 to 120 Hz, sidechain the bass 4 dB. Synth lead 1.5 to 3 kHz, sax 800 Hz to 2 kHz so they trade without masking. Cannon high-passed at 500 Hz so it never sits in 200 to 500 Hz. Brass wide.
- **(h) Caption.** "Instrumental Eurobeat: a screaming synth lead stamps a short repeated machine riff, D D E-flat D then a leap, and an alto saxophone answers with a rising swung arpeggio, ending in a unison finale with jazz brass. D minor, driving offbeat bass locked to a four-on-the-floor kick. Cannon volley and piston kick in a tight supporting groove. Frantic, triumphant, melodramatic. Instrumental, no vocals. No pentatonic or East Asian melody or instruments."
- **(i) Strength.** 0.42 (from 0.34). Keeps the legend's freedom for the hard switch, and holds more of the pick's groove and riff so the cover leans less on the caption's percussion. The partner seed shows the take can be balanced at low strength; 0.42 narrows the seed spread (inference).
- **(j) Test.** After one pass you can whistle the duel: four stamped notes, then the sax's rising answer.

---

## 2. The Mind, Overclock (`take-mind-overclock`, legend, 210 s, 150 BPM, G minor to G major)

Measured: 0.89 median, 0.89 dominant; partner 0.72 and 0.77. Both seeds fail.

- **(a) Story moment.** The Mind's last phase, where it finally plays your song the right way up. Anchor: "the Mind's intro card has a "LIKES" line, and the only entry is the player" (TONE-BIBLE.md:56). Cue job: "the Mind learns your song the right way up" (`themes.py:190`).
- **(b) Feeling.** A lonely machine that has been humming your song backwards gets it right, too loud and too fast, and will not stop talking.
- **(c) Motif.** The Call in G, inverted (G4 E4 C4 A3, F3) in the hard-house half, upright in G major (G4 B4 D5 F#5 A5) in the finale. The Cannon cell (B3 E4 G4 D5) is the fake ending's one voice.
- **(d) Arrangement.** Bar = 1.60 s.

| Section | Bars | Time | Sec | What happens |
| --- | --- | --- | --- | --- |
| Cold open | 4 | 0:00-0:06 | 6 | Sine-chime synth alone plays the inverted Call twice; a pad holds G |
| Hard house A | 16 | 0:06-0:32 | 26 | Inverted Call on the chime synth, bass on G and C; kick enters bar 1 |
| Answer | 16 | 0:32-0:58 | 26 | Soprano sax answers with the Call upright, one bar each |
| Glitch build | 16 | 0:58-1:24 | 26 | Relay stutter chops the chime's phrase into sixteenths; sax holds long notes |
| Peak | 16 | 1:24-1:50 | 26 | Both versions at once, inverted below, upright above |
| Wind-down | 6 | 1:50-2:00 | 10 | Band drops out one part per bar; bass last |
| Fake ending | 4 | 2:00-2:06 | 6 | Near silence: chime plays the Cannon cell once, sax holds D5 one bar too long |
| Count-in | 1 | 2:06-2:08 | 2 | One cannon hit per beat over a held bass G |
| Eurodance finale | 32 | 2:08-2:59 | 51 | G major, full band: sax, synth-brass and the relay stutter lock the upright Call in unison, a cannon hit on each phrase downbeat; the 808 holds roots |
| Final return | 16 | 2:59-3:24 | 25 | The Call's bar 8 hangs on the dominant (themes.py:62); the Let-Go in G resolves it and lands on G major |
| Button | 4 | 3:24-3:30 | 6 | Final chord rings; one relay stutter after it (it still won't shut up) |

- **(e) Lead and bass.** Chime synth then soprano sax; in the finale soprano and synth-brass in unison, an octave apart. 808 bass plays roots on the offbeat, never the hook.
- **(f) Percussion.** Kick and 808 locked; hats on the offbeat. Textures (two): relay stutter (glitch build, finale unison and the button), cannon hit (count-in and finale phrase downbeats). Electro whir and piston kick are cut as named parts.
- **(g) Mix.** 808 mono 50 to 100 Hz; kick click at 3 kHz kept short so it does not mask the soprano. Soprano and chime 1 to 3 kHz; pads wide and cut 200 to 500 Hz. Fake ending: reverb tail only, no sub.
- **(h) Caption.** "Instrumental hard house into a Eurodance finale: a glassy chime synth plays a falling arpeggio, a soprano saxophone answers with it rising, and the whole band, brass, supersaw and a stuttering relay, plays the rising version together in G major. Jazz brass, G minor turning major, pumping offbeat 808 bass. Relay stutter and cannon hits as tight supporting groove. Relentless, triumphant. Instrumental, no vocals. No pentatonic or East Asian melody or instruments."
- **(i) Strength.** 0.42 (from 0.34). Both seeds were drum-heavy, so the fix is the caption; a little more strength keeps the pick's harmony through the fake ending.
- **(j) Test.** You hear the same arpeggio fall in the first half and climb in the finale, and the climb gives you a lift.

---

## 3. Highdraft, Hands Up (`take-highdraft-hands-up`, take, 135 s, 145 BPM, G minor)

Measured: 0.89 median, 0.87 dominant, bass share 0.004 (no bass); partner 0.74 and 0.96.

- **(a) Story moment.** Ten launches in one stage, more air than ground, over the nets somebody under the isle keeps taut. Anchor: "Nets are strung under every gap. Fall all you like." (LORE-ALPHA-DRAFT.md:284).
- **(b) Feeling.** Weightless and safe: you can fall, so you fly.
- **(c) Motif.** The Call, all 8 bars of K in G with the raised fourth (C#), as `roam-highdraft` derives it. Variation: the final note is cut short (`unresolved`, `themes.py:161-164`) and we extend the device on purpose: in the last return the note is withheld, and a rope snap takes its place.
- **(d) Arrangement.** Bar = 1.66 s.

| Section | Bars | Time | Sec | What happens |
| --- | --- | --- | --- | --- |
| Hook | 8 | 0:00-0:13 | 13 | Supersaw pluck states the Call bars 1-2 twice; pad and bass |
| Verse | 16 | 0:13-0:40 | 27 | Soprano sax plays K bars 1-4; kick and bass lock |
| Riser | 8 | 0:40-0:53 | 13 | Propeller riser under the sax's held A5; snare builds in the last 2 bars only |
| Drop 1 | 16 | 0:53-1:20 | 27 | Supersaw and soprano in unison on K bars 1-4 |
| Breath | 8 | 1:20-1:33 | 13 | Pads and soprano play K bars 5-8; the last note stops short |
| Riser 2 | 4 | 1:33-1:40 | 7 | Propeller riser, bass pedal on D |
| Drop 2 | 16 | 1:40-2:06 | 26 | Soprano solo over the K changes, supersaw holds the hook underneath |
| Final return | 5.5 | 2:06-2:15 | 9 | Call once more, last note withheld; a rope snap lands where it should be |

- **(e) Lead and bass.** Soprano sax leads, supersaw doubles in drops. The bass must exist: offbeat roots of the K changes (G C G F Eb C A D, from derive), under the whole take.
- **(f) Percussion.** Kick four on the floor, offbeat open hat. Textures: propeller whir (risers only), rope snap (the final button and section edges). Wind gust is cut.
- **(g) Mix.** Bass mono 50 to 120 Hz and audible; it was missing. Soprano 1 to 3 kHz; supersaw cut at 2 to 3 kHz while the sax plays. Pads very wide.
- **(h) Caption.** "Instrumental hands-up trance house: a soprano saxophone plays a long rising arpeggio that climbs, falls back and climbs higher, doubled by a supersaw lead in each drop. G minor jazz harmony with a bright raised fourth, wide pads, audible offbeat bassline, four-on-the-floor kick. Propeller whir and rope snap in a tight supporting groove. Weightless, euphoric, fast. Instrumental, no vocals. No pentatonic or East Asian melody or instruments."
- **(i) Strength.** 0.52 (from 0.46). The pick is the Highdraft roam, which SCORE.md:17 measures in G minor with the raised fourth not audible; the caption asks for the C#, so a render may or may not carry it (inference). This take measured bass share 0.004, so the bass comes from the caption, not the pick.
- **(j) Test.** You can hum the sax's rising line, and the ending makes you wait for a note that never comes.

---

## 4. Top Shelf, Overdrive (`take-top-shelf-overdrive`, take, 135 s, 150 BPM, D minor to E minor)

Measured: 0.81 median, 0.88 dominant; partner 0.69 and 0.99.

- **(a) Story moment.** A harpoon smash at full speed along the dam's top shelf. Anchor: Moss, "Then ride the water up. Leave the wheel alone." (LORE-ALPHA-DRAFT.md:70).
- **(b) Feeling.** The rush of a ball nobody can stop, on a dam that opens on its own.
- **(c) Motif.** The Call in D Dorian (the Spillway's roam cue, bars 1-2). Variations: up an octave on the drop, then a whole step up to E for the last 30 s (E4 G4 B4 D5 F#5).
- **(d) Arrangement.** Bar = 1.60 s.

| Section | Bars | Time | Sec | What happens |
| --- | --- | --- | --- | --- |
| Hook | 8 | 0:00-0:13 | 13 | Alto sax states the Call over a filtered Dm9 G13 pad |
| Groove | 16 | 0:13-0:39 | 26 | Full groove, the Call twice, brass answers the second bar |
| Filter build | 13 | 0:39-1:00 | 21 | Filter rises on the band; sax repeats bar 1 higher each time |
| 808 drop | 16 | 1:00-1:26 | 26 | A synth lead takes the hook up an octave, the alto answers at pitch, 808 bass under; boost whoosh lands on D |
| Breath | 4 | 1:26-1:32 | 6 | Sax alone holds E5 one bar too long over a pad |
| Re-entry | 8 | 1:32-1:45 | 13 | Band back, A7 turnaround sets up the key change |
| Key change, E | 17.5 | 1:45-2:13 | 28 | Whole step up: the Call in E Dorian, brass in thirds |
| Button | 1.25 | 2:13-2:15 | 2 | Unison hit on E, boost whoosh pitched to E |

- **(e) Lead and bass.** Alto sax leads. Distorted synth bass plays roots and fifths; the 808 on the drop replaces it, never doubles it.
- **(f) Percussion.** Kick four on the floor with the 808. Textures: piston kick, steam release (section edges only). Electro whir is cut.
- **(g) Mix.** 808 and kick mono, sidechain 4 dB. Sax 800 Hz to 2.5 kHz. Steam release high-passed at 2 kHz. Pads wide.
- **(h) Caption.** "Instrumental driving electro house: a bright alto saxophone calls a rising swung hook with a falling answer, a synth lead lifts it an octave on the drop, then the band steps up a whole step for the last chorus. D minor jazz chords, filtered pads, distorted synth bass and 808 under a four-on-the-floor kick. Piston kick and steam release in a tight supporting groove. Hype, unstoppable. Instrumental, no vocals. No pentatonic or East Asian melody or instruments."
- **(i) Strength.** 0.52 (from 0.46). The pick is the Spillway roam at 172 stretched to 150; more strength keeps more of the pick (what its sax does is not measured; inference).
- **(j) Test.** You notice the key change, and the hook still sounds like the same tune afterwards.

---

## 5. Champion, Club Mix (`take-champion-club-mix`, take, 135 s, 140 BPM, D minor)

Measured: 0.73 median, 0.77 dominant; partner 0.81 and 1.00. Cover source is the off-key combat-hype pick: shift it down 3 semitones first.

- **(a) Story moment.** A champion machine worn down to its last third: the golden fight. Anchor: "Boss fights are call-and-response duels, the game's "bass battle": the boss states, the pilot's motif answers." (TONE-BIBLE.md:42). The champion is the worn-down elite: it states, you answer.
- **(b) Feeling.** A machine in its last third of health that decides to go out on a dance floor, and the steel gong rings every time it lands a phrase.
- **(c) Motif.** The Call up an octave with brass a third above (the champion cue, `themes.py:185`), the Stamp underneath in the bass (`against`, `themes.py:244-245`).
- **(d) Arrangement.** Bar = 1.71 s.

| Section | Bars | Time | Sec | What happens |
| --- | --- | --- | --- | --- |
| Hook | 8 | 0:00-0:14 | 14 | Eurodance arpeggio plays the Call up an octave; pad |
| Verse | 16 | 0:14-0:41 | 27 | Piano stabs on Dm9 G13; synth-brass hook with brass a third above |
| Build | 8 | 0:41-0:55 | 14 | Snare build in the last 2 bars only; arpeggio climbs |
| Drop 1 | 16 | 0:55-1:22 | 27 | Hook on synth-brass, the Stamp on the bass, crowd-stomp clap on 2 and 4 |
| Breakdown | 8 | 1:22-1:36 | 14 | One sax note (E5) held over Bbmaj9; piano stays |
| Build 2 | 4 | 1:36-1:43 | 7 | Arpeggio returns, filter opens |
| Final drop | 16 | 1:43-2:10 | 27 | Hook, brass third, piano and sax together |
| Tail | 3 | 2:10-2:15 | 5 | Piano plays the Let-Go once; cut on the downbeat |

- **(e) Lead and bass.** Synth-brass leads, piano riff second; sax has the one breakdown note. The brass third above sits one octave lower than the hook (at the original octave) so it stays in real brass range. The bass carries the Stamp, so hook and bass are the two themes against each other.
- **(f) Percussion.** Kick four on the floor, clap on 2 and 4. Textures: crowd stomp (as the clap), steel gong (one per phrase, SOUND-BIBLE.md:130). Cannon hit and steam hiss are cut.
- **(g) Mix.** Bass mono 60 to 120 Hz. Piano 300 Hz to 2 kHz but cut 200 to 500 Hz; synth-brass 1 to 3 kHz. Brass third panned opposite the piano.
- **(h) Caption.** "Instrumental 90s Eurodance club mix: a bright synth-brass hook climbs in stacked thirds to a high held note and drops home, answered by jazz brass a third below, over a bouncing piano riff. D minor, a short stamped bass riff, four-on-the-floor kick. Crowd stomp and one steel gong per phrase in a tight supporting groove. Euphoric, cheesy on purpose, huge. Instrumental, no vocals. No pentatonic or East Asian melody or instruments."
- **(i) Strength.** 0.55 (from 0.46), after the 3-semitone shift. SCORE.md:114's result (0.55 kept the theme) came from a hybrid source carrying the guide lead; on a plain pick cover 0.55 keeps the pick's melody, not the theme (reviewer fix 14). The caption and the key shift carry the fix; the hybrid arm tests whether the theme lands.
- **(j) Test.** You can sing the arpeggio after one pass, and the one sax note in the breakdown stops you.

---

## 6. Round Arena, Main Event (`take-round-arena-main-event`, take, 135 s, 129 then 140 BPM, D minor)

Measured: 0.69 median, 0.66 dominant; partner 0.63 and 0.85. Shift the combat-hype source down 3 semitones first.

- **(a) Story moment.** The round arena, finished, crowd on its feet. Anchor: "Cut on the beat (129 BPM house grid, 172 BPM in-run). Smash cut from loud to quiet. Use split-screen panels for face-offs and a freeze frame for every intro card." (TONE-BIBLE.md:37), and the fanfare of "the cold-open fanfare, the team roll call" (TONE-BIBLE.md:11).
- **(b) Feeling.** Your name called out like a title fight, and you walk in to it.
- **(c) Motif.** The Call as the announcer's brass fanfare (bar 1 alone, rising arpeggio), then on alto sax in full; the Stamp under it in the drop. Variation: a ring-bell switch to 140 BPM for the last round.
- **(d) Arrangement.** Bar = 1.86 s at 129, 1.71 s at 140.

| Section | Bars | Time | Sec | What happens |
| --- | --- | --- | --- | --- |
| Stomp intro | 4 | 0:00-0:07 | 7 | Stomp-stomp-clap over a held sub D and a pad (not drums alone) |
| Fanfare | 8 | 0:07-0:22 | 15 | Brass plays Call bar 1 as a fanfare, answered by the pad; the crowd chants the Stamp's rhythm (stomp-stomp-clap) under it |
| Verse | 16 | 0:22-0:52 | 30 | Alto sax plays the Call and answer; brass answers in gaps |
| Build | 8 | 0:52-1:07 | 15 | Brass climbs; snare build in the last 2 bars only |
| Big-room drop | 16 | 1:07-1:37 | 30 | Sax and brass unison on the hook; the Stamp lives in the crowd chant, not the bass (it is Heavyweight's bass job) |
| Ring bell | 1 | 1:37-1:39 | 2 | One ring bell, one beat of silence |
| Final round, 140 | 20 | 1:39-2:13 | 34 | Faster: hook on sax, brass fanfare between phrases |
| Button | 1 | 2:13-2:15 | 2 | Unison hit, ring bell |

- **(e) Lead and bass.** Alto sax leads, brass plays fanfare and answers. Bass plays the Stamp only in the drop and final round, roots elsewhere.
- **(f) Percussion.** Kick four on the floor. Textures: crowd stomp (intro and clap), ring bell (switch and button only). Piston kick is cut.
- **(g) Mix.** Sub and kick mono. Brass 500 Hz to 2 kHz and wide; sax 1 to 3 kHz centre. Crowd stomp high-passed at 150 Hz and cut at 200 to 500 Hz.
- **(h) Caption.** "Instrumental big-room electro swing house: a brass fanfare leaps up four bold notes and holds like a ring announcer, then a hype alto saxophone sings the call back with a falling tail, brass shouting in the gaps. D minor jazz chords, pumping bass riff, four-on-the-floor kick, lifting to a faster final round. Crowd stomp and ring bell in a tight supporting groove. Rowdy, proud. Instrumental, no vocals. No pentatonic or East Asian melody or instruments."
- **(i) Strength.** 0.52 (from 0.46), after the shift. Enough to keep the pick's groove; the fanfare comes from the caption.
- **(j) Test.** You can hum the fanfare, and you hear it is the same tune as the sax hook.

---

## 7. Heavyweight, Big Room (`take-heavyweight-big-room`, take, 135 s, 132 BPM, D minor)

Measured: 0.65 median, 0.67 dominant (just over the line); partner 0.44 and 0.43. Shift the combat-hype source down 3 semitones first.

- **(a) Story moment.** Three events won in one run: the mini-boss weigh-in. Anchor: the Collision beat, "the stakes arrive | smash cut, rival's intro card, music drops to bass only" (TONE-BIBLE.md:27). The weigh-in is a rival's intro card; the bass riff is the snarl, the sax the pilot who stays calm (Tarn's shape, TONE-BIBLE.md:51).
- **(b) Feeling.** A calm, kind giant facing a snarling heavy machine, and not raising his voice.
- **(c) Motif.** The Stamp as the heavy electro bass riff (the machine snarling); the Call on tenor sax (the calm giant). Tarn's own motif has the Stamp's shape (`harmony.gd:135`). Variation: the sax plays the Call in half time in the breakdown.
- **(d) Arrangement.** Bar = 1.82 s.

| Section | Bars | Time | Sec | What happens |
| --- | --- | --- | --- | --- |
| Riff | 8 | 0:00-0:15 | 15 | Electro bass states the Stamp; pad; kick on bar 5 |
| Build A | 16 | 0:15-0:44 | 29 | Tenor sax enters with the Call; brass stabs answer the riff |
| Anvil roll | 4 | 0:44-0:51 | 7 | Anvil snare roll under a riser, bass holds D |
| Drop 1 | 16 | 0:51-1:20 | 29 | Riff and sax together, brass stabs on the offbeats |
| Half-time sax | 8 | 1:20-1:35 | 15 | Half-time feel: sax plays the Call slowly over keys and bass |
| Re-build | 4 | 1:35-1:42 | 7 | Riser, riff returns |
| Double drop | 16 | 1:42-2:11 | 29 | Two 8-bar drops back to back, the second with brass on the hook |
| Tail | 2 | 2:11-2:15 | 4 | Sax plays the Let-Go: the lean rises, the giant smiles |

- **(e) Lead and bass.** The bass riff is a melody here, so the sax stays above it (1 octave plus). The sax leads every section after bar 9.
- **(f) Percussion.** Kick four on the floor locked to the riff. Textures: anvil hit (as the snare and the roll), hammering piston (offbeat, quiet). Crowd roar is cut.
- **(g) Mix.** Riff fundamental 50 to 120 Hz mono, its grit 1 to 2 kHz; cut it at 2 to 3 kHz to leave the sax's slot. Anvil high-passed at 400 Hz.
- **(h) Caption.** "Instrumental big-room electro house: a calm tenor saxophone plays a rising arpeggio melody over a heavy stamped electro bass riff, D D E-flat D then a leap, brass stabs answering. D minor, half-time sax breakdown, double drop, four-on-the-floor kick. Anvil hits and hammering piston in a tight supporting groove. Heavy, calm, proud, pumping. Instrumental, no vocals. No pentatonic or East Asian melody or instruments."
- **(i) Strength.** 0.50 (from 0.46). The partner seed is balanced, so a small rise is enough.
- **(j) Test.** You can hum both the bass riff and the sax line, and you can tell them apart.

---

## 8. Stampede, Encore (`take-stampede-encore`, b-side, 85 s, 150 BPM, D minor)

Measured: 0.78 median, 0.96 dominant; partner 0.91 and 0.96, worse. Shift the combat-hype source down 3 semitones first.

- **(a) Story moment.** The scrap stampede is won and the junk comes back for a bow. Anchor: "Machines are workers, not monsters, so a downed machine gets a tiny "shift over" gag (a clock-out stamp, a sigh of steam)." (TONE-BIBLE.md:40).
- **(b) Feeling.** A curtain call for the junk that just tried to flatten you.
- **(c) Motif.** The Call down an octave on honking baritone sax (D3 F3 A3 C4 E4), swung; the Stamp in the brass stabs.
- **(d) Arrangement.** Bar = 1.60 s.

| Section | Bars | Time | Sec | What happens |
| --- | --- | --- | --- | --- |
| Hook | 4 | 0:00-0:06 | 6 | Bari honks the Call over swung bass and kick |
| A | 16 | 0:06-0:32 | 26 | Bari hook, brass stabs play the Stamp between phrases |
| Turn | 4 | 0:32-0:38 | 6 | ii-V turnaround in the brass; one scrap fill on the last beat |
| Bari break | 8 | 0:38-0:51 | 13 | Honking bari solo over bass and kick |
| Breath | 2 | 0:51-0:54 | 3 | Band stops; a hubcap rolls left to right alone (the egg) |
| Final A | 16 | 0:54-1:20 | 26 | Hook and Stamp together, full band |
| Bow | 3 | 1:20-1:25 | 5 | Brass plays the Let-Go, one steam sigh |

- **(e) Lead and bass.** Bari leads; walking swung bass on roots and fifths, below the bari's register.
- **(f) Percussion.** Swung kick and hats, a light snare on 2 and 4. Textures: clattering scrap (fills at section edges only), hubcap roll (the egg). "Galloping drums" is cut: it is the likely strangler (inference from both seeds failing).
- **(g) Mix.** Bass mono 50 to 120 Hz. Bari 200 to 500 Hz is its body, so cut everything else there. Brass wide. Scrap high-passed at 2 kHz. Hubcap panned hard left to hard right.
- **(h) Caption.** "Instrumental electro swing house: a honking baritone saxophone plays a swung hook that climbs and flops back down like a tumbling pile of junk, brass stabs replying in a short stamped riff. D minor swing chords, walking bass, a straight four-on-the-floor kick, swung hats. Clattering scrap and one hubcap roll in a tight supporting groove. Chaotic, fun, breathless. Instrumental, no vocals. No pentatonic or East Asian melody or instruments."
- **(i) Strength.** 0.60 (from 0.56). A b-side stays close to its parent; both seeds failed, so the caption change is the main fix.
- **(j) Test.** You can whistle the bari hook, and the hubcap makes you smile.

---

## Cards: mix and master pass only

### Fabricator, Overclocked (`take-fabricator-overclocked`, b-side, 85 s, 128 BPM, D minor)
1. Anchor: Moss, "every crisis ends with Moss holding the spare part" (TONE-BIBLE.md:54).
2. Feeling: the satisfying click of three parts that fit.
3. Motif: the Stamp in D minor on the robot lead, sax answers (title-b is theme M, `themes.py:175`).
4. Lead vs bass: robot lead states, sax answers in the gaps; bass on roots.
5. Mix flag: drum median 0.58, dominant 0.67. The failing bar is median >= 0.65 AND dominant >= 0.65, so it passes on median; it gets a card, not a brief, and a 2 dB drum trim in the master pass (ratchet and conveyor clank down).

### Upper Bench, Live Wire (`take-upper-bench-live-wire`, b-side, 85 s, 138 BPM, E minor)
1. Anchor: "Conveyor sign-out: belt stopped for lunch. Lunch tins arrived at the hoist house anyway." (LORE-ALPHA-DRAFT.md:206).
2. Feeling: the machines working on through lunch, lamps flickering, nobody minding.
3. Motif: the Call in E Phrygian, an octave down (E3 G3 B3 D4 F4), on baritone sax.
4. Lead vs bass: bari sits above the bass by an octave; keep them apart in 200 to 500 Hz.
5. Mix flag: drum median 0.34 (drum-share.json), fine; check the bari is the loudest melodic part.

### The Waking, 808 Edition (`take-waking-808`, take, 135 s, 129 BPM, E minor)
1. Anchor: "Waking: The pool was mine first. You may keep the lamps." (LORE-ALPHA-DRAFT.md:272).
2. Feeling: something old and huge, polite about it, then shaken loose into joy.
3. Motif: the Stamp in E Phrygian on the 3+3+2 grid (E3 dq, E3 dq, F3 q), then a key change up.
4. Lead vs bass: growling bari over the 808; the 808 carries 0.60 of the loudness (drum-share.json bass_share), so it is the louder risk.
5. Mix flag: mono the 808 below 120 Hz and pull it 2 dB so the bari reads. Keep the seismograph needle scratch under the 808 audible (the catalogue's egg).

### The Dam Breaks (`take-dam-breaks`, legend, 210 s, 172 BPM, D minor)
1. Anchor: "Fleet notice, posted at both ends of the river: ALL WATER IS NOW INVENTORY. Below it, in chalk: Tell the river." (LORE-ALPHA-DRAFT.md:399).
2. Feeling: the river answering the Fleet's notice, all at once.
3. Motif: the Call in D Dorian on alto sax; after the 1:30 silence, a whole step up (E4 G4 B4 D5 F#5).
4. Lead vs bass: alto over brass swells; bass carries 0.45 of the loudness (drum-share.json), keep it mono and under the sax.
5. Mix flag: drum median 0.32, fine; check the dripping-water silence holds no sub rumble.


## Review log (2026-10-19)

Captions are capped at 512 characters (ACE-Step reads no more); every caption above is under it.

Independent review (verifier, evidence 4 for notes, quotes and numbers): FAIL on Champion and The Mind, Overclock, PASS+NOTES on the rest. Applied above: fixes 1-21 except those listed here. Not applied: the odd phrase lengths in the maps (kept so sections sum to the catalogue seconds), the G3 note in motif 1 (no take uses it), "double drop" wording (kept; the form line is the catalogue's). Open: the hybrid-source arm is tested after the caption arm.
