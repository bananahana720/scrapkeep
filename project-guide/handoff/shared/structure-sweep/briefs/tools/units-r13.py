"""Units of round 13, read by make-round.py. All three change the game's tree."""
POOL = "the task pool, `git show " + BASE + ":project-guide/handoff/shared/structure-sweep/pool.tsv`"
SURVEY = "`git show " + BASE + ":project-guide/handoff/shared/structure-sweep/"
SURVEY_AGE = (
    "The survey is three days old and more than fifty units have moved code since, so confirm every count and every name in the code before you rely on it; "
    "where the code and the survey differ, the code is right and your report says what differed."
)
FLIGHT = (
    "Other units are in flight. One deletes dead code in `sketches/core-loop/src/combat/`, `src/build/`, `src/movement/` and `src/world/`: in those four folders change only the lines this brief sends you to, and nothing beside them. "
    "One moves the source reads of guard tests onto the shared reader `sketches/core-loop/tests/support/source_scan.gd` and adds a lint rule: do not edit that reader, `scripts/sketch-lint.mjs`, `scripts/sketch-lint.test.mjs`, "
    "`sketches/core-loop/tests/test_tool_owners_test.gd`, or the way an existing guard test reads source. {beside} "
    "If the integration branch moves while you work and your pull request conflicts, merge `origin/entropy/gate` into your branch; never rebase or force-push."
)
GUARD = (
    "**The guard.** Add one case under `sketches/core-loop/tests/unit/` (read two of its neighbours for the shape, and `tests/support/source_scan.gd` for the reader). It reads source only through `SourceScan.matching` or `SourceScan.captures` "
    "and compares what it finds with an exact list, so it fails when a new file joins and when a listed file leaves. Never read a file by hand in a guard: a guard that reads nothing must fail, and the shared reader does that for you. "
    "Prove the guard: break the rule in one file, run the case, see it fail, undo the break, and put both results in the report."
)
MODEL_PAGES = (
    " If a page under `.agents/skills/scrapkeep-verify-formal/references/` names a file you changed (`game.gd`, `audio.gd` and `combat.gd` among them), "
    "say so in the report with the functions you changed there; do not edit the model pages."
)
UNIT_SUITE = (
    " A `--test` argument replaces the tests that call would have picked from your changed files; it does not add to them. So make the one call above without it, read the list of tests it ran, "
    "and only if `unit_suite_test` is not in that list make a second call, `npm run sketch:fast -- --base " + BASE + " --test unit_suite_test`."
)
UNITS = {
    "Q1": dict(
        branch="entropy/q1-reduced-motion-one-owner",
        findings="Finding `UI-08` in " + SURVEY + "ui.md` and finding `VF-04` in " + SURVEY + "visuals-fx.md`; they describe the same problem from two sides. " + SURVEY_AGE,
        body=(
            "The player's reduced-motion setting is one yes-or-no fact, and today it is held in about fifteen places. This unit gives it one owner and deletes the copies. "
            "What a player sees with the setting on, and with it off, must not change, and neither may the settings file.\n\n"
            "**What is there on your base.** `set_motion_statics(on)` in `sketches/core-loop/src/game.gd` writes the setting into: `EnemyMotion.motion_scale` (as 0.0 or 1.0), `HighdraftFx.preferred`, `WorldFx.preferred` "
            "(a property that forwards to `reduced_motion` in `src/presentation/world_fx/world_fx_kit.gd`), and a `static var reduced_motion` on each of `AbilityBar`, `UiTokens`, `AimReticle`, `RewardView`, `MossBubble`, "
            "`src/ui/caller_tile.gd`, `ClassCard`, `PilotAntics`, `ClassPreview`, `BossPlate` and `src/presentation/flourish_player.gd`; it also calls `set_water_calm(on)` on `src/presentation/spillway_scenery.gd`. "
            "`set_reduced_motion(on)` just below it then pushes the same value into live objects: the world effects' `set_quality`, the juice object, `player_fx`, the camera, and every `HighdraftFx` node. "
            "Readers pick whichever copy is nearest. Game-rule code reads the UI's copy: `UiTokens.reduced_motion` is read in `src/boss/requisition.gd`, `src/combat/miniboss.gd`, `src/combat/pit_jaw.gd`, `src/combat/warden_reactor.gd`, "
            "`src/world/cracked_cache.gd`, two files under `src/experimental/` and five under `src/presentation/`; and about thirty files ask the question as `EnemyMotion.motion_scale <= 0.0`. "
            "List them yourself: `git grep -n -E 'reduced_motion|motion_scale|\\.preferred' -- sketches/core-loop/src sketches/core-loop/tools sketches/core-loop/tests`. "
            "Not every hit is this setting: the camera has its own `motion_scale` field that `src/presentation/juice.gd` sets to a level, and a shader has a `reduced_motion` uniform. Those are other facts fed by the setting; sort each hit before you change it.\n\n"
            "**What to build.** One small file in `sketches/core-loop/src/core/` (name it `comfort.gd`; follow how its neighbours in that folder are named and loaded) that holds the setting as one static bool, set from one place in `game.gd`. "
            "Every reader in `src/` and `tools/` reads it from there. If a reader needs the number rather than the bool (code that multiplies by the scale), the owner gives it through one function that derives it from the bool; there is no second stored value. "
            "Then delete every copy the list above names, with its setter line in `game.gd`, so `set_motion_statics` shrinks to the one write plus the calls that must do work.\n\n"
            "Rules for the cases that are not a plain copy:\n\n"
            "- A call that does work at the moment the setting changes stays as a call: `set_water_calm`, `set_quality`, anything that stops a running tween, rebuilds a mesh or sets a shader uniform. Keep each, and list each in the report with what it does.\n"
            "- A field on a live object that only mirrors the setting (read later, never acted on when it is written) goes: its readers read the owner. Do this as its own commit after the statics, and list any mirror you keep with the reason.\n"
            "- `HighdraftFx.preferred` and `WorldFx.preferred` are properties with a getter and a setter. Read what each setter does. If it only stores, it is a copy: delete it. If it does work, it becomes one of the calls above.\n"
            "- Tests set these copies directly (about thirty-six test files name `reduced_motion`, and several set `EnemyMotion.motion_scale`, one of them from a table of values). Move each onto the owner. "
            "If a test sets a scale that is neither 0.0 nor 1.0, read what it proves and keep that proof by passing the value to the function under test; do not keep a static for it. "
            "A test that sets the owner must leave it as it found it; `tools/test_batch_driver.gd` `_reset()` resets the owner after every file, in place of its `set_motion_statics(false)` call if that call no longer does what it did.\n"
            "- Do not move `src/presentation/flash_guard.gd` (the flash setting). A later unit moves it into `src/core/`; build nothing that would stop it sitting beside your file.\n"
            "- `scripts/sketch-lint.baseline.json` holds an L14 list of static variables the batch driver does not reset. Remove the entries of the statics you delete; add none.\n\n"
            + GUARD + " Here the rule is: under `res://src`, only the owner declares a static named `reduced_motion` or `motion_scale`.\n\n"
            "Keep the live pages true: if `sketches/core-loop/ARCHITECTURE.md`, `CONTRACTS.md` or `VISUAL-LANGUAGE.md` names one of the deleted copies, name the owner there instead.\n\n"
            "Commit in steps that each pass the lint: the owner and the `game.gd` write; the readers in the game-rule folders; the readers under `src/ui/` and `src/presentation/` with their statics deleted; the mirrors on live objects; the tests and the guard."
        ),
        done="one file under `src/core/` holds the setting; no other file under `src/` declares a static copy of it; `git grep -n 'UiTokens.reduced_motion' -- sketches/core-loop` finds nothing; every remaining call in `set_reduced_motion` and `set_motion_statics` is listed in the report with the work it does; the guard case fails on a new copy; no entry was added to any lint list; and the settings file and what the setting does on screen are unchanged.",
        flight=FLIGHT.format(beside="Two more units of this round run beside you: one folds duplicate sound loaders under `src/presentation/` (`foley_audio.gd`, `jolt_layer_audio.gd`, `special_audio.gd`, `sfx_bank.gd`), and one gives the UI profile one object and folds the page lists in `src/ui/screens.gd`. In `screens.gd`, `hud.gd` and `codex_banner.gd` change only the lines that read the setting."),
        checks=GODOT_CHECKS.format(base=BASE) + UNIT_SUITE + MODEL_PAGES,
    ),
    "H1": dict(
        branch="entropy/h1-sound-files-one-table",
        findings="Finding `SOUND-01` in " + SURVEY + "sound.md`. " + SURVEY_AGE,
        body=(
            "Three small files under `sketches/core-loop/src/presentation/` each load a sound file, look up its level and build a positional player, and each keeps its own table. This unit leaves one table and one way to build the player. "
            "What a player hears must not change: no level, no file, no bus, no distance curve.\n\n"
            "**What is there on your base.** `foley_audio.gd` and `jolt_layer_audio.gd` are near copies of each other: each has a `TRIM_DB` table, `path`, `stream`, `player` and `one_shot`, and a `static var _streams` cache. "
            "`sfx_bank.gd` has its own `TRIM_DB` and `FILE_SOUNDS` tables, `stream` and `trim_db`, and names the same foley and jolt-layer cues. `special_audio.gd` builds one more positional player in `presence_player`. "
            "The survey counted eight cues whose level differs between the small file's table and `sfx_bank.gd`'s (for example `zipline_whine` at -6.0 in one and -5.0 in the other). List the callers of each file with `node scripts/no-caller.mjs <file>` and with `git grep -n -w <name>` for each function.\n\n"
            "**What to build.** `SfxBank` already owns the file and level tables for every other cue, so it owns these too: one row per cue for its file and one for its level. "
            "One helper builds a positional player and plays a one-shot for any cue (keep it in `foley_audio.gd`, or name it for what it now is; pick whichever leaves fewer names). "
            "`jolt_layer_audio.gd` goes, with its `.gd.uid` file; its one game caller, `sketches/core-loop/src/combat/jolt_layer.gd`, calls the shared helper (change only its load line and its call sites there). "
            "`presence_player` in `special_audio.gd` builds its player through the same helper if the two set the same properties; if they differ in a property a player hears, keep the difference as an argument and say so.\n\n"
            "**The levels, which is where this can go wrong.** For each cue that two tables give different levels, find which table each playing path reads today. "
            "If only one path ever plays the cue, keep that path's level and delete the other row: the report names the path and the search that shows the other is never played. "
            "If both paths play it, at different levels, the game has two levels for that cue today: keep both, each named for its path, in the one table, and list them in the report as a question for a later tuning pass. Do not pick one. "
            "The same goes for a file path that differs. Add a test, beside the existing sound tests, that pins the level each path gives for every cue you touched, written from the values on the base before you change anything, and show it passes before and after.\n\n"
            "**The caches.** The two `_streams` caches become one, or become `SfxBank`'s own cache if that already does the job. Whatever holds loaded streams after your change is reset by `sketches/core-loop/tools/test_batch_driver.gd` `_reset()` or is already on a path that is; "
            "remove the L14 entries of the statics you delete from `scripts/sketch-lint.baseline.json`, and add none.\n\n"
            "**The asset registry.** `tests/asset_registry_test.gd` checks that each shipped file's row names a loader that exists. If a row names a file you delete as its loader, point it at the new loader in the same commit. No file under `assets/` changes.\n\n"
            + GUARD + " Here the rule is: under `res://src`, the files that declare a constant named `TRIM_DB` are exactly the list you end with (one, unless you show another table holds a different fact).\n\n"
            "Do not touch `audio.gd`, `ace_sequencer.gd`, `music_arbiter.gd`, `melody_lease.gd` or `music_engine.gd`, and do not split `sfx_bank.gd`: both are other units' work."
        ),
        done="each foley and jolt-layer cue has one row for its file and one for its level, in `SfxBank`; `jolt_layer_audio.gd` is deleted and nothing names it; one function builds the positional player; the pinning test shows every level and file a player hears is the same before and after; the report lists every cue whose two tables differed, with which path was live; and no entry was added to any lint list.",
        flight=FLIGHT.format(beside="Two more units of this round run beside you: one gives the reduced-motion setting one owner (it changes single lines that read the setting in many files under `src/`), and one works in `src/ui/screens.gd`, `src/ui/hud.gd` and `src/presentation/codex_banner.gd`. Stay in the sound files this brief names, their tests, the asset registry rows and the batch driver's reset."),
        checks=GODOT_CHECKS.format(base=BASE) + UNIT_SUITE + MODEL_PAGES,
    ),
    "O1": dict(
        branch="entropy/o1-ui-profile-and-page-lists",
        findings="Findings `UI-07` and `UI-04` in " + SURVEY + "ui.md`. " + SURVEY_AGE,
        body=(
            "Two changes in the UI, each its own commit. Neither may change what a player sees or what is written to disk.\n\n"
            "**Part 1 (UI-07), one UI profile object.** `UiProfile` (in `sketches/core-loop/src/ui/ui_profile.gd`) loads and saves one file, `ui-profile.json`. Two objects of it exist in a running game: `src/ui/hud.gd` makes one from `game.storage_dir`, "
            "and `src/presentation/codex_banner.gd` makes another from the storage folder `src/presentation/presentation.gd` hands it. Each holds its own copy in memory and they are reconciled only when one saves (`_merge_disk`). "
            "Make one: the game owns it and hands it to the HUD and to the banner. Read every `UiProfile.new` in `src/`, `tools/` and `tests/` first (`git grep -n 'UiProfile.new'`); other readers already go through the HUD's (`class_preview.gd`, `screens.gd`). "
            "Keep the file's name, folder and format exactly, and keep `_merge_disk`: a second game process can still write the file. "
            "A test that builds a HUD or a banner on its own must still work: where a caller passes no profile the object makes its own, in one place, and the report names which tests rely on that. "
            "Add a test that in a running game the HUD's profile and the banner's are the same object, and that a mark made through one is read through the other without a save.\n\n"
            "**Part 2 (UI-04), one list of pages in `src/ui/screens.gd`.** About twelve places in that file each spell out a list of page nodes and test `.visible` on them (`page_open`, `overlay_open`, and the guards inside the `toggle_*` functions), and six `toggle_*` functions repeat the same open and close steps. "
            "The lists differ from each other today: some leave out the jukebox and the radio, one leaves out the camp, one leaves out settings. "
            "Build one list of pages in setup and one helper that answers \"is any page other than these open\", and give the six toggles one shared helper for the open and close steps. "
            "**Keep every difference.** Each guard keeps exactly the set of pages it tests today, passed to the helper as that guard's exceptions, so the differences become visible data instead of twelve hand-typed lists. "
            "Do not decide that a difference is a bug and do not fix one: list every difference in the report (which guard, which page it leaves out) so the coordinator can record it. "
            "Before you change a guard, write down its page set from the base; after, show the set is the same. The tests that open and close pages (`git grep -l -E 'toggle_settings|toggle_help|toggle_logbook' -- sketches/core-loop/tests`) must pass unchanged.\n\n"
            "Add a test that every page node the screen owns is in the one list, so a new page cannot be left out of every guard by accident; make it fail first by leaving one out, and put both results in the report.\n\n"
            "Stay out of the radio and jukebox key handling in `screens.gd` beyond what the page list needs, and add no word to any screen."
        ),
        done="one `UiProfile` object serves the HUD and the banner in a running game, with a test that fails on two; the file on disk is unchanged in name, place and format; `screens.gd` holds one list of pages and one helper each for the guard and the toggle steps; every guard tests the same set of pages as on the base, and the report lists each difference between guards; and the page tests pass without an edit to what they assert.",
        flight=FLIGHT.format(beside="Two more units of this round run beside you: one gives the reduced-motion setting one owner and changes single lines that read `reduced_motion` in many files under `src/ui/` and `src/presentation/` (it will touch lines in `screens.gd`, `hud.gd` and `codex_banner.gd`; leave every `reduced_motion` line as you find it), and one folds duplicate sound loaders under `src/presentation/`."),
        checks=GODOT_CHECKS.format(base=BASE) + UNIT_SUITE + MODEL_PAGES,
    ),
}
