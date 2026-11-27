# Every-park intentionality check: method

Owner of the method: local coordinator (written 17 Oct 2026). The red team re-runs it every wave on the wave candidate and adds a dated results file here.

**Why it exists.** Andrew (19:54Z 17 Oct): games, and AI-built games most of all, front-load effort into the first world as trailer bait. Every level, moment and place gets deliberate intent. This check catches the Dig or the Highdraft falling behind the Spillway, and any one park going thin, before the sitting.

## 1. Run the counts (about 30 s, no Godot)

```sh
git -C <checkout> fetch origin <wave candidate, e.g. cand/alpha-w16>
git -C <checkout> worktree add <dir> origin/<wave candidate>
python3 -I project-guide/handoff/shared/alpha-status/intent-check/scorecard.py --repo <dir> \
  --json project-guide/handoff/shared/alpha-status/intent-check/results/w<N>-<sha>.json \
  --md   project-guide/handoff/shared/alpha-status/intent-check/results/w<N>-<sha>.md
```

It needs python3 and node (it runs `scripts/placeholder-gate.mjs --json`). It reads the park table (`src/core/park_defs.gd`), the six park files (`src/world/park/park_*.json`, not `park_test`), the rosters, `lore_rows.gd`, `music_rows.gd`, the `assets/music_ace` manifests, `fx_library.gd` and the boss files.

## 2. What each number means

| Measure | Source | Reads as |
| --- | --- | --- |
| Authored rows (no anchors) | `park_rows` minus `anchor_field` | hand-placed rides and landforms. Anchor fields are post lattices and inflate the raw count |
| Dressed rows | `recipe` that is a GLB, not `greybox:` or empty | real art on the ground |
| Placeholders | placeholder gate, `kind: park`, by `where` | stand-ins left in that park |
| Own-world enemy kinds | pack kinds plus `home_rows.enemy` seen in this world only | world identity. The shared elite (plated brute, winch drone) never counts |
| Events / kinds only here | `event_rows` | set pieces, and how many no other park has |
| Contraptions (kinds) | `contraption_rows` | toys. A high count with few kinds is repetition |
| Discoverables | caches, altars, bounties in `activity_rows` | the secrets you can find |
| Story fragments | `fragment` ids not starting `none_` or `ref_` | lore tied to a people or a past, not geology |
| Field notes | `lore_rows.gd` by zone (world-stage) | readable lore |
| Music sections | `clips` in the stage's ACE manifest (not `sources`, which lists render takes) | adaptive score depth |
| Distinct event sounds | event `music_cue` after alias chains in `music_rows.gd` | whether a park's named stingers really sound different |
| World-flavoured effects | world-prefixed `fx_library` specs, world material folders, world shaders | effects that say "this world" |
| Top verb (share) | the verb of the park's declared skill line (`SKILL_LINES` in scorecard.py: the route its stage page names, rows weighted by length); otherwise the most common `verb` over authored rows | the park's skill test. Each park should own one. Add a park's line to `SKILL_LINES` once its stage page declares one |
| Society share | hand-built rows (no anchor fields) whose `society` is not `none` | the people living in the place |
| Ride-fact share | hand-built rows with a `ride_fact` or a default fact for their element (`park_recipes.gd ELEMENT_FACTS`) | rows whose purpose is written down |
| Boss lines | fight code, arena dressing, music sections, codex | boss depth, a rough proxy |

## 3. How to judge

1. **Front-loading flag.** The script prints a flag when a later world totals under 70% of the Spillway on authored rows, events, discoverables, story fragments, field notes, music sections or society share, or has fewer own-world enemy kinds or unique events. It also flags any park under half the park median of authored rows.
2. **Thin is not the same as worse.** A low count is a question, not a verdict. Read the stage page (`design-v3/park/stages/N-<park>.md`) and the journey board (`design-v3/park/journeys/`) before calling it a gap.
3. **Motif coverage** (Andrew's rule, 19:37Z): world theme (own-world enemies and one master verb), skill-test areas (top verb share at least 0.4), damage types against armour, auras, cast times. Read the last three from the "Enemy auras and pilot cast times" design (`FIELDS-AND-CASTS.md`). Count them only once they are in `src/`. At w16, `aura` appears 0 times in src and there are no damage families.
4. **Enemy rosters are in `sketches/core-loop/design-v3/WORLD-ROSTERS.md`.** Use its numbers; do not re-audit.
5. **The qualitative read.** For each park, write one memorable moment and one filler stretch in a sentence each. Take them from the stage page and the journey board, and from the red team's own runs. Automated play does not judge feel.
6. **Manual checks the script can't do.**
   - Which table does the app-menu launch use? Under `ruling ep` / `eq` on `main`, `LAUNCH_TABLE := "park"` in `game.gd` (historically legacy maps at w16).
   - Do per-world scenery and effects run on park maps? Verified on park maps since World 1–3 unparking (legacy w16 `dig_scenery`/`highdraft_scenery` note is historical).
   - Does each world have a rescue? Historical w16 note (worlds 1 and 2 had rescues, world 3 had none).
7. **Gut check at wave 21.** Before the sitting, the red team plays one run per world back to back. Each player writes one line per park: "would I screenshot this?" A park with no yes is a card for Andrew.

## 4. Report

Write `results/w<N>-<sha>.md` with the table, the flags and the per-park read. Send the coordinator the new or worsened flags only, as work items. Send taste calls as card text.

## Change log

- 2026-10-17 20:15Z: music sections count `clips`, not `sources` (render takes). Stage 1 music gap withdrawn.
- 2026-10-17 20:55Z: ride-fact and society shares count hand-built rows only and include element default facts, after the parks scenery thread (PR #68) showed anchor fields diluted them (sinkhole ride facts 5% to 91%).
- 2026-10-18 03:20Z: top verb reads a park's declared skill line when it has one (flume: `flume_whole`), after the flume review found 65 swing piers outvoting the momentum line. Flume branch 5c39fa03: swing 0.49 to grind 0.91; the other five parks unchanged on it and on stage/alpha-w17 f8c87419. Weighting every route instead flipped four parks (routes are mostly bank and roll ground rides), so it was not used. Also reads named pack constants (`PACKS_SHIFT`), which broke the parser at w17.
