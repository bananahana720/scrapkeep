# Owner interview, 2026-10-02 (three rounds through AskUserQuestion)

The table preserves the 2 October interview. The implementation request on 3 October adds the refinements below; use them with the current [alpha plan](ALPHA-PLAN.md).

| # | Question | Andrew's answer |
| --- | --- | --- |
| 1 | Run shape | All three worlds in a row; every run starts in world one; death ends the run (default) |
| 2 | Death and retries | One retry per world, then death ends the run (default) |
| 3 | Run length for a winning run | 30 to 45 minutes, about 10 to 15 per world (default) |
| 4 | Carry-over between runs | Unlocks only: pilots, cosmetics, achievements, new parts and synergies in the pool; no permanent stat boosts (default) |
| 5 | Arizona per world | By theme: Spillway Works = Glen Canyon Dam, Horseshoe Bend, Antelope slots, The Wave; Dig = Meteor Crater, Bisbee pit, Jerome, cliff dwellings; Highdraft = Grand Canyon rim strata, Monument Valley buttes, Sedona spires (default) |
| 6 | Enemy homes | Breakable side goal: smashing a home stops that kind's arrivals for the stage and pays scrap (default) |
| 7 | Story delivery | Moss and the camp crew talk briefly between stages, plus found field notes and item text; short and skippable (default) |
| 8 | Difficulty | A winning run in 3 to 5 tries for Andrew (default) |
| 9 | Camp | His words: "Small camp that has a interactable game menus and also areas to lounge and play any games and just practice the movement and gameplay" |
| 10 | Input to polish first | Keyboard and mouse (default) |
| 11 | First new pilot | Tarn, melee (default) |
| 12 | Showpiece | Builds and synergies, and traversal and maps (he picked two) |
| 13 | Camp lounge games | Ball games on the same physics (pinball, skee-ball, target wall), and pets and toys to fuss with |
| 14 | Practice yard | A time-trial course with ghost and medals, plus a sandbox where any enemy can be spawned (default) |
| 15 | What makes a synergy great | A big visible effect on the world, and chains where synergies feed each other |
| 16 | What a great line feels like | All four: speed and flow, big air, threading gaps, hidden routes |

## Refinements authorized on 3 October

- Mind ends the three-world campaign. Six full pilots are required. Rivet retains the world-one rescue, Tarn unlocks after Brindle, Kest retains the Dig rescue, Tally returns the three ledger leaves to Moss, and the remembered cannon unlocks after Mind. Earned pilots become selectable next run; preserve existing profile unlocks.
- The first death in a world spends its one retry. The next death there ends the run. Quit or crash replays the saved zone entrance without spending the retry. Restore stable offers and prevent duplicate transient rewards or permanent transactions.
- One binary tree per pilot has four picks and sixteen endpoints. World one opens depths one and two; later worlds open three and four. Scrap supplies size and temporary armour, Cogs supply spending agency, and cores remain zone-local.
- The combat companion is one SPIL-9 hover chassis with two unordered sockets. Fit any two different support families from conductive priming, a brief ram brace and a clutch escape corridor at intermission. Run-found pieces do not auto-equip. No additional combat key, companion health economy, revival or extra retry. Camp pets remain separate.
- The required camp has the launch gate, lockers, Moss, achievements, settings, one working skee-ball lane, pet and toys, a saved-ghost time trial with medals, and an any-enemy sandbox. Additional lounge games and decorative expansion are optional. Launch targets remain five seconds by rolling or two through the shortcut.
- Andrew's Cable Reach sitting comes before any Dig or Highdraft map or encounter construction. Reuse the approved kit and terrain probes. A weak kit probe refines the required pilot rather than reducing the six-pilot target.
