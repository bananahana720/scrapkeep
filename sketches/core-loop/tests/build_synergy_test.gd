extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

# A synergy is live exactly while both of its parts are held, and it shows. Storm
# Lattice (Cross Split + Chain Arc) adds its transformer, a chain level and damage, and
# grows the lattice halo on the ball. Thermal Shock (Frost Vane + Arc Coil) makes the
# slam carry frost after its arc and doubles shatter damage. A gate that would
# complete a synergy says so, and a retry that drops a part drops the synergy.

var _game
var _build
var _failures := 0
var _ticks := 0


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
		_game.flow.choose_class(1)
		_build = _game.ctx.get_meta("build")
		return false
	if _ticks < 12:
		return false
	_check_storm_lattice()
	_check_thermal_shock()
	_check_gate_hint()
	_check_retry()
	print("build_synergy_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _check_storm_lattice() -> void:
	var run = _game.run
	run.add_part("cross_split", "test")
	var half: bool = not "storm_lattice" in _build.active_synergies() and not _build.has_transformer("storm_lattice") \
		and not _build.accretion.halo_visible("storm_lattice")
	var damage_half: float = _game.tuning.mod("weapon_damage")
	run.add_part("chain_arc", "test")
	var live: bool = "storm_lattice" in _build.active_synergies() and _build.has_transformer("storm_lattice")
	_report("storm lattice waits for both", half and is_equal_approx(damage_half, 1.0),
		"Cross Split alone: synergies %s, weapon_damage x%.2f, halo hidden" % [[], damage_half])
	_report("storm lattice triggers", live and _build.pattern_level("chain_arc") == 2 and _build.pattern_level("cross_split") == 1
			and is_equal_approx(_game.tuning.mod("weapon_damage"), 1.25),
		"with Chain Arc: synergies %s, transformer storm_lattice %s, patterns %s, weapon_damage x%.2f"
			% [_build.active_synergies(), _build.has_transformer("storm_lattice"), _build.patterns(), _game.tuning.mod("weapon_damage")])
	_report("storm lattice shows", _build.accretion.halo_visible("storm_lattice"),
		"the lattice halo is on the ball: %s" % _build.accretion.halo_visible("storm_lattice"))


func _check_thermal_shock() -> void:
	var run = _game.run
	run.add_part("arc_coil", "test")
	var before: Array = _build.sheet.elements_for("slam")
	run.add_part("frost_vane", "test")
	var after: Array = _build.sheet.elements_for("slam")
	_report("thermal shock triggers", before == ["arc"] and after == ["arc", "frost"]
			and "thermal_shock" in _build.active_synergies() and is_equal_approx(_build.field.shatter_scale, 2.0),
		"slam elements %s with Arc Coil alone, %s with Frost Vane too; shatter x%.1f"
			% [before, after, _build.field.shatter_scale])
	_report("thermal shock shows", _build.accretion.halo_visible("thermal_shock"),
		"the frosted coil ring is on the ball: %s" % _build.accretion.halo_visible("thermal_shock"))


func _check_gate_hint() -> void:
	var gates = _build.gates
	var ball: Vector3 = _game.player.ball_position()
	var offers: Array = gates.open(["chain_arc", "hot_rivets"], ball, Vector3(0.0, 0.0, 1.0), ["cross_split"])
	var hint: String = offers[0].get("synergy", "")
	var plain: String = offers[1].get("synergy", "")
	gates.close()
	_report("gate names the synergy", hint == "Storm Lattice" and plain == "" and offers[0]["name"] == "Chain Arc"
			and offers[0]["text"] != "" and offers[0]["rarity"] == "rare",
		"holding Cross Split, the Chain Arc gate reads '%s: %s' with hint '%s'; Hot Rivets hint '%s'"
			% [offers[0]["name"], offers[0]["text"], hint, plain])


func _check_retry() -> void:
	_game.flow.retry_stage()
	_report("retry drops the synergy", _build.active_synergies().is_empty() and not _build.accretion.halo_visible("storm_lattice")
			and not _build.accretion.halo_visible("thermal_shock") and is_equal_approx(_game.tuning.mod("weapon_damage"), 1.0),
		"after retry to the stage start: synergies %s, halos hidden, weapon_damage x%.2f"
			% [_build.active_synergies(), _game.tuning.mod("weapon_damage")])
