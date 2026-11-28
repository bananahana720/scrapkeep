"""Units of round 18, read by make-round.py. C5 moves four dependency-free helper scripts down into src/core and deletes three dead compatibility paths."""
import pathlib
import runpy

_R12 = runpy.run_path(str(pathlib.Path(__file__).with_name("units-r12.py")), init_globals=dict(BASE=BASE, DELETE=DELETE, NODE_CHECKS=NODE_CHECKS, GODOT_CHECKS=GODOT_CHECKS))
NO_CALLER = _R12["NO_CALLER"]
DELETE_RULES = _R12["DELETE_RULES"]
POOL = "the task pool, `git show " + BASE + ":project-guide/handoff/shared/structure-sweep/pool.tsv`"
SURVEY = "`git show " + BASE + ":project-guide/handoff/shared/structure-sweep/"
UNITS = {
    "C5": dict(
        branch="entropy/c5-leaf-scripts-into-core",
        findings="Findings `CORE-02` and `CORE-13` in " + SURVEY + "core.md`, finding `COMBAT-01` in " + SURVEY + "combat.md`, and the rows `CORE-02`, `CORE-13`, `COMBAT-01` and `VF-03` of " + POOL + ". "
        "The survey is five days old and more than sixty units have moved code since, so confirm every count and every name in the code before you rely on it; where the code and the survey differ, the code is right and your report says what differed. "
        "Two things already differ: `word_budget.gd` is in `src/core/` already, and the reduced-motion setting already has its owner, `src/core/comfort.gd`.",
        body=(
            "The game's code is layered: `src/core/` is the bottom, and a file there should load nothing from the folders above it (`movement`, `combat`, `world`, `build`, `boss`, `ui`, `presentation`). "
            "Several small helper scripts that load nothing themselves sit in upper folders and are loaded by `src/core/` and by many folders at once, which makes every one of those loads point the wrong way. This unit moves four of them down, and deletes three dead compatibility paths in `src/core/`. It changes nothing a player meets.\n\n"
            "**Part 1, move four scripts into `src/core/`.** The four, each with its `.gd.uid` file: `src/movement/speed_tier.gd`, `src/world/director_cards.gd`, `src/combat/boss_posture.gd` and `src/presentation/flash_guard.gd`. "
            "First prove each is a leaf on your base: it has no `preload(`, no `load(`, no `extends` of a script path, and names no global class that lives above `src/core/`. If one is not a leaf, leave it where it is and say why. "
            "Check that no file of the same name already exists in `src/core/` and that no global `class_name` would collide. "
            "About 260 files name one of the four paths (most are tests), so do not edit by hand: write a small script that moves each file and its `.gd.uid` with `git mv` and rewrites the old `res://` path to the new one in every tracked text file that may be changed "
            "(`.gd`, `.tscn`, `.tres`, `.cfg`, `.json`, `.mjs`, `.py`, `.sh`, and the live pages `sketches/core-loop/ARCHITECTURE.md`, `CONTRACTS.md`, `VISUAL-LANGUAGE.md`, `src/build/SEAMS.md` and `src/presentation/world_fx/WORLD-FX.md`). "
            "The script must refuse to run on a dirty tree, print what it changed, and change nothing on a second run. Run it, keep it out of the repository, and paste it whole in the pull request's description so the Gate can rerun it after a merge. "
            "Never rewrite a dated record: the survey files, `sketches/core-loop/DESIGN-NOTES.md`, anything under `project-guide/handoff/shared/`, receipts, ledgers and dated design specs keep the old path; list the old-path hits you left and why each is a record. "
            "Do not move `src/combat/pack_pressure.gd` although the survey lists it: `scripts/sketch-lint.mjs` names its path and another unit holds that file. Say so in the report. "
            "Paths can be built from parts or matched by a pattern: search for each file's base name (`speed_tier`, `director_cards`, `boss_posture`, `flash_guard`) as well as its full path, in `scripts/`, `.agents/`, `.github/` and `sketches/core-loop/tools/`, and in every guard test that holds a list of files or folders (`tests/unit/*_case.gd`, `tests/*_owners_test.gd`, the layer and loop lists). "
            "A guard that holds an exact list naming an old path must name the new one; a guard that counts loads from `src/core/` to the folders above it must now find fewer, and its pinned list or number shrinks to match. "
            "A scene or resource that refers to a script by `uid://` keeps working because the `.uid` file moves with the script; where the same line also holds a `path=`, the script must have updated it. "
            "Leave no forwarding copy at an old path.\n\n"
            "The lint's lists in `scripts/sketch-lint.baseline.json` only shrink. Moving these files should let entries leave the list of script dependency loops (rule `L16`) and perhaps others: remove every entry `npm run sketch:lint` says no longer offends. "
            "If an entry names one of the moved files by its old path and the offence is still there at the new path, the entry is renamed, not added: keep the count the same, and say which entries you renamed. Do not edit `scripts/sketch-lint.mjs`.\n\n"
            "**Part 2 (CORE-13), three dead compatibility paths.**\n\n"
            + DELETE + "\n\n" + NO_CALLER + "\n\n" + DELETE_RULES + "\n\n"
            "(a) `src/core/meta_options.gd` and `src/core/work_orders.gd` ask `profile.has_method(\"camp_get\")` and `profile.has_method(\"camp_set\")` before reading or writing the camp box. The survey found no `func camp_get` or `func camp_set` anywhere. "
            "Prove no object that reaches those functions has either method: list every class and every test double passed as `profile` to the functions that hold the branches (search `tests/` for a stand-in profile that defines `camp_get` or `camp_set`). If none does, delete the branches. "
            "The survey also says the two files each keep their own copy of the same read-change-write of `profile.camp()`: if the two helpers are the same after the dead branches are gone, give them one home on the module that owns the camp box and delete the other; if they differ, say how and leave them.\n\n"
            "(b) `src/core/run_moments.gd` asks `ResourceLoader.exists` for `res://src/core/scrapbook_store.gd`, a tracked file that is always there, and keeps a copy of the store's save code for the case that it is not. "
            "Show the fallback cannot run in the game or in an exported build (find how the export decides which scripts ship, and whether any export preset or test removes the store), then load the store directly and delete the fallback. If a test runs the fallback on purpose, say which and stop this part.\n\n"
            "(c) `const BRINDLE_COBALT_PICK := true` in `src/core/worlds.gd` has one reader, a branch in `src/boss/boss.gd` that returns early only when the constant is false. Delete the constant and that half of the condition. "
            "`tests/boss_pickup_asset_test.gd` pins a hash of one function of `boss.gd` (`BASE_LOGIC_SHA`, over the `_spawn_pickup` slice): find out whether the line you change is inside the pinned slice. If it is, do not change the pin and do not do (c): report it.\n\n"
            "Commit Part 1 on its own (one commit for the move and the rewritten paths, so the diff is a pure rename plus path strings), then each of (a), (b) and (c) on its own. Add no code comment except a tool-read line or a note on an engine or operating-system quirk."
        ),
        done="the four scripts and their `.uid` files live in `src/core/`, no tracked file that may be changed names an old path, no forwarding copy is left, every guard list and lint list that changed only shrank or renamed, and the move commit changes no line that is not a path; "
        "each of the three compatibility paths is deleted with its proof, or kept with the reader or pin named; `npm run sketch:lint` passes; and the report holds the script, the count of files it changed, and the old-path hits left in records.",
        flight="Other units are in flight, and this unit's move touches one line in many files they also touch. One moves the source reads of guard tests onto the shared reader and adds a lint rule: do not edit `sketches/core-loop/tests/support/source_scan.gd`, `scripts/sketch-lint.mjs`, `scripts/sketch-lint.test.mjs` or `sketches/core-loop/tests/test_tool_owners_test.gd`, "
        "and in any other test change only the path string. One works in `src/ui/screens.gd`, `src/ui/hud.gd` and `src/presentation/codex_banner.gd`; one in `src/presentation/craft_prop_meshes.gd` and `tests/mesh_census_test.gd`; "
        "one, with its reviewer, deletes single lines in `src/combat/enemy.gd`, `fleet.gd`, `splitter.gd`, `ultimate.gd`, `src/world/events/storm_seek.gd`, `tools/test_batch_driver.gd` and `tests/test_batch_reset_test.gd`. In all of those files change only the path string of a moved script. "
        "The integration branch will move while you work. Before your last check, merge `origin/entropy/gate` into your branch (never rebase or force-push), run your script again so paths that arrived with the merge are rewritten too, and commit that as its own commit. "
        "If the only conflict is in `scripts/sketch-lint.baseline.json` and both sides only removed entries, keep an entry only where both sides kept it.",
        checks=GODOT_CHECKS.format(base=BASE) + " With this many files changed the call will pick most of the test suite and can take half an hour: start it once and wait for it. "
        "If a model page under `.agents/skills/scrapkeep-verify-formal/references/` names a file you moved or changed, say so in the report with the old and new path; do not edit the model pages.",
    ),
}
