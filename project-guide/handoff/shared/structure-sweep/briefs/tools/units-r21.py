"""Units of round 21, read by make-round.py. M5 and M6 move the two pilot kits still inside combat.gd into child scripts, the way unit M4 moved two blocks."""
POOL = "the task pool, `git show " + BASE + ":project-guide/handoff/shared/structure-sweep/pool.tsv`"
SURVEY = "`git show " + BASE + ":project-guide/handoff/shared/structure-sweep/"

FINDINGS = (
    "Finding `COMBAT-05` in " + SURVEY + "combat.md`, and the row `COMBAT-05` of " + POOL + "; this unit does the {which} half of it. "
    "The survey is five days old and more than sixty units have moved code since, so its line ranges are wrong now and its counts may be: find the block by the function and variable names, and confirm every count in the code before you rely on it. "
    "Where the code and the survey differ, the code is right and your report says what differed."
)


def body(intro, block, example):
    return (
        "`sketches/core-loop/src/combat/combat.gd` is about 6,800 lines. " + intro + " This unit moves it into its own script that combat creates and owns. It changes nothing a player meets.\n\n"
        "**The block.** " + block + " First make the real list on your base: every function and variable that belongs to the kit, every place in `combat.gd` outside the block that calls or reads one, "
        "and every place outside `combat.gd` (`src/`, `tests/`, `tools/`, `scripts/`, `.agents/`) that does. Put the list in the pull request's description. "
        "A function or variable that the rest of `combat.gd` uses for something that is not this kit stays in `combat.gd`; where one variable is shared between the kit and something else, say which side keeps it and why.\n\n"
        "**The shape to follow.** Unit M4 (pull request 1360, merged; `git log --first-parent --grep='PR 1360' " + BASE + "`) moved two blocks out of `combat.gd` this way, into `src/combat/hero_hooks.gd` and `src/combat/consumable_runtime.gd`: read both files and how `combat.gd` creates them in `setup`, steps them, resets them and tells them about events, and make this child the same way. "
        "Do not copy the shape of `src/combat/tarn_claw.gd`, which combat finds by node name and asks `has_method` before each call. "
        "Give the child a plain file name (" + example + "; check no file or global class of that name exists) and a plain public field on combat. "
        "The child owns all of the kit's state. `combat.gd` enters it through as few functions as the kit's real entry points need, and the child reaches combat only through combat's public functions and fields: "
        "the lint's lists (`npm run sketch:lint`) only shrink, so the new file must add no entry to any of them. "
        "Where the kit needs something of combat's that is private today, prefer passing the value into the call; make a combat member public only when several calls need it, and say which you made public and why. "
        "The child's `combat` field stays untyped if typing it would put the two scripts in a dependency loop (M4 found it would).\n\n"
        "**Callers move; nothing forwards.** Every caller of a moved function or variable, in `src/`, `tests/`, `tools/` and anywhere else, is changed to reach the child. Leave no function on `combat.gd` whose body only calls the child, and no property that only reads it. "
        "The renames are mechanical: write a small script that rewrites them, run it, keep it out of the repository and paste it whole in the pull request's description, so it can be run again after a merge. It must change nothing on a second run. "
        "Where a caller asked `has_method(\"<moved function>\")` before calling, it now asks whether the object has the child (M4 used `get(\"consumables\") != null`); then every test stand-in for combat that defined the old function must get the child field, or its test would pass without testing anything: list each stand-in you changed. "
        "Never rewrite a dated record: the survey files, `sketches/core-loop/DESIGN-NOTES.md`, anything under `project-guide/handoff/shared/`, receipts, ledgers and dated design specs keep the old names. A live page that names a moved function (`sketches/core-loop/ARCHITECTURE.md`, `CONTRACTS.md`, `src/combat/README.md`) is corrected.\n\n"
        "**Checks that read the text of `combat.gd`.** Several tests and one source file look for words inside `combat.gd`, and a move takes text out of their sight. Search `tests/`, `tests/unit/` and `src/` for `combat.gd` and for the names of the functions you move. Known ones: "
        "`src/presentation/sound_twins.gd` pins words inside named functions of `combat.gd` (cannon functions among them); `tests/flash_comfort_test.gd` has an exemption keyed `combat.gd:exposure tint`; "
        "`tests/weapon_driver_test.gd` and `tests/w47_h2_heroes_test.gd` each hold a short list of files they read, which already names M4's two files. "
        "Where the text a check looks at moved, point the check at the new file (a path or a key changes; add your file to a list) so it still checks the same thing. Do not weaken or delete a check, and do not edit `sketches/core-loop/tests/support/source_scan.gd`. "
        "A test that scans a whole folder needs nothing. Say for each check what you changed.\n\n"
        "**Pilot ids.** The lint counts comparisons of a pilot's id against text, and the count for `combat.gd` only shrinks. M4 added `ClassDef.SABLE_ID` and `ClassDef.KEST_ID` to `src/core/class_def.gd` and compared against those in the moved code, with a test that ties each constant to its pilot row (`tests/w47_h1_heroes_test.gd`). "
        "Do the same for this kit's pilot if the moved code compares its id against text: one constant, used by the moved comparisons, and one line in a test that ties it to the row. The rows in `ClassDef.all()` keep their text ids, because `scripts/lib/game-defs.mjs` reads them from the source.\n\n"
        "**Nothing about the play changes.** The report shows each of these: "
        "(a) the order of work inside one physics step, before and after, for `_physics_process` and each other entry point that runs a step of the kit; "
        "(b) every random draw the kit makes: same generator, same moment, same order; "
        "(c) what is reset when: an attempt start, a player death, a stage change and a run's start and end clear the same state at the same moment as before, and the warm test batch (`tools/test_batch_driver.gd`) still resets everything it reset (a child with no `static var` needs nothing there); "
        "(d) every `_draw`, mesh, material and node the kit builds is parented and freed as before. "
        "Signals connected by name, `call(\"...\")`, `has_method(\"...\")`, `Callable(self, \"...\")` and deferred calls by string do not show in a plain search for a call: search for each moved name as a string as well.\n\n"
        "Move code without rewording it: apart from the receiver of a call (`combat.` in front of what used to be bare, or the reverse), a dropped underscore on a function combat now calls, and an explicit type where `:=` can no longer infer one, a moved line is unchanged; list every other line that had to change and why. "
        "After the move, delete each `preload(` constant in `combat.gd` that your move left with no user (name them in the report); leave the ones that were unused before. Add no code comment except a tool-read line or a note on an engine or operating-system quirk. "
        "Commit the move with its callers as one commit that passes its tests alone; small follow-ups (the unused preloads, a corrected page) may be their own commits."
    )


DONE = ("the kit lives in one new script under `src/combat/` that combat creates and owns the way it owns `hero_hooks` and `consumables`; `combat.gd` is shorter by about the size of the kit and holds no forwarding function or property for it; every caller in the repository reaches the child; "
        "every check that read the moved text still reads it; the lint lists did not grow; the step order, the random draws, the resets and the built nodes are shown unchanged; and the report holds the list, the script, and the count of lines `combat.gd` lost.")


def flight(other):
    return (
        "Other units are in flight. " + other + " "
        "One moves four small scripts into `src/core/` (`speed_tier.gd`, `director_cards.gd`, `boss_posture.gd`, `flash_guard.gd`) and rewrites their path wherever they are preloaded: do not touch a `preload(` line of one of those four. "
        "One moves the source reads of guard tests onto the shared reader and adds a lint rule: do not edit `sketches/core-loop/tests/support/source_scan.gd`, `scripts/sketch-lint.mjs`, `scripts/sketch-lint.test.mjs` or `sketches/core-loop/tests/test_tool_owners_test.gd`. "
        "One deletes single lines in `src/combat/enemy.gd`, `fleet.gd`, `splitter.gd`, `ultimate.gd`, `tools/test_batch_driver.gd` and `tests/test_batch_reset_test.gd`; one changes `src/world/camp_sandbox.gd` and `src/ui/camp_enemy_picker.gd`; one works in `src/ui/screens.gd`, `src/ui/hud.gd` and `src/presentation/codex_banner.gd`; one in `src/presentation/craft_prop_meshes.gd` and `tests/mesh_census_test.gd`. "
        "In those files change only the lines your move needs. The integration branch will move while you work. Before your last check, merge `origin/entropy/gate` into your branch (never rebase or force-push), run your script again so callers that arrived with the merge are rewritten too, and commit that as its own commit. "
        "If the only conflict is in `scripts/sketch-lint.baseline.json` and both sides only removed entries, keep an entry only where both sides kept it."
    )


def checks(nearest):
    return (
        GODOT_CHECKS.format(base=BASE) + " `combat.gd` is read by most of the test suite, so the call will pick several hundred tests and can take a quarter of an hour or more: start it once and wait for it. "
        + nearest + " While you work, run the nearest tests alone with one call that gives each as its own `--test <name>` argument. "
        "If a model page under `.agents/skills/scrapkeep-verify-formal/` names a function or variable you moved, say so in the report with the old and new place; do not edit the model pages."
    )


UNITS = {
    "M5": dict(
        branch="entropy/m5-tally-kit-out-of-combat",
        findings=FINDINGS.format(which="Tally"),
        body=body(
            "The kit of the pilot Tally (the dispatch wire-tapper: plates, cards, clips, ink, the bay and the link group) sits inside it as one block of about 830 lines, though three other pilots have a script of their own.",
            "The survey lists 57 functions and these variables: `plate`, `last_card`, `bay`, `link_group`, `_arcing`, `_gather_tick`, `_roll_clock`, `_restored_frame`, `tally_last_settle`, `_tally_cards`, `_cards`, `clip_post`, `_ink`, `ride_clips`, `_fly_plates`, `_fly_pulled`, `_run_settles`, `_tally_card_frame`, `tally_piece`, `_stage_clip_casts`, `_ink_mesh`. "
            "It found only three of them (`plate`, `last_card`, `_cards`) touched by `combat.gd` outside the block.",
            "for example `src/combat/tally_kit.gd`",
        ),
        done=DONE,
        flight=flight("One moves the Remembered Cannon kit out of `combat.gd` at the same time as you move Tally's, into its own file: leave every cannon function and variable alone. You will both add a line where `setup` creates the children and where `_physics_process` steps them; when you merge the integration branch, keep both lines in the order the steps ran before."),
        checks=checks("Find the tests nearest this kit by searching `tests/` for `tally` (the pilot's asset, kit and economy tests) and for each moved function name."),
    ),
    "M6": dict(
        branch="entropy/m6-cannon-kit-out-of-combat",
        findings=FINDINGS.format(which="Remembered Cannon"),
        body=body(
            "The kit of the pilot called the Remembered Cannon (the walk, the wake, the recital, exposure and its marks, the paint lanes, and the piton and recoil added later) sits inside it as two blocks of about 720 lines together, though three other pilots have a script of their own.",
            "The survey lists 46 functions in two places (the main kit, and the piton and recoil functions around `_reset_w47_h2_state` near the end of the file) and these variables: `_cannon`, `_walk`, `_wake`, `_recital_index`, `_recital_at`, `_exposure_mesh`, `_exposure_material`, `_arc_mark_mesh`, `_exposed`, `last_cannon_paint`, `_cannon_count`, `_cannon_recoil_airborne`, `_cannon_recoil_air_grace`, `_cannon_piton`, `last_cannon_piton`, `last_cannon_recoil_reset`. "
            "It found only three of them (`_exposed`, `_cannon_count`, `_cannon_piton`) touched by `combat.gd` outside the blocks. "
            "The functions near `_reset_w47_h2_state` are not all the cannon's: that reset also clears the state of the pilot Tarn's claw (it looks the claw up by node name). Move only what is the cannon's, and leave the Tarn lines where they are.",
            "for example `src/combat/cannon_kit.gd`",
        ),
        done=DONE,
        flight=flight("One moves the pilot Tally's kit out of `combat.gd` at the same time as you move the cannon's, into its own file: leave every Tally function and variable alone. You will both add a line where `setup` creates the children and where `_physics_process` steps them; when you merge the integration branch, keep both lines in the order the steps ran before."),
        checks=checks("Find the tests nearest this kit by searching `tests/` for `cannon` (the pilot's asset, look, kit and `w47_h2` tests) and for each moved function name."),
    ),
}
