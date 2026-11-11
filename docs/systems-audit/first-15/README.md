# The first 15 minutes (pass E, world 1)

**What this page says.** On the park maps, world 1 teaches every mechanic before it asks for it. The [first-timer audit](first-timer-report.md) passes for all six pilots, after two fixes to the audit itself (section 4). The order goes wrong in two places:

- **The first 12 seconds.** Seven or eight lessons arrive while the player is still learning to roll. Three or four of them teach things the player does not need for minutes.
- **The dam Warden.** In one minute the player meets the clamp crews, the water-sheet ride and the ultimate prompt. The first real damage lands in that same minute.

After the dam, world 1 does not get harder. Damage per minute never returns to the dam Warden's level, while max hull grows by 29 to 55 in each run. The fixes sit in files other threads hold, so this pass sends them as described changes (section 5) and changes no game file.

**Read at.** `stage/alpha-w37` head `7eea9226`, 11 Nov 2026, with pass C's mechanics table (`docs/systems-audit/mechanics/README.md`, PR 773) and pass D's [feature-fit.md](../feature-fit.md). Card: [SA-E in BACKLOG.md](../../../BACKLOG.md#sa-e). Mechanics in flight are off by default and are not counted here: the fold (PR 772), Marked hull and Moss's scale (PR 768), and Heat, Reservoir and Called Shot (PR 763).

**Game minutes, not player minutes.** The evidence is bot play. Three first-timer bot runs (the `random` policy, seeds 2860 to 2862, pilots Tally, the Cannon and Sable) reach the end of world 1 in 381 to 498 seconds of play, 6.4 to 8.3 minutes. A person meeting the game for the first time reads, hesitates and dies, so "the first 15 minutes" of a real first-timer is about this same stretch: one world 1 run, from the drop to Brindle. That is an estimate; a first-timer film on Andrew's PC is the check (section 5, change 6).

## 1. The order a first-timer meets things

From the three first-timer bot runs (pace rows, [data.json](data.json) `runs`). Times are seconds of play from the drop into the dam, as the range across the three runs.

| Time | Meets | Kind | Alone? | Practised safely? | Tested | Combined with one earlier thing? |
| --- | --- | --- | --- | --- | --- | --- |
| 0 s | Roll, boost, "Find the Warden" | key prompts, objective row | three at once, though roll and the route are one idea | yes: no hits in minute 0 in any run | at the Warden | no |
| 3.4 s | The radio dial | tip | **no**: still learning to roll | n/a (music only) | never | no |
| 5 to 19 s | Harpoon | key prompt | **no** in two runs | yes | yard crew, Warden | yes: roll |
| 6.1 s | Actives | tip | **no** | not needed until a fight | n/a | no |
| 6.5 s (one run) | Mount (E) | key prompt | **no** | yes | no | no |
| 8.9 s | Wall grip | tip | **no**; it fires from the first seam hop, with no wall in view (film frame `0017`) | n/a | never | no |
| 11.6 s (Tally) | Cast times | tip | **no** | n/a | never | no |
| 66 to 94 s | First fight: the yard crew | objective row | yes | yes: 0 to 1 hits in minute 1 | yes | yes: ram and harpoon |
| 124 to 163 s | The Warden and its clamp crews | objective row, boss bar | yes | the clamp crews are the practice | yes | yes: the yard fight |
| 128 to 200 s | **Ride the water sheet up**, and the **ultimate** prompt on the same tick in two runs | objective row, key prompt | **no: two new things at once, in the Warden fight** | **no**: the damage spike is here (section 2) | yes | two at once |
| 166 to 251 s | Reward gates, then the dunk tip | objective row, tip | yes | yes (no enemies) | stage 2 Warden | yes: slam |
| 268 to 397 s | Stage 2 Warden: "Hook, shoot, smash core", then the slam prompt | objective row (three steps), key prompt | yes, one loop | the steps dim as they are done | yes | **yes: harpoon, weapon and slam, all met before** |
| 298 to 419 s | Brindle: one row a phase (shoot magnets, slam caps, bait into walls, ram the scooter) | objective rows | one phase at a time | each phase repeats its loop | yes | **yes: each phase reuses one earlier verb** |

**What works.** From the yard crew on, most new things come alone, get a safe try and are then tested. The stage 2 Warden and the four Brindle phases each combine verbs the player has already used, one loop at a time. That is the shape the card asks for. Every lesson is one line on screen: the tips are a sentence or two, and each draws on a single line (`src/ui/field_tips.gd` `TIPS`; the radio tip in film frame `0016`).

**What does not.**
- **The first 12 seconds.** These carry seven or eight lessons. The radio, actives, wall-grip and cast-time tips are not needed for minutes, and the radio is never needed. In the film, the sentence at the top of the screen changes every one to three seconds while the ball learns to roll (frames `0014`, `0016` and `0017` on the scratch branch).
- **The dam Warden.** The water-sheet ride, the ultimate prompt and the clamp crews arrive in the same fight. In the film, the first lobber shells that land fall during the ride (frames `0047` to `0070`). Lobbers can spawn earlier, from the director's cards and the dam's ledges, and the film shows none hitting the ball before the Warden. The pace rows do not record what hit the ball, so the three bot runs cannot confirm that.

## 2. Difficulty and new things, minute by minute

![New things to learn and hull damage taken per game minute](chart.svg)

Both rows come from the same three first-timer bot runs, on one clock (seconds of play). Top: lessons first shown each minute (key prompts, first-meet tips, objective rows). Bottom: hull damage taken each minute. Each value is the mean of the runs still playing; two runs are still playing in minutes 7 and 8. Numbers: [data.json](data.json).

| Minute | New things | Damage taken | Enemies alive | Where (range over runs) | Flag |
| --- | --- | --- | --- | --- | --- |
| 0 | 7.7 | 0 | 5.3 | the drop, the dam's open ground | **spike in lessons**: all of them in the first 12 s |
| 1 | 1.3 | 10 | 8.9 | the yard crew | the safe practice the card asks for |
| 2 | 3 | 74 | 11.2 | the dam Warden | **spike in damage**: one run fell to 45 of its 90 hull |
| 3 | 1.7 | 12 | 12.2 | the Warden's end, the gates | |
| 4 | 2 | 0.6 | 11.1 | the gates, the launch, the flume's start | **flat**: almost no damage |
| 5 | 0.7 | 30 | 10.4 | the flume | |
| 6 | 3.3 | 14.5 | 12.0 | the flume Warden, Brindle's start | |
| 7 | 3 | 20 | 6.3 | Brindle | |
| 8 | 1 | 12 | 6.5 | Brindle | |

What it says:
- **Two spikes and one flat stretch.** The lessons pile up in minute 0, before anything can hurt. The damage piles up in minute 2, at the first Warden. Minute 4, from the reward gates to the flume's start, asks for almost nothing.
- **World 1 does not get harder after the dam.** After minute 3 no minute comes near the dam Warden's 74, while max hull rises with every panel and heft class. The three runs go from 90 to 119, 105 to 140 and 100 to 155 ([data.json](data.json) `runs`). Brindle takes 12 to 20 hull a minute. Ruling cu says difficulty only goes up. The owner is the parked difficulty stack on `claude/w37-difficulty`, which lands at the end of the sprint. This page gives it a target: from the flume on, each minute should take at least the dam Warden's share of max hull.

## 3. Two things a first-timer is never taught

From the first-timer report. Both are optional, so neither fails the audit.

- **Scrap makes you heavier.** The first scrap comes within a second of the drop, and no lesson says what it does. The old "Scrap = heft" callout was retired (LEGIBILITY.md item 33). Pass C's table shows the heft class change has a pop, a sound and a toast, and pass C added a rumble. That is a lesson carried by shape and sound, in the spirit of ruling cx, but the audit does not count it, so this stays open rather than failed. The PC film should say whether a player notices the ball grow.
- **What cogs buy.** No probe run reaches Moss's bay. Pass D's "Moss weighs your haul" (PR 768) changes this anyway.

## 4. What this pass changed

All tools; no game file.

1. **The first-timer audit now plays the park maps.** A test-mode game with no `--table` plays the legacy default table (`src/game.gd` `_chosen_table`). So `scripts/first-timer.mjs` measured the old maps, the same blind spot the red team had before PR 761. It now passes `--table=park` by default. Running it on the park maps exposed the next fix.
2. **Brindle's lesson is the plate the park fight shows.** On the park table, Brindle's objective plate names each phase's loop from the arena's first frame (`objectives.gd` `choose`, the "boss" rows). The audit knew only the legacy rows (`break_guard`, `smash_core`), so it failed "Stagger Brindle" for all six pilots. It now counts `shoot_magnets`, Brindle's first phase row, and passes. The actives row's note now says what the probes show: a run starts with an active racked. Two tests in `scripts/first-timer.test.mjs` pin both fixes (16 of 16 pass).
3. **A pace probe.** `sketches/core-loop/tools/sysaudit/first15_pace.gd` writes one row per second of play (hull, max hull, enemies alive, hits, damage, kills), plus one row the first time each lesson shows, on the same clock.
4. **The chart script.** `scripts/sysaudit/first15-chart.mjs` builds this page's chart and data from the pace rows.

## 5. Changes to make, by owner

Each change keeps every story beat. Wording follows ruling cx: where a shape, an icon or a sound can carry the fact, it does.

| # | Change | Why (section) | Owner and file | Kind |
| --- | --- | --- | --- | --- |
| 1 | Pace the first-meet tips. Show at most one tip in the first 20 s of a run. Move the actives tip to the first moment an active is ready in a fight, the radio tip to after the first stage is cleared, and the cast-time tip to the first cast. | 7 to 8 lessons in 12 s, 4 not needed yet (1, 2) | "Rebuild game UI for clarity" (PR 764): `src/ui/field_tips.gd` | order and timing; no new rule |
| 2 | Raise the wall-grip tip on pass C's `carved` event (a real carve of 0.3 s or more), not on the first grip contact, which is a seam hop. | 1 | UI thread; `carved` is on the stage since PR 773 | wiring |
| 3 | The radio tip sends the player to the notes for its keys. Either drop it, since the radio only changes the music, or let the dial draw its own keys the first time it shows. A toast cannot draw a keycap (`field_tips.gd` header). | 1; ruling cx | UI thread: `field_tips.gd`, the radio dial | words |
| 4 | Split the dam Warden's lessons. Give the ultimate prompt its own moment, the first time the meter fills outside the fight, and make the lobber's shell something a player has dodged before the Warden: one lobber on the yard crew's ground, in reach of its route. This is harder sooner, never easier (ruling cu). | 1, 2 | the UI thread for the prompt; the wave 37 board thread or the park owner for the dam's park file (`src/world/park/park_dam.json`; check board 749 at claim) | order and layout |
| 5 | From the flume on, each minute takes at least the dam Warden's share of max hull, so world 1 keeps getting harder as the ball grows. | 2 | the difficulty stack on `claude/w37-difficulty` | numbers, end of sprint |
| 6 | A first-timer film on the PC with a pad, to check three things: the tip pacing after change 1; whether a player notices the ball grow (section 3); and how long a person takes over world 1, against the bots' 6.4 to 8.3 minutes. | 3; game minutes | PC lane, NEEDS: gpu on board 749 | evidence |

None of these is NEEDS ANDREW. Each is an order, a number, a word or a layout tweak within the rulings. Changes 1 to 4 are decided here and logged as assumptions Andrew can overturn. Change 5 is already the parked stack's job. Change 6 is the card's PC film, which this pass could not make in the cloud; it is open, not done.

## 6. Evidence and how to rerun

The raw evidence is on the branch [scratch/systems-audit-pass-e](https://github.com/bananahana720/scrapkeep/tree/scratch/systems-audit-pass-e/evidence/systems-audit-pass-e), not in the docs:
- the whole-world film: 147 frames on the software renderer, the `skipper` line, Sable, seed 1;
- the six first-timer probes;
- the pace rows.

The cloud film shows words, layout and marks truly. Colour, light and frame pacing belong to a PC film (`tools/eye_film.gd` header). The first-timer audit runs the `skipper` bot and counts all ticks, so its times differ from the pace rows. It is used here only for its verdict, taught in time or not, never for the per-minute chart.

```bash
# from the repo root, GODOT_BIN set (cloud: /opt/scrapkeep-toolchain/Godot_v4.7.2-stable_linux.x86_64)
$GODOT_BIN --headless --import --path sketches/core-loop
# the first-timer audit, all six pilots, park maps (about 25 min on 4 cores)
node scripts/first-timer.mjs --pilots=all --jobs=3 --out=$PWD/artifacts/local/sysaudit-e/park
# the pace rows, three first-timer bot runs (about 8 min, one seed per process)
for s in 2860 2861 2862; do mkdir -p artifacts/local/sysaudit-e/pace/r$s
  $GODOT_BIN --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/sysaudit/first15_pace.gd -- \
    --out=$PWD/artifacts/local/sysaudit-e/pace/r$s --policy=random --seeds=$s --table=park --until=2 & done; wait
# the chart
node scripts/sysaudit/first15-chart.mjs --pace=artifacts/local/sysaudit-e/pace --out=docs/systems-audit/first-15
# the whole-world film (about 30 min under xvfb)
node scripts/redteam/eye.mjs --persona=first-timer --film=whole --seed=1 --pilot=pylon_engineer --out=artifacts/local/sysaudit-e/eye-whole
```

The `--out` paths must be absolute for the Godot runs, which use the sketch as their working folder.

## Systems health (for the coordinator's digest)

| System group | Pass status | Top open issue | Last result | What changed |
| --- | --- | --- | --- | --- |
| Teaching (tips, prompts, plates) | E done; changes 1 to 4 to their owners | 7 to 8 lessons in the first 12 s | first-timer audit PASS, 6 of 6 pilots, park maps | the audit plays the park maps and knows Brindle's park plate |
| World 1 difficulty curve | E done; change 5 to the difficulty stack | no minute after the dam comes near the Warden's 74 hull, while max hull grows by 29 to 55 | 3 first-timer bot runs | nothing in the game |

**One finding in plain words.** The game teaches everything, but it talks most when the player can take in least. In the first 12 seconds the sentence at the top of the screen changes every couple of seconds while the player is still finding the stick, and then nothing new comes for about a minute. Moving four of those sentences to the moment they matter costs nothing. It frees the opening for the one thing it should teach: rolling.
