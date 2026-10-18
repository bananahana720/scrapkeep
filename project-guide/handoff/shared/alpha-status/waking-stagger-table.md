# Waking first-stagger table (for the posture-family sweep)

Measured 2026-10-18 ~00:30Z by thread "Reward overpowered builds". Tree: #98 head 8b1efb7e merged onto #104 34b649ff (MULT_MAX 3.0, hit_cap mechanism). waking.gd POSTURE_GAIN 0.565 unchanged. waking_bot_fight_test, fixed-90-fps child, seed(1), one process per column, runs in the order below (the child's 340 s wall cap was raised to 3000 s so every run finishes; the probe overrides came from env vars in a scratch tree, nothing pushed).

First stagger, seconds (boss fight length in brackets). Target for an ordinary pilot: 45-70 s.

| run | no cap (today) | hit_cap 15 | hit_cap 12 | hit_cap 8 | own contact gain 10 / floor 0.35 |
|---|---|---|---|---|---|
| brawler (completionist) seed 1 | 11.8 (28.2) | 40.0 (89.0) | 41.3 (98.9) | 43.2 (119.3) | 11.8 (28.2) |
| brawler seed 2 | 46.1 (63.1) | 46.1 (90.3) | 46.1 (94.9) | 46.1 (108.6) | 46.1 (63.1) |
| brawler seed 3 | 9.8 (38.0) | 35.3 (80.5) | 36.5 (90.1) | 39.2 (115.9) | 9.8 (33.6) |
| skipper seed 1 | 66.6 (88.3) | 66.6 (137.0) | 66.6 (146.7) | 66.6 (152.9) | 58.3 (81.1) |
| skipper seed 2 | 68.0 (88.3) | 68.0 (140.5) | 68.0 (140.3) | 68.0 (148.1) | 63.8 (101.6) |
| skipper seed 3 | 70.2 (107.3) | 70.2 (130.5) | 70.2 (137.9) | 70.2 (164.2) | not run |

The own-contact-gain column comes from the first pass, which hit the child's wall cap after five runs.

## What it says
- The one-hit fill is a ram at punch/plating about 0.9 multiplied by the inherited Dig row's contact_gain_scale 150 (x50, about 1000 posture). Any hit_cap removes it: brawler seeds 1 and 3 go from about 10 s to 35-43 s.
- Contact gain 10 does not fix it (1 + 10 x (0.9 - 0.35) is still about x6.5, enough to fill from 17).
- hit_cap does not move the skipper's first stagger at all (its hits are already under the cap), but it lengthens every later stagger: fights grow from 28-107 s to 80-164 s, because chunks 2-4 also need more capped hits.
- Lower caps buy little for the first stagger (15 → 8 adds 3-4 s) and cost a lot of fight length.

## Recommendation
hit_cap 15 to kill the spike, then centre with POSTURE_GAIN: the brawler still lands at 35-46 s and the skipper at 66-70 s, so the band is narrower than the spread between the two bots. A higher gain helps the skipper and does nothing for a capped brawler. A cap that applies only until the first stagger (or a per-chunk cap) would hold the first stagger without stretching the rest of the fight. That's a design call for the sweep, not this thread.

## Shipped on #104: hit_cap 15 until the first stagger (measured 2026-10-18 ~04:15Z)
Tree: #104 e14a51c4 (merged with cand f9f58944), waking.gd HIT_CAP 15 with hit_cap_until_stagger, POSTURE_GAIN unchanged. Same probe, one process, runs in order, alone on the box.

| run | first stagger (fight) |
|---|---|
| brawler seed 1 | 40.0 (58.6) |
| brawler seed 2 | 46.1 (63.8) |
| brawler seed 3 | 35.3 (53.0) |
| skipper seed 1 | 65.0 (116.1) |
| skipper seed 2 | 64.7 (100.0) |
| skipper seed 3 | 70.8 (121.6) |

The first stagger matches the hit_cap 15 column (the one-hit fill is gone), and the brawler's fights stay at 53-64 s instead of 80-90 s because the cap lets go after the first stagger. Still outside 45-70 s: brawler seeds 1 and 3 (40.0, 35.3 s, early) and skipper seed 3 (70.8 s, 0.8 s late). The skipper's fights are longer than in the first table because the tree now carries wave 16's close, not because of the cap (the cap never touches the skipper's hits). Centring the two bots inside one band is still the sweep's call.
