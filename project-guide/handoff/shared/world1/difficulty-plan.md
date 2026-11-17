# World 1 difficulty plan (architect, read-only, 10 Nov 2026)

Read at 75099fa70. Evidence level 2 (file and line reads; nothing run). Numbers are the last recorded reads on waves 31 and 32; wave 34 band tables did not exist yet.

Terms: a cell is one thing the band harness measures (`w1` dam Warden fight, `w2` flume Warden fight, `park1`/`park2` reaching each Warden). A band is a bot skill level (Novice, Learner attempt 1 or 5, Expert). A fight cap is a run stopped by a time limit: not a win, not a death. Cruise is the ball's tuned rolling speed, 14 m/s (`src/movement/tuning.gd:7`).

## Is World 1 hard enough for Andrew's direction? No.
| Cell | Measured | Target |
|---|---|---|
| Dam Warden, Novice wins | 42% | harness target <= 15%; the recorded ceiling was raised to match (ruling bk) |
| Dam Warden, Learner attempt 5 | 83% | >= 60% |
| Dam Warden, Expert | 100%, fight median 46 s | >= 85% |
| Park reach, Novice | 100% | <= 50%, waived |
| HARD rungs 1 to 5, Expert | 100 / 100 / 96 / 88 / 56% | rung 5 about 50% |
Sources: `project-guide/handoff/ROADMAP.md:13`, `scripts/world1-bands.rows.json:358-362`, `DECISIONS.md:178-182,229,351`.

Biggest gap: no World 1 enemy threatens a ball that keeps rolling. The only mobile enemy is the chaser at 4.8 m/s against a 14 m/s cruise (`src/combat/chaser.gd:16`); every other kind is fixed (`src/combat/roster.gd:182-215`). The Expert "is rarely hit" (`DECISIONS.md:181`). Weak players lose by timeout, not death: 13 deaths and 15 fight caps in 28 Novice non-wins. Losses are a grind, not mistakes punished.

A Novice win is the game failing to stop a weak player, so a higher Novice number means an easier game; above the ceiling is out of band.

## Levers
- Free to tune at base: difficulty clock (`world/director.gd:107-108,251`: +1 tier per 45 s, cap +2 per stage), crowd cap and spawn interval (`:110-114,276-286`), stage pressure rows (`core/park_defs.gd:96-98`), pack lists and elite (`park_defs.gd:54-73,81`), mob hit damage (`challenge_dials.gd:38,87`, dam x1.5), pack pressure A to D (`challenge_dials.gd:92`, `combat/pack_pressure.gd:23-29`, off today), silt boils (`challenge_dials.gd:33,93`, `combat/silt_boil.gd:26-37`), Warden pulse (`challenge_dials.gd:75-82`, `combat/warden.gd:75-78`), Brindle (`challenge_dials.gd:49-58`, `boss/boss_rules.gd`), lock yards (`world/lock_rows.gd:19-27`).
- Frozen by ruling: enemy health (ruling al), attacker budget and 0.2 s warning gap (`combat/attack_budget.gd:32-36`), pilot regen at base (6 hp/s after 5 s, `core/run_state.gd:22-23,304-305`; pilot dials are ladder-only, DECISIONS.md:174), the one-shot guard (19 Oct), scrap armour (ruling ce, revisit after the sitting).

## Enemies
- chaser: too easy to kite (0.34 of cruise, leads only with pack dial A). Best carrier for pressure.
- lobber: right shape (ring placed ahead on your line; a turn or jump beats it). Shells ignore terrain.
- mag trapper, jolt layer, ramp flipper, boom tender: punish a slow ball, never a fast one. Keep.
- hooker: the model anti-ball counter (telegraphed tether, speed or a boost snaps it).
- plated brute, foreman, dispatcher: fine.
- silt boil: built to punish circle-kiting (DECISIONS.md:176). Conflicts with the new direction: re-scope to punish the stall, not the kite.
- Brindle: the model kiting fight (charge at 24 m/s, bait into a wall for a 3 s stun).
- Bosses (Brindle's charge, the gate crane's sweep and drop, the miniboss's slam and charge) aimed at where the ball was at the commit, so a ball that kept rolling was never hit (Andrew: "a pushover"). They now lead a ball that has held a line for a second at 85% of cruise or more, scaled by the tell (none at 0.6 s or less), and a turning ball not at all (`PackPressure.lead_aim`; `tests/boss_lead_line_test.gd` for the per-attack numbers; BACKLOG MG-11 for the band read still owed).
- Reject at base: lowering the one-shot guard (does not reward movement); churned silt (pack D), which drags the ball below fast tier.
- Comps rows worth borrowing (`design-v3/research/comps/difficulty/SUMMARY.md`): row 14 raise aggression and elite share, not count; row 15 attack interval x0.85 to 0.7; enemy speed x1.15 (RoR2 uses x1.4); row 5 no step ever shortens a tell; Roboquest players run about 2.35 times the median enemy (chaser is at 2.9 times today).

## Ranked units (proof: paired harness `scripts/challenge/run.mjs --only=w1,w2,brindle`, same seeds each arm)
| # | Unit | Player sees | Files | Size | Proof | Before the sitting? |
|---|---|---|---|---|---|---|
| D8 | Measurement first: a whole-World-1 clear cell (`w1clear`) and fairness fields in the bot record | nothing (tool layer) | `scripts/challenge/lib.mjs`, `run.mjs`, `tools/bot_driver.gd` (`_on_player_hit` :1182, `_threats` :4043), `tools/bot_plants.gd` | M | tool tests | yes, do first |
| D1 | Chasers steer for where you are going (pack dial A at 0.5, stages 1-2) | a straight escape gets lunged; a curve slips it | `challenge_dials.gd` defaults | S | 48 seeds an arm on w1, w2; gate 2 quick | yes if Expert holds >= 85% |
| D2 | Chasers between walk and cruise (4.8 to about 9 m/s) | stop and they catch you; keep rolling and they never do | new `mobs.chaser_speed_by_stage` dial, `chaser.gd` | S | 48 seeds an arm + stop-vs-move check | yes (coordinator call: speed joins the allowed levers) |
| D3 | A third clock tier at 135 s | staying longer means more crowd and lobbers | `director.gd`, `build/run_clock.gd` | S | 24 seeds an arm | yes if the threat announcement fires |
| D4 | Shells stop on landforms; lobbers lead more in the open (lead 0.5 to 0.75, share +0.05 per tier) | terrain is cover worth kiting through; open straight lines hurt more | `lobber.gd`, `projectile.gd` | M | one arm with both; gate 2 (terrain beats orbit); 48 seeds | yes by wave 37 |
| D5 | Boils punish the stall, not the kite | wide curves round a pack are free; tight orbits still boil | `silt_boil.gd` | M | gate 1 orbit still 8 of 8 dead; new kite arm | pair with D1 or D2 |
| D6 | Warden pulse at rung 2 values on base (damage x1.3, cycle x0.85) | the Warden demands in-and-out timing | `challenge_dials.gd` | S | 24 seeds + deaths-share check | yes |
| D7 | Regen only while rolling at cruise or above | camping to heal stops working; motion heals | `run_state.gd:304` | M | 48 seeds an arm | needs Andrew: pilot dials at base are ruled out today |

## Targets and fairness checks (World 1, default difficulty)
| Check | Pass line | Seeds | Planted failing case |
|---|---|---|---|
| Dam Warden, Novice wins | <= 20% | 48 | today's head (42%) |
| Flume Warden, Novice wins | <= 15% | 24 | pulse x0.5 tune |
| Dam Warden, Learner attempt 5 | 30 to 60% | 48 | today's head (83%) |
| Expert on each fight cell | >= 85% | 48 | rung 5 dials (56%) |
| Whole World 1 clear, Expert, one attempt | >= 70% | 48 | rung 5 dials |
| Whole World 1 clear, Novice | <= 5% | 24 | mob damage x0.5 |
| Novice non-wins that are deaths | >= 60% | same runs | today's probe (46%) |
| Expert fight time | <= base +10% | same runs | spawns x0.8 |
| F1 telegraph share | >= 95% of hull damage and 100% of killing hits inside a hazard the bot had seen >= 0.6 s | 24 | `--plant=rut=1` (untelegraphed drain) |
| F2 stop against move | hull lost per minute below cruise / at or above cruise >= 2.0 | 24 | a plant that taxes fast balls |
| F3 first hit | median first contact to first hit >= 3 s (Learner 1) | 24 | a plant that spawns with no arrival ring |
| F4 momentum | dead stops per minute <= base +10% (`core/run_log.gd:37`) | 24 | not built |
Bots cannot tell: fun, whether a death felt fair, human kiting (no bot kites with skill; the Expert dodges by reading tells).

## Arrivals on the grid (INTEGRATION.md:165-196)
No longer blocked by the Novice ceiling. But p = 0.39 means no measured effect, and its lean was toward fight caps (15 to 20) with deaths flat: a slower fight, not a harder one. Admit at 96 seeds an arm when Expert does not fall by more than 1 seed, Expert fight time does not rise more than 2 s, and the death share of Novice non-wins does not fall.

## Where the architect disagreed with the coordinator's reading
1. "The Novice ceiling may drop" should be a target that must drop, counted through deaths, not caps.
2. "Expert must still win" should be a hard floor: >= 85% per fight cell and a whole-world floor.
3. The silt boils exist to punish kiting; that premise is reversed and needs re-scoping.
4. Regen and enemy health are ruled out at base; both need Andrew.

## Draft ruling
Difficulty rises through pressure on a ball that slows, stops or rolls a predictable line, never on a ball that keeps rolling and turning. Enemies may chase faster than walking pace and slower than cruise, lead your line, and hold you only with a telegraphed hold that speed, a jump or a bite breaks. Each world's default leaves the Novice bot winning at most one Warden fight in five, the practised Learner one or two in two, and the Expert at least 85% of fights and 70% of whole-world clears. Losses come mostly from deaths with a tell on screen, not from timeouts. Anything that eases play ships only with a matching pressure measured in the same arm; the stall, not the kite, is what the ground punishes.

## Not checked
Whether enemies path around terrain; the attacker budget's World 1 value; the Brindle attack table beyond constants; the comps files beyond the difficulty summary; whether `bot_plants.gd` implements `rut` as its README says.
