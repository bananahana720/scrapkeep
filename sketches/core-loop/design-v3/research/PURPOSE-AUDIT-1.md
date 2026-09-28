# Purpose audit 1: every world-one system, and scrap as size

Codex (gpt-6-astra, high), read-only, 2026-09-28, job task-mulp911v-yt4lih, launched from v3 aa1b0e2 before the threshold, durability, mass-as-momentum and cogs rulings (v3 14336ab to f436f3f); read its Part 2 against those. Verbatim report follows.

**Scrap already has a purpose, but its two roles do not form one coherent decision.** Collecting it increases both spending money and physical power; spending the money leaves that physical power intact. The shop therefore asks “which upgrade should I buy?”, while the ball asks “how much have I collected?”. Those decisions barely meet. That separation is explicit in `src/core/run_state.gd:98–121` and `:177–181`.

**My recommendation is to make scrap the ball’s recoverable armour reserve, retain hull health underneath, and separate three kinds of growth:**

- **Scrap:** how much temporary power and protection you are carrying.
- **Parts and the kit tree:** how you play.
- **Cores:** what optional danger you undertook before confronting the Warden.

That is a design inference, not a claim that this arrangement is already implemented.

I reviewed the requested documents and implementation in [the v3 integration sketch](/home/andrew/Projects/scrapkeep-worktrees/core-loop-v3/sketches/core-loop). **All paths below are relative to that directory.** This was static, read-only inspection; I did not run the game, write files, or test feel.

The branch advanced during the review from `aa1b0e2` to **`b5a7e732dc6c7ba8b6f58b8b2d63195e4917f622`**. The intervening changes were confined to `design-v3/ROADMAP.md`; the reviewed code was unchanged. Those additions settle temporary armour over hull, rolling wear, class hysteresis, and pilot-specific uses of mass. I have incorporated them as design requirements. The two options in Part 2 consequently explore different implementations of that ruling rather than reopening hull replacement.

**Part 1 — Purpose audit**

All scores, costs, overlaps and verdicts below are **design inferences from the cited implementation**, not measured playtest findings. “Planned” rows receive scores for their proposed role and do not count as dimensions already served.

The scoring scale is:

- **0:** no meaningful contribution.
- **1:** supporting or conditional contribution.
- **2:** a strong, repeatable reason for the system to exist.

The dimensions are **S** strategy, **R** risk, **G** gambling, **K** performance and skill, **PB** personal-best mastery, **E** expression and identity, **D** discovery, **F** spectacle and feel, **P** pacing, and **Rec** recovery and resilience. I added recovery because retaining agency after a mistake is central to the scrap proposal.

Gambling means knowingly staking something on uncertainty. Random loot alone does not earn a gambling score. Personal-best mastery means a comparable achievement the player can deliberately improve, rather than simply a system requiring skill.

For readability costs, **low** means a local glyph or one compact reading, **medium** means comparing a few readings or maintaining another objective, and **high** means a choice panel, substantial build knowledge, or several simultaneous meanings. These are estimated attention costs, not measured word-budget compliance.

| # | System | S | R | G | K | PB | E | D | F | P | Rec |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | Scrap wallet | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 0 |
| 2 | Mass/heft and collection | 1 | 1 | 0 | 1 | 0 | 1 | 1 | 2 | 2 | 0 |
| 3 | Heft classes | 1 | 0 | 0 | 0 | 0 | 1 | 1 | 2 | 2 | 0 |
| 4 | Pilots, abilities and charge stockpiles | 2 | 2 | 0 | 2 | 1 | 2 | 2 | 2 | 2 | 1 |
| 5 | Rolling, contact, punch and plating | 2 | 2 | 0 | 2 | 1 | 2 | 2 | 2 | 2 | 1 |
| 6 | Parts, rarity and free picks | 2 | 1 | 0 | 1 | 0 | 2 | 2 | 2 | 2 | 1 |
| 7 | Fabricators | 1 | 1 | 0 | 1 | 0 | 1 | 1 | 1 | 1 | 0 |
| 8 | Moss’s shop | 2 | 1 | 1 | 0 | 0 | 2 | 1 | 1 | 2 | 1 |
| 9 | Moss’s bay and its toys | 1 | 0 | 0 | 1 | 1 | 1 | 1 | 2 | 2 | 2 |
| 10 | Bonus cores and gate tiers | 2 | 2 | 0 | 1 | 0 | 1 | 1 | 2 | 2 | 1 |
| 11 | Risk bets / interactable family 5 | 1 | 2 | 2 | 0 | 0 | 1 | 1 | 2 | 1 | 0 |
| 12 | Evolutions — planned | 2 | 1 | 0 | 0 | 0 | 2 | 2 | 2 | 2 | 0 |
| 13 | Synergies | 2 | 1 | 0 | 1 | 0 | 2 | 2 | 2 | 1 | 0 |
| 14 | Kit tree, world-one tiers | 2 | 1 | 0 | 2 | 1 | 2 | 2 | 2 | 1 | 1 |
| 15 | Travel interactables / family 1 | 2 | 1 | 0 | 2 | 1 | 1 | 2 | 2 | 2 | 1 |
| 16 | Fight interactables / family 2 | 2 | 2 | 0 | 2 | 0 | 1 | 1 | 2 | 2 | 0 |
| 17 | Secrets, caches and vaults / family 3 | 2 | 2 | 0 | 2 | 0 | 1 | 2 | 2 | 1 | 0 |
| 18 | Ally interactables / family 4 — planned | 2 | 1 | 0 | 1 | 0 | 2 | 2 | 1 | 1 | 1 |
| 19 | Participation events | 2 | 2 | 0 | 2 | 1 | 1 | 2 | 2 | 2 | 1 |
| 20 | Terrain hazards and elemental reactions | 2 | 2 | 0 | 2 | 0 | 2 | 2 | 2 | 2 | 1 |
| 21 | Difficulty clock and encounter director | 2 | 2 | 0 | 1 | 0 | 0 | 1 | 1 | 2 | 0 |
| 22 | Drop loop and gun-role alternatives | 2 | 2 | 0 | 2 | 1 | 2 | 2 | 2 | 2 | 1 |
| 23 | Lap loop | 2 | 2 | 0 | 2 | 2 | 1 | 1 | 2 | 2 | 1 |
| 24 | Warden families and opening windows | 2 | 2 | 0 | 2 | 1 | 1 | 2 | 2 | 2 | 1 |
| 25 | Brindle, phase structure and theft | 2 | 2 | 0 | 2 | 1 | 1 | 2 | 2 | 2 | 2 |
| 26 | Hull health, regeneration and defensive parts | 2 | 2 | 0 | 1 | 0 | 1 | 1 | 1 | 2 | 2 |
| 27 | Gentle hot-wired parts — planned | 2 | 2 | 1 | 2 | 0 | 2 | 2 | 2 | 1 | 0 |
| 28 | Codex and discovery rewards | 1 | 0 | 0 | 1 | 1 | 1 | 2 | 1 | 1 | 0 |
| 29 | Par records and challenge modifiers | 1 | 1 | 0 | 2 | 2 | 1 | 0 | 1 | 1 | 0 |
| 30 | Strike, Spare and Turkey feats | 1 | 1 | 0 | 2 | 1 | 1 | 2 | 2 | 1 | 0 |
| 31 | HUD, feedback, music and ceremonies | 0 | 0 | 0 | 1 | 0 | 1 | 1 | 2 | 2 | 0 |
| 32 | Death, checkpoints and quick restart | 1 | 1 | 0 | 1 | 2 | 0 | 0 | 1 | 2 | 2 |

The matrix is not a ranking by total. A small system can earn its place by doing one indispensable job.

**1. Scrap wallet**

**Today:** Pickup raises `scrap` and `mass`; purchase subtracts only `scrap`. The HUD displays the wallet separately. `src/core/run_state.gd:98–103,177–181`; `src/ui/hud.gd:513`.

**Decision:** “Which purchase should I reserve my money for?”

**Costs:** No direct movement interruption; medium readability cost from a persistent number whose relationship to size must be explained.

**Overlap:** Fabricators, shop stock and shop rerolls all use it to mediate build acquisition; free picks provide the same acquisition without this payment.

**Verdict: cut the separate wallet.** Preserve deliberate purchasing, but give the price a physical or build consequence. “No purpose” would overstate the finding: budget allocation is a purpose; it is simply weakly connected to the game’s defining physical system.

**2. Mass/heft and collection**

**Today:** Heft is `1 + mass/450 + 0.2 × part count`. It therefore grows from both scrap and fitted parts. Collection magnet range grows with heft and speed; contact resolution also compares heft against enemy weight. `src/core/run_state.gd:13–15,120–121`; `src/build/scrap_field.gd:11–18,74–84`; `src/movement/contact.gd:18–19`.

**Decision:** “Do I take a longer or more dangerous line to become heavier?”

**Costs:** No menu stop; low readability if mass remains one physical fact, medium when players must reconcile mass, part count and wallet.

**Overlap:** Parts currently increase capability and heft simultaneously; Scrap Armor adds a separate mass-to-health relationship.

**Verdict: protect, then rethink its defensive role.** This is the best place to unite routing, greed, power, survival and visible growth. One current part contributes as much heft as 90 scrap, an arithmetic consequence of the cited formula; removing that contribution requires rebalancing growth, not merely deleting the term.

**3. Heft classes**

**Today:** Five thresholds categorize heft; rising and falling publish different events. Accretion uses mass, parts and class to construct the visible shell. `src/core/run_state.gd:15,124–154`; `src/build/accretion.gd:62–67,87–102`.

**Decision:** “Do I push for the next size threshold before committing?”

**Costs:** No inherent stop in the class calculation; low persistent readability cost, with additional attention at transformations.

**Overlap:** Rarity and evolutions also promise conspicuous growth moments.

**Verdict: protect as the visible summary of scrap.** The latest requested transformation ceremony is planned direction, not something the threshold calculation proves. With continuous wear, use hysteresis and a brief shedding response; do not replay a full ceremony every time a boundary is crossed. `design-v3/ROADMAP.md:147–148,160`.

**4. Pilots, abilities and charge stockpiles**

**Today:** Pilot definitions bind weapon, movement, special and smash identities. Ability slots separately track availability and charges; spending consumes a charge, and grants/refills respect their caps. `src/core/class_def.gd:46–65`; `src/core/ability_state.gd:201–240`.

**Decision:** “Which movement and attack vocabulary do I want, and when do I spend its available charges?”

**Costs:** Player-triggered actions rather than automatic choice stops; medium readability from several ability states and gauges.

**Overlap:** Parts and tree choices also define identity; shop cells and tree operations both modify ability capacity.

**Verdict: protect.** Pilot identity should determine *how* mass becomes useful, while leaving multiple viable identities inside each pilot. Avoid making every pilot’s best answer “be the largest possible ram”.

**5. Rolling, contact, punch and plating**

**Today:** Movement preserves speed above ordinary drive speed rather than simply clamping it away. Contact can reflect normal velocity while retaining tangential motion; combat distinguishes full damage from insufficient punch against plating. `src/movement/ball_rules.gd:66–107`; `src/movement/contact.gd:18–36`; `src/combat/combat.gd:309–346`.

**Decision:** “Which line, speed, impact angle and attack let me pass through this threat rather than rebound from it?”

**Costs:** Physical collisions can reduce or redirect motion; these are encounter consequences, not automatic interface stops. Medium readability: weight, plating, opening and contact response must be distinguishable without arithmetic.

**Overlap:** Drop attacks, cache breaks, Warden openings and bowling feats all apply this vocabulary.

**Verdict: protect.** This is the game’s principal skill system. Other systems should create reasons to use it.

**6. Parts, rarity and free picks**

**Today:** Offers are filtered and rolled from authored/generated parts, with synergy assistance and gate rarity tiers. Gate selection grants a free part; events and vaults provide additional parts through separate paths. `src/build/parts.gd:261–281,300–327,354–368`; `src/build/build.gd:590–615,620–622`.

**Decision:** “Which offered behavior best advances this run’s build?”

**Costs:** Medium to high comparison cost; movement cost depends on delivery, especially ceremonies. Physical reward selection need not itself pause play.

**Overlap:** Fabricators, Moss, tree nodes, synergies and planned evolutions all promise build progression.

**Verdict: protect the choices; merge redundant delivery.** Give each source a job: routine growth, targeted correction, or risky discovery.

The roadmap’s “2.5–3 free picks per minute” is a **design target**, not a measured property of this implementation. The referenced cadence appears in the laps proposal; current gate code opens offers on the `gates` flow state. `design-v3/SYSTEMS-CHAOS.md:412–421`; `src/build/build.gd:600–607`.

**7. Fabricators**

**Today:** They sell a rolled part when the ball crosses the hoop and can afford it; price increases with rarity and total held parts. `src/build/fabricators.gd:17–41,117–140`; `src/build/build.gd:706–711`.

**Decision:** “Do I route through this known offer and spend my budget on it?”

**Costs:** No shopping pause; medium local readability because an at-speed purchase needs the item, price and affordability to be legible.

**Overlap:** Moss sells parts; reward gates present physical part choices.

**Verdict: merge their delivery role with earned part opportunities, pending the sitting.** They are a good physical interface. They do not necessarily need a separate economy. If converted to weight prices, the current automatic purchase-on-crossing becomes a much more consequential interaction and needs explicit consent.

**8. Moss’s shop**

**Today:** Moss provides shelf stock, a heft-locked top offer, paid rerolls, charge cells and sell-back. Pattern parts cannot currently be sold through the fallback removal path. `src/build/shop.gd:142–155,196–265,270–329,438–465`.

**Decision:** “What should I deliberately change about this build before leaving safety?”

**Costs:** An intentional counter stop freezes the player; high but calm-screen readability cost. `src/ui/workshop.gd:221–222,252,381`.

**Overlap:** Fabricators acquire parts; the tree adjusts identity; cells overlap with charge-increasing upgrades.

**Verdict: protect as the place to correct a build; rethink payment.** Give Moss a dependable service that random free picks cannot provide. Retain her character and the heft hook, but avoid turning cores into universal money simply because the wallet is gone.

**9. Moss’s bay and toys**

**Today:** The cradle banks entry speed, and the exit returns at least the relevant banked/current/cruise speed. The bay includes toys and a timed miniature lap. Difficulty timing pauses inside the shop/bay context while stage/par time continues. `src/world/bay.gd:273–344`; `src/world/bay_lap.gd:12–15,38–64`; `src/build/shop.gd:165–166`; `src/build/run_clock.gd:48–54`.

**Decision:** “Do I take a breather, inspect or refit, or preserve my time and leave?”

**Costs:** Entering deliberately changes the movement rhythm; high spatial footprint, low compulsory reading if the counter remains optional.

**Overlap:** Regeneration, menus and post-Warden rewards also create respite.

**Verdict: protect.** It gives the run contrast and makes a voluntary weight melt plausible. Keep its timing semantics clear: safety from escalation and a paused personal-best clock are different benefits.

**10. Bonus cores and gate tiers**

**Today:** Cores raise gate rarity only up to two bonus tiers. In the drop implementation, the opening-window calculation reads the raw core count rather than the gate-tier cap. `src/core/run_state.gd:158–173`; `src/build/parts.gd:261–266`; `src/combat/warden_drop.gd:149–162`.

**Decision:** “Do I undertake another optional challenge for a better reward or an easier opening?”

**Costs:** No direct stop; medium readability because one count has two payoff curves.

**Overlap:** Events, vaults and bets all supply cores; mass and parts also improve combat prospects.

**Verdict: protect the optional-risk role; rethink the payoff explanation, pending the sitting.** Choose a readable world-one cap and make each displayed increment useful. Cores should not become the new wallet.

**11. Risk bets — interactable family 5**

**Today:** The crate stakes all current cores, resolves a seeded 50% outcome, and either adds the staked amount or burns the cores. `src/world/bet_crate.gd:16,55–70,79–103`.

**Decision:** “Do I risk my earned advantage to double it?”

**Costs:** Voluntary interaction; no ball-freeze operation in the bet sequence. Medium local reading: stake, odds and actual outcome must be clear.

**Overlap:** Shop rerolls spend resources on uncertainty; proposed hot-wired parts offer uncertainty about future suitability.

**Verdict: keep one bounded wager, but rethink the stake and payoff, pending the sitting.** At two or more cores, winning adds no gate-tier benefit, although it can still help the current drop window. That makes the offer’s meaning mode-dependent. A wager should display the benefit being gambled, not merely a larger count.

**12. Evolutions — planned**

**Design status:** The proposal consumes ripe copies at a break, preserves heft, requires another part’s tag, and limits evolutions per break/run. The roadmap narrows the candidate set to four. I found no implemented evolution acquisition path in the reviewed build catalogue and reward routes. `design-v3/SYSTEMS-CHAOS.md:15–28`; `design-v3/ROADMAP.md:63–74`; `src/build/parts.gd:159–174`; `src/build/build.gd:600–622`.

**Decision:** “Do I specialize this established behavior into its evolved form?”

**Costs:** Planned calm-break choice and substantial explanatory cost.

**Overlap:** Synergies already recognize combinations; the tree already specializes behavior.

**Verdict: merge its eligibility and explanation with synergy discovery; retain a separate evolution only when it changes the player’s verb.** “Same effect, larger numbers, another name” does not earn another progression ladder. Timing remains **pending the sitting**.

**13. Synergies**

**Today:** Named combinations include pickup arcs, ram shockwaves, mounted arcs and frost-land effects; an unnamed tag combination also exists. Activation checks a shown ingredient and a qualifying different part. `src/build/synergies.gd:36–85,101–109`; effect execution is in `src/build/build.gd:765–846`.

**Decision:** “Do I choose a useful part now or pursue a combination that changes what my actions produce?”

**Costs:** No inherent stop; high learning cost, potentially high effect density.

**Overlap:** Evolutions and hot-wired parts also reshape a build.

**Verdict: protect a small world-one set.** Synergies should reward noticing relationships between things already acquired. Evolutions should then transform a mature behavior, rather than re-awarding that same discovery.

**14. Kit tree — world-one tiers**

**Today:** The implementation supports four depths, with 2/4/8/16 nodes. Checkpoints can open all four picks by the end of stage three, including when the bay is skipped. Pending choices can open during play and apply the workshop hold. `src/core/upgrade_tree.gd:12–29,231–253`; `src/world/world.gd:648–655`; `src/ui/workshop.gd:156–183`.

**Decision:** “Which enduring way of playing this pilot am I committing to?”

**Costs:** Automatic choice interruption is possible; high calm-screen reading and long-term build commitment.

**Overlap:** Parts, synergies and evolutions.

**Verdict: protect early identity choices; reconcile the scope and interruption rules.** The roadmap excludes the 8- and 16-way variations, while the code exposes those depths before Brindle. My proposed reconciliation is to keep the first two branching tiers for world one and make later bay visits about existing-build decisions, not new tree depth. This is a recommendation, not an already accepted rule.

Sable’s early rows already distinguish Cannonball/airborne play from Beachhead/mounted play, with fling, airborne charge, turret reach and mounted protection choices. They do **not by themselves establish** the newly proposed mass-powered rebound fantasy. `src/core/trees/sable.gd:9–21`; `design-v3/ROADMAP.md:149–159`.

**15. Travel — interactable family 1**

**Today:** Travel has its own shape, cue and consent vocabulary; the device records planar speed and delegates the ride to its owner. `src/world/interactables.gd:39–43`; `src/world/travel_device.gd:59–64`.

**Decision:** “Which route or launch will put my speed and position where I need them?”

**Costs:** Player-entered movement redirection; low words, meaningful environmental space.

**Overlap:** Drop lines, lap routes, bay exits and terrain traversal.

**Verdict: protect; exact placement pending the sitting.** This is how the world participates in combat rather than merely connecting encounters.

**16. Fights — interactable family 2**

**Today:** The ambush altar spawns a pack, runs a time limit, and grants a core for clearing it. `src/world/ambush_altar.gd:48–87`.

**Decision:** “Can this build clear the advertised fight cheaply enough to justify the reward?”

**Costs:** Voluntary danger and time; low local prompt, medium attention during the fight.

**Overlap:** Participation events and vault fights.

**Verdict: keep, but merge its reward and consent vocabulary with optional events.** Its unique value is choosing *when* to activate a compact challenge.

**17. Secrets, cracked caches and vaults — interactable family 3**

**Today:** The cracked wall responds to approach speed, sprint or slam; opening the cache exposes part pedestals, and rolling onto one chooses it. Vault rewards separately grant a part and a core. `src/world/cracked_cache.gd:126–175,183–201`; `src/build/build.gd:590–593`.

**Decision:** “Do I investigate this suspicious feature and apply the right movement action to reach its reward?”

**Costs:** Detour and physical collision risk; low words before discovery, medium comparison cost afterward.

**Overlap:** Travel discoveries and optional fights.

**Verdict: protect.** These connect curiosity to physical understanding. Avoid reducing every secret to a differently dressed three-choice shop.

**18. Allies — interactable family 4, planned**

**Observed boundary:** An ally family exists in the interaction vocabulary, including a scrap cost, but the reviewed device factory and stage-one placements contain altar/cache/bet devices rather than a playable ally. `src/world/interactables.gd:54–57,71–77`; `src/world/interact.gd:22–26,45–55`.

**Decision:** Planned: “Which local helper would change how I approach this area?”

**Costs:** Planned voluntary activation; medium readability if the helper needs a role, duration and status indicator.

**Overlap:** Turrets, drones, defensive parts and event rewards.

**Verdict: rethink its distinctive job, then keep one world-one implementation.** A helper that opens a route, redirects danger or retrieves dangerous scrap has a stronger purpose than another automatic damage source. The roadmap asks for this family on every stage; a vocabulary row does not satisfy that requirement. `design-v3/ROADMAP.md:19`.

**19. Participation events**

**Today:** Stampede rewards catching moving scrap opportunities; Surge Run asks for sequential gates; Hold Relay accumulates time within a region. Event participation, progress and rewards are routed through the event director and world. `src/world/scrap_stampede.gd:54–68`; `src/world/surge_run.gd:54–76`; `src/world/hold_relay.gd:8–11,35–55`; `src/world/event_director.gd:191–229`; `src/world/world.gd:370–382`.

**Decision:** “Do I abandon my current route to pursue this temporary objective?”

**Costs:** No choice-screen stop; medium objective and timer footprint. Relay changes the spatial rhythm even though it does not require standing still.

**Overlap:** Altars, secrets, cores and the main loop’s route demands.

**Verdict: protect Stampede and Surge as movement tests; rethink Relay’s contribution, pending the sitting.** Relay earns its place if it creates a moving defence problem. If it merely asks for time spent inside another circle, it crowds the Warden and lap gates.

**20. Terrain hazards and elemental reactions**

**Today:** Event selection includes flood, squall and terrain changes. Elemental rules can freeze water into a surface, electrify water and shatter ice; the field resolves these against actual material providers and creates the effects. `src/world/event_director.gd:60–88`; `src/build/elements.gd:25–33`; `src/build/element_field.gd:103–149`.

**Decision:** “Do I avoid this terrain, exploit it, or change it with my build?”

**Costs:** Physical route changes and hazard consequences; medium to high spatial readability, little necessary text.

**Overlap:** Synergies and travel interactables.

**Verdict: protect a small readable set.** A reaction earns more than a generic damage bonus when it changes a route or creates an opportunity. Keep threatening terrain visually distinguishable from player-created effects.

**21. Difficulty clock and encounter director**

**Today:** Difficulty has two timed tiers at 45-second intervals. The director combines its time tier, encounter spikes and heft-dependent population cap; enemy HP scaling is separately tied to stage threat. `src/build/run_clock.gd:14–18,74–80`; `src/world/director.gd:123–142`.

**Decision:** “Do I cash out my current strength now, or spend more time gathering while pressure rises?”

**Costs:** No direct movement stop; medium persistent attention, especially alongside event, lap and Warden timers.

**Overlap:** Mandatory laps, wear, event deadlines and boss phase minimums all control time.

**Verdict: keep one legible escalation, pending the sitting.** Do not let difficulty growth and scrap wear jointly make every detour feel wrong. Heft-based crowd growth also needs care: becoming stronger should feel useful before it creates more work.

**22. Drop loop and gun roles**

**Today:** A valid drop considers approach history, descent, core contact and speed; damage scales with heft and arrival speed. The “hold” gun role banks damage during openings; “full” permits direct gun damage in the staggered opening. `src/combat/warden_drop.gd:193–244`.

**Decision:** “Which route and arrival will create a worthwhile impact, and how do I use my gun around it?”

**Costs:** No choice-panel stop; significant timing and spatial-reading demand. Impact response redirects the ball. `src/combat/warden_drop.gd:296–325`.

**Overlap:** Ordinary contact combat, travel devices, Warden windows and laps.

**Verdict: protect as a candidate; pending the sitting.** Its special value is making the map an attack. The gun role must support that relationship without leaving a pilot’s chosen identity feeling temporarily disabled.

**23. Lap loop**

**Today:** The course uses ordered route rings and records lap times. Three required laps wake the Warden; later laps strip plating. The mode only activates on maps with loop data. `src/world/lap_course.gd:46–64,86–104`; `src/core/flow.gd:333–356`; `src/core/loop_mode.gd:44–48`.

**Decision:** “Do I improve my route and take another lap to weaken the Warden, or fight now?”

**Costs:** No interface stop, but compulsory laps impose a time requirement before the later choice exists. Medium route/progress footprint.

**Overlap:** Drop approach runs, difficulty pressure and timed traversal events.

**Verdict: rethink the compulsory three-lap opening; pending the sitting.** The optional extra lap has a clear strategic purpose. Mandatory laps must establish enjoyable mastery rather than delay the encounter.

The inspected lab implementation is not evidence that either candidate loop is complete across world one: the map defaults are empty, with the loop population found in Spillway. `src/world/stage_map.gd:43–49`; `src/world/map_spillway.gd:111–114`.

**24. Warden families and opening windows**

**Today:** Family behavior determines openings and responses; guards and habit-driven responses modify the encounter. Reactor pulses distinguish the attack and its resulting opening. `src/combat/warden.gd:268–300,312–358,448–480`.

**Decision:** “Do I commit to this opening now, or reposition for the next one?”

**Costs:** Threat-driven dodges and displacement; high spatial readability demand, which should be carried by the attacker rather than extra HUD prose.

**Overlap:** Drop timing, lap stripping and core-assisted openings.

**Verdict: protect the readable opening; mode-specific tuning pending the sitting.** It is where route preparation, build and execution become one payoff.

**25. Brindle, phase pacing and theft**

**Today:** Brindle gates phase changes on both health floors and minimum phase durations. Crane catches remove mass, distribute it into recoverable trails, and allow shots on a magnet to release what it still holds. `src/boss/boss.gd:207–239,333–429`; `src/boss/boss_rules.gd:10–12,41–51`.

**Decision:** “Do I pursue the boss opening, recover my stolen size, or attack the mechanism holding it?”

**Costs:** Attack-driven movement changes; medium to high spatial reading. Minimum phase durations constrain how quickly extra damage can advance the fight.

**Overlap:** Proposed ordinary armour spills and Warden opening language.

**Verdict: protect theft and recovery; rethink hard phase-time floors for mastery.** Preserve time for a first-time player to read a phase without making a strong replay wait pointlessly.

A useful terminology correction: **the observed theft belongs to Brindle’s cranes**, not the stage Warden opening system. `src/boss/boss.gd:333–341`.

**26. Hull health, regeneration and defensive parts**

**Today:** Base hull is 100, with regeneration after five seconds without damage at six HP per second. Scrap Armor separately grants max HP from mass. Several defensive effects heal back damage after it has already been applied, and cannot rescue a killing blow. `src/core/run_state.gd:8–10,88–95,196–214`; `src/build/items.gd:161–177`; `src/build/item_effects.gd:373–409`.

**Decision:** “Do I maintain pressure or disengage long enough to recover?”

**Costs:** No automatic stop; low bar cost, but defensive-item explanations are medium. Regeneration can encourage a slower route.

**Overlap:** Planned scrap armour, bay respite and defensive abilities.

**Verdict: protect hull as the stable safety net; merge the generic Scrap Armor premise into the core scrap rule.** Retune the item into a specialist modifier. Resolve protection before lethal damage rather than relying on heal-back to imitate armour.

**27. Gentle hot-wired parts — planned**

**Design status:** The requested alpha scope is two or three parts with obvious upside, readable survivable downside and one meaningful forced skip. Bulk penalties are now explicitly opt-in, with inversion through a pilot’s skills a desired pattern. `design-v3/ROADMAP.md:131–137,157–159`.

**Decision:** “Is this powerful tradeoff right for this run, or should I leave it?”

**Costs:** No mandatory stop if delivered through existing choices; high per-item explanation cost, so the set must stay small.

**Overlap:** Tree specialization, evolutions and synergies.

**Verdict: keep two gentle examples.** They should make ordinary behaviors meaningfully different, not require a new resource or subsystem.

Two candidate inferences:

- **Spark Tread:** faster scrap wear produces a short, capped damaging trail. Movement turns a known cost into an attack.
- **Riveted Shell:** more protection per scrap, but a smaller recovery magnet. The player chooses safety on impact versus easier recovery.

These are candidates for play, not approved balance values. Do not make all attractive early builds pay a handling penalty.

**28. Codex and discovery rewards**

**Today:** Discoveries are recorded, and discovery events can trigger an immediate scrap burst through flow. `src/core/codex.gd:131–165`; `src/core/flow.gd:287–288`.

**Decision:** “Do I experiment with an unfamiliar combination or interaction?”

**Costs:** No inherent stop in recording; optional browsing costs screen space, while first-discovery presentation adds its own interruption policy.

**Overlap:** Secrets, synergy completion and achievement-style feats.

**Verdict: protect recognition and recall; rethink the automatic material reward.** If scrap becomes armour, “I learned something” also becomes “I instantly gained protection”. That can be welcome, but it should be intentional rather than an inherited economy side effect.

The home-menu codex is beyond this alpha’s scope; the roadmap retains the in-run version. `design-v3/ROADMAP.md:137`.

**29. Par records and challenge modifiers**

**Today:** The clock supports par and scrapless modifiers and loads the best Warden-break time by stage. Its loader does not partition those best times by class, loop mode or gun role, although the run log records class and lab tags. `src/build/run_clock.gd:14–18,85–123`; `src/core/run_log.gd:50–63,90–103`.

**Decision:** “Which comparable performance am I trying to improve on this attempt?”

**Costs:** No direct stop; one additional timer/split and optional setup choices.

**Overlap:** Lap times, bay lap and bowling feats.

**Verdict: protect comparable records; rethink record grouping.** A fast time obtained under a different loop or pilot is a poor personal ghost. Scrapless also needs a new definition once scrap is a basic defensive layer, rather than merely optional growth.

**30. Strike, Spare and Turkey feats**

**Today:** The system recognizes short kill-chain and rebound achievements and reports them through discovery entries. `src/build/lanes.gd:11–25,56–89`; `src/build/build.gd:701–703`.

**Decision:** “Can I arrange this crowd into a better chain instead of killing it one target at a time?”

**Costs:** No menu stop; low transient glyph/name cost.

**Overlap:** Synergy spectacle and codex discovery.

**Verdict: keep.** These give crowd manipulation a vocabulary. They are not yet a complete personal-best system merely because they recognize skill.

**31. HUD, impact feedback, music and ceremonies**

**Today:** Reward ceremonies queue until their calm test passes, then pause the tree and preserve velocity. The calm test checks threats, enemies and airborne motion but does not require low horizontal speed. During the build phase, one skip advances to the reveal; another closes it. Hit-stop has a separate bounded slowdown mechanism. `src/presentation/reward_ceremony.gd:354–377,407–429,492–543`; `src/game.gd:32–35,259–285`.

**Decision:** **None directly.** This system makes other decisions perceivable.

**Costs:** Automatic ceremony pauses are real interruptions even though velocity is restored. High total screen/audio attention if rewards, discoveries, size changes and threats compete.

**Overlap:** Every reward system requests some of this presentation budget.

**Verdict: protect the shared feedback grammar; rethink interruption frequency.** Respect the requested calm-gated first explanation, but do not equate “no nearby threat” with “the player wanted to stop”. Repeated size crossings and ordinary gains need motion-compatible feedback. Full audio quality and visual clarity remain unjudged without running the game.

**32. Death, checkpoints and quick restart**

**Today:** Stage retry restores a snapshot and entry velocity; arena retry restores its own entry state. The held restart input uses a half-second threshold. `src/core/flow.gd:184–199,216–234`; `src/game.gd:30,234–244`.

**Decision:** “Do I immediately retry this challenge or begin another run?”

**Costs:** Deliberate reset after failure or player input; low reading and setup cost.

**Overlap:** Regeneration and armour recovery operate at shorter timescales.

**Verdict: protect.** A risky economy is much easier to enjoy when failure does not lead to administrative work. Armour, wear, hysteresis and spilled pickups must restore consistently with the checkpoint.

**Where the dimensions are thin**

These are design inferences from the audit:

- **Recovery through skill is concentrated in Brindle.** Most ordinary recovery is time-based regeneration or a defensive effect. Recoverable armour could make a mistake create a new movement problem rather than just lower a bar.
- **Comparable personal-best mastery is underdeveloped.** Timers and feats exist, but the main ghost currently mixes materially different run conditions. Fix comparability before adding another score.
- **Deliberate build correction needs a stronger identity.** Plenty of systems add something. Moss should own the ability to say “this run needs a specific adjustment”.
- **Small, readable gambles are scarce.** The core crate provides genuine gambling, but its all-in terms and capped gate payoff are awkward. One good wager is enough for world one; this is not an argument for many more.
- **The ally family lacks a distinct implemented job.** It should solve a positioning, route or recovery problem.

**Where systems crowd one another**

- **Build growth:** free parts, fabricators, shop stock, kit tree, synergies, evolutions and hot-wired parts all compete to say “your build changed”.
- **Time pressure:** difficulty tiers, mandatory laps, event timers, boss phase floors and newly proposed wear can jointly turn exploration into debt.
- **Reward currencies:** events and vaults can supply parts, cores and scrap through different paths. Adding more reward types would weaken the meaning of each.
- **Celebration:** rare parts, discoveries, synergies, heft transformations and evolutions all want the same attention. A shared queue prevents overlap technically; it does not establish that the total interruption is enjoyable.
- **Defence:** hull, regeneration, mass-health, heal-back protection, defensive abilities and the proposed armour layer need one comprehensible damage order.

**Part 2 — Scrap as size**

The latest roadmap settles **temporary health over hull**, slow rolling wear, size-neutral default handling and hysteresis. `design-v3/ROADMAP.md:147–159`. I therefore recommend testing two armour behaviors, not replacing hull in one of the candidates.

Both options below are **proposals and inferences**, including all numbers.

**Shared contract for either option**

1. **One stored scrap quantity.** It drives size and remaining armour. The HUD may visualize those consequences differently, but there is no independently spendable wallet.
2. **Parts change behavior; scrap supplies physical bulk.** Remove the hidden `0.2` heft per fitted part, then retune scrap supply and thresholds together. Otherwise a part trade changes size even when no scrap changed. The current coupling is in `src/core/run_state.gd:120–121`.
3. **Hull remains the stable baseline.** Wear never damages hull. Keep the existing regeneration initially so the first experiment isolates the new layer.
4. **Fresh scrap and recovered scrap are distinct acquisition causes.** Recovering your own spill restores mass but does not repeatedly trigger “new pickup” combat bonuses or discovery rewards.
5. **All damage resolves in one order:** mitigation → scrap absorption → hull damage → committed result → effects and presentation.
6. **Wear is quiet.** It does not spawn a recovery shower, play repeated loss alarms or trigger a full ceremony. It consumes only the scrap layer.
7. **Class is a stable visual state.** Rise at the threshold; fall only below a margin. For a first trial, use a downward margin of 5% of the preceding class interval. Armour still uses actual remaining scrap.
8. **Default handling and collision size remain unchanged.** Pilot-specific uses of mass affect explicitly chosen actions. Do not make ordinary steering steadily worse as the reward grows.
9. **No additional permanent progression, currencies or world-two branches.**

Three existing seams particularly matter:

- Stage scrap currently increments mass and posts pickup effects one piece at a time, only inside the stage branch. Brindle instead collects valued pickups through its own arena path. A world-wide spill feature needs one recovery contract across both. `src/build/build.gd:686–693`; `src/boss/boss.gd:402–429`.
- Damage reduction currently heals back applied damage; it does not prevent lethal damage. Armour cannot safely be implemented as another after-hit refund. `src/build/item_effects.gd:399–409`.
- Mass-health recalculation happens on pickup, while the current scrap-loss handler handles shell shedding and redraw. Continuous loss needs its own consistent derived-state update. `src/build/build.gd:515–520,625–630`.

**Option A — Recoverable plating, with deliberate refitting**

This is my lead candidate.

**How it works**

Scrap absorbs damage before hull. As an initial test value, **10 scrap absorb 1 HP of damage**.

A 12-damage hit against 100 scrap would therefore remove the 100 scrap and pass 2 damage to hull. Of the scrap removed by the hit:

- 75% becomes a recoverable spill.
- 25% is destroyed.
- The spill is represented by at most six valued clusters, never one physics object per unit.
- Clusters remain reachable ahead of or beside the ball’s outgoing trajectory, rather than routinely demanding a full reversal.
- Recovery has a brief per-spill collection delay, but grants no global invulnerability.
- Recovered scrap does not count as a fresh pickup for proc purposes.

These values are experiment settings. They are not a balance recommendation independent of world-one scrap supply.

Start wear at roughly **30 scrap per minute at sustained cruise**, scaled down below cruise and capped above it. That makes high speed no more expensive per second than cruising. Apply it only during ordinary grounded play, excluding pauses, the bay and authored transfer sequences. Do not add skid or wall penalties in the first trial.

Use one readable world-one mass cap aligned with the eventual class-V threshold. Calibrate it after removing part-count heft; retaining the old thresholds without checking supply would distort the entire growth curve.

**Relationship to hull**

A literal layer on top. Hull is damaged only by overflow after armour is exhausted. Hull regeneration does not regenerate scrap.

**Decision**

“Do I keep attacking, take a safer collection line, or chase my spilled protection before the next hit?”

| S | R | G | K | PB | E | D | F | P | Rec |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2 | 2 | 0 | 2 | 1 | 2 | 1 | 2 | 2 | 2 |

It adds risk and recovery without making every pickup a gambling event. Personal-best potential comes from clean-run mass retention and recovery efficiency; those would need explicit comparable records before earning a stronger score.

**Fabricators and Moss**

- **Fabricators become the physical delivery of earned free choices.** The price is completing the selected loop opportunity and forgoing another offered part. Whether this occurs after a drop or a lap is **pending the sitting**.
- **Moss provides known part-for-part refits.** The outgoing part and incoming part are visible before confirmation. This gives the shop a correction role.
- Remove wallet sell-back and paid cash rerolls. If a reroll remains, make it a single clearly limited rejection of the shelf rather than introduce another token.
- Keep cores attached to optional risk and Warden preparation.
- Treat charge cells as explicit build trades, not a surviving cash-only exception.

Part barter is not a trivial UI change: the present shop intentionally excludes pattern parts from fallback removal. Full refitting requires authoritative removal and rebuilding of the affected weapon patterns. `src/build/shop.gd:434–456`.

**Does a voluntary bay melt earn its place?**

**Yes, provisionally, as one known conversion per visit.** Moss can turn an explicitly shown amount of armour mass into one known part. The card should show the resulting size and protection, including whether a class will be lost.

It earns its place only if it produces a real “keep the bulk or fix the build” decision. It should not be a compulsory progression step or a profitable loop in which fitting/selling parts manufactures mass. No hull spending; no surprise class loss; no random result hidden behind the melt.

**Fit with the principles**

- **Momentum:** spills create rolling routes, not pickup menus. No automatic purchase consumes armour.
- **Quick restart:** restore mass, hull, class state and wear state from the same checkpoint.
- **Readable caps:** one mass cap, five silhouettes, bounded spill clusters and one bay melt.
- **Scrap culture:** the ball visibly wears its salvage; Moss deliberately remakes it.
- **Pilot identity:** retaining mass benefits signature actions differently. It should not be necessary to take a particular tree branch merely to avoid an imposed handling penalty.

**Cheap play experiment**

Use one fixed three-minute route with the same pilot, build, enemy sequence and starting mass:

1. Baseline hull.
2. Armour and recoverable spill, with wear off.
3. The same armour with slow wear on.

Provide one known bay melt at the end. No new art beyond existing scrap and shell effects is required for the experiment.

Record fresh scrap, hit loss, wear loss, recovered amount, hull damage, class changes and time spent reversing for a spill. Andrew’s decisive questions are:

- Did getting hit create a satisfying recovery move or a chore?
- Did wear change a route in an interesting way?
- Did he choose the melt for the build, or feel forced into it?

A failure is visible if wear makes him brake or camp to preserve power, or recovery repeatedly requires abandoning the enjoyable line.

**Option B — Ablative plating, with weight-priced fabrication**

This keeps hull exposed even while scrap is present.

**How it works**

While armour remains, split incoming damage between scrap and hull. Begin with **50% absorbed by scrap and 50% reaching hull**, using the same test conversion of 10 scrap per absorbed HP.

For the same 12-damage hit with 100 scrap:

- 60 scrap are consumed.
- 6 damage reaches hull.
- A portion of the consumed scrap spills for recovery.

If scrap cannot cover its share, the remainder reaches hull. Use the same slow wear and class hysteresis as Option A.

The physical promise becomes: **“A big ball takes less hull damage,”** rather than “the scrap takes the hit first.”

**Relationship to hull**

Still a temporary layer over hull, but it mitigates a share of each hit instead of fully shielding hull until depleted. Hull can therefore remain the urgent survival reading throughout combat.

**Decision**

“Do I preserve enough plating to reduce future hits, or spend it now on a part that should prevent those hits?”

| S | R | G | K | PB | E | D | F | P | Rec |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2 | 2 | 0 | 2 | 1 | 2 | 1 | 1 | 1 | 2 |

This makes defensive tradeoffs more continuous. It scores lower on feel and pacing because every hit changes two defensive readings and recovery may compete with a need to let hull regenerate.

**Fabricators and Moss**

- **Fabricators consume weight for a known part.** Payment requires an explicit held interaction on a readable approach. Merely crossing the current purchase hoop is insufficient consent for spending protection.
- **Moss uses the same weight-for-part conversion**, with a clearer preview and a safe place to compare.
- Each fabricator is a one-use offer for the encounter; do not retain frequent restocking until the economy has survived play.
- Cores remain dedicated to Warden preparation.
- No wallet sell-back. A part removed during refitting must not return an amount of mass that enables a profitable purchase loop.

**Does a voluntary bay melt earn its place?**

**Yes, but it is the shop transaction itself.** Do not build both a weight-priced shop and a separate “melt system” that performs the same exchange. Moss’s advantage is selection, information and safety.

**Fit with the principles**

- **Momentum:** no pause is needed, but safe at-speed price comprehension is harder than Option A.
- **Quick restart:** the same state restoration contract applies.
- **Readable caps:** the count is simple; the two-way damage split is less simple.
- **Scrap culture:** fabrication literally consumes what the ball is wearing.
- **Expression:** the player can intentionally run light with more behavior-changing parts. That strategy must work because of the parts, not because heavy handling has been made unpleasant.

**Cheap play experiment**

Reuse Option A’s route and damage sequence. Add one known fabricator offer before a threatening section and repeat with:

- a cheap price;
- a price large enough to cross a class boundary.

The experiment asks whether Andrew can understand and accept that exchange while moving. Record purchase/skip, subsequent hull damage, recovery detours and whether he correctly predicts the lost protection.

If explaining the transaction requires stopping to discuss two health consequences, this option fails the introductory-world readability test.

**Blast radius**

The following is the **proposed edit set**, inferred from the inspected dependencies. It is not a claim that every file needs a large rewrite. Paths are real existing paths under the linked sketch; no files were changed.

| Area | Existing files affected by both options | Intended change |
|---|---|---|
| Run state and checkpoints | `src/core/run_state.gd`, `src/core/flow.gd` | Remove wallet semantics; own armour loss, wear and class hysteresis; restore all new state consistently. |
| Gameplay facts | `src/core/game_events.gd`, `src/core/event_kinds.gd` | Distinguish fresh gain, recovery, wear, theft, armour damage and hull damage without contradictory totals or cues. |
| Build orchestration | `src/build/build.gd` | Resolve continuous mass changes, feed wear from movement, use the new damage/pickup contract and update all derived state. |
| Pickup representation | `src/build/scrap_field.gd` | Valued recovery clusters, source/provenance, lifetime and bounded spill presentation; usable outside the current stage-only collection branch. |
| Existing theft | `src/boss/boss.gd`, `src/boss/boss_rules.gd` | Move crane recovery onto the same semantics; retain the distinction between stolen and destroyed scrap. |
| Defensive parts | `src/build/items.gd`, `src/build/item_effects.gd`, `src/build/build_sheet.gd`, `src/build/triggers.gd` | Replace generic mass-health duplication; apply protection before lethal damage; define what armour-only hits and recovered scrap trigger. |
| Physical transactions | `src/build/fabricators.gd`, `src/build/shop.gd` | Replace wallet prices, affordability, cash rerolls and cash refunds with each option’s transaction. |
| Shop and run UI | `src/ui/hud.gd`, `src/ui/shop_counter.gd`, `src/ui/workshop.gd` | Remove wallet display, show armour/hull clearly, preview costs and preserve explicit consent. |
| Explanations | `src/ui/growth_sheet.gd`, `src/ui/callouts.gd` | Explain scrap → size/protection and the chosen transaction without the old wallet/part-heft story. |
| Ball appearance | `src/build/accretion.gd`, `src/presentation/juice.gd` | Make additions, erosion, class loss and class transformations honestly reflect the new source of size. |
| Feedback | `src/presentation/vfx.gd`, `src/presentation/audio.gd`, `src/presentation/reward_ceremony.gd` | Differentiate a damaging spill from quiet wear; bound repeated class feedback; preserve first-discovery policy. |
| Evidence and challenges | `src/core/run_log.gd`, `src/build/run_clock.gd` | Record armour outcomes and comparable conditions; define or defer scrapless under the new survival model. |
| Interaction vocabulary | `src/world/interactables.gd` | Remove the obsolete wallet-cost meaning, including the planned ally cost vocabulary. |

**Option A adds these specific changes:**

- `src/combat/combat.gd`: rebuild affected patterns after authoritative part removal/refit. The existing shop restriction identifies this dependency explicitly. `src/build/shop.gd:434–442`.
- `src/build/parts.gd`, `src/build/reward_gates.gd`, `src/world/world.gd`: consolidate earned choices and fabricator delivery according to the loop selected at the sitting.
- `src/core/flow.gd`: coordinate that chosen reward cadence without granting the same earned pick twice.

**Option B adds these specific changes:**

- `src/build/fabricators.gd`, `src/build/build.gd`: replace purchase-on-crossing with explicit weight-spend consent and one-use offers.
- `src/ui/shop_counter.gd`, `src/ui/workshop.gd`: make the melt the ordinary shop transaction, including post-purchase class and protection previews.
- It does **not** require arbitrary part removal if world-one transactions only add parts and cash sell-back is removed.

**Existing checks whose assumptions would need revision for either option:**

`tests/spine_heft_test.gd`, `tests/spine_restart_test.gd`, `tests/spine_arena_retry_test.gd`, `tests/build_arena_retry_shell_test.gd`, `tests/build_magnet_test.gd`, `tests/build_fabricator_test.gd`, `tests/shop_economy_test.gd`, `tests/item_trigger_test.gd`, `tests/boss_fixwave_test.gd`, `tests/boss_scaling_test.gd`, `tests/ui_scrap_frame_test.gd`, `tests/ui_workshop_shop_test.gd`, `tests/ui_word_budget_test.gd`, `tests/presentation_ceremony_test.gd`, and `tests/build_clock_test.gd`.

Option A additionally reaches `tests/build_parts_test.gd`, `tests/build_gate_seam_test.gd` and `tests/combat_pattern_test.gd` through refitting and reward delivery. These are identified test surfaces, not claims that their current assertions were executed or that this is a complete future test plan.

**Indirect balance consumers require verification, not automatic edits:**

- Contact and ordinary damage: `src/movement/contact.gd`, `src/combat/combat.gd`.
- Warden impact damage: `src/combat/warden_drop.gd`.
- Collection strength: `src/build/scrap_field.gd`.
- Heft-responsive population: `src/world/director.gd`, fed by `src/world/world.gd`.
- Mass-sensitive build effects: `src/build/item_effects.gd`.

Those dependencies follow the current heft and mass readers. `src/movement/contact.gd:18–19`; `src/combat/warden_drop.gd:208`; `src/build/build.gd:679–682`; `src/world/world.gd:472–479`; `src/world/director.gd:136–138`; `src/build/item_effects.gd:179–183`.

The newly requested pilot-specific mass conversions are **a separable extension**, not necessary to settle the armour experiment. They would also reach `src/core/trees/sable.gd`, `src/core/trees/rivet.gd`, `src/core/trees/kest.gd`, `src/core/upgrade_tree.gd`, and the movement/combat consumers of their operations. The current operation vocabulary is documented in `src/core/upgrade_tree.gd:17–33`; the exact implementation set should follow selection of the world-one verbs, not an invented capstone programme.

**Recommendation**

Choose **Option A: recoverable plating over hull**, with slow wear tested separately, earned physical part choices, and Moss owning deliberate refits. Trial the voluntary bay melt as one explicit known exchange.

It gives a direct answer to “why collect scrap?”:

**To become a tougher, more forceful ball; to keep that advantage by playing cleanly; and to recover it through movement when a hit knocks it loose.**

The single biggest risk is **a downward spiral after damage**. Scrap loss can simultaneously reduce protection, punch, contact advantage and collection reach, while wear keeps consuming the same reserve. The current coupling of heft to impact, rebound thresholds and magnet strength makes that a concrete risk rather than a generic balance concern. `src/combat/warden_drop.gd:208`; `src/movement/contact.gd:18–19`; `src/build/build.gd:679–682`; `src/build/scrap_field.gd:11–18`.

The next decisive step is the short fixed-route play experiment: determine whether the first ordinary armour spill makes Andrew want to roll through the recovery line. If it instead makes him feel smaller, weaker and obliged to backtrack, fix that recovery interaction before adding more progression.