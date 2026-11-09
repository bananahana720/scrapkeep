# Hook chain: the combo on the harpoon

Status: spec, written by the coordinator after checkpoint 1 (playtest entry 12, EV-0624). Build spec for the first wave of the full-send round. Andrew's words: "the chaining on enemies or walls off of enemies back onto enemies ... Kind of like a combo counter ... more like a rhythm game." He keeps the soft lock and the spam ("I like the spammingness of it"), wants a cost "on a miss", and the enemy-side answer later.

## The rule

A **chain** is a sequence of harpoon bites with no ground contact between them. Each bite extends the chain; the ball touching the ground, a dry fire, or a `let_go` with no bite within the grace window ends it. The chain's length is the **combo**.

| Link | Counts | Note |
| --- | --- | --- |
| bite an enemy | +1 | the existing `latched_body` |
| bite a surface (post, wall hook, wall) | +0, keeps the chain alive | a **pivot**; the kicker Andrew described: enemy → wall → enemy |
| smash lands on a chained enemy | pays the combo | damage × (1 + 0.3 × (combo − 1)), capped at combo 6 (×2.5); combo 1 pays ×1.0, today's game |
| dry fire | ends the chain, **miss cost**: 0.6 s harpoon cooldown and a dull `dry_tick` | today a dry fire costs nothing, which is the spam he called too easy |
| ground contact | ends the chain | the rhythm is airborne |

Grace: a `let_go` keeps the chain alive for 0.8 s of airtime. A pivot does not raise the combo, so a wall-wall-wall chain pays nothing; two walls in a row with no enemy between them end the chain. The soft lock is untouched. Spam stays legal: a combo of 1 is exactly today's game. The ceiling is new, the floor is not lower.

## One source, every layer

One `ChainState` on the player (`src/combat/chain.gd`, new) owns `combo`, `links`, `grace_left`. Everything else reads it; nothing else writes it.

| Layer | Reads | Shows |
| --- | --- | --- |
| HUD | `combo` | a counter beside the ability bar, only while `combo >= 2`; digits scale with the beat on each link (`SOUND-STORY` section 7's hit-stop clock) and fall when the chain ends |
| body | `combo` | the line's bite collar (`latched_body`) gains one ring per link up to 6 |
| sound | link event | `line_bite` rises a rung of the pentatonic per link (`chain_link` row; C, D, F, G, then A an octave up, AUDIO-V3 section 5 rule 3), falls to the root on the smash; the chain end is a short `line_zip`; the miss is `dry_tick` with the cooldown's length |
| impact | `combo` | `IMPACT["harpoon_smash"]` knock and shake scale with the same multiplier, so a combo-5 smash looks like a combo-5 smash |
| run log | chain end | `chains: [{links, pivots, combo, paid}]`, plus `best_combo` and `misses` |
| codex | first combo ≥ 3 | discovery card "Chain" opens, with the two causes and the effect drawn (WY callout grammar) |

All rows live in `event_kinds.gd` next to `LINE_ROWS` (line 509), new state ids `chain_link`, `chain_pivot`, `chain_end`, `chain_miss`, emitted through `line_state_changed` so the existing listeners and tests see them.

## What the enemies get later

Not in this unit. Worlds two and three answer spam on their side: the deflector's dish already vaults a hooked ball; the Dig's drill crew cuts a line that stays on it past one beat; the Highdraft's line cutter is the chain's natural enemy. The anchor is `LINE_ROWS` so a counter is one row, not a system.

## Units

| Unit | Owner files | Done when |
| --- | --- | --- |
| HC1 chain state and rule | `src/combat/chain.gd` (new), `src/movement/player_ball.gd` (the harpoon bite, let_go and dry-fire hooks), `event_kinds.gd` chain rows | table test: 14 scripted sequences (enemy-enemy, enemy-wall-enemy, wall-wall, ground break, grace edge at 0.79 and 0.81 s, dry fire) give the expected combo and payout; the soft lock test is unchanged |
| HC2 readout | `src/ui/hud.gd` counter, `src/presentation/line_view.gd` collar rings, `src/presentation/audio.gd` rows | still of combo 4 with four rings and the counter; sound test: `chain_link` pitch steps per link, root on smash |
| HC3 miss cost and log | `player_ball.gd` cooldown, `src/core/run_log.gd` chains, codex "Chain" card | run log test: a scripted run writes `best_combo`, `misses`; dry fire sets 0.6 s cooldown |

HC1 lands first and alone (it touches the harpoon). HC2 and HC3 follow in one wave on disjoint files. Bot band after HC3: the skipper's smash damage per fight must not rise more than 10% (it never chains), the explorer's best_combo median ≥ 2 over 16 seeds (the bot gets a two-hook script). If the explorer cannot chain, the grace or the anchor spacing is wrong, not the bot.

## Open calls, decided here

- The first link pays nothing extra (coordinator, 3 Oct, HC1 build). The first draft paid combo 1 at ×1.25, which contradicted "combo 1 is exactly today's game" and broke the harpoon canon test by killing its chaser on a plain smash. The multiplier counts links beyond the first, 0.3 each, so the floor is today's game and the cap is still ×2.5 at six.
- The combo pays the chained enemy only (coordinator, 3 Oct, gate review). The landing's shockwave, its bystanders and the `slammed` strength other systems threshold on (activity walls) stay at the plain smash. Shake and knock feel for a big combo belong to HC2's presentation, not to the physics.
- A press during the rewind is not a miss (coordinator, 3 Oct, gate review). Only a press with nothing under the reticle is a dry fire that ends the chain and costs the cooldown; the post-smash rewind already refuses the press, and Andrew keeps the spam.
- Chain rows are silent and invisible until HC2 (gate review). The line view, the audio and the enemy reaction listeners skip `chain_*` ids, because they otherwise read a chain fact as the line's state and hid the lock brackets at combo 1.
- The chain end is heard only when it had a combo of 2 or more (coordinator, 3 Oct, wave 2 gate). A one-bite chain or a lone pivot ends silently, so a plain wall grapple then landing sounds as it always did.
- Arena chains count (coordinator, 3 Oct, wave 2 gate). The run log's chains, best_combo and misses count in the Brindle fight like bites and smashes do.
- Payout is damage, not scrap. Scrap is size and armour; making the chain pay scrap would bend the economy around a movement verb.
- The combo caps at 6. Past six the counter is noise and the multiplier would outrun the Warden's chunk size.
- The pivot adds nothing. Walls are routing, enemies are the beat.
- The miss cost is a cooldown, not damage to the player. Punishing a miss with hull damage would make the spam feel bad; a cooldown makes it feel sloppy, which is the lesson.

Say "veto" on any of these and it changes.
