"""Units of round 17, read by make-round.py. Z5 deletes dead things an earlier unit had to keep because one other file still named each."""
import pathlib
import runpy

_R12 = runpy.run_path(str(pathlib.Path(__file__).with_name("units-r12.py")), init_globals=dict(BASE=BASE, DELETE=DELETE, NODE_CHECKS=NODE_CHECKS, GODOT_CHECKS=GODOT_CHECKS))
NO_CALLER = _R12["NO_CALLER"]
DELETE_RULES = _R12["DELETE_RULES"]
POOL = "the task pool, `git show " + BASE + ":project-guide/handoff/shared/structure-sweep/pool.tsv`"
UNITS = {
    "Z5": dict(
        branch="entropy/z5-dead-leftovers-with-their-holders",
        findings="The rows `LEAD-86`, `LEAD-90` and `LEAD-26` of " + POOL + ", and the row `COMBAT-12` for where the first began. "
        "Each row was written from a review, not from a fresh read of the code, and rows like these have been wrong in detail before: confirm every name and every claim in the code on your base before you rely on it; where the code and the row differ, the code is right and your report says what differed.",
        body=(
            "An earlier unit deleted game code that nothing calls and had to keep four things, because for each one a single other file still named it and that unit could not change that file. This unit deletes each of the four together with what holds it. It changes nothing a player meets.\n\n"
            + DELETE + "\n\n" + NO_CALLER + "\n\n" + DELETE_RULES + "\n\n"
            "**Part 1 (LEAD-86), `Enemy.rim_color`.** `static var rim_color` in `sketches/core-loop/src/combat/enemy.gd` is written by `src/combat/fleet.gd` from the run's class row and, by the row, read by nothing in the game. "
            "Prove it first: search for the bare name inside `enemy.gd` and its subclasses as well as `Enemy.rim_color` everywhere (other files have their own unrelated `rim_color`: a function in `projectile.gd` and a dictionary key in `damage_numbers.gd`; leave those alone), "
            "and search for a read by string (`get(\"rim_color\")`, a shader parameter or a material set from it). If something does read it, stop this part and report the reader. "
            "If nothing does, delete the field and its write, and change its holders in the same commit: `tools/test_batch_driver.gd` resets it between tests, `tests/test_batch_reset_test.gd` dirties it and asserts the reset, and `tests/status_marks_test.gd` sets it. "
            "For the two tests, remove only the lines about this field; if an assertion in `status_marks_test.gd` passes only because the field was set, that assertion was reading the field by another road and the field is not dead: stop and report. "
            "The lint keeps a list of static variables the batch driver must reset (rule `L14` in `scripts/sketch-lint.baseline.json`); if removing the field lets an entry leave that list, remove the entry, and never add one. Do not edit `scripts/sketch-lint.mjs`. "
            "Then correct the one live page that describes the field as drawn: `sketches/core-loop/CONTRACTS.md` says the plate's rim is the class colour held in `Enemy.rim_color`. Find out from the code what colour the rim is drawn in today and make the sentence say that, in plain words. "
            "`sketches/core-loop/DESIGN-NOTES.md` is a dated record: do not edit it, even where it names the field. "
            "This part deletes a field a designer once meant to drive a colour. Say in the report, in one sentence, what the design page said the rim should be and what the game draws, so the owner can decide whether the colour should come back as real behaviour; do not make it real here.\n\n"
            "**Part 2 (LEAD-90), `piece_parts` and `PIECE_GLB` in `src/combat/splitter.gd`.** No script calls them. The asset registry row `sketches/core-loop/assets/registry.d/enemy_splitter_piece.json` names `splitter.gd:piece_parts` in its `loader` field. "
            "Find out what loads the splitter piece's model in the game today (follow the model's path from the row to the code that instantiates it) and what the `loader` field is for: read the registry's own page and the tests that check registry rows (`tests/asset_registry_test.gd` among them) and say whether anything checks that a `loader` names code that exists. "
            "Then name the real loader in the row, fold the registry again with the project's own tool (find it from the registry page or `package.json`; `sketches/core-loop/assets/registry.json` is its output and must change only for this row), and delete the two names. "
            "If nothing loads the piece's model at all, the asset itself has no reader: do not delete the asset or its row, keep `piece_parts`, and report it as a delete candidate. "
            "If no check ties a `loader` to code that exists, say so in the report as a gap; add such a check only if it is a few lines in an existing registry test and passes on every row today, and otherwise leave it for another unit.\n\n"
            "**Part 3 (LEAD-26), two keys of `Ultimate.leg_state()`.** The row says the function in `src/combat/ultimate.gd` returns the keys `index` and `count` and nothing reads them. List every caller of `leg_state` in `src/`, `tests/` and `tools/` and every key each reads, including a caller that passes the whole dictionary on (to a HUD, a log line, a recorder or a save). "
            "Delete only keys that no reader anywhere takes. A key that a run log or a recording writes to disk is read by whoever reads that file: keep it and say so.\n\n"
            "**Part 4, one constant.** A unit in review reports that `const MIN_TELL_S` in `src/world/events/storm_seek.gd` is read by nothing, in its own file or elsewhere. Confirm it with the same proof and delete it; if the pull request of that unit (number 1355) has not landed on your base, the constant of the same name under `src/experimental/` is a different thing and stays.\n\n"
            "Commit each part on its own. If a listed thing has a reader, keep it and name the reader. If you find more dead code beside a listed thing, delete it only when the same proof covers it, and list it apart in the report. "
            "Add no code comment except a tool-read line or a note on an engine or operating-system quirk."
        ),
        done="each of the four is deleted with its holder changed in the same commit, or kept with its reader named; the registry row names the code that really loads the piece and the folded registry differs only for that row; `CONTRACTS.md` says what the game draws; no test lost an assertion about behaviour a player meets; "
        "`npm run sketch:lint` passes with no list grown; and the report gives, for each deleted name, the search that shows no reader.",
        flight="Other units are in flight. One moves the source reads of guard tests onto the shared reader `sketches/core-loop/tests/support/source_scan.gd` and adds a lint rule: do not edit that reader, `scripts/sketch-lint.mjs`, `scripts/sketch-lint.test.mjs` or `sketches/core-loop/tests/test_tool_owners_test.gd`. "
        "Three more change `src/ui/`, `src/presentation/damage_numbers.gd` with the craft showcase, and files under `src/experimental/`: change nothing there. "
        "If the integration branch moves while you work and your pull request conflicts, merge `origin/entropy/gate` into your branch; never rebase or force-push. "
        "If the only conflict is in `scripts/sketch-lint.baseline.json` and both sides only removed entries, keep an entry only where both sides kept it.",
        checks=GODOT_CHECKS.format(base=BASE) + " Add `--test unit_suite_test`, `--test test_batch_reset_test`, `--test status_marks_test` and `--test asset_registry_test` to that one call only if the call would not pick them by itself (a `--test` argument replaces what the call would pick, so if you pass any, pass every test the changed files need). "
        "Also run the test files once shuffled, as the rules page says for anything that touches the batch driver: `npm run sketch:fast -- --base " + BASE + " --shuffle` counts as that one call. "
        "If a model page under `.agents/skills/scrapkeep-verify-formal/references/` names a file you changed, say so in the report with what you deleted there; do not edit the model pages.",
    ),
}
