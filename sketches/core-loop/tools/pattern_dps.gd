extends SceneTree

const BuildSweep := preload("res://tools/build_sweep.gd")
const Enemy := preload("res://src/combat/enemy.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Intent := preload("res://src/movement/intent.gd")
const BuildSheet := preload("res://src/build/build_sheet.gd")

const DT := 1.0 / BuildSheet.POWER_CONTRACT["ticks_per_second"]
const SECONDS := 30.0
const WARMUP := 1.0
const DISTANCES := [5.0, 20.0]
const BALL := Vector3(0.0, 500.0, 0.0)
const BASELINE_SETS := [
	{"world": 1, "paired_set": ["cross_split", "sunforged_core"],
		"unpaired_set": ["cross_split", "chain_arc"]},
	{"world": 2, "paired_set": ["chain_arc", "cross_split", "sunforged_core"],
		"unpaired_set": ["chain_arc", "sunforged_core", "gatling_heart"]},
	{"world": 3, "paired_set": ["chain_arc", "cross_split", "sunforged_core", "gatling_heart"],
		"unpaired_set": ["chain_arc", "sunforged_core", "gatling_heart", "spiral_wave"]},
]

class MeasurementGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _started := false


func _initialize() -> void:
	if "--proposal-input" in OS.get_cmdline_user_args():
		var definitions := {}
		for id in BuildSweep._legal_pool():
			var part: Resource = BuildSweep.Parts.def(id)
			definitions[id] = {"mods": part.mods, "patterns": part.patterns, "punch": part.punch,
				"tags": Array(part.tags)}
		print("pattern_dps proposal_input: " + JSON.stringify({"parts": definitions,
			"pairs": BuildSweep.Synergies.ROWS, "rules": {},
			"seeds": BuildSweep._pair_seeds(BuildSweep._legal_pool())}))
		quit(0)
		return
	_game = MeasurementGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null or _started:
		return false
	_started = true
	prepare(_game)
	var sets := BuildSweep.slot_growth_arm()
	print("pattern_dps arm: " + JSON.stringify(sets))
	if "--arm-only" in OS.get_cmdline_user_args():
		_game.free()
		quit(0)
		return true
	var contract_rows := measure_contract(_game)
	for row in contract_rows:
		print("pattern_dps contract: " + JSON.stringify(row))
	if "--contract-only" in OS.get_cmdline_user_args():
		var ok := contract_rows.size() == 18
		for row in contract_rows:
			ok = ok and valid_row(row) and absf(row["difference_pct"]) <= 10.0
		print("pattern_dps: %s (%d contract rows)" % ["PASS" if ok else "FAIL", contract_rows.size()])
		_game.free()
		quit(0 if ok else 1)
		return true
	var neighbours := 3 if "--neighbours=3" in OS.get_cmdline_user_args() else 0
	var rows := measure(_game, cases(BASELINE_SETS), DISTANCES, neighbours)
	var valid := rows.size() == DISTANCES.size() * cases(BASELINE_SETS).size()
	for row in rows:
		print("pattern_dps row: " + JSON.stringify(row))
		valid = valid and row["dps"] > 0.0 and row["hits"] > 0 and row["retired"] == 0 \
			and row["stationary"] and row["ledger_agrees"] and row["parts_match"] \
			and row["weapon"] == Weapons.RAPID_LASER
		if row["id"] == "chain_arc_1":
			valid = valid and (row["measured_ratio"] > 1.5 if neighbours > 0 else is_equal_approx(row["measured_ratio"], 1.0))
	print("pattern_dps: %s (%d rows)" % ["PASS" if valid else "FAIL", rows.size()])
	_game.free()
	quit(0 if valid else 1)
	return true


static func prepare(game, class_index := 1) -> void:
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(class_index)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.player.reset_to(BALL)
	game.player.body().global_position = BALL
	game.player.body().freeze = true
	game.camera.cam.get_parent().global_position = BALL
	game.camera.cam.global_basis = Basis.IDENTITY
	for group in ["enemy", "enemy_shot"]:
		for node in game.get_tree().get_nodes_in_group(group):
			node.remove_from_group(group)
			node.process_mode = Node.PROCESS_MODE_DISABLED
			node.queue_free()


static func cases(sets: Array) -> Array:
	var out: Array = [{"id": "bare", "parts": []}]
	for pattern in ["cross_split", "spiral_wave", "chain_arc"]:
		var held: Array = []
		for level in range(1, 4):
			held.append(pattern)
			out.append({"id": "%s_%d" % [pattern, level], "parts": held.duplicate()})
	for row in sets:
		var world: int = row["world"]
		out.append({"id": "world_%d_paired" % world, "parts": row["paired_set"].duplicate()})
		out.append({"id": "world_%d_missing" % world, "parts": row["unpaired_set"].duplicate()})
		if world >= 2:
			out.append({"id": "world_%d_no_lattice" % world, "parts": row["paired_set"].duplicate(), "no_lattice": true})
	return out


static func measure(game, scenarios: Array, distances := DISTANCES, neighbours := 0) -> Array:
	var rows: Array = []
	for distance in distances:
		var bare_dps := 0.0
		for scenario in scenarios:
			var row := _measure_one(game, scenario, distance, neighbours)
			if scenario["id"] == "bare":
				bare_dps = row["dps"]
			row["measured_ratio"] = row["dps"] / maxf(bare_dps, 0.000001)
			row["difference_pct"] = 100.0 * (row["power_ratio"] / row["measured_ratio"] - 1.0)
			rows.append(row)
	return rows


static func measure_contract(game) -> Array:
	return measure(game, cases(BASELINE_SETS), [BuildSheet.POWER_CONTRACT["distance_m"]],
		BuildSheet.POWER_CONTRACT["neighbours"])


static func valid_row(row: Dictionary, weapon: String = BuildSheet.POWER_CONTRACT["weapon"]) -> bool:
	return row["dps"] > 0.0 and row["hits"] > 0 and row["retired"] == 0 \
		and row["stationary"] and row["ledger_agrees"] and row["parts_match"] \
		and row["weapon"] == weapon


static func _measure_one(game, scenario: Dictionary, distance: float, neighbours: int) -> Dictionary:
	var combat = game.ctx.spawner
	var build = game.ctx.build
	game.run.parts.assign(scenario["parts"])
	build.recompute()
	if scenario.get("no_lattice", false):
		build.sheet.transformers.erase("storm_lattice")
		build.sheet.synergies.erase("storm_lattice")
		build.sheet.patterns["chain_arc"] = maxi(0, build.sheet.pattern_level("chain_arc") - 1)
	combat.rebuild_patterns()
	if scenario.get("no_lattice", false):
		for weapon in Weapons.ALL:
			combat.set_pattern(weapon, Weapons.base(weapon).transformed(combat.active_transformers()))
	var targets: Array = []
	var positions: Array = []
	for i in neighbours + 1:
		var at: Vector3 = BALL + Vector3.FORWARD * distance \
			+ Vector3.RIGHT * BuildSheet.POWER_CONTRACT["neighbour_spacing_m"] * i
		targets.append(_dummy(game, at))
		positions.append(at)
	combat.bolts.clear()
	combat.bolts.retired = 0
	combat.bolts.fired = 0
	combat.volleys = 0
	var active_w: String = combat.active_weapon()
	combat.weapon_driver.reset(combat.pattern(active_w))
	combat.reset_ledger()
	for _tick in roundi(WARMUP / DT):
		_drive_cadence(game)
		_tick_combat(game)
	var before := _health(targets)
	var target_hp_before: Array = targets.map(func(target): return target.hp)
	var ledger_before: float = combat.delivered_damage()["total"]
	var hits_before: int = combat.delivered_damage()["hits"]
	var volleys_before: int = combat.volleys
	for _tick in roundi(SECONDS / DT):
		_drive_cadence(game)
		_tick_combat(game)
	var removed := before - _health(targets)
	var ledger_damage: float = float(combat.delivered_damage()["total"]) - ledger_before
	var stationary: bool = game.player.ball_position() == BALL
	for i in targets.size():
		stationary = stationary and targets[i].global_position == positions[i]
	var target_dps: Array = []
	for i in targets.size():
		target_dps.append((target_hp_before[i] - targets[i].hp) / SECONDS)
	var pattern: Resource = combat.pattern(combat.active_weapon())
	var row := {
		"id": scenario["id"], "parts": scenario["parts"], "distance_m": distance,
		"neighbours": neighbours,
		"weapon": combat.active_weapon(), "seconds": SECONDS, "dt": DT,
		"dps": removed / SECONDS, "power_ratio": build.sheet.power(),
		"hits": int(combat.delivered_damage()["hits"]) - hits_before,
		"volleys": combat.volleys - volleys_before, "retired": combat.bolts.retired,
		"stationary": stationary,
		"ledger_agrees": absf(removed - ledger_damage) < 0.001,
		"parts_match": game.run.parts == scenario["parts"],
		"target_dps": target_dps,
		"volley_size": pattern.volley_size(),
		"chain_jumps": pattern.chain_jumps,
		"lattice": build.has_transformer("storm_lattice"),
	}
	for target in targets:
		target.remove_from_group("enemy")
		target.free()
	combat.bolts.clear()
	combat.effects.clear()
	return row


static func _dummy(game, at: Vector3) -> Node3D:
	var dummy := Enemy.new()
	dummy.name = "FixedDummy"
	dummy.hp = 100000000.0
	dummy.max_hp = dummy.hp
	dummy.plating = 0.0
	dummy.collision_layer = 0
	dummy.collision_mask = 0
	dummy.burst_fx = game.ctx.burst
	game.add_child(dummy)
	dummy.global_position = at
	dummy.add_to_group("enemy")
	return dummy


static func _health(targets: Array) -> float:
	var hp := 0.0
	for target in targets:
		hp += target.hp
	return hp


static func _drive_cadence(game) -> void:
	var combat = game.ctx.spawner
	var intent = game.player.intent
	var snap: Dictionary = combat.weapon_driver.state_snapshot()
	var trig: String = String(snap.get("trigger", "hold_auto"))
	intent.fire_pressed = false
	intent.fire_released = false
	if trig == "press":
		intent.fire_held = false
		if bool(snap.get("reloading", false)):
			if bool(snap.get("window_open", false)):
				intent.fire_pressed = true
		elif bool(snap.get("ready", false)):
			intent.fire_pressed = true
	elif trig == "tap_charge":
		intent.fire_held = false
		if bool(snap.get("ready", false)) or (float(snap.get("cooldown", 0.0)) <= DT + 0.0001 and float(snap.get("recover", 0.0)) <= DT + 0.0001):
			intent.fire_pressed = true
	else:
		intent.fire_held = true


static func _tick_combat(game) -> void:
	game.ctx.spawner._physics_process(DT)
	game.ctx.build._physics_process(DT)
	game.ctx.spawner.effects._process(DT)
