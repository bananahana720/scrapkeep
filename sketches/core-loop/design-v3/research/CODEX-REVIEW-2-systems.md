The design has a promising snowball, but **it does not yet establish escalating power over 20–30 minutes**. My prediction, still speculative, is uneven growth: late transformations for some runs, projectile saturation for others, and combinations that collapse Warden fights before players enjoy their rewards.

Read-only review of clean `7144a9e`, spikes `1cb5f7c` and `daf58c4`, and the loop/review documents at `494cd44`. No files edited or gameplay tests run. **S** below means [SYSTEMS-CHAOS.md](../archive/SYSTEMS-CHAOS.md).

1. **Blocker — The simulator does not validate the proposed snowball.**  
   S §§1.2, 14 reports 47.5% lapper and 84% completionist reach by break 2. But S1 allows self-pairing, checks eligibility **after break rewards and shop purchases**, never consumes evolved ingredients, and uses the superseded bait/Meteor rules. Its 15/27 picks also differ from the design’s 25–30/40–45. These numbers establish availability under another contract, not completed evolutions or DPS. S2 proves injected-event plumbing, not physical 95% restitution.  
   **Smallest fix:** simulate the final eligibility rules at the actual break instant, consume ingredients, and feed it measured reward schedules. Guarantee missing ingredients for dry runs: §5.6’s Cracked Core rescue currently requires an already-armed pair.

2. **Blocker — Paper power can rise while delivered power plateaus or falls.**  
   S §§1.4, 8 targets 30–400× DPS, but [`build_sheet.power()`](/home/andrew/Projects/scrapkeep-worktrees/core-loop-v3-systems/sketches/core-loop/src/build/build_sheet.gd:113) omits combat caps. At 20 volleys/s ×16 bolts, 64 live bolts represent only **0.2 seconds** before replacement under sustained saturation. [`bolts.gd:84`](/home/andrew/Projects/scrapkeep-worktrees/core-loop-v3-systems/sketches/core-loop/src/combat/bolts.gd:84) deletes the oldest projectile; this can reduce effective range. Meanwhile, uncapped punch and heft multipliers can trivialize fixed encounters.  
   **Smallest fix:** measure delivered damage at several distances, projectile retirement, and drops-to-break. Consolidate excess projectile output into surviving shots. Choose the duration target explicitly: §2.2 currently budgets 12–16 minutes, including a three-minute reward drought in the arena.

3. **Should-fix — Better drops earn fewer choices; weak drops invite farming.**  
   S §§1.1, 2 gives a gate per landed drop while power reduces required drops. Completionists supposedly receive more gates despite shorter fights. Low-damage repeat impacts could maximize rewards; post-break eligibility is unspecified.  
   **Smallest fix:** give each Warden a finite reward budget tied to newly crossed integrity thresholds, rejecting duplicate contacts. Settle remaining rewards at the break so powerful hits do not lose progression. Preserve legitimate skillful shortcuts.

4. **Should-fix — The economy mistakes predictable outcomes for bounded risk.**  
   S §4’s 50% double-or-nothing has expected core return **C**, not above-even; capped gate tiers can make its utility worse. A deterministic retry still lets players discover a loss, restart, then skip that wager. Loaded Dice doubles an undefined stake, including “all cores.” Clock Cores, Hollow packs and guaranteed fodder create potential farming loops.  
   **Smallest fix:** specify payouts and utility at each core tier, define Loaded Dice per eligible bet, distinguish practice retries from recorded runs, and budget repeat-spawn rewards. Adversarially test Cursed Cache beside prepared fodder and Hungry Magnet’s self-damage during its one-hit curse.

5. **Blocker — Stacked rules violate their own boundaries.**  
   S §4 claims an eight-second maximum, but Mind’s 5 + Long Window’s 2 + extension pool’s 3 = **10 seconds**, before resolving Call the Warden. §1.2 automatically removes ingredients without specifying preserved effects/tags or selection among multiple armed recipes. §5.3’s Prophet braces against two verbs although alternating verbs is the stated escape.  
   **Smallest fix:** define one final window calculation, preserve required ingredient contributions, let players nominate the teased evolution before the break, and guarantee an available response to every brace.

6. **Should-fix — Four evolutions need a stronger decision than extra damage.**  
   S §1.2’s strongest candidates are Pinball Hull, Screaming Spiral, Meteor Frame and Glacier Wake. My weakest four and proposed replacements are **design hypotheses**:

   | Evolution | Weakness | Ball-native replacement |
   |---|---|---|
   | Storm Tether | Automatic proximity damage | Rebounds anchor two conductive endpoints; crossing their tether discharges and slingshots the ball. |
   | Live Hull | Contact adds nearby zaps | Contact polarizes one enemy; hitting another connects them, rewarding deliberate target order. |
   | Fault Line | Periodic damage lane | A ram lays a fault; crossing it with a slam launches a ridge of pins along its original heading. |
   | Capacitor Bank | Larger special burst | Distinct wall/enemy/ground rebounds load charges; the next aimed ram spends them as sequential impacts. |

7. **Should-fix — Choices and spectacle still threaten momentum/readability.**  
   S §§2.3, 7 places newly spawned gates 20–30 m away but assumes 38 m of reading time. At 45 m/s, even 38 m is **0.84 seconds**; the five-word prompt at 6 m gets 0.13 seconds. Automatic evolution’s 120 ms hit-stop is not a chosen stop. Squall explicitly hides lips that §1.5 says never to obscure.  
   **Smallest fix:** preview gate choices before impact, allow deferred collection, animate evolution while rolling, and keep landing/kicker silhouettes visible through weather. Density counts and stills cannot establish moving readability.

**Minimum high-impact set**

Build **S7’s essential measurements first**, then **S2 cadence + reduced S1** with the four contrasting evolutions above. Add **reduced S5** for feed/test composition, control limits and bounded rewards; retain the current population cap initially. Add **reduced S3** with two contrasting rules and **reduced S4** with one skill wager and one explicit luck wager.

Take only seeded line contents and one meaningful route variant from **S6**. Defer its nine Warden modifiers, elite catalogue, and **all S8 unlock machinery**. Run 20 should differ through routes, target order and experiments players choose; meta cannot rescue repetition. Preserve discovery records. Full three-stage delivery still depends on the accepted loop and readable Wardens.

**Five things to watch when Andrew plays**

- Does an evolution change his next route or target?
- Does a huge hit feel rewarding despite skipping reward opportunities?
- Does he choose gates deliberately without braking?
- Can he explain the danger and his escape during peak chaos?
- After finishing, does he voluntarily restart with a specific experiment in mind?


Codex session ID: 01a0e7f9-4314-7d11-9f49-d6e73a2b83f4
Resume in Codex: codex resume 01a0e7f9-4314-7d11-9f49-d6e73a2b83f4
