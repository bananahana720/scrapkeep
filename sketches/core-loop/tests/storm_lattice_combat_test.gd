extends SceneTree

const Measurement := preload("res://tools/pattern_dps.gd")
const Weapons := preload("res://src/combat/weapons.gd")

const EXPECTED_CHECKS := 8
const FALL_OFF := 0.7
const ERROR_MAX := 0.10

var _game
var _started := false
var _checks := 0
var _failures := 0


func _initialize() -> void:
	_game = Measurement.MeasurementGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null or _started:
		return false
	_started = true
	Measurement.prepare(_game)
	var scenarios: Array = [{"id": "bare", "parts": []}]
	for level in [1, 2]:
		var held: Array = ["cross_split"]
		for _copy in level:
			held.append("chain_arc")
		scenarios.append({"id": "lattice_%d" % level, "parts": held})
		scenarios.append({"id": "control_%d" % level, "parts": held, "no_lattice": true})
	for neighbours in [3, 0]:
		var rows := Measurement.measure(_game, scenarios, [5.0], neighbours)
		var valid := rows.size() == 5
		for row in rows:
			valid = valid and Measurement.valid_row(row)
		_report("measurement neighbours=%d" % neighbours, valid, "%d real-combat rows" % rows.size())
		for level in [1, 2]:
			var enabled: Dictionary = rows[2 * level - 1]
			var control: Dictionary = rows[2 * level]
			var direct: float = rows[0]["dps"] * 5.0
			# The bonus continues Chain Arc's falloff: the second jump is 0.7^2,
			# and the third is 0.7^3, on each of the five real Cross Split bolts.
			var expected := direct * pow(FALL_OFF, level + 1) if neighbours > 0 else 0.0
			var added: float = enabled["dps"] - control["dps"]
			var ok := absf(added - expected) <= expected * ERROR_MAX if neighbours > 0 \
				else is_equal_approx(enabled["dps"], control["dps"])
			ok = ok and enabled["chain_jumps"] == level + 1 and control["chain_jumps"] == level
			_report("extra jump level=%d neighbours=%d" % [level, neighbours], ok,
				"enabled %.6f, removed %.6f, added %.6f, predicted %.6f DPS" \
				% [enabled["dps"], control["dps"], added, expected])
	_game.run.parts.clear()
	_game.ctx.build.recompute()
	_game.ctx.spawner._rebuild_patterns()
	_game.run.add_part("cross_split", "test")
	_game.run.add_part("chain_arc", "test")
	_report("first volley after part_gained", _game.ctx.spawner.pattern(Weapons.RAPID_LASER).chain_jumps == 2,
		"real part_gained handlers must see the new lattice before Build recomputes")
	_game.flow.retry_stage()
	_report("retry removes lattice", _game.run.parts.is_empty() \
		and _game.ctx.spawner.pattern(Weapons.RAPID_LASER).chain_jumps == 0, "no retained jump after retry")
	if _checks != EXPECTED_CHECKS:
		_failures += 1
	print("storm_lattice_combat_test: %s (%d checks, %d failures)" \
		% ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _report(label: String, ok: bool, detail: String) -> void:
	_checks += 1
	print("%s %s: %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures += 1
