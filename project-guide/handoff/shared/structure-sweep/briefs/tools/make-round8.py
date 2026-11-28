import sys, pathlib, re

BASE = sys.argv[1]
HERE = pathlib.Path(__file__).parent
OUT = HERE / "briefs"
src = (HERE / "make-round7.py").read_text()
m = re.search(r'INTRO = """(.*?)"""', src, re.S)
INTRO = m.group(1)

FLIGHT = (
    "Other units are in flight. Do not edit their files beyond a line a rename or a moved path forces, and list every such line in your report: "
    "everything under `src/build/`, `src/boss/` and `src/movement/` (a build, boss and movement unit, in its fix round); "
    "eleven files under `src/core/` and `src/core/signal_wire.gd` (a core unit, which may also change one line in `src/combat/weapons.gd` and one in `src/world/event_director.gd`); "
    "`src/presentation/sfx_bank.gd`, `synth.gd`, `music_engine.gd`, `audio.gd` and three new files beside them (a sound unit); "
    "`src/ui/glyphs.gd`, which moves to `src/core/glyphs.gd` and changes one path line in about 23 files, with `src/ui/why_callout.gd`, `src/ui/class_preview.gd`, `src/ui/screens.gd`, one added method in `src/core/flow.gd` and one call in `src/world/world.gd` (a UI unit); "
    "`tools/bot_profile.gd`, `skill_band.gd`, `traversal_line.gd`, `bot_fairness.gd`, `tools/alpha_capture.gd`, `scripts/sketch-lint.mjs`, `src/presentation/craft/ramp.gd` and about fifty test files' reads of `screens._body` and `warden._posture` (a tests and tools unit); "
    "the five files `adversity_director.gd`, `dynamic_setpieces.gd`, `encounter_engine.gd`, `env_tags.gd` and `refurbished_elites.gd` under `src/experimental/` (a unit waiting on the owner). "
    "{siblings} Several units add lines to `tools/test_batch_driver.gd`; keep yours together in one place and to what your change needs."
)
INTRO, n = re.subn(r"Other units are in flight\..*?\{siblings\}", lambda _: FLIGHT, INTRO, flags=re.S)
assert n == 1

SPLIT_RULE = (
    "A unit before this one failed review because it split a file along a seam that was not clean: the new file took its parent into almost every function and the parent grew public functions that only the new file called. "
    "So before each extraction, list every name the moved block reads or writes outside itself. If the block needs more than a handful of calls back into its old file, or shares mutable state with what stays behind, do not move it: report the list instead."
)

UNITS = {
    "W3": dict(
        branch="entropy/w3-world-seams",
        findings="Findings `WORLD-11`, `WORLD-18` and `WORLD-10` in `git show origin/entropy/records:project-guide/handoff/shared/structure-sweep/world.md`. They name the lines, the callers and the tests. Only the parts listed below are yours.",
        body=(
            "Three parts, one commit each, in this order. Every move is byte-for-byte: no value, no order of work, no lock and no worker-thread rule changes. "
            + SPLIT_RULE
            + "\n\n"
            "**Part 1 (WORLD-11), the anchor field leaves `park_recipes.gd`.** The finding says one block of `src/world/park/park_recipes.gd` (about 626 lines: anchor-post placement, cover tagging, the level-of-detail mesh, anchor-fit boxes and the band hulls) owns seven private static caches (`_anchor_meshes`, `_anchor_fit`, `_anchor_fit_read`, `_anchor_fit_lock`, `_anchor_hulls`, `_anchor_hull_lock`, `_anchor_lod_cache`) that nothing outside the block touches, and that the rest of the file calls only six of its functions. Line numbers have moved: a unit before you made seven helpers of this file public (`load_glb`, `collider_body`, `attach_views`, `set_visibility_range`, `relative_transform`, `lift_drawn`, `band_hull`). Confirm the seam in the code. Then move the block and its caches to a new `src/world/park/park_anchors.gd`. Every caller in `src/`, `tests/` and `tools/` calls the new owner directly; `ParkRecipes` keeps no forwarding function (the finding's \"thin forwarding wrappers\" are not allowed). A moved cache that the test driver resets keeps its reset under the new owner. One exception to the baseline rule below: when a `static var` that is on the `\"L14\"` list of `scripts/sketch-lint.baseline.json` moves to the new file unchanged and cannot be reset safely (a lock, or a cache a worker thread fills), replace its old entry with the same entry under the new path; that is a move, not an addition, and you list each one in your report. `tools/park_graph.gd` hashes the files on its `TOOL_FILES` list into the `tool_sha256` line of the seven `assets/park/*/graph.json` files: if a file you change is on that list, refresh those lines the way the last change to them did (`git log -3 -- sketches/core-loop/assets/park/park_dam/graph.json`), and check that no `graph.bin` file changes. Also weigh the finding's note on the `Placer` inner class and the unused top-level `MaterialSlots` preload: remove the unused preload only if nothing reads it.\n\n"
            "**Part 2 (WORLD-18), one flag and one teardown.** (a) `static var threaded_in_bot_runs` in `src/world/terrain.gd` is read by `src/combat/fleet.gd` and `src/presentation/bake_warm.gd`, which load `terrain.gd` only for that. The finding proposes `src/core/sim_clock.gd`, which all three already load. Confirm, check the name fits what `sim_clock.gd` owns, and move it there with every reader and writer in `src/`, `tests/` and `tools/` and its reset in the test driver; `fleet.gd` and `bake_warm.gd` lose the `terrain.gd` load if nothing else there needs it (one or two lines each, the lines the move forces). (b) `Activities._exit_tree()` loads four unrelated files by path and clears their caches. Weigh moving each clear to the owner the finding names: do it only if the clear then runs at the same moment and under the same condition (`_owns_shared`) for every way the game and the tests tear down; if you cannot show that, leave it and report what you found. (c) `ParkTerrain.draw_regions`: weigh only, and report.\n\n"
            "**Part 3 (WORLD-10, seam 1 only), the mend wards and lore plates leave `activities.gd`.** The finding says about 208 lines of `src/world/activities.gd` own `wards` and `plates` and nothing else, and that the rest of the file enters through `_build_wards_and_plates`, `_watch_ward`, `_watch_plate`, `_on_surface_changed` and the clear. Confirm it, and check every reader of `wards` and `plates` in `src/`, `tests/` and `tools/` (tests read them through the activities object). If the seam is clean, move it to one new file under `src/world/` that owns that state, with a small set of calls from `activities.gd`; readers outside go to the new owner. If it is not clean, leave it and report the list of shared names. Seams 2 to 5 of WORLD-10 are not in this unit. `src/world/event_director.gd` is covered by a formal model: do not change it."
        ),
        done="`park_recipes.gd` holds no anchor cache and no anchor, level-of-detail or hull function (give the grep you used); `git grep -n 'threaded_in_bot_runs' -- sketches/core-loop/src/world/terrain.gd` shows nothing; the `\"L14\"` list gained no entry apart from moved ones you list; no `graph.bin` changed; nothing a player or a test can observe changes.",
        guard="extend the existing source-text case `sketches/core-loop/tests/unit/world_reach_ins_case.gd` (read it first): fail when `src/world/park/park_recipes.gd` declares a `static var` whose name starts with `_anchor_`, when a file other than `src/core/sim_clock.gd` declares `threaded_in_bot_runs`, and, if you did Part 3, when `src/world/activities.gd` declares `var wards` or `var plates`. Do not add a lint rule.",
        siblings="Two sibling units started with you: a combat unit (private members of `src/combat/combat.gd` that other files call become public by rename, with callers moved in `src/combat/`, `src/world/camp_sandbox.gd`, three files under `tools/` and many tests); an experimental and dev unit (`src/experimental/live_run_bridge.gd`, `live_world_actors.gd`, `src/presentation/experimental_audio_bank.gd`, `src/dev/dev_console.gd`).",
        testgrep="git grep -l -i -E 'park_recipes|anchor|hull|cover|lod|activities|ward|plate|lore|mend|threaded|bake_warm|fleet|park_graph|park_seat|test_batch_reset|world_reach' -- sketches/core-loop/tests",
    ),
    "M3": dict(
        branch="entropy/m3-combat-collaborator-calls",
        findings="Finding `COMBAT-06` in `git show origin/entropy/records:project-guide/handoff/shared/structure-sweep/combat.md`. It names the files and the members. Read `.agents/skills/scrapkeep-verify-formal/SKILL.md` too: the deferred queues of `src/combat/combat.gd` are covered by a formal model.",
        body=(
            "One part, several commits (one per member or small family of members). No logic, no value, no order of work and no signal order changes: this unit renames and adds thin reads, nothing else.\n\n"
            "**COMBAT-06, other files stop calling private members of `combat.gd`.** A unit before you moved some of these; the count now is about 145 uses in 14 files under `src/` and 3 under `tools/`. List them first: `git grep -n -o -E '(combat|spawner)\\._[a-z_]+' -- sketches/core-loop/src sketches/core-loop/tools ':!sketches/core-loop/src/combat/combat.gd'`, and the same over `sketches/core-loop/tests` for the test callers. The most used are `_hit` (26), `_flat_aim` (19), `_clock` (13), `_damage_mod` (10), `_ult_hit` (7), `_line_skills` (7), `_hull` (6), `_target_class`, `_patterns`, `_specials` and `_chain`; the callers are combat's own kits and actives (`relic_swaps.gd`, `tarn_claw.gd`, `rivet_kit.gd`, `ultimate.gd`, `kest_kit.gd`, the files under `actives/`, `stakes.gd`), plus `src/world/camp_sandbox.gd`, `src/build/maker_bonuses.gd` and three tools. For each member, find every use in `src/`, `tests/`, `tools/`, `.tscn`, `.tres` and string calls (`call(\"name\"`, `has_method(\"name\"`, `Callable(x, \"name\")`, `get(\"name\")`), then take the cheapest of these that fits: "
            "(a) a function that outside files call becomes public by rename (drop the underscore), with the same body, and every caller moves in the same commit; "
            "(b) a state field that outside files only read gets one public read, or is renamed if `combat.gd` already treats it as shared; "
            "(c) a state field that an outside file writes gets one call on `combat.gd` that does that write, not a public field; "
            "(d) if a kit reaches for something it could be handed once at setup with less code, hand it in. "
            "Do not publish a member that only tests call: tests are not in this unit's count, and a test moves only when a rename forces it. Before each rename check the new name is free: no member of `combat.gd`, of a class that extends it, or of a test double that stands in for it has that name, and no local variable or parameter of the same name changes meaning (`hit`, `clock`, `hull` and `chain` are common local names; pick a name that reads well and is free, and say which you chose). `spawner._physics_process` in a tool is an engine callback: leave it. "
            "Formal model: do not change any line of the deferred queues, `in_play()` or the attempt-boundary code beyond the rename of a called name, and report every changed line in those areas. "
            "In `src/build/maker_bonuses.gd` change only the one call. Splitting `combat.gd` (findings COMBAT-03, COMBAT-04 and COMBAT-05) is not in this unit."
        ),
        done="the first `git grep` above shows only the lines you list with a reason (the engine callback, and any member you left); no forwarding copy with the old name remains in `combat.gd`; `git diff --stat` shows `combat.gd` about the same length as before; nothing a player or a test can observe changes.",
        guard="extend the existing source-text case `sketches/core-loop/tests/unit/combat_helper_owners_case.gd` (read it first; it already lists some retired `combat._*` names): fail when a `.gd` file under `res://src/` other than `src/combat/combat.gd` contains `combat._` or `spawner._` followed by a lowercase letter, unless the file is on a list of the files you left, and fail when a listed file no longer does, so the list can only shrink. Check the pattern against the tree before your change to be sure it matches the real reach-ins. Do not add a lint rule.",
        siblings="Two sibling units started with you: a world unit (`src/world/park/park_recipes.gd`, a new `park_anchors.gd`, `src/world/activities.gd`, `src/world/terrain.gd`, `src/core/sim_clock.gd`, and one or two lines in `src/combat/fleet.gd` and `src/presentation/bake_warm.gd`); an experimental and dev unit (`src/experimental/live_run_bridge.gd`, `live_world_actors.gd`, `src/presentation/experimental_audio_bank.gd`, `src/dev/dev_console.gd`).",
        testgrep="git grep -l -E 'combat\\._[a-z]|spawner\\._[a-z]' -- sketches/core-loop/tests",
    ),
    "X3": dict(
        branch="entropy/x3-experimental-dev-seams",
        findings="Findings `XD-18`, `XD-19` and `XD-20` in `git show origin/entropy/records:project-guide/handoff/shared/structure-sweep/experimental-dev.md`. They name the lines, the callers and the tests. Only the parts listed below are yours.",
        body=(
            "Three parts, one commit each. Nothing a player, a test or a dev-console user can observe changes. "
            + SPLIT_RULE
            + "\n\n"
            "**Part 1 (XD-18, two of its three seams).** (a) In `src/dev/dev_console.gd` the still, QA-pack and contact-sheet capture block (about 290 lines) owns `_busy`, `_shots`, `shot_dir` and the `SHEET_*` constants and touches the drawer only to hide and show it. (b) In `src/experimental/live_world_actors.gd` the procedural mesh and material block (about 400 lines) owns `_mesh_cache` and `_fx_mats` and no gameplay state. Confirm each seam, then move each block to one new file beside its parent that owns that state; callers in `src/`, `tests/` and `tools/` go to the new owner, and the parent keeps no forwarding copy. A moved `static var` keeps or gains its reset in the test driver. The third seam of XD-18 is in `dynamic_setpieces.gd`, which another unit holds: leave it.\n\n"
            "**Part 2 (XD-19, the cooldown state only).** `static var _last_trigger_s` in `src/presentation/experimental_audio_bank.gd` is process-wide, while the clock it is compared with belongs to one `LiveRunBridge`. Trace every path that creates a bridge and every call of `can_trigger`, `mark_triggered` and `reset_cooldowns`. If every bridge resets the cooldowns before its first trigger, so that with one bridge at a time the stored state can never carry over, move the state onto the bridge (or pass it in) and delete the static; with one bridge the behaviour is then the same for every input. If state can carry over from one bridge to the next today, do not change it: report the path. The second half of XD-19 (routing these sounds through `src/presentation/audio.gd`) changes what is heard and is not in this unit.\n\n"
            "**Part 3 (XD-20, weigh before you act).** (a) The experimental launch flags (`--experimental-depth`, `SCRAPKEEP_EXPERIMENTAL`) are parsed in more than one file with overlapping string constants. If one of the parsers can call the other and give the same result for every input, make it one; in `src/game.gd` change only that call. (b) The dev commands return either a string with a `!` prefix for failure or an `{ok, text, data}` dictionary. Weigh one return form: count the commands, the callers and the tests on each side, and do it only if the change stays inside `src/dev/` and its tests and every reply a user or `dev_agent.gd` sees stays the same text. Otherwise leave it and report the counts, so the finding can be parked with a reason."
        ),
        done="`dev_console.gd` holds no capture code and `live_world_actors.gd` no mesh or material builder (give the greps you used); `git grep -n '_last_trigger_s' -- sketches/core-loop/src/presentation/experimental_audio_bank.gd` shows nothing, or you report why it stays; nothing a player, a test or a dev-console user can observe changes.",
        guard="add one source-text case `sketches/core-loop/tests/unit/experimental_dev_seams_case.gd`, in the form of the existing `tests/unit/world_constants_case.gd` and run by the same suite: fail when `src/dev/dev_console.gd` declares the capture state you moved, when `src/experimental/live_world_actors.gd` declares `_mesh_cache` or `_fx_mats`, and, if you did Part 2, when a file under `res://src/` declares a `static var _last_trigger_s`. Do not add a lint rule.",
        siblings="Two sibling units started with you: a world unit (`src/world/park/park_recipes.gd`, a new `park_anchors.gd`, `src/world/activities.gd`, `src/world/terrain.gd`, `src/core/sim_clock.gd`); a combat unit (private members of `src/combat/combat.gd` that other files call become public by rename, with callers moved in `src/combat/`, `src/world/camp_sandbox.gd`, three files under `tools/` and many tests).",
        testgrep="git grep -l -i -E 'experimental|live_run|live_world|dev_console|dev_agent|dev_command|dev_fight|dev_inspect|audio_bank|contact_sheet|qa_pack|test_batch_reset' -- sketches/core-loop/tests",
    ),
}

DEFAULTS = dict(baseline_exception="", extra_checks="")
UNITS["W3"]["baseline_exception"] = " (the one exception is in Part 1)"

OUT.mkdir(exist_ok=True)
for unit, u in UNITS.items():
    d = dict(DEFAULTS)
    d.update(u)
    text = INTRO.format(unit=unit, base=BASE, **d)
    assert "{" not in text.replace("{}", "").replace("{ok, text, data}", ""), unit
    p = OUT / f"r8-{unit.lower()}.md"
    p.write_text(text)
    print(p.name, len(text))
