# Scrapkeep character bible

5 September 2026. This document is the production-guiding character reference for pilots, antagonists, companions, and supporting cast, written deep enough to brief an artist or writer cold.

Everything here that invents fiction is a proposal. The Requisition premise, the five-rung campaign, and the pilot species slots come from the 5 September 2026 audit (docs/DESIGN-AUDIT.md:45,66-70; docs/audit-2026-09-05/worker-4-universe.md:24,56-70,106-113) and remain pending Andrew's approval. Confirmed pillars this document must not contradict: rolling, collecting and bumping central with the cute animal visible in accumulated scrap (docs/DISCOVERY.md:15); four class fantasies (docs/DISCOVERY.md:17); loot-assembled companions that prime, buff and intervene (docs/DISCOVERY.md:29); between-run unlocks that never raise permanent combat stats (docs/DISCOVERY.md:35; docs/project/REQUIREMENTS.md:18).

## Cast rules (proposal)

1. Pilots are keepers, not soldiers. They are the region's maintenance crews, fighting with the junk pile (worker-4-universe.md:36-46). Machines are workers, not monsters.
2. Animals appear in exactly two places: inside pilot capsules and inside Fleet command cars. Enemy machines are autonomous, faces are control boxes, no animal operators (docs/CONCEPT-STUDY-03.md:15).
3. Identity lives in silhouette, emotion lives in the face. Each pilot owns one saturated accent color, one ear-plus-headgear dome silhouette, and one idle posture (worker-4-universe.md:102). The capsule is about 64 px in the chase camera, so shape carries recognition.
4. Nobody in this cast is evil. Brindle is wrong, the overseers are loyal or tired, the machines are conscripted. Comedy and menace both come from workplaces misbehaving (worker-4-universe.md:24).
5. Names are short object nouns from working life, matching the shipped precedent Pip, Rivet, Moss, Brindle (src/campaign.js:2-21; docs/CONFLICT-AND-COMBAT.md:22).

## Pilot roster

Four slots map to the four confirmed class fantasies (docs/DISCOVERY.md:17), following the audit's species table (worker-4-universe.md:106-113). Names other than Pip and Rivet are proposals.

Artist quick reference (proposal):

| Pilot | Species | Class | Owned accent | Dome silhouette | Idle posture |
| --- | --- | --- | --- | --- | --- |
| Pip | Hamster | Grapple | Amber-orange (src/heroes.js:16) | Round ears, pushed-up goggles | Leaning hard forward, paws on levers |
| Vane | Fox | Hover mortar | Rust-red (from src/heroes.js:8) | Tall ears through slotted aviator cap | Lounging back, one paw on stick |
| Rivet | Mole | Cyborg laser | Mint (src/heroes.js:17) | No ears, wide rectangular lens visor | Perfectly still, tracking in increments |
| Fuse | Squirrel | Lightning | Storm blue (src/heroes.js:18) | Tufted ears under oversized cap, static tail | Cannot hold one; cycles three perches |

### Reconciling Rivet and Moss (contested)

The baseline trio is Pip the scavenger, Rivet the engineer, Moss the warden (docs/BASELINE-GUIDE.md:28-30; src/campaign.js:2-21). The meta lane retires the three-hero roster as content while keeping the names as candidates (worker-3-meta.md:153). The universe lane names the mole machinist a candidate heir to Rivet's slot (worker-4-universe.md:112). **Recommendation:** Rivet survives as the mole laser machinist, keeping the name, the engineer identity and the motto "One more wire. One less problem." (src/campaign.js:12). Moss leaves the playable roster and becomes the supporting cast's depot provisioner and Scrapbook author (section below). Moss's owned blue (src/heroes.js:18) passes to the lightning pilot. Nothing about the preserved yard demo at `/` changes (docs/project/REQUIREMENTS.md:11, R05).

### Pip, hamster, grapple keeper (proposal on audit canon)

- **Bio.** Depot keeper of the Yard Commons salvage rounds. Small, loud, fearless, sentimental about machinery. The shipped story line stays canon taste: "If it rattles, Pip can probably make it shoot." (src/campaign.js:6). Pip as hamster is the audit recommendation, already modeled in the first build (worker-4-universe.md:104, citing docs/FIRST-BUILD-VERIFICATION.md:31).
- **Occupational backstory.** Ran the Commons depot winch and collection crane, hooking dead machines onto flatbeds. Grapple is the day job with the safety limiter removed. Real-role grounding: municipal refuse and salvage collection is a real occupation (O*NET 53-7081.00, https://www.onetonline.org/link/summary/53-7081.00, accessed 5 September 2026).
- **Owned accent.** Amber-orange, the shipped scavenger color (src/heroes.js:16), worn as a harness scarf.
- **Silhouette.** Round ears plus push-up goggles on the forehead. Never worn over the eyes; Pip aims by feel.
- **Idle posture.** Leaning hard forward, both paws on the levers, nose almost on the glass.
- **Barks.** "Hooked it!" / "That rattles. Mine now." / "Bolt's off. Go home, big fella."
- **Class tie-in.** Grapple traversal: small body, huge momentum, the whole fantasy of swinging mass (worker-4-universe.md:110). Kit skeleton: Lash Hook, Winch Yank, Scrap Comet (worker-2-combat.md:85-90).
- **Capsule expression range.** Neutral: cheeks working on a seed. Windup read: ears snap up. Deflect: cheeks puff, eyes shut. Counter payoff: full-body bounce, fists up. Low hull: ears flat, grip tightens, no fear face, just focus.
- **Figurine note.** The hamster dome is the line's hero SKU. Capsule collar must pop from any scrap density (worker-4-universe.md:83); dome bears no load in the pose (worker-4-universe.md:125). Base chip: curb corner, the Commons module name (WORLD-ENVIRONMENTS.md:44), orange-edged.

### Vane, fox, hover mortar artillerist (proposal)

- **Bio.** Orchard keeper who ran the frost towers. Patient, dry, talks to the wind. Recovers the study-01 fox pilot the hamster decision freed (worker-4-universe.md:104,111; docs/CONCEPT-STUDY-01.md:20).
- **Occupational backstory.** Operated the Iron Orchard's frost-protection wind machines, the tall fans that pull warm air down onto the rows on freezing nights. Real machines, real vigil work: wind machines mix warm inversion air to protect orchards during radiational frosts (UC Cooperative Extension Ventura County, https://ucanr.edu/county/cooperative-extension-ventura-county/methods-frost-protection, accessed 5 September 2026; Penn State Extension, https://extension.psu.edu/frost-critical-temperatures-and-frost-protection, accessed 5 September 2026). A keeper who spends nights reading air columns becomes an artillerist who lofts shells through them.
- **Owned accent.** Rust-red, deepened from the shipped orangeDark (src/heroes.js:8), worn as a neck kerchief.
- **Silhouette.** Tall ears through a slotted aviator cap, one ear always cocked off vertical.
- **Idle posture.** Lounging back, one paw on the stick, watching the top of the screen.
- **Barks.** "Wind's right." / "Shell's up. Count three." / "Told you where it lands."
- **Class tie-in.** Hover mortar: patient, watchful posture suits bombardment (worker-4-universe.md:111). Kit skeleton: Lofted Shell, Hop-Jet, Skydeck (worker-2-combat.md:92-99).
- **Capsule expression range.** Neutral: half-lidded. Windup read: one ear rotates, eyes narrow. Deflect: unimpressed grimace. Counter payoff: slow satisfied nod. Low hull: sits up straight for the first time, which reads as the real alarm.
- **Figurine note.** Cap and ears are one silhouette unit; mold them as a single separable part with the two-ear axis dominant (part rules at worker-4-universe.md:127). Base chip: orchard apron with a nursery tray.

### Rivet, mole, cyborg laser machinist (proposal keeping a shipped name)

- **Bio.** Foundry Crown pattern-shop machinist. Precise, literal, kind. Nearly blind in daylight and completely untroubled by it. Keeps the shipped motto (src/campaign.js:12).
- **Occupational backstory.** Kept the foundry's alignment instruments and cutting gear, the reference lines every crane and carriage was squared against. Foundries are real dispatch-and-remelt workplaces (repo-inspected source at docs/ENEMY-TAXONOMY.md:114). Weak eyes, perfect aim through instruments: the visor is the character (worker-4-universe.md:112).
- **Owned accent.** Mint, the shipped engineer color (src/heroes.js:17), as visor glow and glove piping.
- **Silhouette.** Almost no ears plus a wide rectangular lens visor, the only hard-edged dome silhouette in the roster.
- **Idle posture.** Perfectly still, head tracking in small exact increments, one claw tapping a dial.
- **Barks.** "Line is true." / "Measured twice. Firing once." / "That joint was loose anyway."
- **Class tie-in.** Cyborg laser: Coherence Beam pierce, Refraction Flick, Foundry Cutter (worker-2-combat.md:101-108). The Open Furnace item, a held sweeping beam steered while braking (worker-2-combat.md:108), is Rivet's transformative fantasy.
- **Capsule expression range.** Smallest range in the cast, on purpose. Neutral and windup read are identical; only the visor's mint line sharpens. Deflect: head ducks a precise centimeter. Counter payoff: visor flips up to show tiny proud eyes, the roster's rarest expression. Low hull: visor cracks display static.
- **Figurine note.** Visor is a clear resin insert; treat like the cockpit dome, no load (worker-4-universe.md:125). Steel, copper and enamel paint as three materials (docs/ENEMY-TAXONOMY.md:183). Base chip: rail siding curve.

### Fuse, squirrel, lightning caster (proposal adopting the notebook)

- **Bio.** Spillway Works electrician's apprentice, three-quarters through certification and certain the last quarter is a formality. Direct adoption of the notebook's amateur chaos caster, "75% there, thinks they're hot shit" (docs/HANDWRITTEN-NOTES.md:37), under the interpretation that personality comes from improvised machinery, not random control loss (docs/HANDWRITTEN-NOTES.md:81; worker-4-universe.md:113).
- **Occupational backstory.** Journeyman electrician certification is a real multi-year apprenticeship of roughly 8,000 supervised hours plus classroom instruction (https://www.electricianschooledu.org/journeyman/, accessed 5 September 2026). Fuse has the hours, not the exam. The kit is competent wiring with the arrogance still attached.
- **Owned accent.** Storm blue, inheriting the freed warden hex (src/heroes.js:18), as taped cable wraps on both arms.
- **Silhouette.** Small tufted ears under an oversized borrowed journeyman's cap, plus the static-charged tail filling the back of the dome (tail silhouette per worker-4-universe.md:113).
- **Idle posture.** Can't hold one. Cycles between three perch positions; the tail never stops.
- **Barks.** "Watch THIS." / "Meant to do that." / "Okay. New plan. Same plan, but louder."
- **Class tie-in.** Lightning network: Arc Lance chains, Capacitor Trail so rolling is casting, Ride the Lightning (worker-2-combat.md:110-117). Ground Loop, where every bump discharges, is Fuse's flagship item (worker-2-combat.md:117).
- **Capsule expression range.** Widest range in the cast. Neutral: smug. Windup read: delighted. Deflect: cackle. Counter payoff: showboat pose held one beat too long. Low hull: the smugness drops and a scared kid is visible for exactly one second, the roster's one honest tell.
- **Figurine note.** Tail violates the one-dominant-axis part rule unless molded curled against the dome collar (rule at worker-4-universe.md:127). Base chip: sluice-gate lip, the Spillway's fixed chip (WORLD-ENVIRONMENTS.md:44,64).

### Roster staging: when each pilot enters the story (proposal)

The meta lane's unlock plan already schedules the classes: starter, then class 2 at the first stage-2 boss kill, class 3 by win or six boss kills, class 4 by an untouched defense or twelve boss kills, all four live before hour 7 (worker-3-meta.md:67,84-89). Character staging should ride those triggers, not add new ones:

- Pip is the starter and the tutorial voice; the Commons is Pip's own depot, so rung 1 is a homecoming gone wrong.
- Vane arrives after the first stage-2 boss falls, introduced by a Moss margin note that the orchard's frost keeper has been asking about the ball.
- Rivet unlocks at the win-or-persistence milestone and is introduced repairing the depot doors nobody asked about, mid-sentence, as if already hired.
- Fuse unlocks last and arrives uninvited, having rewired the depot loudhailer to announce Fuse.
- Each unlock's results-screen preview line (worker-3-meta.md:133) is written in the incoming pilot's voice, so the character is a promise before it is a choice.

### Cast chemistry (proposal)

Solo ships first (docs/DISCOVERY.md:23), so chemistry surfaces in Scrapbook margins, interstitial staging and result-screen stingers now, and becomes co-op bark material later. One line per pair, written as the relationship's engine:

- Pip and Vane: speed versus patience. Vane calls Pip "the ricochet." Pip has never once waited for the count of three.
- Pip and Rivet: Pip breaks it, Rivet measures it, both call that teamwork and mean it.
- Pip and Fuse: the two overconfidences. Together they are the cautionary tale Moss writes up most often.
- Vane and Rivet: the quiet professionals. Entire conversations happen in one ear movement and one dial tap.
- Vane and Fuse: Vane is the only one Fuse performs for, because Vane never reacts, which drives Fuse insane.
- Rivet and Fuse: master and almost-journeyman. Rivet is the only authority Fuse accepts, three-quarters of the time.
- Moss and everyone: Moss stocks each pilot's capsule with the thing they forgot. The Scrapbook margin notes are how the player learns this.

## Antagonists

### Admiral Brindle (development of docs/CONFLICT-AND-COMBAT.md:22)

- **Who.** A badger you could hold in two paws, commanding more iron than any animal should need (worker-4-universe.md:38). Optional recurring antagonist in the workshop paper; this bible develops him as the campaign spine, pending approval.
- **Motivation.** Sincere, not scheming. The Furnace City really is starving (worker-4-universe.md:24) and Brindle genuinely believes one more harvest secures it. He inherited a magnificent city already dying and has never once said so aloud. The proposal is sincere-but-wrong rather than lying; the tone fork is flagged as an open question.
- **Speech pattern.** Ledger arithmetic. Short declaratives in tonnage, rations and ledger lines. Never shouts, never threatens, rounds every number up. Signature constructions: "The city needs eleven hundred tons. Call it twelve." and the canon promise "one more harvest" (docs/CONFLICT-AND-COMBAT.md:22). He thanks regions for their contribution as if they volunteered.
- **On-screen presence per campaign rung** (five-rung campaign per docs/DESIGN-AUDIT.md:67):
  1. Yard Commons: paper only. Requisition manifests stamped with his seal on bolted machines. The player learns the name before the face.
  2. Spillway Works: voice only, through loudhailers on requisitioned machines, praising quota progress.
  3. Iron Orchard: first sighting, distant and small, an inspection car crossing the horizon behind the Grand Pruner. He does not notice the player.
  4. Foundry Crown: first direct address. Mid-encounter, over the yard horns, he offers the keeper a Fleet commission by name, inside the overseers' three-line budget. Refusal costs nothing; the cranes never stop.
  5. Furnace City: present throughout the rung, directing the city's defense from an open command balcony. The finale's staging is combat design's problem; his character rule is that he never runs and he is the last to admit the arithmetic never worked.
- **What Brindle never does** (writer's negative space, proposal). He never raises his voice. He never threatens a keeper personally; machines are requisitioned, animals are "invited." He never appears without the ledger. He never destroys anything himself, which is exactly the point: everything the Fleet breaks was broken by a machine that used to fix things. And he never gets the sums to balance on screen, not once, so the player can do the arithmetic he refuses to.

### Fleet overseers, one per rung (proposal)

Each overseer is a rival-crew animal in a real occupational role, commanding the biome's requisitioned machinery through the bolted overrides (docs/ENEMY-TAXONOMY.md:122). They appear at defense encounters and boss approaches, speak at most three lines per encounter, and are never fought bodily; their machines are the fight.

| Rung | Overseer | Species | Real occupational role | Machinery commanded |
| --- | --- | --- | --- | --- |
| Yard Commons | Reeve Cinch | Stoat | Collection-route foreman; refuse and recyclable collection is a real occupation (O*NET 53-7081.00, https://www.onetonline.org/link/summary/53-7081.00, accessed 5 September 2026) | Scooplet-strain collectors and yard bugs of the baseline enemies (worker-4-universe.md:60; docs/ENEMY-TAXONOMY.md:49) |
| Spillway Works | Overseer Weir | Muskrat | Wastewater treatment plant and system operator, a real licensed occupation (BLS OES 51-8031, https://www.bls.gov/oes/2023/may/oes518031.htm, accessed 5 September 2026) | Cancrusher family: Scooplet, Rackspan, Crossbelly, Rinsebelly, Pressling; Sluiceback miniboss (docs/ENEMY-TAXONOMY.md:26-71) |
| Iron Orchard | Steward Pomace | Marten | Orchard harvest steward; pruning, training and irrigation service are the taxonomy's inspected real practices (docs/ENEMY-TAXONOMY.md:161-164) | Grand Pruner family: Snipcart, Spreadleg, Flushpot, Discback, Graftmender; Rowkeeper miniboss (docs/ENEMY-TAXONOMY.md:120-155) |
| Foundry Crown | Dispatcher Bessemer | Shrew | Rail yardmaster, a real coordination occupation (BLS railroad occupations, https://www.bls.gov/OOH/transportation-and-material-moving/railroad-occupations.htm; O*NET 53-4031.00, https://www.onetonline.org/link/summary/53-4031.00, both accessed 5 September 2026) | Counterweight Crown family: Pegjack, Reelrat, Bellhanger, Brakebogie, Clampcart; the Yardmaster miniboss is her personal machine (docs/ENEMY-TAXONOMY.md:73-118) |
| Furnace City | First Stoker Damper | Porcupine | Stationary engineer and boiler operator, a real licensed occupation (BLS OOH, https://www.bls.gov/ooh/production/stationary-engineers-and-boiler-operators.htm, accessed 5 September 2026) | The city engine works and every family's overseer variants (worker-4-universe.md:66) |

**Reeve Cinch, Yard Commons.** A clipboard on legs. Speech pattern: inventory readbacks; every sentence ends with an item count or the word "logged." Sample line: "Two fences, one gantry, forty tin cans. Logged. You were never here." Presence: opens the campaign as the first speaking antagonist, bolting overrides during the tutorial rounds. Cinch is the joke that teaches the premise: the Fleet does not raid, it files. Defeat reaction: requests a receipt for the machines the player unbolts.

**Overseer Weir, Spillway Works.** The only overseer who was good at the real job. Speech pattern: process states spoken as weather: "Screens fouled. Pressure climbing. You are the blockage." Presence: appears at basin defense encounters and at Sluiceback's arena mouth. Weir hates the quota because dirty water offends her professionally; she says so once, quietly, if the player counters cleanly through a whole encounter. First hairline crack in the Fleet's story.

**Steward Pomace, Iron Orchard.** Performed cheer over quiet arithmetic. Speech pattern: harvest-festival warmth with tonnage underneath: "What a season. What a yield. Do stop denting it." Presence: rides ahead of the Grand Pruner on a tally cart, narrating the harvest as if the orchard consented. Pomace counts trees the way Brindle counts tons, and the wrongness of that echo is the rung's theme: the orchard stays worth protecting (docs/ENEMY-TAXONOMY.md:122,166).

**Dispatcher Bessemer, Foundry Crown.** The campaign's most dangerous mind. Speech pattern: departure times and track assignments, nothing else: "Hammer on four. You are standing on four." Presence: audible over the yard horns through the whole rung, and every miniboss and carriage pattern is staged as one of her timetables. The Yardmaster miniboss is her personal machine (docs/ENEMY-TAXONOMY.md:89,104). **Naming collision, contested.** That miniboss name is set, and a second Yardmaster would confuse the Scrapbook. **Recommendation:** keep the machine's name, title the character Dispatcher, and let one line land the joke that Bessemer named the machine after her own job.

**First Stoker Damper, Furnace City.** Chief of engines, oldest crew member, the one animal aboard who has read the boiler math. Speech pattern: maintenance confession; he narrates the city's failures as if reading its service log. Sample line: "Boiler six is a memorial. We stoke it anyway. Morale." Presence: speaks to the player across the whole final rung through the engine works, half warning, half job interview. Damper is the defection candidate the workshop paper allows for (captains negotiate, defect, or take a rivalry personally, docs/CONFLICT-AND-COMBAT.md:22). Whether he turns is left to campaign writing; his character rule is that he will not lie about a gauge reading, even to Brindle.

## Companions

Confirmed base: companions are found and assembled from run loot, and their value is priming, buffing and clutch intervention (docs/DISCOVERY.md:29). A found chassis supplies form and movement; modules change support behavior (docs/DISCOVERY.md:125). One is implemented: Shear Buddy, deployed after collecting a Shear Linkage, priming targets for 1.3x (docs/FIRST-BUILD-PLAYGUIDE.md:57,63).

### Chassis personality archetypes (proposal)

Personality is movement, not dialogue. Three archetypes map onto the confirmed contribution triad:

- **Heralds** (primers): darting, pointing movers that face what you should hit. Herald chassis lean forward when a mark lands.
- **Stewards** (buffers): steady orbiters that hold formation and brighten when their field is up. A Steward's calm is the readability cue.
- **Catchers** (interveners): loose, springy loiterers that explode into motion for a rescue, then trot back visibly pleased with themselves.

### Naming scheme players encounter (proposal, one recommendation)

Chassis keep their service stencils, the way the ball's salvage plate reads ORCH-7 in the family study (worker-4-universe.md:78). Format: biome prefix plus bay number: SNIP-3, SPIL-12, CROWN-8. The Scrapbook then appends an earned epithet after the companion's first notable logged deed, following the written-only-by-observed-play rule (worker-3-meta.md:102-106): SNIP-3 "Nibbles", SPIL-12 "Latchkey". **Recommendation:** stencil plus earned epithet, no free-text player naming at launch; earned names are shareable and safe by construction.

### Module swaps read as personality changes (proposal)

Rule: a module changes gait, chirp and posture, never just a stat line. Three worked examples:

1. **SNIP-3, Snipcart-linkage walker.** As shipped it is a Herald: quick darting approach, two-click chirp, primes a target every 2.5 seconds (docs/FIRST-BUILD-PLAYGUIDE.md:63). Swap in a Drain Basket module (docs/ENEMY-TAXONOMY.md:52) and it becomes a Catcher-leaning collector: the dart becomes a busy circling sweep, the chirp becomes a satisfied gulp, and it hoards displaced pickups toward the player's exit line. Same legs, visibly different soul.
2. **SPIL-9, hover salvage drone.** The discovery record's own worked candidate (docs/DISCOVERY.md:125). With a conductive applicator it is an eager Herald that bobs twice before every mark. Swap the applicator for the rescue module and it becomes a showboat Catcher: it shadows the player higher and lazier, then dives to cut an escape corridor and pulls up in a little loop. Same rotor, new temperament.
3. **The Wakeful Core.** Adaptation of the notebook's just-awoken conscious bomb drone (docs/HANDWRITTEN-NOTES.md:46), per the interpretation that it suits a deployable companion theme without runtime AI services (docs/HANDWRITTEN-NOTES.md:83). A salvaged Fleet ordnance core that decided not to detonate. As a Steward it projects a brief brace field when the player commits to a ram; its single ascending chime gets one note longer with each module fitted, which reads as it learning. It is the only companion whose epithet slot fills with a name it appears to choose.

### Companion readability rules (proposal)

The discovery record asks that a companion's contribution be readable through animation, effects and reactions, and that a rescue create a recoverable opportunity the player can exploit (docs/DISCOVERY.md:121). Character rules that serve that requirement:

1. Every contribution has a wind-up pose lasting long enough to notice, in the companion's archetype language: Heralds point, Stewards plant, Catchers crouch.
2. Cooldown is body language, not a bar. A spent companion visibly droops, trots, or dims until ready, so trust is learned by watching (availability must be understandable, docs/DISCOVERY.md:121).
3. Companions never speak words. Chirps, chimes and gestures only. The text budget stays with pilots and the Scrapbook.
4. A companion reacts to the player's big moments: counters at 2.1x (docs/FIRST-BUILD-PLAYGUIDE.md:44) get a companion celebration one beat after the payoff, never during the read.
5. Companion cores are never absorbed into the ball; they dock (never-absorbed list, worker-4-universe.md:86). Losing a run never deletes an assembled companion's Scrapbook entry.

## Supporting cast and the Scrapbook voice

### Who writes the log (contested, one recommendation)

The Scrapbook is one screen, five tabs, written only by observed play (worker-3-meta.md:106). Someone's hand should hold the pen. Candidates: an unvoiced player-keeper hand, or a named provisioner. **Recommendation:** Moss writes it. Moss the warden already owns the protective register, "The little garden behind the core is worth protecting." (src/campaign.js:18), and the retirement of the trio as playable content (worker-3-meta.md:153) frees the name. Proposed staging: Moss the hedgehog, provisioner of the keepers' depot, appears in interstitials restocking the ball, and every Scrapbook entry is Moss's service log of what the player actually did. The title avoids the enemy roster's Quartermaster miniboss (ENEMY-ROSTER.md:131), applying the same machine-keeps-the-name rule used for the Yardmaster above.

### Tone rules for all written text (proposal)

1. Service-log grammar. Short declaratives, present tense, machine empathy. "Snipcart. Cuts a fixed arc, then rests. The rest is where you answer."
2. Machines get respect, never hatred. Entries record the job the machine used to do and end deadpan: "Good rake. Wrong boss."
3. The seen-not-taken shelf writes longing, not guilt: "Counterweight Heart. Left on the bench. It will keep." (ledger per worker-3-meta.md:104,131).
4. No military vocabulary anywhere. Keepers decommission, unbolt, and send machines home. Only the Fleet says harvest.
5. Wonder over dread at every scale rung. The Furnace City is written as magnificent and hungry, matching the premise page (worker-4-universe.md:38).

### Sample entries, one per Scrapbook tab (proposal)

The five tabs are Pilots, Salvage, Companions, Foes, Expeditions (worker-3-meta.md:106). Writing samples in Moss's voice, to calibrate a writer, not final copy:

- Pilots: "Fuse. Cleared the south basin without touching the water. Told me twice. Restocked the capsule with dry socks anyway."
- Salvage: "Valve Wheel. Stores a shove in the brake and spends it in the turn. Pip calls it the argument-winner. Entry updated after it actually worked."
- Companions: "SNIP-3, now 'Nibbles.' Primed a Pressling mid-stroke and did a little bow. The bow is not in any manual I stock."
- Foes: "Rinsebelly. Fills, drains, presses. Approach on the drain. Good pump. Wrong boss." (behavior checkmarks fill only when the player performs the counter, worker-3-meta.md:103).
- Expeditions: "Spillway, second attempt. Two branches found, one basin drained. The Counterweight Heart stayed on the bench. It will keep."

### Bark matrix (proposal, writing samples)

The four trigger families key to events the simulation already emits or the audit specifies: enemy windup within threat range, a Roll-Through deflect (worker-2-combat.md:44), a recovery counter payoff (docs/FIRST-BUILD-PLAYGUIDE.md:44), and the low-hull threshold. One sample per cell; launch needs three per cell per pilot:

| Trigger | Pip | Vane | Rivet | Fuse |
| --- | --- | --- | --- | --- |
| Windup read | "Big swing. Bad idea." | "Hold. Hold." | "Committed. Noted." | "Ooh, it's MAD." |
| Deflect | "Off me!" | "Through." | "Glancing. Acceptable." | "Can't touch this!" |
| Counter payoff | "Bolt's off!" | "Down where I said." | "Line was true." | "SAW that, right?" |
| Low hull | "Still rolling!" | "Getting loud in here." | "Hull integrity: rude." | "New plan. Louder." |

### Text budget (contested, one recommendation)

How much text the game carries is a real scope choice. **Recommendation:** silence is the default and the budget is fixed as follows. Combat carries barks only: 12 per pilot at launch across four trigger families (windup read, deflect, counter payoff, low hull), each 6 words or fewer, text-chirp delivery with no recorded voice at launch. The world-space threat banner already carries the warning load (docs/DESIGN-AUDIT.md:28), so barks are flavor and must never carry safety information. Written prose lives only in the Scrapbook (40 to 80 words per entry, Moss's voice) and one interstitial card of at most 25 words per stage break (the interstitial is one breath, no shop, worker-3-meta.md:51). Brindle and overseers get at most 3 lines per encounter. No cutscenes inside expeditions. Estimated launch total: roughly 48 barks, about 120 Scrapbook entries, under 40 antagonist lines. Small enough to rewrite in a week, which is the point.

## Notebook personality verdicts

The notebook characters are candidates, not requirements (docs/HANDWRITTEN-NOTES.md:5,74-84). Verdicts, one each:

| Notebook character (docs/HANDWRITTEN-NOTES.md:33-38,46,66) | Verdict | Reason |
| --- | --- | --- |
| Chaos caster, "75% there, thinks they're hot shit" (:37) | **Keep** | Adopted whole as Fuse, the lightning squirrel, per the interpretation that improvised machinery carries the personality without random control loss (:81; worker-4-universe.md:113). |
| Conscious bomb drone (:46) | **Adapt** | Becomes the Wakeful Core companion, exactly as the interpretation table suggests (:83). A pilot slot would waste its best trait, which is being equipment with an opinion. |
| Oil-slick character (:66) | **Adapt** | Becomes an item and terrain mechanic, not a pilot, per the interpretation (:82). Character survives as the item's Scrapbook entry voice: the entry is written with elongated letters, the notebook's own joke. |
| Beast-mode body shifter (:33) | **Park** | A toggled transformation fights bounded growth within designed routes (docs/DISCOVERY.md:37). The shout energy survives: ult activations are the sanctioned beast-mode moment, and the 100% charge cue is class-voiced (worker-2-combat.md:145). Revisit if a fifth class slot ever opens. |
| Gunslinger with knockback pistols (:34) | **Park** | No slot among the four confirmed fantasies (docs/DISCOVERY.md:17) and knockback authorship already belongs to grapple displacement and mass trades (worker-2-combat.md:56-75,87). Candidate expansion pilot for a Harvest Roads rung. |
| Ghost of unresolved name (:61-64) | **Park** | The name is illegible in the source and the rule is not to convert uncertain handwriting into requirements (docs/HANDWRITTEN-NOTES.md:91). Hold until Andrew supplies a reading. |

## Character expression without dialogue

### Mastery titles (proposal on shipped systems)

The baseline ships five badge titles from "New wheels" to "Orchard legend" (src/campaign.js:89-95), cosmetic only, and the meta lane carries titles forward as shelf finishes and poses, never combat stats (worker-3-meta.md:124; docs/project/REQUIREMENTS.md:18). Proposal: title tracks become per-class registers, so progression reads as the pilot's trade advancing. Pip's track uses rigging terms (Hook Hand, Load Bearer), Vane's uses watch terms (Night Watch, Stormglass), Rivet's uses shop grades (Apprentice True, Micrometer), Fuse's is certification stages ending one short of Journeyman forever, which is the character.

### Capsule animation (proposal on shipped events)

The cockpit is the single visual invariant (worker-4-universe.md:83), so it is the emotional channel. Expression states key to events the simulation already emits: enemy windup, the announced recovery ("Housing exposed" fires as an event, worker-2-combat.md:143), the hurt window, and counter payoff. Each pilot's five-state range is specified in the roster above; the design rule is that all four pilots share the trigger set but never share a pose, so a screenshot of any dome at any moment identifies the pilot.

### Per-class movement personality (proposal)

Expression lives in decorative motion outside the dependable collision envelope, never taxing control (worker-4-universe.md:86). Grapple: pendulum swagger, the ball settles with a rope-like overshoot after swings. Hover mortar: a breathing bob at rest, Hop-Jet arcs leave a lazy smoke ring. Laser: no overshoot at all, brake-precise stops, the one class whose stillness is the flourish. Lightning: static pops in the trailing scrap and a tail-flick shimmy after every chain. These read at thumbnail distance and double as class identification during future co-op or challenge replays.

## Next three character studies for the art pipeline

These extend the audit's five-step art plan without duplicating it; the Pip capsule and expression sheet is already queued as its step 3 (worker-4-universe.md:145).

1. **Four-pilot capsule lineup.** Medium: Krita turnaround sheet, monochrome pass then accent pass, all four domes at identical scale. Acceptance: at 64 px dome crops a cold viewer names each pilot by silhouette alone in 8 of 10 trials, and no two accent colors are confusable in a grayscale print.
2. **Brindle and the overseers heraldry sheet.** Medium: Krita, one sheet: Brindle full body plus the five overseers, each with one occupational prop and their machine's silhouette behind them. Acceptance: occupation guessable from silhouette and prop before reading any label for at least 5 of 6 characters, and Brindle measurably smaller than every machine on the sheet.
3. **Companion module-swap turnaround.** Medium: Blender blockout of the SNIP-3 chassis plus Krita motion-thumbnail strips for three module states. Acceptance: viewers match module to motion strip 3 of 3, and the silhouette change reads at 48 px. Feeds the figurine part-separation rule directly, since module seams are print seams (worker-4-universe.md:127).

## Evidence limits

Scope of invention in one line: this document coins two pilot names (Vane, Fuse), five overseers, one companion character (the Wakeful Core), a naming scheme, and a text budget; everything else extends cited material.

Paper review only. Sources read in full this session: docs/DESIGN-AUDIT.md, docs/DISCOVERY.md, docs/CONFLICT-AND-COMBAT.md, docs/ENEMY-TAXONOMY.md, docs/HANDWRITTEN-NOTES.md, docs/BASELINE-GUIDE.md, docs/CONCEPT-STUDY-01.md through 03, docs/FIRST-BUILD-PLAYGUIDE.md, docs/project/REQUIREMENTS.md, src/heroes.js, src/campaign.js lines 1 to 100, and all four audit working papers via the three read here (worker-2, worker-3, worker-4). Claims about FIRST-BUILD-VERIFICATION.md and FIRST-BUILD-CONTRACT.md are cited through worker-4's lines, not read directly. Web claims are six occupational-role sources, each cited with URL and the 5 September 2026 access date; none establishes anything about the game beyond the reality of the role. No images were generated, no runtime was tested, no repository file was written. Every named character other than Pip, Rivet, Moss and Brindle is invented in this document and pending Andrew's approval, as is everything downstream of the Requisition premise. No fun, tone-landing or localization claim is verified; barks and log entries are writing samples, not final copy.
