extends "res://tests/cannon_ultimate_test.gd"
# 2026-10-11 (PC-CANNON): the eight old branch ops gain variants and sixteen leaves gain knobs.
# EXPECTED_VARIANT_CHECKS includes the inherited count guard.
const EXPECTED_VARIANT_CHECKS := 72
const CannonTree := preload("res://src/core/trees/cannon.gd")


func _expected_checks() -> int:
	return EXPECTED_VARIANT_CHECKS


func _cases() -> void:
	_t = T.new("cannon_ultimate_variants_test")
	await _reset()
	var nodes: Array = CannonTree.NODES
	for i in range(6, 14):
		var node: Dictionary = nodes[i]
		var expected := "cannon_creeping_barrage" if i % 2 == 0 else "cannon_plate_mortar"
		UpgradeTree.apply_pick(_player.abilities, node)
		_t.eq("depth-3 %s swaps" % node["id"], _player.abilities.ultimate_id, expected)
		_t.check("depth-3 %s retains its original proc" % node["id"], not node.get("proc", []).is_empty())
	for i in range(6, 14, 2):
		_t.check("depth-3 siblings differ %d" % i, nodes[i]["swap"] != nodes[i + 1]["swap"])
	for i in range(14, 30):
		var knob: Dictionary = nodes[i]["knob"]
		_t.check("leaf %s has exactly one framework knob" % nodes[i]["id"], knob.size() == 1 and knob.keys()[0] in ["ult_volley", "ult_encore", "ult_radius", "ult_beats"])
	for i in range(14, 30, 2):
		_t.check("leaf siblings differ %d" % i, nodes[i]["knob"].keys() != nodes[i + 1]["knob"].keys())
	for key in ["ult_volley", "ult_encore", "ult_radius", "ult_beats"]:
		_t.eq("each knob appears four times: " + key, nodes.filter(func(n): return n.get("knob", {}).has(key)).size(), 4)
	_t.check("movement changes remain Cannon-owned", nodes.all(func(n): return String(n["id"]).begins_with("c_")))

	await _reset("cannon_creeping_barrage")
	_player.kit.hooked = true
	_player.kit.anchor = HOME + Vector3.RIGHT * 20.0
	var p: Dictionary = _ult.plan(HOME, _aim(Vector3(18.0, 100.5, 0.0)))
	_t.eq("Creeping Barrage prefers the line", p["path"], "line")
	_ult.start(p)
	_ult._begin_flight()
	_ult._cannon_tech(1, HOME, Vector3.RIGHT, 1.0)
	var entry: Dictionary = _combat._cannon.back()
	var h = entry["hazards"][0]
	_t.near("creeping warn is one beat", h.warn_seconds, float(_ult.leg_state()["beat_length"]))
	_t.near("lane is two beats ahead", h.centre.x, HOME.x + _ult._ride.velocity.x * 2.0 * float(_ult.leg_state()["beat_length"]), 0.01)
	_t.near("lane lies across the path", absf(h.heading.dot(_ult.ride_heading())), 0.0)
	var before: int = _ult._cannon_calls
	_player.tree._knobs["ult_volley"] = 1
	_ult._cannon_tech(2, HOME, Vector3.RIGHT, 1.0)
	_t.eq("volley knob adds a second lane", _ult._cannon_calls - before, 2)
	_t.near("second lane is six metres beyond the first", _combat._cannon[-1]["hazards"][0].centre.x - _combat._cannon[-2]["hazards"][0].centre.x, 6.0, 0.01)

	await _reset("cannon_plate_mortar")
	p = _ult.plan(HOME, _aim(Vector3(30.0, 100.5, 0.0)))
	_t.eq("Mortar cannot reach beyond half the class arc", p["path"], "hop")
	p = _ult.plan(HOME, _aim(Vector3(18.0, 100.5, 0.0)))
	_t.eq("Mortar uses the arc", p["path"], "arc")
	_t.eq("Mortar has six flight beats", p["beats"], Weapons.MORTAR_BEATS)
	_t.near("Mortar flight is six musical beats", p["flight"], 6.0 * float(Harmony.BEAT) / Harmony.RATE)
	_player.tree._knobs["ult_beats"] = 2
	var longer: Dictionary = _ult.plan(HOME, _aim(Vector3(18.0, 100.5, 0.0)))
	_t.eq("beat knob makes an eight-beat lob", longer["beats"], 8)
	_player.tree._knobs.clear()
	_ult.start(p)
	_ult._begin_flight()
	var foe := _enemy(HOME + Vector3.RIGHT * 4.0)
	_ult._cannon_tech(1, HOME, Vector3.RIGHT, 1.0)
	entry = _combat._cannon.back()
	_t.eq("Mortar calls a plate", entry["family"], "plate")
	_t.near("Mortar's plate warns for one beat", entry["hazards"][0].warn_seconds, float(_ult.leg_state()["beat_length"]))
	for i in ceili(float(_ult.leg_state()["beat_length"]) / DT):
		_combat._clock += DT
		_combat._step_cannon(DT)
	_t.check("Mortar plate exposes its target", _combat._exposed.has(foe.get_instance_id()))
	_ult._leg = 1
	var hp: float = foe.hp
	_ult._cannon_landing(HOME, 1.0, 1.0)
	var exposed: float = hp - foe.hp
	_combat._exposed.clear()
	hp = foe.hp
	_ult._cannon_landing(HOME, 1.0, 1.0)
	_t.near("Mortar slam cashes exposure at 1.4x", exposed / maxf(0.001, hp - foe.hp), 1.4, 0.001)
	_player.tree._knobs["ult_radius"] = 2.0
	_t.near("radius knob grows the landing", _ult.landing_radius(), _ult.LANDING_RADIUS[_ult.heft_index()] + 2.0)
	_player.tree._knobs["ult_volley"] = 1
	before = _ult._cannon_calls
	_ult._cannon_tech(2, HOME, Vector3.RIGHT, 1.0)
	_t.eq("volley knob adds a mirrored plate", _ult._cannon_calls - before, 2)
	var a = _combat._cannon[-2]["hazards"][0]
	var b = _combat._cannon[-1]["hazards"][0]
	_t.near("second plate faces the opposite side", absf(wrapf((a.a_from + a.a_to - b.a_from - b.a_to) * 0.5, -PI, PI)), PI, 0.01)

	await _reset("cannon_creeping_barrage")
	_enemy(HOME + Vector3.RIGHT * 25.0)
	_player.tree._knobs["ult_encore"] = true
	p = _ult.plan(HOME, _aim(HOME + Vector3.RIGHT * 10.0))
	_ult.start(p)
	_ult._begin_flight()
	_ult._land(HOME + Vector3.RIGHT * 10.0)
	_t.eq("encore adds one leg", _ult._plan["legs"].size(), 2)
	_t.eq("creeping encore is a line", _ult._plan["legs"].back()["mode"], "line")
	_t.eq("encore is four beats", _ult._plan["legs"].back()["beats"], 4)
	if _ult._plan["legs"].size() > 1:
		_ult._land(HOME + Vector3.RIGHT * 25.0)
	_t.eq("encore never repeats indefinitely", _ult._plan["legs"].size(), 2)
