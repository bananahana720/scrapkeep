# S1: snowball offer-rule simulator

Tool: `godot --headless --path sketches/core-loop --script res://tools/snowball_sim.gd -- --seeds=200`

Base SHA: 43eeeea

Parameters: policy {lapper, completionist} x ripe {2, 3} x bait {0.0, 0.35, 0.5} x greedy {0.0, 0.8}, 24 cells, 200 seeds each (rng.seed = 20260928 + 7919 * seed).

Ripe count: a pattern part (spiral_wave, chain_arc, cross_split) is ripe at 2 copies; a row whose own stack_cap is 1 is ripe at 1 copy; every other row is ripe at the `ripe` parameter, capped at its own stack_cap when that cap is >= 1. A pair is ripe when held holds at least that many copies of its shown part and some held part (including the shown part itself, when it carries the tag) carries the pair's tag.

Chooser: with probability `greedy`, prefer an offer that ripens a pair (the shown part below its ripe count, or a part carrying a pair's tag when that pair's shown part is already held), picked uniformly among qualifying offers; otherwise pick uniformly among the whole offer.

Bait (`--bait`, off by default): a post-roll substitution the tool applies itself, never inside parts.gd. After each roll, with probability `bait`: if any pair's shown part is below its ripe count and sits in that roll's own rarity pool (`Parts.offer_pool`), the last offer slot becomes that shown part (uniformly among qualifying pairs); else if any pair's shown part is held at or above ripe but no held part carries its tag, the last slot becomes a random pool part carrying that tag (uniformly among qualifying pairs). Only the last slot ever moves, at most once per roll.

Evidence limit: this is a draw simulation of the offer rules against a synthetic pick schedule and chooser, not play. It measures how often the rules make a pair reachable; it says nothing about whether reaching one feels good, whether the schedule matches how Andrew or a bot actually spends picks, or how the chooser's greedy/bait knobs compare to a real player's judgement.

## Results

| policy | ripe | bait | greedy | share ripe by break 1 | share ripe by break 2 | share ripe by break 3 | mean ripe pairs at end | distinct build ids /200 | mean picks |
|---|---|---|---|---|---|---|---|---|---|
| lapper | 2 | 0.00 | 0.00 | 0.065 | 0.230 | 0.420 | 0.510 | 200 | 15.00 |
| lapper | 2 | 0.00 | 0.80 | 0.095 | 0.350 | 0.675 | 0.840 | 200 | 15.00 |
| lapper | 2 | 0.35 | 0.00 | 0.170 | 0.475 | 0.735 | 1.180 | 200 | 15.00 |
| lapper | 2 | 0.35 | 0.80 | 0.240 | 0.655 | 0.855 | 1.535 | 200 | 15.00 |
| lapper | 2 | 0.50 | 0.00 | 0.230 | 0.600 | 0.855 | 1.540 | 200 | 15.00 |
| lapper | 2 | 0.50 | 0.80 | 0.320 | 0.755 | 0.930 | 2.010 | 200 | 15.00 |
| lapper | 3 | 0.00 | 0.00 | 0.055 | 0.165 | 0.295 | 0.350 | 200 | 15.00 |
| lapper | 3 | 0.00 | 0.80 | 0.070 | 0.235 | 0.480 | 0.555 | 200 | 15.00 |
| lapper | 3 | 0.35 | 0.00 | 0.155 | 0.360 | 0.595 | 0.775 | 200 | 15.00 |
| lapper | 3 | 0.35 | 0.80 | 0.190 | 0.515 | 0.715 | 1.055 | 200 | 15.00 |
| lapper | 3 | 0.50 | 0.00 | 0.190 | 0.455 | 0.700 | 1.015 | 200 | 15.00 |
| lapper | 3 | 0.50 | 0.80 | 0.240 | 0.585 | 0.790 | 1.295 | 200 | 15.00 |
| completionist | 2 | 0.00 | 0.00 | 0.160 | 0.470 | 0.820 | 1.455 | 200 | 27.00 |
| completionist | 2 | 0.00 | 0.80 | 0.225 | 0.735 | 0.955 | 2.080 | 200 | 27.00 |
| completionist | 2 | 0.35 | 0.00 | 0.395 | 0.840 | 0.985 | 3.200 | 200 | 27.00 |
| completionist | 2 | 0.35 | 0.80 | 0.565 | 0.950 | 0.990 | 3.885 | 200 | 27.00 |
| completionist | 2 | 0.50 | 0.00 | 0.500 | 0.925 | 0.995 | 4.050 | 200 | 27.00 |
| completionist | 2 | 0.50 | 0.80 | 0.630 | 0.970 | 1.000 | 4.660 | 200 | 27.00 |
| completionist | 3 | 0.00 | 0.00 | 0.120 | 0.375 | 0.710 | 1.050 | 200 | 27.00 |
| completionist | 3 | 0.00 | 0.80 | 0.190 | 0.600 | 0.890 | 1.470 | 200 | 27.00 |
| completionist | 3 | 0.35 | 0.00 | 0.340 | 0.700 | 0.940 | 2.115 | 200 | 27.00 |
| completionist | 3 | 0.35 | 0.80 | 0.470 | 0.875 | 0.970 | 2.605 | 200 | 27.00 |
| completionist | 3 | 0.50 | 0.00 | 0.435 | 0.840 | 0.990 | 2.600 | 200 | 27.00 |
| completionist | 3 | 0.50 | 0.80 | 0.510 | 0.885 | 0.985 | 3.075 | 200 | 27.00 |

## Top 5 most-reached pairs overall (ever ripe at any break, any of the 24 cells)

- tumbler_bearing/mass: 1949
- cross_split/kinetic: 1429
- spiral_wave/split: 1402
- chain_arc/anchor: 1292
- impact_driver/kinetic: 610
