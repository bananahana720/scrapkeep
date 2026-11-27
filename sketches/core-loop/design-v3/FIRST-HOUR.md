# First-hour progression: the shift board

World 1 unit 16 (historical unit card `/mnt/project-files/world1/UNITS.md`). What a new player unlocks and learns across
their first world 1 runs, how camp shows it, and the hooks the later variation layer plugs into.
Code: `src/core/shift_board.gd` (rows and reads), `src/core/achievements.gd` (the six
`brindle_mark_*` grant rows), `src/core/progress.gd` (the time card), `src/build/parts.gd`
(`opened_items`), `src/ui/achievements_page.gd` (the board strip), `src/ui/screens.gd` (the summary
line). Test: `tests/shift_board_test.gd`.

## What it is

A board on the camp's trophy wall, the pump crew's shift board. Each rung is one thing to do in
the Spillway, inked with a stamp when it lands (CLOCKED IN, LOGGED, HIRED, FOUND). The wall always
names the next rung and what it opens. A time card beside it takes one punch for every finished
run that stamped nothing, and every full card opens an item. So every finished run, a loss
included, moves one mark: a stamp or a hole.

The HIRED stamp is the Mind's motif (principle 7, "All hands"): the foreman hires its hands, and
the crew's board uses the same ink. Each pilot's Brindle mark is a HIRED stamp under their name.

## Runs 1 to 5 for a new player (Sable only, world 1)

| Run | What usually happens (inference from bot medians, not a measured person) | Board | Opens |
| --- | --- | --- | --- |
| 1 | Dies on the dam or early flume | CLOCKED IN: finish a shift | Salt Skip trail |
| 2 | Breaks the dam Warden, dies in the flume | LOGGED: Warden Breaker | Any Night paint |
| 3 | Finds Rivet's cage, or nothing new | HIRED: Rivet, or a time card hole | Rivet, or 1 of 3 holes |
| 4 to 5 | Routs Brindle | HIRED: Brindle Routed and Sable's Mark in one run | Tarn; Strike Pocket joins the pools next run |
| After | Flies Rivet or Tarn to Brindle; looks for the flume weir tape | Rivet's Mark, Tarn's Mark, FOUND: Lost Tape | Clean Break, Warhead Slug; the tape in the jukebox |

Rows the board reads already existed (salt skip, Warden, Rivet, Brindle). The new grant rows are
the six marks. A mark for a pilot the profile cannot fly stays off the board, so a new player sees
three marks they can chase (Sable, then Rivet and Tarn as they sign on), not six.

## Why this shape (references, and what was rejected)

- **Isaac completion marks.** Isaac unlocks an item per character per boss (the completion-mark
  grid), so trying a new character on a known boss pays. The Brindle marks are that, scoped to
  world 1's one boss. Items open into the pool rather than handing power to the player, which is
  Isaac's own rule: unlocks widen what can appear, they never buff.
- **Hades: every run pays something.** Hades gives a meta currency even on a death. We have no
  currency (PROGRESSION.md section 4 rule 10), so the time card is the currency-free version: a
  hole you can see, three holes open a named item. It only punches when nothing else landed, so it
  never competes with a real stamp.
- **Risk of Rain 2: unlocks as lessons.** Each rung's text is what to try next (break a core,
  ram the cage, fly another pilot to Brindle), so the board doubles as a curriculum.
- **Rejected: a meta-currency shop** (Rogue Legacy, Hades' mirror). It adds stats, which breaks
  "nothing persistent adds a stat", and a price list is outside alpha scope (Andrew holds
  currencies, W13-INTEGRATION-3 section 6).
- **Rejected: locking items a fresh profile has today.** That would shrink the first run's pool and
  move every band and bot proof. The board opens items the park table does not list, so a fresh
  profile and every bot run see exactly today's pool.
- **Rejected: a cumulative grind count** ("break 500 machines"). A rung is one run's
  accomplishment; the time card is the only cross-run count, it needs a finished run with at least
  five kills (so quitting or a deliberate early death does not farm it), and it caps at three cards.

## Rules kept

- Nothing persistent adds a stat. Opened items join the offer pool at the rarity their row has;
  the wave 20 rung table (item ladder) maps them to its colours with every other item.
- Overpowered pays: an opened item is one more way to break the game, never a tax.
- No time gates, no dailies, no currency.
- The sitting profile shows every mark (it opens every pilot) but never saves, so a sitting cannot
  earn a stamp. See "For the world 1 sitting" below.

## Data schema

`ShiftBoard.RUNGS`, id to row, in board order:

| Field | Meaning |
| --- | --- |
| name | 3 words or fewer, the stamp caption |
| text | 12 words or fewer, shown while it is the next rung |
| when | `{"earned": <achievements.gd id>}` or `{"tune": <tune_rows.gd id>}` |
| stamp | one of CLOCKED IN, LOGGED, HIRED, FOUND |
| pays | one of `pilot`, `cosmetic`, `item`, `tune`, `option` to an id; must equal the earned row's reward |
| pilot | optional: the mark's pilot; the rung shows only once that pilot is open |

`ShiftBoard.TIME_CARD` (`holes` 3, `min_kills` 5) and `ShiftBoard.CARDS` (three, each pays one
item). The punch count is the profile stat `shift.punches`; everything else is read from earned
rows and heard tunes, so a profile that earned a row before the board existed shows it stamped.

Achievement rows gain an optional `pilot` field (the fact counts only while the run flies that
pilot) and a reward kind `item` (the settle is the grant; the board reads the earn).

`ShiftBoard.SEEDS`: the layered variation hooks (stage variants and run modifiers, Andrew's 23 Oct
note: Isaac-style variant floors, never copied). Each names the rung that opens it. `src/core/shift_variants.gd`
(`BUILT`) implements `overtime`, `dam_night_shift`, `crew_short`, `malpais_monsoon`, and `highdraft_eclipse`;
`flume_backwash` remains seeded in `ShiftBoard.SEEDS` without a variant handler yet.

| Seed | Kind | Opened by |
| --- | --- | --- |
| dam_night_shift | stage variant | Brindle Routed |
| flume_backwash | stage variant | Rivet's Mark |
| overtime | run modifier | Warden Breaker |
| crew_short | run modifier | Sable's Mark |

## Item picks

Each opened item is a rare, every-pilot row with no seam, chosen for a pinball verb (principle 15):

| Rung | Item | What it does |
| --- | --- | --- |
| Sable's Mark | Strike Pocket | third rebound in 4 s strikes double |
| Rivet's Mark | Clean Break | killing blows crack nearby plating |
| Tarn's Mark | Warhead Slug | smashes hit plating 35% harder |
| Kest's Mark | Ring Wave | impacts emit a pulse ring |
| Tally's Mark | Salvage Drone | kills sometimes pull in mass |
| Cannon's Mark | Scrap Geyser | pickups sometimes burst pins |
| First Card | Spring Hull | rebounds throw you harder |
| Second Card | Shock Liner | hits taken arc back (wet machines conduct) |
| Third Card | Rebound Skin | after a rebound, hits glance for 1 s |

## How it shows

- **Trophy wall page:** three lines over the achievement list: "SHIFT BOARD 3 of 6 stamped",
  "Next: Rivet Freed. Find the cage on the dam and ram it open. Signs on a pilot.", and the card
  "Time card ●○○ Full card opens Spring Hull".
- **Run summary:** one line, "Shift board: Rivet Freed, Brindle Routed, Sable's Mark (HIRED)." or
  "Time card punched, 2 of 3." or "Time card full: First Card pays Spring Hull next shift." A run
  that stamps under more than one stamp says each stamp once, after its deeds ("Shift board: CLOCKED IN;
  Warden Breaker (LOGGED)."), and Clocked In is the stamp alone.
- Earns still toast as before (achievement rows), with the pilot beat line for Rivet and Tarn.

## For the world 1 sitting

The sitting profile never saves, so the board cannot be felt across a repeatable sitting on that
profile. The world 1 sitting build (unit 24) should launch on a fresh real profile (or a fresh
throwaway save folder) if Andrew is to see runs 1 to 5 open things. Flagged to the coordinator.

## Follow-ups (not in this unit)

- A physical board prop at the trophy wall with ink stamps (Blender kit, needs a board first).
- A stamp sound: a short rubber-stamp thunk, HIRED gets the brass hit from the Mind's motif.
- Secrets unit rows (fresh-profile walls, the timed Brindle door) join as FOUND rungs.
- Once the panel core lands, a rung may open a panel silhouette instead of an item.
