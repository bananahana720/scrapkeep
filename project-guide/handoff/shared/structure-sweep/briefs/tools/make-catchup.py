"""Write a catch-up brief for a finished unit that fell behind the integration branch.

Usage: python3 -I make-catchup.py <full gate tip SHA> <output dir>
Safe to rerun: it overwrites the files it writes and nothing else.
"""
import pathlib
import sys

GATE, OUT = sys.argv[1], pathlib.Path(sys.argv[2])
assert len(GATE) == 40, "pass the full 40-character SHA of origin/entropy/gate"

GODOT = """Start every shell line with `export PATH=/opt/homebrew/bin:$PATH GODOT_BIN="$HOME/Applications/Godot_4.7.2.app/Contents/MacOS/Godot"`, and run Godot only with `HOME` set to a scratch folder under `artifacts/local/` as the rules page says. After your last commit make one call of `npm run sketch:fast -- --base {gate}`. It picks tests from the changed files; make sure every test file the unit changed and those found by `git grep -l -i -E '{grep}' -- sketches/core-loop/tests` ran, and if any did not, run them in one more call with `--test` (on this repo `--test` replaces the automatic selection, so that second call is in addition to the first, not instead of it). Then `npm run sketch:lint`. `npm run sketch:fast` may wait several minutes for a machine slot before it starts: that is normal, wait for it, and make one call rather than several. Known failures that are not yours: `tests/profile_purity_test.gd` and `tests/slice1_patch_and_w1_craft_test.gd` are red on the base, and `tests/fub_ramp_flash_test.gd` can fail when it runs after `tests/enemy_ramp_flipper_asset_test.gd` in one process; rerun any other red alone before you call it red."""

NODE = """This unit changes no Godot file, so do not run Godot or `npm run sketch:fast`. Start every shell line with `export PATH=/opt/homebrew/bin:$PATH`. Run, after your last commit: `npm test` (it must now go through the runner); `node scripts/ci/node-tests.mjs --shuffle`; each shard form the CI workflow uses (read `.github/workflows/ci.yml` for the exact calls, run each, and check that the shards together run every file exactly once); `npm run lint:js`; `npm run format:check`; `npm run check:project`; `npm run check:docs` if you changed a Markdown file. A known failure that is not yours: `scripts/budget-audit.test.mjs` can be red on the base; check it on the base before you call it yours."""

UNITS = {
    "s2": dict(
        unit="S2", pr=1293, branch="entropy/s2-node-test-discovery",
        head="f0d01f69145c46ba83f7bfc12f0e744a2b09aa28",
        what="makes `scripts/ci/node-tests.mjs` list the Node test files from the disk, so that a new test file cannot be left off a hand-kept list, and replaces the `\"test\"` line of the root `package.json` with `node scripts/ci/node-tests.mjs`. It changes three files: `package.json` (that one line), `scripts/ci/node-tests.mjs` and `scripts/ci/node-tests.test.mjs`",
        conflicts="`scripts/ci/node-tests.mjs` and `scripts/ci/node-tests.test.mjs`. Since the unit was written, the integration branch gave the runner duration-balanced shards (`--shard INDEX/TOTAL`, `DURATION_HINTS_MS`), a seeded `--shuffle`, and a mode that keeps unbundled Node tests under `--ci-godot-only`; today the runner still reads its file list out of the `\"test\"` line of `package.json`",
        extra="**The `package.json` line.** The rules page forbids touching `package.json`. This unit is the one exception: Andrew approved exactly this one-line edit on 27 November 2026. Change that line and nothing else in the file: no dependency, no other script, no lock file. Keep every option the runner has today (shards, hints, shuffle, seed, the Godot-only mode) working as it does now, with the file list coming from the disk in place of `package.json`. Read every caller of the runner first: `git grep -n 'node-tests' -- .github scripts package.json CONTRIBUTING.md AGENTS.md project-guide`. A test file on disk that must not run in the plain `npm test` (a fixture, a file another command runs) goes on one short exclusion list in the runner with a reason beside it in a test assertion, and a test in `scripts/ci/node-tests.test.mjs` fails when a `*.test.mjs` or `tests/*.test.js` file on disk is neither run nor on that list. `scripts/godot-home.test.mjs` must be among the files that run.",
        done="`npm test` runs the runner; `git grep -n 'node --test' -- package.json` shows nothing; the runner holds no hand-kept list of files to run; the shard forms CI uses still partition every file exactly once; `git diff {gate} -- package.json` shows one changed line.",
        checks=NODE,
    ),
    "x1": dict(
        unit="X1", pr=1323, branch="entropy/x1-experimental-duplicates",
        head="a3eabfc9beb6e1ce879752dbf6e32cc766f0f14b",
        what="routes the experimental `never_brake` calls to `EventDirector` (Part A) and gives the environment-tag vocabulary, the payload builders and the validators one owner in `src/experimental/env_tags.gd` (Part B). Findings `XD-02` and `XD-03` in `git show origin/entropy/records:project-guide/handoff/shared/structure-sweep/experimental-dev.md`",
        conflicts="none in text (`git merge-tree` reports a clean merge), but more than thirty units landed since its base, among them one that changed `src/experimental/live_run_bridge.gd`, `src/dev/` and the experimental audio bank, and one that added `clear_families()` to `src/world/event_director.gd`. A clean text merge can still leave a caller on a name that no longer exists",
        extra="`src/world/event_director.gd` is covered by a formal model: after the merge, say exactly which of its lines differ from the integration tip because of this unit.",
        done="the unit's two parts are intact on top of the integration tip; `git grep` for each name the unit moved or deleted shows no stale caller in `src/`, `tests/` or `tools/`.",
        grep="experimental|env_tag|never_brake|setpiece|encounter|adversity|refurbished|live_run|live_world",
        checks=GODOT,
    ),
    "c4": dict(
        unit="C4", pr=1324, branch="entropy/c4-event-juice",
        head="9abf33025356d190a6b8ae0c74dae08e60dc6db3",
        what="moves the display weighting out of `src/core/event_kinds.gd` into `src/presentation/event_juice.gd`, so that a `core` file no longer holds presentation data (24 files, mostly callers and tests). Finding `CORE-04` in `git show origin/entropy/records:project-guide/handoff/shared/structure-sweep/core.md`",
        conflicts="`sketches/core-loop/src/core/event_kinds.gd`, `sketches/core-loop/tests/combat_juice_elevation_test.gd` and `sketches/core-loop/tests/unit/weight_table_case.gd`. Units that landed since moved the shared weight-table helper and several core tables",
        extra="If a landed unit already moved part of what this unit moves, keep the landed form and drop this unit's copy of that part; say which. A new script needs its `.gd.uid` file committed beside it.",
        done="`src/core/event_kinds.gd` holds no display weighting (give the grep); every reader of the moved names in `src/`, `tests/` and `tools/` reads `event_juice.gd`; no forwarding copy stays in `event_kinds.gd`.",
        grep="event_kinds|event_juice|juice|weight_table|event_director|combat_juice",
        checks=GODOT,
    ),
    "f1": dict(
        unit="F1", pr=1325, branch="entropy/f1-fx-pools",
        head="265f34a0b20f09ab20155bfa4a91c84cf999c0f7",
        what="puts the owner-filtered effect pools in `src/presentation/fx_library.gd` (finding `VF-02`) and removes the `SpecialCues` forwarders from `src/presentation/machine_fx.gd` (finding `VF-13`); four files. The findings are in `git show origin/entropy/records:project-guide/handoff/shared/structure-sweep/visuals-fx.md` (list the folder with `git ls-tree --name-only origin/entropy/records project-guide/handoff/shared/structure-sweep/` if that name is not there)",
        conflicts="`sketches/core-loop/src/presentation/vfx.gd`. A unit that landed since split `vfx.gd` into several files, so the lines this unit changed may now live in another file under `src/presentation/`",
        extra="Find where each line this unit changed in `vfx.gd` lives now (`git log --oneline --first-parent -- sketches/core-loop/src/presentation/vfx.gd` on the integration tip names the split) and apply the unit's change there.",
        done="one pool implementation, in `fx_library.gd` (give the grep that shows no second copy); `machine_fx.gd` holds no `SpecialCues` forwarder and every caller calls the owner.",
        grep="fx_library|machine_fx|special_cues|vfx|fx_pool|pool|bead|burst",
        checks=GODOT,
    ),
}

TEMPLATE = """You are bringing unit {unit} of the Scrapkeep structure sweep up to date. Scrapkeep is a Godot 4.7.2 GDScript game under `sketches/core-loop` with a Node toolchain under `scripts/`. The sweep removes duplicate code, wrong-way dependencies and private reach-ins without changing anything a player or a test can observe. Another session wrote this unit earlier; it is finished and pushed, but it has fallen behind the integration branch. Your job is to merge the integration branch into it, keep the unit's change intact, prove it still holds, and push. You add no new work to the unit.

## Read first

Run `git fetch origin`. Read `git show origin/entropy/records:project-guide/handoff/STRUCTURE-SWEEP.md`, the section "Rules for every writer": its hard limits, checks and hand-in rules bind you. Read `AGENTS.md` in your checkout.

## The unit

Unit {unit} is pull request {pr} (https://github.com/bananahana720/scrapkeep/pull/{pr}), branch `{branch}`, head `{head}`. It {what}. Read its commits (`git log -p {gate}..{head}`) before you merge, so you know what it changed and why.

## Set up

Your checkout may start on another commit, and the branch name `{branch}` may be checked out in another checkout on this machine, so work on a local branch of your own and push to the unit's branch:

```
git fetch origin
git switch -c {unit_lower}-catch-up {head}
git rev-parse HEAD
```

`git rev-parse HEAD` must print `{head}`; stop with `BLOCKED` if it does not. Then follow the set-up steps of the rules page (`npm run worktree:deps`, the scratch `HOME`, the import).

## The work

1. `git merge {gate}` (the integration tip; check that `git rev-parse origin/entropy/gate` contains it with `git merge-base --is-ancestor {gate} origin/entropy/gate`). Known conflicts: {conflicts}. Resolve each by hand so that both sides' intent survives: the integration branch's later changes stay, and the unit's change is applied on top of them. Say which files conflicted and how you resolved each.
2. After the merge, for every name the unit moved, renamed or deleted, search the whole tree for a stale use (`git grep -n -F '<name>' -- sketches/core-loop scripts`), including `.tscn`, `.tres` and string calls such as `call("name"`. Fix each stale use by pointing it at the unit's owner. Check the other way too: that the unit uses no name a landed unit moved.
3. In `scripts/sketch-lint.baseline.json` keep the integration branch's lists; remove only an entry the lint reports as `no longer offends`; never add an entry and never pass `--write-baseline`.
4. {extra}

Limits: nothing a player, a test or a tool can observe changes. No test is deleted or weakened; a test changes only to follow a moved or renamed call. Add no code comments. Do not start sub-agents. Run every command in the foreground to completion and never end your turn while a command runs. Other units are in flight in most directories, so change only this unit's files and the lines the merge forces, and list every line you changed outside the unit's own files.

Done looks like: {done}

## Checks

{checks}

## Hand in

Push with `git push origin HEAD:{branch}` (if the push is declined, do not try another way: report `BLOCKED` with the local commit SHA). Do not open a new pull request; pull request {pr} follows the branch. Lead your final message with `PASS`, `ISSUES` or `BLOCKED`. Give the integration tip you merged, the files that conflicted and how you resolved them, the stale uses you fixed, the `git grep` output behind "done looks like", the last lines of each check, and your model and effort. End with the line `PR https://github.com/bananahana720/scrapkeep/pull/{pr}, head <SHA>, checks and reviews <state>`.
"""

OUT.mkdir(parents=True, exist_ok=True)
for key, u in UNITS.items():
    fields = dict(u, gate=GATE, unit_lower=key)
    fields["checks"] = u["checks"].format(gate=GATE, grep=u.get("grep", ""))
    fields["done"] = u["done"].format(gate=GATE)
    path = OUT / f"catch-up-{key}.md"
    path.write_text(TEMPLATE.format(**fields))
    print(path.name, len(path.read_text().split()), "words")
