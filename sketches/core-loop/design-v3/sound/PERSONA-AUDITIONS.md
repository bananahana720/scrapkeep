# Sound persona auditions: one tune, three years of the same band

Render brief for the PC (ACE-Step on the RTX 3060 or an idle 4080), written 2026-11-09 by the sound thread ("Develop sound artist and game music"). It changes no game file. The renders let Andrew judge the sound persona by ear on a phone: the same two picked tunes, produced the way the band would have produced them in three different years. The persona page that these feed is in the project library (INDEX.md, "Direction").

**Outcome (10 November 2026): Andrew picked 2010, the festival years.** The band's section in [SOUND-BIBLE.md](../SOUND-BIBLE.md) records it. The fight and anthem cells decided it; the roam cell was left out of the card, and the free cell went up as an extra (one take per year). The captions under A are now the pattern for new music; B and C are for radio records. Roaming takes in 2010 follow "Roaming after the pick" at the end.

## What to render

Three candidates, each a dated period of one band (the house band, working name Local 172). Per candidate: two covers of picks Andrew already knows, plus one free render with no parent so the period's own sound is heard without the parent's production showing through.

| Cell | Parent (under `~/Music/Scrapkeep-sound-direction/sound-bible-2026-10-16/`) | Mode | Tempo | Length |
| --- | --- | --- | --- | --- |
| roam | `spice/roam-spillway-current.wav` (the Spillway roaming pick, 172.0 read) | cover, strength 0.55 | 172 | 64 s |
| fight | `spice/boss-brindle-spiced.wav` (Brindle's fight pick, 129.0 read) | cover, strength 0.55 | 129 | 64 s |
| free | none | text to music | 129 | 64 s |
| anthem | Brindle's phase 1 anthem pick, `anthem-brindle-s4202.wav` (the take the `anthem_brindle` pack names; this is what plays in his fight today) | cover, strength 0.55 | 140 | 64 s |

The anthem cell was added after the first 18 were queued; it uses each candidate's fight caption with the tempo changed to 140 BPM. Seeds 6101 and 6102 for every cell: 3 candidates x 4 cells x 2 seeds = 24 renders, draft mode, instrumental, key D minor (Dorian). If a cover at 0.55 still sounds like the parent's production, render that cell again at 0.45 with the same seeds and return both.

## Captions

Never write "anime" in a caption, never a real artist's name, and never ask for vocals. Every caption ends with: `instrumental, D Dorian, melody-led, saxophone hook clearly on top, drums supporting`. After that line every caption also carries the standing guard: `No pentatonic or East Asian melody or instruments`. ACE-Step's keyscale field is D minor; Dorian comes from the caption.

### A. The festival years (sounds like 2010)

- roam: `2010 liquid drum and bass, 172 BPM, rolling two-step breakbeat, warm Rhodes ninth chords chopped into offbeat stabs, live alto saxophone lead in call and response, reese sub bass, sidechain pumping pads, filter sweep into each chorus, tuned piston and steam valve hits as fills, glossy bright laptop production, tight and loud`
- fight: `2010 French electro house and big room, 129 BPM, four on the floor kick, heavy sidechain pump, distorted filtered jazz chord stabs, overdriven bass, live alto saxophone hook doubled by a supersaw lead, snare roll build, one beat of silence, big drop, tuned anvil and piston percussion, glossy festival production`
- free: `2010 electro swing house, 129 BPM, four on the floor kick, swung shuffle hats, sidechained Rhodes and clavinet ninths, bouncing plucked bass, live alto saxophone melody with brass section answers, filter sweeps, tuned steam valve and ratchet percussion, bitcrushed chiptune arpeggio between phrases, glossy laptop production`

### B. The pirate years (sounds like 1996)

- roam: `1996 jazzy jungle, 172 BPM, chopped breakbeat with ghost snares, sampled upright bass and sub, dusty Rhodes loop, alto saxophone riff lifted from an old record and re-pitched, 12-bit sampler crunch, vinyl crackle, timestretch artefacts, tape stop turnarounds, pirate radio cassette sound, warm and gritty`
- fight: `1995 rave and Eurodance anthem, 129 BPM, pounding 909 kick, offbeat bass, bright house piano stabs, hoover synth stab, singable saw lead answered by a sampled alto saxophone hook, snare roll build, breakdown, big drop, sampler crunch, rave tape saturation`
- free: `1996 acid jazz and French filter house, 129 BPM, swung MPC drum machine groove, filtered disco loop, sampled Rhodes, sampled horn stabs, live alto saxophone melody over the top, chopped machine shop samples as percussion, vinyl crackle, 12-bit grit, pirate radio tape`

### C. The dance-band years (sounds like 1978)

- roam: `1978 fast jazz-funk fusion, 172 BPM, live drummer on ride cymbal and tight snare, slap electric bass, clavinet riff, Fender Rhodes ninth chords, real horn section stabs, alto saxophone lead in call and response, talkbox answers, one room live recording, analog tape warmth, no synths on the drums`
- fight: `1979 disco and hi-NRG anthem, 129 BPM, four on the floor live kick with open hi-hat, octave Moog bass line, string machine, big synth-brass lead melody answered by alto saxophone, timbale and anvil fills, hand claps, build to a bigger final chorus, live band on analog tape`
- free: `1978 disco funk dance band, 129 BPM, four on the floor kick, open hi-hat on the offbeat, clavinet and wah guitar, Fender Rhodes, real horn section, alto saxophone lead melody, slap bass, gospel organ swells, steam whistle and wrench percussion played live, warm analog tape, one room`

## What to send back

1. For each of the 24 renders: a 30 s MP3 (128 kbps stereo) cut from the strongest half, named `<candidate>-<cell>-s<seed>.mp3` (for example `a-roam-s6101.mp3`), loudness-matched to -16 LUFS so no candidate wins by being louder.
2. One table: file, tempo read, `measure_variants.py` chroma match against the parent and against a different-parent control (covers only), integrated LUFS before matching.
3. Which seed you would pick per cell and one line why (melody on top, clean seam, tempo on the grid).

## Tempo check before a take is returned

A cover can come back at a different tempo from the one asked: in the first batch (9 November) five of the six roam takes came back at 150 BPM, bar length 1.60 s, against the 172 asked, and a beat detector misread them as 180 and 187.5. Check every take by bar length instead. Find the strongest repeat of its onsets inside 0.25 to 2.2 s. The take passes when that repeat is one bar of the asked tempo, half a bar or a quarter of it (one beat), within 1%, and the bar itself scores at least 0.75 of the strongest repeat. One bar is 1.395 s at 172, 1.860 s at 129 and 1.714 s at 140. A four-on-the-floor take repeats most strongly at the beat or the half bar, which is why the bar alone is too strict. A take that fails is rendered again (check the tempo field of the job first, then try seeds 6103 and 6104); it is not returned as an audition, because the roaming tempo is a ruling and the three years must be compared at the same tempo.

Route the MP3s per current PC-to-Mac asset handoff (originally staged to retired external bucket `/mnt/project-files/music/persona/auditions/`). Run on the 3060 if the 4080 is timing frames or Andrew is using it.

## Not in this job

No stems, no loops, no packaging, no game files. Nothing replaces a standing pick; these are auditions (ruling: a new take replaces one only if Andrew picks it by ear).

## Roaming after the pick

Every roam cover asked for at 172 landed on a 150 BPM grid except one (2010, seed 6101), with or without the drums in the parent. So 2010 roaming takes are rendered at 174, the tempo the style is usually tagged with, and fitted:

1. Fit the parent to 174 first, so the source and the ask agree: `ffmpeg -af rubberband=tempo=1.011628:pitchq=quality`.
2. Render with the 2010 roam caption, "174 BPM" in place of "172 BPM", tempo field 174, cover strength 0.55, batch 1.
3. Check by bar length at 174 (beat 0.3448 s, half bar 0.6897 s, bar 1.3793 s), by the rule above. A take on the 150 grid fails and is not fitted.
4. Fit a passing take to 172: `ffmpeg -af rubberband=tempo=0.988372:pitchq=quality`, then check again at 172.
5. Label it "rendered at 174, fitted to 172" wherever it is shown.

This is the one allowed stretch: 1.16 percent, pitch kept. Fitting a 150 take to 172 (15 percent) is still out. A fitted take is an audition like any other: the current Spillway roaming tune stays until Andrew picks one by ear.
