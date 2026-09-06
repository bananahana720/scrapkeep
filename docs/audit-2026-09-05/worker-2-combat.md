# Worker 2 — Moment-to-moment combat system proposal

5 September 2026. Combat-design worker report for the Scrapkeep design swarm. Read in full this session: `docs/CONFLICT-AND-COMBAT.md`, `docs/ENEMY-TAXONOMY.md`, `docs/ORCHARD-ENCOUNTER-STUDY.md`, `docs/FIRST-BUILD-PLAYGUIDE.md`, `docs/DISCOVERY.md`, `src/orchard/simulation.js` (863 lines); skimmed `docs/COMBAT-DESIGN-SWARM.md`, `docs/CONCEPT-STUDY-02.md`. No repository file was written or changed. Every implemented number below cites `src/orchard/simulation.js` (abbreviated `sim.js`) or a doc line; everything not cited to a file is labeled **proposal**.

**Implemented grammar this builds on (all cited):** direction locks at windup start (`enemy.yaw = yawTo(enemy, this.player)` only inside the windup transition, sim.js:365; approach re-aims each step, sim.js:399). Windup renders the full stroke as 17 sampled preview capsules (sim.js:488–492). Each attack damages the player at most once (`enemy.struck`, sim.js:494–505) and the player then has a 1.05 s hurt-protection window (sim.js:732, 737). Recovery exposes a side weak point offset `radius + 0.2` (sim.js:438–440); a ram counter needs `state === "recovery" && weakGap < p.radius + 1.9` during a dash (sim.js:608–612), a shot counter needs `recovery && weakAcross <= 0.9` (sim.js:669–673). Counters deal 2.1×, primes 1.3×, and they stack multiplicatively (sim.js:681). Counters drop scrap once per attack cycle (sim.js:689–695). Only one non-Pruner worker may be in windup at a time, with a 0.8 s stagger (sim.js:406–413, 422). Body contact is a damage-free pushout (sim.js:621–630). Player: roll 7.4 / brake 2.2 (sim.js:323), accel 25 + brace·4, brake accel 48 (sim.js:329), burst 19 u/s for 0.24 s on cooldown `max(0.85, 1.45 − brace·0.22)` (sim.js:297–300), charge shot 10 + 32·charge over 1.1 s (sim.js:319, 673), shot cooldown 0.28 s (sim.js:638). Radius grows `1 → min(1.65, 1 + scrap·0.022 + shear·0.045 + brace·0.045)` (sim.js:139, 778–781) and the radius **is** the hitbox against tool capsules (sim.js:497–500) and offcuts (sim.js:575–576).

---

## 1. Defensive rhythm — comparison and single recommendation

This is the standing open publisher question (CONFLICT-AND-COMBAT.md:11, 106–110, 173: "The balance among evasive movement, held guard and precise parries is still a publisher question").

### Model A — pure spacing/repositioning (today, implemented)

What ships now: read the 1.15–1.75 s windup (sim.js:17, 29, 42), leave the locked stroke, brake-turn (accel 48, sim.js:329) or burst 4.6 u (19 u/s × 0.24 s, sim.js:297–299). Burst grants no protection (FIRST-BUILD-PLAYGUIDE.md:42; `_hurt` checks only `hurtTime`, sim.js:732).

- **Rolling identity:** good — defense is steering. But it never *uses* the ball's defining properties (mass, momentum); a hovercraft would defend identically.
- **Controller:** excellent — zero extra inputs.
- **Fit with hit rules:** trivially compatible; it is the hit rules.
- **Weakness:** no mastery ceiling, no defensive expression to feed the "defending well should feed the rolling and scavenging fantasy" hypothesis (CONFLICT-AND-COMBAT.md:9), nothing for enemies to escalate against.

### Model B — timed brace/deflect on the ball

A held scrap guard with a raise-near-impact reward, as sketched in CONFLICT-AND-COMBAT.md:108–110 (Elden Ring / Sekiro references at :122).

- **Rolling identity:** poor–mixed. A guard is a *stopping* verb grafted onto a momentum character. The brief itself flags the core problem: "Guard direction should be visibly understandable even as the shell spins" (CONFLICT-AND-COMBAT.md:110) — an irregular tumbling scrap mass has no stable face to read a guard arc from.
- **Controller:** costs a held button plus a direction while the player already holds move, aim, brake, and charge (four concurrent channels in the implemented gamepad map, FIRST-BUILD-PLAYGUIDE.md:25).
- **Fit with hit rules:** awkward. Hits are capsule-vs-circle with one strike per attack (sim.js:497–505); a directional guard needs contact *normals* and per-frame facing, none of which exists, and a timing window fights the fixed 1/120 step (sim.js:50) less than it fights readability.
- **Weakness:** imports a soulslike rhythm the pillars never asked for; the confirmed appeal is rolling/bumping, not stance play.

### Model C — momentum as the defense (speed/mass answers the attack)

The ball's velocity and accumulated mass *are* the defensive stat. Crossing a committed stroke fast enough turns a hit into a physical deflect — sparks, a chip of damage, and you keep rolling out the far side.

- **Rolling identity:** best of the three — the defensive verb is "roll harder/heavier," and mass collected by playing the core loop directly buys defense.
- **Controller:** zero new inputs. The threshold is only reachable via the existing burst (19 u/s vs 7.4 max roll, sim.js:297, 323), so Space/A already *is* the commit button; timing skill lives in when and along what line you burst.
- **Fit with hit rules:** minimal extension — one branch inside the existing segment-contact check (sim.js:497–505), reusing `dashTime`, speed, and radius the sim already tracks.

### Recommendation: Model C — "Roll-Through" momentum deflect (single recommendation)

**Proposal spec:**

- **Inputs:** none new. Burst (Space / gamepad A, FIRST-BUILD-PLAYGUIDE.md:17, 25) with a movement direction, exactly as implemented (sim.js:291–299).
- **Rule:** at the moment a hazard capsule contacts the player (the existing check at sim.js:497–500), if player speed ≥ 9.5 u/s (reachable only by burst, downhill, or items — max roll is 7.4, sim.js:323) **and** the attack is not `heavy`-flagged: the hit becomes a **deflect** — damage reduced to 30% of the attack's value, hurt protection shortened to 0.35 s instead of 1.05 s (sim.js:737), no control loss, `enemy.struck` still set so the stroke is spent (sim.js:502). Deflecting grants 1 ult pip (§5). Chip damage still uses the Brace reduction (sim.js:734).
- **Timings:** burst gives a 0.24 s ≥-threshold window (sim.js:299) against active phases of 0.48–0.8 s (sim.js:17, 29, 43) — you can cover roughly a third to half of an active window, so the read is "burst *through* the blade as it arrives," not "hold a button."
- **Failure states:** (1) speed < 9.5 at contact → full damage, full 1.05 s stagger, exactly today's rule. (2) `heavy` attacks (Pruner sweep, offcuts, boss hammer class) cannot be deflected — full damage regardless of speed. (3) Clamp-family grabs (Clampcart, Reelrat — ENEMY-TAXONOMY.md:97, 100) *specifically punish* roll-through: bursting across their active jaws is the grab trigger; the correct answer is spacing or hitting the coupling. (4) Deflect chips accumulate: at 30% chip, three deflects in ten seconds ≈ one full worker hit (17–20 damage, sim.js:19, 32), so it is never free tanking — enemies keep their fighting chance.
- **How enemies telegraph against it:** two visual grades on the committed tool, consistent with "color alone should not encode the answer" (CONFLICT-AND-COMBAT.md:120): *gapped/segmented* stroke rendering + light rattle = deflectable; *solid, ground-coupled* rendering + heavy thud cue = must be spaced (heavy flag). Grab-family tells are open jaws oriented across your lane — the geometry itself says "crossing is the trap." Elite escalation gets a real axis: a veteran can upgrade one attack from deflectable to heavy with a visible brace, teaching the change per CONFLICT-AND-COMBAT.md:120.
- **Why not A or B:** A stays as the floor (it is untouched — every attack still has a pure-spacing answer, satisfying CONFLICT-AND-COMBAT.md:106), and B is rejected, not deferred: it costs an input channel, fights the spinning-shell readability problem the brief already flagged, and spends its mastery budget on a rhythm that isn't rolling. Model C is strictly additive to the implemented sim and makes mass/speed — the things the collecting loop produces — the defensive currency, which is what §2 needs.

---

## 2. Mass as the core combat currency

**Implemented base being extended, not replaced:** radius `1 → 1.65` cap via `min(1.65, 1 + scrap·0.022 + shear·0.045 + brace·0.045)` (sim.js:778–781); radius is the hitbox against strokes and offcuts (sim.js:497–500, 575–576); the clearance contract already plans arenas around the largest normal envelope D (ORCHARD-ENCOUNTER-STUDY.md:47–49). Everything below is **proposal**, with `m = (radius − 1) / 0.65` in [0,1].

**The four-way trade (sketch numbers):**

| Axis | Implemented today | Proposed mass scaling | Effect at m = 1 |
| --- | --- | --- | --- |
| Ram damage | 23 + min(shear,3)·9 (sim.js:612) | × (0.75 + 0.5·m) | 28.75 base; 60 on a 2.1× counter; 78 with a prime (2.1·1.3, sim.js:681) |
| Steering | accel 25 + brace·4 (sim.js:329) | 25 − 7·m (+ brace·4) | 18 — heavier, drifting turns; top speed 7.4 unchanged |
| Burst | cooldown max(0.85, 1.45 − brace·0.22) (sim.js:300) | + 0.15·m | fewer deflect/counter windows per fight |
| Hitbox | radius = collision radius (sim.js:499) | unchanged — already the cost | 1.65 vs 1.0: strokes 0.65–1.25 wide (sim.js:16, 28, 41) become much harder to thread |
| Deflect chip (§1) | — | 30% − 10%·m | mass is armor *when rolling through*: 20% chip at full mass |

So a fat ball is a battering ram that deflects cheaply but can't dodge; a lean ball threads strokes and bursts often but hits soft. Collecting mid-fight is now a combat decision, not just score.

**Moments a player deliberately sheds or spends mass:**

1. **Shed Vent (deliberate shed):** hold Brake + press Burst → eject 4 scrap (−0.088 radius), instantly refund the burst cooldown, and scatter the chunks 3–5 u along facing for 5 contact damage each to light enemies. Chunks stay collectible for 8 s — and Scooplet-family collectors contest them (ENEMY-TAXONOMY.md:49; CONFLICT-AND-COMBAT.md:34), so shedding *creates* a contested-resource beat. Use it when a volley is incoming (smaller hitbox), when you need a deflect *now*, or to bait a collector into a kill lane.
2. **Deploy spend:** quick-deploy devices (§3) cost 3 scrap of mass each. This answers open publisher question 2 (DISCOVERY.md:193) in line with the coordinator's own lean: spend *scrap only*, never earned Shear/Brace parts (DISCOVERY.md:94), so building never feels like losing progression — it feels like converting bulk into presence.
3. **Ultimate conversion:** the grapple ult already proposes gathering a temporary scrap mass and slingshotting it (DISCOVERY.md:104); generalize — each class ult may consume up to 6 scrap for a scaled payoff, making "am I fat enough to ult big?" a lean-forward threshold (§5).
4. **Involuntary crumb, never confiscation:** a heavy (undeflected) hit knocks 1 scrap loose to the floor, re-collectible; earned Shear/Brace parts are never dropped, honoring "enemies never confiscate an already-earned inventory part" (ORCHARD-ENCOUNTER-STUDY.md:68) and taxonomy rule "collected body parts remain earned" (ENEMY-TAXONOMY.md:24).

**Why this preserves the pillar:** rolling over scrap mid-dodge is now simultaneously healing your deflect economy, loading your ram, and fattening your hitbox — collecting *is* the tactical layer, which is the confirmed central appeal (DISCOVERY.md:15). The 1.65 cap and route clearances stand untouched.

---

## 3. Class kit skeletons

Constraints honored: low-cooldown abilities + class-specific ult charging confirmed (DISCOVERY.md:31); quick tactical deployment while moving, no build screens (DISCOVERY.md:25, 96); each row extends the DISCOVERY infrastructure table (DISCOVERY.md:85–91), the ult table (DISCOVERY.md:100–108), and the class-advantage table (CONFLICT-AND-COMBAT.md:144–150) without contradiction. Advantages, not keys (CONFLICT-AND-COMBAT.md:151). Aimed skill shots per Andrew's Mom's Knife/Brimstone taste (DISCOVERY.md:21). All **proposal**; numbers are tuning sketches on the implemented baseline (charge 1.1 s, shot 10+32·charge, burst economy — sim.js:319, 673, 300).

### Grapple traversal — "the redirector"

- **Signature aimed attack — Lash Hook:** charge-release skill shot (same 1.1 s charge input as the implemented pulse) that embeds in an enemy or anchor point up to 20 u. Release near full charge: yank yourself to it *or* (if lighter than you — mass check from §2) yank it into your travel line for a collision. A moving-target hook is the class's Mom's-Knife-grade skill shot.
- **Low-cooldown — Winch Yank (1.2 s):** short tug on the current anchor; interrupts a light enemy's windup step or corrects your own trajectory mid-burst.
- **Ult charge:** pips from successful displacements — enemies pulled into other enemies/hazards, swing-attacks, and contested-salvage steals (extends CONFLICT-AND-COMBAT.md:146 verbatim: "useful displacement, successful trajectory attacks and contested salvage").
- **Ult — Scrap Comet:** gather up to 6 scrap into a temporary over-mass shell, pick a slingshot line, release (extends DISCOVERY.md:104). Mass spent per §2.
- **Quick-deploy — Winch Mast (3 scrap):** the DISCOVERY.md:87 mast, deployed on the move with a flick; intermittently drags light enemies off a lane; swinging from it winds a stronger pull.
- **Transformative item — Anchor Heart:** your hook no longer pulls you or it — it pulls *everything else*: the embedded point becomes a 6 u gravity winch for 3 s, reeling loose scrap, offcuts, and light enemies into one collision pile. Brimstone-grade rewrite of the signature without changing its input.

### Hover mortar — "the vertical answer"

- **Signature aimed attack — Lofted Shell:** charge sets range along the aim line with a visible landing ring (the committed-telegraph grammar, mirrored onto the player); 0.9 s flight; big splash, weak direct. Skill expression is leading targets the way the Pruner's offcut leads *you* (sim.js:513–524).
- **Low-cooldown — Hop-Jet (1.4 s):** a 0.5 s hover arc ~4 u forward. It is this class's *alternative* defensive answer: it crosses ground strokes the way a deflect crosses blades, but heavy attacks and grabs track the landing — announced by their tells — so it obeys "a burst must not allow the player to remain safely inside a sustained hazard" (CONFLICT-AND-COMBAT.md:106).
- **Ult charge:** pips from shells that land on ≥2 enemies or on a designated weak point, and from nest volleys the player designated mid-hop (extends DISCOVERY.md:105 and CONFLICT-AND-COMBAT.md:147).
- **Ult — Skydeck:** brief flying-artillery platform (DISCOVERY.md:105); optional scrap spend adds shells.
- **Quick-deploy — Mortar Nest (3 scrap):** DISCOVERY.md:88 nest; an airborne designation redirects its next volley; keeps firing unattended.
- **Transformative item — Cluster Womb:** shells split at apex into 5 bomblets that inherit your on-hit effects (primes, §5 chains). With Anchor-style items in the pool this is the Isaac combinatorial explosion Andrew named (DISCOVERY.md:19–21).

### Cyborg laser — "the precision line"

- **Signature aimed attack — Coherence Beam:** the implemented charge pulse (10 + 32·charge, sim.js:673) matured: at full 1.1 s charge it becomes a piercing line through everything on the ray (extends the implemented 27 u ray select at sim.js:642–656 from first-hit to pierce). Weak-point counters at 2.1× (sim.js:681) reward line-ups through the exposed housing.
- **Low-cooldown — Refraction Flick (1.0 s):** instant short beam that bends once off the nearest deployed prism or shiny loosened plate — the answer to a directional shield (CONFLICT-AND-COMBAT.md:130, 148).
- **Ult charge:** pips from multi-enemy pierces, weak-point hits, and redirected prism shots (extends DISCOVERY.md:106).
- **Ult — Foundry Cutter:** sustained cutting beam routed through the deployed prism network (DISCOVERY.md:106).
- **Quick-deploy — Prism Sentry (3 scrap):** DISCOVERY.md:89; covers a corridor; your charged shot through it splits.
- **Transformative item — Open Furnace:** charge no longer releases — it *holds*: a sweeping Brimstone-style column you steer while braking, at the cost of movement speed while firing. Directly the Brimstone fantasy Andrew cited (DISCOVERY.md:21), gated behind a run drop, not the default.

### Lightning wizard — "the network"

- **Signature aimed attack — Arc Lance:** a fast aimed bolt; on hit it chains to the nearest primed enemy, conductor, or loosened metal part within 6 u, up to 3 jumps (extends CONFLICT-AND-COMBAT.md:149 "use a loosened conductive part or primed enemy to extend a chain"). The skill shot is picking the *entry point* that unlocks the longest chain.
- **Low-cooldown — Capacitor Trail (1.3 s):** your next burst leaves a 4 u spark trail for 2 s; enemies crossing it are primed (the implemented 1.3× prime state, sim.js:681, 824–826, generalized from the companion to a class verb). Rolling *is* casting.
- **Ult charge:** pips from 3+ jump chains and discharges routed through deployed rods (extends DISCOVERY.md:107).
- **Ult — Ride the Lightning:** teleport-hop between storm rods, each arrival pulsing the network (DISCOVERY.md:107).
- **Quick-deploy — Storm Rod pair (3 scrap):** DISCOVERY.md:90; rods periodically arc across their gap; rolling past deposits charge.
- **Transformative item — Ground Loop:** your entire shell becomes a live conductor — every body-contact *bump* (the damage-free pushout at sim.js:621–630) discharges a mini-chain. This is the flagship "rolling and bumping become the weapon" item: Katamari contact, Isaac transformation, zero new inputs.

---

## 4. Enemy counterplay grammar — the mandatory fill-in table

Derived from the implemented Snipcart/Spreadleg/Pruner rules (sim.js and FIRST-BUILD-PLAYGUIDE.md:36–47) and the taxonomy family rhythms (ENEMY-TAXONOMY.md:45, 92, 139). **Proposal:** no enemy is admitted to a build until every cell is filled; "n/a" requires a written justification. The three implemented enemies are the exemplar rows; the fourth row shows the template absorbing a taxonomy-only enemy.

| Field | Definition / rule | Snipcart (implemented) | Spreadleg (implemented) | Pruner arm (implemented) | Brakebogie (proposal, ENEMY-TAXONOMY.md:99) |
| --- | --- | --- | --- | --- | --- |
| **Telegraph** | Visible windup ≥ ~1 s; full stroke previewed; sound + shape, not color alone (CONFLICT-AND-COMBAT.md:120) | 1.15 s windup, jaws spread (sim.js:17, 96); 17-sample stroke preview (sim.js:488–492) | 1.3 s, feet turn outward (sim.js:29) | 1.75 s sweep, or announced offcut path (sim.js:42, 450–466) | Plates shift + route flag moves before brake release |
| **Commitment** | Direction/position lock at windup start; tool follows declared motion, never re-aims | yaw locked in `_transition` (sim.js:365) | same | same; offcut flies the previewed line at 9 u/s (sim.js:536–537) | committed travel to the flagged stop; no mid-run steering |
| **Locked geometry** | Exact damaging capsules, and the §1 deflect grade (deflectable / heavy / grab) | inward arcs, width 0.65, reach 3.11 (sim.js:14–16, 94–103) — *deflectable* | outward foot arcs, width 0.94 (sim.js:27–28, 89–93) — *deflectable* | sweep width 1.25, reach 6.51 (sim.js:40–41); offcut r 0.65, 18 dmg (sim.js:578) — *heavy* | its own hull on rails — *heavy*, but only on the marked line |
| **Recovery window** | Exposed interval ≥ active duration; announced ("Housing exposed", sim.js:377–381) | 1.85 s (sim.js:18) | 2.0 s (sim.js:31) | 2.7 s (sim.js:44) | braked at the stop, 2.2 s |
| **Weak point** | Reachable at max radius 1.65; side offset today (sim.js:438–440); shot ≤0.9 across, ram <r+1.9 (sim.js:611, 672) | right-side housing (PLAYGUIDE:37) | ankle side | arm housing | reachable stack latch (drops a ballast plate, ENEMY-TAXONOMY.md:99) |
| **Counter reward** | 2.1× (sim.js:681) + a physical drop once per attack cycle (sim.js:689–695) | scrap | scrap | scrap + repair heart (sim.js:693–694) | ballast plate = bank surface + collectible mass |
| **Contested resource** | What the enemy and player both want; must exist per family rule "contest loose salvage" (ENEMY-TAXONOMY.md:24) | drops it feeds on near lanes | the lane itself | offcuts leave no pickups (PLAYGUIDE:47) — the contest is terrain | the cargo it hauls; intercept vs. let pass |

**Admission checks (proposal):** every attack carries exactly one deflect grade, taught before its family's miniboss; every heavy attack must have a pure-spacing answer (Model A floor, CONFLICT-AND-COMBAT.md:106); important protection keeps two class-independent answers (ENEMY-TAXONOMY.md:19); the weak point must be reachable by ground route at radius 1.65 (ORCHARD-ENCOUNTER-STUDY.md:47–51).

---

## 5. Anticipation beats — what makes the player lean forward

Five mechanisms, each already rooted in an implemented or confirmed system, chained deliberately:

1. **The announced recovery** (implemented): "Housing exposed" fires as an event (sim.js:377–381) and the 2.1× + guaranteed drop (sim.js:681, 689–695) make every enemy attack a *promise*. The lean-forward is during the enemy's windup: you are already plotting the counter route.
2. **Primes** (implemented seed): the companion's 3 s, 1.3× prime (sim.js:824–826, 681) generalizes into class verbs (Capacitor Trail, §3). Because counter and prime stack in code today (2.1 × 1.3 = 2.73×, sim.js:681), a primed housing counter is the game's natural "big number" — a visible mark with a timer is a fuse the player races.
3. **Ult pips with audible thresholds** (confirmed direction, DISCOVERY.md:31): charge only from class-useful actions (§3 rules; DISCOVERY.md:102–107), announced at 50% and 100% with a class-voiced cue. "One more chain and I have it" is the mid-fight hook; deflects (§1) feed a pip so defense charges offense.
4. **Announced projectiles that become ammo** (extends implemented offcuts): the offcut already telegraphs a straight lane and keeps rolling after release (sim.js:450–466, 526–539; PLAYGUIDE:40). Proposal: a full-speed *ram* (not deflect — offcuts stay heavy) on an offcut redirects it along your exit line for 25 damage to the first machine hit. The toss stops being pure threat and becomes a delivery.
5. **Mass thresholds** (§2): the shed/spend decisions put a resource meter *on the player's own body* — "vent now and dodge clean, or stay fat for the counter-ram?" is a lean-forward every time a windup starts.

**The chain across systems:** trail-prime an enemy (2) → its windup starts, you read the deflect grade (§1) → burst-deflect through the stroke, gaining a pip (3) → the deflect deposits you at the exposed housing for a primed counter-ram at 2.73× (1) → the counter drops scrap → collecting it on the exit line raises mass for the next ram (5) → the Pruner's offcut arrives and you ram it back down the lane (4). Every link is one of the four confirmed pillars doing double duty.

---

## 6. First 90 seconds of a mid-game fight (written playthrough)

**Proposal.** Foundry siding, mid-expedition (stage 3 of a 30–45 min run, DISCOVERY.md:33). Lightning wizard, radius 1.42 (m ≈ 0.65), one Shear part, one Brace part. Opposition per taxonomy: Brakebogie, Bellhanger, Clampcart (ENEMY-TAXONOMY.md:98–100), Reelrat arriving late. Numbers reference §1–§3 and the implemented baseline.

- **0–8 s — read the room.** Brakebogie's plates shift and a route flag swings: committed travel telegraph. Player rolls a collection line through four loose scrap (radius ticks toward 1.47; per sim.js:778 each scrap is +0.022) *because* mass is deflect armor now — collecting is the pre-fight buff.
- **8–14 s — first deploy while moving.** Flick-deploys the Storm Rod pair (−3 scrap, §2) across the siding bend the Bogie must take — quick deployment mid-roll, no screen (DISCOVERY.md:25). Radius drops back; steering lightens (accel back up, §2 table).
- **14–22 s — the interception.** Bogie commits down the flagged line (heavy grade — solid glow, §1). Player does NOT roll through; spaces beside the rail (Model A floor), fires Arc Lance into it as it crosses the rod gap: chain jumps Bogie → rod → rod, priming it. Ult pip 1.
- **22–30 s — Bellhanger winds up.** Rear weight shifts, cradle shadow sweeps the apron (arc telegraph, ENEMY-TAXONOMY.md:98). Its cradle stroke shimmers *gapped* — deflectable. Player bursts through the arc at 19 u/s: deflect, 30%−6.5% chip (~5 damage at m 0.65), 0.35 s protection, pip 2 — and exits exactly at the planted frame's recovery side.
- **30–37 s — primed counter.** "Housing exposed." Counter-ram the tilt latch: 23 + 9 (shear) = 32, × 2.1 counter × 1.3 prime ≈ **87** (multipliers implemented, sim.js:612, 681). Scrap + the Swing Yoke component drop; collecting them on the exit line refills mass to 1.45.
- **37–50 s — the contested steal.** Clampcart marks the Storm Rods and begins its ratchet closure (capture telegraph, ENEMY-TAXONOMY.md:100). Decision fork: finish Bellhanger or save the rods. Player sheds — Brake + Burst vents 4 scrap toward the Clampcart's lane (Shed Vent, §2): cooldown refunds instantly, chunks pepper the jaws for 20, and the *bait* pulls a newly-arrived Scooplet off the wall toward the loose chunks. Two problems now share one lane.
- **50–62 s — grab discipline.** Clampcart's jaws face across the shortest route to the rods — the geometry says crossing is the trap (§1 failure state 3). Player circles wide (spacing, not deflect), Refl— no, wrong class — Arc Lances the exposed hinge during its closure knock: interrupt, device released, pip 3, 50% ult cue plays.
- **62–75 s — Reelrat line.** A snare line establishes toward the player (line telegraph, ENEMY-TAXONOMY.md:97). Rolls across the cast before closure, through the Capacitor Trail it just laid — Reelrat crosses the trail and primes itself. Lance entry through Reelrat chains to the Scooplet on the scrap pile: two-jump chain, pip 4 — **100% ult**.
- **75–90 s — spend everything.** Player rides the lightning between the recovered rods: first hop pulses the network through the primed Reelrat (kill), second hop lands the player at the Clampcart's flank mid-retreat for a counter-ram finish. Fight ends with the player physically fatter than it began, one new component fitted, and the Bogie's dropped ballast plate now a bank for the next encounter — defense fed the rolling and scavenging fantasy, which was the design hypothesis to satisfy (CONFLICT-AND-COMBAT.md:9).

Decision density: ~11 discrete reads/choices in 90 s, every one resolvable through roll, burst, aim, or a one-button deploy — no input the orchard build doesn't already bind (FIRST-BUILD-PLAYGUIDE.md:12–25).

---

## 7. Evidence limits

Implemented values are cited to `src/orchard/simulation.js` and `docs/FIRST-BUILD-PLAYGUIDE.md` as read this session; the playguide's prose matches the code at every point I cross-checked (multiplier 2.1, offcut 9 u/s / 0.65 r / 18 dmg / 3.5 s, radius cap 1.65, buddy 7 dmg / 3 s prime / 2.5 s cooldown — PLAYGUIDE:44, 47, 61, 63 vs sim.js:681, 536–578, 778–781, 819–826). Everything labeled proposal is paper design: no fun, timing, balance, or controller claim is verified, matching the standing evidence posture (CONFLICT-AND-COMBAT.md:171). The single highest-risk proposal is the deflect chip economy (§1) — it needs the Sluiceback basin experiment (CONFLICT-AND-COMBAT.md:177) extended with one deflectable and one heavy attack before any other system builds on it. Inference, uncited: I judged Model B's readability cost from the brief's own flag at CONFLICT-AND-COMBAT.md:110 plus the input inventory; no controller test exists either way.
