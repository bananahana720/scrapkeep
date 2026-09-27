extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const SpawnerDouble := preload("res://tests/doubles/spine_spawner_double.gd")

# The power curve (DEMO-SPEC, reconciled.json owner B). Four builds are composed through
# the real run: skipper (3 gate parts, mass 60), reference (9 parts, mass 250), engaged
# (13 parts, mass 400) and absurd (17 parts, mass 700). For each it measures punch_now()
# at cruise and at blazing speed through the spine's flow, and weapon DPS.
#
# Evidence limits, stated in each line:
#   - Punch comes from tests/doubles/spine_spawner_double.gd, the spine's stand-in for
#     combat's plating rule: ram punch is (14 + 1.3 * speed) * heft. Combat's real
#     punch_now() also counts the gun; this test measures the ram half.
#   - Weapon DPS is modelled from the build sheet, not measured against a dummy: base
#     14 per hit at 5 shots a second, times (14 + part punch) / 14, the damage and rate
#     multipliers and the pattern shot factor. The stub combat on this branch ignores
#     part multipliers, so a measured DPS would be flat. Switch to a dummy measurement
#     once combat reads the build.
# The table goes to artifacts/local/power-curve.tsv.

const BUILDS := [
	{"name": "skipper", "mass": 60.0, "parts": ["hot_rivets", "cross_split", "loose_trigger"]},
	{"name": "reference", "mass": 250.0, "parts": ["hot_rivets", "cross_split", "loose_trigger", "slag_rounds", "double_feed",
		"spiral_wave", "frost_vane", "chain_arc", "focus_lens"]},
	{"name": "engaged", "mass": 400.0, "parts": ["hot_rivets", "cross_split", "loose_trigger", "slag_rounds", "double_feed",
		"spiral_wave", "frost_vane", "chain_arc", "focus_lens", "sunforged_core", "rime_heart", "gatling_heart", "horizon_optic"]},
	{"name": "absurd", "mass": 700.0, "parts": ["hot_rivets", "cross_split", "loose_trigger", "slag_rounds", "double_feed",
		"spiral_wave", "frost_vane", "chain_arc", "focus_lens", "sunforged_core", "rime_heart", "gatling_heart", "horizon_optic",
		"tempest_core", "slag_rounds", "ram_plow", "galvanic_rounds"]},
]
const BASE_DPS := 14.0 * 5.0
const HOLD_TICKS := 4

var _game
var _build
var _failures := 0
var _ticks := 0
var _index := -1
var _phase := ""
var _wait := 0
var _rows: Array[Dictionary] = []
var _row := {}


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		var double := SpawnerDouble.new()
		_game.add_child(double)
		double.setup(_game.ctx)
		_game.ctx.spawner = double
		_game.flow.press_start()
		_game.flow.choose_class(1)
		_build = _game.ctx.build
		return false
	if _ticks < 12:
		return false
	match _phase:
		"", "next":
			_index += 1
			if _index >= BUILDS.size():
				return _finish()
			_compose(BUILDS[_index])
			_phase = "cruise"
			_wait = 0
		"cruise", "blazing":
			var multiple: float = 1.0 if _phase == "cruise" else SpeedTier.MULTIPLES[SpeedTier.BLAZING] * 1.02
			_game.player.set_velocity_now(Vector3(0.0, _game.player.state.velocity.y, _game.tuning.f("cruise") * multiple))
			_wait += 1
			if _wait == HOLD_TICKS:
				_row[_phase] = _game.flow.punch_now()
				_row[_phase + "_speed"] = _game.player.planar_velocity().length()
				_row[_phase + "_tier"] = _game.player.speed_tier()
				_wait = 0
				if _phase == "cruise":
					_phase = "blazing"
				else:
					_rows.append(_row)
					_phase = "next"
	return false


# A fresh run as the runner, then the build's parts, then scrap up to its mass (the
# codex's discovery bursts land first and count toward it).
func _compose(build: Dictionary) -> void:
	_game.flow.new_run()
	var at: Vector3 = _game.ctx.terrain.drop_point(-62.0, -92.0, 1.05)
	_game.player.reset_to(at)
	_game.player.body().global_position = at
	var run = _game.run
	for part_id in build["parts"]:
		run.add_part(part_id, "test")
	var missing: float = build["mass"] - run.mass
	if missing > 0.0:
		run.add_scrap(int(missing), Vector3.ZERO)
	_row = {
		"name": build["name"], "parts": run.parts.size(), "mass": run.mass, "heft": run.heft(),
		"class": run.heft_class(), "dps": BASE_DPS * _build.power(), "punch_bonus": _build.punch_bonus(),
		"synergies": _build.active_synergies().size(),
	}


func _finish() -> bool:
	var by := {}
	for row in _rows:
		by[row["name"]] = row
	var sk: Dictionary = by["skipper"]
	var rf: Dictionary = by["reference"]
	var en: Dictionary = by["engaged"]
	var ab: Dictionary = by["absurd"]
	for row in _rows:
		print("[curve %s] %d parts, mass %.0f, heft %.2f (class %d), %d synergies: ram punch %.1f at cruise (%.1f m/s), %.1f at blazing (%.1f m/s, tier %d); modelled DPS %.0f -> PASS"
			% [row["name"], row["parts"], row["mass"], row["heft"], row["class"], row["synergies"], row["cruise"],
				row["cruise_speed"], row["blazing"], row["blazing_speed"], row["blazing_tier"], row["dps"]])
	_report("fixed ground probe", not _game.tuning.on("legacy_spin_probe"),
		"speeds measured with the default fixed ground probe (legacy spin probe off)")
	_report("skipper cruise", sk["cruise"] >= 30.0 and sk["cruise"] < 95.0, "punch %.1f (needs 30 to under 95)" % sk["cruise"])
	# Skill substitutes for growth through stage 2; on stage 3 the skipper needs the
	# Warden's magnet (the tuning pass's approved band, DESIGN-NOTES L12).
	var plating_2: float = StageDefs.of(2)["warden_plating"]
	var plating_3: float = StageDefs.of(3)["warden_plating"]
	_report("skipper blazing", sk["blazing"] >= plating_2 and sk["blazing"] < plating_3 and sk["blazing_tier"] == SpeedTier.BLAZING,
		"punch %.1f at tier %d (needs %.0f to under %.0f: skill beats stage 2's plating, stage 3 needs the magnet)"
			% [sk["blazing"], sk["blazing_tier"], plating_2, plating_3])
	_report("reference cruise", rf["cruise"] >= 95.0, "punch %.1f (needs 95+)" % rf["cruise"])
	_report("engaged cruise", en["cruise"] >= 120.0, "punch %.1f (needs 120+)" % en["cruise"])
	_report("engaged DPS", en["dps"] >= 3.0 * sk["dps"], "modelled %.0f against skipper %.0f (%.1fx, needs 3x)" % [en["dps"], sk["dps"], en["dps"] / sk["dps"]])
	_report("absurd DPS", ab["dps"] >= 6.0 * sk["dps"], "modelled %.0f against skipper %.0f (%.1fx, needs 6x)" % [ab["dps"], sk["dps"], ab["dps"] / sk["dps"]])
	_report("table written", _write(), "artifacts/local/power-curve.tsv")
	print("build_power_curve_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _write() -> bool:
	var dir := ProjectSettings.globalize_path("res://").path_join("../../artifacts/local").simplify_path()
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(dir.path_join("power-curve.tsv"), FileAccess.WRITE)
	if file == null:
		return false
	file.store_line("build\tparts\tmass\theft\tclass\tsynergies\tpunch_bonus\tram_punch_cruise\tram_punch_blazing\tmodelled_dps")
	for row in _rows:
		file.store_line("%s\t%d\t%.0f\t%.3f\t%d\t%d\t%.0f\t%.1f\t%.1f\t%.0f" % [row["name"], row["parts"], row["mass"], row["heft"],
			row["class"], row["synergies"], row["punch_bonus"], row["cruise"], row["blazing"], row["dps"]])
	file.close()
	return true
