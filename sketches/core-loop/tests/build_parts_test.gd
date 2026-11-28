extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Parts := preload("res://src/build/parts.gd")
const PartOffers := preload("res://src/build/part_offers.gd")
const BuildSheet := preload("res://src/build/build_sheet.gd")
const Elements := preload("res://src/build/elements.gd")

# Parts are data that change what they name. Each part's knobs move by exactly its
# multiplier, the live actions read the changed value (grapple range, boost cooldown,
# health ceiling), copies stack, a retry restores the build exactly, class mods and
# milestone parts stay out of the wrong pools, milestone_won grants a milestone part,
# and the growth curve starts modest and ends absurd.

const LATE_BUILD := ["sunforged_core", "sunforged_core", "gatling_heart", "gatling_heart", "cross_split",
	"cross_split", "spiral_wave", "chain_arc", "tempest_core", "slag_rounds"]

var _game
var _build
var _failures := 0
var _ticks := 0
var _milestones: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.flow.press_start()
		_game.flow.choose_class(0)
		_build = _game.ctx.get_meta("build")
		_game.events.part_gained.connect(func(id: String, source: String):
			if source == "milestone":
				_milestones.append(id))
		return false
	if _ticks < 12:
		return false
	_check_every_part()
	_check_live_actions()
	_check_stacking_and_retry()
	_check_pools()
	_check_milestones()
	_check_trajectory()
	_check_table()
	print("build_parts_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _spec_keys() -> Array:
	var keys: Array = []
	for spec in Tuning.SPECS:
		keys.append(spec["key"])
	return keys


# Every catalogue part, alone: each knob it names reads base x multiplier, and nothing
# else moves.
func _check_every_part() -> void:
	var tuning = _game.tuning
	var specs := _spec_keys()
	var wrong: Array = []
	var checked := 0
	for part_id in Parts.ids():
		var d: Resource = Parts.def(part_id)
		BuildSheet.from_parts([part_id]).apply(tuning, null)
		for knob in d.mods:
			checked += 1
			var want: float = d.mods[knob]
			var got: float = tuning.f(knob) / tuning.base(knob) if knob in specs else tuning.mod(knob)
			if not is_equal_approx(got, want):
				wrong.append("%s.%s %.3f != %.3f" % [part_id, knob, got, want])
		if not is_equal_approx(tuning.boost_cooldown_scale, d.cooldown_scale):
			wrong.append("%s cooldown %.3f" % [part_id, tuning.boost_cooldown_scale])
	BuildSheet.from_parts([]).apply(tuning, null)
	_report("each part moves its knobs", wrong.is_empty() and checked >= 20,
		"%d parts, %d named knobs checked at base x multiplier; wrong %s" % [Parts.ids().size(), checked, wrong])


# Through the real run: add_part publishes part_gained, the build recomputes, and the
# ball's own queries read the new value.
func _check_live_actions() -> void:
	var run = _game.run
	var rope: float = _game.player.grapple_range()
	var cooldown: float = _game.tuning.boost_cooldown()
	var hp: float = run.max_hp
	var dash: float = _game.tuning.f("dash_impulse")
	run.add_part("long_spool", "test")
	run.add_part("boost_coil", "test")
	run.add_part("rivet_plating", "test")
	run.add_part("frost_vane", "test")
	_report("grapple range", is_equal_approx(_game.player.grapple_range(), rope * 1.3),
		"Long Spool: grapple_range() %.1f m -> %.1f m" % [rope, _game.player.grapple_range()])
	_report("boost cooldown", is_equal_approx(_game.tuning.boost_cooldown(), cooldown * 0.85),
		"Boost Coil: shared cooldown %.3f s -> %.3f s" % [cooldown, _game.tuning.boost_cooldown()])
	_report("health ceiling", is_equal_approx(run.max_hp, hp + 15.0) and is_equal_approx(run.hp, run.max_hp),
		"Rivet Plating: max hp %.0f -> %.0f, hp %.0f" % [hp, run.max_hp, run.hp])
	_report("frost vane", is_equal_approx(_game.tuning.f("dash_impulse"), dash * 1.1) and _build.sheet.elements_for("dash") == ["frost"],
		"Frost Vane: dash impulse %.1f -> %.1f, dash element %s" % [dash, _game.tuning.f("dash_impulse"), _build.sheet.elements_for("dash")])


func _check_stacking_and_retry() -> void:
	var run = _game.run
	run.add_part("hot_rivets", "test")
	run.add_part("hot_rivets", "test")
	var stacked: float = _game.tuning.mod("weapon_damage")
	# SG15: Hot Rivets is levelled, so a second copy is level 2, whose numbers replace level 1's.
	var level_two: float = Parts.def_at("hot_rivets", 2).mods["weapon_damage"]
	_report("copies stack", is_equal_approx(stacked, level_two) and is_equal_approx(_build.weapon_mod("weapon_damage"), stacked),
		"two Hot Rivets: weapon_damage x%.4f (level 2 x%.4f)" % [stacked, level_two])
	_build.recompute()
	_build.recompute()
	_report("recompute is idempotent", is_equal_approx(_game.tuning.mod("weapon_damage"), stacked)
			and is_equal_approx(_game.player.grapple_range(), _game.tuning.base("rope_range") * 1.3),
		"after two more recomputes: weapon_damage x%.4f, grapple %.1f m" % [_game.tuning.mod("weapon_damage"), _game.player.grapple_range()])
	var parts_before: Array = run.parts.duplicate()
	_game.flow.retry_stage()
	_report("retry restores the build", run.parts.is_empty() and is_equal_approx(_game.tuning.mod("weapon_damage"), 1.0)
			and is_equal_approx(_game.player.grapple_range(), _game.tuning.base("rope_range")) and is_equal_approx(run.max_hp, run.base_max_hp()),
		"retry from %d parts back to the stage-start build %s: weapon_damage x%.2f, grapple %.1f m, max hp %.0f"
			% [parts_before.size(), run.parts, _game.tuning.mod("weapon_damage"), _game.player.grapple_range(), run.max_hp])


func _check_pools() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var leaks: Array = []
	var every: Array = ["common", "uncommon", "rare", "rare_plus"]
	var pylon := Parts.offer_pool("pylon_engineer", every)
	var runner := Parts.offer_pool("runner_gunner", every)
	for i in 400:
		for part_id in Parts.roll(rng, PartOffers.gate_rarities(i % 2), "pylon_engineer", [], 2):
			if Parts.def(part_id).milestone_only or part_id == "runner_overclock":
				leaks.append(part_id)
	_report("offer pools", leaks.is_empty() and "pylon_capacitor" in pylon and not "runner_overclock" in pylon
			and "runner_overclock" in runner and not "pylon_capacitor" in runner,
		"800 pylon offers at 0 and 1 bonus cores leaked %d milestone or runner parts; class mods only in their own pool" % leaks.size())


func _check_milestones() -> void:
	var run = _game.run
	run.record_milestone("surge_run")
	run.record_milestone("mystery_event")
	var held_ok: bool = run.parts.has("rime_heart") and run.parts.has("scrap_gravity")
	_report("milestone_won grants", _milestones == ["rime_heart", "scrap_gravity"] and held_ok,
		"milestone_won(surge_run) and milestone_won(mystery_event) granted %s with source milestone" % [_milestones])
	_report("milestone part works", _build.sheet.elements_for("roll_on_water") == ["frost"] and is_equal_approx(_build.sheet.magnet, 2.5),
		"Rime Heart freezes water under the ball (%s); Scrap Gravity magnet x%.1f" % [_build.sheet.elements_for("roll_on_water"), _build.sheet.magnet])


# Growth: one early part is modest, a late build multiplies into an absurd one, and
# gate offers climb in tier with bonus cores.
# 2026-10-15 SG14-CONTRACT ruling C10: the late floor is 20x (was 25x). power() now tracks
# measured combat on its declared contract; the late build measures 22.95x the bare laser
# (1927.8 DPS / 84 DPS, live HP removal) with Cross Split at 0.6 per fragment. The old 25x
# was set against an estimate that overstated late builds by 106 to 1657 percent.
func _check_trajectory() -> void:
	var early: float = BuildSheet.from_parts(["hot_rivets"]).power()
	var late: float = BuildSheet.from_parts(LATE_BUILD).power()
	_report("growth curve", early <= 1.5 and late >= 20.0,
		"estimated weapon output: one Hot Rivets x%.2f; a ten-part late build x%.1f" % [early, late])
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var mean := {}
	for cores in [0, 1, 2]:
		var total := 0.0
		for i in 300:
			total += Parts.def(Parts.roll(rng, PartOffers.gate_rarities(cores), "runner_gunner", [], 1)[0]).tier
		mean[cores] = total / 300.0
	_report("offers climb", mean[0] < mean[1] and mean[1] <= mean[2],
		"mean offered tier at 0, 1 and 2 bonus cores: %.2f, %.2f, %.2f" % [mean[0], mean[1], mean[2]])


func _check_table() -> void:
	var problems := Elements.problems()
	_report("element table admission", problems.is_empty() and not Elements.resolve("frost", "water").is_empty()
			and Elements.resolve("frost", "lava").is_empty(),
		"%d rows, problems %s; frost x water resolves, an unknown pair does nothing" % [Elements.ROWS.size(), problems])
