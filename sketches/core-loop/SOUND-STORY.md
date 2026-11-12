# Sound and story, core-loop v2

This is the audio identity and the narrative through-line for the v2 round (TRACKING EV-0588). The vision keeper owns it under `design-v2/PROTOCOL.md`. Writers read it once at the start of a task, beside `DESIGN-V2.md` (what the game does), `VISUAL-LANGUAGE.md` (how it looks), `src/presentation/MUSIC-GEMS.md` (what Andrew already loves) and `src/core/event_kinds.gd` (the one row per event). It applies BIBLE §8 and amends nothing in the Bible; the species, factions and collapse premise are DESIGN-V2 §10's sketch-only use of the Bible's candidates.

**One source, every layer.** A fact has one row in code and every layer reads it: shape, colour, motion, sound, wording, placement. Sound is one of those layers, never a separate opinion. Where this file names a note, an instrument or a word, it names what that row should carry, and the writer who owns the row puts it there.

| Fact | Source row | Sound reads from it |
| --- | --- | --- |
| A class's colour, shape and motif | the class row in `src/core/class_def.gd` (W3 adds `shape` and `motif`) | every ability cue, the ready pulse, the charge pips, the break-free burst |
| A motif's notes and rhythm | `src/presentation/harmony.gd`, one table keyed by motif id (W5) | the band's layers and every class or faction cue |
| An event's sound id and priority | `src/core/event_kinds.gd` | `audio.gd` plays the id at the priority's trim |
| A threat type's sound family | `src/combat/threat_grammar.gd` (W2) | every telegraph, whoever owns it |
| An enemy's faction and mechanic tag | the enemy row (W7) | the timbre of its telegraph and hold |

## 1. The through-line

An older telling. The current story facts are in [design-v3/STORY-MAP.md](design-v3/STORY-MAP.md) (9 Nov 2026); where the two differ, that page is the current one. Sections 2 to 8 here still own the sound grammar.

Humans built machines that could end them, and did. Animals inherited the quiet that followed, grew up among the buried hulls and learned to repair what they found, so a fox winches, a mole cuts and a bird lifts. Salvagers like Sable, Rivet and Kest repurpose the tech that ended us into rolling workshops that hum with the mint field that pulls scrap home. The Furnace Fleet digs up what should have stayed buried, because Admiral Brindle counts ancient housings as inventory, and inventory does not wake. It woke, and the collapse has a second act.

Every run tells a small piece of this without a cutscene, because stopping to read defeats the game (playtest entry 7). Three channels carry it:

| Channel | What it carries | Where the player meets it |
| --- | --- | --- |
| **Codex fragments** (world category, arc wave) | The causes of the collapse and the uplift, never resolved. Each fragment supports at least two readings. | Found in vaults and secrets, read from the Tab codex between fights, never on the HUD. |
| **Environmental storytelling** | Two material eras side by side: bolted steampunk repairs grown over seamless ancient casting. The dam-works tower cluster is both. A Fleet dig site is a hole with brass tags on what came out of it. | Seen at gameplay distance, in silhouette and material, from every layer of the gorge. |
| **Audio motifs** | Who is here and what they are. The three class motifs are yours. The Fleet is brass and anvil. The ancients are three timbres that share nothing with the living world. | Heard the moment a thing acts, in the live key, before its danger can land. |

The rule for lore is the rule for telegraphs: it is read on the move, and it never asks for a stop. A fragment is short enough to read in a codex glance. A ruin explains itself by what it is made of. A motif says who without a name on screen.

## 2. Leitmotifs

Everything is in D, the home the band never leaves (`harmony.gd` `HOME`), and every motif transposes with the live key, so after a Warden lift the motifs are in Eb like every keyed cue (`audio.gd` `KEYED_SOUNDS`). At 172 BPM a sixteenth is 87 ms, so a five-note motif in sixteenths is under half a second: short enough to be a cue and long enough to be a tune.

### The three classes

Each motif is the class's sound word from DESIGN-V2 §2 made into notes, and it moves the way the class moves. Sable rises and launches. Rivet hammers and never stops. Kest drops and lands. The fox goes up and the bird comes down, so the two are mirror shapes and can never be confused, and Rivet's is a rhythm before it is a tune.

| | Sable (mint, ring) | Rivet (copper, chevron) | Kest (amber, starburst) |
| --- | --- | --- | --- |
| Sound word | A rising arpeggio | Hi-hat rolls | Low thumps |
| Notes (D home) | D4 F4 A4 C5 E5 (62 65 69 72 76): the Dm9 stacked up to the ninth | A4 A4 A4 D5 (69 69 69 74): one note hammered, then up a fourth to home | D4 A3 F3 D3 (62 57 53 50): the D minor triad falling to the low root |
| Interval shape | Stacked thirds, always up, ending open on the ninth: it launches rather than resolves | Unison, unison, unison, perfect fourth: repetition is the rapid laser; the fourth is the sprint arriving | A fourth down, a third down, a third down: things dropped, each landing lower |
| Rhythm | Even sixteenths, one per note, like a winch reeling | A closed-hat roll in sixteenths under the hammered note; the fourth lands on a beat | Eighths, long and heavy, the last thump doubled: tick, tick, tick, boom |
| Instrument | Mallet and bell (the Spillway `keys` family), bright, with a short ring | Closed hat and clav stab, dry and clean, like the optical rail among the grime | Tuned floor tom and 808 sub, so the thumps are pitched and sit in key |
| Where it plays whole | Detonation gauge release (the ninth resolves onto a bright chord), the slingshot (run fast), the ready pulse (first note only) | Overdrive blast release (the roll accelerates into an open-hat crash), the ready pulse (one tick) | Detonation line release (one thump per charge caught, down the line), the ready pulse (first thump, soft) |
| Where a piece plays | The arc caster's single high note is the ninth. The vault kick is the octave leap D to D, because exit speed is incoming × 1.8 and an octave is × 2. Charge pips climb the arpeggio one note per pip. | Each laser bolt is one closed-hat tick. The sprint is the roll for its whole length. A crowd-control hit that fails is a cymbal choke. Charge pips add a hat each. | The sticky-charge throw is one soft thump, the blink is one muffled thump, the demo slam is the falling triad with three mini-thumps. Charge pips add a thump each. |

Every cue on the class row's abilities is built from the motif's own material, so a run's most frequent sounds are the class's tune broken into parts, and the full tune is the payoff on the class's biggest release. `VISUAL-LANGUAGE.md` §6 already assigns these instruments per ability; this section gives them the notes.

### The Fleet: industrial, brassy, requisition

Brindle's set already owns brass stabs, anvils, D minor and the Neapolitan Eb (G4, G6, `harmony.gd` `BRINDLE`). The Fleet motif is the smallest thing that can be that set: **an anvil stamp, then a brass semitone lean, D3 Eb3 D3 (50 51 50)**, two anvil hits on the beat and the brass on the offbeat. It is a stamp on a requisition tag: stamp, stamp, decree. The semitone is the same lean the existing enemy arrival already makes (the low E-F growl of DESIGN-NOTES item 6), so every Fleet unit is a small Brindle and Brindle is the Fleet grown to full size. Fleet units speak in the klaxon family: steam hiss, whistle, winch clank, ratchet. Their telegraphs are the W2 type sounds in that timbre.

### The three ancient families

The ancients share nothing with the living world. They are tonal where the Fleet is mechanical, seamless where the Fleet clanks, and each family has one harmony no other family uses. They are the only sounds in the game that sit still.

| Family (cause) | Motif | Harmony | Timbre | B grammar in miniature |
| --- | --- | --- | --- | --- |
| **Reactor relics** (nuclear) | No tune. A pedal on the tritone, Ab (44, 56), under whatever the band plays. | The tritone against home: the note that never resolves. It is the same Ab the Warden's sinister break already walks (`harmony.gd` `TRITONE`, `SINISTER`), so an ancient fight and the Warden's worst quarter are one family. | Sub sine with a crackling tick, a Geiger counter. | The tick rate follows the vent's real charge state and speeds up toward eruption; the eruption is the payoff on the beat. |
| **Swarm remnants** (drones) | One high pitch buzzed in unison, G5 (79). | When the formation locks, the unison becomes a quartal chord, D5 G5 C6 F6 (74 79 84 89): stacked fourths, many identical things in tune. Scattering breaks the chord back into single detuned notes. | High sawtooth buzz pulsed in sixteenths, thin, no low end. | The chord is the threat's state, read from the formation: locked is a chord, breaking is single notes, gone is silence. |
| **The Mind's hands** (superintelligence) | It has no motif of its own. It plays your class motif back, inverted (every interval flipped) with the last note a semitone flat. Sable's rising D F A C E comes back as a falling D B G E B. | Whatever key you are in, one note wrong. It is the only hostile sound built from a class row. | Pure sine chime with a long tail and a slow 3-cent bend. | The wrong quote is the telegraph. It plays once per adaptation, then the lens shows the trigger icon and the counter takes effect. It never enters the band. |

### Weaving into the adaptive music, under the warden spill B grammar

G11 is the standing rule: keep the loved core, escalate on real game-state thresholds, add layers and never swap them in, land the payoff on the gameplay moment. The motifs enter the band as layers under that rule, and nothing below touches a gem.

1. **The class motif is a layer, not a lead.** The band's `echo` and `counter` layers already re-voice every four bars (G10, `ROTATIONS`). One rotation may seed the counter-line from the class motif's head, refitted to the chord it lands on, the way the choir already answers the lead's call from two bars back. The lead, the progression and the bass figures stay exactly as they are. The class motif never replaces the lead.
2. **The Fleet grows with the clock.** The Risk of Rain difficulty ticks past the Warden break add reinforcement weight (DESIGN-V2 §10.5). Each tick adds, never swaps: the first tick adds the anvil on beats 2 and 4 under the kick, the second adds the brass semitone lean answering the lead in the second half of the bar, the third adds the anvil to every beat. `threat_rose` is the threshold; the music reads the same tick the HUD's difficulty bar reads.
3. **An ancient colours the band without stopping it.** While a reactor relic is the fight's centre, the sub takes the Ab pedal under the existing bass figure for the bars its vent is charging, which is the sinister break's colour arriving early and leaving when the vent blows. A swarm adds nothing to the band: its chord is its own sound. The Mind never touches the band.
4. **The B arc stays the one arc.** `escalate()` is the only escalation. Ancient Wardens use it unchanged. A miniboss, an event and Brindle keep their existing arcs (items 65 to 69).
5. **Every new pitched cue joins `KEYED_SOUNDS`.** A motif cue, a hold loop or a faction stinger that is not in the live key after a lift is a bug.
6. **Danger never waits for a beat.** A motif that is a telegraph plays on the game frame. A motif that is an announcement lands on the beat. The class motif on release is the player's own action and plays now.

Andrew ruled on all three of these on 2026-09-27 (DESIGN-V2 §11): only the reactor colours the band, the Fleet borrows Brindle's anvil and brass one layer per difficulty tick, and the Mind's inverted quote is the one sanctioned hostile use of a class motif and doubles as its telegraph. The rules above are settled, not defaults.

Gem by gem: G1 (the band), G2 (the rice cooker), G3 and G4 (the Warden pivot and club), G5 (level palettes), G6 (Brindle's reverse quotes and the victory), G7 (phase shifts), G8 (the bass lines), G9 (the drops), G10 (Pyramids layering) and G11 (the B grammar) are untouched by any rule here. R1 (talking growls) and R2 (wobble) stay out: the Fleet motif is brass and anvil, the reactor drone is a clean sub, and no motif uses a formant or an LFO.

## 3. Sound grammar

Threats come first in the mix (BIBLE line 795). Every row names the register, the envelope, the length, whether it sits in the live key, the `event_kinds` priority and the test that matters: what Andrew knows happened without looking.

**Registers.** Threat cues live low and on the tense degrees: the flat second (Eb), the tritone (Ab) and the flat sixth (Bb), which are the notes of the sinister set and never the reward ladder. Player cues take the class instrument in the class motif's material. Reward cues climb the D minor pentatonic (D F G A C), as they already do. World announcements are stingers on the beat. UI is dry, high and quiet.

### Player abilities

| Event | Register and material | Envelope | Length | Live key | Priority | Without looking |
| --- | --- | --- | --- | --- | --- | --- |
| Ability ready | The motif's first note on the class instrument, with the ready pulse | Instant attack, short ring | 120 ms | yes | 1 | "F is back", and which class I am |
| Cooldown running | Silent. The petrol wedge is the information. | | | | 0 | Nothing; a sweep that ticked would nag |
| Gauge charging | The motif accumulates as the gauge fills: Sable adds a note per ring, Rivet's roll accelerates, Kest's sub swells | Linear with `charge_max` | 0.6 to 1.4 s | yes | 1 | How far the gauge is, from how much of the tune I have heard |
| Gauge full, grace | The last note held with a slow class-colour breathe | Sustain, 0.5 s period | up to 0.5 s | yes | 1 | It will fire itself if I wait |
| Gauge release | The full motif resolved: Sable's ninth onto a bright chord, Rivet's open-hat crash, Kest's thumps down the line | Sharp, then a short tail | 0.4 to 0.7 s | yes | 2 | The special fired and roughly how big it was (release scales the tail) |
| Gauge cancel or knock | A dry click, indicator collapses in 120 ms, no release note, no cooldown sweep | Click | 40 ms | no | 1 | Nothing fired and nothing was spent |
| Rebound | Compression then a spring snap, pitched by the enemy's weight over heft | Squash, snap | 180 ms | yes | 1 | I bounced, and off something heavy or light |
| Smash-through (crush) | The existing thwack ladder | Thwack | 120 ms | yes | 1 | I went through it |
| Pin | Two thwacks, the second a fourth up, 50 ms hit-stop | Double hit | 200 ms | yes | 1 | One enemy hit another |
| Vault kick (Sable) | The octave leap, top note pitched by exit speed toward the 45 m/s cap | Attack on the face contact | 200 ms | yes | 1 | I vaulted, and how hard |
| Cloak on (Kest) | A muffled thump; every Kest cue 6 dB quieter while cloaked | Soft | 150 ms | yes | 1 | I am hidden; the world sounds farther away |
| Cloak crit | A bright starburst and a snare crack | Crack | 120 ms | no | 1 | The cloak broke and it paid |
| Sprint (Rivet) | The closed-hat roll for the sprint's whole length | Sustain | 2 s per charge | rhythm only | 1 | I am unstoppable right now |
| CC ignored (Rivet) | A cymbal choke on top of the roll | Choke | 80 ms | no | 1 | Something tried to hold me and failed |
| Smash, shared air slam | The existing sub womp on the slam's frame, scaled by strength and flatness | Sine 86 to 34 Hz | 300 ms | no (sub) | 1 | I slammed, and how flat |
| Smash flavour, Sable arc slam | The womp plus a low root and fifth on mallet; steep faces glow mint | Womp, then ring | 400 ms | yes | 1 | Faces near me are vault invitations for 2 s |
| Smash flavour, Rivet skid | The womp plus a snare flam, then a tick per 0.5 s refunded | Flam, ticks | 300 ms plus ticks | no | 1 | I skidded, and each tick is sprint coming back |
| Smash flavour, Kest demo slam | The womp plus the falling triad on tom, three mini-thumps after the 0.3 s arm | Thumps | 500 ms | yes | 1 | Three charges are down and about to arm |
| Boost (Shift) | The existing whoosh | Whoosh | 250 ms | no | 1 | |
| Grapple fire, release, winch | Clink, release, reel ticks up the scale (existing, keyed) | | | yes | 1 | The rope is on, off, or reeling |
| Mount, slingshot | Clack on plant; the arpeggio run fast on release, pitched by throw speed | | | yes | 1 | Planted; launched, and how fast |

### Threats, by type (W2's grammar), in the owner's timbre

The type says what kind of danger. The owner says who: Fleet is steam, clank, ratchet and whistle; an ancient is hum, sub and sine. A unit's mechanic tag is a short identifier inside that. No unit invents a fifth type sound.

| Type | Register and material | Envelope | Length | Live key | Priority | Without looking |
| --- | --- | --- | --- | --- | --- | --- |
| Instant AOE | Rising ratchet clicks, one per 0.1 s, then a sharp clang at impact | Accelerating clicks, clang | the wind-up | clicks no, clang on Eb | 2 | Something is about to land where it is drawn; the click rate is the clock |
| Travelling wave | A whoosh whose pitch rises as the edge nears the player | Rising sweep | the travel | rises through the sinister set | 2 | It is coming at me and I can hear how close |
| Projectile | A launch thunk, a falling whistle, a landing crump | Thunk, fall, crump | the flight | the whistle falls Bb to Eb | 2 | Something was thrown; the fall tells me when |
| Lane or beam | A charge hum that holds, then a tearing buzz | Hum, tear | the fill | hum on Ab | 2 | A line is charging from a source; the tear is fire time |
| Boss telegraph | The same four, HAZARD fill, a brass tick on the rim and in the sound | | | | 2 | It is Brindle's |

### Enemy counters (Fleet reinforcements): the hold and the break

A hold is a loop in the threat register that lasts as long as the hold. Breaking it is a class-colour burst, the boost refund whoosh and the bass coming back. §4 says how holds stack.

| Counter | Telegraph type | Hold loop | Break-free | Without looking |
| --- | --- | --- | --- | --- |
| Mag pit (trapper) | Instant AOE, Fleet ratchet | Filings rattle plus a D pedal, the slow grind of a wheel in sand | The disc shatters outward: a ring burst and the class first note | I am in a pit; I am out |
| Tether (hooker) | Lane, Fleet winch hum | A taut cable tone on Eb that rises in pitch as my speed strains it | The snap whips, and the sling forward is the class first interval | I am tied; I snapped it and got slung |
| Air net (netcaster) | Instant AOE, Fleet crackle | The existing 60 Hz `zap_hum` on the tritone | The net tears: a noise rip and the class first note | I am caught in the air; I tore through |
| Bola (thrower) | Projectile, Fleet whistle | Whipping cords, a rattle on Bb | The cords burst outward | I am wrapped; I am free |
| Plated brute | Instant AOE when it strikes | none | Each plate pops with the existing clank ladder, rising as the punch nears its plating | One more plate to go, and how close I am |
| Deflector | Lane (the shield's face) | none | The rebound spring snap plus a vault chevron and the octave leap | I bounced off a shield and got a free vault |
| Winch drone | Lane, rotor thrum and winch clank | A pull tone on Ab with the rotor above it | The cable snaps | I am being dragged; the cable broke |

### Ancients

| Unit | Telegraph | Hold or state | Without looking |
| --- | --- | --- | --- |
| Reactor relic vent | Instant or wave, in the Geiger crackle; tick rate follows charge | The Ab pedal while charging | A vent is charging and how close it is |
| Swarm formation | The unison buzz snapping into the quartal chord | The chord holds while the formation holds | They locked; I scattered them when the chord breaks |
| The Mind's hand | The inverted, wrong class motif on sine, once per adaptation | The lens shows the countered trigger icon | It has read my last habit and is about to counter it |
| Warden (an ancient) | The existing Warden cues, in its family's timbre | The B arc | Unchanged |

### Terrain events and contraptions (W6)

| Event | Announcement | Telegraph | Payoff | Without looking |
| --- | --- | --- | --- | --- |
| Cave-in | `event_announced` klaxon on the beat, "Cave-in" | Instant fill over the 3 s crumble: rocks grind, dust hiss from the roof edge, ratchet clicks | Rockfall boom on the collider swap; a new-route chime (found_chime) if a route opened | A roof is coming down over there in 3 s |
| Impact | Klaxon on the beat, "Impact" | Projectile: a far thunk, a long falling whistle, brackets closing | A crater crump with a sub boom; a rail-ride whoosh if I ride the new bowl | Something big is landing at the brackets |
| Structural collapse | Klaxon on the beat, "Collapse" | Lane striped along the fall: girders groan, rivets ping in a row | The shear: a tearing metal fall and a settling ring | A piece of tower is shearing along that line |
| Steam lift | none | The bone gauge needle: a pressure hiss that rises through the cycle | A chuff and the platform's clank at the fire moment | The lift fires soon; it fired |
| Steam launcher | none | A **rising** steam whistle through the cycle (breathy, noise-based) | A bang and the rail whoosh on launch | The launcher is about to throw me |
| Pressure valve | none | A visible crack, a squeal under pressure | The smash womp, then a long hiss as the route opens | I opened a route |

The launcher's whistle rises and is steam; the projectile telegraph's whistle falls and is a pitched sine. Rising and breathy means a ride, falling and pure means incoming.

### Pickups, gates and growth (W4)

| Event | Register and material | Live key | Priority | Without looking |
| --- | --- | --- | --- | --- |
| Scrap pickup | The pentatonic ladder tick, climbing in a combo (existing) | yes | 1 | Scrap, and how fast I am taking it |
| Part pickup, by rarity | Common one note on the ladder, uncommon two, rare three, rare_plus the level motif head plus the two "done" beeps | yes | 2 | Which rarity, from how many notes |
| Synergy-completing pickup pulse | The existing `synergy_hit` light chime on top | yes | 1 | That one finishes a synergy |
| Gates open | The existing gates stinger, plus one note per rarity present, high to low | yes | 3 | Gates ahead and the best rarity among them |
| Gate roll-through | `gate_through`, keyed, on the move | yes | 3 | I took it |
| Heft class up, down | The existing A-D-A climb and its fall | yes | 3, 2 | Bigger; smaller |
| Codex fragment found | A three-note phrase from the level motif head on mallet, at half speed, 6 dB under the found chime, on the beat | yes | 2 | Something old to read later |
| Synergy discovered | The existing bebop fanfare | yes | 3 | |

### UI

| Event | Register and material | Priority | Without looking |
| --- | --- | --- | --- |
| Menu move, select | Short switch clicks and latch tones, dry, on the UI bus | 0 | Focus moved; a choice latched |
| Refusal | One dry interruption, never a damage alarm | 1 | No, and not a threat |
| Class select | The chosen class's motif whole, once | 2 | Who I am about to be |
| Codex open | A page-turn tick; the category's colour, no note | 0 | |
| Difficulty tick | The existing `threat_up` on the beat | 2 | The clock ticked and reinforcements grew |

## 4. Mix and priority

**Order.** Imminent threats and damage taken, then the player's meaningful action, then build reactions and rewards, then background and UI. This is the Bible's order and the existing priority trims (`PRIORITY_DB` -6, -3, 0, 0) already lean that way; a threat cue at priority 2 sits at 0 dB while a pickup at priority 1 sits at -3 dB and further trimmed per cue.

**Ducking.** Priority 2 and 3 cues duck the band (item 17). Danger cues duck the bass bus to 30% and it returns over a beat (item 47). Add one rule: a hold loop keeps the bass ducked for as long as the hold lasts, and a second simultaneous hold ducks it to 15%. The bass coming back is the sound of freedom, and it comes back on the frame you break free, because that is your action, not the world's.

**Voices.** Polyphony is 32 (`audio.gd` `POLYPHONY`). Budget it: 8 reserved for threats and holds (never stolen), 12 for the player's own cues, 8 for rewards and the world, 4 for UI. A reward or world cue that would exceed its budget steals the oldest of its own kind. A player cue steals the oldest player cue. Nothing steals a threat. Per-cue voice limits and minimum gaps stay as they are and extend to every new cue: a hold loop is one voice per hold, a formation chord is one voice, a Geiger tick is one voice per vent.

**Loudness and state (8 Nov 2026, Andrew: "way too loud").** Every mix number lives in `src/presentation/mix_rows.gd`. Target about -20 LUFS integrated over a world 1 run with true peak at or under -1 dBTP (master compressor, then a hard ceiling at -1.5 dB). Each game state (menu, camp, roam, combat, shop, miniboss, boss phases 1 to 3, run over) is a snapshot of bus offsets that glides down fast and up slow; roaming sits the music back so a fight reads louder by contrast. A priority 2+ or danger cue pulls the music and the Ambient bus (the parks' life) down for a moment (`FOCUS` in `mix_rows.gd`; the band leads the effects in a fight since 12 Nov) and is never quieted by the crowd rule, which steps priority 0 and 1 cues down 3 dB per doubling of live effect voices above six. Measure with `tools/ace_bounce.gd` then `tools/mix_meter.py`.

**Tails.** Overlapping tails are capped: at most two ringing tails of the same family at once, and the third cuts the oldest. Threat tails are never cut.

**A CC chain, from danger to relief.** Rolling into a trapper and a bola thrower together should sound like this, and the sound is read from the same hold state the tenacity clock reads (DESIGN-V2 §10.3):

1. The two telegraphs play on their frames in the Fleet timbre: ratchet clicks for the pit, a thrown whistle for the bola. The bass ducks to 30%.
2. The pit takes hold: the filings rattle and the D pedal start. The bola wraps: the cords rattle on Bb joins. Two holds, so the bass ducks to 15%. The cluster is D and Bb, a flat sixth against home, and it grows with each hold added (Eb for a tether, Ab for a net): the sinister set assembling itself around you.
3. The accumulated hold nears 1.8 s: the cluster gains a slow riser, the one instrument in the game that means "this is about to be over".
4. Tenacity lands: the copper or class-colour shimmer is a cymbal choke (the same choke as Rivet's ignored hit, because both mean crowd control cannot hold you), then the class first interval bright, and the bass returns over one beat.
5. Breaking free by your own action instead: the hold loops cut on the frame, the class burst plays, the boost refund whooshes, and the bass returns on that frame. The relief is felt in the low end before it is heard anywhere else.

A bad combination of enemies is therefore legible by ear as a chord growing more wrong, and escape is the chord going away. The player never hears a hold they cannot see, because every hold is a striped HAZARD binding drawn first.

## 5. The words

**Tone.** Dry, workshop-humane, a little funny. The voice is a mechanic who has seen this before and will help you fix it, not a narrator. The existing rows set it: "Scrapped", "Scrap torn loose: chase it down", "{event} lost: it comes round again".

**HUD rules (W1).** The fight HUD holds 25 words (`VISUAL-LANGUAGE.md` §7). A toast is five words or fewer; an objective line is five; a prompt is three. Verbs first ("Break the Warden", "Charge the beacon"). Nouns are names, not titles ("Brindle", not "the Admiral"). No adjectives, no lore, no "optional". One exclamation mark exists in the game and it is "Launch!". Numbers are glyphs and gauges, never sentences. A word the player must read while rolling is a word too many; if a glyph can carry it, the glyph wins.

**Callouts.** A pack arrives as its faction and its tools: "Fleet: trapper, bola" (priority 3, three words). An ancient wakes as one line in the world's register: "Something old wakes". A hold says what has you and how out: "Tethered: speed snaps it", "Netted: jump or glide". Tenacity says "Can't be held" for its 2.5 s.

**Codex fragments.** Each is a found object with a source (a stencil, a log, a tag, a proverb), short enough to read in one glance, and each supports at least two causes. None resolves the collapse or the uplift. Ten samples for the world category:

1. Stencil on a cast vent, half buried: **VENT 4. DO NOT OPEN UNTIL CLEAR.** Scratched underneath in a newer hand: *clear of what.*
2. Maintenance log, water-stained: *Day 212. The Mind says the reactors are fine. The Mind said that about the drones.*
3. Fleet requisition tag, brass: *Item 3,118: one (1) ancient housing, humming. Do not list as scrap. Do not list at all.*
4. Chalk on a tower footing, in Enclave script: *Grandmother says the old ones made the sky hot. Grandfather says they made it think.*
5. Loop on a cracked drone lens, still lit: *FORMATION HOLD. AWAITING OPERATOR. AWAITING OPERATOR. AWAITING*
6. Roost proverb cut into a lift cradle: *Everything that flies was taught by something that fell.*
7. Cast plaque under a feed trough welded to it: **CARETAKER NODE 7. WE WILL KEEP THEM SAFE UNTIL YOU RETURN.**
8. Enclave winch tag, felt-lined: *If it's seamless, it isn't ours. Leave it buried. M.*
9. Fleet broadcast transcript: *The Admiral reminds all crews: the machines are inventory. Inventory does not wake.*
10. Scratched inside a reactor relic's cracked shell: *It was never one thing. The last shift.*

Fragment 2 names all three causes and settles none. Fragment 7 hints at uplift without saying by whom. Fragment 9 is the joke the run is about to disprove.

## 6. Coherence checks

The alignment pass answers each for any unit's vision delta. Every answer must be yes, except 11, which must be no.

1. Does every new player-facing fact read from one source row (palette, class row, motif table, event row, threat row, enemy row), with sound reading the same row as shape and colour?
2. If the cue is pitched, is it in the live key (added to `KEYED_SOUNDS`), on the reward ladder if it is good news and on the sinister degrees if it is a threat?
3. Does a threat sound on the game frame, before it can harm, never waiting for a beat, while its announcement stinger may land on the beat?
4. Is a hostile sound in a hostile timbre (Fleet steam, clank, ratchet, whistle, klaxon; ancient hum, sub, sine) and never a class instrument, with the Mind's quote as the one sanctioned exception?
5. Does the player's own action sound on its frame, in the class instrument, from the class motif's material?
6. Does a new music element enter as a layer on a real game-state threshold, leaving every G1 to G11 core playing and every R1 and R2 item out?
7. Can Andrew tell what happened with his eyes closed, as the row's "without looking" line states?
8. Does the cue's prominence (register, length, trim, ducking) match its `event_kinds` priority, with threats at the top of the mix?
9. Does a hold sound like rising danger and a break-free like relief, with the bass returning on the moment of freedom?
10. Is the wording inside the slot budget, verbs first, names not titles, and free of lore on the HUD?
11. Does any fragment, callout or name resolve the collapse's cause, the uplift or Brindle's ending? (Must be no.)
12. Does a new enemy's sound belong to it alone, so no two entries can be confused by ear, the way no two can be confused by silhouette?

## 7. Alignment notes on DESIGN-V2 sections 1 to 10

**must** breaks the vision or a one-source rule. **could** would sharpen it. Where the fix is a wording change in `DESIGN-V2.md`, the coordinator owns the edit.

### W1 UI

- **must.** The `event_kinds` objective strings are long sentences ("Break the Warden at the beacon ({distance} m). Punch {punch} / plating {plating}. {hint}"). Andrew's entry 7 verdict was "so many words", and `VISUAL-LANGUAGE.md` §7 budgets the objective line at five words with an icon. Rewrite every `objective` and `hud` row to the budget: the icon carries the noun, the gauge carries the number, the words carry the verb.
- **must.** The ready pulse's note, the charge pips' sounds and the cooldown wedge must read the class row's `motif` (§2 of this file), not a generic UI ping, so the HUD is the first place the class tune is heard.
- **could.** Charge pips stockpiling should climb the motif one note per pip, so a stockpiled special is audibly "loaded".
- **could.** DESIGN-V2 §10.3 says the tenacity shimmer is copper; `VISUAL-LANGUAGE.md` §11 makes it the class colour, and "class colour means yours" is the rule. Amend §10.3 to "the class colour (copper for Rivet)".

### W2 threat

- **must.** DESIGN-V2 §10.1 gives each counter "its own warn sound" and §4 of the visual language gives each threat type one sound. Both stand, layered: the type sound is the base, the owner's timbre (Fleet or ancient) is the voice, and the mechanic tag is a short identifier inside it. `threat_grammar.gd` rows carry the type sound and accept an owner timbre; an enemy row supplies the timbre and the tag. No unit adds a fifth type sound.
- **must.** The telegraph fill and its sound start on the game frame the threat is declared. Only the `event_announced` stinger waits for the beat. A 3 s crumble telegraph is 3 s from declaration, never 3 s from the next beat.
- **could.** Pitched telegraph elements (the wave's rising sweep, the projectile's falling whistle, the lane's hum) sit on the sinister degrees of the live key (Eb, Ab, Bb), so a threat is in key but never on the reward ladder.

### W3 characters

- **must.** DESIGN-V2 §2 says each class row carries colour, shape and sound; `class_def.gd` today carries `color` only. Add `shape` and `motif` (an id). The motif's notes and rhythm live in one table in `harmony.gd` keyed by that id (W5 owns the table, W3 owns the id). Every ability cue is built from that motif's material as §2 lays out.
- **must.** Two Sable discharges exist (the F gauge release, and the free discharge on planting a pylon). They must be distinguishable by ear: the gauge release is the whole arpeggio resolving onto a chord; the plant discharge is the existing plant clack plus the arpeggio's first three notes, short.
- **could.** The vault kick's octave leap should pitch its top note by exit speed toward the 45 m/s cap, so a capped vault hits the top of the ladder and a weak one falls short of the octave.
- **could.** Kest's thumps are pitched (tuned tom and sub) so they sit in key; state that in the class row's motif rather than leaving it to the synth.

### V1 look

- **must.** `VISUAL-LANGUAGE.md` §11 says the Mind's chime "plays the class motif back, slightly wrong". Define "wrong" once: inverted, last note a semitone flat, on sine (§2 of this file). W7 and W5 read that definition; neither invents its own.
- **could.** Sable's detonation gauge adds "one arpeggio note per ring". The motif has five notes; draw five rings from 12 to 30 m so the rings and the notes count the same.
- **could.** The focal landmark's Cherenkov-blue light (`#3d8bff`, DESIGN-V2 §11) could carry a sound: a sub pulse on bar 1 of each phrase, panned toward the tower and louder as you near it, so the landmark orients by ear from every layer. It is a background layer at priority 0 and never competes with a threat.

### W4 loot

- **could.** Part pickups count their rarity in notes (common one, uncommon two, rare three, rare_plus the level motif head plus the two "done" beeps), and the gates stinger adds one note per rarity present. A gate then reads by ear at the distance a topper reads by eye.
- **could.** The codex fragment found in a vault gets its own quiet cue (§3, pickups table) so a lore find never spends the synergy fanfare's sense of occasion, per BIBLE line 780.

### W5 audio

- **must.** DESIGN-V2 §8 replaces stage 2 with the vertical gorge. Stage 2's theme is Sluice (G5: the clavinet riff, brass stabs, the funk groove). The gorge keeps the Sluice palette as its core and adds layers by height: the undercroft adds the reese and sub forward, the shelf is the theme as it is, the sky layer adds the bell and arp shimmer. The layer you are on is the layer you hear. Nothing in G5 is swapped.
- **must.** Every new pitched cue (motif cues, hold loops, faction stingers, rarity notes, the fragment cue) is added to `KEYED_SOUNDS` and baked in the live key like the existing stingers.
- **must.** The class motif, the Fleet motif and the reactor pedal enter the band only as §2's layers on named thresholds; `escalate()` stays the one arc; the swarm and the Mind never enter the band.
- **could.** One motif table in `harmony.gd` keyed by id (`sable`, `rivet`, `kest`, `fleet`, `reactor`, `swarm`, `mind`), each row a note list, a rhythm and an instrument, so a class row's `motif` and an enemy row's family both resolve through the same lookup.

### W6 stage

- **must.** The steam launcher "whistles then bangs" and the projectile telegraph is "a falling whistle". Make the launcher's whistle rise and breathy (steam) and the projectile's fall and pure (sine). Rising means a ride, falling means incoming; a player who hears a whistle must never have to look to know which.
- **must.** Terrain events keep DESIGN-V2 §9's order (telegraph first, then the stinger on the beat) with the telegraph on the game frame, and the collider swap's sound plays on the swap, never before it.
- **could.** The five layer transitions each get a sound in the ride family: the grapple line's clink, a glide's wind, the skylight halfpipe's rail hum, the geyser's rising steam whistle and bang, a chute's rolling metal. None uses a class instrument, because a transition belongs to the world.

### W7 enemies

- **must.** Two factions, two timbre families, no crossover: Fleet is steam, clank, ratchet, whistle and the klaxon family; ancients are hum, sub drone and sine. Each roster entry's telegraph is a W2 type sound in its faction's timbre plus one mechanic tag no other entry uses (the tables in §3). Two entries that share a tag fail the no-reskins rule by ear the way two silhouettes fail it by eye.
- **must.** `enemy_spawned` plays `enemy_arrive` (the Fleet's semitone growl) for every kind. Ancients need their own arrival: a sine swell on the family's harmony. Carry the faction in the `kind` string or an enemy-row field so `audio.gd` can pick, and add the ancient arrival cue to `KEYED_SOUNDS`.
- **applied 2026-09-27.** A deflector rebound gives any class the ×1.8 vault (DESIGN-V2 §10.6 as amended); the sound is the rebound snap plus the octave leap, in the class instrument.
- **must.** The Mind's adaptation quotes the player once per adaptation and shows the trigger icon before the counter takes effect (DESIGN-V2 §10 says bounded and telegraphed). The quote is the telegraph; the counter never lands without it.
- **could.** The plated brute's plate pops reuse the existing clank ladder (DESIGN-NOTES item 22), so "how close I was to breaking through" survives on a new enemy without a new cue.

### Coordinator: DESIGN-V2 wording

- **applied 2026-09-27.** §10.3's tenacity shimmer is now the class colour, and §10.6's deflector rebound gives any class the ×1.8 vault. Both notes are closed.
- **could.** §2's Sound row could name the motif ids this file defines, so the class table and the motif table share a vocabulary from the first read.

### W4, W1, W6, W5: Moss's workshop (DESIGN-V2 §12)

- **must.** The 25-word fight budget does not apply inside the bay, but Moss's bubbles are 12 words at most and the shop UI is 5 words per line with icons first. Moss's lines come only from §8 of this file; a unit that needs a line it does not have asks the coordinator (PROTOCOL trigger 3) rather than writing one.
- **must.** The bay banks speed like the pylon mount and the pad slingshots it back, so entry and exit reuse the mount and slingshot cues (the plant clack and, on exit, the class motif run fast) rather than new sounds. Nothing in the bay sounds like a stop.
- **must.** The lounge is a layer mask over the stage theme in the live key (§8), never a new track, so no gem is lost in the bay.
- **could.** The shop bell is the rice cooker's two "done" beeps (callback C9 in `design-v2/STORY-THREADS.md`).

### Meeting of the minds, 2026-09-27: reconciled must-notes for Wave 3

The primer (`design-v2/board/PRIMER.md`) settled these across the four boards. Each is routed to its owner so the Wave 3 packets can quote it.

- **W1 UI (must).** `callout_chime` stays the four first-run teaching callouts' sound: two dry mallet pings, A5 then D6, 70 ms apart, priority 2, retiring with the callout. It is never a pack callout.
- **W7 enemies (must).** A pack arriving is a new event row `pack_arrived` (event group, HAZARD, the faction's `fac_` icon at the screen edge, priority 2): its sound is the faction motif head, the Fleet stamp for crews and a sine swell on the family's harmony for an ancient. This is also the ancient arrival cue. The plated "now" and "not yet" read as a class-colour rim with an open-crack glyph against closed plates, never a tint; the clank ladder stays the sound. Every Fleet crew figure is an animal. The Mind's quote is its telegraph and learns within a run only (default). C11's scattered drones follow the ball seamless, with one loose unison buzz panned to the ball for 2 s, then silence.
- **W6 stage with W5 (must).** The gorge's layers by height on the stage theme's core: undercroft adds reese and sub, the shelf is the theme, the sky adds bells and the arp. One ride-family sound per transition, never a class instrument. The landmark's sub pulse on bar 1 of each phrase, panned toward the tower, priority 0 (C18, now Wave 3). The launcher's whistle rises and is steam; the projectile's falls and is pure. `pressure_opened` is the valve's smash womp and long hiss; no `threat_up` in the bay.
- **W5 audio (must).** `mastery_earned` is the class motif whole on the beat, answered by its resolution an octave up and the rice cooker's two "done" beeps; a release stays on the frame with no answer. The relent's cue is Moss's sigh, a padlock clunk, then the hook's chain rising D to A on mallet; the shop bell means purchases only; the codex entry "Too heavy for you" takes the fragment cue. Break-free plays the current class row's first interval, never Sable's by default. The gauge-charge and charge-pip cues get built. Brindle's core does not colour his music; Pressure does not change the music.
- **V1 look, then V2 (must).** Add to VISUAL-LANGUAGE §5: a variant notch on `ab_` icons, class-shape milestone pips under `cls_` emblems, an unearned-variant silhouette in dull petrol at 40% value, Pressure's pre-filled `res_difficulty` notches, and a `pack_arrived` edge marker. Kest's satchels are horizontal amber bands. Ancient enamel is capped at dull petrol with charcoal-grooved blue seams. The title's beacon is dark on a fresh profile and lights after the first win.
- **V3 assets (must).** Shapes from the sheets, never their surface detail; no badger pilot; no human crew.
- **W3 characters (must, with progression).** The three pilot barks are the three special milestones' codex names (C15 to C17); completing the milestone is the discovery. Sidegrades wait for a dispatch table (Andrew's question 1).
- **Vision keeper with progression (done here).** One Moss memory table, §8 below, with the progression board's facts added; facts live in `profile.json`, lines here.

## 8. Moss

Moss keeps the workshop bay that opens off the launch after each Warden break (DESIGN-V2 §12). He is the Bible's proposed keeper who "remembers what each pilot neglects" (BIBLE.md:384); the sketch says "he" as DESIGN-V2 does, and his species stays open (`design-v2/STORY-THREADS.md` §7, question 1). He has no recorded voice. He has babble, a bench and a bell, and he is the only character in the game who talks to you.

The callback index DESIGN-V2 §13 asks this file to keep lives in `design-v2/STORY-THREADS.md` §5, one source for every callback and the mechanic it rides.

### The lounge arrangement

The bay drops the band to a sax-led lounge re-voicing of the current stage theme, in the live key. It is a layer mask over the loved core, never a new track, so every gem keeps playing.

- **Same grid, half the feel.** The tempo and the grid do not change, so the exit drops back on a beat with no pivot. The kick is off, the hats become a brushed ride at low level, and the drums play half time. The felt tempo halves; the clock does not.
- **The bass stays (G8).** The stage's own calm figure plays on the clean sub, as it does at pressure 0.
- **The keys thin.** The electric piano plays the stage's voicings on beats 1 and 3 only.
- **The sax leads (G1, G5).** The existing synth-sax `lead` voice plays the stage motif at half speed with a wider scoop and slower vibrato, and answers itself as it already does. Sluice's clav and Weir's organ stay in their own stage's lounge, quiet.
- **Pad on, everything busy off.** No arp, echo, counter or choir. The tone filter sits at its calm 2.8 kHz.
- **Pressure floor 0.15** inside the bay, so the difficulty clock's pause is audible as calm.
- **In and out.** The lounge enters on the bar after the bay banks the ball. The exit pad fires the existing launch build (`start_build`), so the landing is the full band's drop (G9), and the calm ends the way every calm in this game ends: on the beat, going faster.

### Babble synthesis

Moss's voice is synthesized babble, one letter at a time, in the live key, rising with exasperation. Since 10 November 2026 he says his letters through a small mouth an octave over his old pitch, at his bench as on a call-in: Andrew ruled mouths for everyone alive and the high mouth for Moss, and the bench following is the coordinator's reading of that, on the sitting watch list for his ear. His row in `CALLERS` (`sfx_bank.gd`) is the one switch; with no mouth on it each letter is the old blip, a square through a low-pass. It never uses a wobble (R2), and it is kept high so that it is never the low talking growl R1 rules out.

| Rule | Value |
| --- | --- |
| Blip | A square wave through a 1.2 kHz low-pass, 5 ms attack, short decay |
| Length | Consonant 40 ms, vowel 80 ms; a word's first letter is 3 dB louder and one scale step up |
| Punctuation | Comma 120 ms rest; full stop 250 ms; a question mark ends its word a fourth up |
| Pitch | Each blip is drawn from the beat root's Dorian triad (root, third, fifth), seeded by the line's hash, so a line always babbles the same way |
| Live key | Every root is transposed by the band's live key, like every keyed cue |
| Exasperation | Beat n's root climbs the scale (table below) and its blip lengths shorten by 8% per beat |
| Refusal grumble | A 200 ms dark-saw burst on the beat root under the first word of beats 2, 4 and 6 (W5's "grumble when he refuses") |
| Bubble | Appears with the first blip, sits away from the reticle, clears 1.2 s after the last blip |
| Bus and trim | SFX bus at -8 dB; the bay has no threats, so nothing ducks it |

| Beat | Root (D home) | Character |
| --- | --- | --- |
| 1 ask | D3 | level, unhurried |
| 2 refuse | E3 | a grumble under the first word |
| 3 insist | F3 | blips 8% shorter |
| 4 double down | G3 | grumble, shorter again |
| 5 plead | A3 | the peak: highest root, fastest blips |
| 6 send off | C3 | falls below where it started; grumble; a slow last word |
| Relent | D3, ending with a fall of a fifth | slower than beat 1, through a larger mouth and a little under his other lines (the old voice: a warmer filtered-triangle blip): a sigh |
| Shop barks | D3 | level |
| Remembers-you lines | D3, said as the relent is | slow and warm |

### Who talks on what

Working (W), 9 November 2026, from Andrew's ask that the people in the game call in on a card and talk in cute babble, one voice each. Moss's bench voice above is the same voice he calls in with. A call-in is one call, `audio.call_in(kind, speaker, text)`: a two-note chirp in the caller's instrument so the ear knows who it is before the eye finds the card, then the line, one letter at a time, in the live key. It returns how long the voice lasts so the card can hold for it, and `audio.call_end()` stops the caller when the card closes early (a fight goes live, the run ends). The line is made on a worker and sounds a third of a second later, the band dips under it by about what the lounge gives Moss at his bench, and one caller talks at a time.

The rule is the story map's: whose hands the caller is sets the instrument. A pilot talks in the notes of their own motif, on their own instrument, so their speech is their tune shuffled. Everyone on the crew's side bends into their notes and strays a little in time. The Foreman alone is on the grid: one pure note, every letter a thirty-second of the band's tempo, nothing bent and nothing left to chance, and it does not rise on a question. A line is laid out the same way every time it is said. The rows live in `sfx_bank.gd` (`CALLERS`).

Mouths (Andrew, 10 November 2026: "reach big"). Everyone alive says their letters through a small vowel mouth, the way Animal Crossing's villagers do; the Foreman has none. A mouth is a reed on the caller's note pushed through two resonances the letter sets: five vowel shapes, a hum for m and n, a half-shut shape for the other consonants, and a breath opening the hissed and stopped ones. Each caller's mouth has a size, and a smaller mouth rings higher, which is what keeps it a creature's voice and not a growl. The chirp stays on the caller's instrument, a little under the voice, so who is calling is still heard in their hands before their mouth. The pilots and the site crews are built this way. R1 was written against low voices with moving formants, and Moss and Brindle are the two low voices here, so theirs went to Andrew as a card: both get the high mouth (Andrew, 10 November 2026), Moss an octave above his bench pitch and Brindle at his brass's pitch. The sound page keeps each of them with no mouth, a low mouth and the high one. Moss's voice at his bench follows his row, so he has one voice everywhere. The Cannon is a machine on the crew's side and keeps its bent chime.

| Caller | Voice | Notes | How they talk |
| --- | --- | --- | --- |
| Moss | The bell on his counter twice, then a grown mouth | D3's Dorian triad, said an octave up | Level and unhurried, laid out as at his bench |
| Sable | Bell chirp (Sable's voice in the band; the motif's own mallet is the site crews'), then the smallest mouth | Own motif: the chirp an octave up, the words at the motif's own height | Quick, scooping up into each word: Sable launches |
| Rivet | Clavinet chirp, then a small mouth | Own motif: the chirp an octave up, the words at the motif's own height | Fast, with no gap between words: Rivet never stops |
| Kest | Tom chirp, then the largest pilot's mouth | Own motif, an octave up | Slow, falling away from each note, long rests after a sentence: Kest commits late |
| Tarn | Round bass chirp (Tarn's voice in the band), then a mouth | Own motif, an octave up | The slowest pilot and the softest voice, about 2 LU under the others by measure: gentle while the machine snarls |
| Tally | Electric piano chirp, then a small mouth | Own motif: the chirp an octave up, the words at the motif's own height | Every letter the same length, where the others stray: the honest ledger |
| The Cannon | Chime, no mouth | Own motif, an octave up | The Foreman's own clean tone, bent: the gun that chose a side |
| Pump crew, flume crew, signal crew | Mallet chirp, then two mouths | The triads on D, E and G | Two talkers trading words on one radio, the second a fourth lower and in before the first is done |
| Brindle | Brass chirp, then the largest mouth here | The Fleet motif: D and E flat | Slow and grand; every sentence ends held on the flat second, because he rounds up |
| The Foreman (the Mind) | A pure tone | One note, D; its chirp is a perfect fifth | On the grid, as above. The memo is read by a metronome. |

A caller id with no row gets Moss's voice and one warning.

### The conversation loop

The player presses the key glyph by Moss; each press plays one beat. The pilot's side is a nod and the class motif's first note, never words, so the 12-word budget is Moss's alone. After beat 6 the next press restarts at beat 1 with a new variation; a beat picks a variation the visit has not used, and the class-tagged lines are extra choices for that class. None of these lines is from the Potion Seller sketch. The structure is borrowed (ask, refuse, insist, double down, plead, send off); every word is Moss's.

**Beat 1, the ask (Moss sees you look at the hook)**

- The hook. Everyone looks at the hook. Shelf's the thing for sale.
- Eyes off the top shelf, salvager. Three fine parts, right there.
- That one? Not for you. Not for anyone your size.
- (Sable) Ears up already. No, fox. The hook stays hooked.

**Beat 2, refuse**

- No. It'd shear your axle the first bump you took.
- Too strong for a ball that light. Ask the dial.
- Bolt that on and I'm scraping you off the rapids.
- (Rivet) You'd measure it twice and still be too light.

**Beat 3, insist**

- Still no. The shelf has three answers. Pick one.
- Asking louder doesn't add weight. Scrap adds weight.
- I heard you the first time. I said it the first time.

**Beat 4, double down**

- Read the dial. One notch short. Come back heavier.
- That part needs a heft you haven't rolled up yet.
- Rules of the bench. Weight before wonders. Always were.

**Beat 5, plead**

- Don't give me the look. I like the look. Still no.
- Begging's free. The hook isn't. Roll some scrap in.
- You'd float away with it. Then who buys my parts?
- (Kest) Crest down, bird. Pleading doesn't count as lift.

**Beat 6, send off**

- Try the scrapper past the rapids. Sells lighter. Sells worse.
- There's a cart down the shelf road. Flimsy parts, no questions.
- Go bother the gates. They'll give you anything.

**Restart flavour** (the press after beat 6, before beat 1 replays): Again? Fine. From the top.

**The relent** (the ball reaches the heft class the hook needs; the loop ends here, the hook unlocks, and the codex gets "Too heavy for you"):

- Fine. You're heavy enough. Don't come back lighter.
- Alternate: Hook's yours. Took you long enough to get fat.
- Alternate: Alright, salvager. It'll hold now. Probably. Bolt it on.

### Shop barks

| Moment | Line |
| --- | --- |
| Buy | Bolted. Mind the weld, it's still warm. |
| Reroll | New shelf. Same shop. Don't get used to it. |
| Sell back | Half back. Lighter, but faster to the next part. |
| Charge upgrade | Second cell's in. Two shots, then wait like everyone. |
| Can't afford | Scrap first. I don't run tabs for rolling things. |
| Leaving | Pad's hot. Go on, before the clock notices. |

### Remembers-you lines

Keyed to run history (`design-v2/STORY-THREADS.md` §6 names the records). One plays on entering the bay when its key holds; the first-visit line plays otherwise.

| Key | Line |
| --- | --- |
| `first_visit` | Shelf's there. Hook's not for sale. Ask anyway, everyone does. |
| `died_last_run`, same class | Back again. The Warden keeps your last shell, you know. |
| `won_last_run` | You finished one. Shelf's the same. Standards aren't. |
| `class_changed` | New pilot, same ball. Moss remembers the ball. |
| `skipped_visits >= 3` | Three launches past my door. Bell still works. |
| `relented_before` | Heavy again. Hook's already yours, don't act surprised. |
| `neglected` (callback C14, scrap at death) | Died holding scrap. Scrap that could've been plating. Hm. |
| `refused_before` (the loop's variation index reads it) | Back for the hook? Answer hasn't changed. Ask anyway. |
| `sold_back` (the family sold most; the shelf leans toward it) | You keep selling plating. Fine. Shelf's got plating. |
| `neglected_ability` (the ability used least last run, per pilot) | Never touched F last run. It's a key, not decoration. |
| `fragment_carried` (a world fragment found this run) | Whatever that is, keep it off my bench. |
| `pressure` (valves on the exit wall; later) | no line: the valves' state is the wording |

This is the one Moss key table (primer reconciliation 4). `PROGRESSION.md` §3 lists the same facts under `moss_*` ids and owns where they persist; the names here are the ones the lines are keyed to.

### Ledger lines

Keyed to the ledger leaves returned so far; one plays instead of the remembers-you line on the visit Moss takes a leaf.

| Key | Line |
| --- | --- |
| `moss.ledger.1` | A ledger leaf. Tally's scrawl. Pinned it by the shelf. |
| `moss.ledger.2` | Second leaf. Tally's been counting on you. Literally. One more. |
| `moss.ledger.3` | Three leaves. Balance due. Tally's at the gate, pockets full. |

**Voice rules for any new Moss line.** Twelve words or fewer. He talks about weight, welds, the shelf and the clock, never about the collapse; that is the codex's job, and Moss keeps his opinions. He is grumpy about the hook and kind about the pilot. He never says "too strong for you" as a sentence of its own, never names a potion, a traveller or a wizard, and never dismisses the player to a seller of "weaker" anything; the send-off goes to lighter parts, flimsy carts or the gates.
