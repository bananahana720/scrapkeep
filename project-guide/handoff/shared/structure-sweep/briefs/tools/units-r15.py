"""Units of round 15, read by make-round.py. All four change the game's tree. O1 is round 13's unit, started now that the unit it had to wait for has landed."""
import pathlib
import runpy

POOL = "the task pool, `git show " + BASE + ":project-guide/handoff/shared/structure-sweep/pool.tsv`"
SURVEY = "`git show " + BASE + ":project-guide/handoff/shared/structure-sweep/"
SURVEY_AGE = (
    "The survey is four days old and more than sixty units have moved code since, so confirm every count and every name in the code before you rely on it; "
    "where the code and the survey differ, the code is right and your report says what differed."
)
FLIGHT = (
    "Other units are in flight. One deletes dead code in `sketches/core-loop/src/combat/`, `src/build/`, `src/movement/` and `src/world/` and is with its reviewer: in those four folders change only the lines this brief sends you to, and nothing beside them. "
    "One moves the source reads of guard tests onto the shared reader `sketches/core-loop/tests/support/source_scan.gd` and adds a lint rule: do not edit that reader, `scripts/sketch-lint.mjs`, `scripts/sketch-lint.test.mjs`, "
    "`sketches/core-loop/tests/test_tool_owners_test.gd`, or the way an existing guard test reads source. {beside} "
    "If the integration branch moves while you work and your pull request conflicts, merge `origin/entropy/gate` into your branch; never rebase or force-push. "
    "If the only conflict is in `scripts/sketch-lint.baseline.json` and both sides only removed entries, keep an entry only where both sides kept it."
)
GUARD = (
    "**The guard.** Add one case under `sketches/core-loop/tests/unit/` (read two of its neighbours for the shape, and `tests/support/source_scan.gd` for the reader). It reads source only through `SourceScan.matching` or `SourceScan.captures` "
    "and compares what it finds with an exact list, so it fails when a new file joins and when a listed file leaves. Never read a file by hand in a guard: a guard that reads nothing must fail, and the shared reader does that for you. "
    "Write the pattern so it matches every way the language can declare the thing (`const`, `var`, `static var`, `static func`, `func`, with or without an annotation in front), not only the one spelling in the tree today. "
    "Prove the guard: break the rule in one file, run the case, see it fail, undo the break, and put both results in the report."
)
MODEL_PAGES = (
    " If a page under `.agents/skills/scrapkeep-verify-formal/references/` names a file you changed (`game.gd`, `stage_locks.gd`, `audio.gd` and `combat.gd` among them), "
    "say so in the report with the functions you changed there; do not edit the model pages."
)
UNIT_SUITE = (
    " A `--test` argument replaces the tests that call would have picked from your changed files; it does not add to them. So make the one call above without it, read the list of tests it ran, "
    "and only if `unit_suite_test` is not in that list make a second call, `npm run sketch:fast -- --base " + BASE + " --test unit_suite_test`."
)
SAME_NUMBERS = (
    "**Nothing a player sees may change.** This unit moves where a fact is written, not what it is. Before your first edit, write a test that pins what the game computes today, run it on the base and keep its output; "
    "after your last edit the same test passes with no number in it changed. A test you write only after the change proves nothing."
)

_O1 = dict(
    runpy.run_path(
        str(pathlib.Path(__file__).with_name("units-r13.py")),
        init_globals=dict(BASE=BASE, DELETE=DELETE, NODE_CHECKS=NODE_CHECKS, GODOT_CHECKS=GODOT_CHECKS),
    )["UNITS"]["O1"]
)
_O1["flight"] = FLIGHT.format(
    beside="The unit that gave the reduced-motion setting one owner has landed and is on your base: `screens.gd`, `hud.gd` and `codex_banner.gd` now read `Comfort.reduced_motion`; leave those reads as they are. "
    "Three more units of this round run beside you: one in `src/experimental/` and `src/world/stage_locks.gd`, one in the mesh builders under `src/presentation/`, and one that wires the reduced-motion setting into `src/presentation/damage_numbers.gd` and the craft showcase."
)

UNITS = {
    "O1": _O1,
    "X4": dict(
        branch="entropy/x4-experimental-shared-numbers",
        findings="Findings `XD-12` and `XD-17` in " + SURVEY + "experimental-dev.md`. " + SURVEY_AGE,
        body=(
            "Three facts are each written in several files under `sketches/core-loop/src/experimental/`. Give each one owner, or show that the copies are different facts and leave them. Each part is its own commit.\n\n"
            + SAME_NUMBERS
            + "\n\n"
            "**Part 1 (XD-12), the wall that holds the ball in a ring.** `src/world/stage_locks.gd` owns a spring that pushes the ball back inside a locked yard: the constants `WALL_SPRING`, `WALL_DAMP` and `WALL_ACCEL_CAP`, and one line of force in the function that holds the ball. "
            "`src/experimental/encounter_engine.gd` declares the same three constants with the same values and its own function `_perimeter_spring_accel`. Read both in full before you decide anything, and compare them term by term: "
            "the survey says they are the same formula, and on a first read the two differ in how the outward speed is clamped and may differ in what happens at the centre or inside the ring. "
            "If they give the same acceleration for every position and velocity, make one pure static function on `StageLocks` that takes the ball's position and velocity, the centre and the radius and returns the acceleration, call it from both places, and delete the copy and its three constants. "
            "If they differ for some input, say exactly which input and what each returns, and still give the three constants one owner; do not change what either caller computes. "
            "Prove sameness with a test that runs both the old and the new code path over a table of inputs (inside, on the ring, outside, moving in, moving out, at the centre, far outside where the cap applies) and compares the vectors exactly. "
            "`src/experimental/` may load from `src/world/` today (check the loads `encounter_engine.gd` already has); if this would add a load in a direction the tree does not have yet, or a script dependency loop the lint refuses, put the function where both can reach it without one and say why.\n\n"
            "**Part 2 (XD-17), the cruise speed used when nobody passes one.** The ball's cruise speed is a tuning value owned by `src/movement/tuning.gd` (the row with the key `cruise`, read through `tier_cruise()`). "
            "Under `src/experimental/` the number `14.0` is written as a fallback for it in several files: `adversity_director.gd` (as the default of a config read), `encounter_engine.gd` (as argument defaults and a dictionary default), `dynamic_setpieces.gd` and `jury_rig_synergies.gd` (as their own constants), and `live_run_bridge.gd`. "
            "Find every one yourself with a search for `14.0` under `src/experimental/` and read each hit: most hits of that number are other things (a damage value, a radius, a height) and must not be touched. Only a value that stands for the ball's cruise speed belongs to this part. "
            "Give those one name in one place. Decide where from the code: if the experimental code can read the tuning row's default without a new load in a wrong direction, that row is the owner and the fallback reads it; if not, one constant in the file the others already load (look at what `env_tags.gd` is for) and a test that fails when it and the tuning row's default differ. "
            "A config resource (`.tres`) that stores `default_cruise_mps` is authored data: leave it.\n\n"
            "**Part 3 (XD-17), the shortest warning a hazard may give.** The number `0.6` (seconds) is the floor under a warning in `adversity_director.gd` (`HAZARD_TELL_FLOOR_S`), `encounter_engine.gd` and `refurbished_elites.gd` (`MIN_TELL_S`), `dynamic_setpieces.gd` (`MIN_WARN_FLOOR_S`) and, written bare, in `resources/director/refurbished_elite_config.gd`. "
            "Outside the experimental folder `src/world/events/storm_seek.gd` has its own `MIN_TELL_S` with the same value. First find out whether this is one rule: read `sketches/core-loop/design-v3/LEGIBILITY.md` and search the design pages and `src/combat/` for where a shortest warning time is stated (`git grep -n -i 'tell' -- sketches/core-loop/design-v3/LEGIBILITY.md` is a start). "
            "If the pages state one floor for every hazard, the five experimental copies become one constant and the report says whether `storm_seek.gd` and any owner in `src/combat/` hold the same rule (name them; changing files outside `src/experimental/` for this part is allowed only for that one constant and only if no new load direction is needed). "
            "If the pages give different floors for different kinds of hazard, or say nothing, merge only the copies that guard the same kind of thing and leave the rest with a sentence each in the report. Two numbers that happen to be equal are not one fact.\n\n"
            + GUARD
            + " The guard for this unit: no file under `src/` other than the owner declares `WALL_SPRING`, `WALL_DAMP` or `WALL_ACCEL_CAP`. Add a second exact list for the warning floor only if Part 3 ends with one owner."
        ),
        done="the ring spring has one function or the report shows the input where the two differ, and its three constants are declared once; the cruise fallback has one name, tied by a test to the tuning row's default; the warning floor has one owner for each rule the design pages state; a test written on the base shows no computed number changed; the guard fails on a second declaration; and no entry was added to any lint list.",
        flight=FLIGHT.format(beside="Three more units of this round run beside you: one in `src/ui/screens.gd`, `src/ui/hud.gd` and `src/presentation/codex_banner.gd`, one in the mesh builders under `src/presentation/`, and one in `src/presentation/damage_numbers.gd` and the craft showcase. In `src/world/` you may change `stage_locks.gd` only (and `events/storm_seek.gd` for one constant, under the condition in Part 3)."),
        checks=GODOT_CHECKS.format(base=BASE) + UNIT_SUITE + MODEL_PAGES,
    ),
    "V3": dict(
        branch="entropy/v3-mesh-primitives-one-owner",
        findings="Findings `VM-02` and `VM-15` in " + SURVEY + "visuals-meshes.md`, and the row of unit `V1` in `git show " + BASE + ":project-guide/handoff/shared/structure-sweep/units.tsv` (it did the first two steps of VM-02). " + SURVEY_AGE,
        body=(
            "The game builds its crafted meshes in code with `SurfaceTool`. The same few primitives are written several times: a box with bevelled edges, a bevelled cylinder, a bevelled ring, a closed torus, a faceted orb. "
            "This unit folds the copies that produce the same vertices into one owner and leaves the ones that do not, with the proof either way.\n\n"
            "**The rule that decides everything: no mesh changes by one vertex.** Before your first edit, build a census: a test or a tool script that builds every mesh the builders below produce (through the public entry points their existing tests already call), "
            "and for each records the surface count and a hash of every surface's arrays (vertices, normals, colours, UVs, indices) in a stable order. Run it on the base and commit its output under `sketches/core-loop/tests/fixtures/` as the pin (look at `tests/fixtures/pins/` for how pins are kept, and reuse an existing mesh pin if one already covers a builder). "
            "After every merge of two builders the census must match the pin exactly. Float noise is not an excuse: the same operations in the same order give the same bytes, so a difference means the merge changed the mesh; undo that merge and report it as a copy that is not the same. "
            "The census must fail when it builds nothing or reads no pin.\n\n"
            "**What to compare.** Find the builders yourself: `git grep -n -E 'func _?(add_|append_)?[a-z_]*(bevel|chamfer|torus|faceted_orb|append_box)[a-z_]*\\(' -- sketches/core-loop/src sketches/core-loop/tools`. On the base that finds, among others: "
            "`_bevel_box`, `_bevel_cyl` and `_bevel_ring` in `src/presentation/craft/enemy_boss_craft.gd`; `add_bevel_box` in `src/presentation/craft/camp_craft_meshes.gd`; `bevel_box`, `bevel_cyl`, `_bevel_ring` and `_bevel_box_masked` in `src/presentation/craft_prop_meshes.gd`; "
            "`add_beveled_box`, `add_torus` and `add_faceted_orb` in `src/presentation/crafted_ball_gear.gd`; `_add_chamfered_box` in `src/presentation/pilot_gear_kit.gd`; `add_chamfered_plate` in `src/presentation/craft/hero_kitbash_sculptor.gd`; "
            "`_add_closed_torus` and `_add_faceted_orb` in `src/presentation/world23_chunk_craft.gd`; and `_append_box` in `src/presentation/craft/vista_megastructures.gd` and `src/combat/dispatcher.gd`. "
            "Put the bodies side by side, family by family, and write down for each pair what differs: the order vertices are emitted in, where colour is set, how UVs are projected, whether a degenerate triangle is skipped, the segment counts, the argument order. "
            "Two builders are the same only when one can be written as a call of the other with fixed arguments and the census agrees.\n\n"
            "**The owner.** Unit V1 already made one home for the flat-projection UV helper and the triangle helper; read where it put them (`git show " + BASE + ":project-guide/handoff/shared/structure-sweep/units.tsv` and then the code) and put the shared primitives beside them, in that same module, so a reader finds every `SurfaceTool` primitive in one place. "
            "Do not make a new module unless the existing home would gain a load that makes a script dependency loop; the lint refuses new loops. Callers keep their own thin wrapper only where it fixes arguments for many call sites in one file and the wrapper is one line.\n\n"
            "**What to leave.** `bevel_box` in `src/presentation/recipe_props.gd` returns planes, not triangles: it is a different thing with the same name; leave it and say so. The small `_cylinder` and `_torus` helpers that make an engine `CylinderMesh` or `TorusMesh` node are a different family; leave them. "
            "`src/combat/dispatcher.gd` is in a folder another unit is working in: compare its `_append_box` and report, but do not edit it. Any pair the census shows is not the same stays as two builders, each named in the report with the difference in one sentence. "
            "It is a good result to merge three pairs and leave five with reasons; it is a failed unit if one shipped mesh changes.\n\n"
            + GUARD
            + " The guard for this unit: the exact list of files under `src/` and `tools/` that declare a `SurfaceTool` primitive builder of these families (use the pattern you searched with). It starts as the list that is left after your merges and can only shrink."
            + "\n\n**Stills.** Mesh work is proved by the census, not by eye, so no screenshots are needed. If a pin of an existing test changes, that is a changed mesh: stop and undo."
        ),
        done="a census pinned on the base shows every crafted mesh has the same surfaces, byte for byte, after the unit; each family of primitives has one builder where the copies were the same, in the module unit V1 chose; every copy that is left is named with the difference that keeps it; the guard holds the exact list of files that still declare one; and no entry was added to any lint list.",
        flight=FLIGHT.format(beside="Three more units of this round run beside you: one in `src/ui/screens.gd`, `src/ui/hud.gd` and `src/presentation/codex_banner.gd`, one in `src/experimental/` and `src/world/stage_locks.gd`, and one in `src/presentation/damage_numbers.gd` and the craft showcase's set-up code (`src/presentation/craft/craft_showcase_assembly.gd`; if you need to change a builder call in that file, change only that line)."),
        checks=GODOT_CHECKS.format(base=BASE) + UNIT_SUITE + MODEL_PAGES,
    ),
    "Q3": dict(
        branch="entropy/q3-reduced-motion-reaches-everything",
        findings="The row `LEAD-82` of " + POOL + ", and the row of unit `Q1` in `git show " + BASE + ":project-guide/handoff/shared/structure-sweep/units.tsv`.",
        body=(
            "The game has one reduced-motion setting. Since unit Q1 it has one owner, `sketches/core-loop/src/core/comfort.gd` (`Comfort.reduced_motion`, written from one place in `game.gd`). Q1 found three things that never receive the setting, so they move the same with it on: "
            "the floating damage numbers (`src/presentation/damage_numbers.gd` keeps its own `var reduced_motion` that nothing writes, and passes it to `pop_scale`), and the two background rigs of the craft showcase (`vista_atmosphere_rig.gd` and `vista_megastructures.gd` under `src/presentation/craft/`), "
            "which are reached by `CraftShowcaseAssembly.sync_accessibility`, a function only a test calls.\n\n"
            "**This unit changes what a player with the setting on sees, on purpose.** The coordinator decided it (Andrew can overturn it): the setting promises less motion everywhere, and code that already has the calm branch written but never gets told is a bug. A player with the setting off must see no change at all.\n\n"
            "**Part 1, damage numbers.** Delete the copy in `damage_numbers.gd` and read the owner where the copy was read. Read `pop_scale` and every other place in that file that animates (rise, drift, shake, scale) and say in the report which of them the calm branch covers and which it does not; do not invent new calm behaviour, only connect what is written. "
            "Test: with the owner set, the pop the file computes is the calm one; with it clear, it is exactly what the base computes (pin the numbers on the base first). Reset the owner in the test's cleanup the way the tests Q1 changed do.\n\n"
            "**Part 2, the showcase rigs.** Find who builds the showcase in a running game (`git grep -n 'CraftShowcaseAssembly' -- sketches/core-loop/src sketches/core-loop/tools`) and whether a player can reach it or only a capture tool does. "
            "If a player can reach it: the two rigs each keep a `reduced_motion` field and an `apply_accessibility`; make them follow the owner the way the objects Q1 changed do (read how Q1 handled an object that must react when the setting changes during a pause, and do the same; do not add a second way), "
            "and delete `sync_accessibility` if nothing needs it afterwards, moving its test onto the real path. If only tools and tests build the showcase, say so, connect it at the one place the tool builds it, and keep the change that small. "
            "The rigs pass the setting to a shader parameter named `reduced_motion`: that name is the shader's and stays.\n\n"
            "**The guard.** Unit Q1 added `tests/unit/comfort_owner_case.gd`, which fails on a new static copy of the setting. Its review noted it does not see a copy held by a live object, which is what this unit removes. "
            "Extend that case, through the shared reader it already uses, with an exact list of the files under `src/` that declare an instance field named `reduced_motion` (after your change the list is what is left, each with its reason in the report), so a new one fails. Prove it fails on a new copy and passes again when the copy is removed."
        ),
        done="damage numbers and the showcase rigs follow the one owner; with the setting off every number a test pinned on the base is unchanged; with it on, the calm branches that were already written run; `sync_accessibility` is gone or has a real caller; the guard holds the exact list of files that still keep their own field; and no entry was added to any lint list.",
        flight=FLIGHT.format(beside="Three more units of this round run beside you: one in `src/ui/screens.gd`, `src/ui/hud.gd` and `src/presentation/codex_banner.gd`, one in `src/experimental/` and `src/world/stage_locks.gd`, and one in the mesh builders under `src/presentation/` (it may change single builder calls in the craft files; stay out of the mesh-building functions)."),
        checks=GODOT_CHECKS.format(base=BASE) + UNIT_SUITE + MODEL_PAGES,
    ),
}
