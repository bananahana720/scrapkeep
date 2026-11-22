# Scrapkeep sound bible

One page for how Scrapkeep sounds, written 2026-10-16 from Andrew's direction: **gritty steampunk and cyberpunk crossed with house, with jazz built into how the songs and notes are written.** It sits on top of [AUDIO-V3.md](AUDIO-V3.md) (the engine grammar), [SOUND-STORY.md](../SOUND-STORY.md) (registers and motifs) and the 2026-10-11 listening packet in `~/Music/Scrapkeep-sound-direction/`, whose mechanical swing track is the one Andrew approved ("huge 180"). Nothing here changes the game. The wiring notes at the end are for the wave coordinator.

## The one sentence

A house pulse you can't sit still to, played by a rusty machine band whose lead line phrases like a sax player: the kick and bass are the engine, the chords are jazz, the melody talks back.

## The band: Local 172, recorded in 2010

Ruled by Andrew on 10 November 2026, on one card for sight and sound together: the game looks and sounds as if it was made in **2010, the festival years**. He picked it by ear from Brindle's fight theme and anthem played three ways. The band's page, with the clips and the three generations in full, is https://claude.ai/artifact/4vBSSMqa4L23bGCrnYSzom; the render brief is [PERSONA-AUDITIONS.md](sound/PERSONA-AUDITIONS.md). The matching sight artist is Dot Marrow, on the same year.

The score is played by the crews' own house band, working name Local 172, from Flagstaff: three generations of one family (working name Castellan, "keeper of a keep") playing one book of tunes, each with the gear of its day. The tunes stay; the year changes how they are recorded. The names are working names until Andrew has seen them; nothing ships carrying one.

| Year | Who | How it is made | Where it is heard |
| --- | --- | --- | --- |
| **2010, the festival years (the live score)** | June on alto, who writes the tunes, and Arlo on laptop, who samples the garage's pistons and valves | A sax on top of a machine: chords pump against the kick, jazz voicings are chopped into off-beat stabs, the filter opens into every drop, a chip arpeggio flicks between phrases. Fight music is big-room anthems with a singable lead, a build, a drop and a bigger drop; the sax hook is doubled by a synth | Everything that follows the player's speed and combo, and the stations Furnace FM and Updraft 107 |
| 1996, the pirate years | Mags and her station KEEP: one sampler and a crate of her father's tapes | Everything is a chop: breakbeats, sampled upright bass, twelve-bit crunch, rave piano, tape stops | Radio only: the Chop Shop and Low Shaft Radio |
| 1978, the dance-band years | Hollis and the Night Shift, nine players in the works canteen | One room, straight to tape: horns, clavinet, Rhodes, slap bass, a talkbox for the answers | Radio only: Moss's Back Room |

What the pick settles:

- **Nothing Andrew has picked is replaced.** 2010 is the sound of nearly every standing pick. The work is making each piece obey the band's rule, not re-recording for its own sake, and a new take still replaces a standing pick only when he picks it by ear.
- **New music is made in the 2010 sound.** A render caption names the year and its production (the 2010 captions in the audition brief are the pattern); the other two years are for radio records only.
- **Roaming** was not part of the pick, because the renderer pulled the roaming covers to 150 BPM. New roaming takes are rendered at 174 and fitted to 172 (a pitch-keeping 1.16 percent stretch, labelled as such), checked by bar length before and after, and offered beside the current Spillway roaming tune. Andrew picked take 6107 (10 November 2026: "Love the sound pick of 6107, very well tuned to my liking"); it is the roaming tune of the Spillway's two stages.
- **The band's rule** is the game's one line in sound (ruling cj): the grid is the machine's, the bend is ours. The keepers are a band that listens: a call gets an answer, the solo is handed round, a wrong note is kept and answered. The Foreman is one perfect tone that needs nobody, beautiful and never sinister. [SOUND-STORY.md](../SOUND-STORY.md) section 8 applies it to who talks.

## The set: the score is played like a DJ plays a room

Andrew, 10 November 2026: "ensure ther musical layers are orchestrated well, and I love how jazzy DJ-ing and house music in a club setting is so infection! how sounds, drops, melody progressions and coupling, makes music in a game hitting on all cylinders. make the sound design system something that can be ironed out in this world 1 sprint and sustainable into worlds 2 3 and beyond!" And the same night: align it with the level conductor, so that game events, states, the pilot and the build feed the music and the music feeds them back.

So the score is one set, and the player is the room the DJ is reading. Every move a DJ makes has one cause in the game, and nothing in the music changes without one. The contract with the level conductor (what each side publishes, the six fight words, the lead times) is [sound/INTEGRATION.md](sound/INTEGRATION.md) section 7.

### The moves

| The DJ's move | Its cause in the game | State |
| --- | --- | --- |
| Pick the record's energy | How hard the stage presses (`pressure_changed`): calm or travel on the shelf | Plays today |
| Bring layers in and out | Rolling speed brings the drums; threat, the approach and the chain lift the lead from its floor | Plays today |
| Build | The Warden's guard near breaking (three quarters gone) plays the tight build | The recorded band, with the Warden form |
| Hold the breath: pull the drums and bass, close the filter | A stagger; the Warden's break | The recorded band, with the Warden form |
| Drop | The pilot's hit that shatters a chunk, on the next beat | The recorded band, with the Warden form |
| Pull the room down for a held moment | The world slows for a close-up (Brindle's entrance): a falling sweep in, the music and the ambience held under it, a rising sweep out | Plays today, for a hand on the controls |
| Mix the next record in on the bar | Zone, fight and moment changes enter on a bar or a beat | Plays today |
| Mix in key | Each world has one key (D, E, G) and each pack declares it | Declared; not checked when a pack is swapped |
| Answer the phrase: the lead steps back and June plays a bar | The room's mood and colour, on each phrase's last bar | The set director, behind `--set-director=on` |
| Swap the bass out the bar before a peak | The room rising toward the peak; a set piece announced to land next bar | The set director, behind `--set-director=on` |
| Pump the chords against the kick | The Warden fight's build, tight build and drop | Behind `--deck=festival` |
| Ride a build into the drop | The Warden's guard tightening toward breaking, the held breath on a stagger, and the chunk-shattering hit | Behind `--deck=festival` |
| Tape stop, switch-hit | A kill chain, the last phase | After the world 1 sitting |
| Cue the next record before the room needs it | The conductor's warning of what is coming | After the world 1 sitting |

### The DJ at the decks: the set director

Andrew, 12 November 2026: "I want it to feel like there is a backend dj that mixes things and orchestrated things perfectly with the players experience", and "I want a dj club vibe. I love house and a jazz-house crossover dj persona" (ruling di). So the 2010 band plays as a club set: **Arlo is the DJ behind the decks, playing a jazz-house crossover set, and June sits in on alto.** The tunes, the year, the keys and the grid are unchanged.

`src/presentation/set_director.gd` is Arlo. Half a bar before each bar line of the recorded band, `audio.gd` hands it one read of the room and books the plan it returns on that bar. The director never moves game time, never touches the synth band and never decides a fight section: the Warden form keeps those. It is behind the launch switch `--set-director=on`, off by default until Andrew has heard it on and off (ruling cq).

| It reads | Into |
| --- | --- |
| Pressure, threat, the chain, the approach, rolling speed, Heat's band, Overtime, the fight word | One energy, 0 to 1, and a mood: lull, build, peak, release. A mood climbs on the next bar; it falls only after two bars low, and a peak falls through two bars of release |
| Low armour, Overtime, Heat at hot or redline | The colour June answers in, in that order |
| A warning sounding, another melodic cue in the last two bars, a fight section that owns the lead | No answer this phrase |
| A set piece announced to land within the next bar; the room rising toward the peak line | The bass swap, or a filter roll inside a fight |
| The fight word: the guard holding or cracking; a boss or set-piece song (an anthem) | June out of an anthem and out of any bar under a warning; an anthem plays as written |

| Move | When | What you hear |
| --- | --- | --- |
| Answer | The last bar of an 8-bar phrase, counted from when the band starts, when nothing else owns the melody and the last move was at least 16 bars ago; taken back if a fight section, warning, caller or quote arrives after it is booked | The recorded lead steps back to about a third, and June plays one bar from her phrase book in the room's colour or mood: lazy and low in a lull, climbing in a build, the hook an octave up at the peak, a run up the ladder when hot, a brass call on Overtime, a fall that winks (a bell after it) when hanging on |
| Home | The first bar of a release | A cadence home to D |
| Bass swap | The bar before a peak or an announced set piece, outside a fight; once per climb and once per announcement | The bass steps out for one bar and slams back on the downbeat |
| Filter roll | The same, inside a fight | The band rolls under a low-pass across the bar and opens on the downbeat |
| Breakdown | A phrase end June does not take, when the last move was at least 16 bars ago | The drums step out for the bar; the melody carries on |
| Hold | Anything else, and always inside the band's own directed sections (a pivot, the Warden's breath, drop, break, return and home, a directed piece) and a boss or set-piece song | Nothing changes |

The move rate (Andrew, 13 November 2026, on the whole-stretch page: "it sounds really chaotic and I can't really follow the song"): melody first. At least 16 bars pass between any two moves, across records, so the song carries and each move is an event: about two a minute at most, fights included. Boss and set-piece songs play as written. The moves that remain only take sound away, and the lead never drops out. This replaces the 12 November target of a move every phrase, which gave the Brindle fight 15 moves in 90 seconds. `tests/set_director_test.gd` holds the gap on a scripted stretch of play, and the bounce receipt's `set_plans` rows carry the time, the fight word and why a phrase end held (`gap` among them), so the PC can measure it on real runs.

How her melody progresses: each book (lull, build, peak, release, hot, overtime, hanging) is four or two one-bar phrases written as statement, variation, development and home, and each is walked in order, so successive answers tell a short story and land where they began. An answer never repeats the one before it. Every note is in D Dorian or a C# leading home, never on Eb, Ab or Bb, the threat notes, so an answer is never heard as a warning (the test checks every phrase). Trims and the low-pass only take sound away and are gone by the next bar; the directed sections and the Warden's breath and drop ignore them.

What it borrows, as principles only (research notes in [sound/DIRECTOR-RESEARCH.md](sound/DIRECTOR-RESEARCH.md)): Left 4 Dead's one intensity number with a held peak and a forced relax; Metal: Hellsinger's best layer saved as the reward; Elias's rule that the melody moves slower than the drums; Hades's thin-out after a fight; Celeste's silence before a confrontation (the bass swap); and Roboquest's drive and its boss music that shifts at a phase. Nothing is copied: no melody, stem or sample from any of them.

### Who has the melody

The rules of orchestration, each with what enforces it today.

1. **One melody at a time.** On the shelf the lead stem has it and never falls under half level. A stinger, a call-in voice or a reward phrase takes it by dipping the band for its length. Today the dip lowers every stem together and nothing stops two melodic cues from sounding at once; a dip of the lead alone and a one-at-a-time gate are after the sitting.
2. **The low end belongs to the kick and the bass.** A cue with weight under 100 Hz stays short. Under a danger cue the synth band dips its bass; the recorded band dips whole. Nothing yet measures a cue's low end against the band.
3. **Music on the grid, sound on the frame.** A musical answer starts on the next beat in the live key. A gameplay sound (a hit, a hurt, a warning) never waits for the beat.
4. **Registers say who is speaking.** Rewards and the pilot's own actions climb D Dorian. Threats sit on Eb, Ab and Bb, outside the scale on purpose, so a warning is heard as foreign. [SOUND-STORY.md](../SOUND-STORY.md) owns the registers.
5. **The band answers, it does not talk over.** A call gets an answer; the solo is handed round. The busier the cues, the thinner the band should play; nothing thins it today (after the sitting).
6. **Every fight ends on the drop** (the hype rule below).
7. **Combat feedback is percussion, not notes** (Andrew, 13 November 2026: the hit-scan sound and the other feedback sounded like jazz instruments and fought the melody). The facts a fight repeats many times a second (the shot, a hit, a crit, a kill and its chain, being hurt, a deflect, a weak point, the interface click, a hit on the beat) carry no pitch the band could clash with, and follow the conventions a shooter player already knows: the shot is a punch with a crack, the hit marker a high tick, the crit that tick with a metal ring, the kill a heavier break, the chain heavier with each link, damage a blow from below. Each lives in two lanes the melody leaves free: a short body from 120 to 300 Hz (above the kick, and still there on a laptop speaker) and a crack or inharmonic ring above 3 kHz; what crosses the melody's band is noise under 15 ms, heard as a click. A hit on the beat claps with the drums instead of playing a sax stab. Warnings stay tonal alarms on Eb, Ab and Bb, and pickups and rewards keep their pitched chimes, because those are the conventions there. [sound/feedback_set.py](sound/feedback_set.py) makes the sounds and lists each convention; the measure is the melody cover (how far the effects raise the melody's own loudest bands in a fight) and each cue's lead in its best third of an octave over the band.

8. **A skill cast on the beat is answered by the band** (Andrew, 13 November 2026, after rule 7: abilities may be musical where basic feedback is not, and timing a skill to the music should be a reward the player finds). The skill's own sound plays the moment it is cast, never moved to the grid, because the player's timing is the point and the cooldown already stops it repeating. A special, gauge release or line skill cast within 80 ms of a beat (the on-beat hit's window) adds the pilot's motif in its own voice on the next sixteenths, in the live key: its first two notes, and the whole motif with the last note doubled in the band voice in a live boss fight or when a line skill bites an elite pack's member, a miniboss or the Warden (a special or gauge release names no foe). A line skill is answered at its bite, not its press. Sound only, like the on-beat hit (Q10). Nothing on screen names it. `skill_answer` in `src/presentation/audio.gd`; `tests/skill_on_beat_test.gd`. The answer size (two notes) is a taste call Andrew can overturn.

### How it is checked

A rule that cannot be checked is a wish. Each bank sound is bounced and measured for the faults a level meter cannot see (a click, a cut-off tail, a flat top, silence before the sound, the strongest note against its register, near twins), and every flagged sound is read as a picture before it is called a fault. The tools and their first run are in the project files under `music/soundcheck/`. The faults that need no picture are a test in the game's own suite (`tests/sound_edges_test.gd`): no trimmed bank sound, event cue or talking voice (one line a caller) is silent, starts loud, jumps on its second sample or stops mid-wave, and every sound the game loops meets its own start (the grid notes, cause notes, pilot quotes and keyed variants are not read yet); the sounds let through are listed in the test with why, and a row that stops being needed fails it. With everything playing, a whole bot run is read two ways. `tools/ace_bounce.gd` records the run's Master bus with every cue's time, pitch and level; `tools/mix/mixcheck.py` reads the recording (clipping, cues that pile up on one frame, the level in each of the game's mix states); `tools/mix/bounce_ids.gd` and `tools/mix/mixsim.py` rebuild the effect layer from the cue log and list each sound that leads no third of an octave over everything else sounding with it. A recording alone cannot say which of forty sounds a second is heard; the rebuild can. For the ear, `tools/mix/cue_reel.py` cuts the same recording into short clips of each sound on its event, once at the start with the fewest other sounds starting beside it and once at the one with the most, each with its numbers; `--slow-at` on the recorder puts the slow-motion sound in a run, which no bot does on its own. `--only=music` or `--only=effects` records one side alone with the same bot and seed (by bus, so the band's stingers count as effects), to say which side sets the level at a moment, and the recorder lists where the music's ring ran dry (`music_skip_rows`), which is a gap in the music you can hear. A pick of taste that goes to Andrew follows ruling cq ([DECISIONS.md](../../../project-guide/handoff/DECISIONS.md)): for a cue, each candidate is a recording cut the same way, and the pass line is the rebuild's margin (over all its starts, the sound's median lead in its best third of an octave is at or above 0 dB). In the cloud the music ring underruns, so whole-mix levels and anything about the recorded band are read on the PC. The recorded packs are checked on the PC for loudness, peaks, start point, bar length and key, and are stored in 20 ms Ogg pages so that a section starting deep in a recording costs its frame no more than one starting at its head ([sound/RENDERS.md](sound/RENDERS.md), "Short pages").

### Adding a world

A new world adds rows and recordings, not code, when it supplies:

1. A key from the family (its offset from D) and the two tempos of the grid, 172 on the shelf and 129 in a fight.
2. A roaming pack (calm, travel, cadence) and a stage pack for each zone with the Warden's sections (pivot, build, telegraph, open, drop, cadence), cut to the manifest format with drums, bass and the lead as separate stems.
3. A boss pack, and the boss's anthem three ways, each phase 10 BPM faster than the last.
4. One row per zone in `MusicRows.ROWS`, and one row per crew member who talks in `SfxBank.CALLERS`.
5. Event sounds for its enemies in the threat register and for its rewards in the reward register.
6. A clean run of the checks above.

Today a fourth world's boss also needs an entry in tables that live in three code files (`MusicRows.THEME_COUNT`, the boss voices and sections in `music_engine.gd`, the phase tables in `phase_music.gd`), and the synth band has three themes. Folding those into the world's own rows is after the sitting.

### Calls made for Andrew, his to overturn

He gave the threads their own judgement on mechanics and tuning for this build-out (10 November 2026). Each call is one line here.

- The Warden's tight build follows the guard (in at three quarters broken, out under half), not the pulse it charges every six seconds, which would chop the track.
- The drop lands on the hit that shatters a chunk. The hit that breaks the Warden lands none: the break and the kill cadence answer it.
- On the dam every chunk breaks on the last ram, so the drop lands on each ram that takes a quarter of the bar instead: two or three drops a fight, by the size of the ball. The dam's sheet opening is not a held breath, because it opens every six seconds whether or not you ram.
- The Warden form is on by default; `--warden-form=loop` plays the fight as before.
- The drop should land at least 3 dB over the held breath with no ceiling hit; on the PC (10 November) it landed only 1.1 to 1.6 dB over, because the effects set a fight's level. Two candidates sit behind `--drop-room`, off by default: `duck` steps the effects back 5 dB for the drop's first two bars, `lift` raises the band 3 dB for them (both in `mix_rows.gd` DROP_ROOM). Each is bounced on the PC and judged on one page before either becomes the default.
- The ultimate's ready pulse is 4 dB louder for every pilot (-5 dB, Kest -4). It is the one buried cue that carries news: rivet_ready led its best third of an octave by a median -2.2 dB in a Warden fight on the PC; in a cloud rebuild of a skipper run (seed 1, 50 starts) it reads -2.0 at the old level, +1.0 at 3 dB up and +2.0 at 4 dB up, so 4 clears the pass line with room for the band, which the rebuild does not hear. The other pilots' pulses share its recipe and were raised with it, unmeasured.
- The held breath and the drop keep the lead even at low armour. Low armour's missing lead is a warning everywhere else; in the breath it would be silence.
- The Warden's fight takes the band from an event's tune that is still playing when it engages (the flood, a squall). Before, the event's tune played the whole fight and the Warden's music was never heard. An event that begins inside the fight does not start its tune.
- After an ultimate's drop the recorded band comes back (it used to stay off for the rest of the stage, leaving the stand-in band). In a Warden fight it comes back to the fight's build, not to where it left.
- Take 6107 keeps its softer top end (4.9 to 6.3 dB below the old roaming tune above 8 kHz at speed). The clip he picked from was softer the same way, so it is the sound he chose. If it reads muffled against the fight, a shelf on the roaming band is one line.
- Take 6107 keeps its drums 1 to 2 LU hotter than the old tune's. The game fades the drums in with speed, so they are loudest at full speed; the drive is the point of the 2010 pick.
- Slow motion is marked at both ends, quietly and above 200 Hz, and the music neither slows nor filters: it is held 3 dB under, as it is for a warning. A tape stop on the band itself waits for after the sitting.
- The Cannon keeps its bent chime and has no mouth: it is a machine on the crew's side.
- Moss sounds the same at his bench as on a call.
- The set director's numbers (12 November 2026): an 8-bar phrase, a mood held two bars before it falls, two bars of release, the lead at 0.35 under an answer, the filter roll at 0.85 wet of a 420 Hz low-pass, answers 2 dB under the pilot's quote. All are constants at the top of `set_director.gd`, and the low-pass's in `ace_sequencer.gd`.
- June answers in the room's colour before its mood: low armour first, then Overtime, then Heat at hot or redline. Low armour already strips the recorded lead, so her winking fall is the only melody there; it plays at the end of each phrase, not throughout.
- The director stays out of the fight's sections: it adds June's answer while the guard holds, never in the breath, the drop or the break, and never trims a directed section.
- The combat feedback sounds (rule 7) sit at about the loudness they had, the shot a little under (it plays ten times a second): trims weapon_zap -9, hit_thwack -1, crit_ping -5, kill_pop -5, kill_chain_tier 0, ui_tick -8, and the on-beat clap about at a ranged hit's level, 8 dB under where the sax stab sat. Over the recorded world 1 fight these cut the effects' cover of the melody from a median 6.8 dB to 2.0 dB, and every cue still leads its best third of an octave over the band; over Brindle's anthem the chain's ratchet sits 3 dB under its own kill, so it is heard as part of the kill. The PC take of a world 1 run (13 November, job P) found the hit buried under its own shot, so the shot's crack sits at 2.5 to 5 kHz and the hit's tick above 5 kHz, and the hit and the chain went up 2 and 5 dB; in a rebuild of that run the hit leads its best band by +2.1 dB and the shot by +1.8. A chain link that lands with a special's blast stays under it, as a tick under its own event's big sound.
- Kest's kick reads a tenth of a decibel over the peak line after its trim. It is left alone: the limiter holds it, and lowering it would change how loud it is.
- The festival deck moves sit behind `--deck=festival`, off by default until Andrew has heard them on and off, and run only on sectioned stage packs while the music arbiter allows the DJ.
- Pump depths by section (`deck_moves.gd` `PUMP`): 0.45 in the Warden build, 0.60 in the tight build, 0.55 in the drop, and 0 everywhere else; only the bass and chords pump, never the drums.
- Pump shape across each beat (`deck_moves.gd` `PUMP_SHAPE`): drops over the first 220 frames (5 ms) to avoid clicks, holds full depth to 0.07 of the beat, and recovers piecewise linearly through 0.20, 0.345 and 0.49 to full level by 0.62 of the beat; depth changes ramp over one beat.
- Warden tight-build roll tiers by posture (`deck_moves.gd` `BUILD_TIERS`): quarter notes from 75, eighth notes from 85, and sixteenths turning to thirty-seconds on the bar's last beat from 95, booked one bar at a time half a bar before each bar line.
- Festival deck one-shot levels and lengths (`deck_fx.gd`): snare roll at 0.28 and rising noise at 0.08 per build bar, one-bar falling breath noise at 0.02 on entering open, up-to-one-beat rising noise swell at 0.07 ending on the drop sample, and a drop impact combining a 0.34 s 125-to-40 Hz sub sweep at 0.26 with a 2.2 s crash at 0.13.
- Every festival deck one-shot is notched with a fourth-order bandstop from 1.8 to 4.4 kHz so the 2 to 4 kHz warning lane stays at least 12 dB under its own loudest band, and capped under 0.58 peak.

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

Short, a little whimsical and tied to their event, like a rice cooker's end-of-cycle tune. Every pitch is in D Dorian so events never clash with the band, and the combat feedback sounds carry no pitch at all (rule 7 under "Who has the melody"). Gameplay sound plays on the frame. Only the musical answer waits for the grid.

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

In the game so far (9 November 2026): the pilot quote answers a long kill chain, six kills inside the chain window. The chain lands on the bar line under its crash, and a beat later the band plays the pilot's motif on the synth sax in eighths, with the brass an octave under the last note and a kick with it (`audio._quote_pilot`, `SfxBank.pilot_quote_score`). It is made for the sounding band's step and key, and it plays at most once in eight bars so it stays a treat. Kest's and Tarn's motifs go up an octave so the sax can sing them. The crit and gauge-release triggers and the other three extras are not built yet.

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
