The Drop Loop merits a prototype, but the current draft is not internally consistent enough to gate implementation or Andrew’s sitting. Its biggest risk is replacing an optional map with a compulsory commute.

Reviewed clean commit `1589f4f`, playtest entries 7–8, both research briefs and the standing principles. This was source inspection, not runtime testing. Below, “D” means [LOOP-REDESIGN.md](/home/andrew/Projects/scrapkeep-worktrees/core-loop-v3-design/sketches/core-loop/design-v3/archive/LOOP-REDESIGN.md).

1. **Blocker — The damage contract permits the shortcut it forbids.**  
   D §1 says only leaving the bowl enables damage; §2 explicitly permits pulse-lift slams, deflector-assisted drops without a shelf, brood-cell damage and body unplating. The open core has zero plating, but no precise descending-impact requirement distinguishes a drop from a fast floor contact. Current [`contact_part()`](/home/andrew/Projects/scrapkeep-worktrees/core-loop-v3-design/sketches/core-loop/src/combat/warden.gd:301) checks horizontal proximity, not altitude or descent. **Smallest fix:** specify one physical hit predicate, including impact direction and duplicate-contact rejection. Decide whether skillful bowl shortcuts are welcome. Test pulse farming, nearest-kicker repetition, lift camping and rebound chains, rather than only the old skipper.

2. **Blocker — The first drop has no reliable timing contract.**  
   D §§1–2 retain family mechanics and proximity activation. Currently, [`_step_pulse()`](/home/andrew/Projects/scrapkeep-worktrees/core-loop-v3-design/sketches/core-loop/src/combat/warden.gd:338) accumulates four seconds inside the 30-metre reach before starting its two-second telegraph. A fast crossing does not provide that residence. Meanwhile, the proposed 3.2-metre target spans only about 0.16–0.21 seconds at 30–40 m/s, before ball radius or forgiveness. **Smallest fix:** guarantee a visibly committed opening before the launch decision, show projected landing, and give an immediate recovery attempt. Test imperfect launch timing and chase-camera occlusion, not just a nominal ballistic arc.

3. **Blocker — The lab’s acceptance rules prejudge Andrew’s choice.**  
   D §6 authorizes full gun damage during windows, but §§4 and 7 require camper failure and ≥80% drop damage. Those rules can reject the authorized gun variant for behaving correctly. Four required windows also conflict with a powerful two-drop kill. Outside-bowl time measures travel, not engagement; prescribed completionist routes manufacture route diversity. **Smallest fix:** use mode-specific mechanical checks. Compare voluntary detours, repeated-route share, miss-recovery time, time without meaningful input, and Andrew’s unaided understanding. Use matched seeds and reverse the finalist order on a second comparison.

4. **Should-fix — Repeated drops could become a toll, and the gun becomes administration.**  
   D §§1 and 6 propose 25–40-second laps and starting counts of four, five and six hits. A miss can buy another commute; gun-hold preserves an appointment rather than delivering Rivet’s payoff. This is a **fun hypothesis**, not a demonstrated failure. Portal’s useful precedent is deliberate momentum teaching and allowing sufficiently skilled shortcuts, documented in [Valve’s commentary](https://theportalwiki.com/wiki/Portal_developer_commentary). Conversely, [PC Gamer’s *Sonic Frontiers* preview](https://www.pcgamer.com/yes-sonic-frontiers-is-as-bad-as-it-looks-but-i-want-more/) describes repeated knock-offs draining a climb-to-weak-point fight’s appeal. **Smallest fix:** trial two successful drops first, preserve meaningful gun burst, and shorten recovery after misses before adding mandatory laps.

5. **Should-fix — “Consent at speed” currently demands slowing down.**  
   D §9 combines six-metre reach with a 0.35-second hold. Even a full diameter pass takes only 0.30 seconds at 40 m/s. Nearby interactables also override Sable’s mount, potentially stealing an intended escape. D §1 describes a routine 15% return-speed loss, while existing [`ride_rail.gd`](/home/andrew/Projects/scrapkeep-worktrees/core-loop-v3-design/sketches/core-loop/src/world/ride_rail.gd:10) banks and restores speed. **Smallest fix:** acquire and lock the target earlier, permit hold completion after passing, protect an already-started mobility action, and restore banked speed. Repeated 70 ms hit-stops need a cumulative interruption budget.

6. **Should-fix — The three reads contradict their own evidence.**  
   D §2 rewards only near-misses, leaving clean early dodges unacknowledged. A hollow pulse says the ring was empty, not necessarily that the player successfully evaded it. “Drops remaining” cannot remain exact with continuous speed×heft damage, partial gun damage and changing heft. Class colour simultaneously means dodge success and vulnerability. **Smallest fix:** distinguish safe resolution from a near-miss bonus; show truthful integrity chunks rather than promised hit counts; reserve different shapes for opening and evasion. Verify all three reads in moving, dense footage with music and effects, beyond ROADMAP’s stills and event tests.

7. **Should-fix — Holds and bets lack bounded economic rules.**  
   D §§1 and 9 leave ambiguous whether the two-second hold allowance is shared across pellets, turrets and procs. Unlimited bonus-core window extensions can erase timing. “Call the Warden” risks becoming free once its clock penalty saturates. Repeatable double-or-nothing invites escalation or restart fishing. These are **prospective exploits**, not observed bugs. **Smallest fix:** one aggregate extension budget per opening; explicit window bounds; a call cost that still exists at the cap; one committed wager per cache, with disclosed stakes and defined persistence. Test these adversarial policies.

8. **Should-fix — The director diagnosis overstates the absence of pressure.**  
   D §0 says stay-longer pressure arrives after the break. [`reinforcement_weight()`](/home/andrew/Projects/scrapkeep-worktrees/core-loop-v3-design/sketches/core-loop/src/world/director.gd:218) already adds `0.12 × effective_tier` before it; only the extra `0.08` term waits. I confirmed the boss-only unseal and route-test funnel. **Smallest fix:** correct the diagnosis and measure which packs actually reach and threaten the beeliner. Adding lap punishment before resolving that may tax traversal while leaving avoidance intact.

9. **Should-fix — Build variety is not yet variety in play.**  
   D §8 counts build IDs, but fixed routes and a heft-dominated boss can make different weapons produce the same fight. Evolutions arrive after the stage’s central challenge; six-pack laps promise density without specifying counter combinations or recovery space. **Smallest fix:** prototype two builds that change the chosen route and attack sequence, plus one bad-luck recovery route. Measure changed decisions and voluntary restarts. Cap simultaneous control chains and protect threat visibility before increasing population.

10. **Should-fix — Buying an ally wrongly shrinks the player.**  
    D §9 explicitly says its scrap cost lowers heft. Standing principle 10 forbids that, and [`spend_scrap()`](/home/andrew/Projects/scrapkeep-worktrees/core-loop-v3-design/sketches/core-loop/src/core/run_state.gd:168) preserves mass. **Smallest fix:** charge wallet scrap only; make any theft a separate, telegraphed event.

11. **Consider — Test the cheaper “drop opens the damage opportunity” alternative.**  
    D compares drops against two compulsory gates, missing a mixed approach. **Speculation:** a terrain-assisted impact could stagger the Warden for substantial gun damage, with growth extending or exploiting that opening. This preserves map-made opportunities and the loved gunning. **Smallest fix:** adapt the already-authorized `full` toggle to test this before building three-stage lap infrastructure.

**What to watch in Andrew’s fun-lab sitting**

- Before his first launch, can he predict where and when the core opens without coaching?
- After a miss, does he immediately choose another action, or wait, brake or repeat a commute?
- Does he choose the longer route for a specific desired payoff, then change that choice after an upgrade?
- Can he identify a dodge, an opening and actual boss progress during peak effects without reading HUD prose?
- After winning or dying, does he restart voluntarily and name something different he wants to try?


Codex session ID: 01a0e7ca-6d2a-7030-8f9f-fb0e44d9e103
Resume in Codex: codex resume 01a0e7ca-6d2a-7030-8f9f-fb0e44d9e103
